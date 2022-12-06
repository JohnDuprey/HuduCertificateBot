function Start-SubscriptionsTimer {
    param($Timer)

    $InstanceId = Start-NewOrchestration -FunctionName 'Start-SubscriptionsOrchestrator'
    Write-Host "Started orchestration with ID = '$InstanceId'"
}

Export-ModuleMember @('Start-SubscriptionsTimer')
