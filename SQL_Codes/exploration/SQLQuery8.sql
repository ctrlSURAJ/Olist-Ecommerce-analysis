USE BrazilianECommerce;
GO

SELECT 'vw_OrderSalesSummary' AS view_name, COUNT(*) AS total_rows
FROM vw_OrderSalesSummary

UNION ALL

SELECT 'vw_CustomerOrderAnalysis', COUNT(*)
FROM vw_CustomerOrderAnalysis

UNION ALL

SELECT 'vw_ProductSellerPerformance', COUNT(*)
FROM vw_ProductSellerPerformance

UNION ALL

SELECT 'vw_DeliveryAnalysis', COUNT(*)
FROM vw_DeliveryAnalysis

UNION ALL

SELECT 'vw_ReviewAnalysis', COUNT(*)
FROM vw_ReviewAnalysis;


SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_id) AS unique_orders
FROM dbo.vw_DeliveryReviewAnalysis;

SELECT
    order_id,
    order_status,
    order_purchase_timestamp,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date
FROM Orders
WHERE order_delivered_customer_date >= '2017-09-19'
  AND order_delivered_customer_date < '2017-09-20'
ORDER BY order_purchase_timestamp;


SELECT
    order_id,
    order_purchase_timestamp,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date,
    DATEDIFF(
        DAY,
        order_estimated_delivery_date,
        order_delivered_customer_date
    ) AS days_after_estimated_delivery
FROM dbo.Orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL
  AND DATEDIFF(
        DAY,
        order_estimated_delivery_date,
        order_delivered_customer_date
      ) >= 30
ORDER BY days_after_estimated_delivery DESC;