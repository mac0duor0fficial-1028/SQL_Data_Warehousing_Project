/*
===============================================================================
DDL Script: Create Gold Views
===============================================================================
Script Purpose:
    This script creates views for the Gold layer in the data warehouse. 
    The Gold layer represents the final dimension and fact tables (Star Schema)

    Each view performs transformations and combines data from the Silver layer 
    to produce a clean, enriched, and business-ready dataset.

Usage:
    - These views can be queried directly for analytics and reporting.
===============================================================================
*/

-- =============================================================================
-- Create Dimension: gold.dim_customers
-- =============================================================================

DROP VIEW IF EXISTS gold.dim_customers;

CREATE OR REPLACE VIEW gold.dim_customers AS
SELECT 
	ROW_NUMBER() OVER(ORDER BY cci.cust_id) as customer_key, -- Generated surrogate key
	cci.cust_id as customer_id,
	cci.cust_key as customer_number,
	cci.cst_firstname as first_name,
	cci.cst_lastname as last_name,
	ela.cntry as country,	
	cci.cust_marital_status as marital_status,
	(CASE WHEN cci.cust_gndr != 'Unknown' THEN cci.cust_gndr -- CRM is the master for gender info
		  ELSE COALESCE(cpa.gen , 'n/a')
	END) gender,
	cpa.bdate as birth_date,
	cci.cust_create_date as create_date
FROM silver.crm_cust_info cci
LEFT JOIN silver.erp_cust_az12 cpa
	ON cci.cust_key = cpa.cid
LEFT JOIN silver.erp_loc_a101 ela
	ON cci.cust_key = ela.cid
;

-- =============================================================================
-- Create Dimension: gold.dim_products
-- =============================================================================

DROP VIEW IF EXISTS gold.dim_products;

CREATE OR REPLACE VIEW gold.dim_products AS
SELECT 
	ROW_NUMBER() OVER(ORDER BY cpi.prd_key, cpi.prd_start_dt) product_key,
	cpi.prd_id as product_id, 
	cpi.prd_key as product_number , 
	cpi.prd_nm as product_name,
	cpi.cat_id as category_id,
	epcgv.cat as category,
	epcgv.subcat as subcategory,
	epcgv.maintenance,
	cpi.prd_cost as cost, 
	cpi.prd_line as product_line, 
	cpi.prd_start_dt as start_date
FROM silver.crm_prd_info cpi
LEFT JOIN silver.erp_px_cat_g1v2 epcgv 
	ON cpi.cat_id = epcgv.id 
WHERE cpi.prd_end_dt IS NULL
;

-- =============================================================================
-- Create Fact Table: gold.fact_sales
-- =============================================================================

DROP VIEW IF EXISTS gold.fact_sales;

CREATE OR REPLACE VIEW gold.fact_sales AS
SELECT 
	csd.sls_ord_num as order_number, 
	dp.product_key ,
	dc.customer_key, 
	csd.sls_order_dt as order_date, 
	csd.sls_ship_dt as shipping_date, 
	csd.sls_due_dt as due_date, 
	csd.sls_sales as sales_amount, 
	csd.sls_quantity as quantity, 
	csd.sls_price as price
FROM silver.crm_sales_details csd
LEFT JOIN gold.dim_products dp 
	ON csd.sls_prd_key = dp.product_number
LEFT JOIN gold.dim_customers dc 
	ON csd.sls_cust_id = dc.customer_id 
;

