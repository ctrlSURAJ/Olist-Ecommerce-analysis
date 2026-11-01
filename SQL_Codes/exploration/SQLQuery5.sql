USE BrazilianECommerce;
GO

CREATE OR ALTER VIEW vw_DeliveryReviewAnalysis AS
SELECT
    o.order_id,
    o.customer_id,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    r.review_id,
    r.review_score,
    r.review_creation_date
FROM Orders o
LEFT JOIN order_reviews r
    ON o.order_id = r.order_id;
GO


SELECT TOP 10 *
FROM vw_DeliveryReviewAnalysis;


SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_id) AS unique_orders,
    COUNT(DISTINCT review_id) AS unique_reviews
FROM vw_DeliveryReviewAnalysis;

SELECT
    'Orders' AS table_name,
    COUNT(*) AS total_rows
FROM Orders

UNION ALL

SELECT
    'vw_OrderSalesSummary',
    COUNT(*)
FROM vw_OrderSalesSummary

UNION ALL

SELECT
    'Customer',
    COUNT(*)
FROM Customer

UNION ALL

SELECT
    'vw_CustomerOrderAnalysis',
    COUNT(*)
FROM vw_CustomerOrderAnalysis

UNION ALL

SELECT
    'order_items',
    COUNT(*)
FROM order_items

UNION ALL

SELECT
    'vw_ProductSellerPerformance',
    COUNT(*)
FROM vw_ProductSellerPerformance

UNION ALL

SELECT
    'order_reviews',
    COUNT(*)
FROM order_reviews

UNION ALL

SELECT
    'vw_DeliveryReviewAnalysis',
    COUNT(*)
FROM vw_DeliveryReviewAnalysis;


SELECT
    COUNT(*) AS total_review_records,
    COUNT(DISTINCT review_id) AS unique_review_ids,
    COUNT(DISTINCT order_id) AS orders_with_reviews
FROM order_reviews;


SELECT
    order_id,
    COUNT(*) AS review_records,
    COUNT(DISTINCT review_id) AS unique_review_ids
FROM order_reviews
GROUP BY order_id
HAVING COUNT(*) > 1
ORDER BY review_records DESC;

SELECT
    order_id,
    COUNT(*) AS review_records,
    COUNT(DISTINCT review_id) AS unique_review_ids,
    COUNT(DISTINCT review_score) AS different_review_scores
FROM order_reviews
GROUP BY order_id
HAVING COUNT(*) > 1
ORDER BY different_review_scores DESC, review_records DESC;



SELECT
    different_review_scores,
    COUNT(*) AS order_count
FROM (
    SELECT
        order_id,
        COUNT(*) AS review_records,
        COUNT(DISTINCT review_score) AS different_review_scores
    FROM order_reviews
    GROUP BY order_id
    HAVING COUNT(*) > 1
) AS MultipleReviews
GROUP BY different_review_scores
ORDER BY different_review_scores;