-- =====================================================================
-- Step 4: DATA QUALITY CHECKS (validation + reconciliation)
-- Run each query and note the result in the README "Data quality" table.
-- These are the checks a BA does before trusting any dashboard.
-- =====================================================================

-- DQ1. Load reconciliation: raw rows vs clean rows (should match,
--      except reviews, where we deliberately keep one per order)
SELECT 'orders' AS table_name,
       (SELECT COUNT(*) FROM raw.orders)        AS raw_rows,
       (SELECT COUNT(*) FROM olist.orders)      AS clean_rows
UNION ALL
SELECT 'order_items',
       (SELECT COUNT(*) FROM raw.order_items),
       (SELECT COUNT(*) FROM olist.order_items)
UNION ALL
SELECT 'order_reviews',
       (SELECT COUNT(*) FROM raw.order_reviews),
       (SELECT COUNT(*) FROM olist.order_reviews);

-- DQ2. Duplicate keys (expect 0 for both)
SELECT
    (SELECT COUNT(*) - COUNT(DISTINCT order_id)    FROM raw.orders)    AS duplicate_order_ids,
    (SELECT COUNT(*) - COUNT(DISTINCT customer_id) FROM raw.customers) AS duplicate_customer_ids;

-- DQ3. Orders with more than one review (why we de-duplicated reviews)
SELECT COUNT(*) AS orders_with_multiple_reviews
FROM (
    SELECT TRIM(order_id) AS order_id
    FROM raw.order_reviews
    GROUP BY TRIM(order_id)
    HAVING COUNT(*) > 1
) x;

-- DQ4. Order status breakdown, and missing timestamps by status
SELECT
    order_status,
    COUNT(*)                                                         AS orders,
    COUNT(*) FILTER (WHERE order_approved_at IS NULL)                AS missing_approved,
    COUNT(*) FILTER (WHERE order_delivered_customer_date IS NULL)    AS missing_delivered_date
FROM olist.orders
GROUP BY order_status
ORDER BY orders DESC;

-- DQ5. Orphan / missing links
SELECT
    (SELECT COUNT(*) FROM olist.orders o
      WHERE NOT EXISTS (SELECT 1 FROM olist.order_items i WHERE i.order_id = o.order_id))
        AS orders_without_items,
    (SELECT COUNT(*) FROM olist.order_items i
      WHERE NOT EXISTS (SELECT 1 FROM olist.orders o WHERE o.order_id = i.order_id))
        AS items_without_order,
    (SELECT COUNT(*) FROM olist.orders o
      WHERE NOT EXISTS (SELECT 1 FROM olist.order_payments p WHERE p.order_id = o.order_id))
        AS orders_without_payment;

-- DQ6. Impossible dates (delivered before purchase)
SELECT COUNT(*) AS delivered_before_purchase
FROM olist.orders
WHERE order_delivered_customer_date < order_purchase_timestamp;

-- DQ7. Payment reconciliation: does what the customer paid match
--      item price + freight? (differences come from instalment
--      interest and vouchers)
WITH item_totals AS (
    SELECT order_id, SUM(price + freight_value) AS items_total
    FROM olist.order_items
    GROUP BY order_id
),
pay_totals AS (
    SELECT order_id, SUM(payment_value) AS paid_total
    FROM olist.order_payments
    GROUP BY order_id
)
SELECT
    COUNT(*)                                                     AS orders_compared,
    COUNT(*) FILTER (WHERE ABS(p.paid_total - i.items_total) <= 1) AS match_within_1,
    COUNT(*) FILTER (WHERE ABS(p.paid_total - i.items_total) > 1)  AS mismatch_over_1,
    ROUND(100.0 * COUNT(*) FILTER (WHERE ABS(p.paid_total - i.items_total) <= 1)
          / COUNT(*), 1)                                         AS match_pct
FROM item_totals i
JOIN pay_totals p USING (order_id);

-- DQ8. Products with no category, and categories with no English name
SELECT
    (SELECT COUNT(*) FROM raw.products WHERE NULLIF(TRIM(product_category_name), '') IS NULL)
        AS products_without_category,
    (SELECT STRING_AGG(DISTINCT TRIM(p.product_category_name), ', ')
       FROM raw.products p
       LEFT JOIN raw.category_translation t
              ON TRIM(t.product_category_name) = TRIM(p.product_category_name)
      WHERE t.product_category_name IS NULL
        AND NULLIF(TRIM(p.product_category_name), '') IS NOT NULL)
        AS categories_without_translation;

-- DQ9. Orders outside the analysis window (Jan 2017 - Aug 2018).
--      Months before and after have very few orders, so they would
--      distort monthly trends.
SELECT
    COUNT(*) FILTER (WHERE order_purchase_timestamp <  DATE '2017-01-01') AS before_window,
    COUNT(*) FILTER (WHERE order_purchase_timestamp >= DATE '2018-09-01') AS after_window
FROM olist.orders;
