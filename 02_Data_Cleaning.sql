-- =====================================================================
-- 02_Data_Cleaning.sql
-- Chapter 2: Data Cleaning
-- Flow: 2.0 Backup -> 2.1 Missing values -> 2.2 Outliers
--       -> 2.3 Data types -> 2.4 Column naming
-- WARNING: This file MODIFIES data (UPDATE / ALTER). Run 2.0 first.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 2.0 Backup raw orders table (run ONCE before any cleaning)
-- Restore if needed:
--   DROP TABLE orders;
--   CREATE TABLE orders AS SELECT * FROM orders_raw;
-- ---------------------------------------------------------------------
CREATE TABLE orders_raw AS SELECT * FROM orders;

-- Verify backup: should return 15000
SELECT COUNT(*) FROM orders_raw;

-- ---------------------------------------------------------------------
-- 2.1 Missing Value Handling
-- ---------------------------------------------------------------------

-- 2.1.1 Confirm the business meaning of NULLs
-- Group by order_status to check whether NULLs in delivery_date /
-- receive_date / review_* match the order lifecycle.
-- FIELD() returns the position of a value in the list -> custom sort order.
SELECT
    order_status,
    COUNT(*)                                               AS 订单数,
    SUM(CASE WHEN delivery_date  IS NULL THEN 1 ELSE 0 END) AS 无发货日期,
    SUM(CASE WHEN receive_date   IS NULL THEN 1 ELSE 0 END) AS 无收货日期,
    SUM(CASE WHEN review_score   IS NULL THEN 1 ELSE 0 END) AS 无评分,
    SUM(CASE WHEN review_content IS NULL THEN 1 ELSE 0 END) AS 无评价内容
FROM orders
GROUP BY order_status
ORDER BY FIELD(order_status, '待付款', '已付款', '已发货', '已完成', '已取消');

-- 2.1.2 Fill missing review fields
-- Only review_score / review_content are true "missing" (user didn't review).
-- delivery_date / receive_date NULLs reflect order status -> keep as NULL.
-- review_score = 0 means "not reviewed" (valid scores are 1~5).
UPDATE orders SET review_score   = 0        WHERE review_score   IS NULL;
UPDATE orders SET review_content = '未评价' WHERE review_content IS NULL;

-- Verify: both counts should be 7579
SELECT COUNT(*)                                                  AS 总订单数,
       SUM(CASE WHEN review_score   = 0        THEN 1 ELSE 0 END) AS 未评分订单数,
       SUM(CASE WHEN review_content = '未评价' THEN 1 ELSE 0 END) AS 无评价内容数
FROM orders;

-- ---------------------------------------------------------------------
-- 2.2 Outlier Handling
-- ---------------------------------------------------------------------

-- 2.2.1 Detect abnormal orders (original rule from the doc)
SELECT order_id, product_id, quantity, unit_price, total_amount
FROM orders
WHERE quantity <= 0 OR unit_price <= 0 OR total_amount <= 0;

-- 2.2.2 Improved rule: also check actual_payment
-- Some orders have normal quantity/total_amount but discount = total,
-- so actual_payment = 0 (likely test orders). The original rule misses them.
SELECT order_id, user_id, quantity, unit_price, total_amount,
       discount, actual_payment, order_status
FROM orders
WHERE quantity <= 0 OR unit_price <= 0
   OR total_amount <= 0 OR actual_payment <= 0;

-- 2.2.3 Flag abnormal orders instead of deleting them
-- is_abnormal = 1 -> exclude in later analysis with WHERE is_abnormal = 0
ALTER TABLE orders ADD COLUMN is_abnormal TINYINT DEFAULT 0;

UPDATE orders SET is_abnormal = 1
WHERE quantity <= 0 OR unit_price <= 0
   OR total_amount <= 0 OR actual_payment <= 0;

-- Verify: 0 -> 14962, 1 -> 38
SELECT is_abnormal, COUNT(*) AS 订单数
FROM orders
GROUP BY is_abnormal;

-- ---------------------------------------------------------------------
-- 2.3 Data Type Check
-- DESCRIBE shows each column's name, type, nullability, key and default.
-- Make sure amounts are DECIMAL, dates are DATE/DATETIME, counts are INT.
-- ---------------------------------------------------------------------
DESCRIBE orders;
DESCRIBE products;
DESCRIBE users;

-- ---------------------------------------------------------------------
-- 2.4 Column Naming Check
-- The doc's original ALTER renames English columns to Chinese
-- (e.g. view_count -> 浏览_count), which contradicts its own goal and
-- breaks 3.2. Skipped. Instead, verify all column names already follow
-- snake_case English (lowercase letters, digits, underscore only).
-- Expected: empty result -> all names are compliant.
-- ---------------------------------------------------------------------
SELECT TABLE_NAME, COLUMN_NAME
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'sam_analysis'
  AND COLUMN_NAME NOT REGEXP '^[a-z0-9_]+$';

-- =====================================================================
-- Chapter 2 Summary
-- * Backup   : orders_raw created (15000 rows)
-- * Missing  : review_score -> 0, review_content -> '未评价' (7579 rows);
--              delivery/receive_date NULLs kept (reflect order status)
--              NOTE: exclude review_score = 0 when averaging scores
-- * Outliers : 38 abnormal orders flagged via is_abnormal = 1
--              (8 zero-quantity + 30 zero-payment test orders)
--              NOTE: add WHERE is_abnormal = 0 in later analysis
-- * Types    : all columns have proper types (DECIMAL for money)
-- * Naming   : all columns already snake_case English; doc's 2.4 skipped
-- =====================================================================