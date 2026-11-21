-- =====================================================================
-- Step 3: CLEAN layer (schema "olist")
-- Fix data types, trim spaces, standardise text, fill missing category
-- names, keep one review per order, add a state/region lookup.
-- Can be run in pgAdmin Query Tool or psql.
-- =====================================================================

DROP SCHEMA IF EXISTS olist CASCADE;
CREATE SCHEMA olist;

-- ---------- Brazilian states lookup (27 states, 5 regions) ----------
CREATE TABLE olist.states (
    state_code  CHAR(2) PRIMARY KEY,
    state_name  TEXT NOT NULL,
    region      TEXT NOT NULL
);

INSERT INTO olist.states (state_code, state_name, region) VALUES
('AC','Acre','North'), ('AP','Amapa','North'), ('AM','Amazonas','North'),
('PA','Para','North'), ('RO','Rondonia','North'), ('RR','Roraima','North'),
('TO','Tocantins','North'),
('AL','Alagoas','Northeast'), ('BA','Bahia','Northeast'), ('CE','Ceara','Northeast'),
('MA','Maranhao','Northeast'), ('PB','Paraiba','Northeast'), ('PE','Pernambuco','Northeast'),
('PI','Piaui','Northeast'), ('RN','Rio Grande do Norte','Northeast'), ('SE','Sergipe','Northeast'),
('DF','Distrito Federal','Central-West'), ('GO','Goias','Central-West'),
('MT','Mato Grosso','Central-West'), ('MS','Mato Grosso do Sul','Central-West'),
('ES','Espirito Santo','Southeast'), ('MG','Minas Gerais','Southeast'),
('RJ','Rio de Janeiro','Southeast'), ('SP','Sao Paulo','Southeast'),
('PR','Parana','South'), ('RS','Rio Grande do Sul','South'), ('SC','Santa Catarina','South');

-- ---------- Customers ----------
-- customer_id = one id per ORDER; customer_unique_id = the real person.
CREATE TABLE olist.customers AS
SELECT
    TRIM(customer_id)                           AS customer_id,
    TRIM(customer_unique_id)                    AS customer_unique_id,
    LPAD(TRIM(customer_zip_code_prefix), 5, '0') AS customer_zip_code_prefix,
    INITCAP(TRIM(customer_city))                AS customer_city,
    UPPER(TRIM(customer_state))                 AS customer_state
FROM raw.customers;

ALTER TABLE olist.customers ADD PRIMARY KEY (customer_id);

-- ---------- Orders ----------
-- NULLIF(x, '') turns empty text into NULL before casting.
CREATE TABLE olist.orders AS
SELECT
    TRIM(order_id)                                          AS order_id,
    TRIM(customer_id)                                       AS customer_id,
    LOWER(TRIM(order_status))                               AS order_status,
    NULLIF(TRIM(order_purchase_timestamp), '')::timestamp      AS order_purchase_timestamp,
    NULLIF(TRIM(order_approved_at), '')::timestamp             AS order_approved_at,
    NULLIF(TRIM(order_delivered_carrier_date), '')::timestamp  AS order_delivered_carrier_date,
    NULLIF(TRIM(order_delivered_customer_date), '')::timestamp AS order_delivered_customer_date,
    NULLIF(TRIM(order_estimated_delivery_date), '')::timestamp AS order_estimated_delivery_date
FROM raw.orders;

ALTER TABLE olist.orders ADD PRIMARY KEY (order_id);

-- ---------- Order items (one row per item in an order) ----------
CREATE TABLE olist.order_items AS
SELECT
    TRIM(order_id)                                 AS order_id,
    NULLIF(TRIM(order_item_id), '')::int           AS order_item_id,
    TRIM(product_id)                               AS product_id,
    TRIM(seller_id)                                AS seller_id,
    NULLIF(TRIM(shipping_limit_date), '')::timestamp AS shipping_limit_date,
    NULLIF(TRIM(price), '')::numeric(12,2)         AS price,
    NULLIF(TRIM(freight_value), '')::numeric(12,2) AS freight_value
FROM raw.order_items;

ALTER TABLE olist.order_items ADD PRIMARY KEY (order_id, order_item_id);

-- ---------- Payments (an order can be paid in several parts) ----------
CREATE TABLE olist.order_payments AS
SELECT
    TRIM(order_id)                                  AS order_id,
    NULLIF(TRIM(payment_sequential), '')::int       AS payment_sequential,
    LOWER(TRIM(payment_type))                       AS payment_type,
    NULLIF(TRIM(payment_installments), '')::int     AS payment_installments,
    NULLIF(TRIM(payment_value), '')::numeric(12,2)  AS payment_value
FROM raw.order_payments;

-- ---------- Reviews ----------
-- Some orders have more than one review. Keep only the LATEST answered
-- review per order, so every order has at most one score.
CREATE TABLE olist.order_reviews AS
WITH typed AS (
    SELECT
        TRIM(review_id)                                     AS review_id,
        TRIM(order_id)                                      AS order_id,
        NULLIF(TRIM(review_score), '')::int                 AS review_score,
        NULLIF(TRIM(review_comment_message), '')            AS review_comment_message,
        NULLIF(TRIM(review_creation_date), '')::timestamp   AS review_creation_date,
        NULLIF(TRIM(review_answer_timestamp), '')::timestamp AS review_answer_timestamp
    FROM raw.order_reviews
),
ranked AS (
    SELECT t.*,
           ROW_NUMBER() OVER (PARTITION BY order_id
                              ORDER BY review_answer_timestamp DESC NULLS LAST,
                                       review_id) AS rn
    FROM typed t
)
SELECT review_id, order_id, review_score, review_comment_message,
       review_creation_date, review_answer_timestamp
FROM ranked
WHERE rn = 1;

ALTER TABLE olist.order_reviews ADD PRIMARY KEY (order_id);

-- ---------- Products (with English category names) ----------
-- Some products have no category, and a few categories have no English
-- translation. Fall back to the Portuguese name, then 'unknown'.
CREATE TABLE olist.products AS
SELECT
    TRIM(p.product_id) AS product_id,
    COALESCE(NULLIF(TRIM(t.product_category_name_english), ''),
             NULLIF(TRIM(p.product_category_name), ''),
             'unknown')                                  AS category,
    NULLIF(TRIM(p.product_weight_g), '')::numeric        AS product_weight_g,
    NULLIF(TRIM(p.product_photos_qty), '')::int          AS product_photos_qty
FROM raw.products p
LEFT JOIN raw.category_translation t
       ON TRIM(t.product_category_name) = TRIM(p.product_category_name);

ALTER TABLE olist.products ADD PRIMARY KEY (product_id);

-- ---------- Sellers ----------
CREATE TABLE olist.sellers AS
SELECT
    TRIM(seller_id)                             AS seller_id,
    LPAD(TRIM(seller_zip_code_prefix), 5, '0')  AS seller_zip_code_prefix,
    INITCAP(TRIM(seller_city))                  AS seller_city,
    UPPER(TRIM(seller_state))                   AS seller_state
FROM raw.sellers;

ALTER TABLE olist.sellers ADD PRIMARY KEY (seller_id);

-- ---------- Indexes for faster joins ----------
CREATE INDEX idx_orders_customer   ON olist.orders (customer_id);
CREATE INDEX idx_items_product     ON olist.order_items (product_id);
CREATE INDEX idx_items_seller      ON olist.order_items (seller_id);
CREATE INDEX idx_payments_order    ON olist.order_payments (order_id);
CREATE INDEX idx_customers_unique  ON olist.customers (customer_unique_id);

-- ---------- Refresh table statistics ----------
-- Without this, the first queries on brand-new tables can be very slow.
ANALYZE olist.states;
ANALYZE olist.customers;
ANALYZE olist.orders;
ANALYZE olist.order_items;
ANALYZE olist.order_payments;
ANALYZE olist.order_reviews;
ANALYZE olist.products;
ANALYZE olist.sellers;
