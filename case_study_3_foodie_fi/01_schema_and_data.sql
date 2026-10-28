CREATE DATABASE IF NOT EXISTS foodie_fi;
USE foodie_fi;

-- ==========================================
-- TABLE 1: plans (small dimension table)
-- ==========================================
CREATE TABLE plans (
    plan_id   INT PRIMARY KEY,
    plan_name VARCHAR(20),
    price     DECIMAL(6,2)
);

INSERT INTO plans VALUES
    (0, 'trial',         0.00),
    (1, 'basic monthly', 9.90),
    (2, 'pro monthly',   19.90),
    (3, 'pro annual',    199.00),
    (4, 'churn',         NULL);   -- churn has no price

-- ==========================================
-- TABLE 2: subscriptions (fact table)
-- One row per plan-change event per customer
-- ==========================================

CREATE TABLE subscriptions (
    customer_id INT,
    plan_id     INT,
    start_date  DATE
);

-- The values for subscriptions table inserted by the sepearte query that took it from the official website of 8 Week SQL Challenge.

-- =====================================================================================================================

-- -----------
-- Validation
-- -----------

SELECT COUNT(*) AS journey_rows,
       COUNT(DISTINCT customer_id) AS customers
FROM subscriptions;

SELECT * FROM subscriptions WHERE customer_id = 1 ORDER BY start_date;

-- =====================================================================================================================

