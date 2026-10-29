-- =====================================================================
-- 06_Product_Analysis.sql
-- Chapter 6: Product Analysis
-- Flow: 6.1 Category -> 6.2 Brand TOP10 -> 6.3 Price band
--       -> 6.4 Conversion rate
-- Revenue scope: valid orders only (已付款/已发货/已完成, is_abnormal = 0)
--   -> consistent with RFM in Chapter 5 (total GMV = 2,838,856.14)
-- =====================================================================

-- ---------------------------------------------------------------------
-- 6.1 Category analysis
-- Fix vs doc: the doc joined fact_orders directly, so each product was
-- repeated once per order and AVG(conversion_rate) got weighted by
-- order count (JOIN fan-out). Here orders are pre-aggregated to ONE row
-- per product in subquery o, then joined -> no duplication.
-- ---------------------------------------------------------------------
SELECT p.category,
       COUNT(*)                                                      AS 商品数,
       SUM(o.order_cnt)                                              AS 订单数,
       ROUND(SUM(o.revenue), 2)                                      AS 销售额,
       ROUND(SUM(o.revenue) * 100 / SUM(SUM(o.revenue)) OVER (), 1)  AS 销售额占比,
       ROUND(SUM(o.revenue) / SUM(o.order_cnt), 2)                   AS 客单价,
       ROUND(AVG(p.conversion_rate), 4)                              AS 平均转化率
FROM dim_product p
LEFT JOIN (
    SELECT product_id,
           COUNT(*)            AS order_cnt,
           SUM(actual_payment) AS revenue
    FROM fact_orders
    WHERE order_status IN ('已付款', '已发货', '已完成')
      AND is_abnormal = 0
    GROUP BY product_id
) o ON p.product_id = o.product_id
GROUP BY p.category
ORDER BY 销售额 DESC;

-- ---------------------------------------------------------------------
-- 6.2 Brand TOP10 by revenue (same pre-aggregation pattern as 6.1)
-- ---------------------------------------------------------------------
SELECT p.brand,
       COUNT(*)                                                      AS 商品数,
       SUM(o.order_cnt)                                              AS 订单数,
       ROUND(SUM(o.revenue), 2)                                      AS 销售额,
       ROUND(SUM(o.revenue) * 100 / SUM(SUM(o.revenue)) OVER (), 1)  AS 销售额占比,
       ROUND(SUM(o.revenue) / SUM(o.order_cnt), 2)                   AS 客单价
FROM dim_product p
LEFT JOIN (
    SELECT product_id, COUNT(*) AS order_cnt, SUM(actual_payment) AS revenue
    FROM fact_orders
    WHERE order_status IN ('已付款', '已发货', '已完成') AND is_abnormal = 0
    GROUP BY product_id
) o ON p.product_id = o.product_id
GROUP BY p.brand
ORDER BY 销售额 DESC
LIMIT 10;

-- ---------------------------------------------------------------------
-- 6.3 Price band
-- Fix vs doc: BETWEEN boundaries overlapped (e.g. 500 in two bands);
-- use half-open ranges with "<". Added units sold & revenue share,
-- since product count alone says little about sales.
-- ---------------------------------------------------------------------
SELECT
    CASE WHEN p.price < 100  THEN '低价(<100)'
         WHEN p.price < 500  THEN '中价(100-500)'
         WHEN p.price < 1000 THEN '中高价(500-1000)'
         WHEN p.price < 3000 THEN '高价(1000-3000)'
         ELSE '超高价(3000+)' END                                     AS price_range,
    COUNT(*)                                                         AS 商品数,
    ROUND(COUNT(*) * 100 / SUM(COUNT(*)) OVER (), 2)                 AS 商品占比,
    SUM(o.units)                                                     AS 销量,
    ROUND(SUM(o.units) * 100 / SUM(SUM(o.units)) OVER (), 1)         AS 销量占比,
    ROUND(SUM(o.revenue) * 100 / SUM(SUM(o.revenue)) OVER (), 1)     AS 销售额占比
FROM dim_product p
LEFT JOIN (
    SELECT product_id, SUM(quantity) AS units, SUM(actual_payment) AS revenue
    FROM fact_orders
    WHERE order_status IN ('已付款', '已发货', '已完成') AND is_abnormal = 0
    GROUP BY product_id
) o ON p.product_id = o.product_id
GROUP BY price_range
ORDER BY MIN(p.price);

-- ---------------------------------------------------------------------
-- 6.4.1 Conversion rate distribution
-- Fix vs doc: COUNT() -> COUNT(*) (syntax error in original)
-- ---------------------------------------------------------------------
SELECT
    CASE WHEN conversion_rate = 1    THEN '100%'
         WHEN conversion_rate >= 0.5 THEN '50%-100%'
         WHEN conversion_rate >= 0.1 THEN '10%-50%'
         WHEN conversion_rate > 0    THEN '0%-10%'
         ELSE '无转化' END                                  AS rate_range,
    COUNT(*)                                               AS 商品数,
    ROUND(COUNT(*) * 100 / SUM(COUNT(*)) OVER (), 2)       AS 商品占比
FROM dim_product
GROUP BY rate_range
ORDER BY 商品数 DESC;

-- Why do some products convert at 100%? Look at their view counts.
SELECT product_id, product_name, view_count, total_sales, conversion_rate
FROM dim_product
WHERE conversion_rate = 1
ORDER BY view_count
LIMIT 10;

-- ---------------------------------------------------------------------
-- 6.4.2 Effective conversion rate by category
-- Fix vs doc: 浏览_count -> view_count (2.4 rename was skipped)
-- 平均转化率: simple average of per-product rates -> skewed by tiny
--            samples (1 view, 1 sale = 100%)
-- 有效转化率: SUM(sales) / SUM(views) over products with >= 10 views
--            -> weighted by traffic, much more reliable
-- ---------------------------------------------------------------------
SELECT category,
       COUNT(*)                                       AS 商品数,
       SUM(view_count)                                AS 总浏览量,
       SUM(total_sales)                               AS 总销量,
       ROUND(AVG(conversion_rate), 4)                 AS 平均转化率,
       ROUND(SUM(CASE WHEN view_count >= 10 THEN total_sales ELSE 0 END) * 1.0 /
             SUM(CASE WHEN view_count >= 10 THEN view_count  ELSE 0 END), 4) AS 有效转化率
FROM dim_product
GROUP BY category
ORDER BY 有效转化率 DESC;

-- =====================================================================
-- Chapter 6 Summary
-- * Category: TOP3 (肉禽水产/生鲜果蔬/家用电器) = 41.4% of revenue.
--   Two models: fresh & snacks win on volume (AOV ~100-280),
--   appliances & digital win on AOV (~1900) with few orders.
-- * Brand   : Member's Mark (private label) = 13.9% of revenue,
--   3x the #2 brand -> Sam's core competitive advantage.
-- * Price   : <100 drives 64.9% of units; 100-500 drives 46.5% of
--   revenue -> the core price band.
-- * CVR     : 100% rates come from tiny samples (1~6 views).
--   Traffic-weighted CVR: staples ~10%, digital/apparel ~6%.
-- * SQL lessons: pre-aggregate before JOIN to avoid fan-out;
--   half-open ranges for bands; weighted > simple average for rates.
-- =====================================================================