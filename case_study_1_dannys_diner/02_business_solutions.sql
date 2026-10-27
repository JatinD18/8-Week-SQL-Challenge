-- ================================================
-- Top 3 Most Important Questions - Q.3; Q.6 & Q.8
-- ================================================

/*
Question 3: What was the first item from the menu purchased by each customer?
*/

WITH RankedOrders AS (
    SELECT 
        s.customer_id,
        s.order_date,
        m.product_name,
        DENSE_RANK() OVER(PARTITION BY s.customer_id ORDER BY s.order_date ASC) AS rnk
    FROM sales s
    JOIN menu m ON s.product_id = m.product_id
)
SELECT 
    customer_id, 
    product_name AS first_item_purchased
FROM RankedOrders
WHERE rnk = 1;

-- Insight: Customer A bought sushi and curry on the same day, so both are returned. Customer B bought curry first, and C bought ramen.

-- =======================================================================================================================================

/*
Question 6: Which item was purchased first by the customer AFTER they became a member?
This tests the ability to filter dates before applying window functions.
*/

WITH MemberOrders AS (
    SELECT 
        s.customer_id,
        s.order_date,
        m.product_name,
        DENSE_RANK() OVER(PARTITION BY s.customer_id ORDER BY s.order_date ASC) AS rnk
    FROM sales s
    JOIN menu m ON s.product_id = m.product_id
    JOIN members mem ON s.customer_id = mem.customer_id
    WHERE s.order_date >= mem.join_date
)
SELECT 
    customer_id, 
    product_name AS first_item_after_membership
FROM MemberOrders
WHERE rnk = 1;

-- =======================================================================================================================================
/*
Question 8: What is the total items and amount spent for each member BEFORE they became a member?
This tests conditional aggregation and date logic.
*/

SELECT 
    s.customer_id,
    COUNT(s.product_id) AS total_items,
    SUM(m.price) AS total_spent
FROM sales s
JOIN menu m ON s.product_id = m.product_id
LEFT JOIN members mem ON s.customer_id = mem.customer_id
WHERE s.order_date < mem.join_date 
   OR mem.join_date IS NULL
GROUP BY s.customer_id
ORDER BY s.customer_id;

-- =======================================================================================================================================
-- =======================================================================================================================================

/*
Q1: Total amount each customer spent
Concept: Simple join + aggregate. Note Customer C appears even though they're not a member — joins don't care about membership.
*/

SELECT 
    s.customer_id,
    SUM(m.price) AS total_spent
FROM sales s
JOIN menu m ON s.product_id = m.product_id
GROUP BY s.customer_id
ORDER BY s.customer_id;

-- =======================================================================================================================================

/*
Q2: How many days each customer visited
Concept: COUNT(DISTINCT ...) — without DISTINCT, Customer A would show 6 (row count) instead of 4 (unique days).
This is the #1 beginner mistake on this question.
*/

SELECT 
    customer_id,
    COUNT(DISTINCT order_date) AS days_visited
FROM sales
GROUP BY customer_id;

-- =======================================================================================================================================

/*
Q4: Most purchased item overall
Concept: ORDER BY ... DESC LIMIT 1 is the MySQL way to get "the top one."
*/

SELECT 
    m.product_name,
    COUNT(*) AS times_purchased
FROM sales s
JOIN menu m ON s.product_id = m.product_id
GROUP BY m.product_name
ORDER BY times_purchased DESC
LIMIT 1;

-- =======================================================================================================================================

/*
Q5: Most popular item per customer
Concept: A window function ordered by an aggregate (ORDER BY COUNT(*) DESC) — this is an advanced pattern. 
And B's tie is why DENSE_RANK() matters: ROW_NUMBER() would have arbitrarily dropped two of B's items.
*/

WITH item_counts AS (
    SELECT 
        s.customer_id,
        m.product_name,
        COUNT(*) AS purchase_count,
        DENSE_RANK() OVER (
            PARTITION BY s.customer_id 
            ORDER BY COUNT(*) DESC
        ) AS rnk
    FROM sales s
    JOIN menu m ON s.product_id = m.product_id
    GROUP BY s.customer_id, m.product_name
)
SELECT customer_id, product_name, purchase_count
FROM item_counts
WHERE rnk = 1;

-- =======================================================================================================================================

/*
Q7: Item purchased just BEFORE becoming a member
Concept: This is the mirror image of Q6 — same structure, but ORDER BY ... DESC and < join_date instead of ASC and >=.
*/

WITH pre_member AS (
    SELECT 
        s.customer_id,
        s.order_date,
        m.product_name,
        DENSE_RANK() OVER (
            PARTITION BY s.customer_id 
            ORDER BY s.order_date DESC   -- DESC = closest date BEFORE joining
        ) AS rnk
    FROM sales s
    JOIN menu m  ON s.product_id  = m.product_id
    JOIN members mem ON s.customer_id = mem.customer_id
    WHERE s.order_date < mem.join_date    -- strictly BEFORE join
)
SELECT customer_id, product_name AS last_item_before_membership
FROM pre_member
WHERE rnk = 1;

-- =======================================================================================================================================

/*
Q9: Loyalty points (sushi = 2x multiplier)
Concept: Conditional aggregation inside SUM() — the CASE evaluates per row before summing.
*/

SELECT 
    s.customer_id,
    SUM(
        CASE 
            WHEN m.product_name = 'sushi' THEN m.price * 20  -- 10 pts/$ × 2
            ELSE m.price * 10
        END
    ) AS points
FROM sales s
JOIN menu m ON s.product_id = m.product_id
GROUP BY s.customer_id;

-- =======================================================================================================================================

/*
Q10: Points with first-week 2x bonus (end of January)
Concept: DATE_ADD(join_date, INTERVAL 6 DAY) — "first week including join date" = join + 6 days, not + 7.
CASE order matters: the week rule is checked first.
*/

SELECT 
    s.customer_id,
    SUM(
        CASE 
            -- First 7 days after joining (incl. join date): 2x on EVERYTHING
            WHEN s.order_date BETWEEN mem.join_date 
                                   AND DATE_ADD(mem.join_date, INTERVAL 6 DAY) 
                THEN m.price * 20
            -- Outside the window: only sushi keeps 2x
            WHEN m.product_name = 'sushi' THEN m.price * 20
            ELSE m.price * 10
        END
    ) AS points
FROM sales s
JOIN menu m  ON s.product_id  = m.product_id
JOIN members mem ON s.customer_id = mem.customer_id
WHERE s.order_date <= '2021-01-31'
GROUP BY s.customer_id;

-- =======================================================================================================================================

-- ---------------------------------
-- FOR CREATING THE FULL AUDIT TABLE
-- ---------------------------------

SELECT 
    s.customer_id,
    s.order_date,
    m.product_name,
    m.price,
    CASE 
        WHEN s.order_date >= mem.join_date THEN 'Y'
        ELSE 'N'
    END AS member,
    CASE 
        WHEN mem.customer_id IS NULL THEN NULL   -- non-members get no ranking
        ELSE RANK() OVER (
            PARTITION BY s.customer_id 
            ORDER BY s.order_date
        )
    END AS ranking
FROM sales s
JOIN menu m ON s.product_id = m.product_id
LEFT JOIN members mem ON s.customer_id = mem.customer_id
ORDER BY s.customer_id, s.order_date;

-- =======================================================================================================================================


