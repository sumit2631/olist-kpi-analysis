-- =====================================================================
-- Step 6: BUSINESS QUESTIONS
-- Each query answers one question a manager would ask.
-- Techniques used: CTEs, FILTER, CASE, window functions (LAG, LEAD,
-- RANK, running SUM), PERCENTILE_CONT.
-- =====================================================================

-- Q1. Headline KPIs for the whole period (Jan 2017 - Aug 2018)
SELECT
    COUNT(*)                                           AS orders,
    COUNT(DISTINCT customer_unique_id)                 AS customers,
    ROUND(SUM(order_value), 0)                         AS revenue,
    ROUND(AVG(order_value), 2)                         AS avg_order_value,
    ROUND(100.0 * (1 - AVG(is_late)), 1)               AS on_time_pct,
    ROUND(AVG(delivery_days), 1)                       AS avg_delivery_days,
    ROUND(AVG(review_score), 2)                        AS avg_review
FROM olist.v_fact_orders;

-- Q2. Monthly trend: revenue growth and on-time %
--     (look at Nov 2017 and Feb-Mar 2018)
SELECT purchase_month, orders, revenue, revenue_mom_pct, on_time_pct, avg_review
FROM olist.v_monthly_kpis
ORDER BY purchase_month;

-- Q3. Do late deliveries hurt customer reviews?
SELECT
    CASE is_late WHEN 1 THEN 'Late' ELSE 'On time' END   AS delivery,
    COUNT(*)                                             AS orders,
    ROUND(AVG(review_score), 2)                          AS avg_review,
    ROUND(100.0 * AVG(CASE WHEN review_score <= 2 THEN 1.0 ELSE 0.0 END), 1) AS pct_1_2_star
FROM olist.v_fact_orders
WHERE is_delivered = 1
  AND review_score IS NOT NULL
GROUP BY 1
ORDER BY 1;

-- Q4. The later the order, the worse the review (days late buckets)
SELECT
    CASE
        WHEN days_late = 0  THEN '0 (on time)'
        WHEN days_late <= 3 THEN '1-3 days late'
        WHEN days_late <= 7 THEN '4-7 days late'
        ELSE '8+ days late'
    END                                  AS lateness,
    COUNT(*)                             AS orders,
    ROUND(AVG(review_score), 2)          AS avg_review
FROM olist.v_fact_orders
WHERE is_delivered = 1 AND review_score IS NOT NULL
GROUP BY 1
ORDER BY MIN(days_late);

-- Q5. Which customer states get the slowest and least reliable delivery?
--     (states with at least 500 delivered orders)
SELECT
    customer_state,
    customer_state_name,
    COUNT(*)                                      AS delivered_orders,
    ROUND(AVG(delivery_days), 1)                  AS avg_delivery_days,
    ROUND(100.0 * (1 - AVG(is_late)), 1)          AS on_time_pct,
    ROUND(AVG(review_score), 2)                   AS avg_review
FROM olist.v_fact_orders
WHERE is_delivered = 1
GROUP BY customer_state, customer_state_name
HAVING COUNT(*) >= 500
ORDER BY on_time_pct ASC;

-- Q6. Delivery time distribution by region: median and 90th percentile
--     (median is fairer than the average because a few orders take very long)
SELECT
    customer_region,
    COUNT(*)                                                                AS delivered_orders,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY delivery_days)::numeric, 1) AS median_days,
    ROUND(PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY delivery_days)::numeric, 1) AS p90_days
FROM olist.v_fact_orders
WHERE is_delivered = 1
GROUP BY customer_region
ORDER BY median_days;

-- Q7. Top 10 categories by revenue, with share and running (Pareto) share
WITH cat AS (
    SELECT category, SUM(item_value) AS revenue
    FROM olist.v_fact_order_items
    GROUP BY category
)
SELECT
    RANK() OVER (ORDER BY revenue DESC)                                   AS rnk,
    category,
    ROUND(revenue, 0)                                                     AS revenue,
    ROUND(100.0 * revenue / SUM(revenue) OVER (), 1)                      AS share_pct,
    ROUND(100.0 * SUM(revenue) OVER (ORDER BY revenue DESC)
          / SUM(revenue) OVER (), 1)                                      AS cumulative_share_pct
FROM cat
ORDER BY revenue DESC
LIMIT 10;

-- Q8. Seller action list: the 10 sellers (30+ orders) with the worst on-time %
SELECT
    RANK() OVER (ORDER BY on_time_pct ASC, orders DESC) AS worst_rank,
    seller_id, seller_city, seller_state, orders, revenue, on_time_pct, avg_review
FROM olist.v_seller_performance
ORDER BY on_time_pct ASC, orders DESC
LIMIT 10;

-- Q9. Repeat customers: how many come back, and after how long?
WITH seq AS (
    SELECT
        customer_unique_id,
        customer_order_number,
        purchase_date,
        LEAD(purchase_date) OVER (PARTITION BY customer_unique_id
                                  ORDER BY customer_order_number) AS next_purchase_date
    FROM olist.v_fact_orders
)
SELECT
    COUNT(DISTINCT customer_unique_id)                                        AS customers,
    COUNT(DISTINCT customer_unique_id) FILTER (WHERE next_purchase_date IS NOT NULL
                                                 AND customer_order_number = 1) AS repeat_customers,
    ROUND(100.0 * COUNT(DISTINCT customer_unique_id) FILTER (WHERE next_purchase_date IS NOT NULL
                                                             AND customer_order_number = 1)
          / COUNT(DISTINCT customer_unique_id), 1)                            AS repeat_rate_pct,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY next_purchase_date - purchase_date)
        FILTER (WHERE customer_order_number = 1 AND next_purchase_date IS NOT NULL)
                                                                              AS median_days_to_2nd_order
FROM seq;

-- Q10. Payment mix
SELECT
    payment_type,
    COUNT(*)                                              AS orders,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)    AS share_pct,
    ROUND(AVG(order_value), 2)                            AS avg_order_value,
    ROUND(AVG(payment_installments), 1)                   AS avg_installments
FROM olist.v_fact_orders
GROUP BY payment_type
ORDER BY orders DESC;
