# Data Catalog for Gold Layer

## Overview

The **Gold Layer** is the business-level data representation, designed to support analytical and reporting use cases. It consists of **dimension tables** (`gold.dim_customers`, `gold.dim_products`) and a **fact table** (`gold.fact_sales`) for tracking sales transactions and their associated dimensions.

---

## **1. gold.dim\_customers**

- **Purpose:** Stores enriched customer details, including demographic and geographic data, derived from `silver.crm_cust_info`, `silver.erp_cust_az12`, and `silver.erp_loc_a101`.
- **Source Tables:**
  - `silver.crm_cust_info` (Primary customer data)
  - `silver.erp_cust_az12` (Birthdate and gender)
  - `silver.erp_loc_a101` (Country information)




| Column Name      | **PostgreSQL Data Type** | Description                                                                                                           |
| ---------------- | ------------------------ | --------------------------------------------------------------------------------------------------------------------- |
| customer\_key    | SERIAL                   | Surrogate key (auto-generated) uniquely identifying each customer in the dimension table.                             |
| customer\_id     | INTEGER                  | Unique numerical identifier for the customer (from `silver.crm_cust_info`).                                           |
| customer\_number | VARCHAR(50)              | Alphanumeric customer identifier (from `silver.crm_cust_info.cust_key`).                                              |
| first\_name      | VARCHAR(50)              | Customer's first name (from `silver.crm_cust_info.cst_firstname`).                                                    |
| last\_name       | VARCHAR(50)              | Customer's last name (from `silver.crm_cust_info.cst_lastname`).                                                      |
| country          | VARCHAR(50)              | Customer's country of residence (from `silver.erp_loc_a101.cntry`).                                                   |
| marital\_status  | VARCHAR(50)              | Marital status (e.g., 'Married', 'Single') (from `silver.crm_cust_info.cust_marital_status`).                         |
| gender           | VARCHAR(50)              | Gender (e.g., 'Male', 'Female', 'n/a'). Prioritizes `silver.crm_cust_info.cust_gndr` over `silver.erp_cust_az12.gen`. |
| birth\_date      | DATE                     | Customer's date of birth (from `silver.erp_cust_az12.bdate`).                                                         |
| create\_date     | TIMESTAMP                | Date when the customer record was created (from `silver.crm_cust_info.cust_create_date`).                             |


---

## **2. gold.dim\_products**

- **Purpose:** Stores product details, including category, subcategory, and cost, derived from `silver.crm_prd_info` and `silver.erp_px_cat_g1v2`.
- **Source Tables:**
  - `silver.crm_prd_info` (Primary product data)
  - `silver.erp_px_cat_g1v2` (Category and subcategory details)




| Column Name     | **PostgreSQL Data Type** | Description                                                                                                               |
| --------------- | ------------------------ | ------------------------------------------------------------------------------------------------------------------------- |
| product\_key    | SERIAL                   | Surrogate key (auto-generated) uniquely identifying each product in the dimension table.                                  |
| product\_id     | INTEGER                  | Unique numerical identifier for the product (from `silver.crm_prd_info.prd_id`).                                          |
| product\_number | VARCHAR(50)              | Alphanumeric product identifier (from `silver.crm_prd_info.prd_key`).                                                     |
| product\_name   | VARCHAR(50)              | Descriptive name of the product (from `silver.crm_prd_info.prd_nm`).                                                      |
| category\_id    | VARCHAR(50)              | Category identifier (from `silver.crm_prd_info.cat_id`).                                                                  |
| category        | VARCHAR(50)              | Broader product classification (e.g., 'Bikes', 'Components') (from `silver.erp_px_cat_g1v2.cat`).                         |
| subcategory     | VARCHAR(50)              | Detailed product classification (from `silver.erp_px_cat_g1v2.subcat`).                                                   |
| maintenance     | VARCHAR(50)              | Indicates if the product requires maintenance (e.g., 'Yes', 'No', 'Unknown') (from `silver.erp_px_cat_g1v2.maintenance`). |
| cost            | NUMERIC(10, 2)           | Cost or base price of the product (from `silver.crm_prd_info.prd_cost`).                                                  |
| product\_line   | VARCHAR(50)              | Product line or series (e.g., 'Road', 'Mountain') (from `silver.crm_prd_info.prd_line`).                                  |
| start\_date     | DATE                     | Date when the product became available (from `silver.crm_prd_info.prd_start_dt`).                                         |


---

## **3. gold.fact\_sales**

- **Purpose:** Stores transactional sales data, linked to `gold.dim_customers` and `gold.dim_products` via surrogate keys.
- **Source Tables:**
  - `silver.crm_sales_details` (Primary sales data)
  - `gold.dim_customers` (Customer dimension)
  - `gold.dim_products` (Product dimension)




| Column Name    | **PostgreSQL Data Type** | Description                                                                                        |
| -------------- | ------------------------ | -------------------------------------------------------------------------------------------------- |
| order\_number  | VARCHAR(50)              | Unique alphanumeric identifier for each sales order (from `silver.crm_sales_details.sls_ord_num`). |
| product\_key   | INTEGER                  | Surrogate key linking to `gold.dim_products` (from `gold.dim_products.product_key`).               |
| customer\_key  | INTEGER                  | Surrogate key linking to `gold.dim_customers` (from `gold.dim_customers.customer_key`).            |
| order\_date    | DATE                     | Date when the order was placed (from `silver.crm_sales_details.sls_order_dt`).                     |
| shipping\_date | DATE                     | Date when the order was shipped (from `silver.crm_sales_details.sls_ship_dt`).                     |
| due\_date      | DATE                     | Date when the order payment was due (from `silver.crm_sales_details.sls_due_dt`).                  |
| sales\_amount  | NUMERIC(10, 2)           | Total monetary value of the sale (from `silver.crm_sales_details.sls_sales`).                      |
| quantity       | INTEGER                  | Number of units ordered (from `silver.crm_sales_details.sls_quantity`).                            |
| price          | NUMERIC(10, 2)           | Price per unit (from `silver.crm_sales_details.sls_price`).                                        |


---

## **Relationships**

- **`gold.fact_sales`** is linked to:
  - **`gold.dim_customers`** via `customer_key`.
  - **`gold.dim_products`** via `product_key`.

---

## **Data Quality Notes**

1. **Duplicates:** Checks for duplicate `cust_id` in `gold.dim_customers` and `prd_key` in `gold.dim_products`.
2. **Data Integration:**
  - Gender in `gold.dim_customers` prioritizes `silver.crm_cust_info.cust_gndr` over `silver.erp_cust_az12.gen`.
  - Only current products (where `prd_end_dt IS NULL`) are included in `gold.dim_products`.
3. **Constraint Check:** Validates foreign key integrity between `gold.fact_sales` and its associated dimensions.

---

## **Usage Guidelines**

- Use `gold.dim_customers` and `gold.dim_products` for filtering and grouping in analytical queries.
- Use `gold.fact_sales` for aggregating sales metrics (e.g., total sales, average price, quantity sold).
- Surrogate keys (`customer_key`, `product_key`) ensure consistent joins across tables.
