

CREATE OR ALTER PROCEDURE #ArrayInArrayJsonDataFromTable
  /**
Summary: >
  This gets the JSON data from a table in Array
Author: phil factor
Date: 26/10/2018

Examples: >
  - use Adventureworks2016
    DECLARE @Json NVARCHAR(MAX)
    EXECUTE #ArrayInArrayJsonDataFromTable
      @database='pubs', 
	  @Schema ='dbo', 
	  @table= 'authors',
	  @JSONData=@json OUTPUT
    PRINT @Json

  - DECLARE @Json NVARCHAR(MAX)
	EXECUTE #ArrayInArrayJsonDataFromTable @TableSpec='bigpubs.[dbo].[oldTitles]',@JSONData=@json OUTPUT
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

    DECLARE @params NVARCHAR(MAX) =(
      SELECT String_Agg(
        CASE
		 WHEN user_type_id IN (128, 129, 130) 
		   THEN'convert(nvarchar(100),' + name + ') as "' + name + '"'
          --hierarchyid (128) geometry (130) and geography types (129) can be coerced. 
         WHEN user_type_id IN (35) 
		   THEN 'convert(varchar(max),' + name + ') as "' + name + '"'
         WHEN user_type_id IN (99) 
		   THEN 'convert(nvarchar(max),' + name + ') as "' + name + '"'
         WHEN user_type_id IN (34) 
		   THEN 'convert(varbinary(max),' + name + ') as "' + name + '"'
		 ELSE QuoteName(name) END, ', ' )
      FROM sys.dm_exec_describe_first_result_set(@SourceCode, NULL, 1) );


DECLARE @expression NVARCHAR(800) =	'
USE ' + @database + '
SELECT @TheData=(SELECT ' + @params + ' FROM ' + QuoteName(@database) + '.'
      + QuoteName(@Schema) + '.' + QuoteName(@table)
      + ' FOR JSON auto, INCLUDE_NULL_VALUES)';
    EXECUTE sp_executesql @expression, N'@TheData nvarchar(max) output',
            @TheData = @Data OUTPUT;

SELECT @jsonData ='['+ String_Agg(f.EachLine,',')+']'
FROM 
  (SELECT '['+String_Agg (
     CASE WHEN shredded.type=1 
       THEN '"'+String_Escape(Coalesce(shredded.value,'null'),'json')+'"'
     ELSE Coalesce(shredded.value,'null') 
     END, ',') +']'
     AS TheValue
  FROM OpenJson(@data) f
   CROSS apply OpenJson(f.value) shredded
   GROUP BY f.[Key])f(EachLine)
  END;
GO





