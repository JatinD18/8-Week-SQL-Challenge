-- --------------------------
-- Section A — Pizza Metrics
-- --------------------------
/*
Q1. How many pizzas were ordered?
Answer: 14
*/

SELECT COUNT(pizza_id) AS total_pizzas_ordered
FROM customer_orders_clean;

-- =======================================================================================================================================

/*
Q2. How many unique customer orders were made?
Answer: 10
*/

SELECT COUNT(DISTINCT order_id) AS unique_orders
FROM customer_orders_clean;

-- =======================================================================================================================================

/*
Q3. How many successful orders were delivered by each runner?
Answer: Runner 1 (4), Runner 2 (3), Runner 3 (1)
*/

SELECT 
    runner_id, 
    COUNT(order_id) AS successful_deliveries
FROM runner_orders_clean
WHERE cancellation IS NULL      -- Only count orders that weren't cancelled
GROUP BY runner_id
ORDER BY runner_id;

-- =======================================================================================================================================

/*
Q4. How many of each type of pizza was delivered?
Answer: Meatlovers (9), Vegetarian (3)
*/

SELECT 
    p.pizza_name, 
    COUNT(c.pizza_id) AS delivered_count
FROM customer_orders_clean c
JOIN runner_orders_clean r ON c.order_id = r.order_id
JOIN pizza_names p ON c.pizza_id = p.pizza_id
WHERE r.cancellation IS NULL
GROUP BY p.pizza_name;

-- =======================================================================================================================================

/*
Q5. How many Vegetarian and Meatlovers were ordered by each customer?
*/

SELECT 
    c.customer_id, 
    p.pizza_name, 
    COUNT(c.pizza_id) AS order_count
FROM customer_orders_clean c
JOIN pizza_names p ON c.pizza_id = p.pizza_id
GROUP BY c.customer_id, p.pizza_name
ORDER BY c.customer_id, p.pizza_name;

-- =======================================================================================================================================

/*
Q6. What was the maximum number of pizzas delivered at one time?
Answer: 3 (Order #4 had 3 pizzas and was successfully delivered)
*/

WITH successful_orders AS (
    SELECT 
        c.order_id, 
        COUNT(c.pizza_id) AS pizzas_in_order
    FROM customer_orders_clean c
    JOIN runner_orders_clean r ON c.order_id = r.order_id
    WHERE r.cancellation IS NULL
    GROUP BY c.order_id
)
SELECT MAX(pizzas_in_order) AS max_pizzas_delivered
FROM successful_orders;

-- =======================================================================================================================================

/*
Q7. For each customer, how many delivered pizzas had at least 1 change and how many had no changes?
*/

SELECT 
    c.customer_id,
    -- If either exclusions OR extras is NOT NULL, it had a change
    SUM(CASE WHEN c.exclusions IS NOT NULL OR c.extras IS NOT NULL THEN 1 ELSE 0 END) AS with_changes,
    SUM(CASE WHEN c.exclusions IS NULL AND c.extras IS NULL THEN 1 ELSE 0 END) AS no_changes
FROM customer_orders_clean c
JOIN runner_orders_clean r ON c.order_id = r.order_id
WHERE r.cancellation IS NULL
GROUP BY c.customer_id
ORDER BY c.customer_id;

-- =======================================================================================================================================

/*
Q8. How many pizzas were delivered that had both exclusions and extras?
Answer: 1 (Order #10, Pizza #1 with exclusions '2, 6' and extras '1, 4')
*/

SELECT 
    SUM(CASE WHEN c.exclusions IS NOT NULL AND c.extras IS NOT NULL THEN 1 ELSE 0 END) AS both_changes
FROM customer_orders_clean c
JOIN runner_orders_clean r ON c.order_id = r.order_id
WHERE r.cancellation IS NULL;

-- =======================================================================================================================================

/*
Q9. What was the total volume of pizzas ordered for each hour of the day?
*/

SELECT 
    HOUR(order_time) AS hour_of_day,
    COUNT(pizza_id) AS pizza_volume
FROM customer_orders_clean
GROUP BY HOUR(order_time)
ORDER BY hour_of_day;

-- =======================================================================================================================================

/*
Q10. What was the volume of orders for each day of the week?
*/

SELECT 
    DAYNAME(order_time) AS day_of_week,
    COUNT(pizza_id) AS pizza_volume
FROM customer_orders_clean
GROUP BY DAYNAME(order_time)
ORDER BY MIN(order_time); -- Orders chronologically by first appearance

-- =======================================================================================================================================

-- ---------------------------
-- Section B (Runner Metrics)
-- ---------------------------

/*
Q1. How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)
Answer: Week 1 = 2, Week 2 = 1, Week 3 = 2
*/

SELECT 
    FLOOR(DATEDIFF(registration_date, '2021-01-01') / 7) + 1 AS week_number,
    COUNT(runner_id) AS runners_signed_up
FROM runners
GROUP BY week_number
ORDER BY week_number;

-- =======================================================================================================================================

/*
Q2. What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?
Answer: Runner 1 ≈ 14.00, Runner 2 ≈ 19.67, Runner 3 ≈ 10.00
*/

WITH order_times AS (
    -- Deduplicate: one row per order (orders with 2-3 pizzas would otherwise be double-counted)
    SELECT DISTINCT order_id, order_time
    FROM customer_orders_clean
)
SELECT 
    r.runner_id,
    ROUND(AVG(TIMESTAMPDIFF(MINUTE, ot.order_time, r.pickup_time)), 2) AS avg_pickup_minutes
FROM runner_orders_clean r
JOIN order_times ot ON r.order_id = ot.order_id
WHERE r.pickup_time IS NOT NULL          -- cancelled orders have no pickup
GROUP BY r.runner_id
ORDER BY r.runner_id;

-- =======================================================================================================================================

/*
Q3. Is there any relationship between the number of pizzas and how long the order takes to prepare?
Answer: 1 pizza ≈ 12 min, 2 pizzas ≈ 18 min, 3 pizzas ≈ 29 min → prep time grows with pizza count.
*/

WITH order_prep AS (
    SELECT 
        c.order_id,
        COUNT(c.pizza_id) AS pizzas_in_order,
        -- MIN(order_time) = the single order timestamp, even when the order has multiple pizzas
        TIMESTAMPDIFF(MINUTE, MIN(c.order_time), r.pickup_time) AS prep_minutes
    FROM customer_orders_clean c
    JOIN runner_orders_clean r ON c.order_id = r.order_id
    WHERE r.pickup_time IS NOT NULL
    GROUP BY c.order_id, r.pickup_time
)
SELECT 
    pizzas_in_order,
    COUNT(*)                AS num_orders,
    ROUND(AVG(prep_minutes), 2) AS avg_prep_minutes
FROM order_prep
GROUP BY pizzas_in_order
ORDER BY pizzas_in_order;

-- =======================================================================================================================================

/*
Q4. What was the average distance travelled for each customer?
Answer: 101 ≈ 20.0, 102 ≈ 18.0, 103 ≈ 23.0, 104 ≈ 10.0, 105 ≈ 25.0
*/

WITH delivered_orders AS (
    -- DISTINCT at order level so multi-pizza orders don't skew the customer's average
    SELECT DISTINCT
        c.customer_id,
        c.order_id,
        r.distance_km
    FROM customer_orders_clean c
    JOIN runner_orders_clean r ON c.order_id = r.order_id
    WHERE r.cancellation IS NULL
)
SELECT 
    customer_id,
    ROUND(AVG(distance_km), 2) AS avg_distance_km
FROM delivered_orders
GROUP BY customer_id
ORDER BY customer_id;

-- =======================================================================================================================================

/*
Q5. What was the difference between the longest and shortest delivery times for all orders?
Answer: 30 (40 mins − 10 mins)
*/

SELECT 
    MAX(duration_mins) - MIN(duration_mins) AS delivery_time_difference_mins
FROM runner_orders_clean
WHERE duration_mins IS NOT NULL;

-- =======================================================================================================================================

/*
Q6. What was the average speed for each runner for each delivery and do you notice any trend for these values?
*/

SELECT 
    runner_id,
    order_id,
    distance_km,
    duration_mins,
    ROUND(distance_km / (duration_mins / 60), 2) AS avg_speed_kmh
FROM runner_orders_clean
WHERE cancellation IS NULL
ORDER BY runner_id, order_id;

-- =======================================================================================================================================

/*
Q7. What is the successful delivery percentage for each runner?
Answer: Runner 1 = 100%, Runner 2 = 75%, Runner 3 = 50%
*/

SELECT 
    runner_id,
    COUNT(*)                          AS total_orders,
    SUM(cancellation IS NULL)         AS successful_deliveries,   -- MySQL treats TRUE as 1
    ROUND(100 * SUM(cancellation IS NULL) / COUNT(*), 2) AS successful_delivery_pct
FROM runner_orders_clean
GROUP BY runner_id
ORDER BY runner_id;

-- =======================================================================================================================================

-- ------------------------------------
-- Section C — Ingredient Optimisation
-- ------------------------------------

/*
Q1. What is the successful delivery percentage for each runner?
Answer: Meatlovers = 8 ingredients (Bacon…Salami), Vegetarian = 6 (Cheese…Tomato Sauce)
*/

WITH RECURSIVE seq AS (
    SELECT 1 AS n UNION ALL SELECT n + 1 FROM seq WHERE n < 12
)
SELECT 
    pn.pizza_name,
    pt.topping_name AS standard_ingredient
FROM pizza_recipes pr
JOIN pizza_names pn ON pn.pizza_id = pr.pizza_id
JOIN seq 
    ON seq.n <= 1 + (LENGTH(pr.toppings) - LENGTH(REPLACE(pr.toppings, ',', '')))
JOIN pizza_toppings pt 
    ON pt.topping_id = CAST(TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(pr.toppings, ',', seq.n), ',', -1)) AS UNSIGNED)
ORDER BY pn.pizza_name, standard_ingredient;

-- =======================================================================================================================================

/*
Q2. Most commonly added extra
Answer: Bacon (4 times)
*/

WITH RECURSIVE seq AS (
    SELECT 1 AS n UNION ALL SELECT n + 1 FROM seq WHERE n < 5
)
SELECT 
    pt.topping_name AS extra,
    COUNT(*) AS times_added
FROM customer_orders_clean co
JOIN seq 
    ON seq.n <= 1 + (LENGTH(co.extras) - LENGTH(REPLACE(co.extras, ',', '')))
JOIN pizza_toppings pt 
    ON pt.topping_id = CAST(TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(co.extras, ',', seq.n), ',', -1)) AS UNSIGNED)
WHERE co.extras IS NOT NULL
GROUP BY pt.topping_name
ORDER BY times_added DESC
LIMIT 1;

-- =======================================================================================================================================

/*
Q3. Most common exclusion
Answer: Cheese (4 times)
*/

WITH RECURSIVE seq AS (
    SELECT 1 AS n UNION ALL SELECT n + 1 FROM seq WHERE n < 5
)
SELECT 
    pt.topping_name AS exclusion,
    COUNT(*) AS times_excluded
FROM customer_orders_clean co
JOIN seq 
    ON seq.n <= 1 + (LENGTH(co.exclusions) - LENGTH(REPLACE(co.exclusions, ',', '')))
JOIN pizza_toppings pt 
    ON pt.topping_id = CAST(TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(co.exclusions, ',', seq.n), ',', -1)) AS UNSIGNED)
WHERE co.exclusions IS NOT NULL
GROUP BY pt.topping_name
ORDER BY times_excluded DESC
LIMIT 1;

-- =======================================================================================================================================

/*
Q4. Generate an order item description per record
Answer: order 5 → Meat Lovers - Extra Bacon
		order 9 → Meat Lovers - Exclude Cheese - Extra Bacon, Chicken
		order 10 → one plain Meat Lovers + one Meat Lovers - Exclude BBQ Sauce, Mushrooms - Extra Bacon, Cheese
*/

WITH RECURSIVE seq AS (
    SELECT 1 AS n UNION ALL SELECT n + 1 FROM seq WHERE n < 5
),
excl AS (
    SELECT 
        co.row_id,
        GROUP_CONCAT(pt.topping_name ORDER BY pt.topping_id SEPARATOR ', ') AS excluded_list
    FROM customer_orders_clean co
    JOIN seq ON seq.n <= 1 + (LENGTH(co.exclusions) - LENGTH(REPLACE(co.exclusions, ',', '')))
    JOIN pizza_toppings pt 
        ON pt.topping_id = CAST(TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(co.exclusions, ',', seq.n), ',', -1)) AS UNSIGNED)
    GROUP BY co.row_id
),
extr AS (
    SELECT 
        co.row_id,
        GROUP_CONCAT(pt.topping_name ORDER BY pt.topping_id SEPARATOR ', ') AS extra_list
    FROM customer_orders_clean co
    JOIN seq ON seq.n <= 1 + (LENGTH(co.extras) - LENGTH(REPLACE(co.extras, ',', '')))
    JOIN pizza_toppings pt 
        ON pt.topping_id = CAST(TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(co.extras, ',', seq.n), ',', -1)) AS UNSIGNED)
    GROUP BY co.row_id
)
SELECT 
    co.order_id,
    co.customer_id,
    CONCAT(
        pn.pizza_name,
        COALESCE(CONCAT(' - Exclude ', e.excluded_list), ''),   -- CONCAT(NULL) = NULL → ''
        COALESCE(CONCAT(' - Extra ',   x.extra_list),   '')
    ) AS order_item
FROM customer_orders_clean co
JOIN pizza_names pn ON pn.pizza_id = co.pizza_id
LEFT JOIN excl e ON e.row_id = co.row_id
LEFT JOIN extr x ON x.row_id = co.row_id
ORDER BY co.order_id, co.row_id;

-- =======================================================================================================================================

/*
Q5. Alphabetical ingredient list per order, with 2x prefixes
Answer: order 5 → Meat Lovers: 2xBacon, BBQ Sauce, Beef, Cheese, Chicken, Mushrooms, Pepperoni, Salami
*/

WITH RECURSIVE seq AS (
    SELECT 1 AS n UNION ALL SELECT n + 1 FROM seq WHERE n < 12
),
recipe_items AS (
    SELECT 
        pr.pizza_id,
        CAST(TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(pr.toppings, ',', seq.n), ',', -1)) AS UNSIGNED) AS topping_id
    FROM pizza_recipes pr
    JOIN seq ON seq.n <= 1 + (LENGTH(pr.toppings) - LENGTH(REPLACE(pr.toppings, ',', '')))
),
excl_items AS (
    SELECT 
        co.row_id,
        CAST(TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(co.exclusions, ',', seq.n), ',', -1)) AS UNSIGNED) AS topping_id
    FROM customer_orders_clean co
    JOIN seq ON seq.n <= 1 + (LENGTH(co.exclusions) - LENGTH(REPLACE(co.exclusions, ',', '')))
    WHERE co.exclusions IS NOT NULL
),
extra_items AS (
    SELECT 
        co.row_id,
        CAST(TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(co.extras, ',', seq.n), ',', -1)) AS UNSIGNED) AS topping_id
    FROM customer_orders_clean co
    JOIN seq ON seq.n <= 1 + (LENGTH(co.extras) - LENGTH(REPLACE(co.extras, ',', '')))
    WHERE co.extras IS NOT NULL
),
base AS (   -- recipe minus exclusions (anti-join)
    SELECT co.row_id, ri.topping_id
    FROM customer_orders_clean co
    JOIN recipe_items ri ON ri.pizza_id = co.pizza_id
    LEFT JOIN excl_items ei 
        ON ei.row_id = co.row_id AND ei.topping_id = ri.topping_id
    WHERE ei.topping_id IS NULL
),
combined AS (   -- base + extras; duplicates = 2x
    SELECT row_id, topping_id FROM base
    UNION ALL
    SELECT row_id, topping_id FROM extra_items
),
counts AS (
    SELECT row_id, topping_id, COUNT(*) AS qty
    FROM combined
    GROUP BY row_id, topping_id
)
SELECT 
    co.order_id,
    CONCAT(
        pn.pizza_name, ': ',
        GROUP_CONCAT(
            CONCAT(CASE WHEN c.qty = 2 THEN '2x' ELSE '' END, pt.topping_name)
            ORDER BY pt.topping_name SEPARATOR ', '
        )
    ) AS ingredient_list
FROM counts c
JOIN customer_orders_clean co ON co.row_id = c.row_id
JOIN pizza_names pn           ON pn.pizza_id = co.pizza_id
JOIN pizza_toppings pt        ON pt.topping_id = c.topping_id
GROUP BY co.order_id, co.row_id, pn.pizza_name
ORDER BY co.order_id, co.row_id;

-- =======================================================================================================================================

/*
Q6. Total quantity of each ingredient used across all DELIVERED pizzas
*/

WITH RECURSIVE seq AS (
    SELECT 1 AS n UNION ALL SELECT n + 1 FROM seq WHERE n < 12
),
recipe_items AS (
    SELECT 
        pr.pizza_id,
        CAST(TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(pr.toppings, ',', seq.n), ',', -1)) AS UNSIGNED) AS topping_id
    FROM pizza_recipes pr
    JOIN seq ON seq.n <= 1 + (LENGTH(pr.toppings) - LENGTH(REPLACE(pr.toppings, ',', '')))
),
excl_items AS (
    SELECT 
        co.row_id,
        CAST(TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(co.exclusions, ',', seq.n), ',', -1)) AS UNSIGNED) AS topping_id
    FROM customer_orders_clean co
    JOIN seq ON seq.n <= 1 + (LENGTH(co.exclusions) - LENGTH(REPLACE(co.exclusions, ',', '')))
    WHERE co.exclusions IS NOT NULL
),
extra_items AS (
    SELECT 
        co.row_id,
        CAST(TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(co.extras, ',', seq.n), ',', -1)) AS UNSIGNED) AS topping_id
    FROM customer_orders_clean co
    JOIN seq ON seq.n <= 1 + (LENGTH(co.extras) - LENGTH(REPLACE(co.extras, ',', '')))
    WHERE co.extras IS NOT NULL
),
base AS (
    SELECT co.row_id, ri.topping_id
    FROM customer_orders_clean co
    JOIN recipe_items ri ON ri.pizza_id = co.pizza_id
    LEFT JOIN excl_items ei 
        ON ei.row_id = co.row_id AND ei.topping_id = ri.topping_id
    WHERE ei.topping_id IS NULL
),
combined AS (
    SELECT row_id, topping_id FROM base
    UNION ALL
    SELECT row_id, topping_id FROM extra_items
)
SELECT 
    pt.topping_name,
    COUNT(*) AS total_quantity_used
FROM combined c
JOIN customer_orders_clean co ON co.row_id = c.row_id
JOIN runner_orders_clean r    
    ON r.order_id = co.order_id AND r.cancellation IS NULL   -- delivered only
JOIN pizza_toppings pt        ON pt.topping_id = c.topping_id
GROUP BY pt.topping_name
ORDER BY pt.topping_name;

-- =======================================================================================================================================

-- ---------------------------------
-- Sections D — Pricing and Ratings
-- ---------------------------------

/*
Q1. Total revenue with no delivery fees
Answer: $138
*/

WITH prices AS (
    SELECT 1 AS pizza_id, 12 AS price
    UNION ALL
    SELECT 2, 10
)
SELECT 
    SUM(p.price) AS total_revenue
FROM customer_orders_clean co
JOIN runner_orders_clean r 
    ON r.order_id = co.order_id AND r.cancellation IS NULL   -- delivered only
JOIN prices p ON p.pizza_id = co.pizza_id;

-- =======================================================================================================================================

/*
Q2. Revenue with a $2 fee on deliveries ≥ 20km
Answer: base $138 + fees $10 = $148 (5 delivered orders were ≥ 20km)
*/

WITH prices AS (
    SELECT 1 AS pizza_id, 12 AS price
    UNION ALL
    SELECT 2, 10
),
delivered AS (
    SELECT 
        co.order_id,
        r.distance_km,
        SUM(p.price) AS pizza_revenue
    FROM customer_orders_clean co
    JOIN runner_orders_clean r 
        ON r.order_id = co.order_id AND r.cancellation IS NULL
    JOIN prices p ON p.pizza_id = co.pizza_id
    GROUP BY co.order_id, r.distance_km
)
SELECT 
    SUM(pizza_revenue)                                          AS base_revenue,      -- 138
    SUM(CASE WHEN distance_km >= 20 THEN 2 ELSE 0 END)          AS delivery_fees,     -- 10
    SUM(pizza_revenue + CASE WHEN distance_km >= 20 THEN 2 ELSE 0 END) AS total_revenue -- 148
FROM delivered;

-- =======================================================================================================================================

/*
Q3. How would you price each pizza? (conceptual → made quantitative)
Insights: Meatlovers (8 toppings) → $12, Vegetarian (6) → $10 — the rule reproduces the real menu exactly,
		so it's a safe pricing model for new pizzas.
*/

WITH RECURSIVE seq AS (
    SELECT 1 AS n UNION ALL SELECT n + 1 FROM seq WHERE n < 12
)
SELECT 
    pn.pizza_name,
    COUNT(*)                AS topping_count,
    4 + COUNT(*)            AS suggested_price,   -- base $4 + $1/topping
    CASE WHEN pn.pizza_id = 1 THEN 12 ELSE 10 END AS actual_price
FROM pizza_recipes pr
JOIN pizza_names pn ON pn.pizza_id = pr.pizza_id
JOIN seq ON seq.n <= 1 + (LENGTH(pr.toppings) - LENGTH(REPLACE(pr.toppings, ',', '')))
GROUP BY pn.pizza_name, pn.pizza_id;

-- =======================================================================================================================================

/*
Q4. Revenue from extras only ($1 per extra topping, delivered orders)
Answer: $4 (orders 5, 7 and 10; order 9's extras were on a cancelled order)
*/

WITH RECURSIVE seq AS (
    SELECT 1 AS n UNION ALL SELECT n + 1 FROM seq WHERE n < 5
)
SELECT 
    COUNT(*) AS extras_sold,          -- 4
    COUNT(*) * 1 AS extras_revenue    -- $4
FROM customer_orders_clean co
JOIN runner_orders_clean r 
    ON r.order_id = co.order_id AND r.cancellation IS NULL
JOIN seq ON seq.n <= 1 + (LENGTH(co.extras) - LENGTH(REPLACE(co.extras, ',', '')))
WHERE co.extras IS NOT NULL;

-- =======================================================================================================================================

/*
Q5. Total revenue including extras
Answer: $138 + $4 = $142
*/

WITH RECURSIVE seq AS (
    SELECT 1 AS n UNION ALL SELECT n + 1 FROM seq WHERE n < 5
),
prices AS (
    SELECT 1 AS pizza_id, 12 AS price
    UNION ALL
    SELECT 2, 10
),
delivered_base AS (
    SELECT co.order_id, SUM(p.price) AS pizza_revenue
    FROM customer_orders_clean co
    JOIN runner_orders_clean r 
        ON r.order_id = co.order_id AND r.cancellation IS NULL
    JOIN prices p ON p.pizza_id = co.pizza_id
    GROUP BY co.order_id
),
delivered_extras AS (
    SELECT co.order_id, COUNT(*) AS extra_count
    FROM customer_orders_clean co
    JOIN runner_orders_clean r 
        ON r.order_id = co.order_id AND r.cancellation IS NULL
    JOIN seq ON seq.n <= 1 + (LENGTH(co.extras) - LENGTH(REPLACE(co.extras, ',', '')))
    WHERE co.extras IS NOT NULL
    GROUP BY co.order_id
)
SELECT 
    SUM(b.pizza_revenue + COALESCE(e.extra_count, 0)) AS total_revenue_with_extras
FROM delivered_base b
LEFT JOIN delivered_extras e ON e.order_id = b.order_id;

-- =======================================================================================================================================

/*
Q6. Average rating for each pizza type
Answer: (all rated orders): Meatlovers 3.0 · Vegetarian 3.5
*/

SELECT 
    pn.pizza_name,
    ROUND(AVG(rt.rating), 2) AS avg_rating
FROM ratings rt
JOIN (   -- one row per (order, pizza) so multi-pizza orders don't double-count
    SELECT DISTINCT order_id, pizza_id 
    FROM customer_orders_clean
) op ON op.order_id = rt.order_id
JOIN pizza_names pn ON pn.pizza_id = op.pizza_id
GROUP BY pn.pizza_name;

-- =======================================================================================================================================

/*
Q7. (Likely follow-up) Average rating per runner
Answer: Runner 1 = 3.5 · Runner 2 = 3.67 · Runner 3 = 1.0 (Runner 3's only delivered order was rated 1 — a retention risk!)
*/

SELECT 
    r.runner_id,
    ROUND(AVG(rt.rating), 2) AS avg_rating
FROM ratings rt
JOIN runner_orders_clean r ON r.order_id = rt.order_id
WHERE r.cancellation IS NULL
GROUP BY r.runner_id
ORDER BY r.runner_id;

-- =======================================================================================================================================

/*
Q8. (Likely follow-up) Top pizzas by customer rating
Answer: Vegetarian - 3.5, Meatlovers - 3.0
*/

SELECT 
    pn.pizza_name,
    ROUND(AVG(rt.rating), 2) AS avg_rating
FROM ratings rt
JOIN (SELECT DISTINCT order_id, pizza_id FROM customer_orders_clean) op
    ON op.order_id = rt.order_id
JOIN pizza_names pn ON pn.pizza_id = op.pizza_id
GROUP BY pn.pizza_name
ORDER BY avg_rating DESC;

-- =======================================================================================================================================

-- ----------------------------
-- Section E — Bonus Questions
-- ----------------------------

/*
Q1. Add a new "Supreme" pizza to the menu
*/

INSERT INTO pizza_names (pizza_id, pizza_name)
VALUES (3, 'Supreme');

INSERT INTO pizza_recipes (pizza_id, toppings)
VALUES (3, '1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12');

-- =======================================================================================================================================

/*
Q2. Validate the new pizza joined correctly (split + name resolution)
*/

WITH RECURSIVE seq AS (
    SELECT 1 AS n UNION ALL SELECT n + 1 FROM seq WHERE n < 12
)
SELECT 
    pn.pizza_name,
    GROUP_CONCAT(pt.topping_name ORDER BY pt.topping_id SEPARATOR ', ') AS ingredients,
    4 + COUNT(*) AS price_using_D3_rule      -- $16 for Supreme
FROM pizza_recipes pr
JOIN pizza_names pn ON pn.pizza_id = pr.pizza_id
JOIN seq ON seq.n <= 1 + (LENGTH(pr.toppings) - LENGTH(REPLACE(pr.toppings, ',', '')))
JOIN pizza_toppings pt 
    ON pt.topping_id = CAST(TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(pr.toppings, ',', seq.n), ',', -1)) AS UNSIGNED)
WHERE pr.pizza_id = 3
GROUP BY pn.pizza_name;
-- =======================================================================================================================================

/*
Q3. Undo the bonus insert (keep your dataset pristine for Sections A–D re-runs)
*/

DELETE FROM pizza_names  WHERE pizza_id = 3;
DELETE FROM pizza_recipes WHERE pizza_id = 3;