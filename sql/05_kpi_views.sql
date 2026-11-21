-- =====================================================================
-- Step 5: KPI VIEWS for Power BI
-- Business rules (write these in the README KPI dictionary):
--   * Analysis window: orders purchased 1 Jan 2017 - 31 Aug 2018.
--   * Canceled and unavailable orders are excluded from sales KPIs.
--   * Order value = item prices + freight.
--   * Late = delivered to the customer AFTER the estimated delivery date
--     (compared by calendar date). Only delivered orders count.
-- =====================================================================

-- Drop old versions first, so this file can be re-run safely.
DROP VIEW IF EXISTS olist.v_seller_performance, olist.v_monthly_kpis,
                    olist.v_fact_order_items, olist.v_fact_orders;

-- ---------- 1. One row per order ----------
CREATE OR REPLACE VIEW olist.v_fact_orders AS
WITH item_totals AS (
    SELECT order_id,
           COUNT(*)            AS items_count,
           SUM(price)          AS product_revenue,
           SUM(freight_value)  AS freight_value
    FROM olist.order_items
    GROUP BY order_id
),
main_payment AS (   -- the payment method that paid the largest share
    SELECT DISTINCT ON (order_id)
           order_id, payment_type, payment_installments
    FROM olist.order_payments
    ORDER BY order_id, payment_value DESC, payment_sequential
),
base AS (
    SELECT
        o.order_id,
        c.customer_unique_id,
        c.customer_state,
        s.state_name                                   AS customer_state_name,
        s.region                                       AS customer_region,
        o.order_status,
        o.order_purchase_timestamp,
        o.order_purchase_timestamp::date               AS purchase_date,
        DATE_TRUNC('month', o.order_purchase_timestamp)::date AS purchase_month,
        it.items_count,
        it.product_revenue,
        it.freight_value,
        it.product_revenue + it.freight_value          AS order_value,
        mp.payment_type,
        mp.payment_installments,
        CASE WHEN o.order_status = 'delivered'
              AND o.order_delivered_customer_date IS NOT NULL THEN 1 ELSE 0 END AS is_delivered,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date,
        r.review_score
    FROM olist.orders o
    JOIN item_totals it        ON it.order_id = o.order_id
    JOIN olist.customers c     ON c.customer_id = o.customer_id
    LEFT JOIN olist.states s   ON s.state_code = c.customer_state
    LEFT JOIN main_payment mp  ON mp.order_id = o.order_id
    LEFT JOIN olist.order_reviews r ON r.order_id = o.order_id
    WHERE o.order_purchase_timestamp >= DATE '2017-01-01'
      AND o.order_purchase_timestamp <  DATE '2018-09-01'
      AND o.order_status NOT IN ('canceled', 'unavailable')
)
SELECT
    b.order_id,
    b.customer_unique_id,
    b.customer_state,
    b.customer_state_name,
    b.customer_region,
    b.order_status,
    b.order_purchase_timestamp,
    b.purchase_date,
    b.purchase_month,
    b.items_count,
    b.product_revenue,
    b.freight_value,
    b.order_value,
    b.payment_type,
    b.payment_installments,
    b.is_delivered,
    -- delivery time in days (1 decimal), delivered orders only
    CASE WHEN b.is_delivered = 1 THEN
         ROUND((EXTRACT(EPOCH FROM b.order_delivered_customer_date
                                  - b.order_purchase_timestamp) / 86400)::numeric, 1)
    END AS delivery_days,
    -- promised delivery time in days
    (b.order_estimated_delivery_date::date - b.purchase_date) AS promised_days,
    -- 1 = late, 0 = on time, NULL = not delivered yet
    CASE WHEN b.is_delivered = 1 THEN
         CASE WHEN b.order_delivered_customer_date::date > b.order_estimated_delivery_date::date
              THEN 1 ELSE 0 END
    END AS is_late,
    CASE WHEN b.is_delivered = 1 THEN
         GREATEST(b.order_delivered_customer_date::date - b.order_estimated_delivery_date::date, 0)
    END AS days_late,
    -- ready-made groups for the dashboard (numbered so they sort correctly)
    CASE WHEN b.is_delivered = 1 THEN
         CASE
             WHEN b.order_delivered_customer_date::date <= b.order_estimated_delivery_date::date
                  THEN '1. On time'
             WHEN b.order_delivered_customer_date::date - b.order_estimated_delivery_date::date <= 3
                  THEN '2. 1-3 days late'
             WHEN b.order_delivered_customer_date::date - b.order_estimated_delivery_date::date <= 7
                  THEN '3. 4-7 days late'
             ELSE '4. 8+ days late'
         END
    END AS lateness_bucket,
    b.review_score,
    -- 1st, 2nd, 3rd... order of the same real customer
    ROW_NUMBER() OVER (PARTITION BY b.customer_unique_id
                       ORDER BY b.order_purchase_timestamp, b.order_id) AS customer_order_number
FROM base b;

-- ---------- 2. One row per item (for category and seller analysis) ----------
CREATE OR REPLACE VIEW olist.v_fact_order_items AS
SELECT
    i.order_id,
    i.order_item_id,
    f.purchase_date,
    f.purchase_month,
    i.product_id,
    p.category,
    i.seller_id,
    se.seller_state,
    f.customer_state,
    i.price,
    i.freight_value,
    i.price + i.freight_value  AS item_value,
    f.is_late,
    f.review_score
FROM olist.order_items i
JOIN olist.v_fact_orders f ON f.order_id = i.order_id
LEFT JOIN olist.products p  ON p.product_id = i.product_id
LEFT JOIN olist.sellers se  ON se.seller_id = i.seller_id;

-- ---------- 3. Monthly KPI table (trend + growth) ----------
CREATE OR REPLACE VIEW olist.v_monthly_kpis AS
WITH m AS (
    SELECT
        purchase_month,
        COUNT(*)                                    AS orders,
        SUM(order_value)                            AS revenue,
        AVG(order_value)                            AS avg_order_value,
        100.0 * (1 - AVG(is_late))                  AS on_time_pct,   -- AVG ignores NULLs
        AVG(review_score)                           AS avg_review
    FROM olist.v_fact_orders
    GROUP BY purchase_month
)
SELECT
    purchase_month,
    orders,
    ROUND(revenue, 0)                               AS revenue,
    ROUND(avg_order_value, 2)                       AS avg_order_value,
    ROUND(on_time_pct, 1)                           AS on_time_pct,
    ROUND(avg_review, 2)                            AS avg_review,
    ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY purchase_month))
          / NULLIF(LAG(revenue) OVER (ORDER BY purchase_month), 0), 1) AS revenue_mom_pct,
    ROUND(AVG(revenue) OVER (ORDER BY purchase_month
                             ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 0) AS revenue_3m_avg
FROM m;

-- ---------- 4. Seller scorecard (sellers with 30+ orders) ----------
CREATE OR REPLACE VIEW olist.v_seller_performance AS
WITH seller_orders AS (   -- one row per seller per order
    SELECT
        i.seller_id,
        i.order_id,
        SUM(i.item_value) AS seller_order_value,
        MAX(i.is_late)    AS is_late,
        MAX(i.review_score) AS review_score
    FROM olist.v_fact_order_items i
    GROUP BY i.seller_id, i.order_id
)
SELECT
    so.seller_id,
    se.seller_city,
    se.seller_state,
    COUNT(*)                                          AS orders,
    ROUND(SUM(so.seller_order_value), 0)              AS revenue,
    ROUND(100.0 * (1 - AVG(so.is_late)), 1)           AS on_time_pct,
    ROUND(AVG(so.review_score), 2)                    AS avg_review,
    ROUND(100.0 * AVG(CASE WHEN so.review_score <= 2 THEN 1.0
                           WHEN so.review_score IS NOT NULL THEN 0.0 END), 1) AS low_review_pct
FROM seller_orders so
JOIN olist.sellers se ON se.seller_id = so.seller_id
GROUP BY so.seller_id, se.seller_city, se.seller_state
HAVING COUNT(*) >= 30;
