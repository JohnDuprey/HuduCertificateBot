function Update-PsaTicket {
    [cmdletbinding()]
    Param(
        $Text,
        $TicketID,
        [switch]$Resolve
    )
    switch ($env:HuduPSAIntegration) {
        'cw_manage' {
            try {
                if ($Text) {
                    New-CWMTicketNote -parentId $TicketId -text $Text -detailDescriptionFlag $true -ErrorAction Stop
                }
                if ($Resolve.IsPresent) {
                    $UpdateParam = @{
                        ID        = $TicketID
                        Operation = 'replace'
                        Path      = 'status'
                        Value     = ${name = $env:CWM_ResolvedStatus}
                    }
                    Update-CWMTicket @UpdateParam -ErrorAction Stop
                }
            }   
            catch {
                throw
            }
        }
    }
}
