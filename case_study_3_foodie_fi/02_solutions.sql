-- =====================================================================================================================

/*
Q1. How many customers has Foodie-Fi ever had?
Answer: 1000
*/

SELECT COUNT(DISTINCT customer_id) AS total_customers
FROM subscriptions;

-- =====================================================================================================================

/*
Q2. Monthly distribution of trial plan start dates (group by start of month)
*/

SELECT 
    DATE_FORMAT(start_date, '%Y-%m-01') AS month_start,  -- truncates to 1st of month
    COUNT(*) AS trial_starts
FROM subscriptions
WHERE plan_id = 0
GROUP BY month_start
ORDER BY month_start;

-- =====================================================================================================================

/*
Q3. Plan events occurring after the year 2020, broken down by plan name
*/

SELECT 
    p.plan_name,
    COUNT(*) AS events_after_2020
FROM subscriptions s
JOIN plans p ON p.plan_id = s.plan_id
WHERE s.start_date >= '2021-01-01'     -- i.e., after the year 2020
GROUP BY p.plan_name
ORDER BY events_after_2020 DESC;

-- =====================================================================================================================

/*
Q4. Customer count and percentage who churned (1 decimal)
Answer: 1000 total · ~307 churned · ~30.7%
*/

SELECT 
    COUNT(DISTINCT customer_id) AS total_customers,
    COUNT(DISTINCT CASE WHEN plan_id = 4 THEN customer_id END) AS churned_customers,
    ROUND(
        100 * COUNT(DISTINCT CASE WHEN plan_id = 4 THEN customer_id END)
            / COUNT(DISTINCT customer_id), 1
    ) AS churn_pct
FROM subscriptions;

-- =====================================================================================================================

/*
Q5. Churned straight after the initial free trial (whole-number %)
*/

WITH journey AS (
    SELECT 
        customer_id,
        plan_id,
        LAG(plan_id) OVER (
            PARTITION BY customer_id 
            ORDER BY start_date
        ) AS prev_plan_id                    -- the plan immediately before this row
    FROM subscriptions
)
SELECT 
    COUNT(*) AS churned_right_after_trial,
    ROUND(100 * COUNT(*) / (SELECT COUNT(DISTINCT customer_id) FROM subscriptions), 0) AS pct_of_all_customers
FROM journey
WHERE plan_id = 4          -- this row is churn
  AND prev_plan_id = 0;    -- previous row was the trial
  
-- =====================================================================================================================

/*
Q6. Plan distribution immediately after the initial free trial
*/

WITH journey AS (
    SELECT 
        customer_id,
        plan_id,
        LAG(plan_id) OVER (PARTITION BY customer_id ORDER BY start_date) AS prev_plan_id
    FROM subscriptions
)
SELECT 
    p.plan_name,
    COUNT(*) AS customers,
    ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct   -- window over an aggregate = % of total
FROM journey j
JOIN plans p ON p.plan_id = j.plan_id
WHERE j.prev_plan_id = 0        -- the row right after the trial
GROUP BY p.plan_name
ORDER BY customers DESC;

-- =====================================================================================================================

/*
Q7. Plan breakdown of all customers at 2020-12-31
*/

WITH current_plan AS (
    SELECT 
        customer_id,
        plan_id,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id 
            ORDER BY start_date DESC        -- latest event on/before the cutoff wins
        ) AS rn
    FROM subscriptions
    WHERE start_date <= '2020-12-31'
)
SELECT 
    p.plan_name,
    COUNT(*) AS customers,
    ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM current_plan cp
JOIN plans p ON p.plan_id = cp.plan_id
WHERE cp.rn = 1                              -- keep only each customer's active plan
GROUP BY p.plan_name
ORDER BY customers DESC;

-- =====================================================================================================================

/*
Q8. Customers who upgraded to an annual plan in 2020
*/

SELECT COUNT(DISTINCT customer_id) AS upgraded_to_annual_2020
FROM subscriptions
WHERE plan_id = 3
AND start_date BETWEEN '2020-01-01' AND '2020-12-31';
  
-- =====================================================================================================================

/*
Q9. Average days from joining to upgrading to annual
*/

WITH trial AS (
    SELECT customer_id, start_date AS join_date
    FROM subscriptions
    WHERE plan_id = 0
),
annual AS (
    SELECT customer_id, start_date AS annual_date
    FROM subscriptions
    WHERE plan_id = 3
)
SELECT 
    ROUND(AVG(DATEDIFF(a.annual_date, t.join_date)), 1) AS avg_days_to_annual
FROM trial t
JOIN annual a ON a.customer_id = t.customer_id;

-- =====================================================================================================================

/*
Q10. Break that average into 30-day periods
*/

WITH trial AS (
    SELECT customer_id, start_date AS join_date
    FROM subscriptions WHERE plan_id = 0
),
annual AS (
    SELECT customer_id, start_date AS annual_date
    FROM subscriptions WHERE plan_id = 3
),
gaps AS (
    SELECT 
        t.customer_id,
        DATEDIFF(a.annual_date, t.join_date) AS days_to_upgrade
    FROM trial t
    JOIN annual a ON a.customer_id = t.customer_id
)
SELECT 
    CASE 
        WHEN days_to_upgrade <= 30  THEN '1: 0-30 days'
        WHEN days_to_upgrade <= 60  THEN '2: 31-60 days'
        WHEN days_to_upgrade <= 90  THEN '3: 61-90 days'
        WHEN days_to_upgrade <= 120 THEN '4: 91-120 days'
        ELSE                             '5: 120+ days'
    END AS upgrade_window,
    COUNT(*) AS customers,
    ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM gaps
GROUP BY upgrade_window
ORDER BY upgrade_window;

-- =====================================================================================================================

/*
Q11. Downgrades from pro monthly → basic monthly in 2020
*/

WITH journey AS (
    SELECT 
        customer_id,
        plan_id,
        start_date,
        LAG(plan_id) OVER (PARTITION BY customer_id ORDER BY start_date) AS prev_plan_id
    FROM subscriptions
)
SELECT COUNT(*) AS downgrades_2020
FROM journey
WHERE plan_id = 1            -- now on basic monthly
  AND prev_plan_id = 2       -- was on pro monthly
  AND start_date BETWEEN '2020-01-01' AND '2020-12-31';
  
-- =====================================================================================================================

/*
Q12. Month-end MRR (monthly recurring revenue) at 2020-12-31
*/

WITH current_plan AS (
    SELECT customer_id, plan_id,
           ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY start_date DESC) AS rn
    FROM subscriptions
    WHERE start_date <= '2020-12-31'
)
SELECT 
    ROUND(SUM(
        CASE WHEN cp.plan_id = 3 THEN p.price / 12   -- annual price → monthly equivalent
             ELSE p.price
        END), 2) AS mrr_at_2020_year_end
FROM current_plan cp
JOIN plans p ON p.plan_id = cp.plan_id
WHERE cp.rn = 1
  AND cp.plan_id <> 4;      -- churned customers contribute $0
-- =====================================================================================================================

/*
Q13. New plan events per month per plan (cohort feed)
*/

SELECT 
    DATE_FORMAT(s.start_date, '%Y-%m') AS month,
    p.plan_name,
    COUNT(*) AS events
FROM subscriptions s
JOIN plans p ON p.plan_id = s.plan_id
GROUP BY month, p.plan_name
ORDER BY month, p.plan_name;