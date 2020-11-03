import-Module sqlserver
<# a list of connection strings
for each of the target databaseinstances on which you'd like to run the code
#>
$ServerAndDatabaseList =
@(
 <# list of connection strings for each of the SQLservers that you need to execute code on #>
  @{ #provide a connection string for the instance
    'ServerConnectionString' = 'Server=MyServer;User Id=PhilFactor;Persist Security Info=False';
         #and a list of databases. Make target the same as source if the database you use it on has the same name
    'Databases' = @(@{'Source'='NorthWind';'Target'='WestWind'}) # do all
  }
)
$FileNameEnd = 'DataMerge'#'AllObjects' #the unique part of the file you save the single string result in
# the file and path in which is your SQL Code
$SQLPerServerFileName = 'MyGithubDirectoryPath\JSONSQLServerRoutines\SaveMergeStatementFromTable.sql'
$FinalBatch="EXEC sp_msforeachtable 'ALTER TABLE ? WITH CHECK CHECK CONSTRAINT all'"
$RootDirectoryForOutputFile = "$env:USERPROFILE\JSONDocumentation" #the directory you want it in
$minimumCompatibilityLevel=130 #specify the minimum database compatibility level
$fileType='SQL' #the filetype of the file you save for each database.
$slash='+' #the string that you want to replace for the 'slash' in an instance name for files etc
# end of data area

$SQLPerServerContent = [IO.File]::ReadAllText($SQLPerServerFileName) #read the file into a variable in one gulp
if ($SQLPerTableFileName -ne $null)
  {$SQLPerTableContent = [IO.File]::ReadAllText($SQLPerTableFileName)}
    #read the file into a variable in one gulp}
else 
{$SQLPerTableContent=$SQLEachTable;}
# now create the directory (folder) for the output files if it doesn't exist
if (!(Test-Path -path $RootDirectoryForOutputFile -PathType Container))
{ $null = New-Item -ItemType directory -Path $RootDirectoryForOutputFile }
#Now for each instance and associated list of databases
$ServerAndDatabaseList | foreach {
  #for each instance/sever
  $csb = New-Object System.Data.Common.DbConnectionStringBuilder
  $csb.set_ConnectionString($_.ServerConnectionString) 
  # create an SMO connection get credentials if necessary
  if ($csb.'user id' -ne '') #then it is using SQL Server Credentials
  { <# Oh dear, we need to get the password, if we don't already know it #>
    $SqlEncryptedPasswordFile = `
    "$env:USERPROFILE\$($csb.'user id')-$($csb.server.Replace('\', $slash)).xml"
    # test to see if we know about the password in a secure string stored in the user area
    if (Test-Path -path $SqlEncryptedPasswordFile -PathType leaf)
    {
      #has already got this set for this login so fetch it
      $SqlCredentials = Import-CliXml $SqlEncryptedPasswordFile
      
    }
    else #then we have to ask the user for it (once only)
    {
      #hasn't got this set for this login
      $SqlCredentials = get-credential -Credential $csb.'user id'
      $SqlCredentials | Export-CliXml -Path $SqlEncryptedPasswordFile
    }
    $ServerConnection =
    new-object `
           "Microsoft.SqlServer.Management.Common.ServerConnection"`
    ($csb.server, $SqlCredentials.UserName, $SqlCredentials.GetNetworkCredential().password)
    $csb.Add('password',$SqlCredentials.GetNetworkCredential().password)
  }
  else
  {
    $ServerConnection =
    new-object `
           "Microsoft.SqlServer.Management.Common.ServerConnection" `
    ($csb.server)
  }
  <# all this work just to maintain passwords ! #>
  try # now we make an SMO connection  to the server, using the connection string
  {
    $srv = new-object ("Microsoft.SqlServer.Management.Smo.Server") $ServerConnection
  }
  catch
  {
    Write-error "Could not connect to SQL Server instance $($csb.server) $($error[0]). Script is aborted"
    exit -1
  }
  $Databasesthere = $srv.Databases.name
  $_.Databases |
    foreach {
      
      write-output "now doing $($_.source) on $($csb.server) "
      $Db = $_.source
      $Destination=$_.Target
      $ReturnedStringFromBatch=''
      $CompatibilityLevel=$srv.ConnectionContext.ExecuteScalar("
        SELECT top 1 compatibility_level FROM sys.databases WHERE name = '$db'");  
       if ($databasesThere -notcontains $db) {
         Write-Error "The Server $($csb.Server) does not have a database called $db"}
      if ($CompatibilityLevel -lt $minimumCompatibilityLevel) {
        Write-Error "The Server database called $db on $($csb.Server) at level $CompatibilityLevel is below the minimum compatibility level $minimumCompatibilityLevel"}
      try #to execute the SQL in the file
      {
      $ds=Invoke-Sqlcmd -QueryTimeout 65535 -connectionstring  $csb.ConnectionString -MaxCharLength ([int32]::MaxValue) -OutputSqlErrors $true -OutputAs DataRows -query "use $db
        $SQLPerServerContent
DECLARE @TotalScript NVARCHAR(MAX)
DECLARE @DestinationDatabase sysname='$Destination'
DROP TABLE IF exists ##myTemp
CREATE TABLE ##myTemp (Bulkcol nvarchar(MAX), TheRightOrder INT IDENTITY)
DECLARE @DisableConstraints nvarchar(4000)='Print ''Disabling all table constraints'''
SELECT @DisableConstraints=@DisableConstraints+'
ALTER TABLE [$Db].'+Object_Schema_Name(object_id)+'.'+QuoteName(name)+' NOCHECK CONSTRAINT ALL
' FROM sys.tables
INSERT INTO ##myTemp (BulkCol) SELECT @DisableConstraints
DECLARE @command NVARCHAR(4000)= '
print ''Creating SQL Merge file for ?''
DECLARE @CreatedScript NVARCHAR(MAX)
EXECUTE #SaveMergeStatementFromTable  @TableSpec=''?'',@DestinationDatabase='''+@DestinationDatabase+''',@Statement=@CreatedScript OUTPUT
INSERT INTO ##myTemp (Bulkcol) SELECT coalesce(@CreatedScript,'''')+''
''
'
EXECUTE sp_msforeachtable @command
Select Bulkcol from ##myTemp order by TheRightOrder
DROP TABLE ##myTemp
       "
       $ReturnedStringFromBatch += $ds.BulkCol
     }
     catch
     {
      Write-error `
            "Could not execute the main code on $($csb.server) $($error[0].Exception). Script is aborted"
      exit -1
     } } 
    #make sure that the folder exists for the subdirectory orresponding to the server
    if (!(Test-Path -path "$RootDirectoryForOutputFile\$($csb.server.Replace('\', $slash))" -PathType Container))
    { $null = New-Item -ItemType directory -Path "$RootDirectoryForOutputFile\$($csb.server.Replace('\', $slash))" }
    #output it to the file
    if ($FinalBatch -ne $null) {$ReturnedStringFromBatch += '
    '+ $FinalBatch}
      $ReturnedStringFromBatch>"$RootDirectoryForOutputFile\$($csb.server.Replace('\', $slash))\$db$FileNameEnd.$FileType"
 
 }
