/*========================================================================
  Project : Olist E-Commerce Data Analysis
  File     : 03_analysis_queries.sql
  Purpose  : Business analysis queries grouped by theme. Each query answers
             a specific question and feeds the Power BI dashboard.
             Run this AFTER 01_schema_setup.sql and 02_data_cleaning.sql.
  Author   : <your name>
  Date     : 2026-06
  Note     : Revenue is measured from order_items.price and, unless stated
             otherwise, restricted to completed (delivered) orders so the
             figures reflect realised sales.
=========================================================================*/

USE Olist;
GO

/*========================================================================
  GROUP 1 - BUSINESS OVERVIEW
=========================================================================*/

/*------------------------------------------------------------------------
  1.1 Monthly revenue and order volume
      Shows the growth trend. Note the dataset is sparse in late 2016 and
      truncated in late 2018, so the first and last months are not
      representative of a full trading period.
------------------------------------------------------------------------*/
SELECT
    FORMAT(o.order_purchase_timestamp, 'yyyy-MM') AS order_month,
    COUNT(DISTINCT o.order_id)                    AS total_orders,
    SUM(oi.price)                                 AS revenue,
    SUM(oi.freight_value)                         AS freight
FROM olist_orders_dataset o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY FORMAT(o.order_purchase_timestamp, 'yyyy-MM')
ORDER BY order_month;

/*------------------------------------------------------------------------
  1.2 Headline KPIs (for dashboard summary cards)
------------------------------------------------------------------------*/
SELECT
    COUNT(DISTINCT o.order_id)                 AS total_orders,
    COUNT(DISTINCT o.customer_id)              AS total_customers,
    SUM(oi.price)                              AS total_revenue,
    SUM(oi.price) / COUNT(DISTINCT o.order_id) AS avg_order_value
FROM olist_orders_dataset o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered';


/*========================================================================
  GROUP 2 - PRODUCTS & CATEGORIES
=========================================================================*/

/*------------------------------------------------------------------------
  2.1 Top 10 categories by revenue
      Tip: bed_bath_table has the most orders but ranks lower on revenue,
      meaning a lower value per item than health_beauty or watches_gifts.
------------------------------------------------------------------------*/
SELECT TOP 10
    p.category_english,
    COUNT(DISTINCT oi.order_id) AS orders,
    SUM(oi.price)               AS revenue,
    AVG(oi.price)               AS avg_item_price
FROM order_items oi
JOIN products p             ON oi.product_id = p.product_id
JOIN olist_orders_dataset o ON oi.order_id   = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY p.category_english
ORDER BY revenue DESC;


/*========================================================================
  GROUP 3 - LOGISTICS & DELIVERY
=========================================================================*/

/*------------------------------------------------------------------------
  3.1 Late delivery vs review score  -- KEY INSIGHT
      Orders delivered late score about 2 points lower on average than
      orders delivered on time, showing delivery performance is a major
      driver of customer satisfaction.
------------------------------------------------------------------------*/
SELECT
    CASE WHEN o.delivery_vs_estimate < 0 THEN 'Late'
         ELSE 'On time / Early' END        AS delivery_status,
    COUNT(*)                               AS num_orders,
    AVG(CAST(r.review_score AS FLOAT))     AS avg_review_score
FROM olist_orders_dataset o
JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.delivery_vs_estimate IS NOT NULL
GROUP BY CASE WHEN o.delivery_vs_estimate < 0 THEN 'Late'
              ELSE 'On time / Early' END;

/*------------------------------------------------------------------------
  3.2 Delivery time distribution (buckets)
      Groups delivered orders by how long they took, so the dashboard can
      show what a "typical" delivery window looks like.
------------------------------------------------------------------------*/
SELECT
    CASE
        WHEN delivery_days <= 7  THEN '0-7 days'
        WHEN delivery_days <= 15 THEN '8-15 days'
        WHEN delivery_days <= 30 THEN '16-30 days'
        ELSE '30+ days'
    END                          AS delivery_bucket,
    COUNT(*)                     AS num_orders
FROM olist_orders_dataset
WHERE delivery_days IS NOT NULL
GROUP BY
    CASE
        WHEN delivery_days <= 7  THEN '0-7 days'
        WHEN delivery_days <= 15 THEN '8-15 days'
        WHEN delivery_days <= 30 THEN '16-30 days'
        ELSE '30+ days'
    END
ORDER BY MIN(delivery_days);


/*========================================================================
  GROUP 4 - CUSTOMERS
=========================================================================*/

/*------------------------------------------------------------------------
  4.1 One-time vs repeat customers
      ~97% of customers buy only once: retention is very low. This points
      to a clear opportunity to improve customer lifetime value.
      customer_unique_id is used because customer_id is unique per order.
------------------------------------------------------------------------*/
SELECT
    purchase_count,
    COUNT(*) AS num_customers
FROM (
    SELECT c.customer_unique_id,
           COUNT(DISTINCT o.order_id) AS purchase_count
    FROM customers c
    JOIN olist_orders_dataset o ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
) t
GROUP BY purchase_count
ORDER BY purchase_count;

/*------------------------------------------------------------------------
  4.2 Revenue by customer state (for the geographic map)
------------------------------------------------------------------------*/
SELECT
    c.customer_state,
    COUNT(DISTINCT o.order_id) AS orders,
    SUM(oi.price)              AS revenue
FROM olist_orders_dataset o
JOIN customers c   ON o.customer_id = c.customer_id
JOIN order_items oi ON o.order_id   = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY revenue DESC;


/*========================================================================
  GROUP 5 - SELLERS & PAYMENTS
=========================================================================*/

/*------------------------------------------------------------------------
  5.1 Top 10 sellers by revenue (ranked with a window function)
------------------------------------------------------------------------*/
WITH seller_revenue AS (
    SELECT
        oi.seller_id,
        COUNT(DISTINCT oi.order_id) AS orders,
        SUM(oi.price)               AS revenue
    FROM order_items oi
    JOIN olist_orders_dataset o ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY oi.seller_id
)
SELECT
    RANK() OVER (ORDER BY revenue DESC) AS revenue_rank,
    seller_id,
    orders,
    revenue
FROM seller_revenue
ORDER BY revenue_rank
OFFSET 0 ROWS FETCH NEXT 10 ROWS ONLY;

/*------------------------------------------------------------------------
  5.2 Payment method breakdown
------------------------------------------------------------------------*/
SELECT
    payment_type,
    COUNT(*)            AS num_payments,
    SUM(payment_value)  AS total_value,
    AVG(payment_value)  AS avg_value
FROM order_payments
GROUP BY payment_type
ORDER BY total_value DESC;

/*------------------------------------------------------------------------
  5.3 Installments distribution (credit card culture in Brazil)
      Shows how many orders are split into multiple instalments, a notable
      feature of the Brazilian market.
------------------------------------------------------------------------*/
SELECT
    payment_installments,
    COUNT(*)           AS num_payments,
    SUM(payment_value) AS total_value
FROM order_payments
WHERE payment_installments > 0
GROUP BY payment_installments
ORDER BY payment_installments;


/*========================================================================
  GROUP 6 - REVIEWS
=========================================================================*/

/*------------------------------------------------------------------------
  6.1 Review score distribution with running share
      Uses a window function to show each score's share and the cumulative
      share, highlighting how polarised reviews are (mostly 5s, then 1s).
------------------------------------------------------------------------*/
SELECT
    review_score,
    COUNT(*)                                              AS num_reviews,
    CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5,2))
                                                          AS pct_of_total
FROM order_reviews
WHERE review_score IS NOT NULL
GROUP BY review_score
ORDER BY review_score;
GO