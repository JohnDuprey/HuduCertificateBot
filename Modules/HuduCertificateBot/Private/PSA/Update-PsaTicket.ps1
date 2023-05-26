function Update-PsaTicket {
    [cmdletbinding(SupportsShouldProcess)]
    Param(
        $Text,
        $TicketID,
        [switch]$Resolve
    )
    switch ($env:HuduPSAIntegration) {
        'cw_manage' {
            try {
                if ($Text) {
                    if ($PSCmdlet.ShouldProcess($TicketID)) {
                        New-CWMTicketNote -parentId $TicketID -text $Text -detailDescriptionFlag $true -ErrorAction Stop
                    }
                }
                if ($Resolve.IsPresent) {
                    $UpdateParam = @{
                        ID        = $TicketID
                        Operation = 'replace'
                        Path      = 'status'
                        Value     = @{name = $env:CWM_ResolvedStatus }
                    }
                    $x = 0
                    $Resolved = $false
                    do {
                        try {
                            $x++
                            if ($PSCmdlet.ShouldProcess($TicketID)) {
                                Update-CWMTicket @UpdateParam -ErrorAction Stop
                                $Resolved = $true
                            }
                        } catch {
                            $Backoff = 5 * $x
                            Start-Sleep -Seconds $Backoff
                        }
                    } while ($x -lt 4 -and !$Resolved)

                    if (!$Resolved) {
                        throw 'Could not resolve ticket'
                    }
                }
            } catch {
                throw
            }
        }
    }
}
