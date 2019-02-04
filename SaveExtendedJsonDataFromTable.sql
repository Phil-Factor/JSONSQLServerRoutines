CREATE OR ALTER PROCEDURE #SaveExtendedJsonDataFromTable
  /**
Summary: >
  This gets the JSON data from a table 
Author: phil factor
Date: 26/10/2018

Examples: >
  USE bigpubs
  DECLARE @Json NVARCHAR(MAX)
  EXECUTE #SaveExtendedJsonDataFromTable 
     @database='pubs', 
	 @Schema ='dbo', 
	 @table= 'authors',
	 @JSONData=@json OUTPUT
  PRINT @Json
Returns: >
  The JSON data
**/
  (@database sysname = NULL, @Schema sysname = NULL, @table sysname = NULL,
  @Tablespec sysname = NULL, @jsonData NVARCHAR(MAX) OUTPUT
  )
AS
  BEGIN
    DECLARE @Data NVARCHAR(MAX);
    IF Coalesce(@table, @Tablespec) IS NULL
    OR Coalesce(@Schema, @Tablespec) IS NULL
      RAISERROR('{"error":"must have the table details"}', 16, 1);

    IF @table IS NULL SELECT @table = ParseName(@Tablespec, 1);
    IF @Schema IS NULL SELECT @Schema = ParseName(@Tablespec, 2);
    IF @database IS NULL SELECT @database =
Coalesce(ParseName(@Tablespec, 3), Db_Name());
    IF @table IS NULL OR @Schema IS NULL OR @database IS NULL
      RAISERROR('{"error":"must have the table details"}', 16, 1);

    DECLARE @SourceCode NVARCHAR(255) =
              (
              SELECT 'SELECT * FROM ' + QuoteName(@database) + '.'
                     + QuoteName(@Schema) + '.' + QuoteName(@table)
              );

DECLARE @a_unique_key bit 
DECLARE @HowManyUniqueKeys INT
SELECT @HowManyUniqueKeys= Sum(Convert(INT,is_part_of_unique_key)) 
	  FROM sys.dm_exec_describe_first_result_set(@SourceCode, NULL, 1)
SELECT @a_unique_key= CASE WHEN @HowManyUniqueKeys = 1 THEN 1 ELSE 0 END
 	
    DECLARE @params NVARCHAR(MAX);

    SELECT @params =
      String_Agg(
                  CASE WHEN system_type_id IN
                       ( 35, -- text
                         99, -- ntext
                         98, -- sql_variant
                         167, -- varchar
                         231, -- nvarchar
                         239, -- nchar
                         175, -- char
                         36, -- uniqueidentifier
                         59, -- real
                         62, -- float
                         104, -- bit
                         241
                       ) -- xml
                  THEN
				  	CASE WHEN @a_unique_key=1 AND is_part_of_unique_key =1  THEN name+ ' as "_id", '
					ELSE '' END +QuoteName(name)
                    WHEN user_type_id IN (128, 129, 130) THEN
                      'convert(nvarchar(100),' + name + ') as "' + name + '"'
                    --hierarchyid (128) geometry (130) and geography types (129) can be coerced. 
                    --------binary
                    WHEN system_type_id IN
                    ( 165, -- varbinary
                      173
                    ) -- binary 
                  THEN               name + ' as "' + name + '.$binary.base64", ''80'' as "' + name + '.$binary.subType"'
                    WHEN system_type_id = 34 THEN --image
                      'convert(varbinary(max),' + name + ') as "' + name
                      + '.$binary.base64"'
                    WHEN system_type_id IN (35) THEN --35 is text
                      'convert(varchar(max),' + name + ') as "' + name + '"'
                    WHEN system_type_id IN (99) THEN --ntext
                      'convert(nvarchar(max),' + name + ') as "' + name + '"'
                    --------numberInt
                    WHEN system_type_id IN
                    ( 48, -- tinyint
                      56, -- int
                      52 -- smallint
                    ) 
                  THEN
				    CASE WHEN @a_unique_key=1 AND is_part_of_unique_key =1 THEN name+ ' as "_id", '
					ELSE '' END +
					 'convert(varchar(50),' + name + ') as "' + name + '.$numberInt"'
                    --------numberLong
                    WHEN system_type_id = 127 -- bigint
                  THEN
				    CASE WHEN @a_unique_key=1 AND is_part_of_unique_key =1 THEN name+ ' as "_id", '
					ELSE '' END +
					 'convert(varchar(50),' + name + ') as "' + name + '.$numberLong"'
                    --------date
                    WHEN system_type_id IN
                    ( 40, -- date
                      41, -- time
                      42, -- datetime2
                      43, -- datetimeoffset
                      58, -- smalldatetime
                      61, -- datetime
                      189
                    ) -- timestamp
                  THEN
                      'convert(datetimeoffset,convert(datetime2(0),' + name + ')) as "' + name + '.$date"'
                    -------numberDecimal
                    WHEN system_type_id IN
                    ( 106, -- decimal
                      108, -- numeric
                      122, -- smallmoney
                      60
                    ) -- money					
                  THEN
                    'convert(varchar(50),' + name + ') as "' + name + '.$numberDecimal"' 
				  ELSE QuoteName(name) 
			      END,
                  ', '
                )
      FROM sys.dm_exec_describe_first_result_set(@SourceCode, NULL, 1);
    DECLARE @expression NVARCHAR(max) =
      '
USE ' + @database + '
SELECT @TheData=(SELECT ' + @params + ' FROM ' + QuoteName(@database) + '.'
      + QuoteName(@Schema) + '.' + QuoteName(@table)
      + ' FOR JSON PATH)';
	--PRINT @Expression
    EXECUTE sp_executesql @expression, N'@TheData nvarchar(max) output',
@TheData = @jsonData OUTPUT;
  END;
GO


/* lets just check the config and make sure that xp_cmdshell is enabled. */
DECLARE @Settings TABLE (
    name sysname, minimum INT, Maximum INT, config_value INT, run_value INT);
INSERT INTO @Settings (name, minimum, Maximum, config_value, run_value)
  EXECUTE sp_configure @configname = 'show advanced options';
IF NOT EXISTS (
  SELECT * FROM @Settings WHERE name = 'show advanced options'
  AND run_value = 1)
  BEGIN
    EXECUTE sp_configure 'show advanced options', 1;
    RECONFIGURE;
  END;
INSERT INTO @Settings (name, minimum, Maximum, config_value, run_value)
  EXECUTE sp_configure @configname = 'xp_cmdshell';
IF NOT EXISTS (
  SELECT * FROM @Settings WHERE name = 'xp_cmdshell'
  AND run_value = 1)
  BEGIN
    EXECUTE sp_configure 'xp_cmdshell', 1;
    RECONFIGURE;
  END;
GO

USE adventureworks2016
DECLARE @ourPath1 sysname = 'C:\Data\RawData\AdventureWorks\ExtendedJSON\';
Declare @command1 NVARCHAR(4000)= '
DECLARE @Json NVARCHAR(MAX)
EXECUTE #SaveExtendedJsonDataFromTable @TableSpec=''?'',@JSONData=@json OUTPUT
CREATE TABLE ##myTemp (Bulkcol nvarchar(MAX))
INSERT INTO ##myTemp (Bulkcol) SELECT @JSON
EXECUTE xp_cmdshell ''bcp ##myTemp out "'+@ourPath1
     +'?.JSON" -c -C 65001 -S '+@@Servername+' -T '', NO_OUTPUT;
DROP TABLE ##myTemp'
EXECUTE sp_msforeachtable @command1


go
DECLARE @Settings TABLE 
    (name sysname, minimum INT, Maximum INT, config_value INT, run_value INT);
INSERT INTO @Settings (name, minimum, Maximum, config_value, run_value)
  EXECUTE sp_configure @configname = 'show advanced options';
IF NOT EXISTS (
  SELECT * FROM @Settings WHERE name = 'show advanced options'
  AND run_value = 1)
  BEGIN
    EXECUTE sp_configure 'show advanced options', 1;
    RECONFIGURE;
  END;
INSERT INTO @Settings (name, minimum, Maximum, config_value, run_value)
  EXECUTE sp_configure @configname = 'xp_cmdshell';
IF NOT EXISTS (
  SELECT * FROM @Settings WHERE name = 'xp_cmdshell'
  AND run_value = 0)
  BEGIN
    EXECUTE sp_configure 'xp_cmdshell', 0;
    RECONFIGURE;
  END; 

 -- SELECT Convert(CHAR(19),ModifiedDate,127), Convert(varCHAR(80),Convert(DATETIMEOFFSET,ModifiedDate),127) FROM [HumanResources].[JobCandidate]
  --SELECT convert(datetime2(0),modifiedDate) FROM [HumanResources].[JobCandidate]
