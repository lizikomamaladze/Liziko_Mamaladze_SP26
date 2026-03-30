-- 1.
-- Data uniqueness is ensured using a WHERE NOT EXISTS condition.
-- Before inserting each film, the query checks whether a film with the same title
-- already exists in the table. If such a record exists, the INSERT is skipped.
-- This prevents duplicate entries and makes the script safe to rerun multiple times.
-- This is confirmed by executing the query multiple times, where after first, next executions
-- result in no rows being returned by the RETURNING clause.

-- Relationships between tables are established through foreign keys.
-- The language_id is not hardcoded, instead, it is dynamically retrieved
-- from the language table using a SELECT statement.
-- This ensures that only valid and existing language_id values are used,
-- preserving referential integrity between the film and language tables.

-- Separate INSERT statements were chosen for clarity and step-by-step control.
-- This makes the script easier to read, test, and debug,
-- It clearly shows how each record is inserted and how conditions
-- are applied individually. 
-- It is especially suitable for a small number of records, as in this case.


BEGIN;

-- The Notebook
INSERT INTO public.film (
	title , description , release_year ,
	language_id , rental_duration , rental_rate ,
	replacement_cost , length , rating , last_update  
	)
SELECT 
    'THE NOTEBOOK',
    'A romantic story of a young couple separated by social differences.',
    2004,
    l.language_id,
    7,
    4.99,
    14.99,
    123,
    'PG-13',
    CURRENT_TIMESTAMP
FROM public.language l
WHERE UPPER(l.name) = 'ENGLISH'
AND NOT EXISTS (
    SELECT 1 FROM public.film f WHERE UPPER(f.title) = 'THE NOTEBOOK'
)
RETURNING * ;


-- Interstellar
INSERT INTO public.film (
    title, description, release_year, 
    language_id, rental_duration, rental_rate, 
    replacement_cost, length, rating, last_update
	)
SELECT 
    'INTERSTELLAR',
    'A team travels through a wormhole in space to ensure humanity survival.',
    2014,
    l.language_id,
    14,
    9.99,
    19.99,
    169,
    'PG-13',
    CURRENT_TIMESTAMP
FROM public.language l
WHERE UPPER(l.name) = 'ENGLISH'
AND NOT EXISTS (
    SELECT 1 FROM public.film f WHERE UPPER(f.title) = 'INTERSTELLAR'
)
RETURNING * ;


-- Shutter Island
INSERT INTO public.film (
    title, description, release_year, 
	language_id, rental_duration, rental_rate, 
	replacement_cost, length, rating, last_update
)
SELECT 
    'SHUTTER ISLAND',
    'U.S. Marshal investigates a disappearance at a mental institution. Where things take a huge turn.',
    2010,
    l.language_id,
    21,
    19.99,
    24.99,
    138,
    'R',
    CURRENT_TIMESTAMP
FROM public.language l
WHERE UPPER(l.name) = 'ENGLISH'
AND NOT EXISTS (
    SELECT 1 FROM public.film f WHERE UPPER(f.title) = 'SHUTTER ISLAND'
)
RETURNING * ;

COMMIT;


-- Let's add this films into film_category table.
-- First we need to add Romance and Thriller to the category table.

BEGIN ;
INSERT INTO public.category ("name", last_update)
SELECT c."name",
	   CURRENT_TIMESTAMP
FROM (
		VALUES 
			('Romance') ,
			('Thriller')  
) AS c("name") 	
WHERE NOT EXISTS (
		SELECT 1 
		FROM public.category existing 
		WHERE UPPER(existing."name") = UPPER(c."name")
) 
RETURNING * ;	
COMMIT ;


-- Next add films to the film_category table.

BEGIN ;
INSERT INTO public.film_category (film_id, category_id, last_update)
SELECT f.film_id ,
	   c.category_id ,
	   CURRENT_TIMESTAMP
FROM public.film f
INNER JOIN (
		VALUES
			('THE NOTEBOOK', 'ROMANCE'),
			('INTERSTELLAR', 'SCI-FI'),
			('SHUTTER ISLAND', 'THRILLER')
) AS m(title, category_name) ON UPPER(f.title) = m.title 
INNER JOIN public.category c ON UPPER(c."name") = m.category_name 
WHERE NOT EXISTS (
	SELECT 1 
	FROM public.film_category fc
	WHERE fc.film_id = f.film_id
		AND fc.category_id = c.category_id 
)		
RETURNING film_id, category_id ;	
COMMIT ;

-- Missing categories (Romance, Thriller) were inserted into the category table
-- before creating relationships, to ensure that all required category records exists.

-- Film-category relationships were then inserted into the film_category table
-- using JOINs to retrieve film_id and category_id from existing tables,
-- avoiding hardcoded IDs and preserving referential integrity.

-- INSERT INTO ... SELECT was used instead of VALUES to allow dynamic retrieval
-- of IDs from existing tables, avoiding hardcoding and ensuring correctness.

-- WHERE NOT EXISTS was used in both queries to prevent duplicate entries,
-- making the script safe to rerun and maintaining data integrity.


------------------------------------------------------------------------------------------------
-- 2. 

-- Adding the real actors who play leading roles in my favorite movies to the actor table.

-- Data uniqueness is ensured using a WHERE NOT EXISTS condition,
-- which checks whether an actor with the same first_name and last_name
-- already exists in the actor table before inserting. If an actor 
-- already exists it skips and transaction is not executed.
-- Relationships are not directly established in this step,
-- but actors are uniquely identified using their first_name and last_name,
-- which are later used to correctly link them with films.

BEGIN ;
INSERT INTO public.actor ( 
		first_name,
		last_name,
		last_update
)
SELECT a.first_name ,
	   a.last_name ,
	   CURRENT_TIMESTAMP
FROM (
		VALUES 
			('RYAN', 'GOSLING'),
	        ('RACHEL', 'MCADAMS'),
	        ('MATTHEW', 'MCCONAUGHEY'),
	        ('ANNE', 'HATHAWAY'),
	        ('LEONARDO', 'DICAPRIO'),
	        ('MARK', 'RUFFALO')
) AS a(first_name, last_name)
WHERE NOT EXISTS (
		SELECT 1
		FROM public.actor existing
		WHERE UPPER(existing.first_name) = a.first_name 
			AND UPPER(existing.last_name) = a.last_name 	
)
RETURNING * ;
COMMIT ;


-- Adding the real actors who play leading roles in my favorite movies to the film_actor table.

-- Data uniqueness in here is also ensured using a WHERE NOT EXISTS condition,
-- which checks whether a relationship between a given actor_id and film_id
-- already exists in the film_actor table before inserting.
-- Relationships between tables are established using JOIN operations:
-- actor_id is retrieved from the actor table and film_id from the film table,
-- based on matching actor names and film titles.
-- This approach avoids hardcoding IDs and ensures referential integrity
-- by linking only existing and valid records from both tables.

BEGIN ;
INSERT INTO public.film_actor (actor_id, film_id, last_update )
SELECT a.actor_id ,
	   f.film_id ,
	   CURRENT_TIMESTAMP
FROM 
	( 
	   VALUES ('RYAN', 'GOSLING', 'THE NOTEBOOK'),
	          ('RACHEL', 'MCADAMS', 'THE NOTEBOOK'),
	          ('MATTHEW', 'MCCONAUGHEY', 'INTERSTELLAR'),
	          ('ANNE', 'HATHAWAY', 'INTERSTELLAR'),
	          ('LEONARDO', 'DICAPRIO', 'SHUTTER ISLAND'),
	          ('MARK', 'RUFFALO', 'SHUTTER ISLAND')
) AS fa(first_name, last_name, title)
INNER JOIN public.actor a ON UPPER(a.first_name) = fa.first_name 
		AND UPPER(a.last_name) = fa.last_name 
INNER JOIN public.film f ON UPPER(f.title) = fa.title 
WHERE NOT EXISTS (
	SELECT 1
	FROM public.film_actor existing 
	WHERE existing.actor_id = a.actor_id
		AND existing.film_id = f.film_id
)
RETURNING * ;
COMMIT ;


----------------------------------------------------------------------------------------------------
-- 3. 
-- Adding my favorite movies to 47 MYSAKILA DRIVE store's inventory.

-- Data uniqueness is ensured using a WHERE NOT EXISTS condition,
-- which checks whether a film_id and store_id combination already exists
-- in the inventory table before inserting. 
-- Relationships between tables are established dynamically:
-- film_id is retrieved from the film table, and store_id is retrieved
-- indirectly from the store table via the address table.
-- Specifically, store_id is determined by selecting the store whose address
-- matches '47 MySakila Drive', as recommended by mentors in the Teams chat.
-- This approach avoids hardcoding IDs and ensures referential integrity.

-- INNER JOIN is used even though film and store are not directly related,
-- because the join condition filters the store table to a single valid row.
-- This effectively pairs each selected film with the chosen store,
-- which is the intended behavior when I am inserting inventory records.

BEGIN ;
INSERT INTO public.inventory (film_id, store_id, last_update)
SELECT f.film_id ,
	   s.store_id ,
	   CURRENT_TIMESTAMP
FROM public.film f 
INNER JOIN public.store s ON s.address_id = (
								SELECT a.address_id
								FROM public.address a
								WHERE UPPER(a.address) = '47 MYSAKILA DRIVE'
								LIMIT 1
                                )
WHERE UPPER(f.title) IN (
    'THE NOTEBOOK',
    'INTERSTELLAR',
    'SHUTTER ISLAND'
)
AND NOT EXISTS (
    SELECT 1
    FROM public.inventory i
    WHERE i.film_id = f.film_id
      AND i.store_id = s.store_id
)
RETURNING * ;
COMMIT ; 


--------------------------------------------------------------------------------------------------------------
-- 4.
-- The goal of this task was to identify one customer who has at least 43 rental and 43 payment records
-- and update their personal information to my own.

-- First, a subquery was created to identify eligible customers. This was done by joining the
-- customer, rental, and payment tables and grouping them by customer_id. The HAVING clause ensures
-- that only customers with at least 43 distinct rentals and payments are considered.
-- Data uniqueness was ensured by selecting a single customer using MIN(customer_id) and LIMIT 1,
-- which guarantees that only one row is updated.
-- Additionally, an extra condition was added:
-- (UPPER(c.first_name) <> 'LIZIKO' OR UPPER(c.last_name) <> 'MAMALADZE')
-- Which prevents repeated updates if the query is executed multiple times,
-- making the operation consistent and avoiding unnecessary changes.

BEGIN ;
UPDATE public.customer c
SET first_name = 'LIZIKO' ,
	last_name = 'MAMALADZE', 
	email = LOWER('liziko.mamaladze') || '@' || (
        SELECT SPLIT_PART(email, '@', 2)
        FROM public.customer
        LIMIT 1
    ),
	address_id = (
					SELECT a.address_id a 
					FROM public.address a 
					ORDER BY a.district 
					LIMIT 1 
				 ) ,
	last_update = CURRENT_TIMESTAMP
WHERE c.customer_id = (	
SELECT MIN(c2.customer_id) 
FROM public.customer c2 
INNER JOIN public.rental r ON c2.customer_id = r.customer_id 
INNER JOIN public.payment p ON c2.customer_id = p.customer_id 
GROUP BY c2.customer_id 
HAVING COUNT(DISTINCT(r.rental_id)) >= 43
	AND COUNT(DISTINCT(P.payment_id)) >= 43
ORDER BY c2.customer_id 
LIMIT 1 
)
AND ( UPPER(c.first_name) <> 'LIZIKO'
      OR UPPER(c.last_name) <> 'MAMALADZE' )
RETURNING * ;
COMMIT ;


----------------------------------------------------------------------------------------------------------
-- 5.
-- Removing any records related to me (as a customer) from all tables except 'Customer' and 'Inventory'.
-- So removing records related to me from - rental and payment tables.

-- Because I only changed one customer records to my information, and there were
-- no other customers with name like mine, I decided to determine which rows i wanted to 
-- delete using first_name and list_name and linking them to proper customer_id, with it
-- I deleted my record from payment table. If it were to be other customers with 
-- same name as mine, i would have used same subquery i used in the previous task in WHERE clause:
-- SELECT MIN(c2.customer_id) 
-- FROM public.customer c2 
-- INNER JOIN public.rental r ON c2.customer_id = r.customer_id 
-- INNER JOIN public.payment p ON c2.customer_id = p.customer_id 
-- GROUP BY c2.customer_id 
-- HAVING COUNT(DISTINCT(r.rental_id)) >= 43
--	 AND COUNT(DISTINCT(P.payment_id)) >= 43
-- ORDER BY c2.customer_id 
-- LIMIT 1 
-- to find corresponding customer_id.

-- Delete payments
BEGIN ;
DELETE FROM public.payment 
WHERE customer_id = (
		SELECT customer_id
		FROM public.customer
		WHERE UPPER(first_name) = 'LIZIKO'
			AND UPPER(last_name) = 'MAMALADZE'
		)
RETURNING * ;

-- Delete rentals
DELETE FROM public.rental 
WHERE customer_id = (
		SELECT customer_id
		FROM public.customer
		WHERE UPPER(first_name) = 'LIZIKO'
			AND UPPER(last_name) = 'MAMALADZE'
		)
RETURNING * ;
COMMIT ;

-- Payments were deleted first because each payment is linked to a rental.
-- If rentals were deleted first, payment records would still reference them,
-- causing an error. Therefore, payments must be removed before rentals.

-- Why deleting from tables is safe:
-- Deletions are limited to one specific customer, identified using
-- first_name and last_name that were uniquely updated earlier.
-- This ensures that only the intended records are affected.

-- How unintended data loss is prevented:
-- The correct customer_id is retrieved using a subquery,
-- ensuring that only records linked to that customer are removed.
-- No hardcoded IDs are used, reducing the risk of mistakes.


-------------------------------------------------------------------------------------------------
-- 6.
-- Renting my favorite movies from the store they are in and paying for them.

-- First, I inserted records into the rental table. To do this, I needed:
-- inventory_id to know which physical copy of the film is rented,
-- customer_id to link the rental to me and 
-- staff_id, assigned using an existing value from the staff table.

-- I joined inventory with film to filter only my selected movies.
-- Then I joined customer using my name. Even though customer is not directly related
-- to inventory or film, this join works as a filtering step to attach my customer_id
-- to each selected row.
-- The return_date is calculated dynamically using rental_duration from the film table,
-- which makes the logic consistent with how long each movie would be rented.

-- After rentals were inserted, I inserted records into the payment table.
-- Here I reused the rental records to get rental_id and staff_id, ensuring that each
-- payment is correctly linked to its rental.
-- The amount is taken from rental_rate, which I had defined earlier when inserting films,
-- so the payment reflects the actual cost of renting each movie.

-- I also used a fixed date (2017-01-15) for rental_date and payment_date to avoid
-- partitioning issues in the payment table, as required in the instructions.

-- Using NOT EXISTS conditions in both INSERT statements ensures data uniqueness
--
-- For rentals it checks if the same customer has already rented the same inventory item.
-- and for payments it checks if a payment already exists for a given rental_id.
-- This prevents inserting duplicate values if the script is run multiple times.

BEGIN ;
INSERT INTO public.rental (
			rental_date, inventory_id, 
			customer_id, return_date, 
			staff_id, last_update
			)
SELECT 
		TIMESTAMP '2017-01-15' ,
		i.inventory_id ,
		c.customer_id ,
		TIMESTAMP '2017-01-15' + (f.rental_duration || ' days')::INTERVAL ,
		( SELECT max(staff_id)
		  FROM public.staff s
	    ) ,
		CURRENT_TIMESTAMP  		
FROM public.inventory i 
INNER JOIN public.film f ON i.film_id = f.film_id 
INNER JOIN public.customer c ON UPPER(c.first_name) = 'LIZIKO'
							 AND UPPER(c.last_name) = 'MAMALADZE'
WHERE UPPER(f.title) IN (
		'THE NOTEBOOK' ,
		'INTERSTELLAR' ,
		'SHUTTER ISLAND' 
		)
AND NOT EXISTS (
				 SELECT 1
				 FROM public.rental r2exi
				 WHERE r2exi.inventory_id = i.inventory_id
				 	AND r2exi.customer_id = c.customer_id
			   )  	
RETURNING * ;

-- Insert into payment table
INSERT INTO public.payment (
			customer_id, staff_id, 
			rental_id, amount, payment_date
			)
SELECT r.customer_id ,
	   r.staff_id ,
	   r.rental_id ,
	   f.rental_rate ,
	   TIMESTAMP '2017-01-15'
FROM public.rental r 
INNER JOIN public.inventory i ON r.inventory_id = i.inventory_id 
INNER JOIN public.film f ON i.film_id = f.film_id 
INNER JOIN public.customer c ON r.customer_id = c.customer_id 
WHERE UPPER(c.first_name) = 'LIZIKO'
	AND UPPER(c.last_name) = 'MAMALADZE'
	AND UPPER(f.title) IN (
		'THE NOTEBOOK' ,
		'INTERSTELLAR' ,
		'SHUTTER ISLAND' 
		)
AND NOT EXISTS (
				 SELECT 1
				 FROM public.payment p2exi
				 WHERE p2exi.rental_id = r.rental_id
			   ) 
RETURNING * ;			   
COMMIT ;

-------------------------------------------------------------------------------------------------
-- Overall Notes:

-- A separate transaction is used to group all operations together.
-- This ensures that either all changes are applied successfully,
-- or none of them are saved if an error occurs.

-- If the transaction fails at any point, none of the changes will be saved.
-- An error will be shown and nothig will run before ROLLBACK. 
-- This prevents partial updates (for example, inserting rentals without payments).

-- Rollback is possible because these are DML operations (INSERT, UPDATE, DELETE),
-- which can be undone before COMMIT. If a failure occurs, 
-- all changes made in the transaction would be reverted.

-- Referential integrity is preserved by always using existing values from related tables
-- such as language_id, category_id, customer_id, inventory_id, instead of hardcoding them.
-- Joins and subqueries ensure that only valid relationships are created.

-- The script avoids duplicates by using NOT EXISTS conditions before inserting data
-- and using not equal <> . This ensures that the same records are not 
-- inserted multiple times if the script is rerun.

