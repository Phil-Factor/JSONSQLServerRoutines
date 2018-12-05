CREATE OR ALTER PROCEDURE  #CreateJSONArrayInArraySchemaFromTable
/**
Summary: >
  This creates a JSON schema from a table that
  matches the JSON you will get from doing a 
  classic FOR JSON select * statemenmt on the entire table

Author: phil factor
Date: 4/12/2018

Examples: >
  DECLARE @Json NVARCHAR(MAX)
  EXECUTE #CreateJSONArrayInArraySchemaFromTable @database='pubs', @Schema ='dbo', @table= 'authors',@JSONSchema=@json OUTPUT
  PRINT @Json
  SELECT @json=''
  EXECUTE #CreateJSONArrayInArraySchemaFromTable @TableSpec='pubs.dbo.authors',@JSONSchema=@json OUTPUT
  PRINT @Json
Returns: >
  nothing
**/
    (@database sysname=null, @Schema sysname=NULL, @table sysname=null, @Tablespec sysname=NULL,@jsonSchema NVARCHAR(MAX) output)

--WITH ENCRYPTION|SCHEMABINDING, ...
AS

DECLARE @required NVARCHAR(max), @NoColumns INT, @properties NVARCHAR(max);
			
	IF Coalesce(@table,@Tablespec) IS NULL
		OR Coalesce(@schema,@Tablespec) IS NULL
		RAISERROR ('{"error":"must have the table details"}',16,1)
			
	IF @table is NULL SELECT @table=ParseName(@Tablespec,1)
	IF @Schema is NULL SELECT @schema=ParseName(@Tablespec,2)
	IF @Database is NULL SELECT @Database=Coalesce(ParseName(@Tablespec,3),Db_Name())
	IF @table IS NULL OR @schema IS NULL OR @database IS NULL
		RAISERROR  ('{"error":"must have the table details"}',16,1)
           
DECLARE @SourceCode NVARCHAR(255)=
  'SELECT * FROM '+QuoteName(@database)+ '.'+ QuoteName(@Schema)+'.'+QuoteName(@table)

SELECT @jsonschema= 
  (SELECT 
    'https://mml.uk/jsonSchema/'+@table+'.json' AS id,--just a unique reference to a real place
    'http://json-schema.org/draft-04/schema#' AS [schema],--the minimum standard you want to use
    'Array (rows) within an array (table) of'+@Schema+'.'+@table AS description,
    'array' AS type, 'array' AS [items.type],
    (
    SELECT  
      f.name, --the individual columns as an array of objects with standard and custom fields
      CASE WHEN f.is_nullable = 1 THEN Json_Query('["null","'+f.type+'"]') -- must be array!
      ELSE  Json_Query('["'+f.type+'"]') END AS [type],--must be an array!
      f.SQLtype, f.is_nullable, Coalesce(EP.value,'') AS description
    FROM
      (--the basic columns we need. (the type is used more than once in the outer query) 
      SELECT r.name, r.system_type_name AS sqltype, r.source_column, r.is_nullable,
             CASE WHEN r.system_type_id IN (58,52,56,58,59,60,62,106,108,122,127) THEN 'number' 
               WHEN system_type_id =104 THEN 'boolean' ELSE 'string' END AS type,
             Object_Id(r.source_database + '.' + r.source_schema + '.' + r.source_table) 
              AS table_id
        FROM sys.dm_exec_describe_first_result_set
               (@SourceCode, NULL, 1) AS r
      ) AS f
    LEFT OUTER  JOIN sys.extended_properties AS EP -- to get the extended properties
      ON EP.major_id = f.table_id
       AND EP.minor_id = ColumnProperty(f.table_id, f.source_column, 'ColumnId')
       AND EP.name = 'MS_Description'
       AND EP.class = 1
    FOR JSON PATH
  ) AS [items.items]
   FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
	IF(IsJson(@jsonschema)=0) 
	RAISERROR ('invalid schema "%s"',16,1,@jsonSchema)
	IF @jsonschema IS NULL RAISERROR ('Null schema',16,1)
GO

/*
USE Adventureworks2016
DECLARE @ourPath sysname = 'C:\data\RawData\JsonSchema\AdventureWorks\';
Declare @command NVARCHAR(4000)= '
print ''Creating JSON file for ?''
DECLARE @Json NVARCHAR(MAX)
EXECUTE #CreateJSONArrayInArraySchemaFromTable @TableSpec=''?'',@JSONSchema=@json OUTPUT
CREATE TABLE ##myTemp (Bulkcol nvarchar(MAX))
INSERT INTO ##myTemp (Bulkcol) SELECT @JSON
print ''Writing out ?''
EXECUTE xp_cmdshell ''bcp ##myTemp out '+@ourPath+'?.JSON -c -C 65001 -T''
DROP TABLE ##myTemp'
EXECUTE sp_msforeachtable @command
*/
GO














