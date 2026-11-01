USE BrazilianECommerce;
GO

CREATE OR ALTER VIEW vw_DeliveryAnalysis AS
SELECT
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date
FROM Orders;
GO

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_id) AS unique_orders
FROM vw_DeliveryAnalysis;

