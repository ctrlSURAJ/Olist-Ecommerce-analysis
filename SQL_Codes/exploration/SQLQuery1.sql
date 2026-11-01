WITH ItemTotals AS (
    SELECT
        order_id,
        COUNT(*) AS item_count,
        SUM(price) AS item_price_total,
        SUM(freight_value) AS freight_total
    FROM order_items
    GROUP BY order_id
),
PaymentTotals AS (
    SELECT
        order_id,
        COUNT(*) AS payment_count,
        SUM(payment_value) AS payment_total
    FROM order_payments
    GROUP BY order_id
)
SELECT TOP 20
    o.order_id,
    o.order_status,
    i.item_count,
    i.item_price_total,
    i.freight_total,
    p.payment_total,
    p.payment_total
        - (i.item_price_total + i.freight_total)
        AS payment_difference
FROM Orders o
JOIN ItemTotals i
    ON o.order_id = i.order_id
JOIN PaymentTotals p
    ON o.order_id = p.order_id
WHERE ABS(
    p.payment_total
        - (i.item_price_total + i.freight_total)
) > 1
ORDER BY ABS(
    p.payment_total
        - (i.item_price_total + i.freight_total)
) DESC;




SELECT
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value
FROM order_payments
WHERE order_id = 'ce6d150fb29ada17d2082f4847107665'
ORDER BY payment_sequential;




SELECT
    order_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date
FROM Orders
WHERE order_id = 'ce6d150fb29ada17d2082f4847107665';



WITH ItemTotals AS (
    SELECT
        order_id,
        SUM(price) AS item_price_total,
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
),
Differences AS (
    SELECT
        o.order_id,
        p.payment_total
          - (i.item_price_total + i.freight_total) AS payment_difference
    FROM Orders o
    JOIN ItemTotals i
        ON o.order_id = i.order_id
    JOIN PaymentTotals p
        ON o.order_id = p.order_id
)
SELECT
    CASE
        WHEN payment_difference > 1 THEN 'Payment higher'
        WHEN payment_difference < -1 THEN 'Payment lower'
    END AS discrepancy_type,
    COUNT(*) AS order_count
FROM Differences
WHERE ABS(payment_difference) > 1
GROUP BY
    CASE
        WHEN payment_difference > 1 THEN 'Payment higher'
        WHEN payment_difference < -1 THEN 'Payment lower'
    END;
