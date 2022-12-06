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

Export-ModuleMember @('Start-CertificateOrchestrator')
