-- =====================================================================
-- 03_Dimensional_Modeling.sql
-- Chapter 3: Dimensional Modeling (Star Schema)
-- Build 2 dimension tables + 2 fact tables from the 6 cleaned raw tables:
--   dim_user       = users    + user_features
--   dim_product    = products + product_features
--   fact_orders    = orders          (incl. is_abnormal flag)
--   fact_behaviors = user_behaviors
-- Re-runnable: each table is dropped and rebuilt.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 3.1 dim_user: merge users + user_features on user_id
-- LEFT JOIN keeps every user even if no feature row exists.
-- Expected: 5000 rows
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS dim_user;

CREATE TABLE dim_user AS
SELECT u.user_id, u.age, u.gender, u.province, u.city,
       u.registration_date, u.member_level, u.account_balance, u.credit_score,
       uf.total_spent, uf.order_count, uf.completed_orders, uf.avg_order_amount,
       uf.browse_count, uf.click_count, uf.favorite_count, uf.cart_count,
       uf.consumption_level, uf.member_level_score
FROM users u
LEFT JOIN user_features uf ON u.user_id = uf.user_id;

-- CREATE TABLE ... AS does not copy keys; add PK for faster joins
ALTER TABLE dim_user ADD PRIMARY KEY (user_id);

SELECT COUNT(*) FROM dim_user;

-- ---------------------------------------------------------------------
-- 3.2 dim_product: merge products + product_features on product_id
-- Works because doc's 2.4 rename was skipped (view_count etc. intact).
-- Expected: 2000 rows
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS dim_product;

CREATE TABLE dim_product AS
SELECT p.product_id, p.product_name, p.category, p.brand, p.price, p.sales_count,
       pf.total_revenue, pf.total_sales, pf.completed_count, pf.cancel_count,
       pf.add_to_cart_count, pf.favorite_count, pf.view_count, pf.click_count,
       pf.conversion_rate, pf.avg_review_score, pf.popularity_score
FROM products p
LEFT JOIN product_features pf ON p.product_id = pf.product_id;

ALTER TABLE dim_product ADD PRIMARY KEY (product_id);

SELECT COUNT(*) FROM dim_product;

-- ---------------------------------------------------------------------
-- 3.2 dim_product: merge products + product_features on product_id
-- Works because doc's 2.4 rename was skipped (view_count etc. intact).
-- Expected: 2000 rows
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS dim_product;

CREATE TABLE dim_product AS
SELECT p.product_id, p.product_name, p.category, p.brand, p.price, p.sales_count,
       pf.total_revenue, pf.total_sales, pf.completed_count, pf.cancel_count,
       pf.add_to_cart_count, pf.favorite_count, pf.view_count, pf.click_count,
       pf.conversion_rate, pf.avg_review_score, pf.popularity_score
FROM products p
LEFT JOIN product_features pf ON p.product_id = pf.product_id;

ALTER TABLE dim_product ADD PRIMARY KEY (product_id);

SELECT COUNT(*) FROM dim_product;

-- ---------------------------------------------------------------------
-- 3.3 fact_orders: copy of cleaned orders (one row per order)
-- Includes is_abnormal from 2.2 -> filter with WHERE is_abnormal = 0
-- Expected: 15000 rows, 16 columns
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS fact_orders;

CREATE TABLE fact_orders AS SELECT * FROM orders;

ALTER TABLE fact_orders ADD PRIMARY KEY (order_id);

SELECT COUNT(*) AS cnt FROM fact_orders;

-- ---------------------------------------------------------------------
-- 3.4 fact_behaviors: copy of user_behaviors (one row per event)
-- Fixed doc typo: "SELECT * cnt" -> "SELECT COUNT(*) AS cnt"
-- Expected: 30000 rows
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS fact_behaviors;

CREATE TABLE fact_behaviors AS SELECT * FROM user_behaviors;

ALTER TABLE fact_behaviors ADD PRIMARY KEY (behavior_id);

SELECT COUNT(*) AS cnt FROM fact_behaviors;

-- Behavior type distribution
SELECT behavior_type, COUNT(*) AS 次数,
       ROUND(COUNT(*) * 100 / SUM(COUNT(*)) OVER (), 1) AS 占比
FROM fact_behaviors
GROUP BY behavior_type
ORDER BY 次数 DESC;

-- ---------------------------------------------------------------------
-- 3.5 Star schema overview
-- ---------------------------------------------------------------------
-- Row counts. Expected: 5000 | 2000 | 15000 | 30000
SELECT 'dim_user' AS 表名, COUNT(*) AS 记录数, '维度表' AS 类型 FROM dim_user
UNION ALL SELECT 'dim_product',    COUNT(*), '维度表' FROM dim_product
UNION ALL SELECT 'fact_orders',    COUNT(*), '事实表' FROM fact_orders
UNION ALL SELECT 'fact_behaviors', COUNT(*), '事实表' FROM fact_behaviors;

-- Join test: every fact row should find its user and product.
-- Expected: 15000 (no rows lost in the join)
SELECT COUNT(*) AS 关联后订单数
FROM fact_orders o
JOIN dim_user    u ON o.user_id    = u.user_id
JOIN dim_product p ON o.product_id = p.product_id;

-- =====================================================================
-- Chapter 3 Summary
-- * dim_user (5000) / dim_product (2000): merged attributes + features
-- * fact_orders (15000) / fact_behaviors (30000): event-level facts
-- * Primary keys added to all 4 tables; fact-to-dim joins 100% intact
-- * Why star schema: filters on dims propagate to facts automatically
--   in PowerBI; measures (e.g. SUM(actual_payment)) are written once
--   and reused across all visuals.
-- =====================================================================