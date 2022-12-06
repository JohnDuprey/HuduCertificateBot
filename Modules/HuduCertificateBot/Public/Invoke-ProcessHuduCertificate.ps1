function Invoke-ProcessHuduCertificate {
    Param($Certificate) 
    try {
        Write-Output 'Certificate processing'
        #Write-Output ($Certificate | ConvertTo-Json)

        if (Initialize-HuduApi) { 
            $OrigCertificateString = ($Certificate.fields | Where-Object { $_.label -eq 'Certificate' }).value
            $Notes = ($Certificate.fields | Where-Object { $_.label -eq 'Notes' }).value
            #Write-Output $OrigCertificateString

            $CertificateString = $OrigCertificateString -replace '-----BEGIN CERTIFICATE-----' -replace '-----END CERTIFICATE-----'
            $CertDetails = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new([System.Convert]::FromBase64String($CertificateString))

            #Write-Output $CertDetails
            $RegexOptions = [System.Text.RegularExpressions.RegexOptions]
            $csvSplit = '(\s*,\s*)(?=(?:[^"]|"[^"]*")*$)'

            $SubjectProps = [regex]::Split($CertDetails.Subject, $csvSplit, $RegexOptions::ExplicitCapture)

            $Subject = $SubjectProps | ForEach-Object { 
                $key, $value = $_ -split '='
                @{$Key = $Value -replace '"' } 
            }
            try {
                $IssuerProps = [regex]::Split($CertDetails.Issuer, $csvSplit, $RegexOptions::ExplicitCapture) 
                #$IssuerProps

                $Issuer = $IssuerProps | ForEach-Object { 
                    $key, $value = $_ -split '='
                    @{$Key = $Value -replace '"' } 
                }
                $IssuerName = $Issuer.CN
                $IssuerOrg = $Issuer.O
                $IssuerCountry = $Issuer.C
            }   
            catch {
                $IssuerName = ''
                $IssuerOrg = ''
                $IssuerCountry = ''
            }

            $CertRow = @{
                CommonName              = "$($Subject.CN)"
                NotBefore               = $CertDetails.NotBefore.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
                NotAfter                = $CertDetails.NotAfter.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
                Issuer                  = "$IssuerName"
                Organization            = "$IssuerOrg"
                Country                 = "$IssuerCountry"
                SignatureAlgorithm      = "$($CertDetails.SignatureAlgorithm.FriendlyName)"
                SubjectAlternativeNames = [string]($CertDetails.DnsNameList -join ', ')
                Certificate             = $OrigCertificateString
                Serial                  = $CertDetails.SerialNumber
            }

            $HuduAssetFields = @{
                common_name              = "$($Subject.CN)"
                valid_from               = $CertDetails.NotBefore.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
                valid_to                 = $CertDetails.NotAfter.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
                issuer                   = "$IssuerName"
                organization             = "$IssuerOrg"
                country                  = "$Country"
                subject_alternative_name = [string]($CertDetails.DnsNameList -join ', ')
                serial                   = $CertDetails.SerialNumber
                notes                    = $Notes
            }

            #Write-Output ($HuduAssetFields | ConvertTo-Json)

            Set-HuduAsset -asset_id $Certificate.id -Name $Subject.CN -company_id $($Certificate.company_id) -asset_layout_id $Certificate.asset_layout_id -Fields $HuduAssetFields | Out-Null

            $CertificateUpdate = @{
                TableName    = 'HuduCertificates'
                RowKey       = [string]$Certificate.id
                PartitionKey = 'Certs'                    
                TableRow     = $CertRow
            }
            Set-TableData @CertificateUpdate
            Write-Output "Certificate Update Complete"
        }
        else {
            Write-Output 'ERROR: Unable to connect to Hudu'
        }        
    }
    catch {
        Write-Output "Exception processing certificates: $($_.Exception.Message)"
    }
}
