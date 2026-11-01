-- 1. Basic overview
SELECT
    COUNT(*) AS total_payment_records,
    COUNT(DISTINCT order_id) AS unique_orders,
    COUNT(DISTINCT payment_type) AS payment_types
FROM dbo.order_payments;


-- 2. Missing values
SELECT
    SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END) AS missing_order_id,
    SUM(CASE WHEN payment_sequential IS NULL THEN 1 ELSE 0 END) AS missing_payment_sequential,
    SUM(CASE WHEN payment_type IS NULL THEN 1 ELSE 0 END) AS missing_payment_type,
    SUM(CASE WHEN payment_installments IS NULL THEN 1 ELSE 0 END) AS missing_installments,
    SUM(CASE WHEN payment_value IS NULL THEN 1 ELSE 0 END) AS missing_payment_value
FROM dbo.order_payments;


-- 3. Zero and negative payment values
SELECT
    SUM(CASE WHEN payment_value = 0 THEN 1 ELSE 0 END) AS zero_payment_values,
    SUM(CASE WHEN payment_value < 0 THEN 1 ELSE 0 END) AS negative_payment_values,
    SUM(CASE WHEN payment_installments = 0 THEN 1 ELSE 0 END) AS zero_installments,
    SUM(CASE WHEN payment_installments < 0 THEN 1 ELSE 0 END) AS negative_installments
FROM dbo.order_payments;


-- 4. Payment type distribution
SELECT
    payment_type,
    COUNT(*) AS payment_records,
    COUNT(DISTINCT order_id) AS unique_orders,
    AVG(payment_value) AS average_payment_value
FROM dbo.order_payments
GROUP BY payment_type
ORDER BY payment_records DESC;


-- 5. Payment value summary
SELECT
    MIN(payment_value) AS minimum_payment,
    MAX(payment_value) AS maximum_payment,
    AVG(payment_value) AS average_payment,
    MIN(payment_installments) AS minimum_installments,
    MAX(payment_installments) AS maximum_installments
FROM dbo.order_payments;



-- 1. Inspect zero-payment records
SELECT *
FROM dbo.order_payments
WHERE payment_value = 0;


-- 2. Inspect zero-installment records
SELECT *
FROM dbo.order_payments
WHERE payment_installments = 0;


-- 3. Inspect undefined payment types
SELECT *
FROM dbo.order_payments
WHERE payment_type = 'not_defined';


-- 4. Inspect the ten highest payments
SELECT TOP 10 *
FROM dbo.order_payments
ORDER BY payment_value DESC;