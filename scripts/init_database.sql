/*##############################################################################
Create DataBase and schemas
################################################################################
Script Purpose:
  This Script creates a new Database named 'DataWareHouse'  after checking if it already exists .
  If the database exists, it is dropped and recreated. Additionally the script sets up the 3 schemas within the database:
  'Bronze', 'Silver', 'Gold'.
Warning:
  Running this script will drop the entire 'DataWarehouse' Database if it exist. All data in the database will be permanently deleted' 
  Proceed with caution and ensure you have proper backups before running this script .*/

USE master;
GO

/*==================================================
  DROP & RECREATE DATABASE
==================================================*/

IF EXISTS (
    SELECT 1
    FROM sys.databases
    WHERE name = 'DataWarehouse'
)
BEGIN
    ALTER DATABASE DataWarehouse
    SET SINGLE_USER
    WITH ROLLBACK IMMEDIATE;

    DROP DATABASE DataWarehouse;
END;
GO

CREATE DATABASE DataWarehouse;
GO

USE DataWarehouse;
GO

/*==================================================
  DROP SCHEMAS IF THEY EXIST
==================================================*/

IF EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'bronze')
    DROP SCHEMA bronze;
GO

IF EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'silver')
    DROP SCHEMA silver;
GO

IF EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'gold')
    DROP SCHEMA gold;
GO

/*==================================================
  CREATE SCHEMAS
==================================================*/

CREATE SCHEMA bronze;
GO

CREATE SCHEMA silver;
GO

CREATE SCHEMA gold;
GO
