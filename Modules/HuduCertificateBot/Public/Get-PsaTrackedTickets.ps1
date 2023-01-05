function Get-PsaTrackedTickets {
    $PsaTickets = @{
        TableName    = 'PsaTicket'
        PartitionKey = 'Ticket'
    }
    Get-TableData @PsaTickets
}
