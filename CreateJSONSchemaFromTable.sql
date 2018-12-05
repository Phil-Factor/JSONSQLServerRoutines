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
		   IF @Database is NULL SELECT @Database=Coalesce(ParseName(@Tablespec,3),Db_Name())
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















