# SQL Server and JSON: Data import, export and validation

This repository contains several stored procedures and PowerShell routines that can be used for inserting JSON data into SQL Server, validate the data  or to export the data from SQL Server. They are described in a series of articles on the Red-Gate site and in Simple-Talk. Some use ordinary JSON files and others show how to include the schema and data in one document. I use
them as temporary procedures because these are better for cross-database work, and as I
generally script them there is little point in maintaining a permanent procedure on every server.

## Schema creation

### CreateJSONSchemaFromTable.sql

This temporary procedure creates a JSON schema from a table that
matches the JSON you will get from doing a
classic `select * from ... FOR JSON` statement on the entire table. This procedure needs SQL Server 2017 or later since it relies on `string_agg()`.

### CreateJSONArrayInArraySchemaFromTable.sql

This will produce a JSON Array-in-Array schema from a table.
This procedure needs SQL Server 2017 or later since it relies on `string_agg()`.

## JSON Data creation

###  SaveJsonDataFromTable.sql

This gets the JSON data from a table, taking into account all the problems that can come about such as dealing with CLR data types

### SaveExtendedJsonDataFromTable.sql

This temporary procedure This gets the JSON data from a table, taking into account all the problems that can come about such as dealing with CLR data types

### ArrayInArrayJSONDataFromTable.sql

This will produce a JSON Array-in-Array schema from either a table or a query.
This can't be done, unfortunately, from SQL Server's implementation of JSON.
This procedure needs SQL Server 2017 or later since it relies on `string_agg()`. It was
first written to check out how much more economical on space the array-in-Array
format was for storing tabular data as a document

## Importing JSON Data

### SaveJSONDataToTable.sql

This saves a JSON file to a table, dealing with the complications of having old deprecated data types and CLR data types

###  SelectJSONIntoTable.sql

This is a way of taking a JSON string that contains both the schema
and the data, and inserting it into a table in the database you wish

## Utilities

###  SaveJSONToFile.sql

This is a utility stored procedure for
saving text to a file It is designed to save
as utf-8 for JSON files but will do any file

###  SaveMultiRowSelectStatementFromTable.sql 

This gets a multirow derived table SELECT * from (VALUES)  statement 
from a table or a query. If you provide a destination, it will create
the entire statement to stock the table with data. Warning: This is slow to use with large tables- use JSON instead as it is quicker, surprisingly.
  
###  SaveMergeStatementFromTable 

This creates a merge statement, creating a table source from a multi-row 
VALUES statement, and merging it with the table whose name you provide.
This MERGE statement can then be executed. Beware
that this is only really practicable for small tables, because the VALUES statement degrades with scale.

The source is specified either by the database.schema.table 'tablespec, 
or by doing tablename, schema and database individually. You can also use queries
  
## JSON Data Discovery

###  UnwrapJSON.sql

This multi-statement table-valued function talkes a JSON string and
  unwraps it into a relational hierarchy table that also retains
  the path to each element in the JSON document, and calculates the
  best-fit sql datatype for every simple value

###  OpenJSONExpressions.sql 

  This inline table-valued function talkes a JSON string and
  locates every table structure. Then it creates an OpenJSON
  Statement that can then be executed to create that table
  from the original JSON.
  
###  TablesFromJSON 

 This procedure returns a table for every one found  in a JSON 
  string 
   
  
## PowerShell routines 

### ValidateViaJSONSchema.ps1

Shows how to validate a directory, with a subdirectory with the schema and a parallel directory with the data

### GenerateSQLMergeScripts.ps1

This is a PowerShell script uses SaveMergeStatementFromTable.sql to generate a gigantic merge script for all the tables of a (small) database.
