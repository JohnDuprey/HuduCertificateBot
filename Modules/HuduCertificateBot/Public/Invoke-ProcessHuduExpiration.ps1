function Invoke-ProcessHuduExpiration {
    Param($Expiration) 
    try {
        Initialize-HuduApi
        Initialize-PsaApi
        
        if ($env:HuduDomainExclusionList) {
            $DomainExclusions = $env:HuduDomainExclusionList -split ','
        }

        $CompanyID = $Expiration.company_id
        $HuduCompany = (Get-HuduCompanies -Id $CompanyID).company
        $CreateTicket = $true
        # Determine expiration type
        if ($Expiration.expirationable_type -eq 'Website') {
            switch ($Expiration.expiration_type) {
                'ssl_certificate' { $ExpirationType = 'SSL Certificate' }
                'domain' { $ExpirationType = 'Domain' }
            }
            $ExpirationID = '{0}-{1}' -f $Expiration.expiration_type, $Expiration.expirationable_id
            $Website = Get-HuduWebsites -WebsiteId $Expiration.expirationable_id

            foreach ($Exclusion in $DomainExclusions) {
                if ($Website.name -match $Exclusion) {
                    $CreateTicket = $false
                }
            }
            $Url = '{0}{1}' -f $env:HuduBaseDomain, $Website.url
            $Name = $Website.name
            $Expiry = Get-Date $Expiration.date
        }
        elseif ($Expiration.asset_type -eq $env:HuduSSLCertAssetLayoutName) {
            $ExpirationID = 'asset-{0}' -f $Expiration.id
            $Url = $Expiration.url
            $Name = $Expiration.name
            $ExpirationType = $env:HuduSSLCertAssetLayoutName
            $Expiry = Get-Date ($Expiration.fields | Where-Object { $_.label -eq 'Cert Expires' }).value
        }

        $Summary = '{0} expiration - {1}' -f $ExpirationType, $Name
        $InitialText = "The following item in Hudu is nearing expiration: `n`nName: {0}`nExpiration: {1}`nHudu Url: {2}`n`n{3}" -f $Name, $Expiry, $Url, $env:PSATicketAdditionalNotes
        
        if ($CreateTicket) {

            $PsaTicketRow = @{
                TableName    = 'PsaTicket'
                PartitionKey = 'Ticket'
                RowKey       = $ExpirationID
            }

            $ExistingTicket = Get-TableData @PsaTicketRow
            $TicketUpdated = $false
            if ($ExistingTicket) {
                $TicketID = $ExistingTicket.TicketID
                if (Test-PsaTicket -TicketID $TicketID) {
                    $Days = (New-TimeSpan -Start (Get-Date) -End $Expiry).Days
                    $UpdateText = 'This {1} will expire in {0} day(s)' -f $Days, $ExpirationType
                    try {
                        Update-PsaTicket -TicketID $TicketID -Text $UpdateText
                        $TicketUpdated = $true
                    }
                    catch {}
                }
            }

            if (!$TicketUpdated) {
                $TicketID = New-PsaTicket -Summary $Summary -Text $InitialText -HuduCompany $HuduCompany
            }
            $PsaTicketRow.TableRow = @{
                TicketID = $TicketID
            }
            if ($TicketID) {
                Set-TableData @PsaTicketRow
            }
        }
    }
    catch {
        Write-Output "Exception processing expirations: $($_.Exception.Message)"
    }
}
