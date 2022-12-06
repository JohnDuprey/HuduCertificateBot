$FuncRoot = (Get-Item $PSScriptRoot).Parent.FullName
### Read the local.settings.json file and convert to a PowerShell object.
$FuncSettings = Get-Content "$FuncRoot\local.settings.json" | ConvertFrom-Json | Select-Object -ExpandProperty Values
### Loop through the settings and set environment variables for each.
$ValidKeys = @('AzureWebJobsStorage', 'HuduAPIKey', 'HuduBaseDomain', 'HuduSSLCertAssetLayoutName')
ForEach ($Key in $FuncSettings.PSObject.Properties.Name) {
    if ($ValidKeys -Contains $Key) {
        [Environment]::SetEnvironmentVariable($Key, $FuncSettings.$Key)
    }
}
