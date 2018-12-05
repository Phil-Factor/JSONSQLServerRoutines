EXEC sp_msforeachtable '
print ''Creating JSON for ?''
DECLARE @TheData NVARCHAR(MAX)=(
SELECT ''[''+ String_Agg(f.EachLine,'','')+'']''
FROM 
  (SELECT ''[''+String_Agg (
     CASE WHEN shredded.type=1 
       THEN ''"''+String_Escape(Coalesce(shredded.value,''null''),''json'')+''"''
     ELSE Coalesce(shredded.value,''null'') 
     END, '','') +'']''
     AS TheValue
  FROM OpenJson((SELECT * 
                 FROM ? 
         FOR JSON AUTO, INCLUDE_NULL_VALUES )) f
   CROSS apply OpenJson(f.value) shredded
   GROUP BY f.[Key])f(EachLine)
)
CREATE TABLE ##myTemp (Bulkcol nvarchar(MAX))
INSERT INTO ##myTemp (Bulkcol) SELECT @TheData
print ''Writing out ?''
EXECUTE xp_cmdshell ''bcp ##myTemp out C:\data\RawData\JsonData\adventureworks\?.JSON -c -C 65001 -T''
DROP TABLE ##myTemp'
