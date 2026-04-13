------------
-- TASK 1
------------

-- This view calculates total sales revenue per film category
-- for the current quarter and current year.

CREATE OR REPLACE VIEW sales_revenue_by_category_qtr AS 
SELECT c."name" AS category_name ,
	   SUM(p.amount) AS total_revenue 
FROM public.category c 
INNER JOIN public.film_category fc ON c.category_id = fc.category_id 
INNER JOIN public.inventory i ON fc.film_id = i.film_id 
INNER JOIN public.rental r ON i.inventory_id = r.inventory_id 
INNER JOIN public.payment p ON r.rental_id = p.rental_id 
WHERE 
	EXTRACT(YEAR FROM p.payment_date) = EXTRACT(YEAR FROM CURRENT_DATE)
	AND EXTRACT(QUARTER FROM p.payment_date) = EXTRACT(QUARTER FROM CURRENT_DATE)
GROUP BY c."name" 
HAVING SUM(p.amount) > 0 ;

-- The current year and current quarter is determined dynamically using:
-- EXTRACT(YEAR FROM CURRENT_DATE) and EXTRACT(QUARTER FROM CURRENT_DATE)
-- This ensures the query always uses the system's current year and
-- makes the view dynamic — when the quarter changes,
-- the result updates automatically.

-- The query uses INNER JOINs between payment-related tables,
-- so only categories with existing payment records are included.

-- Categories without sales are excluded because:
-- INNER JOIN removes categories with no related payment records
-- and HAVING SUM(p.amount) > 0 removes categories with zero total revenue.

-- Example of data that should NOT appear:
-- This query shows categories with NO sales in the current quarter
SELECT c.name
FROM category c
WHERE c.category_id NOT IN (
    SELECT DISTINCT c2.category_id
    FROM category c2
    INNER JOIN film_category fc ON c2.category_id = fc.category_id
    INNER JOIN inventory i ON fc.film_id = i.film_id
    INNER JOIN rental r ON i.inventory_id = r.inventory_id
    INNER JOIN payment p ON r.rental_id = p.rental_id
    WHERE 
        EXTRACT(YEAR FROM p.payment_date) = EXTRACT(YEAR FROM CURRENT_DATE)
        AND EXTRACT(QUARTER FROM p.payment_date) = EXTRACT(QUARTER FROM CURRENT_DATE)
);
-- These categories should NOT appear in the view
-- because they have no sales in the current quarter.


-- Why this logic is used:
-- This allows us to calculate total revenue per category.
-- We might need it to see which movie genre is more popular in current year and quarter
-- and also filtering by them ensures the result is dynamic and always up-to-date.

-- How the result is calculated:
-- Revenue is calculated using SUM(p.amount),
-- which adds all payment amounts for each category and 
-- GROUP BY c.name ensures aggregation is done per category.

-- Test queries:
-- The query logic was tested using a fixed year and quarter
-- before creating a VIEW.
-- Valid case - using known data:
SELECT 
    c."name" ,
    SUM(p.amount)
FROM public.category c 
INNER JOIN public.film_category fc ON c.category_id = fc.category_id 
INNER JOIN public.inventory i ON fc.film_id = i.film_id 
INNER JOIN public.rental r ON i.inventory_id = r.inventory_id 
INNER JOIN public.payment p ON r.rental_id = p.rental_id 
WHERE 
    EXTRACT(YEAR FROM p.payment_date) = 2017
    AND EXTRACT(QUARTER FROM p.payment_date) = 1
GROUP BY c."name" ;
-- Using known existing data shows the expected result 
-- that should have been returned.
-- This confirms correct joins and aggregation.

-- But our created VIEW shows how empty, non-exsistant data is handled
-- so that would have been invalid testing.
SELECT * FROM sales_revenue_by_category_qtr;


----------------------------------------------------------------------------------------------------------

------------
-- Task 2 
------------

-- This function returns total sales revenue per category
-- for the quarter and year based on the input date parameter.

CREATE OR REPLACE FUNCTION get_sales_revenue_by_category_qtr(p_date DATE)
RETURNS TABLE (
    category_name TEXT,
    total_revenue NUMERIC
)
LANGUAGE SQL
AS $$
	SELECT c."name" AS category_name ,
		   SUM(p.amount) AS total_revenue 
	FROM public.category c 
	INNER JOIN public.film_category fc ON c.category_id = fc.category_id 
	INNER JOIN public.inventory i ON fc.film_id = i.film_id 
	INNER JOIN public.rental r ON i.inventory_id = r.inventory_id 
	INNER JOIN public.payment p ON r.rental_id = p.rental_id 
	WHERE 
		EXTRACT(YEAR FROM p.payment_date) = EXTRACT(YEAR FROM p_date)
		AND EXTRACT(QUARTER FROM p.payment_date) = EXTRACT(QUARTER FROM p_date)
	GROUP BY c."name" 
	HAVING SUM(p.amount) > 0 ;
$$;

-- The parameter is needed because, it allows the function to be reusable and flexible,
-- so users can specify any date and see totoal sales revenue for that year and quarter,
-- instead of relying on CURRENT_DATE, this prevents having to fix whole query again and again.

-- The function accepts a DATE, so quarter is automatically derived.
-- Therefore, invalid quarter values cannot be passed directly.
-- If NULL is passed, the function returns an empty result.

-- If there are no payments for the given quarter and year,
-- the function returns an empty result (no rows), not an error.

-- Test queries:
-- valid case:
SELECT * 
FROM get_sales_revenue_by_category_qtr('2017-01-01');
-- Expected result:
-- Returns categories with total revenue for Q1 2017
-- (same logic as in Task 1 test) as this test shows what will the result be 
-- if date is chosen from, dates in our database.

-- edge case – NULL input or non-existent
SELECT * 
FROM get_sales_revenue_by_category_qtr(NULL);

SELECT *
FROM get_sales_revenue_by_category_qtr(CURRENT_DATE);

-- Return empty results (since SQL function cannot raise exception)

------------------------------------------------------------------------------------------------------

-------------
-- Task 3
-------------

-- This function returns the most popular film (by number of rentals)
-- for each given country.

-- This function returns the most popular film (by number of rentals)
-- for each given country.

CREATE OR REPLACE FUNCTION public.most_popular_films_by_countries(p_countries TEXT[])
RETURNS TABLE (
    country TEXT,
    film TEXT,
    rating TEXT,
    "language" TEXT,
    "length" INT,
    release_year INT
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_countries IS NULL OR array_length(p_countries, 1) IS NULL THEN
        RAISE EXCEPTION 'Country list cannot be NULL or empty';
    END IF;
    RETURN QUERY
    WITH film_counts AS (
        SELECT 
            co.country::TEXT AS country_name,
            f.title::TEXT AS film,
            f.rating::TEXT AS rating,
            l.name::TEXT AS "language",
            f.length::INT AS "length",
            f.release_year::INT AS release_year,
            COUNT(r.rental_id) AS rental_count
        FROM public.country co
        INNER JOIN public.city ci ON co.country_id = ci.country_id
        INNER JOIN public.address a ON ci.city_id = a.city_id
        INNER JOIN public.customer cu ON a.address_id = cu.address_id
        INNER JOIN public.rental r ON cu.customer_id = r.customer_id
        INNER JOIN public.inventory i ON r.inventory_id = i.inventory_id
        INNER JOIN public.film f ON i.film_id = f.film_id
        INNER JOIN public.language l ON f.language_id = l.language_id
        WHERE co.country = ANY(p_countries)
        GROUP BY co.country, f.title, f.rating, l.name, f.length, f.release_year
    ),
    max_counts AS (
        SELECT 
            country_name,
            MAX(rental_count) AS max_rentals
        FROM film_counts
        GROUP BY country_name
    )
    SELECT 
        fc.country_name AS country,
        fc.film,
        fc.rating,
        fc."language",
        fc."length",
        fc.release_year
    FROM film_counts fc
    INNER JOIN max_counts mc
        ON fc.country_name = mc.country_name
       AND fc.rental_count = mc.max_rentals;
END;
$$;

-- The logic is structured using CTEs to separate steps - first calculating rental counts,
-- then identifying the maximum rental count per country, and finally selecting the top films.
-- Using CTEs improves readability and avoids complex nested queries, making the logic
-- easier to understand and maintain.
-- Data types are explicitly casted to match the function’s return types and ensure
-- consistency, especially when working with non-standard types.
-- Column names are carefully defined and renamed where needed to avoid ambiguity
-- between internal query columns and the function’s output columns. This helps
-- to refer to a specific column without misundersanding.

-- The most popular film is defined by the number of rentals (COUNT of rental_id).
-- Rental counts are calculated for each film, and the maximum count per country is identified.
-- The film(s) with this maximum rental count are considered the most popular.

-- How ties are handled:
-- If multiple films have the same highest number of rentals in a country,
-- all of them are returned, since they match the maximum rental count.
-- this is done with - fc.rental_count = mc.max_rentals

-- If a country has no data, it will not appear in the result,
-- because there are no records to include after filtering and aggregation.

SELECT * 
FROM public.most_popular_films_by_countries (ARRAY['Brazil','United States']);
-- Returns the most popular film(s) for each country based on rental count.

SELECT * 
FROM public.most_popular_films_by_countries(NULL);

SELECT * 
FROM public.most_popular_films_by_countries(ARRAY[]::TEXT[]);

-- The function raises an exception: 'Country list cannot be NULL or empty',
-- because input validation checks prevent execution with invalid parameters.

------------
-- Task 4 
------------

-- The goal is to return films that match a partial title and are currently available in stock.
-- Based on mentors feedback, "in stock" is defined as having at least one inventory copy that is not currently rented (meaning, not in an active rental without return_date).
-- Additionally, the task requires showing the most recent rental information (customer and rental date), so the query selects only the latest rental per film using MAX(rental_date).
--
-- A loop iterates over query results and a counter variable generates row numbers manually.
--
-- Overall, the function satisfies all requirements: filtering by title, ensuring availability, returning latest rental data, 
-- and generating row numbers (without window functions).

CREATE OR REPLACE FUNCTION public.films_in_stock_by_title(p_title TEXT)
RETURNS TABLE (
    row_num INT,
    film_title TEXT,
    "language" TEXT,
    customer_name TEXT,
    rental_date TIMESTAMP
)
LANGUAGE plpgsql
AS $$
DECLARE counter INT := 0;
BEGIN
    FOR film_title, "language", customer_name, rental_date IN
        SELECT 
            f.title::TEXT,
            l.name::TEXT,
            (cu.first_name || ' ' || cu.last_name)::TEXT,
            r.rental_date
        FROM public.film f
        INNER JOIN public."language" l ON f.language_id = l.language_id
        INNER JOIN public.inventory i ON f.film_id = i.film_id
        INNER JOIN public.rental r ON i.inventory_id = r.inventory_id
        INNER JOIN public.customer cu ON r.customer_id = cu.customer_id
        WHERE f.title ILIKE p_title
        -- Only films that are available
        AND EXISTS (
            SELECT 1
            FROM public.inventory i2
            LEFT JOIN public.rental r2 ON i2.inventory_id = r2.inventory_id 
              AND r2.return_date IS NULL
            WHERE i2.film_id = f.film_id
              AND r2.rental_id IS NULL
        )
        -- Only latest rental
        AND r.rental_date = (
            SELECT MAX(r2.rental_date)
            FROM public.rental r2
            INNER JOIN public.inventory i2 
                ON r2.inventory_id = i2.inventory_id
            WHERE i2.film_id = f.film_id
        )
    LOOP
        counter := counter + 1;
        row_num := counter;
        RETURN NEXT;
    END LOOP;

    IF counter = 0 THEN
        RAISE NOTICE 'No films found or no available copies in stock';
    END IF;
END;
$$;

-- '%' represents any sequence of characters, so '%love%' matches titles containing "love" anywhere.

-- Performance considerations:
-- The query can be slower because it joins multiple tables and uses '%...%' pattern matching,
-- which cannot use indexes efficiently.
-- To reduce unnecessary work, filtering is done early (by title and availability),
-- so fewer rows are processed in the rest of the query.

-- Case sensitivity:
-- ILIKE is used instead of LIKE to ensure case-insensitive matching,
-- so titles match regardless of uppercase or lowercase letters.

-- Multiple matches:
-- If multiple films match the title and are available, all of them are returned.
-- Each result is assigned a unique row number using a counter in the loop.

-- No matches:
-- If no films match the title or no copies are available in stock,
-- the function returns no rows and raises a NOTICE message indicating no results found.

SELECT * 
FROM public.films_in_stock_by_title('%love%');
-- Returns a list of films whose titles contain "love" (case-insensitive)
-- and have at least one available copy in stock.

SELECT * 
FROM public.films_in_stock_by_title('%notexistent%');
-- Since no film titles match this pattern, the query returns no rows.
-- The function handles this by raising a NOTICE message indicating that
-- no films were found or no copies are available in stock.

-------------------------------------------------------------------------------------------------

--------------
-- Task 5
--------------

CREATE OR REPLACE FUNCTION public.new_movie(
    p_title TEXT,
    p_language TEXT DEFAULT 'Klingon',
    p_release_year INT DEFAULT EXTRACT(YEAR FROM CURRENT_DATE)
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_language_id INT;
BEGIN
    -- Validate title
    IF p_title IS NULL OR TRIM(p_title) = '' THEN
        RAISE EXCEPTION 'Movie title cannot be NULL or empty';
    END IF;
    -- Prevent duplicates
    IF EXISTS (
        SELECT 1
        FROM public.film f
        WHERE UPPER(f.title) = UPPER(p_title)
    ) THEN
        RAISE EXCEPTION 'Movie with this title already exists';
    END IF;
    -- Check if language exists
    SELECT l.language_id
    INTO v_language_id
    FROM public.language l
    WHERE UPPER(l."name") = UPPER(p_language);
    -- If language does NOT exist we insert it
    IF v_language_id IS NULL THEN
        INSERT INTO public.language("name")
        VALUES (p_language)
        RETURNING language_id INTO v_language_id;
    END IF;
    -- Insert new movie
    INSERT INTO public.film (
        title,
        release_year,
        language_id,
        rental_duration,
        rental_rate,
        replacement_cost
    )
    VALUES (
        p_title,
        p_release_year,
        v_language_id,
        3,
        4.99,
        19.99
    );
END;
$$;

-- The film_id is generated automatically by the database (serial/auto-increment),
-- so no manual handling is required in the function.

-- Before inserting, the function checks if a movie with the same title already exists
-- using IF EXISTS and WHERE UPPER(f.title) = UPPER(p_title). 

-- If movie already exists:
-- The function stops execution and raises an exception,
-- preventing duplicate records from being inserted.

-- The function checks whether the given language exists in the language table.
-- If it does not exist, a new language record is inserted and its ID is used.

-- If insertion fails:
-- PostgreSQL automatically rolls back the transaction if an error occurs,
-- so no partial or incorrect data is saved.

-- Consistency preservation:
-- The function ensures data integrity by validating inputs, preventing duplicates,
-- and maintaining correct relationships before inserting.

SELECT public.new_movie('My New Film');
-- Valid input: inserts a new movie with default language ('Klingon') and current year

SELECT *
FROM public.film
WHERE title = 'My New Film';
-- Checks that the movie was successfully inserted

SELECT public.new_movie('My New Film');
-- Running this again, will RAISE EXCEPTION that movie with this tile already exists

SELECT public.new_movie('');
-- RISES EXCEPTION that movie title cannot be NULL or empty

SELECT public.new_movie('Another Film', 'Georgian');
-- Inserts movie and also inserts 'Georgian' into language table as it does not exist

SELECT *
FROM public.language
WHERE name = 'Georgian';
-- Checks that the new language was added

SELECT *
FROM public.film
WHERE title = 'Another Film';
-- Confirms the movie was inserted with the new language

--------------------------------------------------------------------------------------------------------------------

