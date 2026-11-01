-- 1. Basic overview
SELECT
    COUNT(*) AS total_order_items,
    COUNT(DISTINCT order_id) AS unique_orders,
    COUNT(DISTINCT product_id) AS unique_products,
    COUNT(DISTINCT seller_id) AS unique_sellers
FROM dbo.order_items;


-- 2. Missing values
SELECT
    SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END) AS missing_order_id,
    SUM(CASE WHEN order_item_id IS NULL THEN 1 ELSE 0 END) AS missing_order_item_id,
    SUM(CASE WHEN product_id IS NULL THEN 1 ELSE 0 END) AS missing_product_id,
    SUM(CASE WHEN seller_id IS NULL THEN 1 ELSE 0 END) AS missing_seller_id,
    SUM(CASE WHEN price IS NULL THEN 1 ELSE 0 END) AS missing_price,
    SUM(CASE WHEN freight_value IS NULL THEN 1 ELSE 0 END) AS missing_freight_value
FROM dbo.order_items;


-- 3. Unusual price and freight values
SELECT
    SUM(CASE WHEN price < 0 THEN 1 ELSE 0 END) AS negative_prices,
    SUM(CASE WHEN price = 0 THEN 1 ELSE 0 END) AS zero_prices,
    SUM(CASE WHEN freight_value < 0 THEN 1 ELSE 0 END) AS negative_freight,
    SUM(CASE WHEN freight_value = 0 THEN 1 ELSE 0 END) AS zero_freight
FROM dbo.order_items;


-- 4. Duplicate order-item combinations
SELECT
    order_id,
    order_item_id,
    COUNT(*) AS occurrences
FROM dbo.order_items
GROUP BY order_id, order_item_id
HAVING COUNT(*) > 1;


-- 5. Summary statistics for price and freight
SELECT
    MIN(price) AS minimum_price,
    MAX(price) AS maximum_price,
    AVG(price) AS average_price,
    MIN(freight_value) AS minimum_freight,
    MAX(freight_value) AS maximum_freight,
    AVG(freight_value) AS average_freight
FROM dbo.order_items;



-- 1. Understand zero-freight records
SELECT
    COUNT(*) AS zero_freight_items,
    COUNT(DISTINCT order_id) AS affected_orders,
    COUNT(DISTINCT product_id) AS affected_products,
    MIN(price) AS minimum_product_price,
    MAX(price) AS maximum_product_price,
    AVG(price) AS average_product_price
FROM dbo.order_items
WHERE freight_value = 0;


-- 2. Inspect sample records
SELECT TOP 20
    order_id,
    order_item_id,
    product_id,
    seller_id,
    price,
    freight_value
FROM dbo.order_items
WHERE freight_value = 0
ORDER BY price DESC;

SELECT
    product_id,
    COUNT(*) AS zero_freight_items,
    COUNT(DISTINCT order_id) AS affected_orders,
    COUNT(DISTINCT seller_id) AS sellers,
    MIN(price) AS minimum_price,
    MAX(price) AS maximum_price,
    AVG(price) AS average_price
FROM dbo.order_items
WHERE freight_value = 0
GROUP BY product_id
ORDER BY zero_freight_items DESC;