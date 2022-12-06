function Start-CertificateTimer {
    param($Timer)

    $InstanceId = Start-NewOrchestration -FunctionName 'Start-CertificateOrchestrator'
    Write-Host "Started orchestration with ID = '$InstanceId'"
}

Export-ModuleMember @('Start-CertificateTimer')
