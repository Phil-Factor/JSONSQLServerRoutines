CREATE OR alter FUNCTION [dbo].[UnwrapJson]
/**
summary:   >
  This multi-statement table-valued function talkes a JSON string and
  unwraps it into a relational hierarchy table that also retains
  the path to each element in the JSON document, and calculates the
  best-fit sql datatype for every simple value
Author: Phil Factor
Revision: 1.0
date: 1 Nov 2020
example:
  - SELECT * FROM UnwrapJson (N'[  
    {"name":"Phil", "email":"PhilipFactor@gmail.com"},  
    {"name":"Bob", "email":"bob32@gmail.com"}  
    ]')
returns:   >
  id, level, [key], Value, type, SQLDatatype, parent, path
 
**/    
(
    @JSON NVARCHAR(MAX)
)
RETURNS @Unwrapped TABLE 
  (
  [id] INT IDENTITY, --just used to get a unique reference to each json item
  [level] INT, --the hierarchy level
  [key] NVARCHAR(100), --the key or name of the item
  [Value] NVARCHAR(MAX),--the value, if it is a null, int,binary,numeric or string
  type INT, --0 TO 5, the JSON type, null, numeric, string, binary, array or object
  SQLDatatype sysname, --whatever the datatype can be parsed to
  parent INT, --the ID of the parent
  [path] NVARCHAR(4000) --the path as used by OpenJSON
  )
AS begin
INSERT INTO @Unwrapped ([level], [key], Value, type, SQLDatatype, parent,
[path])
VALUES
  (0, --the level
   NULL, --the key,
   @json, --the value,
   CASE WHEN Left(ltrim(@json),1)='[' THEN 4 ELSE 5 END, --the type
   'json', --SQLDataType,
   0 , --no parent
   '$' --base path
  );
DECLARE @ii INT = 0,--the level
@Rowcount INT = -1; --the number of rows from the previous iteration
WHILE @Rowcount <> 0 --while we are still finding levels
  BEGIN
    INSERT INTO @Unwrapped ([level], [key], Value, type, SQLDatatype, parent,
    [path])
      SELECT [level] + 1 AS [level], new.[Key] AS [key],
        new.[Value] AS [value], new.[Type] AS [type],
-- SQL Prompt formatting off
/* in order to determine the datatype of a json value, the best approach is to a determine
the datatype that can be parsed. It JSON, an array of objects can contain attributes that arent
consistent either in their name or value. */
       CASE 
        WHEN new.Type = 0 THEN 'bit null'
		WHEN new.[type] IN (1,2)  then COALESCE(
  		  CASE WHEN TRY_CONVERT(INT,new.[value]) IS NOT NULL THEN 'int' END, 
  		  CASE WHEN TRY_CONVERT(NUMERIC(14,4),new.[value]) IS NOT NULL THEN 'numeric' END,
  		  CASE WHEN TRY_CONVERT(FLOAT,new.[value]) IS NOT NULL THEN 'float' END,
		  CASE WHEN TRY_CONVERT(MONEY,new.[value]) IS NOT NULL THEN 'money' END,
  		  CASE WHEN TRY_CONVERT(DateTime,new.[value],126) IS NOT NULL THEN 'Datetime2' END,
		  CASE WHEN TRY_CONVERT(Datetime,new.[value],127) IS NOT NULL THEN 'Datetime2' END,
		  'nvarchar')
	   WHEN new.Type = 3 THEN 'bit'
	   WHEN new.Type = 5 THEN 'object' ELSE 'array' END AS SQLDatatype,
        old.[id],
        old.[path] + CASE WHEN old.type = 5 THEN '.' + new.[Key] 
					   ELSE '[' + new.[Key] COLLATE DATABASE_DEFAULT + ']' END AS path
-- SQL Prompt formatting on
      FROM @Unwrapped old
        CROSS APPLY OpenJson(old.[Value]) new
          WHERE old.[level] = @ii AND old.type IN (4, 5);
    SELECT @Rowcount = @@RowCount;
    SELECT @ii = @ii + 1;
  END;
  return
END
go