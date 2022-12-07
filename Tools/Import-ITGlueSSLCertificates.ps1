Param(
    $ITGlueCSV,
    $HuduAPIKey,
    $HuduBaseUrl,
    $HuduSslAssetName = 'SSL Certificates'
)

if ($HuduAPIKey) { New-HuduAPIKey -ApiKey $HuduAPIKey }
else { New-HuduAPIKey }
if ($HuduBaseUrl) { New-HuduBaseURL -BaseURL $HuduBaseUrl }
else { New-HuduBaseURL }

if (-not (Test-Path $ITGlueCSV)) {
    Write-Error 'No CSV file specified'
    exit
}

try {
    $Certificates = Import-Csv -Path $ITGlueCSV
    $Companies = $Certificates | Group-Object -Property organization
}
catch {
    Write-Error "CSV Processing error $($_.Exception.Message)"
    exit
}

if ($Companies) {
    Write-Host 'Getting Company List'
    $HuduCompanies = Get-HuduCompanies

    Write-Host 'Getting Websites'
    $Websites = Get-HuduWebsites

    $SslLayout = Get-HuduAssetLayouts -Name $HuduSslAssetName

    foreach ($Company in $Companies) {
        $CompanyName = $Company.Name
        $HuduCompany = $HuduCompanies | Where-Object { $_.name -eq $CompanyName }
        if ($HuduCompany) {
            Write-Host "`r`nMatched ITG Organization: $CompanyName to Hudu Company: $($HuduCompany.name)"
            $CompanyWebsites = $Websites | Where-Object { $_.company_id -eq $HuduCompany.id }
            $CompanyCerts = Get-HuduAssets -CompanyId $HuduCompanyId -AssetLayoutId $SslLayout.id

            foreach ($Cert in $Company.Group) {
                Write-Host "`r`nCertificate: $($Cert.host)"
                $WebsiteMatch = $false
                $CertMatch = $false
                foreach ($CompanyWebsite in $CompanyWebsites) {
                    if ($CompanyWebsite.name -match [Regex]::Escape($Cert.name) -or $CompanyWebsite.name -match [Regex]::Escape($Cert.host)) {
                        $WebsiteMatch = $true
                        Write-Host '- Matched cert to website'

                        if ($CompanyWebsite.paused -or $CompanyWebsite.disable_ssl -or $CompanyWebsite.disable_whois -or $CompanyWebsite.disable_dns) {
                            Write-Host '- Enabling website checks'
                            Set-HuduWebsite -Id $CompanyWebsite.id -Name $CompanyWebsite.name -CompanyId $CompanyWebsite.company_id -Paused 'false' -DisableDNS 'false' -DisableSSL 'false' -DisableWhois 'false'
                        }

                        break
                    }
                }

                if (-not $WebsiteMatch) {
                    Write-Host '- Site not matched, checking certificates'
                    foreach ($CompanyCert in $CompanyCerts) {
                        if ($CompanyCert.name -eq $Cert.name -or $CompanyCerts.name -eq $Cert.host) {
                            $CertMatch = $true
                            Write-Host '- Certificate matched, updating'
                            if ($Cert.host) {
                                $UpdateField = @{
                                    enable_https_check = $true
                                    certificate        = ($CompanyCert.fields | Where-Object { $_.label -eq 'Certificate' }).value
                                    notes              = $Cert.notes
                                }
                                try {
                                    #Set-HuduAsset -CompanyId $HuduCompany.id -asset_id $CompanyCert.id -AssetLayoutId $SslLayout.id -Name $Cert.host -Fields $UpdateField -ErrorAction Stop
                                }
                                catch {}
                                break
                            }
                        }
                    }
                    if (-not $CertMatch) {
                        Write-Host '- Certificate not matched, creating new'
                        $NewCertFields = @{
                            certificate = $Cert.certificate
                            notes       = $Cert.notes
                        }
                        if ($Cert.host) { 
                            $NewCertFields.enable_https_check = $true
                        }
                        New-HuduAsset -CompanyId $HuduCompany.Id -AssetLayoutId $SslLayout.id -Name $Cert.name -Fields $NewCertFields
                        break
                    }
                }
            }
        }
        else {
            Write-Error "`r`nCould not find a match for $CompanyName"
            continue
        }
    }
}