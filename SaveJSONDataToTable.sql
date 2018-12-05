USE philfactor
go
CREATE OR ALTER PROCEDURE #SaveJsonDataToTable (@database sysname=null, @Schema sysname=NULL, @table sysname=null, @Tablespec sysname=NULL, @Path sysname)
AS 
Declare @parameters nvarchar(max)
DECLARE @hasIdentityColumn INT
DECLARE @columnlist  NVARCHAR(4000)

 IF Coalesce(@table,@Tablespec) IS NULL
			 OR Coalesce(@schema,@Tablespec) IS NULL
			   RAISERROR ('{"error":"must have the table details"}',16,1)
			
		   IF @table is NULL SELECT @table=ParseName(@Tablespec,1)
		   IF @Schema is NULL SELECT @schema=ParseName(@Tablespec,2)
		   IF @Database is NULL SELECT @Database=coalesce(ParseName(@Tablespec,3),Db_Name())
		   IF @table IS NULL OR @schema IS NULL OR @database IS NULL
		      RAISERROR  ('{"error":"must have the table details"}',16,1)
DECLARE @source NVARCHAR(MAX) = 
(Select @path+Replace(Replace(Replace(@schema+'-'+@Table,'.','-'),']',''),'[','')+'.json')
SELECT @TableSpec=QuoteName(@database)+ '.'+ QuoteName(@Schema)+'.'+QuoteName(@table)
DECLARE @SelectStatement NVARCHAR(200)=(SELECT 'Select * from '+@TableSpec)

SELECT  @parameters=String_Agg(QuoteName(name)+' '+
CASE f.system_type_name
    WHEN 'hierarchyid' THEN 'nvarchar(30)' 
    WHEN 'geometry'THEN 'nvarchar(100)'
    WHEN 'geography' THEN 'nvarchar(100)'
    WHEN 'image' THEN 'Varbinary(max)'
    WHEN 'text' THEN 'Varchar(max)' 
    WHEN 'ntext' THEN 'Nvarchar(max)'
    ELSE f.system_type_name  end+ ' ''$."'+name+'"''',', '),
	@hasIdentityColumn  =MAX(Convert(INT,is_identity_column)),
	@columnlist=String_Agg(name,', ')
from
   sys.dm_exec_describe_first_result_set
	  (@SelectStatement, NULL, 1) f
	  
IF @parameters IS NULL RAISERROR('cannot execute %s',16,1,@selectStatement)
Declare @command nvarchar(max)=(SELECT '
use '+@database+'
DECLARE @jsonData NVARCHAR(max)= 
(SELECT  BulkColumn
FROM OPENROWSET (BULK '''+@source +''', SINGLE_CLOB, CODEPAGE=''65001'' ) AS json )

Delete from '+@TableSpec+ CASE WHEN @hasIdentityColumn>0 THEN '
SET IDENTITY_INSERT '+@TableSpec+' ON ' ELSE '' END+'
   INSERT INTO '+@TableSpec+' ('+@columnList+')
   SELECT '+@columnList+' FROM OpenJson(@jsonData) 
   WITH
    (
  '+@parameters+' );
'+ CASE WHEN @hasIdentityColumn>0 THEN '
SET IDENTITY_INSERT '+@TableSpec+' OFF ' ELSE '' END)
IF @command IS NULL RAISERROR('cannot execute null command',16,1)
EXECUTE sp_executeSQL @command
GO




