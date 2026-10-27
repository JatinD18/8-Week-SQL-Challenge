-- =============================================
-- SCHEMA: Case Study #1 - Danny's Diner
-- =============================================
CREATE DATABASE IF NOT EXISTS dannys_diner;
USE dannys_diner;

-- ---------------------------------------------
-- TABLE: menu (Product catalog)
-- product_id is the natural PRIMARY KEY
-- ---------------------------------------------
CREATE TABLE menu (
    product_id   INT PRIMARY KEY,
    product_name VARCHAR(10) NOT NULL,
    price        INT NOT NULL            -- price in dollars
);

INSERT INTO menu (product_id, product_name, price) VALUES
  (1, 'sushi', 10),
  (2, 'curry', 15),
  (3, 'ramen', 12);
  
SELECT COUNT(*) FROM menu;
  
-- ---------------------------------------------
-- TABLE: members (Loyalty program)
-- ---------------------------------------------
CREATE TABLE members (
    customer_id VARCHAR(1) PRIMARY KEY,
    join_date   DATE NOT NULL
);

INSERT INTO members (customer_id, join_date) VALUES
  ('A', '2021-01-07'),
  ('B', '2021-01-09');
  
SELECT COUNT(*) FROM members;
  
-- ---------------------------------------------
-- TABLE: sales (Transaction log)
-- ---------------------------------------------
CREATE TABLE sales (
    sale_id     INT AUTO_INCREMENT PRIMARY KEY,
    customer_id VARCHAR(1) NOT NULL,
    order_date  DATE NOT NULL,
    product_id  INT NOT NULL,
    CONSTRAINT fk_sales_product
        FOREIGN KEY (product_id) REFERENCES menu(product_id)
);

INSERT INTO sales (customer_id, order_date, product_id) VALUES
  ('A', '2021-01-01', 1), ('A', '2021-01-01', 2), ('A', '2021-01-07', 2),
  ('A', '2021-01-10', 3), ('A', '2021-01-11', 3), ('A', '2021-01-11', 3),
  ('B', '2021-01-01', 2), ('B', '2021-01-02', 2), ('B', '2021-01-04', 1),
  ('B', '2021-01-11', 1), ('B', '2021-01-16', 3), ('B', '2021-01-01', 3),
  ('C', '2021-01-01', 3), ('C', '2021-01-01', 3), ('C', '2021-01-07', 3);
   
SELECT COUNT(*) FROM sales;