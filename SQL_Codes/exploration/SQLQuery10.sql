-- 1. Total customers
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT customer_id) AS unique_customer_ids,
    COUNT(DISTINCT customer_unique_id) AS unique_customers
FROM dbo.Customer;


-- 2. Missing values
SELECT
    SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) AS missing_customer_id,
    SUM(CASE WHEN customer_unique_id IS NULL THEN 1 ELSE 0 END) AS missing_customer_unique_id,
    SUM(CASE WHEN customer_zip_code_prefix IS NULL THEN 1 ELSE 0 END) AS missing_zip_code,
    SUM(CASE WHEN customer_city IS NULL THEN 1 ELSE 0 END) AS missing_city,
    SUM(CASE WHEN customer_state IS NULL THEN 1 ELSE 0 END) AS missing_state
FROM dbo.Customer;


-- 3. Duplicate customer IDs
SELECT
    customer_id,
    COUNT(*) AS occurrences
FROM dbo.Customer
GROUP BY customer_id
HAVING COUNT(*) > 1;


-- 4. Customers by state
SELECT
    customer_state,
    COUNT(*) AS customer_records
FROM dbo.Customer
GROUP BY customer_state
ORDER BY customer_records DESC;


-- 5. Top 10 cities by customer records
SELECT TOP 10
    customer_city,
    customer_state,
    COUNT(*) AS customer_records
FROM dbo.Customer
GROUP BY customer_city, customer_state
ORDER BY customer_records DESC;