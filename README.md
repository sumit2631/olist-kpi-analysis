# Olist E-commerce: Delivery & Customer KPI Analysis

**PostgreSQL · SQL · Power BI · DAX**

**Status:** in progress. The SQL pipeline and DAX measures are written; the Power BI dashboard and final findings are in progress.

An end-to-end analysis of about 99,000 real orders from Olist, a Brazilian e-commerce marketplace (2016–2018). The project builds a SQL pipeline in PostgreSQL (raw → clean → KPI views), runs data-quality checks, and feeds a Power BI dashboard for an operations manager.

## Business question

> Which factors drive late deliveries and poor customer reviews, and where should the operations team focus first?

## Dataset

[Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) (Kaggle, CC BY-NC-SA 4.0). It has 8 related tables: orders, order items, payments, reviews, customers, products, sellers and category translations. The CSV files are not stored in this repo; download them from Kaggle.

## Approach

1. **Raw layer:** load the CSVs into all-text tables, so the load never fails on a bad value.
2. **Clean layer:** fix data types, trim and standardise text, restore leading zeros in zip codes, translate product categories, keep one review per order, and add a Brazilian state/region lookup.
3. **Data-quality checks:** 9 validation and reconciliation checks.
4. **KPI views:** an order-level view, an item-level view, a monthly KPI view and a seller scorecard.
5. **Analysis:** 10 business questions in SQL.
6. **Dashboard (in progress):** Power BI with a date table and DAX measures.

## Data-quality checks

- Raw vs clean row counts (load reconciliation)
- Duplicate order and customer IDs
- Orders with more than one review
- Missing timestamps by order status
- Orders without items or payments, and items without orders
- Impossible dates (delivered before purchase)
- Payments vs item price + freight (reconciliation)
- Products without a category, and categories without an English name
- Orders outside the analysis window (Jan 2017 – Aug 2018)

## KPI dictionary

| KPI | Definition |
| --- | --- |
| Orders | Orders purchased Jan 2017 – Aug 2018, excluding canceled and unavailable |
| Revenue | Sum of item prices + freight (R$) |
| AOV | Revenue ÷ Orders |
| On-time % | Delivered orders that arrived on or before the estimated date ÷ delivered orders |
| Avg delivery days | Purchase to customer delivery, in days |
| Avg review | Mean review score (1–5) |
| Low review % | Reviews of 1–2 stars ÷ all reviews |
| Repeat customer % | Customers (`customer_unique_id`) with 2+ orders ÷ all customers |

## Business questions answered in SQL

1. Headline KPIs for the whole period
2. Monthly trend: revenue growth and on-time %
3. Do late deliveries hurt customer reviews?
4. Review score by how many days late
5. Which customer states get the slowest and least reliable delivery?
6. Median and 90th-percentile delivery time by region
7. Top 10 categories by revenue, with running (Pareto) share
8. Sellers with the worst on-time %
9. Repeat-customer rate and time to second order
10. Payment mix

SQL techniques used: CTEs, joins, `FILTER`, `CASE`, window functions (`ROW_NUMBER`, `RANK`, `LAG`, `LEAD`, running `SUM`), `PERCENTILE_CONT`.

## Dashboard

In progress. Planned pages:

- **Executive overview:** revenue, orders, AOV, on-time %, average review; monthly trend; top categories; orders by region.
- **Delivery & customer experience:** on-time % and delivery days; review score by lateness; on-time % by state; seller scorecard.

Screenshots and key findings will be added when the dashboard is complete.

## How to run

1. Download the dataset from Kaggle and put the 8 CSVs in a `data/` folder next to `sql/`.
2. The scripts use the folder `C:/Users/SUMIT/Desktop/olist/`. If yours is elsewhere, change that path in `02_load_data.sql`, `run_all.sql` and `07_export_for_powerbi.sql`.
3. In PostgreSQL, create a database `olist_db`. In SQL Shell (psql), connect to it and run `\i 'C:/Users/SUMIT/Desktop/olist/sql/run_all.sql'`.
4. Run `04_data_quality_checks.sql` and `06_analysis_queries.sql` query by query.
5. In Power BI Desktop: Get data → PostgreSQL → `localhost` / `olist_db` → import `olist.v_fact_orders`, `olist.v_fact_order_items` and `olist.v_seller_performance`. Add the date table and measures from `powerbi/DAX_measures.txt`.

## Repository structure

```
sql/
  01_create_raw_tables.sql    raw tables (all text)
  02_load_data.sql            \copy the CSVs (psql)
  03_clean_tables.sql         typed, cleaned tables + lookups
  04_data_quality_checks.sql  9 validation and reconciliation checks
  05_kpi_views.sql            views used by Power BI
  06_analysis_queries.sql     10 business questions
  07_export_for_powerbi.sql   optional CSV export
  run_all.sql                 runs steps 1, 2, 3 and 5
powerbi/
  DAX_measures.txt            date table + measures
```

## Next steps

- [ ] Run the full pipeline and record the data-quality results
- [ ] Build the two-page Power BI dashboard
- [ ] Add screenshots and key findings to this README
- [ ] Upload the `.pbix` file