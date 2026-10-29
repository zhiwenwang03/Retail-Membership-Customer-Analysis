-- =====================================================================
-- 04_User_Profile.sql
-- Chapter 4: User Profile Analysis
-- Dimensions: 4.1 Age -> 4.2 Gender -> 4.3 Member level
--             -> 4.4 Region TOP10 -> 4.5 Spending power
-- Source: dim_user (5000 users, incl. 1198 users with no orders)
-- Note: Read-only queries.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 4.1 Age distribution
-- Bins aligned with the doc's conclusion (18-24 / 25-34 / 35-44 / 45+).
-- (The doc's SQL used <20 / 20-29 / ... which didn't match its own text.)
-- ---------------------------------------------------------------------
SELECT
    CASE WHEN age BETWEEN 18 AND 24 THEN '18-24岁'
         WHEN age BETWEEN 25 AND 34 THEN '25-34岁'
         WHEN age BETWEEN 35 AND 44 THEN '35-44岁'
         ELSE '45岁及以上' END                                        AS age_group,
    COUNT(*)                                                         AS 人数,
    ROUND(COUNT(*) * 100 / SUM(COUNT(*)) OVER (), 2)                 AS 人数占比,
    ROUND(AVG(total_spent), 2)                                       AS 人均消费,
    ROUND(SUM(total_spent) * 100 / SUM(SUM(total_spent)) OVER (), 1) AS GMV占比
FROM dim_user
GROUP BY age_group
ORDER BY MIN(age);

-- ---------------------------------------------------------------------
-- 4.2 Gender distribution
-- ---------------------------------------------------------------------
SELECT gender,
       COUNT(*)                                                         AS 人数,
       ROUND(COUNT(*) * 100 / SUM(COUNT(*)) OVER (), 2)                 AS 人数占比,
       ROUND(AVG(total_spent), 2)                                       AS 人均消费,
       ROUND(SUM(total_spent) * 100 / SUM(SUM(total_spent)) OVER (), 1) AS GMV占比
FROM dim_user
GROUP BY gender;

-- ---------------------------------------------------------------------
-- 4.3 Member level
-- FIELD() keeps tiers in business order instead of alphabetical.
-- ---------------------------------------------------------------------
SELECT member_level,
       COUNT(*)                                                         AS 人数,
       ROUND(COUNT(*) * 100 / SUM(COUNT(*)) OVER (), 2)                 AS 人数占比,
       ROUND(AVG(total_spent), 2)                                       AS 人均消费,
       ROUND(SUM(total_spent) * 100 / SUM(SUM(total_spent)) OVER (), 1) AS GMV占比
FROM dim_user
GROUP BY member_level
ORDER BY FIELD(member_level, '普通会员', '铜牌会员', '银牌会员', '金牌会员', '钻石会员');

-- ---------------------------------------------------------------------
-- 4.4 Region TOP10 by user count
-- ---------------------------------------------------------------------
SELECT province,
       COUNT(*)                                                         AS 人数,
       ROUND(COUNT(*) * 100 / SUM(COUNT(*)) OVER (), 2)                 AS 人数占比,
       ROUND(AVG(total_spent), 2)                                       AS 人均消费,
       ROUND(SUM(total_spent) * 100 / SUM(SUM(total_spent)) OVER (), 1) AS GMV占比
FROM dim_user
GROUP BY province
ORDER BY 人数 DESC
LIMIT 10;

-- ---------------------------------------------------------------------
-- 4.5 Spending power (consumption_level)
-- Check the 80/20 rule: does the top tier drive most of the GMV?
-- ---------------------------------------------------------------------
SELECT consumption_level,
       COUNT(*)                                                         AS 人数,
       ROUND(COUNT(*) * 100 / SUM(COUNT(*)) OVER (), 2)                 AS 人数占比,
       ROUND(AVG(total_spent), 2)                                       AS 人均消费,
       ROUND(SUM(total_spent) * 100 / SUM(SUM(total_spent)) OVER (), 1) AS GMV占比
FROM dim_user
GROUP BY consumption_level
ORDER BY FIELD(consumption_level, '低', '中', '高');

-- =====================================================================
-- Chapter 4 Summary
-- * Age    : 25-44 = 71.5% of users, 72.3% of GMV -> core segment
-- * Gender : female 57.6% of users; male spends ~14% more per capita
-- * Member : spend rises sharply with tier; 钻石会员 6% users -> 40.5% GMV
--            (differs from the doc's "flat" conclusion - data-driven)
-- * Region : concentrated in 广东/江苏/浙江/北京/上海 (tier-1/2 cities)
-- * Power  : top 25% users -> 80.2% GMV, a textbook 80/20 distribution
-- Action  : retain high-value / high-tier members (VIP service, upgrades);
--           activate 1198 registered-but-never-purchased users.
-- =====================================================================