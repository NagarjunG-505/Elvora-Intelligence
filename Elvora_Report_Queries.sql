-- ================================================================
--  ELVORA INTELLIGENCE SYSTEMS PVT. LTD.
--  PostgreSQL Queries — Every Table in the Consulting Report
--  Table/column names match your actual PostgreSQL tables:
--    sales, products, stores, customers, exchange_rates
-- ================================================================


-- ================================================================
-- PAGE 4 — SECTION 3.1
-- Annual Revenue, Cost, Profit & Margin
-- ================================================================
SELECT
    EXTRACT(YEAR FROM s.order_date)                                         AS year,
    SUM(p.unit_price_usd * s.quantity)                                      AS revenue_usd,
    SUM(p.unit_cost_usd  * s.quantity)                                      AS cost_usd,
    SUM((p.unit_price_usd - p.unit_cost_usd) * s.quantity)                  AS profit_usd,
    COUNT(DISTINCT s.order_number)                                          AS orders,
    ROUND(
        SUM((p.unit_price_usd - p.unit_cost_usd) * s.quantity)
        / SUM(p.unit_price_usd * s.quantity) * 100
    , 2)                                                                    AS margin_pct
FROM sales s
JOIN products p ON s.productkey = p.productkey
GROUP BY EXTRACT(YEAR FROM s.order_date)
ORDER BY year;


-- ================================================================
-- PAGE 4 — SECTION 3.2
-- Year-over-Year Revenue Growth
-- ================================================================
WITH yearly AS (
    SELECT
        EXTRACT(YEAR FROM s.order_date)              AS year,
        SUM(p.unit_price_usd * s.quantity)           AS revenue_usd,
        COUNT(DISTINCT s.order_number)               AS orders
    FROM sales s
    JOIN products p ON s.productkey = p.productkey
    GROUP BY 1
)
SELECT
    year,
    revenue_usd,
    orders,
    LAG(revenue_usd) OVER (ORDER BY year)            AS prev_year_revenue,
    orders - LAG(orders) OVER (ORDER BY year)        AS orders_change,
    ROUND(
        (revenue_usd - LAG(revenue_usd) OVER (ORDER BY year))
        / LAG(revenue_usd) OVER (ORDER BY year) * 100
    , 1)                                             AS yoy_growth_pct
FROM yearly
ORDER BY year;


-- ================================================================
-- PAGE 4 — SECTION 3.3
-- Monthly Seasonality — Revenue by Month
-- ================================================================
SELECT
    EXTRACT(YEAR  FROM s.order_date)                 AS year,
    EXTRACT(MONTH FROM s.order_date)                 AS month,
    TO_CHAR(s.order_date, 'Mon')                     AS month_name,
    SUM(p.unit_price_usd * s.quantity)               AS revenue_usd,
    COUNT(DISTINCT s.order_number)                   AS orders
FROM sales s
JOIN products p ON s.productkey = p.productkey
WHERE EXTRACT(YEAR FROM s.order_date) BETWEEN 2016 AND 2020
GROUP BY 1, 2, 3
ORDER BY 1, 2;


-- ================================================================
-- PAGE 5 — SECTION 4.1
-- Customer Base Overview
-- ================================================================
SELECT
    COUNT(DISTINCT c.customerkey)                    AS registered_customers,
    COUNT(DISTINCT s.customerkey)                    AS transacting_customers,
    COUNT(DISTINCT c.customerkey)
        - COUNT(DISTINCT s.customerkey)              AS never_purchased,
    ROUND(
        COUNT(DISTINCT s.customerkey) * 100.0
        / COUNT(DISTINCT c.customerkey)
    , 1)                                             AS conversion_rate_pct
FROM customers c
LEFT JOIN sales s ON c.customerkey = s.customerkey;


-- ================================================================
-- PAGE 5 — SECTION 4.1
-- Repeat vs One-Time Customers
-- ================================================================
WITH customer_orders AS (
    SELECT
        customerkey,
        COUNT(DISTINCT order_number)                 AS total_orders
    FROM sales
    GROUP BY customerkey
)
SELECT
    SUM(CASE WHEN total_orders > 1 THEN 1 ELSE 0 END)   AS repeat_customers,
    SUM(CASE WHEN total_orders = 1 THEN 1 ELSE 0 END)   AS one_time_customers,
    COUNT(*)                                             AS total_customers,
    ROUND(
        SUM(CASE WHEN total_orders > 1 THEN 1 ELSE 0 END) * 100.0
        / COUNT(*)
    , 1)                                                 AS repeat_rate_pct
FROM customer_orders;


-- ================================================================
-- PAGE 5 — SECTION 4.1
-- Dormant Customers (no purchase in 2020 or 2021)
-- ================================================================
WITH active_recent AS (
    SELECT DISTINCT customerkey
    FROM sales
    WHERE EXTRACT(YEAR FROM order_date) IN (2020, 2021)
),
transacting AS (
    SELECT DISTINCT customerkey
    FROM sales
)
SELECT
    COUNT(*)                                                 AS dormant_customers,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM transacting), 1) AS dormant_pct
FROM transacting t
WHERE t.customerkey NOT IN (SELECT customerkey FROM active_recent);


-- ================================================================
-- PAGE 5 — SECTION 4.2
-- RFM Analysis — Recency, Frequency, Monetary per Customer
-- ================================================================
SELECT
    s.customerkey,
    c.name,
    c.country,
    c.continent,
    MAX(s.order_date)                                        AS last_order_date,
    CURRENT_DATE - MAX(s.order_date)                        AS recency_days,
    COUNT(DISTINCT s.order_number)                          AS frequency,
    ROUND(SUM(p.unit_price_usd * s.quantity), 2)            AS monetary_usd,
    ROUND(SUM(p.unit_price_usd * s.quantity)
        / COUNT(DISTINCT s.order_number), 2)                AS avg_order_value
FROM sales s
JOIN products  p ON s.productkey  = p.productkey
JOIN customers c ON s.customerkey = c.customerkey
GROUP BY 1, 2, 3, 4
ORDER BY monetary_usd DESC;


-- ================================================================
-- PAGE 5 — SECTION 4.3
-- Customer Value Segmentation (High / Mid / Low)
-- ================================================================
WITH customer_revenue AS (
    SELECT
        s.customerkey,
        SUM(p.unit_price_usd * s.quantity)               AS total_revenue,
        COUNT(DISTINCT s.order_number)                   AS total_orders
    FROM sales s
    JOIN products p ON s.productkey = p.productkey
    GROUP BY s.customerkey
),
percentiles AS (
    SELECT
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY total_revenue) AS p25,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY total_revenue) AS p75
    FROM customer_revenue
)
SELECT
    CASE
        WHEN cr.total_revenue >= p.p75  THEN 'High Value'
        WHEN cr.total_revenue >= p.p25  THEN 'Mid Value'
        ELSE                                 'Low Value'
    END                                                  AS segment,
    COUNT(*)                                             AS customers,
    ROUND(AVG(cr.total_revenue), 2)                      AS avg_revenue_usd,
    ROUND(AVG(cr.total_orders),  1)                      AS avg_orders
FROM customer_revenue cr
CROSS JOIN percentiles p
GROUP BY 1
ORDER BY avg_revenue_usd DESC;


-- ================================================================
-- PAGE 6 — SECTION 4.4
-- Gender Split
-- ================================================================
SELECT
    c.gender,
    COUNT(DISTINCT s.customerkey)                        AS customers,
    COUNT(DISTINCT s.order_number)                       AS orders,
    ROUND(SUM(p.unit_price_usd * s.quantity), 2)         AS revenue_usd,
    ROUND(SUM(p.unit_price_usd * s.quantity) * 100.0
        / SUM(SUM(p.unit_price_usd * s.quantity)) OVER()
    , 2)                                                 AS revenue_share_pct
FROM sales s
JOIN customers c ON s.customerkey = c.customerkey
JOIN products  p ON s.productkey  = p.productkey
GROUP BY 1
ORDER BY revenue_usd DESC;


-- ================================================================
-- PAGE 6 — SECTION 4.4
-- Revenue by Age Group
-- ================================================================
SELECT
    CASE
        WHEN DATE_PART('year', AGE(s.order_date, c.birthday)) < 25  THEN '<25'
        WHEN DATE_PART('year', AGE(s.order_date, c.birthday)) < 35  THEN '25-34'
        WHEN DATE_PART('year', AGE(s.order_date, c.birthday)) < 45  THEN '35-44'
        WHEN DATE_PART('year', AGE(s.order_date, c.birthday)) < 55  THEN '45-54'
        WHEN DATE_PART('year', AGE(s.order_date, c.birthday)) < 65  THEN '55-64'
        ELSE '65+'
    END                                                  AS age_group,
    COUNT(DISTINCT s.customerkey)                        AS customers,
    COUNT(DISTINCT s.order_number)                       AS orders,
    ROUND(SUM(p.unit_price_usd * s.quantity), 2)         AS revenue_usd,
    ROUND(SUM(p.unit_price_usd * s.quantity) * 100.0
        / SUM(SUM(p.unit_price_usd * s.quantity)) OVER()
    , 2)                                                 AS revenue_share_pct
FROM sales s
JOIN customers c ON s.customerkey = c.customerkey
JOIN products  p ON s.productkey  = p.productkey
GROUP BY 1
ORDER BY MIN(DATE_PART('year', AGE(s.order_date, c.birthday)));


-- ================================================================
-- PAGE 7 — SECTION 5.1
-- Revenue, Profit & Margin by Category
-- ================================================================
SELECT
    p.category,
    SUM(p.unit_price_usd * s.quantity)                   AS revenue_usd,
    SUM(p.unit_cost_usd  * s.quantity)                   AS cost_usd,
    SUM((p.unit_price_usd - p.unit_cost_usd) * s.quantity) AS profit_usd,
    SUM(s.quantity)                                      AS units_sold,
    COUNT(DISTINCT s.order_number)                       AS transactions,
    ROUND(
        SUM((p.unit_price_usd - p.unit_cost_usd) * s.quantity)
        / SUM(p.unit_price_usd * s.quantity) * 100
    , 2)                                                 AS margin_pct,
    ROUND(
        SUM(p.unit_price_usd * s.quantity) * 100.0
        / SUM(SUM(p.unit_price_usd * s.quantity)) OVER()
    , 1)                                                 AS revenue_share_pct
FROM sales s
JOIN products p ON s.productkey = p.productkey
GROUP BY 1
ORDER BY revenue_usd DESC;


-- ================================================================
-- PAGE 7 — SECTION 5.2
-- Top 10 Products by Revenue
-- ================================================================
SELECT
    p.product_name,
    p.brand,
    p.category,
    SUM(s.quantity)                                                  AS units_sold,
    ROUND(SUM(p.unit_price_usd * s.quantity), 2)                     AS revenue_usd,
    ROUND(SUM((p.unit_price_usd - p.unit_cost_usd) * s.quantity), 2) AS profit_usd,
    ROUND(
        SUM((p.unit_price_usd - p.unit_cost_usd) * s.quantity)
        / SUM(p.unit_price_usd * s.quantity) * 100
    , 2)                                                             AS margin_pct
FROM sales s
JOIN products p ON s.productkey = p.productkey
GROUP BY 1, 2, 3
ORDER BY revenue_usd DESC
LIMIT 10;


-- ================================================================
-- PAGE 7 — SECTION 5.3
-- Revenue & Margin by Subcategory
-- ================================================================
SELECT
    p.category,
    p.subcategory,
    ROUND(SUM(p.unit_price_usd * s.quantity), 2)                     AS revenue_usd,
    SUM(s.quantity)                                                  AS units_sold,
    ROUND(
        SUM((p.unit_price_usd - p.unit_cost_usd) * s.quantity)
        / SUM(p.unit_price_usd * s.quantity) * 100
    , 2)                                                             AS margin_pct
FROM sales s
JOIN products p ON s.productkey = p.productkey
GROUP BY 1, 2
ORDER BY revenue_usd DESC
LIMIT 15;


-- ================================================================
-- PAGE 7 — SECTION 5.4
-- Brand Performance
-- ================================================================
SELECT
    p.brand,
    ROUND(SUM(p.unit_price_usd * s.quantity), 2)                     AS revenue_usd,
    ROUND(SUM((p.unit_price_usd - p.unit_cost_usd) * s.quantity), 2) AS profit_usd,
    ROUND(
        SUM((p.unit_price_usd - p.unit_cost_usd) * s.quantity)
        / SUM(p.unit_price_usd * s.quantity) * 100
    , 2)                                                             AS margin_pct,
    SUM(s.quantity)                                                  AS units_sold
FROM sales s
JOIN products p ON s.productkey = p.productkey
GROUP BY 1
ORDER BY revenue_usd DESC;


-- ================================================================
-- PAGE 8 — SECTION 6.1
-- Revenue by Country (Store Location)
-- ================================================================
SELECT
    st.country,
    COUNT(DISTINCT s.customerkey)                        AS unique_customers,
    COUNT(DISTINCT s.order_number)                       AS orders,
    ROUND(SUM(p.unit_price_usd * s.quantity), 2)         AS revenue_usd,
    ROUND(SUM((p.unit_price_usd - p.unit_cost_usd) * s.quantity), 2) AS profit_usd,
    ROUND(
        SUM((p.unit_price_usd - p.unit_cost_usd) * s.quantity)
        / SUM(p.unit_price_usd * s.quantity) * 100
    , 2)                                                 AS margin_pct,
    ROUND(
        SUM(p.unit_price_usd * s.quantity) * 100.0
        / SUM(SUM(p.unit_price_usd * s.quantity)) OVER()
    , 1)                                                 AS revenue_share_pct,
    ROUND(
        SUM(p.unit_price_usd * s.quantity)
        / COUNT(DISTINCT s.order_number)
    , 0)                                                 AS avg_order_value
FROM sales s
JOIN stores   st ON s.storekey   = st.storekey
JOIN products p  ON s.productkey = p.productkey
GROUP BY 1
ORDER BY revenue_usd DESC;


-- ================================================================
-- PAGE 8 — SECTION 6.2
-- Revenue by Continent
-- ================================================================
SELECT
    c.continent,
    COUNT(DISTINCT s.customerkey)                        AS unique_customers,
    COUNT(DISTINCT s.order_number)                       AS orders,
    ROUND(SUM(p.unit_price_usd * s.quantity), 2)         AS revenue_usd,
    ROUND(
        SUM(p.unit_price_usd * s.quantity) * 100.0
        / SUM(SUM(p.unit_price_usd * s.quantity)) OVER()
    , 1)                                                 AS revenue_share_pct,
    ROUND(
        SUM(p.unit_price_usd * s.quantity)
        / COUNT(DISTINCT s.order_number)
    , 0)                                                 AS avg_order_value
FROM sales s
JOIN customers c ON s.customerkey = c.customerkey
JOIN products  p ON s.productkey  = p.productkey
GROUP BY 1
ORDER BY revenue_usd DESC;


-- ================================================================
-- PAGE 8 — SECTION 6.3
-- Top US States by Revenue
-- ================================================================
SELECT
    st.state,
    COUNT(DISTINCT s.order_number)                       AS orders,
    ROUND(SUM(p.unit_price_usd * s.quantity), 2)         AS revenue_usd
FROM sales s
JOIN stores   st ON s.storekey   = st.storekey
JOIN products p  ON s.productkey = p.productkey
WHERE st.country = 'United States'
  AND s.storekey != 0
GROUP BY 1
ORDER BY revenue_usd DESC
LIMIT 10;


-- ================================================================
-- PAGE 8 — SECTION 6.4
-- Store Size vs Revenue Correlation
-- ================================================================
SELECT
    st.storekey,
    st.country,
    st.state,
    st.square_meters,
    COUNT(DISTINCT s.order_number)                       AS orders,
    ROUND(SUM(p.unit_price_usd * s.quantity), 2)         AS revenue_usd,
    ROUND(
        SUM(p.unit_price_usd * s.quantity)
        / st.square_meters
    , 2)                                                 AS revenue_per_sqm
FROM sales s
JOIN stores   st ON s.storekey   = st.storekey
JOIN products p  ON s.productkey = p.productkey
WHERE s.storekey != 0
  AND st.square_meters IS NOT NULL
GROUP BY 1, 2, 3, 4
ORDER BY revenue_usd DESC;


-- ================================================================
-- PAGE 8 — SECTION 6.5
-- Online vs In-Store Revenue by Year
-- ================================================================
SELECT
    EXTRACT(YEAR FROM s.order_date)                              AS year,
    CASE WHEN s.storekey = 0 THEN 'Online' ELSE 'In-Store' END  AS channel,
    COUNT(DISTINCT s.order_number)                               AS orders,
    ROUND(SUM(p.unit_price_usd * s.quantity), 2)                 AS revenue_usd,
    ROUND(
        SUM(p.unit_price_usd * s.quantity) * 100.0
        / SUM(SUM(p.unit_price_usd * s.quantity)) OVER (
            PARTITION BY EXTRACT(YEAR FROM s.order_date)
        )
    , 1)                                                         AS channel_share_pct
FROM sales s
JOIN products p ON s.productkey = p.productkey
GROUP BY 1, 2
ORDER BY 1, 2;


-- ================================================================
-- END OF REPORT QUERIES
-- ================================================================
