$EnvironmentVariables = @('AzureWebJobsStorage', 'HuduAPIKey', 'HuduBaseDomain', 'HuduSSLCertAssetLayoutName')
ForEach ($Key in $EnvironmentVariables) {
    [Environment]::SetEnvironmentVariable($Key, $null)
}