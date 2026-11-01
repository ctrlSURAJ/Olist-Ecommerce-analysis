USE BrazilianECommerce;
GO

CREATE OR ALTER VIEW vw_CustomerOrderAnalysis AS
SELECT
    c.customer_id,
    c.customer_unique_id,
    c.customer_city,
    c.customer_state,
    o.order_id,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_delivered_customer_date
FROM Customer c
LEFT JOIN Orders o
    ON c.customer_id = o.customer_id;
GO

SELECT TOP 10 *
FROM vw_CustomerOrderAnalysis;

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT customer_id) AS unique_customer_records,
    COUNT(DISTINCT order_id) AS unique_orders
FROM vw_CustomerOrderAnalysis;