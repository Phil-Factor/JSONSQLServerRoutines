CREATE OR alter FUNCTION [dbo].[OpenJSONExpressions]
/**
summary:   >
  This inline table-valued function talkes a JSON string and
  locates every table structure. Then it creates an OpenJSON
  Statement that can then be executed to create that table
  from the original JSON.
Author: Phil Factor
Revision: 1.0
date: 1 Nov 2020
example:
  - SELECT * FROM OpenJSONExpressions (N'[  
    {"name":"Phil", "email":"PhilipFactor@gmail.com"},  
    {"name":"Bob", "email":"bob32@gmail.com"}  
    ]')
returns:   >
  expression
 
**/    
(
   @JSON NVARCHAR(MAX)
    
)
RETURNS TABLE AS RETURN
(
WITH UnwrappedJSON (id, [level], [key], [Value], [type], SQLDatatype, parent,
                   [path]
                   )
AS (SELECT id, [level], [key], [Value], [type], SQLDatatype, parent, [path]
      FROM dbo.UnwrapJson(@json) )
  SELECT 'Select * from openjson(@json,''' + path + ''')
WITH ('  + String_Agg(
                       [name] + ' ' + datatype + ' ' --the WITH statement
-- SQL Prompt formatting off
   + case when datatype='nvarchar' then '('+length+')' 
     WHEN datatype='numeric' then  '(14,4)' ELSE '' end,', ')
   WITHIN GROUP ( ORDER BY  TheOrder  ASC  )    +')' as expression
-- SQL Prompt formatting on
    FROM
      (
      SELECT Parent.path, GrandChild.[key] AS [name], Min(GrandChild.id) AS TheOrder,
	    Max(GrandChild.SQLDatatype) AS datatype,
        Convert(NVARCHAR(100), Max(Len(GrandChild.Value))) AS length
        FROM
          (SELECT path, id FROM UnwrappedJSON WHERE type = 4) Parent
          INNER JOIN UnwrappedJSON Child
            ON Child.parent = Parent.id AND child.type IN (4, 5)
          INNER JOIN UnwrappedJSON GrandChild
            ON GrandChild.parent = Child.id AND GrandChild.type NOT IN (4, 5)
        GROUP BY Parent.path, GrandChild.[key]
      ) TheFields
    GROUP BY path
	)
GO