-- -- Netflix Project
DROP TABLE IF EXISTS netflix;
CREATE TABLE netflix
(
	show_id VARCHAR(6) ,
	type VARCHAR (10) ,
	title VARCHAR( 150) ,
	director VARCHAR(208) ,
	casts VARCHAR (1000) ,
	country VARCHAR (150) ,
	date_added VARCHAR (50) ,
	release_year INT,
	rating VARCHAR(10),
	duration VARCHAR (15) ,
	listed_in VARCHAR (100) ,
	description VARCHAR (250)
);

SELECT * FROM netflix LIMIT 5;

-- I. EDA
-- Overview of the Table
SELECT * FROM netflix LIMIT 5;

-- Total Movies and TV Shows: 8807
SELECT COUNT(*) AS total_content FROM netflix; 

-- Problems & Solutions

-------------------------------------------------------------------------------
-- 1. Count the Number of Movies vs TV Shows
-- Rename, Group By
SELECT 
    type, COUNT(*) AS total_count
FROM netflix
GROUP BY type;
-- Result: There are 6131 Movies and 2617 TV Shows

-------------------------------------------------------------------------------
-- 2. Find the Most Common Rating for Movies and TV Shows
-- Window Function, Subquery
SELECT 
    type, rating, rating_count 
FROM (
    SELECT 
        type, 
        rating, 
        COUNT(*) AS rating_count,
        RANK() OVER (PARTITION BY type ORDER BY COUNT(*) DESC) AS ranking
    FROM netflix
    GROUP BY 1, 2
) AS table_1
WHERE ranking = 1;
-- ORDER BY 1, 3 DESC;
-- Result: The most common rating for both Movies and TV Shows is TV-MA

-------------------------------------------------------------------------------
-- 3. List All Movies Released in the Year 2020
-- With Duration Greater Than One Hour
SELECT * FROM netflix
WHERE 
    release_year = 2020
    AND type = 'Movie';

-------------------------------------------------------------------------------
-- 4. Find the Top 5 Countries with the Most Content on Netflix
SELECT 
	country, COUNT(title) AS content_counts
FROM netflix
WHERE country <> 'null'
GROUP BY 1
ORDER BY 2 DESC;
/* Problem: There are movies with mupltiple  originated countries 
e.g. line 19: United Kingdom, United States
Solution: 
- Use STRING_TO_ARRAY function to convert the strings into array, seperate by the comma.
- Use unnest to returns multiple rows for each element of the array */
SELECT 
	UNNEST(STRING_TO_ARRAY(country, ',')) as new_country, 
	COUNT(title) AS content_counts
FROM netflix
WHERE country <> 'null'
GROUP BY 1
ORDER BY 2 DESC
LIMIT 5;
/* Result: The majority of the movies came from the US, which is greater than the 
combination of the other top 4 */

-------------------------------------------------------------------------------
-- 5. Identify the longest movie and longest TV show
SELECT title, duration
FROM netflix
WHERE duration = (
	SELECT MAX(duration)
	FROM netflix
	WHERE 
		type = 'Movie'
		AND duration <> 'null');

-------------------------------------------------------------------------------
-- 6. Find content added in the last 5 years
-- Problem: the date_added's data type is a string , not date.
-- Solution: Convert date_added from string to DATE, then extract the year.

-- Add a new column for date added
ALTER TABLE netflix
ADD new_date_added DATE;

UPDATE netflix
SET new_date_added = TO_DATE(date_added, 'Month DD, YYYY');

SELECT * from netflix;

-- Now, we can check if the content added is within the last 5 years
SELECT title, duration_added
FROM (
	SELECT title, (CURRENT_DATE - new_date_added)/ 365 as duration_added
	FROM netflix)
WHERE duration_added < 5;

-------------------------------------------------------------------------------
-- 7. Find all the movies/TV shows by director 'Rajiv Chilaka'
-- Problem: One movie can have multiple directors 
SELECT title 
FROM netflix
WHERE director = 'Rajiv Chilaka';

-- Solution: Use LIKE exists
SELECT title, director
FROM netflix
WHERE director LIKE '%Rajiv Chilaka%';


-------------------------------------------------------------------------------
-- 8. List all TV shows with more than 5 seasons
-- Problem: The duration is in text, hence ca not be compared
-- Solution: Extract the number from Season using split_part function
SELECT title, seasons FROM (
	SELECT title, duration, CAST(SPLIT_PART(duration,' ',1) as seasons
	FROM netflix
	WHERE 
		type = 'TV Show'
	) 
WHERE seasons > 5;

-------------------------------------------------------------------------------
-- 9. Count the number of content items in each genre
SELECT
	UNNEST (STRING_TO_ARRAY (listed_in, ',')) as genre,
	COUNT (show_id) as total_content
FROM netflix
GROUP BY 1
ORDER BY 2 DESC;

-------------------------------------------------------------------------------
-- 10. Find the average release year for content produced in a specific country.
-- Illustrate the yearly content contribution in percentage, round up to 2 d.p.
-- and order by the weight of contribtuion.
	
SELECT
	EXTRACT (YEAR FROM TO_DATE (date_added, 'Month DD, YYYY')) as year,
	COUNT (*) as yearly_content,
	ROUND (
		COUNT (*):: numeric/(
			SELECT COUNT(*) FROM netflix WHERE country = 'India'):: numeric * 100,2) 
			as avg_content_per_year
FROM netflix
WHERE country = 'India'
GROUP BY 1
ORDER BY 3 DESC;


-- 11. List all movies that listed in documentaries along with other categories
SELECT title, listed_in
FROM netflix
WHERE title NOT IN (
	SELECT title 
	FROM netflix
	WHERE listed_in ILIKE 'documentaries')
AND listed_in ILIKE '%documentaries%';

-- 12. Find all content items without a director, and group them by content type (Movie or TV Show). 
-- Then, for each group, calculate the percentage of content that has no listed director, format
-- the reuslt as standard percentage fomat (e.g. 100.00%)

WITH cte_no_movie AS(
	SELECT 
		type, 
		count(*) FILTER(WHERE director IS NULL) as count_no_dir,
		count(*) as total
	FROM netflix
	GROUP BY 1)
SELECT 
	type, count_no_dir, total, 
	CAST(
		ROUND((count_no_dir::numeric / total * 100),2) AS VARCHAR)|| '%' as no_dir_percentage
FROM cte_no_movie;

-- 13. Find how many movies actor 'Salman Khan' appeared in last 10 years!
SELECT sum(count_khan) as khan_appearance
FROM(
	SELECT title, casts, new_date_added,
		COUNT(*)as count_khan
	FROM netflix
	WHERE casts ILIKE '%Salman Khan%'
	AND DATE_PART('year', NOW())  - DATE_PART('year', new_date_added) < 10
	GROUP BY 1,2,3
	);

-- 14. Find the top 10 actors who have appeared in the highest number of movies produced
SELECT single_cast, count(*) as appearances FROM (
	SELECT 
		title, 
		UNNEST(STRING_TO_ARRAY(casts, ',')) as single_cast
	FROM netflix) single_cast_table
GROUP BY 1
ORDER BY 2 DESC
LIMIT 10;
----------------------------------------------------------------------


-- 15.Categorize the content based on the presence of the keywords 'kill' and 'violence' in
-- the description field. Label content containing these keywords as '18+' and all other
-- content as 'Good'. Count how many items fall into each category.
WITH new_cte AS(
	SELECT
		CASE
			WHEN description ILIKE '%kill%' OR description ILIKE'%violence%' THEN 'Violence Content'
			WHEN description ILIKE '%sex%'THEN '18+ Content'
			ELSE 'Normal Content'
		END category
	FROM netflix)
SELECT 
	category, 
	count(*) as category_count
FROM new_cte
GROUP BY 1
ORDER BY 2 DESC;
