/* ==========================================================================
   Employee attrition analysis (fictional IBM HR dataset)
   Database: SQL Server. Table: employees (1,470 rows, 35 columns).

   "attrition_pct" = leavers / headcount in this file. The file is a snapshot
   with no dates, so this is a share of employees, not an annual rate.
   Attrition and OverTime are stored as 1/0 (1 = left / works overtime).
   Each query lists the result you should see ("Expected").
   ========================================================================== */


-- 0. Setup (run once). The import wizard stored Yes/No as bit. Convert to INT
--    so SUM(Attrition) works. Take a backup first.
-- SELECT * INTO employees_backup FROM employees;
-- ALTER TABLE employees ALTER COLUMN Attrition INT;
-- ALTER TABLE employees ALTER COLUMN OverTime INT;


-- 1. DATA CHECKS ------------------------------------------------------------

-- 1a. How many rows? Expected: 1470.
SELECT COUNT(*) AS row_count
FROM employees;

-- 1b. Are employee IDs unique? Two methods that must agree.
-- Expected: total_rows = distinct_ids = 1470.
SELECT COUNT(*)                       AS total_rows,
       COUNT(DISTINCT EmployeeNumber) AS distinct_ids
FROM employees;

-- Expected: no rows returned (an ID that appears twice would show up here).
SELECT EmployeeNumber, COUNT(*) AS times_appearing
FROM employees
GROUP BY EmployeeNumber
HAVING COUNT(*) > 1;

-- 1c. Group sizes of the two flags. Each pair must add up to 1470 (no NULLs).
-- Expected: Attrition 0 = 1233, 1 = 237.
SELECT Attrition, COUNT(*) AS headcount
FROM employees
GROUP BY Attrition;

-- Expected: OverTime 0 = 1054, 1 = 416.
SELECT OverTime, COUNT(*) AS headcount
FROM employees
GROUP BY OverTime;


-- 2. OVERALL ATTRITION ------------------------------------------------------

-- Share of employees marked as leavers.
-- 100.0 (not 100) forces decimal division. With whole numbers, SQL Server
-- does integer division, and 237 / 1470 returns 0.
-- Expected: headcount 1470, leavers 237, attrition_pct 16.1.
SELECT COUNT(*)       AS headcount,
       SUM(Attrition) AS leavers,
       CAST(100.0 * SUM(Attrition) / COUNT(*) AS DECIMAL(5,1)) AS attrition_pct
FROM employees;


-- 3. BY DEPARTMENT ----------------------------------------------------------

-- Which department has the highest attrition?
-- Expected: Sales 446 / 92 / 20.6, Human Resources 63 / 12 / 19.0,
--           Research & Development 961 / 133 / 13.8.
SELECT Department,
       COUNT(*)       AS headcount,
       SUM(Attrition) AS leavers,
       CAST(100.0 * SUM(Attrition) / COUNT(*) AS DECIMAL(5,1)) AS attrition_pct
FROM employees
GROUP BY Department
ORDER BY attrition_pct DESC;


-- 4. BY OVERTIME ------------------------------------------------------------

-- Do employees who work overtime leave more often?
-- Expected: Yes 416 / 127 / 30.5, No 1054 / 110 / 10.4.
SELECT CASE WHEN OverTime = 1 THEN 'Yes'
            WHEN OverTime = 0 THEN 'No'
       END            AS works_overtime,
       COUNT(*)       AS headcount,
       SUM(Attrition) AS leavers,
       CAST(100.0 * SUM(Attrition) / COUNT(*) AS DECIMAL(5,1)) AS attrition_pct
FROM employees
GROUP BY OverTime
ORDER BY attrition_pct DESC;


-- 5. BY DEPARTMENT AND OVERTIME --------------------------------------------

-- Does the overtime gap hold inside every department?
-- Expected: the overtime group is higher in all three departments, e.g.
--   Sales:                  No 318 / 44 / 13.8,  Yes 128 / 48 / 37.5
--   Research & Development: No 690 / 59 / 8.6,   Yes 271 / 74 / 27.3
--   Human Resources:        No 46 / 7 / 15.2,    Yes 17 / 5 / 29.4
-- Caution: Human Resources with overtime is only 17 people, so read it carefully.
SELECT Department,
       CASE WHEN OverTime = 1 THEN 'Yes'
            WHEN OverTime = 0 THEN 'No'
       END            AS works_overtime,
       COUNT(*)       AS headcount,
       SUM(Attrition) AS leavers,
       CAST(100.0 * SUM(Attrition) / COUNT(*) AS DECIMAL(5,1)) AS attrition_pct
FROM employees
GROUP BY Department, OverTime
ORDER BY Department, OverTime;


-- 6. BY TENURE BAND ---------------------------------------------------------

-- How does attrition change with years at the company?
-- The CTE labels each employee with a band first, so the outer query can
-- GROUP BY the band. band_order keeps the bands in a sensible order.
-- Check: headcounts add up to 1470 and leavers to 237.
-- Expected: 0-1 Years 215 / 75 / 34.9,   2-4 Years 365 / 66 / 18.1,
--           5-9 Years 524 / 58 / 11.1,   10+ Years 366 / 38 / 10.4.
WITH banded AS (
    SELECT Attrition,
           CASE WHEN YearsAtCompany BETWEEN 0 AND 1 THEN '0-1 Years'
                WHEN YearsAtCompany BETWEEN 2 AND 4 THEN '2-4 Years'
                WHEN YearsAtCompany BETWEEN 5 AND 9 THEN '5-9 Years'
                ELSE '10+ Years'
           END AS band,
           CASE WHEN YearsAtCompany BETWEEN 0 AND 1 THEN 1
                WHEN YearsAtCompany BETWEEN 2 AND 4 THEN 2
                WHEN YearsAtCompany BETWEEN 5 AND 9 THEN 3
                ELSE 4
           END AS band_order
    FROM employees
)
SELECT band,
       COUNT(*)       AS headcount,
       SUM(Attrition) AS leavers,
       CAST(100.0 * SUM(Attrition) / COUNT(*) AS DECIMAL(5,1)) AS attrition_pct
FROM banded
GROUP BY band, band_order
HAVING COUNT(*) >= 50          -- guard: hide bands too small to trust
ORDER BY band_order;