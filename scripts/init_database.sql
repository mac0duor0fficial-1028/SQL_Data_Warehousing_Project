/*
=============================================================
1. Create Database
=============================================================
Script Purpose:
    This script drops the existing 'Sales_Data_Warehouse' database 
    if it exists and creates a fresh instance.
	
WARNING:
    Running this script will permanently delete all data in the 
    'Sales_Data_Warehouse' database. Proceed with caution.
*/

-- Terminate active connections to the database so it can be dropped
SELECT pg_terminate_backend(pg_stat_activity.pid)
FROM pg_stat_activity
WHERE pg_stat_activity.datname = 'sales_data_warehouse'
  AND pid <> pg_backend_pid();

-- Drop and recreate the database
DROP DATABASE IF EXISTS sales_data_warehouse;
CREATE DATABASE sales_data_warehouse;

/*
=============================================================
2. Create Schemas
=============================================================
Script Purpose:
    This script sets up the three layers of the medallion 
    data architecture ('bronze', 'silver', and 'gold') 
    inside the 'sales_data_warehouse' database.
*/

-- Create Schemas if they don't already exist
CREATE SCHEMA IF NOT EXISTS bronze;
CREATE SCHEMA IF NOT EXISTS silver;
CREATE SCHEMA IF NOT EXISTS gold;
