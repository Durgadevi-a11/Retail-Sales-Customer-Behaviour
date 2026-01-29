create database Customer_Sales_Behaviour
select * from dim_product
select * from dim_date
select * from dim_customer
select * from fact_sales
ALTER TABLE dim_customer
ADD CONSTRAINT pk_customer PRIMARY KEY (customer_id);
ALTER TABLE dim_product
ADD CONSTRAINT pk_product PRIMARY KEY (product_id);
ALTER TABLE dim_date
ADD CONSTRAINT pk_date PRIMARY KEY (date_id);
ALTER TABLE fact_sales
ADD CONSTRAINT fk_customer
FOREIGN KEY (customer_id) REFERENCES dim_customer(customer_id);

ALTER TABLE fact_sales
ADD CONSTRAINT fk_product
FOREIGN KEY (product_id) REFERENCES dim_product(product_id);

ALTER TABLE fact_sales
ADD CONSTRAINT fk_date
FOREIGN KEY (date_id) REFERENCES dim_date(date_id);

SHOW INDEX FROM dim_customer;
-- check nulls 
SELECT
  SUM(customer_id IS NULL) AS null_customers,
  SUM(product_id IS NULL) AS null_products,
  SUM(date_id IS NULL) AS null_dates,
  SUM(total_amount IS NULL) AS null_amount
FROM fact_sales;

DELETE FROM fact_sales
WHERE invoice_no IN (
  SELECT invoice_no
  FROM (
    SELECT invoice_no,
           ROW_NUMBER() OVER (PARTITION BY invoice_no ORDER BY invoice_no) r
    FROM fact_sales
  ) t
  WHERE r > 1
);
-- set total amount
UPDATE fact_sales
SET total_amount = quantity * unit_price
WHERE total_amount IS NULL;

-- check negative values
UPDATE fact_sales
SET total_amount = 0
WHERE total_amount < 0;

-- clean dimension table
DELETE FROM dim_customer
WHERE customer_id IN (
  SELECT customer_id FROM (
    SELECT customer_id,
           ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY customer_id) r
    FROM dim_customer
  ) t WHERE r > 1
);

-- Step 1: Test joins
SELECT
    f.invoice_no,
    f.customer_id,
    c.gender,
    c.age,
    c.city,
    p.product_name,
    p.category,
    d.invoice_date,
    f.total_amount
FROM fact_sales f
JOIN dim_customer c ON f.customer_id = c.customer_id
JOIN dim_product p ON f.product_id = p.product_id
JOIN dim_date d ON f.date_id = d.date_id
LIMIT 10;

-- Step 2: Customer-level aggregation
SELECT
    c.customer_id,
    c.gender,
    c.age,
    c.city,
    COUNT(DISTINCT f.invoice_no) AS frequency,       -- Number of purchases
    MAX(d.invoice_date) AS last_purchase_date,      -- Most recent purchase
    SUM(f.total_amount) AS total_spent              -- Total spent
FROM fact_sales f
JOIN dim_customer c ON f.customer_id = c.customer_id
JOIN dim_date d ON f.date_id = d.date_id
GROUP BY
    c.customer_id,
    c.gender,
    c.age,
    c.city;

-- Step 3: Create view
-- Drop the view first if it exists
DROP VIEW IF EXISTS customer_sales_behaviour;

-- Create the view
CREATE VIEW customer_sales_behaviour AS
SELECT
    c.customer_id,
    c.gender,
    c.age,
    c.city,
    COUNT(DISTINCT f.invoice_no) AS frequency,
    MAX(d.invoice_date) AS last_purchase_date,
    SUM(f.total_amount) AS total_spent
FROM fact_sales f
JOIN dim_customer c ON f.customer_id = c.customer_id
JOIN dim_date d ON f.date_id = d.date_id
GROUP BY
    c.customer_id,
    c.gender,
    c.age,
    c.city;


-- Check row count

SELECT COUNT(*) FROM customer_sales_behaviour;

-- Preview data
SELECT * FROM customer_sales_behaviour ;


CREATE INDEX idx_fact_customer ON fact_sales(customer_id);

SELECT * FROM customer_sales_behaviour;
