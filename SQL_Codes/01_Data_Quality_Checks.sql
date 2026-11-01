/*
============================================================
PROJECT: Brazilian E-Commerce Sales & Customer Insights
DELIVERABLE: Initial SQL Data Quality Checks
DATABASE: BrazilianECommerce

OBJECTIVES:
1. Verify imported table row counts.
2. Check missing values and duplicate identifiers.
3. Identify missing relationships between tables.
4. Check date consistency.
5. Inspect unusual payment and product values.
6. Compare order-level payments with item and freight totals.
7. Check category translation consistency.
8. Explore delivery delays and customer review scores.

============================================================
*/

USE BrazilianECommerce;
GO


/* =========================================================
   SECTION 1: TABLE ROW COUNTS
   Purpose: Verify that the imported tables contain records.
   ========================================================= */

-- Row count of every table in one result set.
SELECT 'Customer' AS table_name, COUNT(*) AS total_rows FROM Customer
UNION ALL
SELECT 'Orders', COUNT(*) FROM Orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL
SELECT 'order_payments', COUNT(*) FROM order_payments
UNION ALL
SELECT 'order_reviews', COUNT(*) FROM order_reviews
UNION ALL
SELECT 'products', COUNT(*) FROM products
UNION ALL
SELECT 'sellers', COUNT(*) FROM sellers
UNION ALL
SELECT 'geolocation', COUNT(*) FROM geolocation
UNION ALL
SELECT 'translation', COUNT(*) FROM translation;
GO


/* =========================================================
   SECTION 2: CUSTOMER ID QUALITY
   Purpose: Check missing and duplicate customer identifiers.
   ========================================================= */

-- COUNT(column) skips NULLs, so total_rows vs non_null_ids shows
-- missing IDs; non_null_ids vs unique_ids shows duplicates.
SELECT
    COUNT(*) AS total_rows,
    COUNT(customer_id) AS non_null_ids,
    COUNT(DISTINCT customer_id) AS unique_ids
FROM Customer;
GO


/* =========================================================
   SECTION 3: ORDER ID QUALITY
   Purpose: Check missing and duplicate order identifiers.
   ========================================================= */

-- Same NULL and duplicate check as Section 2, for order_id.
SELECT
    COUNT(*) AS total_rows,
    COUNT(order_id) AS non_null_ids,
    COUNT(DISTINCT order_id) AS unique_ids
FROM Orders;
GO


/* =========================================================
   SECTION 4: ORDER ITEM ID COMPLETENESS
   Purpose: Find missing order, product and seller IDs.
   Note: Multiple items can belong to the same order.
   ========================================================= */

-- Count NULLs in each key column of order_items.
SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END)
        AS missing_order_ids,
    SUM(CASE WHEN product_id IS NULL THEN 1 ELSE 0 END)
        AS missing_product_ids,
    SUM(CASE WHEN seller_id IS NULL THEN 1 ELSE 0 END)
        AS missing_seller_ids
FROM order_items;
GO


/* =========================================================
   SECTION 5: PAYMENT DATA QUALITY
   Purpose: Check missing payment values and non-positive
   amounts. Unusual values are investigated, not deleted.
   ========================================================= */

-- Summary: missing IDs, missing values and zero/negative payments.
SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END)
        AS missing_order_ids,
    SUM(CASE WHEN payment_value IS NULL THEN 1 ELSE 0 END)
        AS missing_payment_values,
    SUM(CASE WHEN payment_value <= 0 THEN 1 ELSE 0 END)
        AS nonpositive_payments
FROM order_payments;
GO

-- Inspect individual zero or negative payment records.
SELECT
    order_id,
    payment_type,
    payment_value
FROM order_payments
WHERE payment_value <= 0
ORDER BY payment_value;
GO

-- Separate zero-value payments from negative payments.
SELECT
    SUM(CASE WHEN payment_value = 0 THEN 1 ELSE 0 END)
        AS zero_payments,
    SUM(CASE WHEN payment_value < 0 THEN 1 ELSE 0 END)
        AS negative_payments
FROM order_payments;
GO

-- Check the number of records and zero-value payments
-- for each payment method.
SELECT
    payment_type,
    COUNT(*) AS total_rows,
    SUM(CASE WHEN payment_value = 0 THEN 1 ELSE 0 END)
        AS zero_value_rows
FROM order_payments
GROUP BY payment_type
ORDER BY total_rows DESC;
GO


/* =========================================================
   SECTION 6: REVIEW DATA QUALITY
   Purpose: Check missing order IDs, missing review scores
   and scores outside the expected range of 1 to 5.
   ========================================================= */

-- Count NULL order IDs, NULL scores and scores outside 1 to 5.
SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END)
        AS missing_order_ids,
    SUM(CASE WHEN review_score IS NULL THEN 1 ELSE 0 END)
        AS missing_scores,
    SUM(CASE
        WHEN review_score NOT BETWEEN 1 AND 5 THEN 1
        ELSE 0
    END) AS invalid_scores
FROM order_reviews;
GO

-- Show the distribution of review scores.
SELECT
    review_score,
    COUNT(*) AS review_count
FROM order_reviews
GROUP BY review_score
ORDER BY review_score;
GO


/* =========================================================
   SECTION 7: PRODUCT CATEGORY COMPLETENESS
   Purpose: Count products with missing categories and
   inspect examples without changing the original data.
   ========================================================= */

-- Total products vs products with no category.
SELECT
    COUNT(*) AS total_products,
    SUM(CASE
        WHEN product_category_name IS NULL THEN 1
        ELSE 0
    END) AS missing_categories
FROM products;
GO

-- Inspect sample products with missing categories.
SELECT TOP 20
    product_id,
    product_category_name,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm
FROM products
WHERE product_category_name IS NULL;
GO

-- Count available source categories in the translation table.
SELECT
    COUNT(*) AS total_translation_categories
FROM translation;
GO


/* =========================================================
   SECTION 8: PURCHASE DATE COMPLETENESS
   Purpose: Check missing purchase timestamps.
   ========================================================= */

-- Orders with no purchase timestamp.
SELECT
    COUNT(*) AS total_orders,
    SUM(CASE
        WHEN order_purchase_timestamp IS NULL THEN 1
        ELSE 0
    END) AS missing_purchase_dates
FROM Orders;
GO


/* =========================================================
   SECTION 9: DELIVERY DELAYS
   Purpose: Count orders delivered after their estimated date.
   Rows with NULL dates are not counted by this comparison.
   ========================================================= */

-- Late = actual delivery date is after the estimated date.
SELECT
    COUNT(*) AS late_deliveries
FROM Orders
WHERE order_delivered_customer_date >
      order_estimated_delivery_date;
GO


/* =========================================================
   SECTION 10: NEGATIVE ITEM PRICES AND FREIGHT
   Purpose: Flag negative prices or freight charges.
   ========================================================= */

-- Count negative prices and negative freight values.
SELECT
    SUM(CASE WHEN price < 0 THEN 1 ELSE 0 END)
        AS negative_prices,
    SUM(CASE WHEN freight_value < 0 THEN 1 ELSE 0 END)
        AS negative_freight
FROM order_items;
GO


/* =========================================================
   SECTION 11: DELIVERY STATUS AND REVIEW SCORES
   Purpose: Explore whether late-delivered orders have
   different average review scores.

   LIMITATION:
   This shows an association, not proof of causation.
   Orders without actual or estimated delivery dates are
   excluded from this comparison.
   ========================================================= */

-- Label each order Late / Not Late, then compare review counts
-- and average scores. DECIMAL cast avoids integer averaging.
SELECT
    CASE
        WHEN o.order_delivered_customer_date >
             o.order_estimated_delivery_date
        THEN 'Late'
        ELSE 'Not Late'
    END AS delivery_status,
    COUNT(*) AS reviewed_rows,
    CAST(
        AVG(CAST(r.review_score AS DECIMAL(10,2)))
        AS DECIMAL(4,2)
    ) AS avg_review_score
FROM Orders o
INNER JOIN order_reviews r
    ON o.order_id = r.order_id
WHERE o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
GROUP BY
    CASE
        WHEN o.order_delivered_customer_date >
             o.order_estimated_delivery_date
        THEN 'Late'
        ELSE 'Not Late'
    END;
GO


/* =========================================================
   SECTION 12: DUPLICATE IDENTIFIER CHECKS
   Purpose: Find duplicate product, seller and review IDs.
   No records are deleted.
   ========================================================= */

-- Duplicate product IDs.
SELECT
    product_id,
    COUNT(*) AS occurrences
FROM products
GROUP BY product_id
HAVING COUNT(*) > 1;
GO

-- Duplicate seller IDs.
SELECT
    seller_id,
    COUNT(*) AS occurrences
FROM sellers
GROUP BY seller_id
HAVING COUNT(*) > 1;
GO

-- Duplicate review IDs.
SELECT
    review_id,
    COUNT(*) AS occurrences
FROM order_reviews
GROUP BY review_id
HAVING COUNT(*) > 1;
GO

-- Orders with multiple review records.
-- Multiple records require investigation, not automatic deletion.
SELECT
    order_id,
    COUNT(*) AS review_records
FROM order_reviews
GROUP BY order_id
HAVING COUNT(*) > 1;
GO


/* =========================================================
   SECTION 13: RELATIONSHIP / ORPHAN RECORD CHECKS
   Purpose: Find IDs that do not exist in their expected
   related table. Returned rows require investigation.
   ========================================================= */

-- Orders whose customer ID is missing from Customer.
SELECT
    o.order_id,
    o.customer_id
FROM Orders o
WHERE NOT EXISTS (
    SELECT 1
    FROM Customer c
    WHERE c.customer_id = o.customer_id
);
GO

-- Order items referring to missing orders.
SELECT oi.order_id
FROM order_items oi
WHERE NOT EXISTS (
    SELECT 1
    FROM Orders o
    WHERE o.order_id = oi.order_id
);
GO

-- Order items referring to missing products.
SELECT oi.product_id
FROM order_items oi
WHERE NOT EXISTS (
    SELECT 1
    FROM products p
    WHERE p.product_id = oi.product_id
);
GO

-- Order items referring to missing sellers.
SELECT oi.seller_id
FROM order_items oi
WHERE NOT EXISTS (
    SELECT 1
    FROM sellers s
    WHERE s.seller_id = oi.seller_id
);
GO

-- Payments referring to missing orders.
SELECT op.order_id
FROM order_payments op
WHERE NOT EXISTS (
    SELECT 1
    FROM Orders o
    WHERE o.order_id = op.order_id
);
GO

-- Reviews referring to missing orders.
SELECT r.order_id
FROM order_reviews r
WHERE NOT EXISTS (
    SELECT 1
    FROM Orders o
    WHERE o.order_id = r.order_id
);
GO


/* =========================================================
   SECTION 14: DATE CONSISTENCY CHECKS
   Purpose: Identify potentially illogical timestamp sequences.
   NULL timestamps are not evaluated by these comparisons.
   ========================================================= */

-- Approval before purchase.
SELECT
    order_id,
    order_purchase_timestamp,
    order_approved_at
FROM Orders
WHERE order_approved_at < order_purchase_timestamp;
GO

-- Carrier delivery before purchase.
SELECT
    order_id,
    order_purchase_timestamp,
    order_delivered_carrier_date
FROM Orders
WHERE order_delivered_carrier_date <
      order_purchase_timestamp;
GO

-- Customer delivery before carrier delivery.
SELECT
    order_id,
    order_delivered_carrier_date,
    order_delivered_customer_date
FROM Orders
WHERE order_delivered_customer_date <
      order_delivered_carrier_date;
GO

-- Customer delivery before purchase.
SELECT
    order_id,
    order_purchase_timestamp,
    order_delivered_customer_date
FROM Orders
WHERE order_delivered_customer_date <
      order_purchase_timestamp;
GO

-- Estimated delivery date before purchase.
-- Flag for review rather than assuming it is always invalid.
SELECT
    order_id,
    order_purchase_timestamp,
    order_estimated_delivery_date
FROM Orders
WHERE order_estimated_delivery_date <
      order_purchase_timestamp;
GO


/* =========================================================
   SECTION 15: PAYMENT RECONCILIATION
   Purpose: Compare payment totals with item prices and
   freight at order level.

   METHOD:
   Aggregate item and payment tables separately first.
   This prevents multiplication of rows when an order has
   multiple items and multiple payment records.

   NOTE:
   Differences can have legitimate explanations and must
   be investigated before any correction.
   ========================================================= */

-- Per-order totals from each table, joined with a FULL OUTER JOIN
-- so orders missing from either side are also returned.
-- Only mismatches (> 0.01 difference) or missing totals are shown.
WITH ItemTotals AS (
    -- Item price and freight summed per order.
    SELECT
        order_id,
        SUM(price) AS item_price_total,
        SUM(freight_value) AS freight_total
    FROM order_items
    GROUP BY order_id
),
PaymentTotals AS (
    -- Payments summed per order (an order can have several).
    SELECT
        order_id,
        SUM(payment_value) AS payment_total
    FROM order_payments
    GROUP BY order_id
),
Reconciliation AS (
    -- payment_difference = amount paid minus (items + freight).
    SELECT
        COALESCE(i.order_id, p.order_id) AS order_id,
        i.item_price_total,
        i.freight_total,
        p.payment_total,
        i.item_price_total + i.freight_total
            AS item_plus_freight_total,
        p.payment_total -
            (i.item_price_total + i.freight_total)
            AS payment_difference
    FROM ItemTotals i
    FULL OUTER JOIN PaymentTotals p
        ON i.order_id = p.order_id
)
SELECT
    order_id,
    item_price_total,
    freight_total,
    item_plus_freight_total,
    payment_total,
    payment_difference
FROM Reconciliation
WHERE item_price_total IS NULL
   OR payment_total IS NULL
   OR ABS(payment_difference) > 0.01
ORDER BY ABS(payment_difference) DESC;
GO


/* =========================================================
   SECTION 15 (CONTINUED): INVESTIGATING MISMATCHES
   Purpose: Follow up on orders flagged in the reconciliation,
   especially orders that have no item records.
   ========================================================= */

-- Check whether item records exist for the first flagged order.
SELECT
    o.order_id,
    COUNT(oi.order_id) AS item_records,
    SUM(oi.price) AS item_price_total,
    SUM(oi.freight_value) AS freight_total
FROM Orders o
LEFT JOIN order_items oi
    ON o.order_id = oi.order_id
WHERE o.order_id = 'e9f308c243d53135de5a481bf3a9cb86'
GROUP BY o.order_id;

-- Raw item rows for that order.
SELECT *
FROM order_items
WHERE order_id = 'e9f308c243d53135de5a481bf3a9cb86';

-- Raw payment rows for that order.
SELECT *
FROM order_payments
WHERE order_id = 'e9f308c243d53135de5a481bf3a9cb86';

-- Total number of orders that have no item records.
SELECT
    COUNT(*) AS orders_without_items
FROM Orders o
WHERE NOT EXISTS (
    SELECT 1
    FROM order_items oi
    WHERE oi.order_id = o.order_id
);


-- Order status breakdown of orders with no items.
SELECT
    o.order_status,
    COUNT(*) AS order_count
FROM Orders o
WHERE NOT EXISTS (
    SELECT 1
    FROM order_items oi
    WHERE oi.order_id = o.order_id
)
GROUP BY o.order_status
ORDER BY order_count DESC;


-- Itemless orders that are NOT unavailable or canceled.
-- These are the unexpected cases, shown with their payments.
SELECT
    o.order_id,
    o.order_status,
    o.order_purchase_timestamp,
    p.payment_value,
    p.payment_type
FROM Orders o
LEFT JOIN order_payments p
    ON o.order_id = p.order_id
WHERE NOT EXISTS (
    SELECT 1
    FROM order_items oi
    WHERE oi.order_id = o.order_id
)
AND o.order_status NOT IN ('unavailable', 'canceled')
ORDER BY o.order_status;


-- Reconciliation summary using SUM(DISTINCT).
-- Caution: SUM(DISTINCT) drops repeated values (e.g. two items at
-- the same price), so totals can be understated. Use the CTE
-- version below as the reliable check.
SELECT
    COUNT(*) AS total_orders_checked,
    SUM(CASE
        WHEN item_price_total IS NULL THEN 1
        ELSE 0
    END) AS orders_without_item_totals,
    SUM(CASE
        WHEN payment_total IS NULL THEN 1
        ELSE 0
    END) AS orders_without_payment_totals,
    SUM(CASE
        WHEN payment_difference IS NOT NULL
             AND ABS(payment_difference) > 1
        THEN 1
        ELSE 0
    END) AS orders_with_difference_over_1
FROM (
    SELECT
        o.order_id,
        SUM(DISTINCT oi.price) AS item_price_total,
        SUM(DISTINCT oi.freight_value) AS freight_total,
        SUM(DISTINCT op.payment_value) AS payment_total,
        SUM(DISTINCT op.payment_value)
          - SUM(DISTINCT oi.price)
          - SUM(DISTINCT oi.freight_value) AS payment_difference
    FROM Orders o
    LEFT JOIN order_items oi
        ON o.order_id = oi.order_id
    LEFT JOIN order_payments op
        ON o.order_id = op.order_id
    GROUP BY o.order_id
) AS reconciliation;


-- Final reconciliation summary across ALL orders.
-- Items and payments are aggregated first (no row multiplication),
-- then joined to Orders. Difference is NULL when either side is
-- missing, and flagged when it exceeds 1.
WITH ItemTotals AS (
    SELECT
        order_id,
        COUNT(*) AS item_count,
        SUM(price) AS item_price_total,
        SUM(freight_value) AS freight_total
    FROM order_items
    GROUP BY order_id
),
PaymentTotals AS (
    SELECT
        order_id,
        COUNT(*) AS payment_count,
        SUM(payment_value) AS payment_total
    FROM order_payments
    GROUP BY order_id
),
Reconciliation AS (
    SELECT
        o.order_id,
        o.order_status,
        i.item_count,
        i.item_price_total,
        i.freight_total,
        p.payment_count,
        p.payment_total,
        CASE
            WHEN i.order_id IS NULL
              OR p.order_id IS NULL
            THEN NULL
            ELSE p.payment_total
                 - (i.item_price_total + i.freight_total)
        END AS payment_difference
    FROM Orders o
    LEFT JOIN ItemTotals i
        ON o.order_id = i.order_id
    LEFT JOIN PaymentTotals p
        ON o.order_id = p.order_id
)
SELECT
    COUNT(*) AS total_orders_checked,
    SUM(CASE
        WHEN item_count IS NULL THEN 1
        ELSE 0
    END) AS orders_without_items,
    SUM(CASE
        WHEN payment_count IS NULL THEN 1
        ELSE 0
    END) AS orders_without_payments,
    SUM(CASE
        WHEN payment_difference IS NOT NULL
         AND ABS(payment_difference) > 1
        THEN 1
        ELSE 0
    END) AS orders_with_difference_over_1
FROM Reconciliation;
GO


/* =========================================================
   SECTION 16: CATEGORY / TRANSLATION CONSISTENCY
   Purpose: Identify non-null product categories that have
   no matching source category in the translation table.
   ========================================================= */

-- Categories without a matching translation entry.
SELECT
    p.product_category_name,
    COUNT(*) AS affected_products
FROM products p
WHERE p.product_category_name IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM translation t
      WHERE t.product_category_name =
            p.product_category_name
  )
GROUP BY p.product_category_name
ORDER BY affected_products DESC;
GO

-- Duplicate source category names in the translation table.
SELECT
    product_category_name,
    COUNT(*) AS occurrences
FROM translation
GROUP BY product_category_name
HAVING COUNT(*) > 1;
GO

-- Repeated English labels for different source categories.
-- These may be legitimate mappings; inspect before deciding.
SELECT
    product_category_name_english,
    COUNT(*) AS occurrences
FROM translation
GROUP BY product_category_name_english
HAVING COUNT(*) > 1;
GO


/* =========================================================
   SECTION 17: DATE COLUMN DATA TYPES
   Purpose: Confirm the Orders date columns use proper date
   types, since text dates would break the comparisons above.
   ========================================================= */

USE BrazilianECommerce;
GO

-- List the data type of each date column in Orders.
SELECT
    TABLE_NAME,
    COLUMN_NAME,
    DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'Orders'
  AND COLUMN_NAME IN (
      'order_purchase_timestamp',
      'order_approved_at',
      'order_delivered_carrier_date',
      'order_delivered_customer_date',
      'order_estimated_delivery_date'
  )
ORDER BY ORDINAL_POSITION;
GO


/* =========================================================
   SECTION 18: REPEAT CUSTOMERS
   Purpose: Identify people (customer_unique_id) who appear
   under more than one customer_id.
   ========================================================= */

-- Every person with more than one customer_id, with the number
-- of times they appear.
SELECT customer_unique_id,
count (*) as times_repeated
FROM Customer
GROUP BY customer_unique_id
HAVING COUNT(*) > 1;

-- Inspect all records for one repeat customer.
select * from Customer
where customer_unique_id = '31d332d20895c5c0baefe55207a0fead'
