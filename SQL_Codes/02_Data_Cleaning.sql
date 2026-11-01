/*
============================================================
PROJECT : Brazilian E-Commerce Sales & Customer Insights
STEP    : 1. SQL Data Cleaning
DATABASE: BrazilianECommerce
OUTPUT  : Two clean views used by every later step (SQL analysis, Python, Power BI)
            dbo.vw_order_master : one row per order
            dbo.vw_item_detail  : one row per order item
RULES   : Raw tables are never changed. Every fix lives in the views.
============================================================
Fixes applied (each comes from your quality checks):
  1. Reviews     : repeated review_id / several reviews per order  -> average score per order
  2. Payments    : several payment rows per order                  -> summed per order
  3. Items       : several items per order                         -> summed per order
  4. Category    : 610 products have no category                   -> 'Others', English names used
  5. Dates       : illogical sequences                             -> flagged in data_issue, not deleted
  6. Late flag   : estimated date has no time of day               -> compare DATES, not timestamps
  7. Customers   : customer_id changes per order                   -> customer_unique_id carried through
============================================================
*/

USE BrazilianECommerce;
GO


/* =========================================================
   VIEW 1: ORDER MASTER (one row per order)
   Items, payments and reviews are aggregated BEFORE joining,
   so no order is ever duplicated.
   ========================================================= */
CREATE OR ALTER VIEW dbo.vw_order_master AS
WITH items AS (
    -- Item totals per order.
    SELECT order_id,
           COUNT(*)                  AS n_items,
           COUNT(DISTINCT seller_id) AS n_sellers,
           SUM(price)                AS item_total,
           SUM(freight_value)        AS freight_total
    FROM dbo.order_items
    GROUP BY order_id
),
pay AS (
    -- Payment totals per order (an order can be paid in several parts).
    SELECT order_id,
           SUM(payment_value)        AS payment_total,
           MAX(payment_installments) AS installments
    FROM dbo.order_payments
    GROUP BY order_id
),
first_pay AS (
    -- Payment method of the first payment.
    SELECT order_id, payment_type
    FROM dbo.order_payments
    WHERE payment_sequential = 1
),
rev AS (
    -- One review score per order (average when an order has several reviews).
    SELECT order_id,
           AVG(CAST(review_score AS FLOAT)) AS review_score
    FROM dbo.order_reviews
    GROUP BY order_id
)
SELECT
    o.order_id,
    o.customer_id,
    c.customer_unique_id,                         -- real person, use for customer counts
    c.customer_state,
    o.order_status,

    -- Dates
    o.order_purchase_timestamp,
    CAST(o.order_purchase_timestamp AS DATE) AS purchase_date,
    DATEFROMPARTS(YEAR(o.order_purchase_timestamp),
                  MONTH(o.order_purchase_timestamp), 1) AS purchase_month,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,

    -- Delivery metrics (NULL when the order has no delivery date)
    DATEDIFF(SECOND, o.order_purchase_timestamp, o.order_delivered_customer_date) / 86400.0
        AS delivery_days,                         -- purchase to delivery, in days
    DATEDIFF(DAY, CAST(o.order_estimated_delivery_date AS DATE),
                  CAST(o.order_delivered_customer_date AS DATE))
        AS delay_days,                            -- positive = late, negative = early
    CASE WHEN o.order_delivered_customer_date IS NULL THEN NULL
         WHEN CAST(o.order_delivered_customer_date AS DATE)
            > CAST(o.order_estimated_delivery_date AS DATE) THEN 1
         ELSE 0 END AS is_late,                   -- date-level comparison

    -- Satisfaction and money
    r.review_score,
    p.payment_total,
    p.installments,
    fp.payment_type AS main_payment_type,
    i.n_items,
    i.n_sellers,
    i.item_total,
    i.freight_total,

    -- Flag illogical records. They stay in the view and are excluded only where relevant.
    CASE WHEN o.order_delivered_carrier_date < o.order_purchase_timestamp          THEN 'carrier_before_purchase'
         WHEN o.order_delivered_customer_date < o.order_delivered_carrier_date     THEN 'customer_before_carrier'
         WHEN o.order_status <> 'delivered'
              AND o.order_delivered_customer_date IS NOT NULL                      THEN 'status_date_mismatch'
         WHEN o.order_status = 'delivered'
              AND o.order_delivered_customer_date IS NULL                          THEN 'delivered_without_date'
         ELSE NULL END AS data_issue
FROM dbo.Orders o
JOIN dbo.Customer c          ON c.customer_id = o.customer_id
LEFT JOIN items i            ON i.order_id    = o.order_id
LEFT JOIN pay p              ON p.order_id    = o.order_id
LEFT JOIN first_pay fp       ON fp.order_id   = o.order_id
LEFT JOIN rev r              ON r.order_id    = o.order_id;
GO


/* =========================================================
   VIEW 2: ITEM DETAIL (one row per order item)
   Adds the English category and the seller state.
   Used for revenue by category, state and seller.
   ========================================================= */
CREATE OR ALTER VIEW dbo.vw_item_detail AS
SELECT
    oi.order_id,
    oi.order_item_id,
    oi.product_id,
    oi.seller_id,
    oi.price,
    oi.freight_value,

    -- English name; two categories are missing from the translation table;
    -- products with no category become 'Others'.
    COALESCE(
        t.product_category_name_english,
        CASE p.product_category_name
             WHEN 'pc_gamer' THEN 'pc_gamer'
             WHEN 'portateis_cozinha_e_preparadores_de_alimentos' THEN 'portable_kitchen_food_preparers'
        END,
        p.product_category_name,
        'Others'
    ) AS category,

    s.seller_state,
    m.order_status,
    m.purchase_month,
    m.customer_state,
    m.customer_unique_id,
    m.review_score,
    m.is_late,
    m.delivery_days
FROM dbo.order_items oi
JOIN dbo.vw_order_master m         ON m.order_id = oi.order_id
LEFT JOIN dbo.products p           ON p.product_id = oi.product_id
LEFT JOIN dbo.translation t        ON t.product_category_name = p.product_category_name
LEFT JOIN dbo.sellers s            ON s.seller_id = oi.seller_id;
GO


/* =========================================================
   VALIDATION: run these and compare with the expected values.
   If a number differs, stop and fix it before the next step.
   ========================================================= */

-- 1. No rows lost or duplicated.
--    Expected: raw_orders = master_rows = 99441 ; raw_items = item_rows = 112650
SELECT
    (SELECT COUNT(*) FROM dbo.Orders)             AS raw_orders,
    (SELECT COUNT(*) FROM dbo.vw_order_master)    AS master_rows,
    (SELECT COUNT(*) FROM dbo.order_items)        AS raw_items,
    (SELECT COUNT(*) FROM dbo.vw_item_detail)     AS item_rows;
GO

-- 2. Delivery and review sanity check (delivered orders only).
--    Expected: delivered_with_date 96470 ; late_orders 6534 ; late_pct about 6.77 ;
--              avg_delivery_days about 12.56 ; avg_review about 4.16
SELECT
    COUNT(*)                                          AS delivered_with_date,
    SUM(is_late)                                      AS late_orders,
    CAST(AVG(CAST(is_late AS FLOAT)) * 100 AS DECIMAL(5,2)) AS late_pct,
    CAST(AVG(delivery_days) AS DECIMAL(5,2))          AS avg_delivery_days,
    CAST(AVG(review_score) AS DECIMAL(4,2))           AS avg_review
FROM dbo.vw_order_master
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL;
GO

-- 3. Category cleaning. Expected: null_categories = 0
SELECT SUM(CASE WHEN category IS NULL THEN 1 ELSE 0 END) AS null_categories,
       SUM(CASE WHEN category = 'Others' THEN 1 ELSE 0 END) AS items_in_others
FROM dbo.vw_item_detail;
GO

-- 4. Flagged records by type (for the data issues slide in the presentation).
SELECT ISNULL(data_issue, 'ok') AS data_issue, COUNT(*) AS orders
FROM dbo.vw_order_master
GROUP BY data_issue
ORDER BY orders DESC;
GO
