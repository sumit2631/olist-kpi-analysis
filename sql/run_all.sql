-- =====================================================================
-- Runs steps 1, 2, 3 and 5 in one go.
-- In "SQL Shell (psql)", connected to the olist_db database:
--   \i 'C:/Users/SUMIT/Desktop/olist/sql/run_all.sql'
-- Then open 04_data_quality_checks.sql and 06_analysis_queries.sql in
-- pgAdmin and run them one query at a time, so you can read each result.
-- =====================================================================

\set ON_ERROR_STOP on
\echo '--- Step 1: raw tables'
\i 'C:/Users/SUMIT/Desktop/olist/sql/01_create_raw_tables.sql'
\echo '--- Step 2: loading CSV files (takes under a minute)'
\i 'C:/Users/SUMIT/Desktop/olist/sql/02_load_data.sql'
\echo '--- Step 3: clean tables'
\i 'C:/Users/SUMIT/Desktop/olist/sql/03_clean_tables.sql'
\echo '--- Step 5: KPI views'
\i 'C:/Users/SUMIT/Desktop/olist/sql/05_kpi_views.sql'
\echo '--- Finished. Quick check (should show about 97,905 orders):'
SELECT COUNT(*) AS orders_in_dashboard FROM olist.v_fact_orders;
