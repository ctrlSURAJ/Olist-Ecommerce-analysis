USE BrazilianECommerce;
GO

CREATE OR ALTER VIEW vw_ProductSellerPerformance AS
SELECT
    oi.order_id,
    oi.order_item_id,
    oi.product_id,
    p.product_category_name,
    oi.seller_id,
    s.seller_city,
    s.seller_state,
    oi.price AS item_price,
    oi.freight_value
FROM order_items oi
LEFT JOIN products p
    ON oi.product_id = p.product_id
LEFT JOIN sellers s
    ON oi.seller_id = s.seller_id;
GO


SELECT TOP 10 *
FROM vw_ProductSellerPerformance;

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_id) AS unique_orders,
    COUNT(DISTINCT product_id) AS unique_products,
    COUNT(DISTINCT seller_id) AS unique_sellers
FROM vw_ProductSellerPerformance;