-- https://sqliteonline.com/

/*
Given a posts table that contains a created_at timestamp column write a query that returns a first date of the month, a number of posts created in a given month and a month-over-month growth rate.
The resulting set should be ordered chronologically by date.
Note:
percent growth rate can be negative
percent growth rate should be rounded to one digit after the decimal point and immediately followed by a percent symbol "%". See the desired output below for the reference.

The resulting set should look similar to the following column: 
date (format YYYY-MM-DD), count, percent_growth
*/

WITH PREP_SET AS (
  SELECT DISTINCT TO_CHAR(date_trunc('MONTH',"date"::TIMESTAMP), 'YYYY/MM/DD') AS MONTHLY_DATE
    , COUNT(VALUE) OVER (PARTITION BY TO_CHAR(date_trunc('MONTH',"date"::TIMESTAMP), 'YYYY/MM/DD')) AS CURR_MONTH_COUNT
from out_3 as posts
  )
 SELECT MONTHLY_DATE
 	, CURR_MONTH_COUNT
    -- FORMULA:
    -- Percent Change = 100 × (Present or Future Value – Past or Present Value) / Past or Present Value
 	, 100 * TRUNC((CURR_MONTH_COUNT - LAG(CURR_MONTH_COUNT,1) OVER (ORDER BY MONTHLY_DATE))::NUMERIC / LAG(CURR_MONTH_COUNT,1) OVER (ORDER BY MONTHLY_DATE)::NUMERIC,1) as PERCENT_GROWTH
 FROM PREP_SET
 ORDER BY MONTHLY_DATE ASC