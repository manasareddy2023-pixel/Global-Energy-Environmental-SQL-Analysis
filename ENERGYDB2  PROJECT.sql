CREATE DATABASE ENERGYDB2;
USE ENERGYDB2;

-- 1. country table
CREATE TABLE country (
    CID VARCHAR(10) PRIMARY KEY,
    Country VARCHAR(100) UNIQUE
);

SELECT * FROM COUNTRY;

-- 2. emission_3 table
CREATE TABLE emission_3 (
    country VARCHAR(100),
    energy_type VARCHAR(50),
    year INT,
    emission INT,
    per_capita_emission DOUBLE,
    FOREIGN KEY (country) REFERENCES country(Country)
);

SELECT * FROM EMISSION_3;


-- 3. population table
CREATE TABLE population (
    countries VARCHAR(100),
    year INT,
    Value DOUBLE,
    FOREIGN KEY (countries) REFERENCES country(Country)
);

SELECT * FROM POPULATION;

-- 4. production table
CREATE TABLE production (
    country VARCHAR(100),
    energy VARCHAR(50),
    year INT,
    production INT,
    FOREIGN KEY (country) REFERENCES country(Country)
);


SELECT * FROM PRODUCTION;

-- 5. gdp_3 table
CREATE TABLE gdp_3 (
    Country VARCHAR(100),
    year INT,
    Value DOUBLE,
    FOREIGN KEY (Country) REFERENCES country(Country)
);

SELECT * FROM GDP_3;

-- 6. consumption table
CREATE TABLE consumption (
    country VARCHAR(100),
    energy VARCHAR(50),
    year INT,
    consumption INT,
    FOREIGN KEY (country) REFERENCES country(Country)
);

SELECT * FROM CONSUMPTION;

-- Q1. What is the total emission per country for the most recent year available?
SELECT country,SUM(emission) AS total_emission
FROM emission_3
WHERE year = (SELECT MAX(year) FROM emission_3)
GROUP BY country
ORDER BY total_emission DESC;

-- Q2. What are the top 5 countries by GDP in the most recent year?
SELECT Country,Value AS GDP
FROM gdp_3
WHERE year = (SELECT MAX(year) FROM gdp_3)
ORDER BY GDP DESC
LIMIT 5;

-- Q3. Compare energy production and consumption by country and year.
SELECT p.country, p.year,
       SUM(p.production) AS production,
       SUM(c.consumption) AS consumption
FROM production p
JOIN consumption c
ON p.country = c.country AND p.year = c.year
GROUP BY p.country, p.year;

-- Q4. Which energy types contribute most to emissions across all countries?
SELECT energy_type,SUM(emission) AS total_emission
FROM emission_3
GROUP BY energy_type
ORDER BY total_emission DESC;

-- TREND ANALYSIS OVER TIME
-- Q5. How have global emissions changed year over year?
SELECT year,SUM(emission) AS global_emission
FROM emission_3
GROUP BY year
ORDER BY year;

-- Q6. What is the trend in GDP for each country over the given years?
SELECT Country,year,Value AS GDP
FROM gdp_3
ORDER BY Country, year;

-- Q7. How has population growth affected total emissions in each country?
SELECT p.countries AS country, p.year,
       p.Value AS population,
       SUM(e.emission) AS total_emission
FROM population p
JOIN emission_3 e
ON p.countries = e.country AND p.year = e.year
GROUP BY p.countries, p.year, p.Value;


-- Q8. Has energy consumption increased or decreased over the years for major economies?
SELECT c.country, c.year,
       SUM(c.consumption) AS total_consumption
FROM consumption c
JOIN (
    SELECT Country
    FROM gdp_3
    WHERE year = (SELECT MAX(year) FROM gdp_3)
    ORDER BY Value DESC
    LIMIT 5
) AS top5
ON c.country = top5.Country
GROUP BY c.country, c.year
ORDER BY c.country, c.year;
  


-- Q9. What is the average yearly change in emissions per capita for each country?
SELECT country,
       AVG(per_capita_emission - prev_emission) AS avg_yearly_change
FROM (
    SELECT country, year, per_capita_emission,
           LAG(per_capita_emission)
           OVER(PARTITION BY country ORDER BY year) AS prev_emission
    FROM emission_3
) x
WHERE prev_emission IS NOT NULL
GROUP BY country;

-- RATIO & PER CAPITA ANALYSIS
-- Q10. What is the emission-to-GDP ratio for each country by year?
SELECT e.country, e.year,
       SUM(e.emission) / NULLIF(g.Value,0) AS emission_gdp_ratio
FROM emission_3 e
JOIN gdp_3 g
ON e.country = g.Country AND e.year = g.year
GROUP BY e.country, e.year, g.Value;
 
-- Q11. What is the energy consumption per capita for each country over the last decade?
SELECT c.country, c.year,
       SUM(c.consumption) / NULLIF(p.Value,0) AS consumption_per_capita
FROM consumption c
JOIN population p
ON c.country = p.countries AND c.year = p.year
WHERE c.year >= (SELECT MAX(year) - 9 FROM consumption)
GROUP BY c.country, c.year, p.Value;

-- Q12. How does energy production per capita vary across countries?
SELECT p.country, p.year,
       SUM(p.production) / NULLIF(pop.Value,0) AS production_per_capita
FROM production p
JOIN population pop
ON p.country = pop.countries AND p.year = pop.year
GROUP BY p.country, p.year, pop.Value;

-- Q13. Which countries have the highest energy consumption relative to GDP?
SELECT c.country,
       SUM(c.consumption) / NULLIF(g.Value,0) AS consumption_gdp_ratio
FROM consumption c
JOIN gdp_3 g
ON c.country = g.Country AND c.year = g.year
GROUP BY c.country, g.Value
ORDER BY consumption_gdp_ratio DESC;

-- Q14. What is the correlation between GDP growth and energy production growth?
WITH prod AS (
    SELECT
        country,
        year,
        SUM(production) AS production
    FROM production
    GROUP BY country, year
),

growth AS (
    SELECT
        g.Country,
        g.year,

        (
            g.Value /
            NULLIF(
                LAG(g.Value) OVER (
                    PARTITION BY g.Country
                    ORDER BY g.year
                ), 0
            )
        ) - 1 AS gdp_growth,

        (
            p.production /
            NULLIF(
                LAG(p.production) OVER (
                    PARTITION BY p.country
                    ORDER BY p.year
                ), 0
            )
        ) - 1 AS production_growth

    FROM gdp_3 g
    JOIN prod p
        ON g.Country = p.country
        AND g.year = p.year
),

stats AS (
    SELECT
        COUNT(*) AS n,
        SUM(gdp_growth) AS sum_x,
        SUM(production_growth) AS sum_y,
        SUM(gdp_growth * production_growth) AS sum_xy,
        SUM(gdp_growth * gdp_growth) AS sum_x2,
        SUM(production_growth * production_growth) AS sum_y2
    FROM growth
    WHERE gdp_growth IS NOT NULL
      AND production_growth IS NOT NULL
)

SELECT
    (
        n * sum_xy - sum_x * sum_y
    )
    /
    SQRT(
        (n * sum_x2 - sum_x * sum_x)
        *
        (n * sum_y2 - sum_y * sum_y)
    ) AS correlation
FROM stats;

-- Global Comparisons
-- Q15. What are the top 10 countries by population and how do their emissions compare?
SELECT
    p.countries AS country,
    p.Value AS population,
    COALESCE(SUM(e.emission), 0) AS emission
FROM population p
LEFT JOIN emission_3 e
    ON p.countries = e.country
    AND p.year = e.year
WHERE p.year = (
    SELECT MAX(p2.year)
    FROM population p2
    WHERE EXISTS (
        SELECT 1
        FROM emission_3 e2
        WHERE e2.year = p2.year
    )
)
GROUP BY p.countries, p.Value
ORDER BY p.Value DESC
LIMIT 10;

 -- Q16. Which countries reduced their per-capita emissions the most over the last decade?
	WITH yearly AS (
    SELECT
        country,
        year,
        SUM(per_capita_emission) AS emission
    FROM emission_3
    GROUP BY country, year
),
period AS (
    SELECT
        country,
        MIN(year) AS start_year,
        MAX(year) AS end_year
    FROM yearly
    WHERE year >= (SELECT MAX(year) - 9 FROM yearly)
    GROUP BY country
)
SELECT
    p.country,
    ROUND(s.emission - e.emission, 2) AS reduction
FROM period p
JOIN yearly s
    ON p.country = s.country
    AND p.start_year = s.year
JOIN yearly e
    ON p.country = e.country
    AND p.end_year = e.year
WHERE s.emission > e.emission
ORDER BY reduction DESC;

-- Q17. What is the global share (%) of emissions by country?
SELECT country,ROUND(SUM(emission) * 100 /
        (SELECT SUM(emission) FROM emission_3), 2
    ) AS global_share
FROM emission_3
GROUP BY country
ORDER BY global_share DESC;

-- Q18. What is the global average GDP, emission, and population by year?
SELECT g.year,ROUND(AVG(g.Value),2) avg_gdp,
ROUND(AVG(e.total),2) avg_emission,ROUND(AVG(p.Value),2) avg_population
FROM gdp_3 g JOIN population p
ON g.Country=p.countries AND g.year=p.year
JOIN (SELECT country,year,SUM(emission) total
FROM emission_3 GROUP BY country,year) e
ON g.Country=e.country AND g.year=e.year
GROUP BY g.year ORDER BY g.year;