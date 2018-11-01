CREATE OR ALTER PROCEDURE #SelectJsonIntoTable
  (@database sysname,  @JSONSchemaAndData NVARCHAR(MAX) 
  )
AS
/**
Summary: >
  This is a way of taking a JSON string that contains both the schema
  and the data, and inserting it into a table in the database you wish
Author: philfactor
Date: 01/11/2018
Database: business
Examples:
 - Declare @jsonSchema NVARCHAR(max)= '
   {"schema":{
   "$id": "https://mml.uk/jsonSchema/Person-PhoneNumberType.json",
   "$schema": "http://json-schema.org/draft-07/schema#",
   "title": "PhoneNumberType",
   "SQLtablename":"[Person].[PhoneNumberType]",
   "SQLschema":"Person",
     "type": "array",
     "items": {
        "type": "object",
      "required": ["PhoneNumberTypeID","Name","ModifiedDate"],
        "maxProperties": 4,
         "minProperties": 3,
        "properties":{
               "PhoneNumberTypeID": {"type":["number"],"sqltype":"int", "columnNo":1, "nullable":0, "Description":""},
               "Name": {"type":["string"],"sqltype":"nvarchar(50)", "columnNo":2, "nullable":0, "Description":""},
               "ModifiedDate": {"type":["string"],"sqltype":"datetime", "columnNo":3, "nullable":0, "Description":""}}
         }
      },"data":[
      {"PhoneNumberTypeID":1,"Name":"Cell","ModifiedDate":"2017-12-13T13:19:22.273"},
      {"PhoneNumberTypeID":2,"Name":"Home","ModifiedDate":"2017-12-13T13:19:22.273"},
      {"PhoneNumberTypeID":3,"Name":"Work","ModifiedDate":"2017-12-13T13:19:22.273"}]}
     '
      EXECUTE #SelectJsonIntoTable @Database='MyDatabase', @JSONSchemaAndData=@jsonSchema
Returns: >
  nothing
**/
DECLARE @ExplicitSchema NVARCHAR(MAX);
DECLARE @columnlist NVARCHAR(4000);
DECLARE @tableSpec sysname;

IF @JSONSchemaAndData IS NULL
OR @Database IS NULL
  RAISERROR('{"error":"must have the database and JSON details"}', 16, 1);
  
SELECT @ExplicitSchema =
 String_Agg(quotename(property.[key])+' '+
  CASE sqltype 
    WHEN 'hierarchyid' THEN 'nvarchar(30)' 
    WHEN 'geometry'THEN 'nvarchar(100)'
    WHEN 'geography' THEN 'nvarchar(100)'
    WHEN 'image' THEN 'Varbinary(max)'
    WHEN 'text' THEN 'Varchar(max)' 
    WHEN 'ntext' THEN 'Nvarchar(max)'
    ELSE sqltype end+ ' ''$."'+property.[key]+'"''',',')
 FROM OpenJson(@JSONSchemaAndData,'strict $.schema.items.properties') property
OUTER APPLY OpenJson(property.value) 
  WITH (sqltype VARCHAR(20)  'strict $.sqltype');

 SELECT  @columnlist = String_Agg(
  CASE WHEN sqltype IN ( 'hierarchyid', 'geometry', 'geography')
   THEN 'Convert('+sqlType+','+QuoteName(property.[key])+') AS "'+property.[key]+'"' 
    ELSE property.[key] end,', ')
 FROM OpenJson(@JSONSchemaAndData,'strict $.schema.items.properties') property
OUTER APPLY OpenJson(property.value) 
  WITH (sqltype VARCHAR(20)  'strict $.sqltype');

IF @ExplicitSchema  IS NULL RAISERROR('Cannot locate the explicit schema for WITH clause ', 16, 1);
SELECT @Tablespec=Json_Value(@JSONSchemaAndData,'strict $.schema.SQLtablename') 
DECLARE @command NVARCHAR(MAX) =
   (SELECT '
use ' + @database + '
DROP TABLE IF EXISTS '+@TableSpec+'
SELECT '+@columnlist+' into '+@TableSpec+' FROM OpenJson(@jsonData,''strict $.data'') 
   WITH
    (
    '+@explicitSchema+'
    );
')
     
EXECUTE sp_executesql @command, N'@jsonData nvarchar(max)', @jsonData = @JSONSchemaAndData;

GO









