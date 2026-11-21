-- =====================================================================
-- Step 7 (ONLY IF NEEDED): export the views to CSV for Power BI
-- Use this only if Power BI cannot connect to PostgreSQL directly.
-- Run in "SQL Shell (psql)":   \i 'C:/Users/SUMIT/Desktop/olist/sql/07_export_for_powerbi.sql'
-- Files are written to C:/Users/SUMIT/Desktop/olist/powerbi/ (create the folder first).
-- =====================================================================

\copy (SELECT * FROM olist.v_fact_orders)        TO 'C:/Users/SUMIT/Desktop/olist/powerbi/fact_orders.csv'        WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy (SELECT * FROM olist.v_fact_order_items)   TO 'C:/Users/SUMIT/Desktop/olist/powerbi/fact_order_items.csv'   WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy (SELECT * FROM olist.v_seller_performance) TO 'C:/Users/SUMIT/Desktop/olist/powerbi/seller_performance.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy (SELECT * FROM olist.v_monthly_kpis)       TO 'C:/Users/SUMIT/Desktop/olist/powerbi/monthly_kpis.csv'       WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
