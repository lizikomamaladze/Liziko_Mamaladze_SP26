---------------------------------------------------------
-- Task 3
-----------

-- DROP statements are used to ensure the script is fully rerunnable.
-- They remove existing database objects before recreation,
-- preventing errors such as "already exists" and avoiding duplicate data.
-- This guarantees a clean environment on every execution.

DROP DATABASE IF EXISTS household_store_db;

-- Create database
CREATE DATABASE household_store_db;

-- Connected to my db and oppened new SQL script connected to household_store_db.

DROP SCHEMA IF EXISTS store_schema CASCADE;
CREATE SCHEMA store_schema;

SET search_path TO store_schema;

-- Set store_schema as default.

-- For creating tables I follow this order to avoid FK errors: category - store - customer -
-- - employee - product - inventory - orders - order_item

-- For rerunnability Dropped in reverse dependency order to avoid FK conflicts

DROP TABLE IF EXISTS order_item CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS inventory CASCADE;
DROP TABLE IF EXISTS product CASCADE;
DROP TABLE IF EXISTS employee CASCADE;
DROP TABLE IF EXISTS customer CASCADE;
DROP TABLE IF EXISTS store CASCADE;
DROP TABLE IF EXISTS category CASCADE;

-- Data types:
-- INT/SERIAL are used for IDs and foreign keys to keep joins efficient.
-- VARCHAR is used for names, emails, and text fields with reasonable limits.
-- DECIMAL is used for prices and amounts to ensure precise financial calculations.
-- TIMESTAMP is used to track when records are created or updated.

-- NOT NULL:
-- Applied to required fields such as names, foreign keys, quantity, price,
-- and status to ensure essential business data is always provided.

-- UNIQUE:
-- Added where values must not repeat in a real-world logic:
-- - category_name (no duplicate categories)
-- - customer.phone_number (each customer has a unique contact)
-- - employee.email (unique identifier for employees)
-- - (store_id, product_id) in inventory (no duplicate product should be registered per store)
-- - (orders_id, product_id) in order_item (no duplicate product per order)
-- (inventory might have several same products, but they are not repeatedly shown in a table, 
-- it is shown in quantity and we have the same approach in order_item table.
-- oder_item.quantity show's, how many same products are bought in each order.)

-------------------
-- CATEGORY table
-------------------

CREATE TABLE category (
    category_id SERIAL PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL UNIQUE,
    last_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-------------------
-- STORE table
-------------------
CREATE TABLE store (
    store_id SERIAL PRIMARY KEY,
    location VARCHAR(150) NOT NULL,
    last_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-------------------
-- CUSTOMER table
-------------------
CREATE TABLE customer (
    customer_id SERIAL PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    phone_number VARCHAR(20) NOT NULL UNIQUE,
    home_address VARCHAR(150),
    last_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

------------------
-- EMPLOYEE table
------------------
CREATE TABLE employee (
    employee_id SERIAL PRIMARY KEY,
    store_id INT NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    position VARCHAR(100),
    email VARCHAR(100) UNIQUE,
    home_address VARCHAR(150),
    last_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_employee_store
        FOREIGN KEY (store_id) REFERENCES store(store_id)
);

-------------------
-- PRODUCT table
-------------------
CREATE TABLE product (
    product_id SERIAL PRIMARY KEY,
    category_id INT NOT NULL,
    name VARCHAR(100) NOT NULL,
    brand VARCHAR(100),
    price DECIMAL(10,2) NOT NULL,
    last_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_product_category
        FOREIGN KEY (category_id) REFERENCES category(category_id)
);

---------------------
-- INVENTORY table
---------------------
CREATE TABLE inventory (
    inventory_id SERIAL PRIMARY KEY,
    store_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    last_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_inventory_store
        FOREIGN KEY (store_id) REFERENCES store(store_id),

    CONSTRAINT fk_inventory_product
        FOREIGN KEY (product_id) REFERENCES product(product_id),

    CONSTRAINT uq_inventory_store_product
        UNIQUE (store_id, product_id)
);

---------------------
-- ORDERS table
---------------------
CREATE TABLE orders (
    orders_id SERIAL PRIMARY KEY,
    customer_id INT NOT NULL,
    employee_id INT NOT NULL,
    store_id INT NOT NULL,
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    amount DECIMAL(12,2) DEFAULT 0,
    status VARCHAR(20) NOT NULL,
    last_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id) REFERENCES customer(customer_id),

    CONSTRAINT fk_orders_employee
        FOREIGN KEY (employee_id) REFERENCES employee(employee_id),

    CONSTRAINT fk_orders_store
        FOREIGN KEY (store_id) REFERENCES store(store_id)
);

-------------------------
-- ORDER_ITEM table
-------------------------
CREATE TABLE order_item (
    order_item_id SERIAL PRIMARY KEY,
    orders_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    price_at_purchase DECIMAL(10,2) NOT NULL,
    last_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_orderitem_orders
        FOREIGN KEY (orders_id) REFERENCES orders(orders_id),

    CONSTRAINT fk_orderitem_product
        FOREIGN KEY (product_id) REFERENCES product(product_id),

    CONSTRAINT uq_orderitem_order_product
        UNIQUE (orders_id, product_id)
);

-- Adding CHECK constraints using ALTER TABLE

ALTER TABLE category
ADD CONSTRAINT chk_category_name_not_empty
CHECK (category_name <> '');

ALTER TABLE store
ADD CONSTRAINT chk_store_location_not_empty
CHECK (location <> '');

ALTER TABLE product
ADD CONSTRAINT chk_product_price_positive
CHECK (price > 0);

ALTER TABLE inventory
ADD CONSTRAINT chk_inventory_quantity_non_negative
CHECK (quantity >= 0);

ALTER TABLE orders
ADD CONSTRAINT chk_orders_amount_non_negative
CHECK (amount >= 0);

ALTER TABLE orders
ADD CONSTRAINT chk_orders_status_valid
CHECK (status IN ('pending', 'completed', 'canceled'));

ALTER TABLE orders
ADD CONSTRAINT chk_orders_date_after_2026
CHECK (order_date > '2026-01-01');

ALTER TABLE order_item
ADD CONSTRAINT chk_order_item_quantity_positive
CHECK (quantity > 0);

ALTER TABLE order_item
ADD CONSTRAINT chk_order_item_price_positive
CHECK (price_at_purchase > 0);


-- CHECK constraints are used to enforce business rules on data values
-- and prevent invalid entries at the database level.

-- They ensure that:
-- Numeric values such as price, quantity, and amount are positive or non-negative;
-- Order status is limited to predefined valid values;
-- Dates follow logical constraints (orders must be after a certain date);
-- Text fields are not empty where meaningful data is required.


-- In this system, calculated values depend on data from multiple rows
-- and tables, so GENERATED columns are not suitable.
-- Specifically:
-- - orders.amount is calculated as the total sum of all related order_item values
-- - inventory.quantity must decrease when a product is sold
-- These operations require aggregation (SUM) and cross-table updates,
-- which are implemented using functions and triggers.
-- Triggers are executed automatically after INSERT operations on order_item,
-- ensuring that calculations and updates happen immediately and consistently
-- without requiring manual queries.

CREATE OR REPLACE FUNCTION update_order_amount()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE orders
    SET amount = (
        SELECT COALESCE(SUM(quantity * price_at_purchase), 0)
        FROM order_item
        WHERE orders_id = NEW.orders_id
    )
    WHERE orders_id = NEW.orders_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
-- This function is created to automatically calculate the total amount of an order.
-- Each time a new item is added to order_item, the function sums all item prices
-- (quantity * price_at_purchase) for that order and updates orders.amount.
-- This ensures that the total is always correct without manual calculation.

CREATE OR REPLACE FUNCTION update_inventory_quantity()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE inventory
    SET quantity = quantity - NEW.quantity
    WHERE product_id = NEW.product_id
      AND store_id = (
          SELECT store_id
          FROM orders
          WHERE orders_id = NEW.orders_id
      );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
-- This function is created to update inventory after a product is sold.
-- When a customer places an order, the ordered quantity is subtracted
-- from the inventory of the corresponding product and store.
-- This keeps stock levels accurate and reflects real store operations.


DROP TRIGGER IF EXISTS trg_update_order_amount ON order_item;

CREATE TRIGGER trg_update_order_amount
AFTER INSERT ON order_item
FOR EACH ROW
EXECUTE FUNCTION update_order_amount();
-- This trigger runs after a new row is inserted into order_item.
-- It calls the update_order_amount function to recalculate the total order amount.
-- This guarantees that every order always reflects the correct total price.

DROP TRIGGER IF EXISTS trg_update_inventory ON order_item;

CREATE TRIGGER trg_update_inventory
AFTER INSERT ON order_item
FOR EACH ROW
EXECUTE FUNCTION update_inventory_quantity();
-- This trigger runs after a new row is inserted into order_item.
-- It calls the update_inventory_quantity function to decrease inventory
-- based on the quantity purchased.
-- This ensures that inventory is updated automatically after each sale.

--------------------------------------------------------------------------

--------------
-- Task 4
--------------
-- Populate the tables with the sample data generated.

-- CATEGORY tabel
INSERT INTO category (category_name)
SELECT v.category_name
FROM (VALUES
    ('TV'),
    ('Smartphone'),
    ('Laptop'),
    ('Washing Machine'),
    ('Refrigerator'),
    ('Microwave')
) AS v(category_name)
WHERE NOT EXISTS (
    SELECT 1 FROM category c WHERE c.category_name = v.category_name
);


-- STORE table
INSERT INTO store (location)
SELECT v.location
FROM (VALUES
    ('Tbilisi Mall'),
    ('City Mall Saburtalo'),
    ('City Mall Gldani'),
    ('Galleria Tbilisi'),
    ('East Point'),
    ('Grand Mall')
) AS v(location)
WHERE NOT EXISTS (
    SELECT 1 FROM store s WHERE s.location = v.location
);


-- CUSTOMER table
INSERT INTO customer (first_name, last_name, phone_number, home_address)
SELECT *
FROM (VALUES
    ('Liziko', 'Mamaladze', '555111111', 'Tbilisi, Guramishvili avenue 12a'),
    ('Giorgi', 'Kapanadze', '555222222', 'Kutaisi, Kandelaki street 22'),
    ('Keto', 'Gumberidze', '555333333', 'Tbilisi, Mosashvili street 2'),
    ('Luka', 'Maisuradze', '555444444', 'Rustavi, Rustaveli avenue 11'),
    ('Mariam', 'Papidze', '555555555', 'Tbilisi, Faliashvili street 35'),
    ('Saba', 'Chabakauri', '555666666', 'Tbilisi, Lotkini street 26')
) AS v(first_name, last_name, phone_number, home_address)
WHERE NOT EXISTS (
    SELECT 1 FROM customer c WHERE c.phone_number = v.phone_number
);


-- EMPLOYEE table
INSERT INTO employee (store_id, first_name, last_name, position, email)
SELECT
    (SELECT store_id FROM store WHERE UPPER(LOCATION) = UPPER(v.LOCATION)),
    v.first_name,
    v.last_name,
    v.position,
    v.email
FROM (VALUES
    ('Tbilisi Mall', 'Dato', 'Girgvliani', 'Manager', 'dato@mail.com'),
    ('City Mall Saburtalo', 'Lasha', 'Talakhadze', 'Sales', 'lasha@mail.com'),
    ('City Mall Gldani', 'Irakli', 'Sulaberidze', 'PR', 'irakli@mail.com'),
    ('Galleria Tbilisi', 'Mariam', 'Giligashvili', 'Sales', 'nika@mail.com'),
    ('East Point', 'Barbare', 'Lomidze', 'Manager', 'giga@mail.com'),
    ('Grand Mall', 'Eka', 'Meladze', 'Marketing', 'tornike@mail.com')
) AS v(location, first_name, last_name, position, email)
WHERE NOT EXISTS (
    SELECT 1 FROM employee e WHERE UPPER(e.email) = UPPER(v.email)
); 


-- PRODUCT table
INSERT INTO product (category_id, name, brand, price)
SELECT
    (SELECT category_id FROM category WHERE UPPER(category_name) = UPPER(v.category_name)),
    v.name,
    v.brand,
    v.price
FROM (VALUES
    ('TV', 'LG OLED (2024)', 'LG', 4799),
    ('Smartphone', 'iPhone 17 Pro Max', 'Apple', 4799),
    ('Laptop', 'MacBook Air (2019)', 'Apple', 1200),
    ('Washing Machine', 'Samsung Wash (2025)', 'Samsung', 3500),
    ('Refrigerator', 'LG Fridge (2020)', 'LG', 1700),
    ('Microwave', 'Panasonic Micro', 'Panasonic', 850)
) AS v(category_name, name, brand, price)
WHERE NOT EXISTS (
    SELECT 1 FROM product p WHERE UPPER(p.name) = UPPER(v.name)
);


-- INVENTORY table
INSERT INTO inventory (store_id, product_id, quantity)
SELECT
    (SELECT store_id FROM store WHERE UPPER(location) = UPPER(v.location)),
    (SELECT product_id FROM product WHERE UPPER(name) = UPPER(v.product_name)),
    v.quantity
FROM (VALUES
    ('Tbilisi Mall', 'LG OLED (2024)', 10),
    ('City Mall Saburtalo', 'iPhone 17 Pro Max', 15),
    ('City Mall Gldani', 'MacBook Air (2019)', 8),
    ('Galleria Tbilisi', 'Samsung Wash (2025)', 6),
    ('East Point', 'LG Fridge (2020)', 7),
    ('Grand Mall', 'Panasonic Micro', 12),
    ('City Mall Saburtalo', 'LG OLED (2024)', 5),
    ('East Point', 'iPhone 17 Pro Max', 3)
) AS v(location, product_name, quantity)
WHERE NOT EXISTS (
    SELECT 1
    FROM inventory i
    WHERE i.store_id = (
        SELECT store_id FROM store WHERE UPPER(location) = UPPER(v.location)
    )
    AND i.product_id = (
        SELECT product_id FROM product WHERE UPPER(name) = UPPER(v.product_name)
    )
);


-- ORDERS table
INSERT INTO orders (customer_id, employee_id, store_id, status)
SELECT
    (SELECT customer_id FROM customer WHERE phone_number = v.phone),
    (SELECT employee_id FROM employee WHERE UPPER(email) = UPPER(v.email)),
    (SELECT store_id FROM store WHERE UPPER(location) = UPPER(v.location)),
    v.status
FROM (VALUES
    ('555111111', 'dato@mail.com', 'Tbilisi Mall', 'completed'),
    ('555222222', 'lasha@mail.com', 'City Mall Saburtalo', 'pending'),
    ('555333333', 'irakli@mail.com', 'City Mall Gldani', 'completed'),
    ('555444444', 'nika@mail.com', 'Galleria Tbilisi', 'completed'),
    ('555555555', 'giga@mail.com', 'East Point', 'pending'),
    ('555666666', 'tornike@mail.com', 'Grand Mall', 'completed')
) AS v(phone, email, location, status)
WHERE NOT EXISTS (
    SELECT 1
    FROM orders o
    WHERE o.customer_id = (
        SELECT customer_id FROM customer WHERE phone_number = v.phone
    )
    AND o.order_date::date = CURRENT_DATE
);


-- ORDER_ITEM table
INSERT INTO order_item (orders_id, product_id, quantity, price_at_purchase)
SELECT
    (
        SELECT o.orders_id
        FROM orders o
        INNER JOIN customer c ON c.customer_id = o.customer_id
        INNER JOIN store s ON s.store_id = o.store_id
        WHERE c.phone_number = v.phone
          AND UPPER(s.location) = UPPER(v.location)
          AND o.order_date::date = v.order_date::date
        ORDER BY o.order_date DESC
        LIMIT 1
    ),
    (
        SELECT p.product_id
        FROM product p
        WHERE UPPER(p.name) = UPPER(v.product_name)
    ),
    v.quantity,
    v.price
FROM (VALUES
    ('555111111', 'Tbilisi Mall', DATE '2026-04-25', 'LG OLED (2024)', 2, 4799),
    ('555222222', 'City Mall Saburtalo', DATE '2026-04-25', 'iPhone 17 Pro Max', 3, 4799),
    ('555333333', 'City Mall Gldani', DATE '2026-04-25', 'MacBook Air (2019)', 1, 1200),
    ('555444444', 'Galleria Tbilisi', DATE '2026-04-25', 'Samsung Wash (2025)', 1, 3500),
    ('555555555', 'East Point', DATE '2026-04-25', 'LG Fridge (2020)', 2, 1700),
    ('555666666', 'Grand Mall', DATE '2026-04-25', 'Panasonic Micro', 4, 850)
) AS v(phone, location, order_date, product_name, quantity, price)
WHERE NOT EXISTS (
    SELECT 1
    FROM order_item oi
    WHERE oi.orders_id = (
        SELECT o.orders_id
        FROM orders o
        INNER JOIN customer c ON c.customer_id = o.customer_id
        INNER JOIN store s ON s.store_id = o.store_id
        WHERE c.phone_number = v.phone
          AND UPPER(s.location) = UPPER(v.location)
          AND o.order_date::date = v.order_date::date
        ORDER BY o.order_date DESC
        LIMIT 1
    )
    AND oi.product_id = (
        SELECT p.product_id
        FROM product p
        WHERE UPPER(p.name) = UPPER(v.product_name)
    )
);

-- Instead of hardcoding orders_id, I use a subquery to dynamically find the correct order.
-- The order is identified using customer (phone_number), store (location), and order_date,
-- because a customer can place multiple orders in the same store at different times.

-- I cast order_date to DATE (o.order_date::date = v.order_date::date)
-- because VALUES inputs are treated as text, and this avoids type mismatch errors.


-- Overall, all INSERT queries are written using INSERT INTO ... SELECT with VALUES blocks
-- instead of direct INSERT INTO ... VALUES. This allows the input data to be treated
-- as a temporary table and then dynamically connected to existing tables.
-- Surrogate keys (like customer_id, product_id, orders_id) are never hardcoded.
-- Instead, subqueries are used to retrieve these IDs based on meaningful business data
-- such as phone number, email, product name, or store location.
-- JOINs and subqueries are used to maintain referential integrity,
-- ensuring that all foreign key relationships are correctly resolved at runtime.
-- UPPER() is used in text comparisons to make matching case-insensitive,
-- preventing errors due to differences in letter casing.
-- WHERE NOT EXISTS is applied in insert statements to prevent duplicate records.
-- This ensures that if the script is executed multiple times, it will not insert the same data again.

-------------------------------------------------------------------------------------------------------

-------------
-- Task 5.1
-------------

-- This function updates a specific column in the product table dynamically.
-- It takes product_id, column name, and new value as inputs.

CREATE OR REPLACE FUNCTION update_product_column(
    p_product_id INT,
    p_column_name TEXT,
    p_new_value TEXT
)
RETURNS VOID AS
$$
BEGIN
    UPDATE product
    SET
        price = CASE 
            WHEN p_column_name = 'price' THEN p_new_value::NUMERIC(10,2) 
            ELSE price 
        END,
        "name" = CASE 
            WHEN p_column_name = 'name' THEN p_new_value 
            ELSE "name" 
        END,
        brand = CASE 
            WHEN p_column_name = 'brand' THEN p_new_value 
            ELSE brand 
        END
    WHERE product_id = p_product_id;
END;
$$ LANGUAGE plpgsql;

-- This function updates a column in the product table using CASE statements.
-- The column to update is chosen based on p_column_name.
-- If the column name matches, the new value is applied,
-- otherwise the existing value is kept.

SELECT update_product_column(1, 'price', '4200');
-- So if a product is on a sale or looses price we can update it easier.

-----------------------------------------------------------------------------------

--------------
-- Task 5.2
--------------

-- This function creates a new transaction by inserting into orders and order_item tables.
-- It uses natural keys (phone, email, location, product name) to find IDs dynamically.

CREATE OR REPLACE FUNCTION add_transaction(
    p_customer_phone TEXT,
    p_employee_email TEXT,
    p_store_location TEXT,
    p_product_name TEXT,
    p_quantity INT,
    p_price NUMERIC
)
RETURNS TEXT AS
$$
DECLARE
    v_order_id INT;
BEGIN
    INSERT INTO orders (customer_id, employee_id, store_id, status)
    VALUES (
        (SELECT customer_id FROM customer WHERE phone_number = p_customer_phone),
        (SELECT employee_id FROM employee WHERE email = p_employee_email),
        (SELECT store_id FROM store WHERE location = p_store_location),
        'pending'
    )
    RETURNING orders_id INTO v_order_id;
    INSERT INTO order_item (orders_id, product_id, quantity, price_at_purchase)
    VALUES (
        v_order_id,
        (SELECT product_id FROM product WHERE "name" = p_product_name),
        p_quantity,
        p_price
    );
    RETURN 'Transaction inserted successfully';
END;
$$ LANGUAGE plpgsql;

SELECT add_transaction(
    '555111111',
    'dato@mail.com',
    'City Mall Saburtalo',
    'iPhone 17 Pro Max',
    2,
    4799
);

-- First, a new order is created and its ID is stored using RETURNING.
-- Then, order_item is inserted using that order_id.
-- The function returns a message to confirm successful insertion.

---------------------------------------------------------------------------

---------------
-- Task 6
---------------

-- This view shows analytics for the most recent quarter based on order_date.

CREATE OR REPLACE VIEW recent_quarter_analytics AS
SELECT
    c.first_name || ' ' || c.last_name AS customer_name,
    s.location AS store,
    p."name" AS product,
    oi.quantity,
    oi.price_at_purchase,
    (oi.quantity * oi.price_at_purchase) AS total_price,
    o.order_date
FROM orders o
JOIN customer c ON c.customer_id = o.customer_id
JOIN store s ON s.store_id = o.store_id
JOIN order_item oi ON oi.orders_id = o.orders_id
JOIN product p ON p.product_id = oi.product_id
WHERE
    EXTRACT(YEAR FROM o.order_date) = (
        SELECT EXTRACT(YEAR FROM MAX(order_date)) FROM orders
    )
AND EXTRACT(QUARTER FROM o.order_date) = (
        SELECT EXTRACT(QUARTER FROM MAX(order_date)) FROM orders
    );	

-- The view joins orders, customer, store, product, and order_item tables
-- to display meaningful business information instead of surrogate keys.
-- The latest year and quarter are determined using MAX(order_date)
-- and EXTRACT is used to compare year and quarter values.

SELECT * FROM recent_quarter_analytics;

-------------------------------------------------------------------------------------

-------------
-- Task 7 
-------------
-- This role is created for a manager with read-only access.

-- drop role if exists so it is rerunnable
DROP ROLE IF EXISTS manager_readonly;

-- create role with login
CREATE ROLE manager_readonly
WITH LOGIN PASSWORD 'manager_readonly_123';

-- allow connection to database
GRANT CONNECT ON DATABASE household_store_db TO manager_readonly;

-- allow usage of schema
GRANT USAGE ON SCHEMA store_schema TO manager_readonly;

-- allow SELECT on all tables
GRANT SELECT ON ALL TABLES IN SCHEMA store_schema TO manager_readonly;

-- ensure future tables also get SELECT permission
ALTER DEFAULT PRIVILEGES IN SCHEMA store_schema
GRANT SELECT ON TABLES TO manager_readonly;


-- LOGIN allows the role to connect to the database.
-- CONNECT allows access to the database itself.
-- USAGE allows access to the schema.
-- SELECT permission allows reading data from all tables.
-- ALTER DEFAULT PRIVILEGES ensures that any new tables
-- will also automatically have SELECT permission.

SET ROLE manager_readonly;

SELECT * FROM store_schema.product;

INSERT INTO store_schema.product(name, brand, price)
VALUES ('Test Product', 'Test', 100);

-- We see that SELECT works for manager_readonly but INSERT fails.

-------------------------------------------------------------------------------
