-- During testing, I noticed that the created roles did not have permission to use SET ROLE,
-- so I could not easily switch between users within the same session.
-- Because of this, I performed privilege granting and revoking while connected as the postgres user,
-- and used a separate SQL editor connection as rentaluser for testing access.

-- Additionally, I hardcoded some values (such as IDs) to simplify testing
-- and avoid overcomplicating the queries at this stage.

--------------
-- Task 2 
--------------

-- Implementing role-based authentication model for dvd_rental database
-------------------------------------------------------------------------------------
-- 1) 

-- Creating the user
CREATE ROLE rentaluser 
WITH LOGIN 
PASSWORD 'rentalpassword';

-- Allowing the user to connect to the dvdrental database
GRANT CONNECT ON DATABASE dvdrental TO rentaluser;

-- Ensuring no additional permissions are given
REVOKE ALL ON SCHEMA public FROM rentaluser;

-- Connected as rentaluser before running the following tests:

-- Successful access (connection works)
SELECT current_user;
-- Result should show : rentaluser

-- Denied access 
SELECT * FROM public.customer;
-- Result showed ERROR: permission denied for table customer

-------------------------------------------------------------------------------------
-- 2)

-- Granting SELECT permission on customer table
GRANT SELECT ON TABLE public.customer TO rentaluser;

-- Still connected as rentaluser for tests :

-- Successful access
SELECT * FROM public.customer;
-- Query should return rows

-- Still restricted action
INSERT INTO public.customer (store_id, first_name, last_name, email, address_id, active)
VALUES (1, 'Test', 'User', 'user@test.ge', 1, 1);
-- Returns - ERROR: permission denied for table customer
-- As mentioned by a mentor, for testing only, I hardcoded some values, as in other case
-- I would had to grant SELECT on other tables as well.

---------------------------------------------------------------------------------------
-- 3)

-- Connected back to postgres as current role - rentaluser does have ability to create roles. 

-- Creating a group role 
CREATE ROLE rental NOLOGIN;

-- Adding rentaluser to the rental group
GRANT rental TO rentaluser;

-- Checking role membership
SELECT 
    r.rolname AS role,
    m.rolname AS member
FROM pg_auth_members am
INNER JOIN pg_roles r ON r.oid = am.roleid
INNER JOIN pg_roles m ON m.oid = am.member
WHERE m.rolname = 'rentaluser';

-- The result should show that rental role has member rentaluser in it

------------------------------------------------------------------------------------
-- 4)

-- Connected as postgres

-- Lets grant INSERT and UPDATE to rental group
GRANT INSERT, UPDATE ON TABLE public.rental TO rental;

-- For testing I again connect as rentaluser
INSERT INTO rental (rental_date, inventory_id, customer_id, return_date, staff_id)
VALUES (CURRENT_TIMESTAMP, 1, 1, CURRENT_TIMESTAMP, 1);
-- The INSERT operation failed even though INSERT permission was granted on the table.
-- The error indicated a lack of permission on the sequence "rental_rental_id_seq".
-- This showed that inserting into a table with an auto-generated primary key
-- also requires access to the underlying sequence.


-- To resolve this issue, I granted USAGE and SELECT permissions on the sequence.
-- This is necessary because PostgreSQL uses the sequence to generate values
-- for the rental_id column during INSERT operations.
-- Without access to the sequence, the database cannot assign a new ID,
-- which causes the INSERT to fail.
GRANT USAGE, SELECT ON SEQUENCE public.rental_rental_id_seq TO rental;
-- Connected back to postgres to grant this.

-- After this the INSERT query executed succssfully

-- To also check UPDATE (connected as rentaluser)
UPDATE rental
SET return_date = CURRENT_TIMESTAMP
WHERE rental_id = 1;

-- The UPDATE operation initially failed even though rentaluser already had SELECT privilege.
-- I realized that PostgreSQL evaluates permissions strictly and does not always combine
-- privileges from different sources (direct user grants vs role-based grants) in a flexible way.

-- In this case, UPDATE was granted through the 'rental' role,
-- while SELECT was not granted within the same role context.

-- To ensure consistent permission evaluation, I granted SELECT on the rental table
-- to the 'rental' role as well. After this, both SELECT and UPDATE were available
-- through the same role, and the UPDATE operation worked successfully.

GRANT SELECT ON TABLE public.rental TO rental;
-- Granted this from postgres connection
-- And after that the UPDATE worked.

DELETE FROM rental WHERE rental_id = 1;
-- This should still be denied and it is.

---------------------------------------------------------------------------------------
-- 5)

-- Revoking INSERT from rental role (connected as postgres)
REVOKE INSERT ON TABLE public.rental FROM rental;

SELECT grantee, privilege_type
FROM information_schema.role_table_grants
WHERE table_name = 'rental';
-- With this we can see that the INSERT privilage is not on the list anymore.

INSERT INTO rental (rental_date, inventory_id, customer_id, return_date, staff_id)
VALUES (CURRENT_TIMESTAMP, 2, 2, CURRENT_TIMESTAMP, 2);
-- So now we can see that we gan an ERROR: "permission denied" 
-- meaning that rental does not have INSERT privilege

---------------------------------------------------------------------------------------
--6)
-- First we find any customer (connected as postgres, to have access on all needed tables)
SELECT c.customer_id, c.first_name, c.last_name
FROM public.customer c
INNER JOIN rental r ON c.customer_id = r.customer_id
INNER JOIN payment p ON c.customer_id = p.customer_id
LIMIT 1;

-- Got TOMMY COLLAZO, with customer_id = 459

-- Creating role for selected customer
CREATE ROLE client_tommy_collazo NOLOGIN;
-- Created the role with NOLOGIN as it was not specifid in the task.

-- As task only asked to create role and not to grant any privileges
-- we can see that SELECT or any other commands will not work.

-- For testing we can connecnt as tommy collazo and check SELECT 

SELECT * FROM public.rental;
-- And the ERROR shows that permission is denied for table rental.

SELECT grantee, privilege_type
FROM information_schema.role_table_grants
WHERE grantee = 'client_tommy_collazo';
-- Additionally we can see that this role has no privileges

----------------------------------------------------------------------------

-----------
-- Task 3
-----------
-- Implementing row-level security
------------------------------------------------------------
-- (connected as postgres)

-- Enabled Row-Level security on rental and payment tables
ALTER TABLE public.rental ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.payment ENABLE ROW LEVEL SECURITY;

-- Created policies that allow access only to rows
-- where customer_id matches the selected customer (459).

CREATE POLICY rental_policy
ON public.rental
FOR SELECT
TO client_tommy_collazo
USING (customer_id = 459);

CREATE POLICY payment_policy
ON public.payment
FOR SELECT
TO client_tommy_collazo
USING (customer_id = 459);

-- Now we grant SELECT to this user
GRANT SELECT ON public.rental TO client_tommy_collazo;

GRANT SELECT ON public.payment TO client_tommy_collazo;

-- Now we can test if it is working
-- we SET ROLE (connect) to client_tommy_collazo and run this queries:

-- Successful access
SELECT * 
FROM public.rental
WHERE customer_id = 459;

SELECT * 
FROM public.payment
WHERE customer_id = 459;
-- And we can see that both queries are executed successfully
-- and they show rental and payment information for tommy collazo only.

-- Denied access 
SELECT * 
FROM public.rental
WHERE customer_id <> 459;

SELECT * 
FROM public.payment
WHERE customer_id <> 459;

-- On the other hand, this queries show 0 rows.
-- meaning that, row-level security is working correctly,
-- ensuring that users can only access their own data.

----------------------------------------------------------------
