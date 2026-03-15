--GENERAL EXPLORATORY ANALYSIS OF DATA

--total all time gifts and average gift amount 
SELECT sum(amount)::money AS "Total Gift Amount All Time", avg(amount)::money AS "Average All Time Gift Amount"
FROM gifts;

--date range of gifts
SELECT min(gift_date) AS "Date of Earliest Donation", max(gift_date) AS "Date of Most Recent Donation"
FROM gifts;
 
--total gift amounts broken down by type of gift
SELECT gift_type AS "Type of Gift", SUM(amount)::money AS "Total Gift Amount"
FROM gifts 
GROUP BY gift_type
ORDER BY "Total Gift Amount" DESC;

--total gift amounts broken down by major of alumni donors
SELECT c.major AS "Major", SUM(g.AMOUNT)::money AS "Total Gift Amount"
FROM gifts AS g
LEFT JOIN (SELECT constituent_id, degree, major
FROM CONSTITUENTS) AS c
ON g.CONSTITUENT_ID = c.CONSTITUENT_ID 
GROUP BY c.MAJOR
ORDER BY "Total Gift Amount" DESC;

--total gift amounts broken down by degree of alumni donors
SELECT c.DEGREE AS "Degree", SUM(g.AMOUNT)::money AS "Total Gift Amount"
FROM gifts AS g
LEFT JOIN (SELECT constituent_id, degree, major
FROM CONSTITUENTS) AS c
ON g.CONSTITUENT_ID = c.CONSTITUENT_ID 
GROUP BY c.degree
ORDER BY "Total Gift Amount" DESC

--total gift amounts broken down by age of alumni donors
SELECT (2026-c.birth_year) AS "Age", SUM(g.AMOUNT)::money AS "Total Gift Amount", COUNT(g.amount) AS "Number of Gifts"
FROM gifts AS g
LEFT JOIN (SELECT constituent_id, BIRTH_YEAR 
FROM CONSTITUENTS) AS c
ON g.CONSTITUENT_ID = c.CONSTITUENT_ID 
GROUP BY "Age"
ORDER BY "Total Gift Amount" DESC;

--extracting the count, mix, and max of ages (from previous results)
SELECT min(age), max(age), count(*)
FROM (SELECT (2026-c.birth_year) AS age, SUM(g.AMOUNT)::money AS total_amount
FROM gifts AS g
LEFT JOIN (SELECT constituent_id, BIRTH_YEAR 
FROM CONSTITUENTS) AS c
ON g.CONSTITUENT_ID = c.CONSTITUENT_ID 
GROUP BY age
ORDER BY total_amount DESC);

--Top 10 ages based on total amount gifts given
SELECT age AS "Age", total_amount AS "Total Gift Amount"
FROM (SELECT (2026-c.birth_year) AS age, SUM(g.AMOUNT)::money AS total_amount
FROM gifts AS g
LEFT JOIN (SELECT constituent_id, BIRTH_YEAR 
FROM CONSTITUENTS) AS c
ON g.CONSTITUENT_ID = c.CONSTITUENT_ID 
GROUP BY age
ORDER BY total_amount DESC
LIMIT 10)
ORDER BY age ASC;
	
--convert date column of gifts table from integer to date format
ALTER TABLE gifts
ALTER COLUMN gift_date TYPE DATE
USING (CAST(gift_date AS TEXT)::DATE);

--total amount of gifts since the beginning of the year
SELECT SUM(amount)::money AS "Total Gift Amount YTD"
FROM GIFTS
WHERE gift_date > '1/1/2026';

--average number of months since last gift
SELECT ROUND(AVG(days_since_last_gift)/30,0) AS "Average Number of Months Since Last Gift"
FROM (SELECT c.constituent_id, CURRENT_DATE - MAX(g.gift_date) AS days_since_last_gift
FROM constituents AS c
LEFT JOIN gifts AS g
ON c.constituent_id = g.constituent_id
GROUP BY c.constituent_id);

--total gift amounts broken down by the year given
SELECT EXTRACT(year FROM gift_date) AS "Year", SUM(amount)::money AS "Total Gift Amount"
FROM gifts
GROUP BY "Year"
ORDER BY "Year" ASC;

--breakdown of gifts received month by month in 2025 and 2026
SELECT g.YEAR AS "Year", g.MONTH AS "Month", total_amount AS "Total Gift Amount"
FROM(SELECT EXTRACT(year FROM gift_date) AS year, EXTRACT(MONTH FROM gift_date) AS month, SUM(amount)::money AS total_amount
FROM gifts
GROUP BY year, month
ORDER BY year ASC) AS g
WHERE g.year = 2025 OR g.year = 2026;

--WERE THE CAMPAIGNS SUCCESSFUL?

--convert target_amount column of campaigns table from integer to currency format
ALTER TABLE campaigns
ALTER COLUMN target_amount TYPE money
USING target_amount::money;

--total gift amounts broken down by campaign
SELECT c.name AS "Campaign", SUM(g.amount)::money AS "Total Gift Amount", c.target_amount AS "Target Amount", c.end_date AS "Campaign End Date"
FROM gifts AS g
LEFT JOIN campaigns AS c
ON g.CAMPAIGN_ID = c.CAMPAIGN_ID 
GROUP BY c.name, c.target_amount, c.end_date;

--WHO ARE THE TOP DONORS?

--Top 5 donors by gift amount
SELECT c.constituent_id, c.first_name, c.last_name, SUM(g.AMOUNT)::money AS "Total Gift Amount"
FROM gifts AS g
LEFT JOIN (SELECT constituent_id, first_name, last_name
FROM CONSTITUENTS) AS c
ON g.CONSTITUENT_ID = c.CONSTITUENT_ID 
GROUP BY c.constituent_id, c.first_name, c.last_name
ORDER BY "Total Gift Amount" DESC
LIMIT 5;

--Demographic information for those top 5 donors
SELECT c.first_name, c.last_name, (2026-birth_year) AS age, c.degree, c.grad_year, c.major, c.employer, c.job_title, COUNT(g.amount) AS "Number of Donations", SUM(g.amount)::money AS "Total Gift Amount"
FROM constituents AS c
LEFT JOIN GIFTS AS g
ON c.CONSTITUENT_ID = g.CONSTITUENT_ID 
WHERE c.constituent_id IN (27, 2683, 1826, 2156, 202)
GROUP BY c.first_name, c.last_name, age, c.DEGREE, c.grad_year, c.major, c.employer, c.job_title;

--RECENCY, FREQUENCY, AND MONETARY (RFM) ANALYSIS

--Recency

--percentiles for the recency analysis
SELECT PERCENTILE_DISC(0.1) WITHIN GROUP (ORDER BY days_since_last_gift) AS tenth_percentile, 
PERCENTILE_DISC(0.3) WITHIN GROUP (ORDER BY days_since_last_gift) AS thirtieth_percentile,
PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY days_since_last_gift) AS median,
PERCENTILE_DISC(0.7) WITHIN GROUP (ORDER BY days_since_last_gift) AS seventieth_percentile,
PERCENTILE_DISC(0.9) WITHIN GROUP (ORDER BY days_since_last_gift) AS nintieth_percentile
FROM(SELECT c.constituent_id, CURRENT_DATE - MAX(g.gift_date) AS days_since_last_gift
FROM constituents AS c
LEFT JOIN gifts AS g
ON c.constituent_id = g.constituent_id
GROUP BY c.constituent_id);

--Assigning a value 1-6 to each constituent based on the number of days since they gave their last gift and creating a new table
CREATE TABLE constituents_recency AS
SELECT constituent_id, days_since_last_gift,
CASE 
	WHEN days_since_last_gift < 2 THEN 6
	WHEN days_since_last_gift BETWEEN 2 AND 27 THEN 5
	WHEN days_since_last_gift BETWEEN 27 AND 101 THEN 4
	WHEN days_since_last_gift BETWEEN 101 AND 298 THEN 3
	WHEN days_since_last_gift BETWEEN 298 AND 1057 THEN 2
	WHEN days_since_last_gift > 1057 THEN 1
END AS recency_value
FROM(SELECT c.constituent_id, CURRENT_DATE - MAX(g.gift_date) AS days_since_last_gift
FROM constituents AS c
LEFT JOIN gifts AS g
ON c.constituent_id = g.constituent_id
GROUP BY c.constituent_id);

--View first 10 rows of table
SELECT *
FROM constituents_recency
LIMIT 10;


--Frequency
--percentiles for the frequency analysis
SELECT PERCENTILE_DISC(0.1) WITHIN GROUP (ORDER BY count_gifts) AS tenth_percentile, 
PERCENTILE_DISC(0.3) WITHIN GROUP (ORDER BY count_gifts) AS thirtieth_percentile,
PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY count_gifts) AS median,
PERCENTILE_DISC(0.7) WITHIN GROUP (ORDER BY count_gifts) AS seventieth_percentile,
PERCENTILE_DISC(0.9) WITHIN GROUP (ORDER BY count_gifts) AS nintieth_percentile
FROM(SELECT c.constituent_id, COUNT(g.amount) AS count_gifts
FROM constituents AS c
LEFT JOIN gifts AS g
ON c.constituent_id = g.constituent_id
GROUP BY c.constituent_id);

--Assigning a value 1-6 to each constituent based on the amount of gifts given and creating a new table
CREATE TABLE constituents_frequency AS 
SELECT constituent_id, count_gifts,
CASE 
	WHEN count_gifts <= 2 THEN 1
	WHEN count_gifts > 2 AND count_gifts <= 3 THEN 2
	WHEN count_gifts > 3 AND count_gifts <= 4 THEN 3
	WHEN count_gifts > 4 AND count_gifts <= 5 THEN 4
	WHEN count_gifts > 5 AND count_gifts <= 7 THEN 5
	WHEN count_gifts > 7 THEN 6
END AS frequency_value
FROM(SELECT c.constituent_id, COUNT(g.amount) AS count_gifts
FROM constituents AS c
LEFT JOIN gifts AS g
ON c.constituent_id = g.constituent_id
GROUP BY c.constituent_id);

--View first 10 rows of table
SELECT *
FROM constituents_frequency
LIMIT 10;

--Monetary
--Percentiles for the monetary analysis
SELECT PERCENTILE_DISC(0.1) WITHIN GROUP (ORDER BY sum_gifts) AS tenth_percentile, 
PERCENTILE_DISC(0.3) WITHIN GROUP (ORDER BY sum_gifts) AS thirtieth_percentile,
PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY sum_gifts) AS median,
PERCENTILE_DISC(0.7) WITHIN GROUP (ORDER BY sum_gifts) AS seventieth_percentile,
PERCENTILE_DISC(0.9) WITHIN GROUP (ORDER BY sum_gifts) AS nintieth_percentile
FROM (SELECT c.constituent_id, SUM(g.amount) AS sum_gifts
FROM constituents AS c
LEFT JOIN gifts AS g
ON c.constituent_id = g.constituent_id
GROUP BY c.constituent_id);


--Assigning a value 1-6 to each constituent based on their total gift amounts and creating a new table
CREATE TABLE constituents_monetary AS
SELECT constituent_id, sum_gifts,
CASE 
	WHEN sum_gifts < 367.2 THEN 1
	WHEN sum_gifts BETWEEN 367.2 AND 739.25 THEN 2
	WHEN sum_gifts BETWEEN 739.25 AND 1093.61 THEN 3
	WHEN sum_gifts BETWEEN 1093.61 AND 1600.35 THEN 4
	WHEN sum_gifts BETWEEN 1600.35 AND 4107.65 THEN 5
	WHEN sum_gifts > 4107.65 THEN 6
END AS monetary_value
FROM (SELECT c.constituent_id, SUM(g.amount) AS sum_gifts
FROM constituents AS c
LEFT JOIN gifts AS g
ON c.constituent_id = g.constituent_id
GROUP BY c.constituent_id);

--Viewing first 10 rows of table
SELECT *
FROM constituents_monetary
LIMIT 10;

--Combine all the rfm values and create a new table
CREATE TABLE rfm_analysis AS 
SELECT cr.constituent_id, cr.recency_value, cf.frequency_value, cm.monetary_value
FROM constituents_recency AS cr
INNER JOIN constituents_frequency AS cf
ON cr.constituent_id = cf.constituent_id
INNER JOIN constituents_monetary AS cm
ON cr.constituent_id = cm.constituent_id;

--use the new table to determine which constituents we should prioritize
SELECT *
FROM rfm_analysis
WHERE recency_value = 6 AND frequency_value = 6 AND monetary_value = 6;

--demographics of these 17 constituents
SELECT c.constituent_id, c.first_name, c.last_name, (2026-birth_year) AS age, c.degree, c.grad_year, c.major, c.employer, c.job_title
FROM constituents AS c
LEFT JOIN GIFTS AS g
ON c.CONSTITUENT_ID = g.CONSTITUENT_ID 
WHERE c.constituent_id 
IN (SELECT constituent_id
FROM rfm_analysis
WHERE recency_value = 6 AND frequency_value = 6 AND monetary_value = 6)
GROUP BY c.constituent_id, c.first_name, c.last_name, age, c.DEGREE, c.grad_year, c.major, c.employer, c.job_title
ORDER BY age ASC;
