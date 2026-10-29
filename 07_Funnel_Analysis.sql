-- =====================================================================
-- 07_Funnel_Analysis.sql
-- Chapter 7: Behavior Funnel Analysis
-- Flow: 7.1 Behavior overview -> 7.2 Funnel conversion
--       -> 7.3 Category add-to-cart rate
-- Path : 浏览 -> 点击 -> 收藏 -> 加购 -> 下单
-- =====================================================================

-- ---------------------------------------------------------------------
-- 7.1 Behavior overview: events, unique users, share, avg duration
-- ---------------------------------------------------------------------
SELECT behavior_type,
       COUNT(*)                                          AS 次数,
       COUNT(DISTINCT user_id)                           AS 用户数,
       ROUND(COUNT(*) * 100 / SUM(COUNT(*)) OVER (), 1)  AS 次数占比,
       ROUND(AVG(duration_seconds), 1)                   AS 平均停留秒数
FROM fact_behaviors
GROUP BY behavior_type
ORDER BY FIELD(behavior_type, '浏览', '点击', '收藏', '加购');

-- ---------------------------------------------------------------------
-- 7.2.2 Strict funnel: a user counts at step N only if they completed
-- ALL previous steps -> numbers are guaranteed to decrease.
-- Step 1: per-user flags (1/0) for each behavior
-- Step 2: cumulative AND across steps
-- Step 3: long format (one row per step) -> ready for a PowerBI funnel
-- ---------------------------------------------------------------------
WITH u AS (
    SELECT user_id,
           MAX(behavior_type = '浏览') AS v,      -- 1 if the user ever browsed
           MAX(behavior_type = '点击') AS c,
           MAX(behavior_type = '收藏') AS f,
           MAX(behavior_type = '加购') AS a
    FROM fact_behaviors
    GROUP BY user_id
),
o AS (
    SELECT DISTINCT user_id
    FROM fact_orders
    WHERE order_status IN ('已付款', '已发货', '已完成') AND is_abnormal = 0
),
s AS (
    SELECT SUM(v)                                              AS s1,
           SUM(v AND c)                                        AS s2,
           SUM(v AND c AND f)                                  AS s3,
           SUM(v AND c AND f AND a)                            AS s4,
           SUM(v AND c AND f AND a AND o.user_id IS NOT NULL)  AS s5
    FROM u
    LEFT JOIN o ON u.user_id = o.user_id
)
SELECT '1 浏览' AS 环节, s1 AS 人数, 100.00 AS 整体转化率, NULL AS 环节转化率 FROM s
UNION ALL SELECT '2 点击', s2, ROUND(s2 * 100 / s1, 2), ROUND(s2 * 100 / s1, 2) FROM s
UNION ALL SELECT '3 收藏', s3, ROUND(s3 * 100 / s1, 2), ROUND(s3 * 100 / s2, 2) FROM s
UNION ALL SELECT '4 加购', s4, ROUND(s4 * 100 / s1, 2), ROUND(s4 * 100 / s3, 2) FROM s
UNION ALL SELECT '5 下单', s5, ROUND(s5 * 100 / s1, 2), ROUND(s5 * 100 / s4, 2) FROM s;

-- ---------------------------------------------------------------------
-- 7.3 Add-to-cart rate by category (user-based)
-- cart_rate = users who carted / users who browsed, per category
-- NULLIF(x, 0) returns NULL when x = 0 -> avoids division by zero
-- ---------------------------------------------------------------------
SELECT p.category,
       COUNT(DISTINCT CASE WHEN b.behavior_type = '浏览' THEN b.user_id END) AS browse_users,
       COUNT(DISTINCT CASE WHEN b.behavior_type = '加购' THEN b.user_id END) AS cart_users,
       ROUND(COUNT(DISTINCT CASE WHEN b.behavior_type = '加购' THEN b.user_id END) * 100.0 /
             NULLIF(COUNT(DISTINCT CASE WHEN b.behavior_type = '浏览' THEN b.user_id END), 0), 2) AS cart_rate
FROM fact_behaviors b
JOIN dim_product p ON b.product_id = p.product_id
GROUP BY p.category
ORDER BY cart_rate DESC;

-- =====================================================================
-- Chapter 7 Summary
-- * Browsing = 65% of events, avg 2.5 min; other actions ~30 s
-- * Doc's method (independent counts) produced an inverted funnel
--   (order rate 81.9% > cart rate 37.7%) -> not a valid funnel.
-- * Strict funnel: 4103 -> 2304 -> 1006 -> 569 -> 538
--   Biggest drop-offs: browse->click (-44%), click->favorite (-56%)
--   -> optimize thumbnails/prices/recommendations and detail pages.
-- * Cart->order 94.6% is an artifact of the simulated data (orders and
--   behaviors generated independently); real-world is ~30-60%.
-- * Category cart rate: staples (fresh/snacks/dairy) 21-23%;
--   appliances/apparel/liquor 9-11%. 数码产品 tops but n = 112 only.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 7.4 Save strict funnel as a table for PowerBI
-- 序号 column lets PowerBI sort the steps in the right order.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS funnel_strict;

CREATE TABLE funnel_strict AS
WITH u AS (
    SELECT user_id,
           MAX(behavior_type = '浏览') AS v,
           MAX(behavior_type = '点击') AS c,
           MAX(behavior_type = '收藏') AS f,
           MAX(behavior_type = '加购') AS a
    FROM fact_behaviors
    GROUP BY user_id
),
o AS (
    SELECT DISTINCT user_id
    FROM fact_orders
    WHERE order_status IN ('已付款', '已发货', '已完成') AND is_abnormal = 0
),
s AS (
    SELECT SUM(v)                                             AS s1,
           SUM(v AND c)                                       AS s2,
           SUM(v AND c AND f)                                 AS s3,
           SUM(v AND c AND f AND a)                           AS s4,
           SUM(v AND c AND f AND a AND o.user_id IS NOT NULL) AS s5
    FROM u LEFT JOIN o ON u.user_id = o.user_id
)
SELECT 1 AS 序号, '浏览' AS 环节, s1 AS 人数 FROM s
UNION ALL SELECT 2, '点击', s2 FROM s
UNION ALL SELECT 3, '收藏', s3 FROM s
UNION ALL SELECT 4, '加购', s4 FROM s
UNION ALL SELECT 5, '下单', s5 FROM s;

SELECT * FROM funnel_strict;