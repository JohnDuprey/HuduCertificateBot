function Test-PsaTicket {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory = $true)]
        $TicketID
    )
    switch ($env:HuduPSAIntegration) {
        'cw_manage' {
            try {
                $Ticket = Get-CWMTicket -id $TicketID -ErrorAction Stop
                return (!$Ticket.closedFlag -and $Ticket.status.name -ne $env:CWM_ResolvedStatus)
            } catch { return $false }
        }
    }
}
