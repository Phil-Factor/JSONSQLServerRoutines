# SQL Server and JSON: Data import, export and validation

This repository contains several stored procedures and PowerShell routines that can be used for inserting JSON data into SQL Server, validate the data  or to export the data from SQL Server. They are described in a series of articles on the Red-Gate site and in Simple-Talk. Some use ordinary JSON files and others show how to include the schema and data in one document. I use
them as temporary procedures because these are better for cross-database work, and as I
generally script them there is little point in maintaining a permanent procedure on every server.

## Schema creation

### CreateJSONSchemaFromTable

This temporary procedure creates a JSON schema from a table that
matches the JSON you will get from doing a
classic `select * from ... FOR JSON` statement on the entire table. This procedure needs SQL Server 2017 or later since it relies on `string_agg()`.

### SaveExtendedJsonDataFromTable

This temporary procedure This gets the JSON data from a table, taking into account all the problems that can come about such as dealing with CLR data types

### CreateJSONArrayInArraySchemaFromTable

This will produce a JSON Array-in-Array schema from a table.
This procedure needs SQL Server 2017 or later since it relies on `string_agg()`.

## JSON Data creation

###  SaveJsonDataFromTable.sql

This gets the JSON data from a table, taking into account all the problems that can come about such as dealing with CLR data types

### ArrayInArrayJSONDataFromTable

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

## PowerShell Validation

### ValidateViaJSONSchema.ps1

Shows how to validate a directory, with a subdirectory with the schema and a parallel directory with the data
