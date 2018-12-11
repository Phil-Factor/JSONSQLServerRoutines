CREATE OR ALTER PROCEDURE #ArrayInArrayJsonDataFromTable
  /**
Summary: >
  This gets the JSON data from a table into 
  Array-in-Array JSON Format
Author: phil factor
Date: 26/10/2018

Examples: >
  - use Adventureworks2016
    DECLARE @Json NVARCHAR(MAX)
    EXECUTE #ArrayInArrayJsonDataFromTable
      @database='Adventureworks2016', 
	  @Schema ='product', 
	  @table= 'authors',
	  @JSONData=@json OUTPUT
    PRINT @Json

  - DECLARE @Json NVARCHAR(MAX)
	EXECUTE #ArrayInArrayJsonDataFromTable @TableSpec='Adventureworks2016.[production].[document]',@JSONData=@json OUTPUT
    PRINT @Json
Returns: >
  The JSON data
**/
  (@database sysname = NULL, @Schema sysname = NULL, @table sysname = NULL,
  @Tablespec sysname = NULL, @jsonData NVARCHAR(MAX) OUTPUT
  )
AS
  BEGIN
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

    DECLARE @params NVARCHAR(MAX) =(
 SELECT '''[''+'
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
	  ) +'+'']''' AS query
	FROM sys.dm_exec_describe_first_result_set(@SourceCode, NULL, 1) r)
  DECLARE @expression NVARCHAR(4000) =	'
USE ' + @database + '
Select @TheData=(SELECT ''[''+String_Agg('+@params+','','')+'']''
FROM ' + QuoteName(@database) + '.'
      + QuoteName(@Schema) + '.' + QuoteName(@table)+');';
  EXECUTE sp_executesql @expression, N'@TheData nvarchar(max) output',
            @TheData = @JSONData OUTPUT;
			IF IsJson(@JSONData) = 0 RAISERROR('{"Table %s did not produce valid JSON"}', 16, 1, @table);
END
GO

