USE pizza_runner;

-- ------------------------------------------------------------
-- 1. CLEAN runner_orders
-- ------------------------------------------------------------
DROP TABLE IF EXISTS runner_orders_clean;
CREATE TABLE runner_orders_clean AS
SELECT
    order_id,
    runner_id,
    CASE
        WHEN pickup_time = 'null' THEN NULL
        ELSE CAST(pickup_time AS DATETIME)
    END AS pickup_time,
    CASE
        WHEN distance = 'null' THEN NULL
        ELSE CAST(REGEXP_REPLACE(distance, '[^0-9.]', '') AS DECIMAL(5,2))
    END AS distance_km,
    CASE
        WHEN duration = 'null' THEN NULL
        ELSE CAST(REGEXP_REPLACE(duration, '[^0-9]', '') AS UNSIGNED)
    END AS duration_mins,
    CASE
        WHEN cancellation IN ('null', '') THEN NULL
        ELSE cancellation
    END AS cancellation
FROM runner_orders;

-- ------------------------------------------------------------
-- 2. CLEAN customer_orders
-- ------------------------------------------------------------
DROP TABLE IF EXISTS customer_orders_clean;
CREATE TABLE customer_orders_clean AS
SELECT
    ROW_NUMBER() OVER (
        ORDER BY order_time, order_id, pizza_id,
                 COALESCE(exclusions, ''), COALESCE(extras, '')
    ) AS row_id,
    t.*
FROM (
    SELECT
        order_id,
        customer_id,
        pizza_id,
        CASE WHEN exclusions IN ('null', '') THEN NULL ELSE exclusions END AS exclusions,
        CASE WHEN extras     IN ('null', '') THEN NULL ELSE extras     END AS extras,
        order_time
    FROM customer_orders
) t;

-- ------------------------------------------------------------
-- 3. VALIDATION — proof the cleaning worked
-- ------------------------------------------------------------
SELECT COUNT(*) AS bad_null_strings
FROM customer_orders_clean
WHERE exclusions = 'null' OR extras = 'null';

SELECT COUNT(*) AS delivered_without_pickup
FROM runner_orders_clean
WHERE pickup_time IS NULL
  AND cancellation IS NULL;

SELECT (SELECT COUNT(*) FROM customer_orders)      AS raw_customer_rows,
       (SELECT COUNT(*) FROM customer_orders_clean) AS clean_customer_rows;

SELECT (SELECT COUNT(*) FROM runner_orders)      AS raw_runner_rows,
       (SELECT COUNT(*) FROM runner_orders_clean) AS clean_runner_rows;