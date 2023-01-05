function Get-CertificatesQueue {
    Param($Name)
    try {
        Get-HuduCertificates
    }
    catch {
        Write-Host "Error getting certificates: $($_.Exception.Message)"
    }
}

function Get-CertExpirationQueue {
    Param($Name)
    try {
        Get-HuduCertExpirations
    }
    catch {
        Write-Host "Error getting certificates: $($_.Exception.Message)"
    }
}

function Get-WebsiteExpirationQueue {
    Param($Name)
    try {
        Get-HuduWebsiteExpirations
    }
    catch {
        Write-Host "Error getting website expirations: $($_.Exception.Message)"
    }
}

function Get-PsaTicketQueue {
    Param($Name)
    try {
        Get-PsaTrackedTickets
    }
    catch {
        Write-Host "Error getting psa tickets: $($_.Exception.Message)"
    }
}

function Invoke-DurableProcessCertificate {
    Param($Certificate)

    Invoke-ProcessHuduCertificate -Certificate $Certificate
}

function Invoke-DurableProcessExpiration {
    Param($Expiration)

    Invoke-ProcessHuduExpiration -Expiration $Expiration
}

Export-ModuleMember -Function @('Get-CertificatesQueue', 'Get-CertExpirationQueue', 'Get-PsaTicketQueue', 'Get-WebsiteExpirationQueue', 'Invoke-DurableProcessCertificate', 'Invoke-DurableProcessExpiration')
