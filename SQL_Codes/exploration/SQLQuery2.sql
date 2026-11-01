USE BrazilianECommerce;
GO

CREATE OR ALTER VIEW vw_OrderSalesSummary AS

WITH ItemTotals AS (
    SELECT
        order_id,
        COUNT(*) AS total_items,
        SUM(price) AS item_sales,
        SUM(freight_value) AS freight_total
    FROM order_items
    GROUP BY order_id
),
PaymentTotals AS (
    SELECT
        order_id,
        SUM(payment_value) AS payment_total
    FROM order_payments
    GROUP BY order_id
)

SELECT
    o.order_id,
    o.customer_id,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_delivered_customer_date,
    i.total_items,
    i.item_sales,
    i.freight_total,
    p.payment_total
FROM Orders o
LEFT JOIN ItemTotals i
    ON o.order_id = i.order_id
LEFT JOIN PaymentTotals p
    ON o.order_id = p.order_id;
GO

SELECT top 10*
FROM vw_OrderSalesSummary;