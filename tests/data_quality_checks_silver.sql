/*
===============================================================================
Quality Checks
===============================================================================
Script Purpose:
    This script performs various quality checks for data consistency, accuracy, 
    and standardization across the 'silver' layer. It includes checks for:
    - Null or duplicate primary keys.
    - Unwanted spaces in string fields.
    - Data standardization and consistency.
    - Invalid date ranges and orders.
    - Data consistency between related fields.

Usage Notes:
    - Run these checks after data loading Silver Layer.
    - Investigate and resolve any discrepancies found during the checks.
===============================================================================
*/

--============================================
-- CUSTOMER INFORMATION
--============================================

SELECT *
FROM silver.crm_cust_info cci;

-----------------------
-- Data Quality Check
-----------------------

-- = Checking Duplicates & Nulls
SELECT cci.cust_id, COUNT(*)
FROM silver.crm_cust_info cci
GROUP BY cci.cust_id
HAVING COUNT(*) > 1 OR cci.cust_id IS NULL;

-- = Removing Duplicates
SELECT *
FROM
(
    SELECT *,
        ROW_NUMBER() OVER(PARTITION BY cci.cust_id ORDER BY cci.cust_create_date DESC) as flag_last
    FROM silver.crm_cust_info cci
)
WHERE flag_last = 1 AND cust_id IS NOT NULL;

-- = Checking for Unwanted Spaces
SELECT cci.cst_firstname
FROM silver.crm_cust_info cci
WHERE cst_firstname != TRIM(cci.cst_firstname);

-- = Removing Unwanted Spaces
SELECT
    cust_id, cust_key,
    TRIM(cst_firstname),
    TRIM(cst_lastname),
    TRIM(cust_marital_status),
    TRIM(cust_gndr),
    cust_create_date
FROM
(
    SELECT *,
        ROW_NUMBER() OVER(PARTITION BY cci.cust_id ORDER BY cci.cust_create_date DESC) as flag_last
    FROM silver.crm_cust_info cci
)
WHERE flag_last = 1;

-- = Checking Data Consistency
SELECT DISTINCT cci.cust_gndr
FROM silver.crm_cust_info cci;

SELECT DISTINCT cci.cust_marital_status
FROM silver.crm_cust_info cci;

-- = Data Standardization & Consistency
SELECT
    cust_id, cust_key,
    TRIM(cst_firstname),
    TRIM(cst_lastname),
    (CASE WHEN UPPER(TRIM(cust_marital_status)) = 'S' THEN 'Single'
          WHEN UPPER(TRIM(cust_marital_status)) = 'M' THEN 'Married'
          ELSE 'Unknown'
    END) as cust_marital_status,
    (CASE WHEN UPPER(TRIM(cust_gndr)) = 'F' THEN 'Female'
          WHEN UPPER(TRIM(cust_gndr)) = 'M' THEN 'Male'
          ELSE 'Unknown'
    END) as cust_gndr,
    cust_create_date
FROM
(
    SELECT *,
        ROW_NUMBER() OVER(PARTITION BY cci.cust_id ORDER BY cci.cust_create_date DESC) as flag_last
    FROM silver.crm_cust_info cci
)
WHERE flag_last = 1 IS NOT NULL;

--============================================
-- CURRENT & HISTORIC PRODUCT INFORMATION
--============================================

SELECT *
FROM silver.crm_prd_info cpi;

-----------------------
-- Data Quality Check
-----------------------

-- = Checking Duplicates & Nulls
SELECT cpi.prd_id, COUNT(*)
FROM silver.crm_prd_info cpi
GROUP BY cpi.prd_id
HAVING COUNT(*) > 1 OR cpi.prd_id IS NULL;

-- = Deriving New column (cat_id and prd_key)
SELECT
    cpi.prd_id,
    cpi.prd_key,
    REPLACE(SUBSTRING(cpi.prd_key, 1, 5), '-', '_') as cat_id,
    SUBSTRING(cpi.prd_key, 7, LENGTH(cpi.prd_key)) as prd_key,
    cpi.prd_nm,
    cpi.prd_cost,
    cpi.prd_line,
    cpi.prd_start_dt,
    cpi.prd_end_dt
FROM silver.crm_prd_info cpi;

-- = Checking for Unwanted Spaces
SELECT prd_nm
FROM silver.crm_prd_info cpi
WHERE prd_nm != TRIM(prd_nm);

-- = Checking for Null and Negative Numbers in prd_cost
SELECT prd_cost
FROM silver.crm_prd_info cpi
WHERE prd_cost < 0 OR prd_cost IS NULL;

-- = Fixing Null in prd_cost
SELECT
    cpi.prd_id,
    cpi.prd_key,
    REPLACE(SUBSTRING(cpi.prd_key, 1, 5), '-', '_') as cat_id,
    SUBSTRING(cpi.prd_key, 7, LENGTH(cpi.prd_key)) as prd_key,
    cpi.prd_nm,
    COALESCE(cpi.prd_cost, 0) as prd_cost,
    cpi.prd_line,
    cpi.prd_start_dt,
    cpi.prd_end_dt
FROM silver.crm_prd_info cpi;

-- = Data Standardization & Consistency Check
SELECT DISTINCT prd_line
FROM silver.crm_prd_info cpi;

-- Standardizing prd_line
SELECT
    cpi.prd_id,
    cpi.prd_key,
    REPLACE(SUBSTRING(cpi.prd_key, 1, 5), '-', '_') as cat_id,
    SUBSTRING(cpi.prd_key, 7, LENGTH(cpi.prd_key)) as prd_key,
    cpi.prd_nm,
    COALESCE(cpi.prd_cost, 0) as prd_cost,
    (CASE WHEN UPPER(TRIM(cpi.prd_line)) = 'M' THEN 'Mountain'
          WHEN UPPER(TRIM(cpi.prd_line)) = 'R' THEN 'Road'
          WHEN UPPER(TRIM(cpi.prd_line)) = 'S' THEN 'Other Sales'
          WHEN UPPER(TRIM(cpi.prd_line)) = 'T' THEN 'Touring'
          ELSE 'n/a'
    END) as prd_line,
    cpi.prd_start_dt,
    cpi.prd_end_dt
FROM silver.crm_prd_info cpi;

-- = Checking for Invalid Date Orders
SELECT *
FROM silver.crm_prd_info cpi
WHERE cpi.prd_end_dt < cpi.prd_start_dt;

-- Fixing end_date where prd_end_dt = prd_start_dt of the 'NEXT' record - 1 using LEAD() Window function
SELECT
    cpi.prd_id,
    REPLACE(SUBSTRING(cpi.prd_key, 1, 5), '-', '_') as cat_id,
    SUBSTRING(cpi.prd_key, 7, LENGTH(cpi.prd_key)) as prd_key,
    cpi.prd_nm,
    COALESCE(cpi.prd_cost, 0) as prd_cost,
    (CASE WHEN UPPER(TRIM(cpi.prd_line)) = 'M' THEN 'Mountain'
          WHEN UPPER(TRIM(cpi.prd_line)) = 'R' THEN 'Road'
          WHEN UPPER(TRIM(cpi.prd_line)) = 'S' THEN 'Other Sales'
          WHEN UPPER(TRIM(cpi.prd_line)) = 'T' THEN 'Touring'
          ELSE 'n/a'
    END) as prd_line,
    cpi.prd_start_dt,
    (LEAD(cpi.prd_start_dt) OVER(PARTITION BY cpi.prd_key ORDER BY cpi.prd_start_dt ASC)::DATE - INTERVAL '1 day')::DATE AS prd_end_dt
FROM silver.crm_prd_info cpi;

--============================================
-- TRANSACTIONAL RECORDS ON SALES & ORDERS
--============================================

SELECT *
FROM silver.crm_sales_details csd;

-----------------------
-- Data Quality Check
-----------------------

-- = Data Integrity Check with silver.crm_prd_info cpi (sls_prd_key)
SELECT *
FROM silver.crm_sales_details csd
WHERE csd.sls_prd_key NOT IN (SELECT prd_key FROM silver.crm_prd_info cpi);

-- = Data Integrity Check with silver.crm_cst_info cpi (sls_cust_key)
SELECT *
FROM silver.crm_sales_details csd
WHERE csd.sls_cust_id NOT IN (SELECT cust_id FROM silver.crm_cust_info cpi);

-- = Checking for Invalid Dates
SELECT csd.sls_order_dt
FROM silver.crm_sales_details csd
WHERE csd.sls_order_dt <= 0
    OR LENGTH(csd.sls_order_dt::TEXT) != 8
    OR csd.sls_order_dt > 20500101
    OR csd.sls_order_dt < 19000101;

-- = Checking for Invalid Dates Orders
SELECT csd.sls_order_dt
FROM silver.crm_sales_details csd
WHERE csd.sls_order_dt > csd.sls_ship_dt OR csd.sls_order_dt > csd.sls_due_dt;

-- = Checking Data Consistency between Sales, Quantity and Price columns
-- >> Sales = Quantity * Price
-- >> Values must not be NULL, zero or negative
SELECT DISTINCT
    csd.sls_sales, csd.sls_quantity, csd.sls_price
FROM silver.crm_sales_details csd
WHERE csd.sls_sales != csd.sls_quantity * csd.sls_price
    OR csd.sls_sales IS NULL OR csd.sls_quantity IS NULL OR csd.sls_price IS NULL
    OR csd.sls_sales <= 0 OR csd.sls_quantity <= 0 OR csd.sls_price <= 0
ORDER BY csd.sls_sales, csd.sls_quantity, csd.sls_price DESC;

/*
 Data Warehouse (Silver schema business rules)
- If sales is negative, zero or null, derive it using quantity and price
- If price is zero or null, calculate it using sales and quantity
- If price is negative, convert it to positive value
*/
SELECT DISTINCT
    csd.sls_sales as old_sls_sales,
    csd.sls_quantity,
    csd.sls_price as old_sls_price,

    -- 1. Calculate sls_sales
    CASE WHEN csd.sls_sales IS NULL OR csd.sls_sales <= 0 OR csd.sls_sales != csd.sls_quantity * ABS(csd.sls_price)
              THEN csd.sls_quantity * ABS(csd.sls_price)
          ELSE csd.sls_sales
    END as sls_sales,

    -- 2. Calculate sls_price
    CASE WHEN csd.sls_price IS NULL OR csd.sls_price <= 0
              THEN (csd.sls_quantity * ABS(csd.sls_price)) / NULLIF(COALESCE(csd.sls_quantity, 0), 0)
          ELSE csd.sls_price
    END as sls_price
FROM silver.crm_sales_details csd;

-- Transformed crm_sales_details table
SELECT
    csd.sls_ord_num,
    csd.sls_prd_key,
    csd.sls_cust_id,
    (CASE WHEN csd.sls_order_dt = 0 OR LENGTH(csd.sls_order_dt::TEXT) != 8 THEN NULL
          ELSE CAST(CAST(csd.sls_order_dt AS VARCHAR) AS DATE)
    END) as sls_order_dt,
    (CASE WHEN csd.sls_ship_dt = 0 OR LENGTH(csd.sls_ship_dt::TEXT) != 8 THEN NULL
          ELSE CAST(CAST(csd.sls_ship_dt AS VARCHAR) AS DATE)
    END) as sls_ship_dt,
    (CASE WHEN csd.sls_due_dt = 0 OR LENGTH(csd.sls_due_dt::TEXT) != 8 THEN NULL
          ELSE CAST(CAST(csd.sls_due_dt AS VARCHAR) AS DATE)
    END) as sls_due_dt,
    CASE WHEN csd.sls_sales IS NULL OR csd.sls_sales <= 0
              THEN csd.sls_quantity * ABS(COALESCE(csd.sls_price, 0))
         WHEN csd.sls_price IS NOT NULL AND csd.sls_sales != csd.sls_quantity * ABS(csd.sls_price)
              THEN csd.sls_quantity * ABS(csd.sls_price)
         ELSE csd.sls_sales
    END AS sls_sales,
    csd.sls_quantity,
    CASE WHEN csd.sls_price IS NULL OR csd.sls_price <= 0
              THEN csd.sls_sales / NULLIF(COALESCE(csd.sls_quantity, 0), 0)
         ELSE csd.sls_price
    END AS sls_price
FROM silver.crm_sales_details csd;

--============================================
-- EXTRA CUSTOMER INFORMATION (Birthdate)
--============================================

SELECT *
FROM silver.erp_cust_az12 eca;

-----------------------
-- Data Quality Check
-----------------------

-- = Checking for duplicate cid records
SELECT eca.cid, COUNT(*)
FROM silver.erp_cust_az12 eca
GROUP BY eca.cid
HAVING COUNT(*) > 1;

-- = Standardizing & Normalizing cid column
SELECT
    (CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LENGTH(eca.cid))
          ELSE cid
    END) as cid,
    eca.bdate,
    eca.gen
FROM silver.erp_cust_az12 eca;

-- = Identifying out-of-range dates
SELECT eca.bdate
FROM silver.erp_cust_az12 eca
WHERE bdate < '1924-01-01' OR bdate > NOW();

-- = Data Standardization & Consistency
SELECT DISTINCT gen,
    (CASE WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
          WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'Male'
          ELSE 'Unknown'
    END) as gen
FROM silver.erp_cust_az12 eca;

-- Transformed Extra Customer Information Table
SELECT
    (CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LENGTH(eca.cid))
          ELSE cid
    END) as cid,
    (CASE WHEN bdate > NOW() THEN NULL
          ELSE bdate
    END) as bdate,
    (CASE WHEN UPPER(TRIM(eca.gen)) IN ('F', 'FEMALE') THEN 'Female'
          WHEN UPPER(TRIM(eca.gen)) IN ('M', 'MALE') THEN 'Male'
          ELSE 'Unknown'
    END) as gen
FROM silver.erp_cust_az12 eca;

--============================================
-- LOCATION OF CUSTOMERS (by Country)
--============================================

SELECT *
FROM silver.erp_loc_a101 ela;

-----------------------
-- Data Quality Check
-----------------------

-- = Data Normalization & Standardization
SELECT REPLACE(cid, '-', '') cid, cntry
FROM silver.erp_loc_a101 ela;

-- = Standardizing country names
SELECT DISTINCT
    (CASE WHEN TRIM(cntry) = 'DE' THEN 'Germany'
          WHEN UPPER(TRIM(cntry)) IN ('US', 'USA') THEN 'United States'
          WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'n/a'
          ELSE TRIM(cntry)
    END) cntry
FROM silver.erp_loc_a101 ela
ORDER BY cntry;

-- Transformed erp_loc_a101 Table
SELECT
    REPLACE(cid, '-', '') cid,
    (CASE WHEN TRIM(cntry) = 'DE' THEN 'Germany'
          WHEN UPPER(TRIM(cntry)) IN ('US', 'USA') THEN 'United States'
          WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'n/a'
          ELSE TRIM(cntry)
    END) cntry
FROM silver.erp_loc_a101 ela;

--============================================
-- EXTRA PRODUCT INFORMATION (by Category)
--============================================

SELECT *
FROM silver.erp_px_cat_g1v2 epcgv;

-----------------------
-- Data Quality Check
-----------------------

-- = Checking for Unwanted Spaces
SELECT *
FROM silver.erp_px_cat_g1v2 epcgv
WHERE epcgv.cat != TRIM(epcgv.cat)
    OR epcgv.subcat != TRIM(epcgv.subcat)
    OR epcgv.maintenance != TRIM(epcgv.maintenance::VARCHAR)::BOOLEAN;

-- = Data Standardization & Consistency
SELECT DISTINCT
    epcgv.maintenance,
    (CASE WHEN epcgv.maintenance = FALSE THEN 'No'
          WHEN epcgv.maintenance = TRUE THEN 'Yes'
          ELSE 'Unknown'
    END) AS maintenance
FROM silver.erp_px_cat_g1v2 epcgv;

-- Transformed erp_px_cat_g1v2 Table
SELECT
    epcgv.id,
    epcgv.cat,
    epcgv.subcat,
    (CASE WHEN epcgv.maintenance = FALSE THEN 'No'
          WHEN epcgv.maintenance = TRUE THEN 'Yes'
          ELSE 'Unknown'
    END) AS maintenance
FROM silver.erp_px_cat_g1v2 epcgv;
