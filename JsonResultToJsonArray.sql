CREATE OR ALTER FUNCTION JsonResultToJsonArray
    (@JSONResult AS NVARCHAR(MAX))
/**
Summary: >
converts a JSON array-on-array document from a JSON result
produced using  FOR JSON AUTO ,INCLUDE_NULL_VALUES 
it must include null values!

Author: Phil Factor
Date: 01/10/2018
Examples: >
DECLARE @JSONResult NVARCHAR(MAX)=
(SELECT * FROM adventureworks2016.person.person
FOR JSON AUTO, INCLUDE_NULL_VALUES)
SELECT dbo.JsonResultToJsonArray(@JSONresult)
Returns: >
  JSON Array-on-array document
**/
RETURNS NVARCHAR(MAX) --JSON Array-on-array document
--WITH ENCRYPTION|SCHEMABINDING, ...
AS
BEGIN
    DECLARE @JSON NVARCHAR(MAX)=(
           SELECT '['+ String_Agg(f.EachLine,',')+']'
           FROM 
             (SELECT '['+String_Agg (
                CASE WHEN shredded.type=1 
                  THEN '"'+String_Escape(Coalesce(shredded.value,'null'),'json')+'"'
                ELSE Coalesce(shredded.value,'null') 
                END, ',') +']'
                AS TheValue
             FROM OpenJson(@JSONResult) f
              CROSS apply OpenJson(f.value) shredded
              GROUP BY f.[Key])f(EachLine)
           )
       RETURN @json
END
GO
