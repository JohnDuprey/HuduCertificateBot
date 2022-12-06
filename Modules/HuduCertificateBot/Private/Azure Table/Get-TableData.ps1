function Get-TableData {
    Param(
        [Parameter(Mandatory = $true)]
        $TableName,
        [Parameter(ParameterSetName = 'RowPartition')]
        $RowKey = '',
        [Parameter(ParameterSetName = 'RowPartition')]
        $PartitionKey = '',
        [Parameter(ParameterSetName = 'FilterString')]
        $Filter = ''
    )

    $Table = Get-Table -TableName $TableName

    switch ($PSCmdlet.ParameterSetName) {
        'FilterString' {
            if ($Filter) {
                $Table.Filter = $Filter
            }
        }
        'RowPartition' {
            $Filter = [system.collections.generic.list[string]]::new()
            if ($RowKey) {
                $Filter.Add("RowKey eq '$RowKey'") | Out-Null
            }
            if ($PartitionKey) {
                $Filter.Add("PartitionKey eq '$PartitionKey'") | Out-Null
            }
            if ($Filter) {
                $Table.Filter = $Filter -join ' and '
            }
        }
    }

    Get-AzDataTableEntity @Table
}
