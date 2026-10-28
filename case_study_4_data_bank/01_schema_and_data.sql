CREATE DATABASE IF NOT EXISTS data_bank;
USE data_bank;

-- ==========================================
-- TABLE 1: regions
-- ==========================================
CREATE TABLE regions (
    region_id   INT PRIMARY KEY,
    region_name VARCHAR(20)
);
INSERT INTO regions VALUES
    (1, 'Australia'), (2, 'America'), (3, 'Africa'), (4, 'Europe'), (5, 'Asia');

-- ==========================================
-- TABLE 2: customer_nodes
-- ==========================================
CREATE TABLE customer_nodes (
  customer_id INTEGER,
  region_id INTEGER,
  node_id INTEGER,
  start_date DATE,
  end_date DATE
);

-- ==========================================
-- TABLE 4: transactions
-- ==========================================
CREATE TABLE customer_transactions (
  customer_id INTEGER,
  txn_date DATE,
  txn_type VARCHAR(10),
  txn_amount INTEGER
);

-- ============================================================================================================

-- -----------
-- Validation
-- -----------

-- Which txn_types exist? (deposit = money in; everything else = money out)
SELECT txn_type, COUNT(*) AS n, SUM(txn_amount) AS total
FROM customer_transactions
GROUP BY txn_type;

-- Allocation episodes per customer (consecutive date windows expected)
SELECT * FROM customer_nodes
WHERE customer_id = 1
ORDER BY start_date;

-- Sentinel end_date for still-active allocations
SELECT end_date, COUNT(*) AS n
FROM customer_nodes
GROUP BY end_date
ORDER BY n DESC
LIMIT 5;

-- ============================================================================================================

-- -------------------------------
-- Surrogate Transaction Sequence
-- -------------------------------

DROP TABLE IF EXISTS txn_numbered;
CREATE TABLE txn_numbered AS
SELECT
    ROW_NUMBER() OVER (
        PARTITION BY customer_id
        ORDER BY txn_date, txn_type, txn_amount
    ) AS txn_seq,
    t.*
FROM customer_transactions t;