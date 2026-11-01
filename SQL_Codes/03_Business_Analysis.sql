/*
============================================================
PROJECT : Brazilian E-Commerce Sales & Customer Insights
STEP    : 2. SQL Business Analysis
DATABASE: BrazilianECommerce
INPUT   : dbo.vw_order_master and dbo.vw_item_detail (from SQL_01_Cleaning.sql)
RULES   : Revenue uses non-canceled orders.
          Delivery and review KPIs use delivered orders.
          Late = delivered DATE is after the estimated DATE.
          Complete trading window = Jan 2017 to Aug 2018.
Each section answers one business question and lists the expected result.
============================================================
*/

USE BrazilianECommerce;
GO


/* =========================================================
   SECTION 1: HEADLINE KPIs
   Question: how big is the business and how healthy is it?
   ========================================================= */

-- 1a. Order and customer KPIs.
-- Expected: 99441 orders | 96096 customers | GMV 15865616.52 | AOV 159.86
--           review 4.16 | late 6.77% | delivery 12.56 days | cancel 0.63%
SELECT
    COUNT(*)                                   AS total_orders,
    COUNT(DISTINCT customer_unique_id)         AS unique_customers,
    CAST(SUM(CASE WHEN order_status <> 'canceled' THEN payment_total END) AS DECIMAL(14,2)) AS gmv,
    CAST(AVG(CASE WHEN order_status = 'delivered' THEN payment_total END) AS DECIMAL(10,2)) AS avg_order_value,
    CAST(AVG(CASE WHEN order_status = 'delivered' THEN review_score END) AS DECIMAL(4,2))   AS avg_review,
    CAST(AVG(CASE WHEN order_status = 'delivered' THEN CAST(is_late AS FLOAT) END) * 100 AS DECIMAL(5,2)) AS late_pct,
    CAST(AVG(CASE WHEN order_status = 'delivered' THEN delivery_days END) AS DECIMAL(5,2))  AS avg_delivery_days,
    CAST(SUM(CASE WHEN order_status = 'canceled' THEN 1.0 ELSE 0 END) / COUNT(*) * 100 AS DECIMAL(5,2)) AS cancel_pct
FROM dbo.vw_order_master;
GO

-- 1b. Product revenue, freight and active sellers (non-canceled orders).
-- Expected: revenue 13496408.43 | freight 2241259.09 | sellers 3056
SELECT
    CAST(SUM(price) AS DECIMAL(14,2))         AS product_revenue,
    CAST(SUM(freight_value) AS DECIMAL(14,2)) AS freight_revenue,
    COUNT(DISTINCT seller_id)                 AS active_sellers
FROM dbo.vw_item_detail
WHERE order_status <> 'canceled';
GO

-- 1c. Repeat customers (a person = customer_unique_id, all orders counted).
-- Expected: 96096 customers | 2997 repeat | 3.12%
WITH c AS (
    SELECT customer_unique_id, COUNT(*) AS orders
    FROM dbo.vw_order_master
    GROUP BY customer_unique_id
)
SELECT COUNT(*) AS customers,
       SUM(CASE WHEN orders > 1 THEN 1 ELSE 0 END) AS repeat_customers,
       CAST(SUM(CASE WHEN orders > 1 THEN 1.0 ELSE 0 END) / COUNT(*) * 100 AS DECIMAL(5,2)) AS repeat_pct
FROM c;
GO


/* =========================================================
   SECTION 2: SALES TREND
   Question: is revenue growing, and when does it peak?
   ========================================================= */

-- Monthly orders, revenue and month-over-month growth.
-- Expected: Jan 2017 about 120098 | peak Nov 2017 about 1003862 | Aug 2018 about 848860
WITH monthly AS (
    SELECT purchase_month,
           COUNT(DISTINCT order_id) AS orders,
           SUM(price)               AS revenue
    FROM dbo.vw_item_detail
    WHERE order_status <> 'canceled'
      AND purchase_month BETWEEN '2017-01-01' AND '2018-08-01'
    GROUP BY purchase_month
)
SELECT purchase_month,
       orders,
       CAST(revenue AS DECIMAL(14,2)) AS revenue,
       CAST((revenue - LAG(revenue) OVER (ORDER BY purchase_month))
            / NULLIF(LAG(revenue) OVER (ORDER BY purchase_month), 0) * 100 AS DECIMAL(6,2)) AS mom_growth_pct
FROM monthly
ORDER BY purchase_month;
GO


/* =========================================================
   SECTION 3: CATEGORY PERFORMANCE
   Question: which categories drive revenue?
   ========================================================= */

-- Top 15 categories with revenue share and cumulative share.
-- Expected: health_beauty 1255695 | watches_gifts 1198185 | bed_bath_table 1035964
WITH cat AS (
    SELECT category,
           COUNT(DISTINCT order_id) AS orders,
           SUM(price)               AS revenue
    FROM dbo.vw_item_detail
    WHERE order_status <> 'canceled'
    GROUP BY category
)
SELECT TOP 15
       category,
       orders,
       CAST(revenue AS DECIMAL(14,2)) AS revenue,
       CAST(revenue * 100.0 / SUM(revenue) OVER () AS DECIMAL(5,2)) AS share_pct,
       CAST(SUM(revenue) OVER (ORDER BY revenue DESC ROWS UNBOUNDED PRECEDING) * 100.0
            / SUM(revenue) OVER () AS DECIMAL(5,2)) AS cumulative_share_pct
FROM cat
ORDER BY revenue DESC;
GO

-- How many categories are needed to reach 80% of revenue?
-- Expected: 18 of 74
WITH cat AS (
    SELECT category, SUM(price) AS revenue
    FROM dbo.vw_item_detail
    WHERE order_status <> 'canceled'
    GROUP BY category
), r AS (
    SELECT category, revenue,
           SUM(revenue) OVER (ORDER BY revenue DESC ROWS UNBOUNDED PRECEDING) * 1.0 / SUM(revenue) OVER () AS cum_share,
           revenue * 1.0 / SUM(revenue) OVER () AS share
    FROM cat
)
SELECT SUM(CASE WHEN cum_share - share < 0.8 THEN 1 ELSE 0 END) AS categories_to_reach_80pct,
       COUNT(*) AS total_categories
FROM r;
GO


/* =========================================================
   SECTION 4: STATE PERFORMANCE
   Question: where are the sales, and where does delivery fail?
   ========================================================= */

-- Revenue share plus delivery speed, lateness and reviews by customer state.
-- Expected: SP share 38.3% (top 3 SP, RJ, MG = 63.4%)
--           late %: SP 4.5 | RJ 12.1 | AL 21.4 (highest)
WITH rev AS (
    SELECT customer_state, SUM(price) AS revenue
    FROM dbo.vw_item_detail
    WHERE order_status <> 'canceled'
    GROUP BY customer_state
), ops AS (
    SELECT customer_state,
           COUNT(*)                                                      AS delivered_orders,
           CAST(AVG(delivery_days) AS DECIMAL(5,2))                      AS avg_delivery_days,
           CAST(AVG(CAST(is_late AS FLOAT)) * 100 AS DECIMAL(5,2))       AS late_pct,
           CAST(AVG(review_score) AS DECIMAL(4,2))                       AS avg_review
    FROM dbo.vw_order_master
    WHERE order_status = 'delivered' AND order_delivered_customer_date IS NOT NULL
    GROUP BY customer_state
)
SELECT r.customer_state,
       CAST(r.revenue AS DECIMAL(14,2)) AS revenue,
       CAST(r.revenue * 100.0 / SUM(r.revenue) OVER () AS DECIMAL(5,2)) AS revenue_share_pct,
       o.delivered_orders, o.avg_delivery_days, o.late_pct, o.avg_review
FROM rev r
JOIN ops o ON o.customer_state = r.customer_state
ORDER BY r.revenue DESC;
GO


/* =========================================================
   SECTION 5: DELIVERY DELAY VS REVIEW SCORE
   Question: how much do late deliveries hurt satisfaction?
   Association only, not proof of cause.
   ========================================================= */

-- Expected (orders | avg review):
--   On time or early 89443 | 4.29    1-3 days late 1852 | 3.29    4-7 days late 1748 | 2.11
--   8-14 days late 1446 | 1.67       15+ days late 1335 | 1.73
SELECT
    CASE WHEN delay_days <= 0  THEN '1. On time or early'
         WHEN delay_days <= 3  THEN '2. 1-3 days late'
         WHEN delay_days <= 7  THEN '3. 4-7 days late'
         WHEN delay_days <= 14 THEN '4. 8-14 days late'
         ELSE                       '5. 15+ days late' END AS delay_band,
    COUNT(*) AS orders,
    CAST(AVG(review_score) AS DECIMAL(4,2)) AS avg_review
FROM dbo.vw_order_master
WHERE order_status = 'delivered'
  AND delay_days IS NOT NULL
  AND review_score IS NOT NULL
GROUP BY CASE WHEN delay_days <= 0  THEN '1. On time or early'
              WHEN delay_days <= 3  THEN '2. 1-3 days late'
              WHEN delay_days <= 7  THEN '3. 4-7 days late'
              WHEN delay_days <= 14 THEN '4. 8-14 days late'
              ELSE                       '5. 15+ days late' END
ORDER BY delay_band;
GO


/* =========================================================
   SECTION 6: PAYMENT METHODS
   Question: how do customers pay?
   ========================================================= */

-- Expected value share: credit_card 78.3% | boleto 17.9% | voucher 2.4% | debit_card 1.4%
SELECT payment_type,
       COUNT(DISTINCT order_id) AS orders,
       CAST(SUM(payment_value) AS DECIMAL(14,2)) AS payment_value,
       CAST(SUM(payment_value) * 100.0 / SUM(SUM(payment_value)) OVER () AS DECIMAL(5,2)) AS value_share_pct,
       CAST(AVG(CAST(payment_installments AS FLOAT)) AS DECIMAL(5,2)) AS avg_installments
FROM dbo.order_payments
GROUP BY payment_type
ORDER BY payment_value DESC;
GO


/* =========================================================
   SECTION 7: SELLER PERFORMANCE
   Question: how concentrated is revenue, and who delivers well?
   ========================================================= */

-- 7a. Share of revenue earned by the top 10% of sellers.
-- Expected: about 67.4%
WITH s AS (
    SELECT seller_id, SUM(price) AS revenue,
           NTILE(10) OVER (ORDER BY SUM(price) DESC) AS decile
    FROM dbo.vw_item_detail
    WHERE order_status <> 'canceled'
    GROUP BY seller_id
)
SELECT CAST(SUM(CASE WHEN decile = 1 THEN revenue END) * 100.0 / SUM(revenue) AS DECIMAL(5,2)) AS top10pct_sellers_revenue_share
FROM s;
GO

-- 7b. Top 20 sellers with at least 30 delivered orders.
WITH s AS (
    SELECT seller_id, seller_state,
           COUNT(DISTINCT order_id) AS orders,
           SUM(price)               AS revenue,
           AVG(review_score)        AS avg_review,
           AVG(CAST(is_late AS FLOAT)) * 100 AS late_pct
    FROM dbo.vw_item_detail
    WHERE order_status = 'delivered'
    GROUP BY seller_id, seller_state
)
SELECT TOP 20 seller_id, seller_state, orders,
       CAST(revenue AS DECIMAL(12,2))    AS revenue,
       CAST(avg_review AS DECIMAL(4,2))  AS avg_review,
       CAST(late_pct AS DECIMAL(5,2))    AS late_pct
FROM s
WHERE orders >= 30
ORDER BY revenue DESC;
GO


/* =========================================================
   SECTION 8: CUSTOMER SEGMENTS (RFM)
   Question: which customers should marketing win back?
   R = days since last order, F = number of orders, M = total spend.
   Saved as a view so Power BI and Python can reuse it.
   ========================================================= */
CREATE OR ALTER VIEW dbo.vw_rfm_customer AS
WITH base AS (
    SELECT customer_unique_id,
           DATEDIFF(DAY, MAX(order_purchase_timestamp),
                    (SELECT MAX(order_purchase_timestamp) FROM dbo.vw_order_master)) AS recency_days,
           COUNT(*)           AS frequency,
           SUM(payment_total) AS monetary
    FROM dbo.vw_order_master
    WHERE order_status <> 'canceled'
    GROUP BY customer_unique_id
), scored AS (
    SELECT *,
           NTILE(4) OVER (ORDER BY recency_days DESC, customer_unique_id) AS r_score,   -- 4 = most recent
           NTILE(4) OVER (ORDER BY monetary, customer_unique_id) AS m_score    -- 4 = highest spend
    FROM base
)
SELECT *,
       CASE WHEN frequency >= 2 AND r_score >= 3 THEN 'Loyal repeat'
            WHEN r_score = 4 AND m_score >= 3     THEN 'New high value'
            WHEN r_score = 4                      THEN 'New low value'
            WHEN r_score <= 2 AND m_score >= 3    THEN 'At risk high value'
            ELSE 'Lapsed / low value' END AS segment
FROM scored;
GO

-- Segment summary. Expected: 'At risk high value' is the biggest spend group
-- (about 23,392 customers, about R$6.31M). The customer_unique_id tiebreaker makes the
-- quartiles identical on every run.
SELECT segment,
       COUNT(*) AS customers,
       CAST(AVG(monetary) AS DECIMAL(10,2)) AS avg_spend,
       CAST(SUM(monetary) AS DECIMAL(14,2)) AS total_spend
FROM dbo.vw_rfm_customer
GROUP BY segment
ORDER BY total_spend DESC;
GO
