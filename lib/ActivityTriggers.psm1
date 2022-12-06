function Get-CertificatesQueue {
    Param($Name)
    try {
        Get-HuduCertificates
    }
    catch {
        Write-Host "Error getting certificates: $($_.Exception.Message)"
    }
}

function Invoke-DurableProcessCertificate {
    Param($Certificate)

    Invoke-ProcessHuduCertificate -Certificate $Certificate
}

Export-ModuleMember -Function @('Get-CertificatesQueue', 'Invoke-DurableProcessCertificate')
