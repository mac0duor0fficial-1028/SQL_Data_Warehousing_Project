/*
===============================================================================
Stored Procedure: Load Bronze Layer (Source -> Bronze)
===============================================================================
Script Purpose:
    This stored procedure loads data into the 'bronze' schema from external CSV files. 
    It performs the following actions:
    - Truncates the bronze tables before loading data.
    - Uses the `COPY` command to load data from csv Files to bronze tables.

Parameters:
    None. 
	  This stored procedure does not accept any parameters or return any values.

Usage Example:
    CALL bronze.load_bronze();
===============================================================================
*/

CREATE OR REPLACE PROCEDURE bronze.load_bronze()
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
    RAISE NOTICE 'Loading Bronze Layer';
    RAISE NOTICE 'Start Time: %', v_start_time;
    RAISE NOTICE '=====================================================';
    
    --=====================================================================================================
    RAISE NOTICE '-----------------------------------------------------';
    RAISE NOTICE 'Loading CRM Tables';
    RAISE NOTICE '-----------------------------------------------------';

    ---------------------------------------------------------------------
    RAISE NOTICE '>> Truncating Table : bronze.crm_cust_info';
    TRUNCATE TABLE bronze.crm_cust_info;
    
    RAISE NOTICE '>> Inserting Data into : bronze.crm_cust_info';
    v_tab_start_time := CLOCK_TIMESTAMP(); -- Start Table Timer
    
    COPY bronze.crm_cust_info
    FROM 'C:\Users\USER\OneDrive\Desktop\SQL_Data_Warehousing_Project\datasets\source_crm\cust_info.csv'
    WITH (FORMAT CSV, HEADER, DELIMITER ',');
    
    v_tab_end_time := CLOCK_TIMESTAMP(); -- End Table Timer
    v_tab_duration := v_tab_end_time - v_tab_start_time;
    
    RAISE NOTICE '>> Row count for crm_cust_info: %', (SELECT count(*) FROM bronze.crm_cust_info);
    RAISE NOTICE '>> Load Duration: %', v_tab_duration;

    ---------------------------------------------------------------------
    RAISE NOTICE '>> Truncating Table : bronze.crm_prd_info';
    TRUNCATE TABLE bronze.crm_prd_info;
    
    RAISE NOTICE '>> Inserting Data into : bronze.crm_prd_info';
    v_tab_start_time := CLOCK_TIMESTAMP();
    
    COPY bronze.crm_prd_info
    FROM 'C:\Users\USER\OneDrive\Desktop\SQL_Data_Warehousing_Project\datasets\source_crm\prd_info.csv'
    WITH (FORMAT CSV, HEADER, DELIMITER ',');
    
    v_tab_end_time := CLOCK_TIMESTAMP();
    v_tab_duration := v_tab_end_time - v_tab_start_time;
    
    RAISE NOTICE '>> Row count for crm_prd_info: %', (SELECT count(*) FROM bronze.crm_prd_info);
    RAISE NOTICE '>> Load Duration: %', v_tab_duration;

    ---------------------------------------------------------------------
    RAISE NOTICE '>> Truncating Table : bronze.crm_sales_details';
    TRUNCATE TABLE bronze.crm_sales_details;

    RAISE NOTICE '>> Inserting Data into : bronze.crm_sales_details';
    v_tab_start_time := CLOCK_TIMESTAMP();
    
    COPY bronze.crm_sales_details
    FROM 'C:\Users\USER\OneDrive\Desktop\SQL_Data_Warehousing_Project\datasets\source_crm\sales_details.csv'
    WITH (FORMAT CSV, HEADER, DELIMITER ',');
    
    v_tab_end_time := CLOCK_TIMESTAMP();
    v_tab_duration := v_tab_end_time - v_tab_start_time;
    
    RAISE NOTICE '>> Row count for crm_sales_details: %', (SELECT count(*) FROM bronze.crm_sales_details);
    RAISE NOTICE '>> Load Duration: %', v_tab_duration;
    
    --=====================================================================================================
    RAISE NOTICE '-----------------------------------------------------';
    RAISE NOTICE 'Loading ERP Tables';
    RAISE NOTICE '-----------------------------------------------------';

    RAISE NOTICE '>> Truncating Table : bronze.erp_cust_az12';
    TRUNCATE TABLE bronze.erp_cust_az12;
    
    RAISE NOTICE '>> Inserting Data into : bronze.erp_cust_az12';
    v_tab_start_time := CLOCK_TIMESTAMP();
    
    COPY bronze.erp_cust_az12
    FROM 'C:\Users\USER\OneDrive\Desktop\SQL_Data_Warehousing_Project\datasets\source_erp\cust_az12.csv'
    WITH (FORMAT CSV, HEADER, DELIMITER ',');

    v_tab_end_time := CLOCK_TIMESTAMP();
    v_tab_duration := v_tab_end_time - v_tab_start_time;

    RAISE NOTICE '>> Row count for erp_cust_az12: %', (SELECT count(*) FROM bronze.erp_cust_az12);
    RAISE NOTICE '>> Load Duration: %', v_tab_duration;
    
    ---------------------------------------------------------------------
    RAISE NOTICE '>> Truncating Table : bronze.erp_loc_a101';
    TRUNCATE TABLE bronze.erp_loc_a101;
    
    RAISE NOTICE '>> Inserting Data into : bronze.erp_loc_a101';
    v_tab_start_time := CLOCK_TIMESTAMP();
    
    COPY bronze.erp_loc_a101
    FROM 'C:\Users\USER\OneDrive\Desktop\SQL_Data_Warehousing_Project\datasets\source_erp\loc_a101.csv'
    WITH (FORMAT CSV, HEADER, DELIMITER ',');
    
    v_tab_end_time := CLOCK_TIMESTAMP();
    v_tab_duration := v_tab_end_time - v_tab_start_time;

    RAISE NOTICE '>> Row count for erp_loc_a101: %', (SELECT count(*) FROM bronze.erp_loc_a101);
    RAISE NOTICE '>> Load Duration: %', v_tab_duration;

    ---------------------------------------------------------------------
    RAISE NOTICE '>> Truncating Table : bronze.erp_px_cat_g1v2';
    TRUNCATE TABLE bronze.erp_px_cat_g1v2;

    RAISE NOTICE '>> Inserting Data into : bronze.erp_px_cat_g1v2';
    v_tab_start_time := CLOCK_TIMESTAMP();
    
    COPY bronze.erp_px_cat_g1v2
    FROM 'C:\Users\USER\OneDrive\Desktop\SQL_Data_Warehousing_Project\datasets\source_erp\px_cat_g1v2.csv'
    WITH (FORMAT CSV, HEADER, DELIMITER ',');
    
    v_tab_end_time := CLOCK_TIMESTAMP();
    v_tab_duration := v_tab_end_time - v_tab_start_time;

    RAISE NOTICE '>> Row count for erp_px_cat_g1v2: %', (SELECT count(*) FROM bronze.erp_px_cat_g1v2);
    RAISE NOTICE '>> Load Duration: %', v_tab_duration;
    
    -- Calculate final global timing metrics
    v_end_time := CLOCK_TIMESTAMP();
    v_total_duration := v_end_time - v_start_time;

    RAISE NOTICE '=====================================================';
    RAISE NOTICE 'Bronze Layer Loaded Successfully!';
    RAISE NOTICE 'Total End Time: %', v_end_time;
    RAISE NOTICE 'Total Pipeline Duration: %', v_total_duration;
    RAISE NOTICE '=====================================================';

EXCEPTION 
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS 
            v_error_msg = MESSAGE_TEXT,
            v_error_code = RETURNED_SQLSTATE;
        
        -- Capture failure timing metrics
        v_end_time := CLOCK_TIMESTAMP();
        v_total_duration := v_end_time - v_start_time;

        RAISE NOTICE '=====================================================';
        RAISE WARNING 'ERROR OCCURRED DURING BRONZE LAYER LOAD!';
        RAISE WARNING 'Pipeline Crashed At: %', v_end_time;
        RAISE WARNING 'Total Execution Before Crash: %', v_total_duration;
        RAISE WARNING 'SQL State Code: %', v_error_code;
        RAISE WARNING 'Error Message: %', v_error_msg;
        RAISE NOTICE '=====================================================';
        
        RAISE EXCEPTION 'Pipeline halted due to error: %', v_error_msg;
END;
$$;
