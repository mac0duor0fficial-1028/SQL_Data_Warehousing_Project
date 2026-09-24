/*
===============================================================================
Stored Procedure: Load Silver Layer (Bronze -> Silver)
===============================================================================
Script Purpose:
    This stored procedure performs the ETL (Extract, Transform, Load) process to 
    populate the 'silver' schema tables from the 'bronze' schema.
	Actions Performed:
		- Truncates Silver tables.
		- Inserts transformed and cleansed data from Bronze into Silver tables.
		
Parameters:
    None. 
	  This stored procedure does not accept any parameters or return any values.

Usage Example:
    CALL Silver.load_silver();
===============================================================================
*/

CREATE OR REPLACE PROCEDURE silver.load_silver()
LANGUAGE plpgsql
AS $$
DECLARE
    -- Error Handling Variables
    v_error_msg  TEXT;
    v_error_code TEXT;
    
    -- Global Pipeline Time Variables
    v_start_time     TIMESTAMP;
    v_end_time       TIMESTAMP;
    v_total_duration INTERVAL;
    
    -- Individual Table Time Variables
    v_tab_start_time TIMESTAMP;
    v_tab_end_time   TIMESTAMP;
    v_tab_duration   INTERVAL;

BEGIN
    -- Capture the overall start time of the entire pipeline
    v_start_time := CLOCK_TIMESTAMP();

    RAISE NOTICE '=====================================================';
    RAISE NOTICE 'Orchestrating Silver Layer Data Migration';
    RAISE NOTICE 'Pipeline Start Time: %', v_start_time;
    RAISE NOTICE '=====================================================';
    
    --=====================================================================================================
    -- SECTION 1: CRM SOURCE TABLES SYSTEM MIGRATION
    --=====================================================================================================
    RAISE NOTICE '-----------------------------------------------------';
    RAISE NOTICE 'BATCH A: Processing CRM System Layer Tables';
    RAISE NOTICE '-----------------------------------------------------';

    -- TABLE 1: silver.crm_cust_info
    ---------------------------------------------------------------------
    RAISE NOTICE '>> Truncating Table : silver.crm_cust_info';
    TRUNCATE TABLE silver.crm_cust_info CASCADE;

    RAISE NOTICE '>> Inserting Data into : silver.crm_cust_info';
    v_tab_start_time := CLOCK_TIMESTAMP();
    
    INSERT INTO silver.crm_cust_info (
            cust_id, cust_key, cst_firstname, cst_lastname, 
            cust_marital_status, cust_gndr, cust_create_date 
    )
    SELECT 
        cust_id, cust_key, TRIM(cst_firstname), TRIM(cst_lastname),
        (CASE WHEN UPPER(TRIM(cust_marital_status)) = 'S' THEN 'Single'
              WHEN UPPER(TRIM(cust_marital_status)) = 'M' THEN 'Married'
              ELSE 'Unknown'
        END) AS cust_marital_status,
        (CASE WHEN UPPER(TRIM(cust_gndr)) = 'F' THEN 'Female'
              WHEN UPPER(TRIM(cust_gndr)) = 'M' THEN 'Male'
              ELSE 'Unknown'
        END) AS cust_gndr,
        -- Standardized: Safely converts long epoch dates down to timestamps if needed
        CASE WHEN cust_create_date > 500000000000 THEN to_timestamp(cust_create_date / 1000)::DATE
             ELSE to_timestamp(cust_create_date)::DATE
        END AS cust_create_date
    FROM (
        SELECT *,
            ROW_NUMBER() OVER(PARTITION BY cci.cust_id ORDER BY cci.cust_create_date DESC) AS flag_last
        FROM bronze.crm_cust_info cci
    ) sub
    WHERE flag_last = 1 AND cust_id IS NOT NULL;

    v_tab_end_time := CLOCK_TIMESTAMP();
    RAISE NOTICE '>> Row count for crm_cust_info: % | Duration: %', (SELECT count(*) FROM silver.crm_cust_info), (v_tab_end_time - v_tab_start_time);
    
    -- TABLE 2: silver.crm_prd_info
    ---------------------------------------------------------------------
    RAISE NOTICE '>> Truncating Table : silver.crm_prd_info';
    TRUNCATE TABLE silver.crm_prd_info CASCADE;
    
    RAISE NOTICE '>> Inserting Data into : silver.crm_prd_info';
    v_tab_start_time := CLOCK_TIMESTAMP();

    INSERT INTO silver.crm_prd_info (
            prd_id, cat_id, prd_key, prd_nm, prd_cost, prd_line, prd_start_dt, prd_end_dt
    )
    SELECT 
        cpi.prd_id,
        REPLACE(SUBSTRING(cpi.prd_key, 1, 5), '-', '_') AS cat_id,
        SUBSTRING(cpi.prd_key, 7, LENGTH(cpi.prd_key)) AS prd_key,
        cpi.prd_nm,
        COALESCE(cpi.prd_cost, 0) AS prd_cost,
        (CASE WHEN UPPER(TRIM(cpi.prd_line)) = 'M' THEN 'Mountain'
              WHEN UPPER(TRIM(cpi.prd_line)) = 'R' THEN 'Road'
              WHEN UPPER(TRIM(cpi.prd_line)) = 'S' THEN 'Other Sales'
              WHEN UPPER(TRIM(cpi.prd_line)) = 'T' THEN 'Touring'
              ELSE 'n/a'
        END) AS prd_line,
        cpi.prd_start_dt,
        (LEAD(cpi.prd_start_dt) OVER(PARTITION BY cpi.prd_key ORDER BY cpi.prd_start_dt ASC)::DATE - INTERVAL '1 day')::DATE AS prd_end_dt 
    FROM bronze.crm_prd_info cpi;

    v_tab_end_time := CLOCK_TIMESTAMP();
    RAISE NOTICE '>> Row count for crm_prd_info: % | Duration: %', (SELECT count(*) FROM silver.crm_prd_info), (v_tab_end_time - v_tab_start_time);
    
    -- TABLE 3: silver.crm_sales_details
    ---------------------------------------------------------------------
    RAISE NOTICE '>> Truncating Table : silver.crm_sales_details'; 
    TRUNCATE TABLE silver.crm_sales_details CASCADE;
    
    RAISE NOTICE '>> Inserting Data into : silver.crm_sales_details';
    v_tab_start_time := CLOCK_TIMESTAMP();
    
    INSERT INTO silver.crm_sales_details (
            sls_ord_num, sls_prd_key, sls_cust_id, sls_order_dt, 
            sls_ship_dt, sls_due_dt, sls_sales, sls_quantity, sls_price
    )
    SELECT 
        csd.sls_ord_num, csd.sls_prd_key, csd.sls_cust_id,
        CASE WHEN csd.sls_order_dt = 0 OR csd.sls_order_dt IS NULL THEN NULL ELSE to_timestamp(csd.sls_order_dt / 1000)::DATE END,
        CASE WHEN csd.sls_ship_dt = 0 OR csd.sls_ship_dt IS NULL THEN NULL ELSE to_timestamp(csd.sls_ship_dt / 1000)::DATE END,
        CASE WHEN csd.sls_due_dt = 0 OR csd.sls_due_dt IS NULL THEN NULL ELSE to_timestamp(csd.sls_due_dt / 1000)::DATE END,
        CASE WHEN csd.sls_sales IS NULL OR csd.sls_sales <= 0 THEN csd.sls_quantity * ABS(COALESCE(csd.sls_price, 0))
             WHEN csd.sls_price IS NOT NULL AND csd.sls_sales != csd.sls_quantity * ABS(csd.sls_price) THEN csd.sls_quantity * ABS(csd.sls_price)
             ELSE csd.sls_sales
        END AS sls_sales,
        csd.sls_quantity,
        CASE WHEN csd.sls_price IS NULL OR csd.sls_price <= 0 THEN csd.sls_sales / NULLIF(COALESCE(csd.sls_quantity, 0), 0)
             ELSE csd.sls_price
        END AS sls_price
    FROM bronze.crm_sales_details csd;

    v_tab_end_time := CLOCK_TIMESTAMP();
    RAISE NOTICE '>> Row count for crm_sales_details: % | Duration: %', (SELECT count(*) FROM silver.crm_sales_details), (v_tab_end_time - v_tab_start_time);

    --=====================================================================================================
    -- SECTION 2: ERP SOURCE TABLES SYSTEM MIGRATION
    --=====================================================================================================
    RAISE NOTICE '-----------------------------------------------------';
    RAISE NOTICE 'BATCH B: Processing ERP System Layer Tables';
    RAISE NOTICE '-----------------------------------------------------';

    -- TABLE 4: silver.erp_cust_az12
    ---------------------------------------------------------------------
    RAISE NOTICE '>> Truncating Table : silver.erp_cust_az12';
    TRUNCATE TABLE silver.erp_cust_az12 CASCADE;

    RAISE NOTICE '>> Inserting Data into : silver.erp_cust_az12';
    v_tab_start_time := CLOCK_TIMESTAMP();

    INSERT INTO silver.erp_cust_az12 (
        bdate, gen, cid
    )
    SELECT 
        -- Cast historical string dates safely to DATE format
        CASE WHEN bdate IS NULL OR bdate = '' THEN NULL ELSE bdate::DATE END,
        -- Cleansing gender text profiles
        CASE WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
             WHEN UPPER(TRIM(gen)) IN ('M', 'MALE')   THEN 'Male'
             ELSE 'Unknown'
        END AS gen,
        -- Removing localized alpha prefixes from ID sequences if needed (e.g., 'NAS1001' to 1001)
        CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid FROM 4)::INT 
             ELSE cid::INT 
        END AS cid
    FROM bronze.erp_cust_az12;

    v_tab_end_time := CLOCK_TIMESTAMP();
    RAISE NOTICE '>> Row count for erp_cust_az12: % | Duration: %', (SELECT count(*) FROM silver.erp_cust_az12), (v_tab_end_time - v_tab_start_time);

    -- TABLE 5: silver.erp_loc_a101
    ---------------------------------------------------------------------
    RAISE NOTICE '>> Truncating Table : silver.erp_loc_a101';
    TRUNCATE TABLE silver.erp_loc_a101 CASCADE;

    RAISE NOTICE '>> Inserting Data into : silver.erp_loc_a101';
    v_tab_start_time := CLOCK_TIMESTAMP();

    INSERT INTO silver.erp_loc_a101 (
        cid, cntry
    )
    SELECT 
        cid,
        -- Standardizing country text descriptions
        CASE WHEN UPPER(TRIM(cntry)) IN ('US', 'USA', 'UNITED STATES') THEN 'United States'
             WHEN UPPER(TRIM(cntry)) IN ('DE', 'GERMANY') THEN 'Germany'
             WHEN UPPER(TRIM(cntry)) IN ('FR', 'FRANCE') THEN 'France'
             WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'Unknown'
             ELSE TRIM(cntry)
        END AS cntry
    FROM bronze.erp_loc_a101;

    v_tab_end_time := CLOCK_TIMESTAMP();
    RAISE NOTICE '>> Row count for erp_loc_a101: % | Duration: %', (SELECT count(*) FROM silver.erp_loc_a101), (v_tab_end_time - v_tab_start_time);

    -- TABLE 6: silver.erp_px_cat_g1v2
    ---------------------------------------------------------------------
    RAISE NOTICE '>> Truncating Table : silver.erp_px_cat_g1v2';
    TRUNCATE TABLE silver.erp_px_cat_g1v2 CASCADE;

    RAISE NOTICE '>> Inserting Data into : silver.erp_px_cat_g1v2';
    v_tab_start_time := CLOCK_TIMESTAMP();

    INSERT INTO silver.erp_px_cat_g1v2 (
        id, cat, subcat, maintenance
    )
    SELECT 
        id,
        TRIM(cat) AS cat,
        TRIM(subcat) AS subcat,
        -- Converts structural DBeaver checkbox statuses cleanly into TRUE/FALSE boolean variables
        CASE WHEN maintenance = TRUE OR maintenance::TEXT IN ('true', '1') THEN TRUE 
             ELSE FALSE 
        END AS maintenance
    FROM bronze.erp_px_cat_g1v2;

    v_tab_end_time := CLOCK_TIMESTAMP();
    RAISE NOTICE '>> Row count for erp_px_cat_g1v2: % | Duration: %', (SELECT count(*) FROM silver.erp_px_cat_g1v2), (v_tab_end_time - v_tab_start_time);

    --=====================================================================================================

EXCEPTION
    WHEN OTHERS THEN
        -- Capture diagnostic attributes on transaction crash
        GET STACKED DIAGNOSTICS v_error_msg = MESSAGE_TEXT, v_error_code = RETURNED_SQLSTATE;
        
        RAISE WARNING '=====================================================';
        RAISE WARNING 'CRITICAL DATABASE EXCEPTION OCCURRED!';
        RAISE WARNING 'SQL State Code : %', v_error_code;
        RAISE WARNING 'Error Message  : %', v_error_msg;
        RAISE WARNING '=====================================================';
        
        -- Re-throw exception to completely roll back changes securely
        RAISE EXCEPTION '% (SQLSTATE %)', v_error_msg, v_error_code;
END;
$$;
