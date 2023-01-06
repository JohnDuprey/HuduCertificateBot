function Start-CertificateTimer {
    param($Timer)

    if (!$env:DEV_NO_CERT_TIMER) {
        $InstanceId = Start-NewOrchestration -FunctionName 'Start-CertificateOrchestrator'
        Write-Host "Started orchestration with ID = '$InstanceId'"
    }
    else {
        Write-Host "Skipping cert timer"
    }
}

function Start-PsaTicketTimer {
    param($Timer)

    $InstanceId = Start-NewOrchestration -FunctionName 'Start-PsaTicketOrchestrator'
    Write-Host "Started orchestration with ID = '$InstanceId'"
}

Export-ModuleMember @('Start-CertificateTimer', 'Start-PsaTicketTimer')
