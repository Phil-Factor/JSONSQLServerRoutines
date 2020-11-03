CREATE PROCEDURE TablesFromJSON @TheJSON NVARCHAR(MAX)
/**
summary:   >
  This procedure returns a table for every one found  in a JSON 
  string 
Author: Phil Factor
Revision: 1.0
date: 1 Nov 2020
example:
  - EXECUTE TablesFromJSON @TheJSON= N'[  
    {"name":"Phil", "email":"PhilipFactor@geeMail.com"},  
    {"name":"Geoff", "email":"Geoff2435@geeMail.com"},
    {"name":"Mo", "email":"MoHussain34@geeMail.com"},
    {"name":"Karen", "email":"KarenAlott34@geeMail.com"},
	{"name":"Bob", "email":"bob32@geeMail.com"}   
    ]'
returns:   >
  expression
 
**/    
AS
DECLARE @expressions TABLE (id INT IDENTITY, TheExpression NVARCHAR(MAX));
INSERT INTO @expressions (TheExpression)
  SELECT expression FROM OpenJSONExpressions(@TheJSON);
DECLARE @RowCount INT = -1, @ii INT = 1, @expressionToExcecute NVARCHAR(MAX);
WHILE @RowCount <> 0
  BEGIN
    SELECT @expressionToExcecute = TheExpression FROM @expressions WHERE id = @ii;
    SELECT @RowCount = @@RowCount;
    SELECT @ii = @ii + 1;
    IF @RowCount > 0
      EXECUTE sp_executesql @expressionToExcecute, N'@JSON NVARCHAR(MAX)',
        @JSON = @TheJSON;
  END;
GO