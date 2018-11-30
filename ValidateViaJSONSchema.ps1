$ErrorActionPreference = "Stop"
# enter the base directory 
$Path = 'ThePathToTheData'
# ...and the names of the subdirectories
$SchemaDirectory = 'JSONSchema\'
$DataDirectory = 'JSONData\'
# all this following section thanks to James Newton-King
$NewtonsoftJsonPath = Resolve-Path -Path "lib\Newtonsoft.Json.dll"
$NewtonsoftJsonSchemaPath = Resolve-Path -Path "lib\Newtonsoft.Json.Schema.dll"

Add-Type -Path $NewtonsoftJsonPath
Add-Type -Path $NewtonsoftJsonSchemaPath


# define the validator type
$source = @'
    public class Validator
    {
        public static System.Collections.Generic.IList<string> Validate(Newtonsoft.Json.Linq.JToken token, Newtonsoft.Json.Schema.JSchema schema)
        {
            System.Collections.Generic.IList<string> messages;
            Newtonsoft.Json.Schema.SchemaExtensions.IsValid(token, schema, out messages);
            return messages;
        }
    }
'@
Add-Type -TypeDefinition $source -ReferencedAssemblies $NewtonsoftJsonPath, $NewtonsoftJsonSchemaPath
# end of James Newton-King's code. Thanks, James.

Get-ChildItem "$($Path)\$($DataDirectory)" -Filter *.json | select Name | Foreach{
# do every file in the directory	
	$JSON = [IO.File]::ReadAllText("$($Path)\$($DataDirectory)$($_.Name)")
	$Schema = [IO.File]::ReadAllText("$($Path)\$($SchemaDirectory)$($_.Name)")
# parse the JSON files documents into a tokenised form
	$Token = [Newtonsoft.Json.Linq.JToken]::Parse($JSON)
	$Schema = [Newtonsoft.Json.Schema.JSchema]::Parse($Schema)
# do the validation, using the parsed documents	
	$ErrorMessages = [Validator]::Validate($Token, $Schema)
	if ($ErrorMessages.Count -eq 0)
	{ write-host "Schema is valid" } #just for the test. I don't approve of write-host!
	else #I've selected just the first five because usually a whole column is wrong!
	{ $ErrorMessages | Select-Object -First 5 | foreach{ write-warning $_ } }
	
}