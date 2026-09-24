/*
===============================================================================
Quality Checks
===============================================================================
Script Purpose:
    This script performs quality checks to validate the integrity, consistency, 
    and accuracy of the Gold Layer. These checks ensure:
    - Uniqueness of surrogate keys in dimension tables.
    - Referential integrity between fact and dimension tables.
    - Validation of relationships in the data model for analytical purposes.

Usage Notes:
    - Investigate and resolve any discrepancies found during the checks.
===============================================================================
*/

-- ====================================================================
-- Checking 'gold.dim_customers'
-- ====================================================================
-- Check for Uniqueness of Customer Key in gold.dim_customers

SELECT cust_id, COUNT(*) duplicate_count
FROM(
	SELECT 
		cci.cust_id,
		cci.cust_key,
		cci.cst_firstname ,
		cci.cst_lastname,
		cci.cust_marital_status,
		cci.cust_gndr,
		cci.cust_create_date,
		cpa.bdate,
		cpa.gen,
		ela.cntry 
	FROM silver.crm_cust_info cci
	LEFT JOIN silver.erp_cust_az12 cpa
		ON cci.cust_key = cpa.cid
	LEFT JOIN silver.erp_loc_a101 ela
		ON cci.cust_key = ela.cid
	) as t
GROUP BY cust_id
HAVING COUNT(*) > 1;.

-- ====================================================================
-- Checking 'gold.product_key'
-- ====================================================================
-- Check for Uniqueness of Product Key in gold.dim_products

SELECT prd_key, COUNT(*) duplicate_count
FROM (
	SELECT 
		cpi.prd_id, 
		cpi.cat_id,
		cpi.prd_key, 
		cpi.prd_nm, 
		cpi.prd_cost, 
		cpi.prd_line, 
		cpi.prd_start_dt,
		epcgv.cat,
		epcgv.subcat,
		epcgv.maintenance 
	FROM silver.crm_prd_info cpi
	LEFT JOIN silver.erp_px_cat_g1v2 epcgv 
		ON cpi.cat_id = epcgv.id 
	WHERE cpi.prd_end_dt IS NULL
)
GROUP BY prd_key 
HAVING COUNT(*) > 1;

-- ====================================================================
-- Checking 'gold.fact_sales'
-- ====================================================================
-- Check the data model connectivity between fact and dimensions

SELECT * 
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers dc 
	ON dc.customer_key = f.customer_key 
LEFT JOIN gold.dim_products dp 
	ON dp.product_key = f.product_key 
WHERE dp.product_key IS NULL;
