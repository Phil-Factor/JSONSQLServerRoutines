CREATE OR ALTER PROCEDURE #SaveMultiRowSelectStatementFromTable 
  /**
Summary: >
  This gets a multirow derived table SELECT * from (VALUES)  statement from a table
  it either by the database.schema.table 'tablespec, or do it individually.
Author: phil factor
Date: 04/05/2019

Examples: >
 - USE pubs
   DECLARE @TheStatement NVARCHAR(MAX)
   EXECUTE #SaveMultiRowSelectStatementFromTable 
     @database='pubs', 
	 @Schema ='dbo', 
	 @table= 'jobs',
	 @Statement=@TheStatement OUTPUT,
	 @Destination='pubs.dbo.jobs'
   PRINT @TheStatement
 - use Adventureworks2016
    DECLARE @TheStatement  NVARCHAR(MAX)
    EXECUTE #SaveMultiRowSelectStatementFromTable
      @query = 'Select * from person.addresstype;',
    @Statement  =@TheStatement  OUTPUT
    PRINT @TheStatement
 - use Adventureworks2016
    DECLARE @TheStatement  NVARCHAR(MAX)
    EXECUTE #SaveMultiRowSelectStatementFromTable
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
    @Statement  =@TheStatement  OUTPUT
    PRINT @TheStatement	
Returns: >
  The Select statement using the multirow Values clause as a derived table.
**/
  (@database sysname = NULL, @Schema sysname = NULL, @table sysname = NULL,
  @tableSpec sysname = NULL , @Query NVARCHAR(4000) = null,  
  @Statement   NVARCHAR(MAX) OUTPUT,
  @Destination sysname=NULL
  )
AS
  BEGIN
    DECLARE @Finalquery NVARCHAR(4000);
    IF @database IS NULL 
	  SELECT @database = Coalesce(ParseName(@Tablespec, 3), Db_Name());
    IF @Query IS NULL
      BEGIN
        IF Coalesce(@table, @Tablespec) IS NULL
        OR Coalesce(@Schema, @Tablespec) IS NULL
          RAISERROR('{"error":"must have the table details"}', 16, 1);

        IF @table IS NULL SELECT @table = ParseName(@Tablespec, 1);
        IF @Schema IS NULL SELECT @Schema = ParseName(@Tablespec, 2);
        IF @table IS NULL OR @Schema IS NULL OR @database IS NULL
          RAISERROR('{"error":"must have the table details"}', 16, 1);
        SELECT @Finalquery ='SELECT * FROM ' + QuoteName(@database)
          + N'.' + QuoteName(@Schema) + N'.' + QuoteName(@table);
      END;
    ELSE 
	  BEGIN
	  	select @Finalquery = left(@Query,patindex('%; ',rtrim(@Query)+' ' COLLATE SQL_Latin1_General_CP1_CI_AI)-1)
      END;
 
Declare @Params nvarchar(4000)

      select @Params= string_agg(name,', ')
	  from sys.dm_exec_describe_first_result_set(@finalquery, NULL, 1)
	  WHERE Coalesce(is_hidden,0)=0
if (@Params is null) Raiserror ('The expression %s was not correct',16,1,@Finalquery)

Declare @expression NVARCHAR(MAX)
Select @expression='Select @TheData=(SELECT '''+
case when @Destination is not null then 'Insert into '+@Destination+' ('+@Params+')
  ' else '' end+'Select * from (VALUES ('' + String_Agg(ROW, ''),
('')    + ''))f(d'+@Params+')''
  FROM
    (
    SELECT
      (
      SELECT 
	    String_Agg
		  (CASE type 
		    WHEN 1 THEN '''''''' + replace(value,'''''''','''''''''''') + ''''''''
            WHEN 2 THEN value
            WHEN 3 THEN
              CASE WHEN value = ''true'' THEN ''1'' ELSE ''0'' END
		  ELSE ''null'' END,
           '', ''
          )
        FROM OpenJson(value)
      ) AS row
      FROM OpenJson(
	    ('+@Finalquery+' FOR JSON PATH, INCLUDE_NULL_VALUES)
	  )
    ) AS f(row));'
  --print @expression
    EXECUTE sp_executesql @expression, N'@TheData nvarchar(max) output',
@TheData = @Statement   OUTPUT;
  END
GO


