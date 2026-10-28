-- ============================================================================================================

/*
Q1. Unique count and total amount per transaction type
*/

SELECT
    txn_type,
    COUNT(*)          AS txn_count,
    SUM(txn_amount)   AS total_amount
FROM customer_transactions
GROUP BY txn_type
ORDER BY total_amount DESC;

/*
Q2. Average number of transactions per customer
*/

SELECT
    COUNT(*) / COUNT(DISTINCT customer_id) AS avg_txns_per_customer
FROM customer_transactions;

/*
Q3. Count and total amount per region (period-accurate join)
*/

SELECT
    r.region_name,
    COUNT(*)          AS txn_count,
    SUM(ct.txn_amount) AS total_amount
FROM customer_transactions ct
JOIN customer_nodes cn
       ON cn.customer_id = ct.customer_id
      AND ct.txn_date >= cn.start_date
      AND ct.txn_date <  cn.end_date
JOIN regions r ON r.region_id = cn.region_id
GROUP BY r.region_name
ORDER BY total_amount DESC;

/*
Q4. Count and average amount per customer
*/

SELECT
    customer_id,
    COUNT(*)                  AS txn_count,
    ROUND(AVG(txn_amount), 2) AS avg_amount
FROM customer_transactions
GROUP BY customer_id
ORDER BY txn_count DESC
LIMIT 20;

/*
Q5. Count and total amount per region per month
*/

SELECT
    r.region_name,
    DATE_FORMAT(ct.txn_date, '%Y-%m') AS month,
    COUNT(*)           AS txn_count,
    SUM(ct.txn_amount) AS total_amount
FROM customer_transactions ct
JOIN customer_nodes cn
       ON cn.customer_id = ct.customer_id
      AND ct.txn_date >= cn.start_date
      AND ct.txn_date <  cn.end_date
JOIN regions r ON r.region_id = cn.region_id
GROUP BY r.region_name, month
ORDER BY month, total_amount DESC;

-- ============================================================================================================

-- --------------------------------------
-- Running Balances (ordered by txn_seq)
-- --------------------------------------

/*
Q1. Running balance per transaction
*/

CREATE OR REPLACE VIEW vw_running_balance AS
SELECT
    customer_id,
    txn_seq,
    txn_date,
    txn_type,
    txn_amount,
    SUM(
        CASE WHEN txn_type = 'deposit' THEN txn_amount ELSE -txn_amount END
    ) OVER (
        PARTITION BY customer_id
        ORDER BY txn_seq                                   -- deterministic, no txn_id needed
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_balance
FROM txn_numbered;

/*
Q2. Daily closing balance per customer
*/

CREATE OR REPLACE VIEW vw_daily_closing AS
WITH ranked AS (
    SELECT
        customer_id,
        txn_date,
        running_balance,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id, txn_date
            ORDER BY txn_seq DESC                          -- last transaction of the day wins
        ) AS rn
    FROM vw_running_balance
)
SELECT customer_id, txn_date AS day, running_balance AS closing_balance
FROM ranked
WHERE rn = 1;

/*
Q3. Monthly closing balance per customer
*/

WITH ranked AS (
    SELECT
        customer_id,
        day,
        closing_balance,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id, DATE_FORMAT(day, '%Y-%m')
            ORDER BY day DESC                              -- last active day of month wins
        ) AS rn
    FROM vw_daily_closing
)
SELECT
    customer_id,
    DATE_FORMAT(day, '%Y-%m') AS month,
    closing_balance           AS month_end_balance
FROM ranked
WHERE rn = 1
ORDER BY customer_id, month;

/*
Q4. Reserve cash the bank must hold (final balance per customer)
*/

WITH final_balances AS (
    SELECT
        customer_id,
        closing_balance,
        ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY day DESC) AS rn
    FROM vw_daily_closing
)
SELECT
    SUM(closing_balance) AS total_customer_balances,
    SUM(CASE WHEN closing_balance < 0 THEN closing_balance ELSE 0 END) AS overdraft_exposure
FROM final_balances
WHERE rn = 1;