-- =====================================================================
-- 00_setup_and_import.sql
-- Sam's Club Customer Spending Analysis
-- Purpose : Create the database, define 6 raw tables, and load CSV data
-- Engine  : MySQL 8.0+
-- =====================================================================


-- ---------------------------------------------------------------------
-- Step 1. Create database and switch to it
-- ---------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS sam_analysis DEFAULT CHARSET utf8mb4;
USE sam_analysis;


-- ---------------------------------------------------------------------
-- Step 2. Create tables
-- ---------------------------------------------------------------------

-- Users: basic demographic and membership info (dimension)
CREATE TABLE users (
    user_id           VARCHAR(10) PRIMARY KEY,  -- unique user ID, e.g. U00001
    age               INT,                      -- user age
    gender            VARCHAR(4),               -- 男 / 女
    province          VARCHAR(20),              -- province of residence
    city              VARCHAR(20),              -- city of residence
    registration_date DATE,                     -- account sign-up date
    member_level      VARCHAR(10),              -- membership tier (普通/铜牌/银牌/金牌/钻石)
    account_balance   DECIMAL(12,2),            -- stored-value balance
    credit_score      INT                       -- credit score (350-950)
);

-- User features: aggregated spending and behavior metrics per user
CREATE TABLE user_features (
    user_id            VARCHAR(10) PRIMARY KEY, -- links to users.user_id
    total_spent        DECIMAL(14,2),           -- total amount paid
    order_count        INT,                     -- number of orders placed
    completed_orders   INT,                     -- number of completed orders
    avg_order_amount   DECIMAL(12,2),           -- average order value
    browse_count       INT,                     -- number of browse events
    click_count        INT,                     -- number of click events
    favorite_count     INT,                     -- number of favorite events
    cart_count         INT,                     -- number of add-to-cart events
    consumption_level  VARCHAR(4),              -- spending level: 低 / 中 / 高
    member_level_score INT                      -- membership tier as score (1-5)
);

-- Products: basic product attributes (dimension)
CREATE TABLE products (
    product_id   VARCHAR(10) PRIMARY KEY,       -- unique product ID, e.g. P00001
    product_name VARCHAR(100),                  -- product name
    category     VARCHAR(20),                   -- product category
    brand        VARCHAR(30),                   -- brand name
    price        DECIMAL(10,2),                 -- list price
    sales_count  INT                            -- historical units sold
);

-- Product features: aggregated sales and engagement metrics per product
CREATE TABLE product_features (
    product_id        VARCHAR(10) PRIMARY KEY,  -- links to products.product_id
    total_revenue     DECIMAL(14,2),            -- total revenue
    total_sales       INT,                      -- total units sold
    completed_count   INT,                      -- number of completed orders
    cancel_count      INT,                      -- number of cancelled orders
    add_to_cart_count INT,                      -- number of add-to-cart events
    favorite_count    INT,                      -- number of favorite events
    view_count        INT,                      -- number of page views
    click_count       INT,                      -- number of clicks
    conversion_rate   DECIMAL(6,4),             -- sales / views
    avg_review_score  DECIMAL(4,2),             -- average review score
    popularity_score  DECIMAL(6,2)              -- popularity index (0-100)
);

-- Orders: one row per order (fact table)
CREATE TABLE orders (
    order_id       VARCHAR(10) PRIMARY KEY,     -- unique order ID, e.g. O000001
    user_id        VARCHAR(10),                 -- FK -> users.user_id
    product_id     VARCHAR(10),                 -- FK -> products.product_id
    quantity       INT,                         -- units purchased
    order_date     DATETIME,                    -- order timestamp
    order_status   VARCHAR(10),                 -- 待付款/已付款/已发货/已完成/已取消
    payment_method VARCHAR(10),                 -- payment channel
    unit_price     DECIMAL(10,2),               -- price per unit
    total_amount   DECIMAL(12,2),               -- quantity * unit_price
    discount       DECIMAL(12,2),               -- discount amount
    actual_payment DECIMAL(12,2),               -- total_amount - discount
    delivery_date  DATE NULL,                   -- NULL if not yet shipped
    receive_date   DATE NULL,                   -- NULL if not yet received
    review_score   INT NULL,                    -- 1-5, NULL if not reviewed
    review_content VARCHAR(200) NULL            -- review text, NULL if not reviewed
);

-- User behaviors: one row per browse/click/favorite/cart event (fact table)
CREATE TABLE user_behaviors (
    behavior_id      VARCHAR(10) PRIMARY KEY,   -- unique event ID, e.g. B000001
    user_id          VARCHAR(10),               -- FK -> users.user_id
    product_id       VARCHAR(10),               -- FK -> products.product_id
    behavior_type    VARCHAR(10),               -- 浏览 / 点击 / 收藏 / 加购
    behavior_time    DATETIME,                  -- event timestamp
    duration_seconds INT                        -- time spent on page (seconds)
);


-- ---------------------------------------------------------------------
-- Step 3. Load CSV data
-- Prerequisites:
--   1) Server side : SET GLOBAL local_infile = 1 (below)
--   2) Client side : DataGrip -> Data Source Properties -> Advanced
--                    -> allowLoadLocalInfile = true, then reconnect
-- Common options:
--   FIELDS TERMINATED BY ','       -> comma-separated values
--   OPTIONALLY ENCLOSED BY '"'     -> strip surrounding double quotes
--   LINES TERMINATED BY '\r\n'     -> Windows line endings
--   IGNORE 1 LINES                 -> skip the header row
-- ---------------------------------------------------------------------

-- Allow the server to accept local file uploads
SET GLOBAL local_infile = 1;

-- Load users
LOAD DATA LOCAL INFILE 'C:/Users/pbcs/Desktop/山姆用户消费数据集/users.csv'
INTO TABLE users
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES;

-- Quick sanity check: preview first 10 rows (Chinese text should display correctly)
SELECT * FROM users LIMIT 10;

-- Load user_features
LOAD DATA LOCAL INFILE 'C:/Users/pbcs/Desktop/山姆用户消费数据集/user_features.csv'
INTO TABLE user_features
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES;

-- Load products
LOAD DATA LOCAL INFILE 'C:/Users/pbcs/Desktop/山姆用户消费数据集/products.csv'
INTO TABLE products
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES;

-- Load product_features
LOAD DATA LOCAL INFILE 'C:/Users/pbcs/Desktop/山姆用户消费数据集/product_features.csv'
INTO TABLE product_features
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES;

-- Load user_behaviors
LOAD DATA LOCAL INFILE 'C:/Users/pbcs/Desktop/山姆用户消费数据集/user_behaviors.csv'
INTO TABLE user_behaviors
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES;

-- Load orders
-- Note: empty strings in the CSV must become NULL, otherwise DATE/INT columns
-- will reject them. Read the nullable columns into user variables (@var) first,
-- then convert '' to NULL with NULLIF() in the SET clause.
LOAD DATA LOCAL INFILE 'C:/Users/pbcs/Desktop/山姆用户消费数据集/orders.csv'
INTO TABLE orders
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(order_id, user_id, product_id, quantity, order_date, order_status, payment_method,
 unit_price, total_amount, discount, actual_payment,
 @delivery_date, @receive_date, @review_score, @review_content)
SET delivery_date  = NULLIF(@delivery_date, ''),
    receive_date   = NULLIF(@receive_date, ''),
    review_score   = NULLIF(@review_score, ''),
    review_content = NULLIF(@review_content, '');

-- ---------------------------------------------------------------------
-- Step 4. Verify row counts
-- Expected: orders 15000 | product_features 2000 | products 2000
--           user_behaviors 30000 | user_features 5000 | users 5000
-- ---------------------------------------------------------------------
SELECT 'orders' AS 表名, COUNT(*) AS 记录数 FROM orders
UNION ALL SELECT 'product_features', COUNT(*) FROM product_features
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'user_behaviors', COUNT(*) FROM user_behaviors
UNION ALL SELECT 'user_features', COUNT(*) FROM user_features
UNION ALL SELECT 'users', COUNT(*) FROM users;



-- =====================================================================
-- Dataset Overview
-- Purpose : Summarize each raw table with row count, column count,
--           and a short description (fact / dimension / feature table)
-- Output  : 表名 | 记录数 | 字段数 | 说明
-- =====================================================================
SELECT
    t.表名,                                          -- table name
    t.记录数,                                        -- row count (from subquery t)
    c.字段数,                                        -- column count (from subquery c)
    -- Map each table name to a human-readable description
    CASE t.表名
        WHEN 'orders'           THEN '订单事实表'      -- order fact table
        WHEN 'products'         THEN '商品维度表'      -- product dimension table
        WHEN 'product_features' THEN '商品特征表'      -- product feature table
        WHEN 'users'            THEN '用户维度表'      -- user dimension table
        WHEN 'user_features'    THEN '用户特征表'      -- user feature table
        WHEN 'user_behaviors'   THEN '用户行为事实表'  -- user behavior fact table
    END AS 说明
FROM (
    -- Subquery t: row count of each table
    -- The extra "排序" column fixes the display order of the final result
    SELECT 'orders' AS 表名, COUNT(*) AS 记录数, 1 AS 排序 FROM orders
    UNION ALL SELECT 'products',         COUNT(*), 2 FROM products
    UNION ALL SELECT 'product_features', COUNT(*), 3 FROM product_features
    UNION ALL SELECT 'users',            COUNT(*), 4 FROM users
    UNION ALL SELECT 'user_features',    COUNT(*), 5 FROM user_features
    UNION ALL SELECT 'user_behaviors',   COUNT(*), 6 FROM user_behaviors
) t
JOIN (
    -- Subquery c: column count of each table
    -- information_schema.COLUMNS is a MySQL system view that lists
    -- every column of every table in the server
    SELECT TABLE_NAME, COUNT(*) AS 字段数
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = 'sam_analysis'          -- only tables in our database
    GROUP BY TABLE_NAME
) c
-- Join t and c on table name.
-- information_schema uses utf8mb3 while our literals are utf8mb4;
-- CONVERT(... USING utf8mb4) unifies the charset to avoid a collation error.
ON CONVERT(c.TABLE_NAME USING utf8mb4) = t.表名
ORDER BY t.排序;                                 -- keep the predefined table order


-- =====================================================================
-- 01_data_exploration.sql
-- Chapter 1: Data Exploration & Quality Check
-- Flow: 1.1 Overview -> 1.2 Missing values -> 1.3 Outliers
--       -> 1.4 Duplicates -> 1.5 Referential integrity
-- Note: Read-only queries. Nothing in this file modifies data.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1.2 Missing Value Check
-- ---------------------------------------------------------------------

-- 1.2.1 orders: count NULLs in every column
-- CASE WHEN col IS NULL THEN 1 END returns 1 for NULL, otherwise NULL.
-- COUNT() ignores NULLs, so the result equals the number of missing values.
-- Expected: 0 for core columns;
--           delivery_date 3027 | receive_date 4552 | review_* 7579
--           (business-driven gaps: unshipped / unreceived / unreviewed orders)
SELECT
    COUNT(CASE WHEN order_id       IS NULL THEN 1 END) AS missing_order_id,
    COUNT(CASE WHEN user_id        IS NULL THEN 1 END) AS missing_user_id,
    COUNT(CASE WHEN product_id     IS NULL THEN 1 END) AS missing_product_id,
    COUNT(CASE WHEN quantity       IS NULL THEN 1 END) AS missing_quantity,
    COUNT(CASE WHEN order_date     IS NULL THEN 1 END) AS missing_order_date,
    COUNT(CASE WHEN order_status   IS NULL THEN 1 END) AS missing_order_status,
    COUNT(CASE WHEN payment_method IS NULL THEN 1 END) AS missing_payment_method,
    COUNT(CASE WHEN unit_price     IS NULL THEN 1 END) AS missing_unit_price,
    COUNT(CASE WHEN total_amount   IS NULL THEN 1 END) AS missing_total_amount,
    COUNT(CASE WHEN discount       IS NULL THEN 1 END) AS missing_discount,
    COUNT(CASE WHEN actual_payment IS NULL THEN 1 END) AS missing_actual_payment,
    COUNT(CASE WHEN delivery_date  IS NULL THEN 1 END) AS missing_delivery_date,
    COUNT(CASE WHEN receive_date   IS NULL THEN 1 END) AS missing_receive_date,
    COUNT(CASE WHEN review_score   IS NULL THEN 1 END) AS missing_review_score,
    COUNT(CASE WHEN review_content IS NULL THEN 1 END) AS missing_review_content
FROM orders;

-- 1.2.2 Other tables: check 3 key columns per table
-- SUM(CASE ... THEN 1 ELSE 0 END) is an equivalent way to count NULLs.
-- UNION ALL stacks results vertically; all SELECTs must have the same
-- number of columns. Column headers come from the FIRST SELECT only,
-- so read the 3 null-count columns according to each table's own fields.
-- Expected: all zeros.

-- products: product_name / category / brand
SELECT 'products' AS 表名,
       COUNT(*) AS 总数,
       SUM(CASE WHEN product_name IS NULL THEN 1 ELSE 0 END) AS name_null,
       SUM(CASE WHEN category     IS NULL THEN 1 ELSE 0 END) AS category_null,
       SUM(CASE WHEN brand        IS NULL THEN 1 ELSE 0 END) AS brand_null
FROM products
UNION ALL
-- users: age / gender / province
SELECT 'users', COUNT(*),
       SUM(CASE WHEN age      IS NULL THEN 1 ELSE 0 END),
       SUM(CASE WHEN gender   IS NULL THEN 1 ELSE 0 END),
       SUM(CASE WHEN province IS NULL THEN 1 ELSE 0 END)
FROM users
UNION ALL
-- user_features: total_spent / order_count / consumption_level
SELECT 'user_features', COUNT(*),
       SUM(CASE WHEN total_spent       IS NULL THEN 1 ELSE 0 END),
       SUM(CASE WHEN order_count       IS NULL THEN 1 ELSE 0 END),
       SUM(CASE WHEN consumption_level IS NULL THEN 1 ELSE 0 END)
FROM user_features
UNION ALL
-- product_features: total_revenue / conversion_rate / avg_review_score
SELECT 'product_features', COUNT(*),
       SUM(CASE WHEN total_revenue    IS NULL THEN 1 ELSE 0 END),
       SUM(CASE WHEN conversion_rate  IS NULL THEN 1 ELSE 0 END),
       SUM(CASE WHEN avg_review_score IS NULL THEN 1 ELSE 0 END)
FROM product_features
UNION ALL
-- user_behaviors: user_id / behavior_type / behavior_time
SELECT 'user_behaviors', COUNT(*),
       SUM(CASE WHEN user_id       IS NULL THEN 1 ELSE 0 END),
       SUM(CASE WHEN behavior_type IS NULL THEN 1 ELSE 0 END),
       SUM(CASE WHEN behavior_time IS NULL THEN 1 ELSE 0 END)
FROM user_behaviors;


-- ---------------------------------------------------------------------
-- 1.3 Outlier Check
-- Look at MIN / MAX of numeric and time columns to spot unreasonable
-- values (e.g. negative quantity, zero price, age 200).
-- ---------------------------------------------------------------------

-- 1.3.1 orders: quantity / unit_price / actual_payment
-- Expected: quantity 0~5, unit_price 10~8895.2, actual_payment 0~11490.2
-- Finding : MIN = 0 for quantity and actual_payment -> a few abnormal
--           (test / zero-value) orders exist; handled in 2.2.
SELECT MIN(quantity)       AS q_min,   MAX(quantity)       AS q_max,
       MIN(unit_price)     AS p_min,   MAX(unit_price)     AS p_max,
       MIN(actual_payment) AS amt_min, MAX(actual_payment) AS amt_max
FROM orders;

-- 1.3.2 users: age / account_balance
-- Expected: age 18~65, balance 12~50000 -> reasonable
SELECT MIN(age)             AS a_min, MAX(age)             AS a_max,
       MIN(account_balance) AS b_min, MAX(account_balance) AS b_max
FROM users;

-- 1.3.3 products: price / sales_count
-- Expected: price 10~8895.2, sales_count 1~368 -> reasonable
SELECT MIN(price)       AS p_min, MAX(price)       AS p_max,
       MIN(sales_count) AS s_min, MAX(sales_count) AS s_max
FROM products;

-- 1.3.4 user_behaviors: behavior_time / duration_seconds
-- Expected: 2025-10-01 ~ 2026-09-30, duration 1~300s -> reasonable
SELECT MIN(behavior_time)    AS time_min, MAX(behavior_time)    AS time_max,
       MIN(duration_seconds) AS d_min,    MAX(duration_seconds) AS d_max
FROM user_behaviors;


-- ---------------------------------------------------------------------
-- 1.4 Duplicate Check
-- Compare total rows with distinct primary-key values.
-- 总数 = 唯一数 means no duplicates, so later JOINs won't double-count.
-- Expected: equal for every table.
-- ---------------------------------------------------------------------
SELECT 'orders'           AS 表名, COUNT(*) AS 总数, COUNT(DISTINCT order_id)    AS 唯一数 FROM orders
UNION ALL SELECT 'products',         COUNT(*), COUNT(DISTINCT product_id)  FROM products
UNION ALL SELECT 'product_features', COUNT(*), COUNT(DISTINCT product_id)  FROM product_features
UNION ALL SELECT 'users',            COUNT(*), COUNT(DISTINCT user_id)     FROM users
UNION ALL SELECT 'user_features',    COUNT(*), COUNT(DISTINCT user_id)     FROM user_features
UNION ALL SELECT 'user_behaviors',   COUNT(*), COUNT(DISTINCT behavior_id) FROM user_behaviors;

-- ---------------------------------------------------------------------
-- 1.5 Referential Integrity Check
-- Make sure every foreign key in the fact tables points to an existing
-- record in the dimension tables (no "orphan" orders or behaviors).
-- LEFT JOIN keeps all rows from the left table; unmatched rows get NULL
-- on the right side, and COUNT() ignores NULL.
-- 出现数 = 匹配数 means 100% matched.
-- Expected: 3802/3802 | 1720/1720 | 4462/4462 | 1853/1853
-- ---------------------------------------------------------------------
-- orders.user_id -> users.user_id
SELECT 'orders → users' AS 关联,
       COUNT(DISTINCT o.user_id) AS 出现数,
       COUNT(DISTINCT u.user_id) AS 匹配数
FROM orders o LEFT JOIN users u ON o.user_id = u.user_id
UNION ALL
-- orders.product_id -> products.product_id
SELECT 'orders → products',
       COUNT(DISTINCT o.product_id), COUNT(DISTINCT p.product_id)
FROM orders o LEFT JOIN products p ON o.product_id = p.product_id
UNION ALL
-- user_behaviors.user_id -> users.user_id
SELECT 'user_behaviors → users',
       COUNT(DISTINCT b.user_id), COUNT(DISTINCT u.user_id)
FROM user_behaviors b LEFT JOIN users u ON b.user_id = u.user_id
UNION ALL
-- user_behaviors.product_id -> products.product_id
SELECT 'user_behaviors → products',
       COUNT(DISTINCT b.product_id), COUNT(DISTINCT p.product_id)
FROM user_behaviors b LEFT JOIN products p ON b.product_id = p.product_id;


-- =====================================================================
-- Chapter 1 Summary
-- * 6 tables, structure complete; primary keys unique; FKs 100% matched
-- * Core fields have no missing values; only delivery_date, receive_date
--   and review fields have business-driven NULLs (verified in 2.1)
-- * A small number of orders have quantity = 0 or actual_payment = 0
--   -> to be handled in 2.2 Outlier Handling
-- =====================================================================