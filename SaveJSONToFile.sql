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
