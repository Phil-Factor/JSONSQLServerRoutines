
DROP PROCEDURE IF exists #SaveMergeStatementFromTable
GO
CREATE PROCEDURE #SaveMergeStatementFromTable 
  /**
Summary: >
  This creates a merge statement, creating a table source from a multi-row 
  VALUES statement, and merging it with the table whose name you provide.
  This MERGE statement can then be executed. Beware
  that this is only really practicable for small tables, because the 
  VALUES statement degrades with scale.
  The source is specified either by the database.schema.table 'tablespec, 
  or by doing tablename, schema and database individually.
  
Author: phil factor
Date: 11/11/2019

Examples: >
 - DECLARE @TheStatement NVARCHAR(MAX)
   EXECUTE #SaveMergeStatementFromTable 
     @database='pubs', 
   @Schema ='dbo', 
   @table= 'jobs',
   @Statement=@TheStatement OUTPUT,
   @DontSpecifyTheDatabase=1
   PRINT @TheStatement
 - DECLARE @TheStatement NVARCHAR(MAX)
   EXECUTE #SaveMergeStatementFromTable 
     @tablespec='Adventureworks2016.[HumanResources].[Department]',
   @Statement=@TheStatement OUTPUT;
   PRINT @TheStatement
 - DECLARE @TheStatement NVARCHAR(MAX)
   EXECUTE #SaveMergeStatementFromTable 
     @tablespec='Adventureworks2016.[Person].[vAdditionalContactInfo]',
   @Statement=@TheStatement OUTPUT;
   PRINT @TheStatement
 - use Adventureworks2016
   DECLARE @TheStatement  NVARCHAR(MAX)
   EXECUTE #SaveMergeStatementFromTable 
      @query = '
    
    SELECT into #temp identity(), AccountNumber, PersonType, Title, FirstName, MiddleName, LastName,
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
    @Statement  =@TheStatement  OUTPUT
    PRINT @TheStatement  
Returns: >
  The Select statement using the multirow Values clause as a derived table.
**/
  (@database sysname = NULL, --if not providing a table spec, then use this for the database
  @Schema sysname = NULL,--if not providing a table spec, then use this for the schema
   @table sysname = NULL,--if not providing a table spec, then use this for the table
  @tableSpec sysname = NULL , --the full three-part table spec database.schema.table
  @Query NVARCHAR(4000) = null,  --if you are doing this for a query rather than a table
  @Statement   NVARCHAR(MAX) OUTPUT,--the resulting sql statement
  @DestinationTable sysname=NULL,--the name of the destination table if you specify a query etc 
  @DestinationDatabase sysname=NULL, --the destination database if different name from the source
  @PrimaryKeys NVARCHAR(100)=NULL, --a list of the primary keys if you use a query as a source
  @DontSpecifyTheDatabase bit=NULL --set this if you wish to avoid the destination database name
   )
AS
  BEGIN
    DECLARE @Source Sysname, @TheFinalQuery NVARCHAR(4000),
	@SelectStarFrom NVARCHAR(4000), @ItHasAnIdentityColumn int;
	DECLARE @compatibility_level INT = (SELECT compatibility_level FROM sys.databases WHERE name = Db_Name())
	IF (@compatibility_level <130)
		RAISERROR ('compatibility LEVEL IS ONLY %d AND should be AT least 130',16,1, @compatibility_level)
    IF @database IS NULL 
    SELECT @database = Coalesce(ParseName(@Tablespec, 3), Db_Name());
    IF @Query IS NULL --we always use a query. If you don't provide it we construct it
      BEGIN
        IF Coalesce(@table, @Tablespec) IS NULL
        OR Coalesce(@Schema, @Tablespec) IS NULL
          RAISERROR('{"error":"must have the table details"}', 16, 1);

        IF @table IS NULL SELECT @table = ParseName(@Tablespec, 1);
        IF @Schema IS NULL SELECT @Schema = ParseName(@Tablespec, 2);
        IF @table IS NULL OR @Schema IS NULL OR @database IS NULL
          RAISERROR('{"error":"must have the table details"}', 16, 1);
    SELECT @source=QuoteName(@database)
          + N'.' + QuoteName(@Schema) + N'.' + QuoteName(@table);
    DECLARE @AllErrors NVARCHAR(4000);
    DECLARE @ColumnExpressions NVARCHAR(4000)
    SELECT 
	  @ColumnExpressions=
-- SQL Prompt formatting off
        String_Agg(
          CASE
           --hierarchyid, geometry,and geography types  can be coerced. 
            WHEN system_type_id IN (240) 
             THEN 'convert(nvarchar(max),' + QuoteName(name) + ') AS "'+name+'"'
           --text and ntext
            WHEN system_type_id IN (35,99)   
              THEN 'convert(nvarchar(max),' + QuoteName(name)  + ')AS "'+name+'"'
            --image varbinary snd uniqueIdentifier
            WHEN system_type_id IN (36,165)  
              THEN 'convert(nvarchar(max),' + QuoteName(name) + ')AS "'+name+'"'
            WHEN system_type_id = 34 --image type
			THEN  'cast(' + QuoteName(name) + ' as varbinary(max)) AS "'+name+'"'
           --xml
           --WHEN system_type_id = 241 
          ELSE QuoteName(name) END,', ') WITHIN GROUP ( ORDER BY column_ordinal ASC ),
-- SQL Prompt formatting on
      --@list=String_Agg(QuoteName(name),', '),
       @allErrors=String_Agg([error_message],', ')
--SELECT String_Agg(name,',')     WITHIN GROUP ( ORDER BY column_ordinal ASC ) 
    FROM sys.dm_exec_describe_first_result_set((SELECT 'Select * from '+@source), NULL, 1)r 
		WHERE Coalesce(is_hidden,0)=0  AND Coalesce(is_computed_column,0)=0

    IF @ColumnExpressions IS NULL
        RAISERROR( 'Source Code %s couldn''t be executed because %s',16,1, '' , @AllErrors);
    SELECT @TheFinalQuery ='SELECT '+ @ColumnExpressions+' FROM ' +@source,
           @SelectStarFrom = 'SELECT * FROM '+@source
    IF @DestinationDatabase IS NULL
      SELECT @DestinationTable=COALESCE(@DestinationTable,@source)
        ELSE
      SELECT @DestinationTable=
        Replace(COALESCE(@DestinationTable,@source),@database,@DestinationDatabase)
      END;
    ELSE 
    BEGIN--you are supplying a query
    --IF you ARE suplying a query then it must not have the final ';'
      SELECT @TheFinalQuery = --so strip the semicolon
        CASE WhereFinalSemicolonWas WHEN 0 THEN @Query
        ELSE Left(@Query,WhereFinalSemicolonWas-1) END
      FROM (VALUES (PatIndex('%; ',rtrim(@Query)
                  + ' ' COLLATE DATABASE_DEFAULT))
       )f(WhereFinalSemicolonWas)
    IF Coalesce(@DestinationTable,'') = '' COLLATE DATABASE_DEFAULT --if null or blank
      RAISERROR (
        'if you provide a query, you must also provide a "@destinationTable" table name',
        16,1)
	  SELECT @SelectStarFrom = @TheFinalQuery
      END;
	IF Coalesce(@DontSpecifyTheDatabase,0)<>0
		SELECT @DestinationTable=QuoteName(ParseName(@DestinationTable,2))+'.'+QuoteName(ParseName(@DestinationTable,1))
  DECLARE @ColumnList nvarchar(4000)
  select @ColumnList= string_agg(name,', ')
    FROM sys.dm_exec_describe_first_result_set(@SelectStarFrom , NULL, 1)
    WHERE Coalesce(is_hidden,0)=0 AND Coalesce(is_computed_column,0)=0
  if (@ColumnList is null) 
    RAISERROR ('The expression %s was not correct',16,1,@TheFinalQuery)
--is there a PK in the specified table or is the a specified PK??
  DECLARE @PK NVARCHAR(400)--the list of unique indexes in the table
  IF @PrimaryKeys IS NOT NULL --then a primary key spec has been provided
    SELECT @PK=String_Agg(
         'source.'+LTrim(value) COLLATE DATABASE_DEFAULT
         +' = target.'+LTrim(value) COLLATE DATABASE_DEFAULT,' AND '
         )
      FROM string_split(@PrimaryKeys COLLATE DATABASE_DEFAULT ,',')
  ELSE
    SELECT  @PK=String_Agg(
            'source.'+name COLLATE DATABASE_DEFAULT+' = '+'target.'
            +name COLLATE DATABASE_DEFAULT,' AND '
        ) 
      FROM sys.dm_exec_describe_first_result_set(@SelectStarFrom, NULL, 1)
        WHERE is_part_of_unique_key=1 
          AND  Coalesce(is_hidden,0)=0 AND Coalesce(is_computed_column,0)=0
  IF (@PK is null) 
    RAISERROR (
      'There seems to be no primary key produced from  "%s"',16,1,@SelectStarFrom)
-- now we have the ON conditions prepared for the merge statement
--is there an identity column in the query?
  SELECT @ItHasAnIdentityColumn = 
      CASE when EXISTS(
      SELECT 1 FROM sys.dm_exec_describe_first_result_set(@SelectStarFrom, NULL, 1
      )
    WHERE Coalesce(is_identity_column,0)=1) THEN 1 ELSE 0 end
--now we can create the SQL that will, it turn create the merge statement
  DECLARE @expression NVARCHAR(MAX)
  SELECT @expression=
    'Select @TheData=(Select '''
    +CASE when @table IS not NULL THEN 'PRINT ''''Ensuring that the "'+ @table+'" data is there''''' ELSE''''END
    +'
'
    +CASE WHEN @ItHasAnIdentityColumn=1 THEN '
SET IDENTITY_INSERT '+@DestinationTable+' ON;'
    ELSE '' END+'
MERGE INTO '+@DestinationTable+' AS target
  USING (VALUES ('' + String_Agg(ROW, ''),
('')    + '')
)source('+@ColumnList+')
ON '+@Pk+'
WHEN NOT MATCHED BY TARGET THEN
  INSERT ( '+@ColumnList+' )
  VALUES ( '+@ColumnList+' )
WHEN NOT MATCHED BY SOURCE THEN
  DELETE;
'
+CASE WHEN @ItHasAnIdentityColumn=1 THEN 'SET IDENTITY_INSERT '+@DestinationTable+' OFF;' ELSE '' END + '
IF @@ERROR <> 0 SET NOEXEC ON

''
  FROM
    (
    SELECT
      (
      SELECT 
      String_Agg
      (CASE type 
        WHEN 1 THEN '''''''' + replace(rtrim(value),'''''''','''''''''''') + ''''''''
            WHEN 2 THEN value
            WHEN 3 THEN
              CASE WHEN value = ''true'' THEN ''1'' ELSE ''0'' END
      ELSE ''null'' END,
           '', ''
          )
        FROM OpenJson(value)
      ) AS row
      FROM OpenJson(
      ('+@TheFinalQuery+' FOR JSON PATH, INCLUDE_NULL_VALUES)
    )
    ) AS f(row));'
  IF @expression IS NULL
    RAISERROR ('The expression could not be created', 16,1)  
    ELSE
    begin
    --now we create the SQL for the merge statement
    DECLARE @RowsInResult int
        EXECUTE sp_executesql @expression, N'@TheData nvarchar(max) output',
          @TheData = @Statement   OUTPUT;
 --it could be some sort of error or maybe an empty table   
  IF @Statement IS NULL
      BEGIN
      DECLARE @CountOfResultExpression NVARCHAR(4000),@RowsInData INT
      SELECT @Statement='',
      @CountOfResultExpression='SELECT @count= Count(*) FROM ('+@TheFinalQuery+')f',
      @RowsInData=0
      EXECUTE sp_ExecuteSQL @CountOfResultExpression,N'@count int output',
      @count = @RowsInData   OUTPUT;
            IF @RowsInData<>0
          RAISERROR ('No merge statement could be produced from "%s"', 16,1,@expression)  
      end
    END
  END
GO

