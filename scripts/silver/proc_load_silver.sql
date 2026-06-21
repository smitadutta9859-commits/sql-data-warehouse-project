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
    EXEC Silver.load_silver;
===============================================================================
*/

EXEC silver.load_silver

CREATE OR ALTER PROCEDURE silver.load_silver
AS
BEGIN
	DECLARE @start_time DATETIME, @end_time DATETIME,  @batch_start_time DATETIME, @batch_end_time DATETIME;
	BEGIN TRY
		SET @batch_start_time = GETDATE();
		PRINT '==============================================='
		PRINT 'Loading Sliver Layer'
		PRINT '==============================================='

		PRINT '-----------------------------------------------'
		PRINT 'Loading CRM Tables'
		PRINT '-----------------------------------------------'

		-- Loading Silver.crm_cust_info
		SET @start_time = GETDATE();
		PRINT'>>>> Truncating Table: silver.crm_cust_info';
		Truncate table silver.crm_cust_info;
		PRINT '>>> Inserting Data Into:silver_crm_cust_info'
		INSERT INTO silver.crm_cust_info (
				cst_id,
				cst_key,
				cst_firstname,
				cst_lastname,
				cst_marital_status,
				cst_gndr,
				cst_create_date)
		Select cst_id, cst_key,
		Trim(cst_firstname) as Firstname, 
		Trim(cst_lastname) as Lastname,
		Case 
			 when Upper(trim(cst_marital_status)) = 'M' then 'Married'
			 when upper(trim(cst_marital_status)) = 'S' then 'Single'
			 else 'N/A'
			 end as cst_marital_status, --- Normalize marital staus values to readable format
		Case when upper(trim(cst_gndr)) = 'M' then 'Male'
			 when upper(trim(cst_gndr)) = 'F' then 'Female'
			 else 'N/A' end as cst_gndr, --- Normalize gender vlues to readable format
		cst_create_date
		from (
		select *, ROW_NUMBER() over (partition by cst_id order by cst_create_date desc) as flag_last
		from bronze.crm_cust_info where cst_id is not null)t where flag_last = 1; --- select the most recent record per customer
		SET @end_time = GETDATE();
		PRINT '>>> Loading: ' + CAST(DATEDIFF(SECOND,@start_time,@end_time) AS NVARCHAR) + 'seconds'
		PRINT '>> ...............................';

		-- Loading silver.crm_prd_info
		SET @start_time = GETDATE();
		PRINT'>>>> Truncating Table: silver.crm_prd_info';
		Truncate table silver.crm_prd_info;

		PRINT '>>> Inserting Data Into:silver.crm_prd_info';

		INSERT INTO silver.crm_prd_info(
			prd_id,
			cat_id,
			prd_key,
			prd_nm,
			prd_cost,
			prd_line,
			prd_start_dt,
			prd_end_dt
			)
		select 
		prd_id,
		replace(substring(prd_key,1,5), '-', '_') as cat_id,
		substring(prd_key,7,len(prd_key)) as prd_key,
		prd_nm,
		ISNULL(prd_cost,0) as prd_cost,
		CASE UPPER(TRIM(prd_line))
			 WHEN 'M' THEN 'Mountain'
			 WHEN 'R' THEN 'Road'
			 WHEN 'S' THEN 'other Sales'
			 WHEN 'T' THEN 'Touring'
			 ELSE 'n/a' END as prd_line,
		CAST(prd_start_dt as DATE) as prd_start_dt ,
		CAST(LEAD(prd_start_dt) over (partition by prd_key order by prd_start_dt)- 1 AS DATE) as prd_end_dt
		FROM bronze.crm_prd_info;
		SET @end_time = GETDATE();
		PRINT '>>> Loading: ' + CAST(DATEDIFF(SECOND,@start_time,@end_time) AS NVARCHAR) + 'seconds'
		PRINT '>> ...............................';

		-- Loading Silver.crm_sales_details
		SET @start_time = GETDATE();
		PRINT'>>>> Truncating Table: silver.crm_cust_info';
		
		Truncate table silver.crm_sales_details;

		PRINT '>>> Inserting Data Into:silver.crm_sales_details';
		INSERT INTO silver.crm_sales_details(
			sls_ord_num ,
			sls_prd_key,
			sls_cust_id,
			sls_order_dt,
			sls_ship_dt,
			sls_due_dt,
			sls_sales,
			sls_quantity,
			sls_price
		)
		select sls_odr_num ,
			sls_prd_key,
			sls_cust_id,
			CASE WHEN sls_order_dt = 0 OR LEN(sls_order_dt) != 8 THEN NULL
				ELSE CAST(CAST(sls_order_dt as VARCHAR) AS DATE) 
				END AS sls_order_dt,
			CASE WHEN sls_ship_dt = 0 OR LEN(sls_ship_dt) != 8 THEN NULL
				ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE) 
				END AS sls_ship_dt,
			CASE WHEN sls_due_dt = 0 OR LEN(sls_due_dt) != 8 THEN NULL
				ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE) 
				END AS sls_due_dt,
			CASE WHEN sls_sales <= 0 OR sls_sales IS NULL OR sls_sales != sls_quantity * ABS(sls_price)
				 THEN sls_quantity * ABS(sls_price) 
				 ELSE sls_sales END AS sls_sales,-- Recalculated Sales if original value is missing or incorrect
			sls_quantity,
			CASE WHEN sls_price IS NULL OR sls_price <= 0
					THEN sls_sales/ NULLIF(sls_quantity,0)
					ELSE sls_price
					END AS sls_price -- derive price if original value is incorrect.
		FROM bronze.crm_sales_details;
		SET @end_time = GETDATE();
		PRINT '>>> Loading: ' + CAST(DATEDIFF(SECOND,@start_time,@end_time) AS NVARCHAR) + 'seconds';
		PRINT '>> ...............................';

		SET @start_time = GETDATE();
		PRINT'>>>> Truncating Table: silver.erp_cust_az12';

		
		Truncate table silver.erp_cust_az12;
		PRINT '>>> Inserting Data Into:silver.erp.cust_az12';
		Insert Into silver.erp_cust_az12(
			cid,
			bdate,
			gender
			)
		Select 
			CASE WHEN cid LIKE 'NAS%' Then substring(cid,4,len(cid)) ---Remove "NAS" prefic if present
				Else cid 
			END AS cid,
			CASE WHEN bdate > GETDATE() THEN NULL
			Else bdate 
			END as bdate, -- Set future brithdates to null
			CASE WHEN Upper(trim(gender)) in ('F', 'Female') Then 'Female'
				 WHEN upper(trim(gender)) in ('M', 'Male') Then 'Male'
				 Else 'N/A' end as gender
		From bronze.erp_cust_az12 ;
		SET @end_time = GETDATE();
		PRINT '>>> Loading: ' + CAST(DATEDIFF(SECOND,@start_time,@end_time) AS NVARCHAR) + 'seconds'
		PRINT '>> ...............................';

		SET @start_time = GETDATE();
		PRINT'>>>> Truncating Table: silver.erp_loc_a101';

		Truncate table silver.erp_loc_a101;
		PRINT '>>> Inserting Data Into:silver.erp_loc_a101';
		INSERT INTO silver.erp_loc_a101(
		cid,
		cntry
		)
		Select 
		replace(cid,'-','') as cid,
		CASE WHEN upper(trim(cntry)) in ('US','USA', 'United States') THEN 'United States'
			 when upper(trim(cntry)) = 'DE' THEN 'Germany'
			 WHEN UPPER(trim(cntry)) = '' OR cntry is  null THEN 'n/a'
			 ELSE TRIM(cntry) 
		END AS cntry
		from bronze.erp_loc_a101;
		SET @end_time = GETDATE();
		PRINT '>>> Loading: ' + CAST(DATEDIFF(SECOND,@start_time,@end_time) AS NVARCHAR) + 'seconds';
		PRINT '>> ...............................';

		SET @start_time = GETDATE();
		PRINT'>>>> Truncating Table: silver.erp_px_cat_g1v2';
		Truncate table silver.erp_px_cat_g1v2;

		SET @start_time = GETDATE();
		
		PRINT '>>> Inserting Data Into:silver.erp_px_cat_g1v2'
		INSERT INTO silver.erp_px_cat_g1v2(
		id,
		cat,
		subcat,
		maintenance
		)
		Select
		id,
		cat,
		subcat,
		maintenance
		FROM bronze.erp_px_cat_g1v2;
		SET @end_time = GETDATE();
		PRINT '>>> Loading: ' + CAST(DATEDIFF(SECOND,@start_time,@end_time) AS NVARCHAR) + 'seconds'
		PRINT '>> ...............................';

		SET @batch_end_time = GETDATE();
		PRINT'===============================================';
		PRINT'Loading Silver Layer is Completed';
		PRINT'  -Total Load Duration: ' + CAST(DATEDIFF(SECOND,@batch_start_time, @batch_end_time) AS NVARCHAR) + 'seconds';
		PRINT '================================================';

		END TRY
		BEGIN CATCH
		PRINT'=================================================';
		PRINT'ERROR OCCURED DURING LOADING SILVER LAYER';
		PRINT'Error Message' + ERROR_MESSAGE();
		PRINT'Error Message' + CAST(ERROR_NUMBER() AS NVARCHAR);
		PRINT'Error Message' + CAST(ERROR_STATE() AS NVARCHAR);
		PRINT'=================================================';
		END CATCH
END;
