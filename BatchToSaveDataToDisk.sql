CREATE OR ALTER PROCEDURE  #CreateJSONSchemaFromTable
/**
Summary: >
  This creates a JSON schema from a table that
  matches the JSON you will get from doing a 
  classic FOR JSON select * statemenmt on the entire table

Author: phil factor
Date: 26/10/2018

Examples: >
  DECLARE @Json NVARCHAR(MAX)
  EXECUTE #CreateJSONSchemaFromTable @database='pubs', @Schema ='dbo', @table= 'authors',@JSONSchema=@json OUTPUT
  PRINT @Json
  SELECT @json=''
  EXECUTE #CreateJSONSchemaFromTable @TableSpec='pubs.dbo.authors',@JSONSchema=@json OUTPUT
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
		   IF @Database is NULL SELECT @Database=ParseName(@Tablespec,3)
		   IF @table IS NULL OR @schema IS NULL OR @database IS NULL
		      RAISERROR  ('{"error":"must have the table details"}',16,1)
           
           DECLARE @SourceCode NVARCHAR(255)=
           (SELECT 'SELECT * FROM '+QuoteName(@database)+ '.'+ QuoteName(@Schema)+'.'+QuoteName(@table))
           SELECT 
             @properties= String_Agg('
               "'+f.name+'": {"type":["'+Replace(type,' ','","')+'"],"sqltype":"'+sqltype+'", "columnNo":'+ Convert(VARCHAR(3), f.column_ordinal)
           	+', "nullable":'+Convert(CHAR(1),f.is_nullable)+', "Description":"'
               +String_Escape(Coalesce(Convert(NvARCHAR(875),EP.value),''),'json')+'"}',','),
             @NoColumns=Max(f.column_ordinal),
             @required=String_Agg('"'+f.Name+'"',',') 
             FROM
               ( --the basic columns we need. (the type is used more than once in the outer query) 
               SELECT 
           	  r.name, 
                 r.system_type_name  AS sqltype, 
                 r.source_column,
                 r.is_nullable,r.column_ordinal,
                 CASE WHEN r.system_type_id IN (48, 52, 56, 58, 59, 60, 62, 106, 108, 122, 127)  
           	    THEN 'number'
                   WHEN system_type_id = 104 THEN 'boolean' ELSE 'string' END
                 + CASE WHEN r.is_nullable = 1 THEN ' null' ELSE '' END AS type,
                 Object_Id(r.source_database + '.' + r.source_schema + '.' + r.source_table) AS table_id
                 FROM sys.dm_exec_describe_first_result_set
           	    (@sourcecode, NULL, 1) AS r
               ) AS f
               LEFT OUTER JOIN sys.extended_properties AS EP -- to get the extended properties
                 ON EP.major_id = f.table_id
                AND EP.minor_id = ColumnProperty(f.table_id, f.source_column, 'ColumnId')
                AND EP.name = 'MS_Description'
                AND EP.class = 1
           
           SELECT @JSONschema =
             Replace(
               Replace(
                Replace(
                 Replace(
                   Replace('{
  "$id": "https://mml.uk/jsonSchema/<-schema->-<-table->.json",
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "<-table->",
  "SQLtablename":"'+quotename(@schema)+'.'+quotename(@table)+'",
  "SQLschema":"<-schema->",
    "type": "array",
    "items": {
       "type": "object",
	   "required": [<-Required->],
       "maxProperties": <-MaxColumns->,
       "minProperties": <-MinColumns->,
       "properties":{'+@properties+'}
        }
   }', '<-minColumns->', Convert(VARCHAR(5),@NoColumns) COLLATE DATABASE_DEFAULT
           	         ) , '<-maxColumns->',Convert(VARCHAR(5),@NoColumns +1) COLLATE DATABASE_DEFAULT
           	         ) , '<-Required->',@required COLLATE DATABASE_DEFAULT
           		   ) ,'<-schema->',@Schema COLLATE DATABASE_DEFAULT
           	     ) ,'<-table->', @table COLLATE DATABASE_DEFAULT
                  );
           
           
           IF(IsJson(@jsonschema)=0) 
		    RAISERROR ('invalid schema "%s"',16,1,@jsonSchema)
           IF @jsonschema IS NULL RAISERROR ('Null schema',16,1)
GO

CREATE OR ALTER PROCEDURE #SaveJSONToFile
  @TheString NVARCHAR(MAX),  @Filename NVARCHAR(255),
  @Unicode INT=8 --0 for not unicode, 8 for utf8 and 16 for utf16
AS
  SET NOCOUNT ON
  DECLARE @MySpecialTempTable sysname, @Command NVARCHAR(4000) , @RESULT INT
 
--firstly we create a global temp table with a unique name
  SELECT  @MySpecialTempTable = '##temp'
       + CONVERT(VARCHAR(12), CONVERT(INT, RAND() * 1000000))
--then we create it using dynamic SQL, & insert a single row
--in it with the MAX Varchar stocked with the string we want
  SELECT  @Command = 'create table ['
       + @MySpecialTempTable
       + '] (MyID int identity(1,1), Bulkcol nvarchar(MAX))
insert into ['
       + @MySpecialTempTable
       + '](BulkCol) select @TheString'
  EXECUTE sp_ExecuteSQL @command, N'@TheString nvarchar(MAX)',
           @TheString
 SELECT @command 
--then we execute the BCP to save the file
  SELECT  @Command = 'bcp "select BulkCol from ['
          + @MySpecialTempTable + ']'
          + '" queryout '
          + @Filename + ' '
         + CASE @Unicode 
		     WHEN 0 THEN '-c' 
		     WHEN 8 THEN '-c -C 65001' 
			 ELSE '-w' END
          + ' -T -S' + @@ServerName
 SELECT @command 
     
  EXECUTE @RESULT= MASTER..xp_cmdshell @command
  EXECUTE ( 'Drop table ' + @MySpecialTempTable )
  RETURN @result
go
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
    IF @database IS NULL SELECT @database = ParseName(@Tablespec, 3);
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
                    'convert(nvarchar(max),' + name
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


USE WideWorldImporters

DECLARE @TheCommand NVARCHAR(4000)
SELECT @TheCommand='
Declare @Path sysname =''C:\data\RawData\'+Db_Name()+'Data\''
DECLARE @destination NVARCHAR(MAX) = 
(Select @path+Replace(Replace(Replace(''?'',''.'',''-''),'']'',''''),''['','''')+''.json'')
DECLARE @Json NVARCHAR(MAX)
  EXECUTE #SaveJsonDataFromTable 
     @database='''+Db_Name()+''',
	 @tablespec= ''?'',
	 @JSONData=@json OUTPUT
 Execute #SaveJSONToFile @theString=@Json, @filename=@destination'
 EXECUTE sp_MSforeachtable @command1=@TheCommand

DECLARE @TheCommand NVARCHAR(4000)
SELECT @TheCommand='
DECLARE @TheJSONSchema NVARCHAR(MAX) --our JSON Schema
EXECUTE #CreateJSONSchemaFromTable @TableSpec='''+Db_Name()+'.?'',@JSONSchema=@TheJSONSchema OUTPUT
DECLARE @destination NVARCHAR(MAX) = (Select ''C:\data\RawData\'+Db_Name()+'SchemaData\''+Replace(Replace(Replace(''?'',''.'',''-''),'']'',''''),''['','''')+''.json'')
DECLARE @TheJsonData NVARCHAR(MAX)
  EXECUTE #SaveJsonDataFromTable 
     @database='''+Db_Name()+''', @tablespec= ''?'', @JSONData=@TheJsonData OUTPUT
DECLARE @TheJSON NVARCHAR(MAX)=
(SELECT * 
 FROM (VALUES(Json_Query(@Thejsonschema), Json_Query(@TheJSONData)))f([schema],[data])
 FOR JSON AUTO, WITHOUT_ARRAY_WRAPPER);
 Execute #SaveJSONToFile @theString=@TheJSON, @filename=@destination'
 
EXECUTE sp_MSforeachtable @command1=@TheCommand




 
 
