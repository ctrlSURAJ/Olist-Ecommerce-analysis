USE BrazilianECommerce;
GO

CREATE OR ALTER VIEW vw_ReviewAnalysis AS
SELECT
    order_id,
    COUNT(*) AS total_review_records,
    AVG(CAST(review_score AS FLOAT)) AS average_review_score,
    MIN(review_score) AS lowest_review_score,
    MAX(review_score) AS highest_review_score
FROM order_reviews
GROUP BY order_id;
GO

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_id) AS unique_orders
FROM vw_ReviewAnalysis;