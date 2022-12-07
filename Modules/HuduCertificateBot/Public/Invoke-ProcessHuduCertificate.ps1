function Invoke-ProcessHuduCertificate {
    Param($Certificate) 
    try {
        if (Initialize-HuduApi) { 
            Write-Output 'Certificate processing'
            #Write-Output ($Certificate | ConvertTo-Json)

            $CertInfo = ''
            $OrigCertificateString = ($Certificate.fields | Where-Object { $_.label -eq 'Certificate' }).value
            $Notes = ($Certificate.fields | Where-Object { $_.label -eq 'Notes' }).value
            $EnableHttpsCheck = ($Certificate.fields | Where-Object { $_.label -eq 'Enable HTTPS Check' }).value

            if ($EnableHttpsCheck) {
                $Url = 'https://{0}' -f $Certificate.name
                $HttpsCheck = Get-ServerCertificateValidation -Url $Url
                $CertDetails = $HttpsCheck.Certificate
                
                $Pem = New-Object System.Text.StringBuilder
                $Pem.AppendLine('-----BEGIN CERTIFICATE-----')
                $Pem.AppendLine([System.Convert]::ToBase64String($CertDetails.RawData, 1))
                $Pem.AppendLine('-----END CERTIFICATE-----')
                $OrigCertificateString = $Pem.ToString()

                $SslErrors = foreach ($SslError in $HttpsCheck.SslErrors) {
                    switch ($SslError) {
                        'None' { 'No SSL policy errors.' }
                        'RemoteCertificateChainErrors' { 
                            $HttpsCheck.Chain.ChainStatus.StatusInformation
                        }
                        'RemoteCertificateNameMismatch' { 'Certificate name mismatch.' }
                        'RemoteCertificateNotAvailable' { 'Certificate not available.' }
                    }
                }

                if ($SslErrors -match 'No SSL policy errors.') {
                    $Callout = 'success'
                }
                else {
                    $Callout = 'danger'
                }
                $CertInfo = '<p class="callout callout-{0}">{1}</p>' -f $Callout, ($SslErrors -join "<br />")
            }
            else {
                $OrigCertificateString = ($Certificate.fields | Where-Object { $_.label -eq 'Certificate' }).value
                $CertificateString = $OrigCertificateString -replace '.*-----BEGIN CERTIFICATE-----' -replace '-----END CERTIFICATE-----.*'
                $CertDetails = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new([System.Convert]::FromBase64String($CertificateString))
            }
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
                EnhancedKeyUsageList    = [string]($CertDetails.EnhancedKeyUsageList -join ', ')
            }

            $HuduAssetFields = @{
                certifiate_info          = $CertInfo
                enable_https_check       = $EnableHttpsCheck
                common_name              = "$($Subject.CN)"
                cert_issued              = $CertDetails.NotBefore.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
                cert_expires             = $CertDetails.NotAfter.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
                issuer                   = "$IssuerName"
                organization             = "$IssuerOrg"
                country                  = "$Country"
                subject_alternative_name = [string]($CertDetails.DnsNameList -join ', ')
                serial                   = $CertDetails.SerialNumber
                signature_algorithm      = "$($CertDetails.SignatureAlgorithm.FriendlyName)"
                enhanced_key_usage_list  = [string]($CertDetails.EnhancedKeyUsageList -join ', ')
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
            Write-Output 'Certificate Update Complete'
        }
        else {
            Write-Output 'ERROR: Unable to connect to Hudu'
        }        
    }
    catch {
        Write-Output "Exception processing certificates: $($_.Exception.Message)"
    }
}
