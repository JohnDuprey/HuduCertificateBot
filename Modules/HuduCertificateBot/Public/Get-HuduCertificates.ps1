function Get-HuduCertificates {
    if (Initialize-HuduApi) {
        $Layout = Get-HuduAssetLayouts -Name $env:HuduSSLCertAssetLayoutName
    
        if (!$Layout) {
            $AssetLayoutFields = @(
                @{
                    label        = 'Common Name'
                    field_type   = 'Text'
                    show_in_list = 'true'
                    position     = 1
                },
                @{
                    label        = 'Valid From'
                    field_type   = 'Date'
                    show_in_list = 'true'
                    position     = 2
                },
                @{
                    label        = 'Valid To'
                    field_type   = 'Date'
                    expiration   = 'true'
                    show_in_list = 'true'
                    position     = 3
                },
                @{
                    label        = 'Issuer'
                    field_type   = 'Text'
                    show_in_list = 'true'
                    position     = 4
                },
                @{
                    label        = 'Organization'
                    field_type   = 'Text'
                    show_in_list = 'true'
                    position     = 5
                },
                @{
                    label        = 'Country'
                    field_type   = 'Text'
                    show_in_list = 'true'
                    position     = 6
                },
                @{
                    label        = 'Subject Alternative Name'
                    field_type   = 'Text'
                    show_in_list = 'false'
                    position     = 7
                },
                @{
                    label        = 'Certificate'
                    field_type   = 'Text'
                    show_in_list = 'false'
                    position     = 8
                },
                @{
                    label        = 'Serial'
                    field_type   = 'Text'
                    show_in_list = 'false'
                    position     = 9
                },
                @{
                    label        = 'Notes'
                    field_type   = 'RichText'
                    show_in_list = 'false'
                    position     = 10
                }
            )
            $Layout = (New-HuduAssetLayout -Name $env:HuduSSLCertAssetLayoutName -Icon 'fas fa-lock' -Color '00adef' -icon_color '#ffffff' -include_passwords $false -include_photos $false -include_comments $false -include_files $true -Fields $AssetLayoutFields).asset_layout
        }

        $TableQuery = @{
            TableName    = 'HuduCertificates'
            PartitionKey = 'Certs' 
        }
        $TrackedCerts = Get-TableData @TableQuery

        #Write-Host $Layout
        #Write-Host $TrackedCerts

        Get-HuduAssets -AssetLayoutId $Layout.id | Where-Object { $TrackedCerts.RowKey -notcontains $_.id -or ($TrackedCerts.RowKey -eq $_.id -and $TrackedCerts.Certificate -ne ($_.fields | Where-Object { $_.label -eq 'Certificate' }).value -or [string]::IsNullOrEmpty(($_.fields | Where-Object { $_.label -eq 'Valid To' })).value) }
    }
}
