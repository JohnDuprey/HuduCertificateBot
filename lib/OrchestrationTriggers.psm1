function Start-CertificateOrchestrator {
    Param($Context)

    try {
        $DurableRetryOptions = @{
            FirstRetryInterval  = (New-TimeSpan -Seconds 30)
            MaxNumberOfAttempts = 2
            BackoffCoefficient  = 2
        }
        $RetryOptions = New-DurableRetryOptions @DurableRetryOptions
        $Certificates = Invoke-ActivityFunction -FunctionName 'Get-CertificatesQueue'

        if (($Certificates | Measure-Object).Count -gt 0) {
            $Tasks = foreach ($Certificate in $Certificates) {
                if (![string]::IsNullOrEmpty($Certificate)) {
                    Invoke-DurableActivity -FunctionName 'Invoke-DurableProcessCertificate' -Input ($Certificate | ConvertTo-Json -Depth 10) -NoWait -RetryOptions $RetryOptions
                }
            }
            if ($Tasks) {
                Wait-ActivityFunction -Task $Tasks
            }
        }
        Write-Host 'Completed.'
    }
    catch {
        Write-Host "EXCEPTION processing certificates $($_.Exception.Message)"
    }
}

function Start-PsaTicketOrchestrator {
    Param($Context)

    try {
        if ($env:HuduPSAIntegration) {
            $DurableRetryOptions = @{
                FirstRetryInterval  = (New-TimeSpan -Seconds 30)
                MaxNumberOfAttempts = 2
                BackoffCoefficient  = 2
            }
            $RetryOptions = New-DurableRetryOptions @DurableRetryOptions

            ## Native Domain and SSL expirations
            $Websites = Invoke-ActivityFunction -FunctionName 'Get-WebsiteExpirationQueue'
            if (($Websites | Measure-Object).Count -gt 0) {
                $WebsiteTasks = foreach ($Website in $Websites) {
                    if (![string]::IsNullOrEmpty($Website)) {
                        Invoke-DurableActivity -FunctionName 'Invoke-DurableProcessExpiration' -Input ($Website | ConvertTo-Json -Depth 10) -NoWait -RetryOptions $RetryOptions
                    }
                }
            }

            ## Get custom SSL tracked assets
            $Certificates = Invoke-ActivityFunction -FunctionName 'Get-CertExpirationQueue'
            if (($Certificates | Measure-Object).Count -gt 0) {
                $CertTasks = foreach ($Certificate in $Certificates) {
                    if (![string]::IsNullOrEmpty($Certificate)) {
                        Invoke-DurableActivity -FunctionName 'Invoke-DurableProcessExpiration' -Input ($Certificate | ConvertTo-Json -Depth 10) -NoWait -RetryOptions $RetryOptions
                    }
                }  
            }

            if ($WebsiteTasks) {
                Wait-ActivityFunction -Task $WebsiteTasks
            }

            if ($CertTasks) {
                Wait-ActivityFunction -Task $CertTasks
            }  
        }
        else {
            Write-Host "PSA integration is not enabled"
        }
        Write-Host 'Completed.'
    }
    catch {
        Write-Host "EXCEPTION processing certificates $($_.Exception.Message)"
    }
}

Export-ModuleMember @('Start-CertificateOrchestrator', 'Start-PsaTicketOrchestrator')
