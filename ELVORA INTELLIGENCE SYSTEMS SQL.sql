--  ELVORA INTELLIGENCE SYSTEMS PVT. LTD.
--  PostgreSQL Queries                

 --Business Performance Analysis
 --Total revenue, profit, cost by years
select 
extract(year from sales.order_date) as year,
sum(productsp.unitpriceusd * sales.quantity) as revenue,
sum(productsp.unitcostusd * sales.quantity) as cost,
sum((productsp.unitpriceusd - productsp.unitcostusd) * sales.quantity) as profit,
count(distinct sales.order_number) as orders,
round(
    (sum((productsp.unitpriceusd - productsp.unitcostusd) * sales.quantity) 
     / sum(productsp.unitpriceusd * sales.quantity)) * 100, 2
) as margin_percent
from sales
join productsp 
on sales.productkey = productsp.productkey

group by 1
order by year;

--Year-over-Year Growth Analysis
WITH yearly AS (
    SELECT
        EXTRACT(YEAR FROM s.order_date)              AS year,
        SUM(p.unitpriceusd * s.quantity)           AS revenue_usd,
        COUNT(DISTINCT s.order_number)               AS orders
    FROM sales s
    JOIN productsP p ON s.productkey = p.productkey
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
    , 1)  AS yoy_growth_pct
FROM yearly
ORDER BY year;

--Customer Analysis
--Total Registered Customers
select count(customerkey) from customers

--Customer Base Overview
SELECT
    COUNT(DISTINCT c.customerkey) AS registered_customers,
    COUNT(DISTINCT s.customerkey) AS transacting_customers,
    COUNT(DISTINCT c.customerkey)
        - COUNT(DISTINCT s.customerkey)AS never_purchased,
    ROUND(
        COUNT(DISTINCT s.customerkey) * 100.0
        / COUNT(DISTINCT c.customerkey)
    , 1) AS conversion_rate_pct
FROM customers c
LEFT JOIN sales s ON c.customerkey = s.customerkey;

-- Repeat vs One-Time Customers
WITH customer_orders AS (
    SELECT
        customerkey,
        COUNT(DISTINCT order_number) AS total_orders
    FROM sales
    GROUP BY customerkey
)
SELECT
    SUM(CASE WHEN total_orders > 1 THEN 1 ELSE 0 END) AS repeat_customers,
    SUM(CASE WHEN total_orders = 1 THEN 1 ELSE 0 END) AS one_time_customers,
    COUNT(*) AS total_customers,
  (ROUND(
        SUM(CASE WHEN total_orders > 1 THEN 1 ELSE 0 END) * 100.0
        / COUNT(*)
    , 1) AS repeat_rate_pct
FROM customer_orders;


-- Gender Split

SELECT
    c.gender,
    COUNT(DISTINCT s.customerkey)                        AS customers,
    COUNT(DISTINCT s.order_number)                       AS orders,
    ROUND(SUM(p.unitpriceusd * s.quantity), 2)         AS revenue_usd,
    ROUND(SUM(p.unitpriceusd * s.quantity) * 100.0
        / SUM(SUM(p.unitpriceusd * s.quantity)) OVER()
    , 2)                                                 AS revenue_share_pct
FROM sales s
JOIN customers c ON s.customerkey = c.customerkey
JOIN productsp  p ON s.productkey  = p.productkey
GROUP BY 1
ORDER BY revenue_usd DESC;

-- Revenue by Age Group

SELECT
    CASE
        WHEN DATE_PART('year', AGE(s.order_date, c.birthday)) < 25  THEN '<25'
        WHEN DATE_PART('year', AGE(s.order_date, c.birthday)) < 35  THEN '25-34'
        WHEN DATE_PART('year', AGE(s.order_date, c.birthday)) < 45  THEN '35-44'
        WHEN DATE_PART('year', AGE(s.order_date, c.birthday)) < 55  THEN '45-54'
        WHEN DATE_PART('year', AGE(s.order_date, c.birthday)) < 65  THEN '55-64'
        ELSE '65+'
    END  AS age_group,
    COUNT(DISTINCT s.customerkey)  AS customers,
    COUNT(DISTINCT s.order_number)  AS orders,
    ROUND(SUM(p.unitpriceusd * s.quantity), 2) AS revenue_usd,
    ROUND(SUM(p.unitpriceusd * s.quantity) * 100.0
        / SUM(SUM(p.unitpriceusd * s.quantity)) OVER()
    , 2) AS revenue_share_pct
FROM sales s
JOIN customers c ON s.customerkey = c.customerkey
JOIN productsp  p ON s.productkey  = p.productkey
GROUP BY 1
ORDER BY MIN(DATE_PART('year', AGE(s.order_date, c.birthday)));

--Product & Pricing Analysis
-- Revenue, Profit & Margin by Category

SELECT
    p.category,
    SUM(p.unitpriceusd * s.quantity) AS revenue_usd,
    SUM(p.unitcostusd  * s.quantity)  AS cost_usd,
    SUM((p.unitpriceusd - p.unitcostusd) * s.quantity) AS profit_usd,
    SUM(s.quantity)  AS units_sold,
    COUNT(DISTINCT s.order_number)AS transactions,
    ROUND(
        SUM((p.unitpriceusd - p.unitcostusd) * s.quantity)
        / SUM(p.unitpriceusd * s.quantity) * 100
    , 2)||'%' AS margin_pct,
    ROUND(
        SUM(p.unitpriceusd * s.quantity) * 100.0
        / SUM(SUM(p.unitpriceusd * s.quantity)) OVER()
    , 1)||'%'   AS revenue_share_pct
FROM sales s
JOIN productsp p ON s.productkey = p.productkey
GROUP BY 1
ORDER BY revenue_usd DESC;

-- Top 10 Products by Revenue
SELECT 
    p.productname,
    p.brand,
    p.category,
    SUM(s.quantity) AS units_sold,
    ROUND(SUM(p.unitpriceusd * s.quantity), 2) AS revenue_usd,
    ROUND(SUM((p.unitpriceusd - p.unitcostusd) * s.quantity), 2) AS profit_usd,
  
    ROUND(
        SUM((p.unitpriceusd - p.unitcostusd) * s.quantity) 
        / SUM(p.unitpriceusd * s.quantity) * 100
    , 2) || '%' AS margin_pct
FROM sales s
JOIN productsp p ON s.productkey = p.productkey
GROUP BY 1, 2, 3
ORDER BY revenue_usd DESC
LIMIT 10;

-- Revenue & Margin by Subcategory
SELECT
    p.category,
    p.subcategory,
    ROUND(SUM(p.unitpriceusd * s.quantity), 2) AS revenue_usd,
    SUM(s.quantity) AS units_sold,
    -- Fixed the parentheses here:
    CONCAT(
        ROUND(
            SUM((p.unitpriceusd - p.unitcostusd) * s.quantity) 
            / SUM(p.unitpriceusd * s.quantity) * 100
        , 2), 
        '%'
    ) AS margin_pct
FROM sales s
JOIN productsp p ON s.productkey = p.productkey
GROUP BY 1, 2
ORDER BY revenue_usd DESC
LIMIT 15;


-- Brand Performance

SELECT
    p.brand,
    ROUND(SUM(p.unitpriceusd * s.quantity), 2)  AS revenue_usd,
    ROUND(SUM((p.unitpriceusd - p.unitcostusd) * s.quantity), 2) AS profit_usd,
    ROUND(
        SUM((p.unitpriceusd - p.unitcostusd) * s.quantity)
        / SUM(p.unitpriceusd * s.quantity) * 100
    , 2)   AS margin_pct,
    SUM(s.quantity)  AS units_sold
FROM sales s
JOIN productsp p ON s.productkey = p.productkey
GROUP BY 1
ORDER BY revenue_usd DESC;

-- Revenue by Country (Store Location)

SELECT
    st.country,
    COUNT(DISTINCT s.customerkey)                        AS unique_customers,
    COUNT(DISTINCT s.order_number)                       AS orders,
    ROUND(SUM(p.unitpriceusd	 * s.quantity), 2)         AS revenue_usd,
    ROUND(SUM((p.unitpriceusd - p.unitcostusd) * s.quantity), 2) AS profit_usd,
    ROUND(
        SUM((p.unitpriceusd - p.unitcostusd) * s.quantity)
        / SUM(p.unitpriceusd * s.quantity) * 100
    , 2)  AS margin_pct,
    ROUND(
        SUM(p.unitpriceusd * s.quantity) * 100.0
        / SUM(SUM(p.unitpriceusd * s.quantity)) OVER()
    , 1)|| '%' AS revenue_share_pct,
    ROUND(
        SUM(p.unitpriceusd * s.quantity)
        / COUNT(DISTINCT s.order_number)
    , 0)   AS avg_order_value
FROM sales s
JOIN stores   st ON s.storekey   = st.storekey
JOIN productsp p  ON s.productkey = p.productkey
GROUP BY 1
ORDER BY revenue_usd DESC;
 

-- Revenue by Continent

SELECT
    c.continent,
    COUNT(DISTINCT s.customerkey)  AS unique_customers,
    COUNT(DISTINCT s.order_number)   AS orders,
    ROUND(SUM(p.unitpriceusd * s.quantity), 2)AS revenue_usd,
    ROUND(
        SUM(p.unitpriceusd * s.quantity) * 100.0
        / SUM(SUM(p.unitpriceusd * s.quantity)) OVER()
    , 1) AS revenue_share_pct,
    ROUND(
        SUM(p.unitpriceusd * s.quantity)
        / COUNT(DISTINCT s.order_number)
    , 0)  AS avg_order_value
FROM sales s
JOIN customers c ON s.customerkey = c.customerkey
JOIN productsp  p ON s.productkey  = p.productkey
GROUP BY 1
ORDER BY revenue_usd DESC;
 

-- Top US States by Revenue

SELECT
    st.state,
    COUNT(DISTINCT s.order_number)                       AS orders,
    ROUND(SUM(p.unitpriceusd * s.quantity), 2)         AS revenue_usd
FROM sales s
JOIN stores   st ON s.storekey   = st.storekey
JOIN productsp p  ON s.productkey = p.productkey
WHERE st.country = 'United States'
  AND s.storekey != 0
GROUP BY 1
ORDER BY revenue_usd DESC
LIMIT 10;
 

-- Store Size vs Revenue Correlation

SELECT
    st.storekey,
    st.country,
    st.state,
    st.square_meters,
    COUNT(DISTINCT s.order_number)  AS orders,
    ROUND(SUM(p.unitpriceusd * s.quantity), 2)   AS revenue_usd,
    ROUND(
        SUM(p.unitpriceusd * s.quantity)
        / st.square_meters
    , 2)    AS revenue_per_sqm
FROM sales s
JOIN stores   st ON s.storekey   = st.storekey
JOIN productsp p  ON s.productkey = p.productkey
WHERE s.storekey != 0
  AND st.square_meters IS NOT NULL
GROUP BY 1, 2, 3, 4
ORDER BY revenue_usd DESC;
 

-- Online vs In-Store Revenue by Year
SELECT
    EXTRACT(YEAR FROM s.order_date)  AS year,
    CASE WHEN s.storekey = 0 THEN 'Online' ELSE 'In-Store' END  AS channel,
    COUNT(DISTINCT s.order_number) AS orders,
    ROUND(SUM(p.unitpriceusd * s.quantity), 2) AS revenue_usd,
   concat( ROUND(
        SUM(p.unitpriceusd * s.quantity) * 100.0
        / SUM(SUM(p.unitpriceusd * s.quantity)) OVER (
            PARTITION BY EXTRACT(YEAR FROM s.order_date)
        )
    , 1),'%') AS channel_share_pct
FROM sales s
JOIN productsp p ON s.productkey = p.productkey
GROUP BY 1, 2
ORDER BY 1, 2;