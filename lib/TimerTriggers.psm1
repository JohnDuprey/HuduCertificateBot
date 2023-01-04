function Start-CertificateTimer {
    param($Timer)

    $InstanceId = Start-NewOrchestration -FunctionName 'Start-CertificateOrchestrator'
    Write-Host "Started orchestration with ID = '$InstanceId'"
}

function Start-PsaTicketTimer {
    param($Timer)

    $InstanceId = Start-NewOrchestration -FunctionName 'Start-PsaTicketOrchestrator'
    Write-Host "Started orchestration with ID = '$InstanceId'"
}

Export-ModuleMember @('Start-CertificateTimer', 'Start-PsaTicketTimer')
