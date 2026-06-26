/*
  Project : Olist E-Commerce Data Analysis
  File     : 02_data_cleaning.sql
  Purpose  : Profile the raw data, document known quality issues, and add
             derived columns used by the analysis queries and the Power BI
             dashboard.
  Author   : Tran Ngoc Nhi
  Date     : 2026-06
  */

USE Olist;
GO

/*PART A - DATA PROFILING (read-only)
  These queries only inspect the data. They make no changes and are kept
  here to document the quality checks that were performed.*/

/*A1. Duplicate review_id
      The raw Olist reviews table contains duplicate review_id values
      (~800 duplicates). This is a known issue in the source data and is
      left as-is. Use COUNT(DISTINCT review_id) when a unique count is
      required.*/
-- SELECT COUNT(*) AS total_rows,
--        COUNT(DISTINCT review_id) AS distinct_reviews
-- FROM   order_reviews;

/*A2. Order status distribution
      ~97% of orders are 'delivered'. Revenue analysis later filters on
      order_status = 'delivered' so figures reflect completed sales only.*/
-- SELECT order_status, COUNT(*) AS cnt
-- FROM   olist_orders_dataset
-- GROUP  BY order_status
-- ORDER  BY cnt DESC;

/*A3. Missing delivery dates
      ~2,965 orders have no customer delivery date. These are orders that
      were never completed (canceled, unavailable, still in transit, etc.),
      not data errors. They are excluded when measuring delivery time.*/
-- SELECT COUNT(*) AS total_orders,
--        SUM(CASE WHEN order_delivered_customer_date IS NULL THEN 1 ELSE 0 END)
--            AS missing_delivered_date
-- FROM   olist_orders_dataset;


/*PART B - DERIVED COLUMNS (modifies tables)*/

/* B1. English category label
      Adds category_english to products. Categories that have no entry in
      the translation table (NULL or missing) are labelled 'unknown'
      instead of being left blank, so every product is reportable.*/
ALTER TABLE products ADD category_english NVARCHAR(100);
GO

UPDATE p
SET    p.category_english = COALESCE(t.product_category_name_english, 'unknown')
FROM   products p
LEFT JOIN product_category_name_translation t
       ON p.product_category_name = t.product_category_name;
GO

/*B2. Delivery time columns
      delivery_days        = days from purchase to customer delivery.
      delivery_vs_estimate = days between actual delivery and the estimate;
                             positive = delivered early, negative = late.
      Only set for orders that have actually been delivered.*/
ALTER TABLE olist_orders_dataset ADD delivery_days INT;
ALTER TABLE olist_orders_dataset ADD delivery_vs_estimate INT;
GO

UPDATE olist_orders_dataset
SET    delivery_days        = DATEDIFF(DAY, order_purchase_timestamp,
                                            order_delivered_customer_date),
       delivery_vs_estimate = DATEDIFF(DAY, order_delivered_customer_date,
                                            order_estimated_delivery_date)
WHERE  order_delivered_customer_date IS NOT NULL;
GO

-- B3. Verification 
-- SELECT category_english, COUNT(*) AS cnt
-- FROM   products
-- GROUP  BY category_english
-- ORDER  BY cnt DESC;

-- SELECT MIN(delivery_days) AS min_days,
--        AVG(delivery_days) AS avg_days,
--        MAX(delivery_days) AS max_days,
--        SUM(CASE WHEN delivery_vs_estimate < 0 THEN 1 ELSE 0 END) AS late_deliveries
-- FROM   olist_orders_dataset
-- WHERE  delivery_days IS NOT NULL;
GO