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

use master;
GO

-- Drop & Recreate the 'DataWarehouse' database
If exists ( select 1 from sys.databases where name ='Datawarehouse')
Begin 
      Alter Database DataWareHouse Set single_user with rollback immediate;
      Drop Database DataWareHouse;
End;
Go 
-- create a database warehouse
create database DataWareHouse;
GO

Use DataWareHouse;
GO
-- Create Schemas
create schema bronze;
GO
create schema Silver;
GO
create schema Gold;
Go
