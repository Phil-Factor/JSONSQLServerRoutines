

DECLARE @TheJSONSchema NVARCHAR(MAX);
EXECUTE #CreateJSONSchemaFromTable @Tablespec = 'adventureworks2016.HumanResources.Employee',
  @jsonSchema = @TheJSONSchema OUTPUT;
DECLARE @TheJSONdata NVARCHAR(MAX) =
          (
          SELECT *
            FROM AdventureWorks2016.HumanResources.Employee
          FOR JSON AUTO, INCLUDE_NULL_VALUES
          );
DECLARE @TheJSON NVARCHAR(MAX) =
          (
          SELECT *
            FROM (VALUES (Json_Query(@TheJSONSchema), Json_Query(@TheJSONdata))) AS f (
            [schema], data
)
          FOR JSON AUTO, WITHOUT_ARRAY_WRAPPER
          );
EXECUTE #SaveJSONToFile @TheJSON,
'C:\data\RawData\HumanResources-Employee.json', 8;