-- =====================================================================
-- Step 2: LOAD the 8 CSV files into the raw tables
--
-- Run this file in "SQL Shell (psql)", NOT in the pgAdmin Query Tool:
--   \i 'C:/Users/SUMIT/Desktop/olist/sql/02_load_data.sql'
-- \copy reads the files from YOUR computer, so there are no
-- "permission denied" errors from the PostgreSQL service.
--
-- The CSVs must be in C:/Users/SUMIT/Desktop/olist/data/ . If you keep them somewhere else,
-- use Find & Replace on "C:/Users/SUMIT/Desktop/olist/data/" in this file.
-- Use forward slashes (/) in Windows paths.
-- Do NOT open and save the CSVs in Excel first: Excel changes date formats.
-- (olist_geolocation_dataset.csv is not needed for this project.)
-- =====================================================================

\copy raw.customers            FROM 'C:/Users/SUMIT/Desktop/olist/data/olist_customers_dataset.csv'            WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy raw.orders               FROM 'C:/Users/SUMIT/Desktop/olist/data/olist_orders_dataset.csv'               WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy raw.order_items          FROM 'C:/Users/SUMIT/Desktop/olist/data/olist_order_items_dataset.csv'          WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy raw.order_payments       FROM 'C:/Users/SUMIT/Desktop/olist/data/olist_order_payments_dataset.csv'       WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy raw.order_reviews        FROM 'C:/Users/SUMIT/Desktop/olist/data/olist_order_reviews_dataset.csv'        WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy raw.products             FROM 'C:/Users/SUMIT/Desktop/olist/data/olist_products_dataset.csv'             WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy raw.sellers              FROM 'C:/Users/SUMIT/Desktop/olist/data/olist_sellers_dataset.csv'              WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy raw.category_translation FROM 'C:/Users/SUMIT/Desktop/olist/data/product_category_name_translation.csv'  WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

-- Quick check: row counts straight after loading
SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM raw.customers
UNION ALL SELECT 'orders',               COUNT(*) FROM raw.orders
UNION ALL SELECT 'order_items',          COUNT(*) FROM raw.order_items
UNION ALL SELECT 'order_payments',       COUNT(*) FROM raw.order_payments
UNION ALL SELECT 'order_reviews',        COUNT(*) FROM raw.order_reviews
UNION ALL SELECT 'products',             COUNT(*) FROM raw.products
UNION ALL SELECT 'sellers',              COUNT(*) FROM raw.sellers
UNION ALL SELECT 'category_translation', COUNT(*) FROM raw.category_translation;
