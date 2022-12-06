function Send-SlackInteraction {
    param($Request, $TriggerMetadata)
    
    # Send HTTP 200 OK and process interaction
    Push-OutputBinding -Name response -Value ([HttpResponseContext]@{
            StatusCode = [System.Net.HttpStatusCode]::OK
        })

    if (Test-SlackEventSignature -Request $Request) {
        Invoke-ProcessSlackInteraction -Request $Request
    }
}

function Send-SlackEvent {
    param($Request, $TriggerMetadata)
    
    # Ingest Slack event and either respond with challenge or send HTTP 200 OK and push to queue for processing
    switch ($Request.Body.type) {
        'url_verification' {
            Push-OutputBinding -Name response -Value ([HttpResponseContext]@{
                    StatusCode = [System.Net.HttpStatusCode]::OK
                    Body       = $Request.Body.challenge
                })
        }
        default {
            Push-OutputBinding -Name response -Value ([HttpResponseContext]@{
                    StatusCode = [System.Net.HttpStatusCode]::OK
                })
            Push-OutputBinding -Name Event -value $Request
        }
    }
}

Export-ModuleMember -Function @('Send-SlackInteraction', 'Send-SlackEvent')
