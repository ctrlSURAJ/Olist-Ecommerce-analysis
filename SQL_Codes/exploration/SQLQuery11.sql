SELECT
    COUNT(*) AS total_unique_customers,
    SUM(
        CASE WHEN order_count = 1 THEN 1 ELSE 0 END
    ) AS customers_with_one_order,
    SUM(
        CASE WHEN order_count > 1 THEN 1 ELSE 0 END
    ) AS repeat_customers,
    MAX(order_count) AS maximum_orders_by_one_customer
FROM
(
    SELECT
        c.customer_unique_id,
        COUNT(o.order_id) AS order_count
    FROM dbo.Customer AS c
    INNER JOIN dbo.Orders AS o
        ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
) AS customer_orders;