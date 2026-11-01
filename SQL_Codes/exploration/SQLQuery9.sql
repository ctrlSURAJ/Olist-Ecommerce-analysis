WITH DeliveryDelays AS
(
    SELECT
        order_id,
        DATEDIFF(
            DAY,
            order_estimated_delivery_date,
            order_delivered_customer_date
        ) AS delay_days
    FROM dbo.Orders
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
)
SELECT
    CASE
        WHEN delay_days <= 0 THEN 'On time or early'
        WHEN delay_days BETWEEN 1 AND 7 THEN '1-7 days late'
        WHEN delay_days BETWEEN 8 AND 30 THEN '8-30 days late'
        WHEN delay_days BETWEEN 31 AND 60 THEN '31-60 days late'
        ELSE 'More than 60 days late'
    END AS delivery_delay_category,
    COUNT(*) AS total_orders
FROM DeliveryDelays
GROUP BY
    CASE
        WHEN delay_days <= 0 THEN 'On time or early'
        WHEN delay_days BETWEEN 1 AND 7 THEN '1-7 days late'
        WHEN delay_days BETWEEN 8 AND 30 THEN '8-30 days late'
        WHEN delay_days BETWEEN 31 AND 60 THEN '31-60 days late'
        ELSE 'More than 60 days late'
    END
ORDER BY MIN(delay_days);