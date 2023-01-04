function New-PsaTicket {
    [cmdletbinding()]
    Param(
        $Summary,
        $Text,
        $HuduCompany
    )

    switch ($env:HuduPSAIntegration) {
        'cw_manage' {
            $CompanyID = ($HuduCompany.integrations | Where-Object { $_.integrator_name -eq 'cw_manage' }).sync_id
            if ($CompanyID) {
                $NewTicketParameters = @{
                    board              = @{ name = $env:CWM_ServiceBoard }
                    status             = @{ name = $env:CWM_NewStatus }
                    summary            = $Summary
                    company            = @{ id = $CompanyID }
                    initialDescription = $Text
                }
                try {
                    $Ticket = New-CWMTicket @NewTicketParameters
                }
                catch {}
                $x = 0

                # Handle timeouts
                while ($x -le 3 -and !$Ticket.id) {
                    $x++
                    $Backoff = $x * 5
                    Start-Sleep -Seconds $Backoff
                    $Ticket = Get-CWMTicket -condition "company/id = $CompanyID and summary = $Summary" -count 1 | Select-Object -First 1
                } 

                return $Ticket.id
            }
            else { return $false }
        }
    }
}
