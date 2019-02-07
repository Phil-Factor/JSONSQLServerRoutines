CREATE OR ALTER PROCEDURE #ArrayInArrayJsonDataFromTable
  /**
Summary: >
  This gets the JSON data from a query or table into 
  Array-in-Array JSON Format
Author: phil factor
Date: 26/10/2018

Examples: >

  - use Adventureworks2016
    DECLARE @Json NVARCHAR(MAX)
    EXECUTE #ArrayInArrayJsonDataFromTable
      @query = 'Select * from person.addresstype;',
    @JSONData=@json OUTPUT
    PRINT @Json

  - use Adventureworks2016
    DECLARE @Json NVARCHAR(MAX)
    EXECUTE #ArrayInArrayJsonDataFromTable
      @query = '
    SELECT AccountNumber, PersonType, Title, FirstName, MiddleName, LastName,
      Suffix, AddressLine1, AddressLine2, City, PostalCode, Name
    FROM Sales.Customer
      INNER JOIN Person.Person
        ON Customer.PersonID = Person.BusinessEntityID
      INNER JOIN Person.BusinessEntityAddress
        ON Person.BusinessEntityID = BusinessEntityAddress.BusinessEntityID
      INNER JOIN Person.Address
        ON BusinessEntityAddress.AddressID = Address.AddressID
      INNER JOIN Person.AddressType
        ON BusinessEntityAddress.AddressTypeID = AddressType.AddressTypeID ;',
    @JSONData=@json OUTPUT
    PRINT @Json


  - use Adventureworks2016
    DECLARE @Json NVARCHAR(MAX)
    EXECUTE #ArrayInArrayJsonDataFromTable
      @database='Adventureworks2016', 
      @Schema ='person', 
      @table= 'PersonPhone',
      @JSONData=@json OUTPUT
    PRINT @Json

  - DECLARE @Json NVARCHAR(MAX)
    EXECUTE #ArrayInArrayJsonDataFromTable 
      @TableSpec='Adventureworks2016.[production].[document]',
      @JSONData=@json OUTPUT
    PRINT @Json
Returns: >
  The JSON data

**/
  (@database sysname = NULL, @Schema sysname = NULL, @table sysname = NULL,
  @Tablespec sysname = NULL, --this means
  @Query NVARCHAR(MAX) = NULL, @jsonData NVARCHAR(MAX) OUTPUT
  )
AS
  BEGIN
    DECLARE @SourceCode NVARCHAR(4000);
    IF @database IS NULL SELECT @database =
Coalesce(ParseName(@Tablespec, 3), Db_Name());
    IF @Query IS NULL
      BEGIN
        IF Coalesce(@table, @Tablespec) IS NULL
        OR Coalesce(@Schema, @Tablespec) IS NULL
          RAISERROR('{"error":"must have the table details"}', 16, 1);

        IF @table IS NULL SELECT @table = ParseName(@Tablespec, 1);
        IF @Schema IS NULL SELECT @Schema = ParseName(@Tablespec, 2);
        IF @table IS NULL OR @Schema IS NULL OR @database IS NULL
          RAISERROR('{"error":"must have the table details"}', 16, 1);
        SELECT @SourceCode =
          N'USE ' + @database + N'; SELECT * FROM ' + QuoteName(@database)
          + N'.' + QuoteName(@Schema) + N'.' + QuoteName(@table);
      END;
    ELSE BEGIN
SELECT @SourceCode = N'USE ' + @database + N';' + @Query;
      END;
    DECLARE @list NVARCHAR(4000);
    DECLARE @AllErrors NVARCHAR(4000);
    DECLARE @params NVARCHAR(MAX);
-- SQL Prompt formatting off
 SELECT @params='''[''+'
   +String_Agg(
      CASE
   --hierarchyid, geometry,and geography types  can be coerced. 
		WHEN system_type_id IN (240) 
		  THEN 'Coalesce(''"''+convert(nvarchar(max),' + QuoteName(name) + ')+''"'',''null'')'
		--text and ntext
		WHEN system_type_id IN (35,99)   
		  THEN 'Coalesce(''"''+convert(nvarchar(max),' + QuoteName(name) + ')+''"'',''null'')'
		--image varbinary
		WHEN system_type_id IN (34,165)  
		  THEN 'Coalesce(''"''+convert(nvarchar(max),' + QuoteName(name) + ',2)+''"'',''null'')'
		--dates
		--WHEN r.system_type_id IN (165)  THEN 'Coalesce(''"''+convert(varbinary(max),' + QuoteName(name) + ')+''"'',''null'')'
		WHEN r.system_type_id IN (40,41,42,43,58,61) 
		  THEN 'Coalesce(''"''+convert(nvarchar(max),'+QuoteName(name)+',126)+''"'',''null'')' 
		--numbers
		WHEN r.system_type_id IN (48,52,56,59,60,62,106,108,122,127) 
		  THEN 'Coalesce(convert(nvarchar(max),'+QuoteName(name)+'),''null'')' 
		--uniqueIdentifier
		WHEN system_type_id IN (36) 
		  THEN 'Coalesce(''"''+convert(nvarchar(max),' + QuoteName(name) + ')+''"'',''null'')'
		--bit
		WHEN system_type_id =104 
		  THEN 'Coalesce(case when '+QuoteName(name)+ '>0 then ''true'' else ''false'' end,''null'') '
		--xml
		WHEN system_type_id = 241 
		  THEN 'Coalesce(''"''+String_Escape(convert(nvarchar(max),'+QuoteName(name)+'),''json'')+''"'',''null'')' 
		ELSE 'Coalesce(''"''+String_Escape('+QuoteName(name)+',''json'') + ''"'',''null'')' END,'+'', ''+'
	  ) +'+'']''',
	  @list=String_Agg(QuoteName(name),', '),
	  @allErrors=String_Agg([error_message],', ')
	FROM sys.dm_exec_describe_first_result_set(@SourceCode, NULL, 1)r WHERE Coalesce(is_hidden,0)=0 
  
-- SQL Prompt formatting on
    DECLARE @expression NVARCHAR(4000);
    IF @params IS NULL
      BEGIN
        RAISERROR( 'Source Code %s couldn''t be executed because %s',16,1,@SourceCode, @AllErrors);
      END;
    IF @Query IS NULL
      BEGIN
        SELECT @expression =
          N'
USE ' +   @database + N'
Select @TheData= ''[''+String_Agg(' + @params + N','','')+'']''
FROM ' +  QuoteName(@database) + N'.' + QuoteName(@Schema) + N'.'
          + QuoteName(@table) + N';';
      END;
    ELSE
      BEGIN --take out any trailing semicolon
        SELECT @Query =
          CASE WHEN Lastsemi < LastText 
		  THEN Left(query, Len(query + ';' COLLATE SQL_Latin1_General_CP1_CI_AI) - Lastsemi - 1)
		  ELSE query END
          FROM
            (
            SELECT query,
              PatIndex
			    (
                SemicolonWildcard,
                  Reverse(';' + query COLLATE SQL_Latin1_General_CP1_CI_AI)  
				  COLLATE SQL_Latin1_General_CP1_CI_AI
                 ) AS Lastsemi,
              PatIndex(
                sqltextWildcard, 
				Reverse(query) COLLATE SQL_Latin1_General_CP1_CI_AI) AS LastText
              FROM
                (
                SELECT @Query AS query, '%;%' AS SemicolonWildcard,
                  '%[A-Z1-0_-]%' AS sqltextWildcard
                ) AS f
            ) AS g;
        SELECT @expression =
          N'USE ' + @database + N';
Select @TheData= ''[''+String_Agg(' + @params + N','','')+'']''
FROM ('                      + @Query + N')f(' + @list + N')';
      END;
    EXECUTE sp_executesql @expression, N'@TheData nvarchar(max) output',
@TheData = @jsonData OUTPUT;
    IF IsJson(@jsonData) = 0 RAISERROR(
'{"Table %s did not produce valid JSON"}', 16, 1, @table
);
  END;
GO

CREATE OR ALTER PROCEDURE #SaveExtendedJsonDataFromTable
  /**
Summary: >
  This gets the Extended JSON data from a table. You can specify
  it either by the database.schema.table 'tablespec, or do it
  individually.
Author: phil factor
Date: 04/02/2019

Examples: >
  USE pubs
  DECLARE @Json NVARCHAR(MAX)
  EXECUTE #SaveExtendedJsonDataFromTable 
     @database='pubs', 
	 @Schema ='dbo', 
	 @table= 'jobs',
	 @JSONData=@json OUTPUT
  PRINT @Json
Returns: >
  The JSON data
**/
  (@database sysname = NULL, @Schema sysname = NULL, @table sysname = NULL,
  @tableSpec sysname,  @jsonData NVARCHAR(MAX) OUTPUT
  )
AS
  BEGIN
    DECLARE @Data NVARCHAR(MAX);
    IF Coalesce(@table, @Tablespec) IS NULL
    OR Coalesce(@Schema, @Tablespec) IS NULL
      RAISERROR('{"error":"must have the table details"}', 16, 1);

    IF @table IS NULL SELECT @table = ParseName(@Tablespec, 1);
    IF @Schema IS NULL SELECT @Schema = ParseName(@Tablespec, 2);
    IF @database IS NULL 
	  SELECT @database = Coalesce(ParseName(@Tablespec, 3), Db_Name());
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
                      173-- binary 
                    ) 
                  --THEN  name + ' as "' + name + '.$binary.hex", ''80'' as "' + name + '.$binary.subType"'
                    THEN  name --I gave up. Extended json binary form is just awful
                    WHEN system_type_id = 34 THEN --image
                      'convert(varbinary(max),' + name + ') as "' + name + '"'
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
	PRINT @Expression
    EXECUTE sp_executesql @expression, N'@TheData nvarchar(max) output',
@TheData = @jsonData OUTPUT;
  END;
GO

CREATE OR ALTER PROCEDURE #SaveJsonDataFromTable
  /**
Summary: >
  This gets the JSON data from a table 
Author: phil factor
Date: 26/10/2018

Examples: >
  USE bigpubs
  DECLARE @Json NVARCHAR(MAX)
  EXECUTE #SaveJsonDataFromTable 
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
    IF @database IS NULL SELECT @database = Coalesce(ParseName(@Tablespec, 3),Db_Name());
    IF @table IS NULL OR @Schema IS NULL OR @database IS NULL
      RAISERROR('{"error":"must have the table details"}', 16, 1);

    DECLARE @SourceCode NVARCHAR(255) =
              (
              SELECT 'SELECT * FROM ' + QuoteName(@database) + '.'
                     + QuoteName(@Schema) + '.' + QuoteName(@table)
              );


    DECLARE @params NVARCHAR(MAX) =
              (
              SELECT 
			    String_Agg(
                  CASE WHEN user_type_id IN (128, 129, 130) THEN
                    'convert(nvarchar(100),' + name
                    + ') as "' + name + '"'
                  --hierarchyid (128) geometry (130) and geography types (129) can be coerced. 
                  WHEN user_type_id IN (35) THEN
                    'convert(varchar(max),' + name + ') as "'
                    + name + '"'
                  WHEN user_type_id IN (99) THEN
                    'convert(nvarchar(max),' + name + ') as "'
                    + name + '"'
                  WHEN user_type_id IN (34) THEN
                    'convert(varbinary(max),' + name
                    + ') as "' + name + '"' ELSE
                                            QuoteName(name) END, ', ' )
                FROM sys.dm_exec_describe_first_result_set(@SourceCode, NULL, 1)
              );
    DECLARE @expression NVARCHAR(800) =
      '
USE ' + @database + '
SELECT @TheData=(SELECT ' + @params + ' FROM ' + QuoteName(@database) + '.'
      + QuoteName(@Schema) + '.' + QuoteName(@table)
      + ' FOR JSON auto, INCLUDE_NULL_VALUES)';
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
go
/* start of timed run */
DECLARE @log TABLE 
  (TheOrder INT IDENTITY(1,1), 
  WhatHappened varchar(200),
  WHENItDid  Datetime2 DEFAULT GETDATE())
USE adventureworks2016
----start of timing
INSERT INTO @log(WhatHappened) SELECT 'Starting Writing out every table'
--place at the start
DECLARE @ourPath9 sysname = 'C:\Data\RawData\AdventureWorks\XML\';
Declare @command9 NVARCHAR(4000)= 
'EXEC xp_cmdshell ''bcp "SELECT * FROM ? FOR XML AUTO"  queryout "'
     +@ourPath9+'?.xml" -S '+@@Servername+' -T -c -C 65001 -t'', NO_OUTPUT;'
EXECUTE sp_msforeachtable @command9
INSERT INTO @log(WhatHappened) 
    SELECT 'Writing out every table as XML  took '
    --log the time taken to get to this point
/* first lets try using JSON array--in-array format */
DECLARE @ourPath1 sysname = 'C:\Data\RawData\AdventureWorks\JSONArrayInArray\';
Declare @command1 NVARCHAR(4000)= '
DECLARE @Json NVARCHAR(MAX)
EXECUTE #ArrayInArrayJsonDataFromTable @TableSpec=''?'',@JSONData=@json OUTPUT
CREATE TABLE ##myTemp (Bulkcol nvarchar(MAX))
INSERT INTO ##myTemp (Bulkcol) SELECT @JSON
EXECUTE xp_cmdshell ''bcp ##myTemp out "'+@ourPath1
     +'?.JSON" -c -C 65001 -S '+@@Servername+' -T '', NO_OUTPUT;
DROP TABLE ##myTemp'
EXECUTE sp_msforeachtable @command1
INSERT INTO @log(WhatHappened) 
SELECT 'Writing out every table as Array-in-Array JSON took '
--log the time taken to get to this point
DECLARE @ourPath2 sysname = 'C:\Data\RawData\AdventureWorks\JSONObjectInArray\';
DECLARE @command2 NVARCHAR(4000)= '
DECLARE @Json NVARCHAR(MAX)
EXECUTE #SaveJsonDataFromTable @TableSpec=''?'',@JSONData=@json OUTPUT
CREATE TABLE ##myTemp (Bulkcol nvarchar(MAX))
INSERT INTO ##myTemp (Bulkcol) SELECT @JSON
EXECUTE xp_cmdshell ''bcp ##myTemp out '+@ourPath2
    +'?.JSON -c -C 65001 -S '+@@Servername+' -T '', NO_OUTPUT;
DROP TABLE ##myTemp'
EXECUTE sp_msforeachtable @command2
INSERT INTO @log(WhatHappened) 
SELECT 'Writing out every table as Object-in-Array JSON took '
--log the time taken to get to this point
DECLARE @ourPath3 sysname = 'C:\Data\RawData\AdventureWorks\TabDelimited\';
DECLARE @Database3 sysname = Db_Name(); --over-ride this if you need to.
DECLARE @command3 NVARCHAR(4000)= '
EXECUTE xp_cmdshell ''bcp  ?  out '+@ourPath3+'?.Tab -c -C 65001 -d'
    +@Database3+' -S '+@@Servername+' -T '', NO_OUTPUT;'
EXECUTE sp_msforeachtable @command3
INSERT INTO @log(WhatHappened) 
SELECT 'Writing out every table as tab-delimited BCP took '
--log the time taken to get to this point
DECLARE @ourPath4 sysname = 'C:\Data\RawData\AdventureWorks\NativeBCP\';
DECLARE @Database4 sysname = Db_Name(); --over-ride this if you need to.
DECLARE @command4 NVARCHAR(4000)= '
EXECUTE xp_cmdshell ''bcp  ?  out '+@ourPath4+'?.data -N -d'
    +@Database4+' -S '+@@Servername+' -T '', NO_OUTPUT;'
EXECUTE sp_msforeachtable @command4
INSERT INTO @log(WhatHappened) 
SELECT 'Writing out every table as native BCP took '
--log the time taken to get to this point
DECLARE @ourPath6 sysname = 'C:\Data\RawData\AdventureWorks\CSV\';
DECLARE @Database6 sysname = Db_Name(); --over-ride this if you need to.
DECLARE @command6 NVARCHAR(4000)= '
EXECUTE xp_cmdshell ''sqlcmd  -d '
    +@Database6+' -u -E -h -1 -s, -W -Q "set nocount on; SELECT * FROM ?" -S '
    +@@Servername+' -o '+@ourPath6++'?.CSV'', NO_OUTPUT;'
EXECUTE sp_msforeachtable @command6
INSERT INTO @log(WhatHappened) 
SELECT 'Writing out every table as SQLCMD comedy-limited took '
--log the time taken to get to this point
DECLARE @ourPath7 sysname =  'C:\Data\RawData\AdventureWorks\ExtendedJSON\';
Declare @command7 NVARCHAR(4000)= '
DECLARE @Json NVARCHAR(MAX)
EXECUTE #SaveExtendedJsonDataFromTable @TableSpec=''?'',@JSONData=@json OUTPUT
CREATE TABLE ##myTemp (Bulkcol nvarchar(MAX))
INSERT INTO ##myTemp (Bulkcol) SELECT @JSON
EXECUTE xp_cmdshell ''bcp ##myTemp out "'+@ourPath7
     +'?.JSON" -c -C 65001 -S '+@@Servername+' -T '', NO_OUTPUT;
DROP TABLE ##myTemp'
EXECUTE sp_msforeachtable @command7
INSERT INTO @log(WhatHappened) 
SELECT 'Writing out every table as Extended JSON took '

--log the time taken to get to this point
SELECT ending.whathappened, 
    DateDiff(ms, starting.whenItDid,ending.WhenItDid) AS ms 
FROM @log starting
INNER JOIN @log ending ON ending.theorder=starting.TheOrder+1
UNION all
SELECT 'Total', DateDiff(ms,Min(WhenItDid),Max(WhenItDid))  
FROM @log 
ORDER BY ms asc
--list out all the timings
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