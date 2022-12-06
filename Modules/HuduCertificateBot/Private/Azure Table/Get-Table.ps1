function Get-Table {
    [CmdletBinding()]
    param (
        $TableName
    )
    @{
        ConnectionString       = $env:AzureWebJobsStorage
        TableName              = $TableName
        CreateTableIfNotExists = $true
    }
}
