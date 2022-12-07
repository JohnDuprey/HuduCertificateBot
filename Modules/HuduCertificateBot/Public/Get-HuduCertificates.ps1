function Get-HuduCertificates {
    if (Initialize-HuduApi) {
        $Layout = Get-HuduAssetLayouts -Name $env:HuduSSLCertAssetLayoutName
    
        if (!$Layout) {
            $AssetLayoutFields = @(
                @{
                    label        = 'Certificate Info'
                    field_type   = 'RichText'
                    show_in_list = 'false'
                    position     = 1
                }
                @{
                    label        = 'Enable HTTPS Check'
                    field_type   = 'CheckBox'
                    show_in_list = 'true'
                    hint         = 'Enable HTTPS scanning on the Asset name (name should be in hostname.com:port format)'
                    position     = 2
                },
                @{
                    label        = 'Common Name'
                    field_type   = 'Text'
                    show_in_list = 'true'
                    position     = 3
                },
                @{
                    label        = 'Cert Issued'
                    field_type   = 'Date'
                    show_in_list = 'true'
                    position     = 4
                },
                @{
                    label        = 'Cert Expires'
                    field_type   = 'Date'
                    expiration   = 'true'
                    show_in_list = 'true'
                    position     = 5
                },
                @{
                    label        = 'Issuer'
                    field_type   = 'Text'
                    show_in_list = 'true'
                    position     = 6
                },
                @{
                    label        = 'Organization'
                    field_type   = 'Text'
                    show_in_list = 'true'
                    position     = 7
                },
                @{
                    label        = 'Country'
                    field_type   = 'Text'
                    show_in_list = 'true'
                    position     = 8
                },
                @{
                    label        = 'Subject Alternative Name'
                    field_type   = 'Text'
                    show_in_list = 'false'
                    position     = 9
                },
                @{
                    label        = 'Certificate'
                    field_type   = 'Text'
                    show_in_list = 'false'
                    required     = 'true'
                    hint         = 'Base64 encoded certificate'
                    position     = 10
                },
                @{
                    label        = 'Serial'
                    field_type   = 'Text'
                    show_in_list = 'false'
                    position     = 11
                },
                @{
                    label        = 'Signature Algorithm'
                    field_type   = 'Text'
                    show_in_list = 'false'
                    position     = 12
                },
                @{
                    label        = 'Enhanced Key Usage List'
                    field_type   = 'Text'
                    show_in_list = 'false'
                    position     = 13
                },
                @{
                    label        = 'Notes'
                    field_type   = 'RichText'
                    show_in_list = 'false'
                    position     = 14
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

        Get-HuduAssets -AssetLayoutId $Layout.id | Where-Object { $TrackedCerts.RowKey -notcontains $_.id -or ($TrackedCerts.RowKey -eq $_.id -and $TrackedCerts.Certificate -ne ($_.fields | Where-Object { $_.label -eq 'Certificate' }).value -or [string]::IsNullOrEmpty(($_.fields | Where-Object { $_.label -eq 'Valid To' })).value) -or (($_.fields | Where-Object { $_.label -eq 'Enable HTTPS Check' }).value -and $_.updated_at -le (Get-Date).AddDays(-1)) }
    }
}
