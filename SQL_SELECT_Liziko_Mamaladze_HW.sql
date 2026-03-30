
-- Part 1 / Task 1 
-------------------------------------------------------------------------------------------------------
-- Find animation movies released between 2017 and 2019
-- with rental_rate > 1, sorted alphabetically
-------------------------------------------------------------

-- Assumptions:
-- 1. The condition "rate more than 1" refers to the column film.rental_rate, (since film.rating is categorical, not numeric).
-- 2. The release period "between 2017 and 2019" is interpreted as inclusive, meaning release_year >= 2017 AND release_year <= 2019
-- 3. Family-friendly movies are G , PG and PG-13

-- Task's Business Logic:
-- The solution is based on identifying relevant films through their relationships
-- with categories, using the linking table between films and categories.

-- The solution requires combining data from multiple related tables:
-- film (contains movie details such as title, release_year, rental_rate)
-- film_category (maps films to categories)
-- category (provides category names)

--------------------------------------------------------------
-- JOIN Solution
--------------------------------------------------------------

-- Advantages:
-- Easy to understand once you know how tables are connected.
-- Everything is in one place, so you don’t have to jump between multiple queries. 
-- Usually faster because databases are optimized for JOINs. (True for all task JOIN solutions)
-- Good when working with related tables (like film and category).

-- Disadvantages:
-- Can get messy and hard to read if there are too many JOINs.
-- Need to clearly understand how tables relate, otherwise it’s confusing.
-- Easy to make mistakes (wrong joins or duplicate rows).
-- Not very step-by-step, everything happens at once.

-- Starting with film table i connected it to category table by brdge table film_category.
-- INNER JOIN is used to return only films that have a matching 'Animation' category.
-- Than the joined table is filtered by multiple conditions and sorted alphabetically
-- IN chechk if f.rating matches any value in the list ('G', 'PG', 'PG-13'),
-- it works like multiple OR conditions


SELECT f.title ,
	   f.release_year ,
	   f.rental_rate 
FROM public.film f 
	INNER JOIN public.film_category fc ON f.film_id = fc.film_id 
	INNER JOIN public.category c ON fc.category_id = c.category_id 
WHERE f.release_year >= 2017 
	AND f.release_year <= 2019 
	AND f.rental_rate > 1 
	AND f.rating IN ('G', 'PG', 'PG-13')
	AND UPPER(c.name) = 'ANIMATION' 
ORDER BY f.title ;


-----------------------------------------------------------
-- Subquery Solution
-----------------------------------------------------------

-- Advantages:
-- Feels more natural to read.
-- Breaks the problem into steps, so it’s easier to think through.
-- Good when filtering based on results from another query.
-- Avoids hardcoding IDs.

-- Disadvantages:
-- Can get confusing when there are multiple nested subqueries.
-- Harder to follow compared to JOIN when working with many tables.
-- Can be slower, especially if the subquery runs multiple times.
-- Checking, is not as easy because logic is split between inner and outer queries.

-- I used a subquery to first find all film_ids that belong to the 'Animation' category.
-- Then, I used those results to filter the main film table and applied
-- additional conditions such as release year and rental rate.
-- IN is used because the subquery returns multiple film_ids (a list).
-- = is used when the subquery returns a single value (one category_id).


SELECT f.title, 
	   f.release_year,
	   f.rental_rate
FROM public.film f 
WHERE f.release_year >= 2017 
    AND f.release_year <=2019
	AND f.rental_rate > 1
	AND f.rating IN ('G', 'PG', 'PG-13')
	AND f.film_id IN (
			SELECT film_id
			FROM public.film_category 
			WHERE category_id = (
					SELECT category_id
					FROM public.category c 
					WHERE upper(c.name) = 'ANIMATION' )  )				
ORDER BY f.title ;				


---------------------------------------------------------
-- CTE Solution
---------------------------------------------------------

-- Advantages:
-- Very easy to read because it’s step-by-step.
-- Logic is separated, so it’s easier.
-- Good for more complex queries where things would get messy.
-- Feels more organized than subqueries and JOINS

-- Disadvantages:
-- Slightly more lines of code.
-- Can feel unnecessary for simple queries.
-- Sometimes not as fast as JOIN in simple cases.

-- I used a CTE to first get films in the 'Animation' category,
-- and then used that result to filter the main film table.


WITH animation_films AS (   
	SELECT fc.film_id
    FROM public.film_category fc
    	INNER JOIN public.category c ON fc.category_id = c.category_id
    WHERE upper(c.name) = 'ANIMATION'   ) 
SELECT f.title ,
	   f.release_year ,
	   f.rental_rate 
FROM public.film f 
	INNER JOIN animation_films af ON f.film_id = af.film_id
WHERE f.release_year >= 2017 
	AND f.release_year <= 2019
	AND f.rental_rate > 1 
	AND f.rating IN ('G', 'PG', 'PG-13')
ORDER BY f.title ;


-- Preferred solution:
-- For this task I would choose the JOIN solution because it is more efficient and faster to write 
-- and in this case it still remains readable.

---------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------
-- Part 1 / Task 2 
---------------------------------------------------------------------------------------------------------------
-- Generate a report showing how much revenue each store generated
-- after March 2017 (since april), including store address information combined
-- into a single column.
---------------------------------------------------------------------------------

-- Assumptions:
-- Revenue is calculated using the payment.amount column.
-- Each payment is linked to a rental, which is linked to inventory and then to a store.
-- If address2 is NULL, it is ignored and treated as empty.

-- Task's Business Logic:
-- The idea is to take each payment and figure out which store it belongs to
-- by following the relationships between tables (payment - rental - inventory - store - adress). Once each payment is linked
-- to a store, all payments for the same store are grouped together and summed
-- to get total revenue.
-- This way, we move from individual transactions to a store-level view,
-- which makes it easier to compare how each store is performing.


---------------------------------------------------------
-- JOIN Solution
---------------------------------------------------------

-- Advantages:
-- Easy to follow how data flows, since multiple related tables need to be combined.
-- Makes aggregation (SUM and GROUP BY) straightforward since all data is already joined together.

-- Disadvantages:
-- Can become hard to read if too many tables are joined and compared to Task 1 this is more so requires more observation.
-- Requires a good understanding of how tables are related, otherwise it’s confusing.

-- I started from the payment table because it contains the revenue data (amount) and that is what we want to look for mainly. 
-- Then I joined related tables step by step to connect each payment to a store and its address.
-- I used SUM to calculate total revenue and GROUP BY to aggregate it per store.
-- COALESCE was used to safely combine address fields when address2 is NULL.
-- Finally, I sorted the results to easily compare store performance.


SELECT (a.address || ' ' || coalesce(a.address2, ' ')) AS full_adress,
	   sum(p.amount) AS revenue
FROM public.payment p
	INNER JOIN public.rental r ON p.rental_id = r.rental_id 
	INNER JOIN public.inventory i ON r.inventory_id = i.inventory_id 
	INNER JOIN public.store s ON i.store_id = s.store_id 
	INNER JOIN public.address a ON s.address_id = a.address_id 
WHERE p.payment_date >= '2017-04-01' 
GROUP BY full_adress 
ORDER BY revenue DESC ;


----------------------------------------------------------
-- Subquery Solution
----------------------------------------------------------

-- Advantages:
-- More step-by-step: each store’s revenue is calculated independently, which is easier.
-- Separates logic, the main query handles stores, while the subquery handles revenue calculation.
-- Avoids grouping in the main query, which can simplify the outer query structure.

-- Disadvantages:
-- Higher logical complexity.
-- Can be less efficient as the subquery may run once per store.
-- Performance can degrade with larger datasets compared to JOIN + GROUP BY.

-- Chose the store table first because the goal is to calculate revenue per store.
-- Then I used a subquery to calculate total revenue for each store separately.
-- Inside the subquery, I connected payments to the store through related tables which, made it into a correlated subquery.
-- This separates the calculation logic from the main query and keeps it more consistent.


SELECT (a.address || ' ' || coalesce(a.address2, ' ')) AS full_address , 
	   ( 
			SELECT sum(p.amount)
			FROM public.payment p 
				INNER JOIN public.rental r ON p.rental_id = r.rental_id 
				INNER JOIN public.inventory i ON r.inventory_id = i.inventory_id 
			WHERE i.store_id = s.store_id
				AND p.payment_date >= '2017-04-01'   ) AS revenue
FROM public.store s 
	INNER JOIN public.address a ON s.address_id = a.address_id 
ORDER BY revenue ;


-----------------------------------------------------------
-- CTE Solution
-----------------------------------------------------------

-- Advantages:
-- Very clear structure, first calculate revenue, then attach store details.
-- Easier to read because aggregation is separated from joins.

-- Disadvantages:
-- Slightly more lines of code.
-- May be slower than other two.
-- Can feel unnecessary for simpler queries.

-- I used a CTE to first calculate total revenue per store,
-- and then joined that created temporary table with store and address tables.


WITH store_revenue AS (
	 SELECT i.store_id ,
	 		sum(p.amount) AS revenue
	 FROM public.payment p 
	 	INNER JOIN public.rental r ON p.rental_id = r.rental_id 
	 	INNER JOIN public.inventory i ON r.inventory_id = i.inventory_id
	 WHERE p.payment_date >= '2017-04-01'
	 GROUP BY i.store_id   )
SELECT (a.address || ' ' || coalesce(a.address2, ' ')) AS full_address, 
	   sr.revenue
FROM store_revenue sr
	INNER JOIN public.store s ON sr.store_id = s.store_id 
	INNER JOIN public.address a ON s.address_id = a.address_id 
ORDER BY sr.revenue ;


-- Preferred solution:
-- I would use the CTE solution because it clearly separates the logic,
-- making it easier to read, maintain, and correct if necessary.

--------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------
-- Part 1 / Task 3
--------------------------------------------------------------------------------------------------------
-- Identifying the most active actors by counting how many movies they appeared in
-- since 2015, and displaying the top 5 based on that count.
--------------------------------------------------------------------

-- Assumptions:
-- Movie participation is determined through the film_actor table.
-- Each appearance of an actor in a film is counted once.
-- Movies released in 2015 and later are counted. 

-- Task's Business Logic:
-- The approach is to connect actors to films using the linking table - film_actor
-- and then filter films based on release year.
-- After identifying relevant records, and counting 
-- how many films each one has participated in,
-- the results are sorted to highlight the most active actors,
-- therefore, making it easier to identify top performers.

-----------------------------------------------------------------------
-- JOIN Solution
-----------------------------------------------------------------------

-- Advantages:
-- Works very naturally for counting how many films each actor has, since JOIN + GROUP BY fits this type of aggregation well.
-- Makes it easy to apply filtering (by release_year) before counting, so only relevant films are included.
-- Clear connection between actors and their films, which helps understand how participation is counted.

-- Disadvantages:
-- Requires careful grouping logic to ensure counts are accurate and avoids duplicates.
-- Not very modular, since filtering, joining, counting, and ranking are all done in one query.

-- I started from the actor table since the goal is to analyze actors.
-- Then I joined the film_actor bridge table to connect each actor to the films they participated in,
-- and joined the film table to access film details like release_year.
-- After filtering films by release year, I grouped the data by actor
-- to count how many films each actor appeared in.
-- Grouping by actor_id is sufficient because it uniquely identifies each actor and determines their name 
-- as it is a primary key of the table actor.
-- However, I included first_name and last_name in the GROUP BY clause for clarity and to follow standard rules.


SELECT a.first_name ,
	   a.last_name ,
	   count(f.film_id) AS number_of_movies
FROM public.actor a 
	INNER JOIN public.film_actor fa on a.actor_id = fa.actor_id 
	INNER JOIN public.film f ON fa.film_id = f.film_id
WHERE f.release_year >= 2015
GROUP BY a.actor_id , a.first_name , a.last_name 
ORDER BY number_of_movies DESC 
LIMIT 5 ;


--------------------------------------------------------------------------
-- Subquery Solution
--------------------------------------------------------------------------

-- Advantages:
-- Matches the logic of the task well: “for each actor, count their films”.
-- Keeps the counting logic separate from the main query, making it easier to follow step-by-step.
-- No need for GROUP BY in the main query.

-- Disadvantages:
-- Can be slower because the subquery runs once for each actor
-- Less efficient than JOIN for aggregation tasks on larger datasets.

-- Started from the actor table to evaluate each actor individually.
-- Then I used a subquery in the SELECT clause to calculate the number of films per actor,
-- since this is a value that needs to be computed for each row in the result.
-- I chose a correlated subquery because the calculation depends on the current actor,
-- so the subquery uses a.actor_id to count only the films for that specific actor.
-- This approach allows me to keep the main query focused on actors,
-- while the subquery handles the counting logic separately.


SELECT a.first_name ,
	   a.last_name ,
       (	
       		SELECT count (fa.film_id )
			FROM public.film_actor fa
				INNER JOIN public.film f ON fa.film_id = f.film_id 
			WHERE fa.actor_id = a.actor_id
			AND f.release_year >= 2015    ) AS number_of_movies
FROM public.actor a 
ORDER BY number_of_movies DESC
LIMIT 5 ;


---------------------------------------------------------------------------
-- CTE Solution
---------------------------------------------------------------------------

-- Advantages:
-- Very clear structure: first calculate movie counts, then attach actor details.
-- Easier to understand compared to subqueries.
-- Reduces complication in understanding by separating aggregation from final query.

-- Disadvantages:
-- Slightly longer and takes more time to write.
-- Can use more memory.

-- Used CTE to calculate the number of movies per actor
-- by grouping data in the film_actor and film tables.
-- Then I joined this result with the actor table to get actor names,
-- which separates the counting logic from the final selection,
-- making the query easier to read and understand.


WITH actor_movie_count AS 
	(	
		SELECT fa.actor_id ,
			   count(f.film_id) AS number_of_movies
		FROM public.film_actor fa 
			INNER JOIN public.film f ON fa.film_id = f.film_id 
		WHERE f.release_year >= 2015
		GROUP BY fa.actor_id   )
SELECT a.first_name ,
	   a.last_name ,   
	   amc.number_of_movies
FROM actor_movie_count amc
	INNER JOIN public.actor a ON amc.actor_id = a.actor_id 
ORDER BY amc.number_of_movies DESC 
LIMIT 5 ;


-- Preferred solution:
-- I would choose the CTE solution.
-- This makes the query easier to read and understand, especially for this task,
-- where counting and ranking are the main focus.
-- It also avoids mixing aggregation with multiple joins in a single step, making it easier to maintain.

-------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------
-- Part 1 / Task 4 
-------------------------------------------------------------------------------------------------------
-- Analyze how many films were produced each year for specific genres
-- (Drama, Travel, Documentary) in order to observe trends over time.
-- including columns: release_year, number_of_drama_movies, number_of_travel_movies, number_of_documentary_movies), 
-- sorted by release year in descending order
------------------------------------------------------------

-- Assumptions:
-- Film categories are identified through the category and film_category tables.
-- Each film has one category.
-- If a category has no films in a given year, the count may appear as 0.
-- Categories are identified by name.

-- Business Logic:
-- The approach is to connect films with their categories and organize them by year.
-- Then, for each year, films are counted separately for each category using conditional logic.
-- This transforms the data into a year-by-year view, where each category is shown
-- as a separate column, making it easier to compare trends across genres.

------------------------------------------------------------
-- JOIN Solution 
------------------------------------------------------------

-- Advantages:
-- Efficient because all three category counts are calculated in one query without repeating joins.
-- Logical flow is clear: group by year, then apply conditions for each genre.
-- Avoids running multiple queries or subqueries for each category, which saves time.

-- Disadvantages:
-- Query becomes less readable as more categories are added

-- I started from the category table because the task is focused on specific genres.
-- Then I joined film_category and film to connect each category to its films
-- and access the release year.
-- I used CASE WHEN with THEN 1 to mark rows that match each category.
-- If the condition is not met, NULL is returned, and COUNT ignores NULL values,
-- allowing me to count only the relevant rows.
-- I used UPPER() to ensure case-insensitive comparison of category names.
-- Finally, I sorted the goruped results by year in descending order for easier analysis.


SELECT f.release_year ,
	   count(CASE WHEN upper(c."name") = 'DRAMA' THEN 1 END) AS number_of_drama_movies ,
	   count(CASE WHEN upper(c."name") = 'TRAVEL' THEN 1 END) AS number_of_travel_movies ,
	   count(CASE WHEN upper(c."name") = 'DOCUMENTARY' THEN 1 END) AS number_of_documentary_movies
FROM public.category c
	INNER JOIN public.film_category fc ON c.category_id = fc.category_id 
	INNER JOIN public.film f ON fc.film_id = f.film_id 
GROUP BY f.release_year 
ORDER BY f.release_year DESC 


--------------------------------------------------------------
- Subquery Solution
--------------------------------------------------------------

-- Advantages:
-- Avoids repeating joins and conditions by preparing data once in the subquery,
-- (could have done it with three subqueries each for each category but would have had repeated logic.)
-- Makes aggregation cleaner since the outer query works on a simplified dataset.
-- Same logic as JOIN solution but would be better if more conditions were added.

-- Disadvantages:
-- Slightly less direct in this case, than a JOIN query since logic is split into two layers.

-- I used a subquery in the FROM clause to first create a dataset
-- that links each film’s release year with its category.
-- This allows me to prepare the data in a structured way before aggregation.
-- Then, in the outer query, I applied conditional aggregation (same as in JOIN)  to count
-- how many films belong to each category per year.
-- This approach avoids repeating joins and keeps the aggregation logic seperate.

SELECT cy.release_year ,
	   count(CASE WHEN upper(cy."name") = 'DRAMA' THEN 1 END) AS number_of_drama_movies ,
	   count(CASE WHEN upper(cy."name") = 'TRAVEL' THEN 1 END) AS number_of_travel_movies ,
	   count(CASE WHEN upper(cy."name") = 'DOCUMENTARY' THEN 1 END) AS number_of_documentary_movies
FROM (  
		SELECT f.release_year ,
			   c."name"
		FROM public.category c 
			INNER JOIN public.film_category fc ON c.category_id = fc.category_id
			INNER JOIN public.film f ON fc.film_id = f.film_id   ) AS cy
GROUP BY cy.release_year 
ORDER BY cy.release_year DESC ;


--------------------------------------------------------------
-- CTE Solution
--------------------------------------------------------------

-- Advantages:
-- Easier to read and understand compared to nested subqueries.
-- Improves maintainability, especially if the query becomes more complex.
-- Easier to debug since the CTE can be run independently.

-- Disadvantages:
-- For simple transformations like this, the CTE does not significantly improve performance
-- and mainly serves readability purposes

-- Transformed same subquery in previous solution into a CTE, which is useful and easier to understand. 
-- This separates the data preparation step from the aggregation step,
-- making the query easier to read and follow.

WITH category_year AS (
	SELECT f.release_year ,
		   c."name" 
	FROM public.category c 
		INNER JOIN public.film_category fc ON c.category_id = fc.category_id
		INNER JOIN public.film f ON fc.film_id = f.film_id   )
SELECT cy.release_year ,
	   count(CASE WHEN upper(cy."name") = 'DRAMA' THEN 1 END) AS number_of_drama_movies ,
	   count(CASE WHEN upper(cy."name") = 'TRAVEL' THEN 1 END) AS number_of_travel_movies ,
	   count(CASE WHEN upper(cy."name") = 'DOCUMENTARY' THEN 1 END) AS number_of_documentary_movies
FROM category_year cy
GROUP BY cy.release_year
ORDER BY cy.release_year DESC ;


-- Preferred solution:
-- I would choose the CTE solution because it clearly separates
-- data preparation from aggregation, making the query easier to read
-- and maintain. As it is practically same solution as the other two, this way is more
-- structured and in a more understanding order.


-------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------
-- Part 2 / Task 1
-------------------------------------------------------------------------------------------------------
-- Identify the top 3 employees based on the revenue they generated in 2017 in a store they last worked in.
-------------------------------------------------------------------------------------------------------

-- Assumptions:
-- staff could work in several stores in a year, please indicate which store the staff worked in (the last one);
-- if staff processed the payment then he works in the same store; 
-- take into account only payment_date

-- Business Logic:
-- The approach is to evaluate each employee’s contribution based on payment data,
-- since it directly reflects revenue generation.
-- For each employee, the most recent activity in 2017 is identified using last payment_date,
-- and the store associated with that activity is treated as the employee’s last store.
-- Stores associated with each payment that is for each rental. is found through
-- connecting tables from rental - inventory - staff (thrrough store_id) and to payment.
-- Revenue is then calculated only for that store and it's employee.
-- The results are then ranked to identify the top 3 employees.

----------------------------------------------------------
-- JOIN Solution
----------------------------------------------------------

-- It is not possible to correctly implement this task using only JOIN operations.

-- The requirement to determine each employee’s last store based on their latest
-- payment in 2017 involves comparing rows within the same group (staff),
-- which is a "top 1 per group" problem.

-- Using only JOINs i cannot compare aggregated results within the same group.
-- In this case, we need to:
-- 1. Identify the latest payment per employee
-- 2. Use that to determine the corresponding store
-- 3. Then aggregate revenue based on that store and employee

-- This cannot be achieved using only JOINs without subqueries or CTEs.
-- Therefore, a correct solution will be implemented using subqueries and CTEs,
-- which allow step-by-step data preparation and proper filtering.

----------------------------------------------------------------------------------
-- Subquery Solution
----------------------------------------------------------------------------------

-- Advantages:
-- Accurately identifies the last store per employee using row-by-row comparison.
-- Handles ties reliably by using MAX(payment_id).
-- Ensures each employee appears only once in the result.
-- Keeps logic precise without needing additional grouping complexity.

-- Disadvantages:
-- Correlated subqueries run once per row, which can be less efficient on large datasets
-- took 5 minutes to give the result so it is slow and would be slower on larger data.
-- Harder to read and understand compared to CTE solutions.
-- Debugging can be more difficult because the logic is evaluated repeatedly per row.

-- I started from the payment table because it contains revenue data (amount and payment_date),
-- and joined it with rental and inventory to correctly determine the store where each transaction occurred.
-- The staff table is joined to associate each payment with an employee.

-- To identify each employee’s last store, I used a correlated subquery.
-- A correlated subquery runs once for each row of the outer query and compares
-- the current row with aggregated results (in this case, the maximum payment_id per employee),
-- I used payment_id because as it appeared same employee had several payments with the exact same 
-- last payment_date, so using only MAX(payment_date) could return multiple rows. So I used MAX(payment_id) as extra tie-breaker
-- to ensure that only one final transaction is selected per employee.
-- So, the subquery:
--     SELECT MAX(p2.payment_id)
--     FROM payment p2
--     WHERE p2.staff_id = p1.staff_id
--       AND p2.payment_date in 2017
-- returns the latest payment_id for the same employee.

-- The outer query then keeps only the row where p1.payment_id matches this maximum value,
-- effectively identifying the last payment for each employee.

-- This result represents the employee’s last store, obtained through the
-- rental → inventory → store relationship.

-- After determining the last store, the outer query aggregates all payments
-- made by that employee in that store during 2017 using SUM(amount),
-- ensuring that the full revenue contribution is captured.

SELECT 
    s.first_name || ' ' || s.last_name AS full_name,
    i.store_id,
    sum(p.amount) AS revenue_contributed
FROM public.payment p
	INNER JOIN public.staff s ON p.staff_id = s.staff_id
	INNER JOIN public.rental r ON p.rental_id = r.rental_id
	INNER JOIN public.inventory i ON r.inventory_id = i.inventory_id
	INNER JOIN (
	    SELECT 
	        p1.staff_id,
	        i1.store_id
	    FROM public.payment p1
	    	INNER JOIN public.rental r1 ON p1.rental_id = r1.rental_id
	    	INNER JOIN public.inventory i1 ON r1.inventory_id = i1.inventory_id
	    WHERE p1.payment_id = (
	        SELECT max(p2.payment_id)
	        FROM public.payment p2
	        WHERE p2.staff_id = p1.staff_id
	        	AND EXTRACT(year FROM p2.payment_date) = '2017'   )     ) last_store
ON p.staff_id = last_store.staff_id
	AND i.store_id = last_store.store_id
WHERE EXTRACT(year FROM p.payment_date) = '2017'
GROUP BY s.staff_id, s.first_name, s.last_name, i.store_id
ORDER BY revenue_contributed DESC
LIMIT 3;


--------------------------------------------------------------------
- CTE Solution
--------------------------------------------------------------------

-- Advantages:
-- Clearly separates logic into steps, making the query easier to read and understand.
-- Avoids deep nesting of subqueries, improving readability.
-- Much faster to complete and see the result.
-- Easier to debug, since each CTE can be tested independently.
-- Makes complex logic more maintainable.

-- Disadvantages:
-- Slightly more code lines compared to subquery solutions.
-- Requires understanding of multiple query steps to follow the logic.

-- I used Common Table Expressions (CTEs) to break down the problem into
-- clear and logical steps, making the query easier to read and understand.

-- The first CTE (last_payment) identifies the last payment for each employee in 2017.
-- Since multiple payments can have the same payment_date,I still used MAX(payment_id)
-- that will be the referance for last store, employee worked in.
-- Therefore, the second CTE (last_store) determines that - the store associated with that last payment.
-- Which is done by joining payment with rental and inventory tables,
-- ensuring that the store is derived from the actual transaction.

-- In the main query, I join the original payment data with the last_store CTE
-- to include only payments made by each employee in their last store.

-- Finally, I aggregate the revenue using SUM(amount), ensuring that all payments
-- from that store in 2017 are included, and then rank employees to identify
-- the top performers.


WITH last_payment AS (
    SELECT p.staff_id,
           max(p.payment_id) AS last_payment_id
    FROM public.payment p
    WHERE EXTRACT(year FROM p.payment_date) = '2017'
    GROUP BY p.staff_id   
    ) ,
last_store AS (
    SELECT lp.staff_id,
           i.store_id
    FROM last_payment lp
	    INNER JOIN public.payment p ON lp.last_payment_id = p.payment_id
	    INNER JOIN public.rental r ON p.rental_id = r.rental_id
	    INNER JOIN public.inventory i ON r.inventory_id = i.inventory_id 
	    )
SELECT s.first_name || ' ' || s.last_name AS full_name,
       ls.store_id,
       sum(p.amount) AS revenue_contributed
FROM public.payment p
	INNER JOIN public.staff s ON p.staff_id = s.staff_id
	INNER JOIN public.rental r ON p.rental_id = r.rental_id
	INNER JOIN public.inventory i ON r.inventory_id = i.inventory_id
	INNER JOIN last_store ls ON p.staff_id = ls.staff_id
		AND i.store_id = ls.store_id
WHERE EXTRACT(year FROM p.payment_date) = '2017'
GROUP BY s.staff_id, s.first_name, s.last_name, ls.store_id
ORDER BY revenue_contributed DESC
LIMIT 3;

-- Preferred solution:
-- CTE solution is far more organized and easier to understand and follow. 
-- does not require complex correlated subqueries.
-- SIncethe task requires multiple logical steps:
-- identifying the last payment per employee, determining the corresponding store,
-- and then aggregating revenue based on that store.
-- The CTE structure allows these steps to be clearly separated,

--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
-- Part 2 / Task 2
--------------------------------------------------------------------------------------------
-- The goal of this task is to identify the top 5 most popular movies based on
-- how frequently they were rented and to describe their target audience
--------------------------------------------------------------------------------------------

-- Assumptions:
-- Movie popularity is measured by the number of rentals.
-- The film rating reflects the intended audience age group.

-- Business Logic:
-- The analysis is based on rental transactions, which represent actual
-- customer demand for movies.
-- Movies are linked to rentals through inventory records, ensuring that
-- each rental is correctly associated with a specific film.
-- Popularity is determined by counting how many times each movie was rented.
-- The target audience is derived from the film’s rating using the Motion
-- Picture Association classification, allowing each movie to be labled
-- to an expected age group.
-- Finally, movies are ranked by rental count to identify the top-performing titles.

--------------------------------------------------------
-- JOIN Solution
--------------------------------------------------------

-- Advantages:
-- Simple and efficient structure using direct joins between related tables.
-- Easy to understand data flow (film → inventory → rental).
-- Performs well since no additional processing steps are required.

-- Disadvantages:
-- Can become harder to manage if more conditions or calculations are added.
-- Relies on correct joins, incorrect joins may lead to duplicated counts.

-- I started from the film table to focus on movie-related information,
-- including title and rating.
-- I used INNER JOIN to connect film with inventory and rental tables,
-- because only movies that have been rented are relevant for this analysis.
-- The inventory table links films to their physical copies,
-- while the rental table represents actual customer transactions.
-- I used COUNT(rental_id) to measure how many times each movie was rented,
-- which represents its popularity.
-- A CASE statement was used to describe film ratings, 
-- like if this rating = '***' return 'text' in a related row of a column,
-- named expected_audiance. 
-- Finally, I grouped the data by film and rating to ensure correct aggregation,
-- and sorted the results to identify the top 5 most rented movies.

SELECT f.title ,
	   count(r.rental_id) AS rental_count ,
		CASE WHEN f.rating = 'G' THEN 'All ages admitted'
	    	 WHEN f.rating = 'PG' THEN 'Parental Guidance Suggested' 
	    	 WHEN f.rating = 'PG-13' THEN 'Parents Strongly Cautioned under 13'
	    	 WHEN f.rating = 'R' THEN '17+ or with parent'
	    	 WHEN f.rating = 'NC-17' THEN '18+ only'
	    END AS expected_audience
FROM public.film f 
	INNER JOIN public.inventory i ON f.film_id = i.film_id 
	INNER JOIN public.rental r ON i.inventory_id = r.inventory_id 
GROUP BY f.film_id , f.title 
ORDER BY rental_count DESC 
LIMIT 5 ;


---------------------------------------------------------------------
-- Subquery 
---------------------------------------------------------------------

-- Advantages:
-- Improves readability by isolating the rental calculation step.
-- Makes it easier to reuse or extend the aggregated result.
-- Reduces complexity in the main query.

-- Disadvantages:
-- Just slightly more complex than a direct JOIN solution.
-- May be less efficient if the subquery processes large datasets.
-- Adds an extra layer that may not be necessary for simpler tasks

-- I used a subquery to first calculate the number of rentals for each movie,
-- grouping by film to determine its popularity.
-- This result simplifies the main query by separating
-- the aggregation step from the final selection.
-- In GROUP BY used both film_id and title, even though only title is in SELECT,
-- this is to make sure no data is repeated.
-- In the outer query, I again used a CASE statement to describe each movie’s rating
-- and finally, the results were sorted to identify the top 5 most rented movies.


SELECT rc.title ,
	   rc.number_of_rentals ,
	   CASE WHEN rc.rating = 'G' THEN 'All ages admitted'
	    	WHEN rc.rating = 'PG' THEN 'Parental Guidance Suggested' 
	    	WHEN rc.rating = 'PG-13' THEN 'Parents Strongly Cautioned under 13'
	    	WHEN rc.rating = 'R' THEN '17+ or with parent'
	    	WHEN rc.rating = 'NC-17' THEN '18+ only'
	   END AS expected_audience
FROM (
	    SELECT 
	        f.title,
	        f.rating,
	        count(r.rental_id) AS number_of_rentals
	    FROM public.film f
		    INNER JOIN public.inventory i ON f.film_id = i.film_id
		    INNER JOIN public.rental r ON i.inventory_id = r.inventory_id
	    GROUP BY f.film_id, f.title, f.rating   ) rc
ORDER BY rc.number_of_rentals DESC
LIMIT 5;


-----------------------------------------------------------------
-- CTE Solution
-----------------------------------------------------------------

-- Advantages:
-- Easier to understand than subqueries.
-- Simplifies debugging by allowing each step to be tested independently.

-- Disadvantages:
-- Requires more to code, which can be unnecessary for this task. 

-- I used a CTE to first calculate the number of rentals per movie,
-- grouping films based on their rental activity.
-- Then in the main query, I selected from this prepared dataset and used a CASE statement
-- and finally sorted the results.

WITH rental_counts AS (
    SELECT f.film_id,
           f.title,
           f.rating,
           count(r.rental_id) AS number_of_rentals
    FROM public.film f
	    INNER JOIN public.inventory i ON f.film_id = i.film_id
	    INNER JOIN public.rental r ON i.inventory_id = r.inventory_id
    GROUP BY f.film_id, f.title, f.rating  
    )
SELECT rc.title,
	   rc.number_of_rentals,
	   CASE WHEN rc.rating = 'G' THEN 'All ages admitted'
	    	WHEN rc.rating = 'PG' THEN 'Parental Guidance Suggested' 
	    	WHEN rc.rating = 'PG-13' THEN 'Parents Strongly Cautioned under 13'
	    	WHEN rc.rating = 'R' THEN '17+ or with parent'
	    	WHEN rc.rating = 'NC-17' THEN '18+ only'
	   END AS expected_audience
FROM rental_counts rc
ORDER BY rc.number_of_rentals DESC
LIMIT 5;


-- Preferred Solution:
-- I would choose the JOIN solution as the preferred approach.
-- This is because it is simple, direct, and easy to understand.
-- All logic is handled in a single shorter query without additional layers,
-- which makes it more straightforward.


----------------------------------------------------------------------------------------------
-- Part 3 / V1
----------------------------------------------------------------------------------------------
-- The goal of this task is to analyze actors inactivity periods by measuring
-- how long it has been since their most recent film appearance.
-----------------------------------------------------------------------------------------------

-- Assumptions V1:
-- An actor’s activity is determined by the release year of the films they participated in.
-- The latest release_year represents the actor’s most recent appearance.
-- The current year is used as a reference point to measure inactivity.

-- Business Logic:
-- Actor activity is acquired from film participation history.
-- Each actor is linked to their films through the film_actor table,
-- allowing identification of all movies they appeared in.
-- The most recent activity is determined by selecting the maximum (latest) release_year
-- for each actor.
-- The inactivity period is calculated as the difference between the current year
-- and this latest release year.
-- Finally, actors are ranked by inactivity period to highlight those
-- with the longest gaps since their last appearance.

------------------------------------------------------------------------------------------------
-- JOIN Solution
-------------------------------------------------

-- Advantages:
-- Simple and efficient structure using direct joins.
-- Clearly shows relationship between actors and their films.
-- Easy to follow from top to bottom.
-- Uses aggregation (MAX) effectively to find latest activity.

-- Disadvantages :
-- Would not be able to handle more complex inactivity logic, for example,
-- if like multiple, older breaks would also was to consider.

-- I joined the actor and film tables using bridge table film_actor
-- to connect each actor with the films they participated in.
-- I used MAX(release_year) to identify the most recent film for each actor.
-- The inactivity period was calculated by subtracting this value
-- from the current year.
-- I used CAST(EXTRACT(YEAR FROM CURRENT_DATE) AS int) to ensure
-- consistent data types in the calculation
-- and finally, I grouped the results by actor to get one row per actor
-- and sorted them in descending order to highlight those with the longest inactivity.

SELECT  a.first_name || ' ' || a.last_name AS full_name ,
	    cast(EXTRACT(year FROM current_date) AS int) - max(f.release_year) AS inactivity_years
FROM public.actor a 
	INNER JOIN public.film_actor fa ON a.actor_id = fa.actor_id 
	INNER JOIN public.film f ON fa.film_id = f.film_id 
GROUP BY a.actor_id , a.first_name , a.last_name 
ORDER BY inactivity_years DESC ;


-----------------------------------------------------
-- Subquery Solution
-----------------------------------------------------

-- Advantages:
-- Separates logic per actor, making the calculation intuitive.
-- Avoids GROUP BY in the main query, simplifying the structure.
-- Eeasier to understand how it is subtracted to get the actor's inacticvity interval.

-- Disadvantages:
-- Can be harder to optimize compared to JOIN-based aggregation.
-- Less efficient due to repeated execution of the subquery.
-- Slightly less readable with correlated logic.

-- I started from the actor table to focus on each individual actor.
-- I used a correlated subquery to find the most recent film for each actor.
-- The WHERE clause inside the subquery:
-- fa.actor_id = a.actor_id
-- connects the subquery with the outer query.
-- It ensures that, for each actor in the outer query,
-- only their own films are considered in the subquery.
-- This makes the subquery "correlated", meaning it runs once for each row
-- of the outer query and uses that row’s actor_id as a filter.


SELECT a.first_name || ' ' || a.last_name AS full_name,
	   cast(EXTRACT(year FROM current_date) AS int) - (
	        	SELECT max(f.release_year)
	        	FROM public.film_actor fa
	        		INNER JOIN public.film f ON fa.film_id = f.film_id
	        	WHERE fa.actor_id = a.actor_id   ) AS inactivity_years
FROM public.actor a
ORDER BY inactivity_years DESC ;


---------------------------------------------------------
-- CTE Solution
---------------------------------------------------------

-- Advantages:
-- Clearly separates finding last activity from final calculation.
-- Shows task logic more clearly.
-- More maintainable if additional logic is added later.

-- Disadvantages:
-- May feel unnecessary for simple aggregation tasks.

-- In the first step (last_activity), I joined the actor, film_actor,
-- and film tables to connect each actor with their films and used
-- MAX(release_year) to identify their most recent appearance.
-- In the second step, I calculated the inactivity period by subtracting
-- the latest release year from the current year.
-- This structure makes the query easier to understand, as the aggregation
-- and calculation steps are separated.


WITH last_activity AS (
	    SELECT a.actor_id,
		       a.first_name,
		       a.last_name,
	           max(f.release_year) AS last_release_year
	    FROM public.actor a
	    	INNER JOIN public.film_actor fa ON a.actor_id = fa.actor_id
	    	INNER JOIN public.film f ON fa.film_id = f.film_id
	    GROUP BY a.actor_id, a.first_name, a.last_name  
	    )
SELECT first_name || ' ' || last_name AS full_name,
       cast(EXTRACT(year FROM current_date) AS int) - last_release_year AS inactivity_years
FROM last_activity
ORDER BY inactivity_years DESC ;


-- Preferred Solution:
-- I would choose the JOIN solution as the preferred approach.
-- This is because the task only requires identifying the latest film per actor
-- and calculating inactivity, which can be done directly using aggregation.


--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
-- Part 3 / V2
--------------------------------------------------------------------------------------------
-- V2: gaps between sequential films per each actor;
-- Meaning, we need to sum up all the break periods (inactivity between movies) for each actor. 

-- Business Logic:
-- Is the same except the part, of calculating inactivity period, which for this version
-- each actor's, films are ordered by release year,
-- and the gaps between consecutive films are calculated.
-- These gaps represent periods of inactivity.
-- Then the total inactivity is calculated by summing all gaps per actor,
-- showing how much time they spent between film appearances.
----------------------------------------------------------------------------------------------
-- JOIN Solution 
-----------------------------------------------------------

-- It is not possible to correctly calculate total inactivity per actor
-- using only JOIN operations.

-- This is because the task requires two levels of aggregation:
-- first, identifying gaps between sequential films,
-- and second, summing those gaps per actor.

-- JOINs alone cannot handle multiple aggregation stages within a single query.

-- STEP 1: find gaps between sequential films
-- (requires grouping by actor + current film year)

-- SELECT a.actor_id,
--	     f1.release_year,
--	     MIN(f2.release_year) AS next_year
-- FROM public.actor a
-- INNER JOIN public.film_actor fa1 ON a.actor_id = fa1.actor_id
-- INNER JOIN public.film f1 ON fa1.film_id = f1.film_id
-- INNER JOIN public.film_actor fa2 ON a.actor_id = fa2.actor_id
-- INNER JOIN public.film f2 ON fa2.film_id = f2.film_id
--            AND f2.release_year > f1.release_year
-- GROUP BY a.actor_id, f1.release_year;

-- At this stage, we get ONE ROW PER GAP (multiple rows per actor)

-- STEP 2: we would need to SUM all gaps per actor:

-- But we cannot do this in the same query, because:
-- we would need another GROUP BY on actor_id only.

-- Therefore, a subquery or CTE is required to first compute individual gaps
-- and then aggregate them to obtain the final result.

-------------------------------------------------------------
-- Subqury Solution
-------------------------------------------------------------

-- Advantages:
-- Handles multi-step logic clearly without overcomplicating the main query.
-- More intuitive than trying to force everything into one JOIN query.
-- Provides accurate results by avoiding duplicate combinations.

-- Disadvantages:
-- Less readable compared to step-by-step CTE solution.
-- Self-joins make it more complicated to understand.

-- I used a subquery to first calculate the gaps between sequential films
-- for each actor.
-- This was done by joining the film table to itself and selecting
-- the next film using MIN(release_year) where the year is greater
-- than the current film.
-- The subquery returns one row per gap (per actor and film).
-- Showing one movie year, paired with the next upcomming movie year,
-- which gaps then are summed for each actor to calculate
-- the total inactivity period.
-- Finally, I grouped the results by actor and sorted them to identify
-- those with the longest total inactivity.


SELECT a.first_name || ' ' || a.last_name AS full_name ,
       sum(g.next_year - g.current_year) AS total_inactivity_years
FROM (
	    SELECT a.actor_id ,
		       f1.release_year AS current_year ,
		       min(f2.release_year) AS next_year
		FROM public.actor a 
			INNER JOIN public.film_actor fa1 ON a.actor_id = fa1.actor_id 
			INNER JOIN public.film f1 ON fa1.film_id = f1.film_id 
			INNER JOIN public.film_actor fa2 ON a.actor_id = fa2.actor_id 
			INNER JOIN public.film f2 ON fa2.film_id = f2.film_id 
				AND f2.release_year > f1.release_year 
		GROUP BY a.actor_id , f1.release_year 	 )  g 	 
INNER JOIN public.actor a ON g.actor_id = a.actor_id 
GROUP BY a.actor_id , a.first_name , a.last_name 
ORDER BY total_inactivity_years DESC ;


-----------------------------------------------------------
-- CTE Solution
-----------------------------------------------------------

-- Advantages:
-- Much easier to read and no need to repeat code.
-- Each step (pairs, gaps, total) can be validated independently.
-- Best suited for multi-stage calculations like this one.

-- Disadvantages:
-- Takes a little longer to write and complete.

-- I used CTEs to break down the problem into multiple logical steps.
-- In the first CTE (film_pairs), I identified, for each actor,
-- the current film and the next upcoming film using a self-join
-- and MIN(release_year).
-- In the second CTE (gaps), I calculated the inactivity gaps
-- between each paired years.
-- In the final query, I summed all gap values per actor
-- to obtain the total inactivity period.

WITH film_pairs AS (
	    SELECT a.actor_id,
	           f1.release_year AS current_year,
	           MIN(f2.release_year) AS next_year
	    FROM public.actor a
		    INNER JOIN public.film_actor fa1 ON a.actor_id = fa1.actor_id
		    INNER JOIN public.film f1 ON fa1.film_id = f1.film_id
		    INNER JOIN public.film_actor fa2  ON a.actor_id = fa2.actor_id
		    INNER JOIN public.film f2 ON fa2.film_id = f2.film_id
		       AND f2.release_year > f1.release_year
	    GROUP BY a.actor_id, f1.release_year
) ,
gaps AS (
	    SELECT actor_id,
	           next_year - current_year AS gap_years
	    FROM film_pairs
        )
SELECT a.first_name || ' ' || a.last_name AS full_name,
       SUM(g.gap_years) AS total_inactivity_years
FROM gaps g
	INNER JOIN public.actor a ON g.actor_id = a.actor_id
GROUP BY a.actor_id, a.first_name, a.last_name
ORDER BY total_inactivity_years DESC ;


-- Preferred Solution:
-- I would choose the CTE solution as the preferred approach.
-- This is because the task involves multiple logical steps,
-- so the CTE structure allows these steps to be separated clearly,
-- making the query easier to read and understand.

------------------------------------------------------------------------------------------------------------------------