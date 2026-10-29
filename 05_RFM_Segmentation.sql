-- =====================================================================
-- 05_RFM_Segmentation.sql
-- Chapter 5: RFM User Segmentation
-- Flow: 5.1 Compute R/F/M -> 5.2 Score 1~5 -> 5.3 Segment into 8 groups
-- Output tables: rfm_raw, rfm_score, rfm_segments (used by PowerBI later)
-- =====================================================================

-- ---------------------------------------------------------------------
-- 5.1 Compute R / F / M per user
-- R = days since last order (reference date fixed at 2026-10-01,
--     the day after the data ends, so results are reproducible)
-- F = number of valid orders
-- M = total actual payment
-- Valid orders: paid / shipped / completed, excluding abnormal ones.
-- Changes vs doc: CURRENT_DATE() -> fixed date; delivery_date ->
--     order_date (real in our data); added is_abnormal = 0.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS rfm_raw;

CREATE TABLE rfm_raw AS
SELECT user_id,
       DATEDIFF('2026-10-01', MAX(order_date)) AS recency,
       COUNT(DISTINCT order_id)                AS frequency,
       ROUND(SUM(actual_payment), 2)           AS monetary
FROM fact_orders
WHERE order_status IN ('已付款', '已发货', '已完成')
  AND is_abnormal = 0
GROUP BY user_id;

-- Check: 3652 users; top spenders
SELECT COUNT(*) FROM rfm_raw;
SELECT * FROM rfm_raw ORDER BY monetary DESC LIMIT 10;

-- ---------------------------------------------------------------------
-- 5.2 Score R / F / M on a 1~5 scale (5 = best)
-- PERCENT_RANK() = (rank - 1) / (total - 1), ranges 0~1.
-- R: ascending order, small recency = recent -> low pct -> HIGH score
-- F/M: high value -> high pct -> HIGH score
-- Why PERCENT_RANK over NTILE: tied values (e.g. many users with
-- frequency = 1) always get the same score; NTILE may split them.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS rfm_score;

CREATE TABLE rfm_score AS
WITH rfm_pct AS (
    SELECT user_id, recency, frequency, monetary,
           PERCENT_RANK() OVER (ORDER BY recency)   AS r_pct,
           PERCENT_RANK() OVER (ORDER BY frequency) AS f_pct,
           PERCENT_RANK() OVER (ORDER BY monetary)  AS m_pct
    FROM rfm_raw
)
SELECT user_id, recency, frequency, monetary,
       CASE WHEN r_pct <= 0.2 THEN 5
            WHEN r_pct <= 0.4 THEN 4
            WHEN r_pct <= 0.6 THEN 3
            WHEN r_pct <= 0.8 THEN 2
            ELSE 1 END AS r_score,
       CASE WHEN f_pct >= 0.8 THEN 5
            WHEN f_pct >= 0.6 THEN 4
            WHEN f_pct >= 0.4 THEN 3
            WHEN f_pct >= 0.2 THEN 2
            ELSE 1 END AS f_score,
       CASE WHEN m_pct >= 0.8 THEN 5
            WHEN m_pct >= 0.6 THEN 4
            WHEN m_pct >= 0.4 THEN 3
            WHEN m_pct >= 0.2 THEN 2
            ELSE 1 END AS m_score
FROM rfm_pct;

-- Score distribution check
SELECT 'R' AS 指标, r_score AS 分数, COUNT(*) AS 人数 FROM rfm_score GROUP BY r_score
UNION ALL SELECT 'F', f_score, COUNT(*) FROM rfm_score GROUP BY f_score
UNION ALL SELECT 'M', m_score, COUNT(*) FROM rfm_score GROUP BY m_score
ORDER BY 指标, 分数;

-- ---------------------------------------------------------------------
-- 5.3 Segment users into 8 groups
-- High = score >= 4. 2 (R) x 2 (F) x 2 (M) = 8 segments.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS rfm_segments;

CREATE TABLE rfm_segments AS
SELECT user_id, recency, frequency, monetary, r_score, f_score, m_score,
       CASE WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN '重要价值用户'
            WHEN r_score >= 4 AND f_score >= 4 AND m_score <  4 THEN '重要发展用户'
            WHEN r_score >= 4 AND f_score <  4 AND m_score >= 4 THEN '重要保持用户'
            WHEN r_score >= 4 AND f_score <  4 AND m_score <  4 THEN '新用户'
            WHEN r_score <  4 AND f_score >= 4 AND m_score >= 4 THEN '重要挽留用户'
            WHEN r_score <  4 AND f_score >= 4 AND m_score <  4 THEN '一般维持用户'
            WHEN r_score <  4 AND f_score <  4 AND m_score >= 4 THEN '一般价值用户'
            ELSE '流失用户' END AS user_segment
FROM rfm_score;

-- Segment summary: user share vs GMV share
SELECT user_segment,
       COUNT(*)                                                      AS 人数,
       ROUND(COUNT(*) * 100 / SUM(COUNT(*)) OVER (), 2)              AS 人数占比,
       ROUND(AVG(monetary), 2)                                       AS 人均消费,
       ROUND(SUM(monetary) * 100 / SUM(SUM(monetary)) OVER (), 1)    AS GMV占比
FROM rfm_segments
GROUP BY user_segment
ORDER BY 人数 DESC;

-- =====================================================================
-- Chapter 5 Summary
-- * 3652 valid buyers scored on R/F/M (1~5) with PERCENT_RANK
-- * 重要价值用户 18.9% of users -> 51.5% of GMV: protect at all costs
-- * 重要挽留用户 7.4% users / 14.0% GMV: loyal & high-spend but going
--   quiet -> highest-ROI win-back target (coupons, personal outreach)
-- * 流失用户 40.2% users but only 8.9% GMV -> low-cost reactivation
-- * F is skewed: 1165 users bought only once -> repeat purchase is the
--   biggest growth lever (new-user 2nd-order incentives)
-- =====================================================================