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
            $Company = Get-CWMCompany -id $CompanyID
            if ($CompanyID -and !$Company.inactiveFlag) {
                $NewTicketParameters = @{
                    board              = @{ name = $env:CWM_ServiceBoard }
                    status             = @{ name = $env:CWM_NewStatus }
                    summary            = $Summary
                    company            = @{ id = $CompanyID }
                    initialDescription = $Text
                }

                if ($env:CWM_ServiceType) {
                    $NewTicketParameters.type = @{ name = $env:CWM_ServiceType }
                }

                if ($env:CWM_ServiceSubType) {
                    $NewTicketParameters.subType = @{ name = $env:CWM_ServiceSubType }
                }

                try {
                    $Ticket = New-CWMTicket @NewTicketParameters
                } catch {}
                $x = 0

                # Handle timeouts
                while ($x -le 3 -and !$Ticket.id) {
                    $x++
                    $Backoff = $x * 5
                    Start-Sleep -Seconds $Backoff
                    $Ticket = Get-CWMTicket -condition "company/id = $CompanyID and summary = $Summary" -count 1 | Select-Object -First 1
                }

                return $Ticket.id
            } else { return $false }
        }
    }
}
