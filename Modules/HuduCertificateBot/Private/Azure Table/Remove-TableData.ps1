function Remove-TableData {
    Param(
        [Parameter(Mandatory = $true)]
        $TableName,

        [Parameter(Mandatory = $true)]
        $Entity
    )

    $Table = Get-Table -TableName $TableName
    Remove-AzDataTableEntity @Table -Entity $Entity | Out-Null
}
