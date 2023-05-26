function Get-HuduWebsiteExpirations {
    if (Initialize-HuduApi) {
        Get-HuduExpirations | Where-Object { $_.expirationable_type -eq 'Website' -and (Get-Date $_.date) -le (Get-Date).AddDays(30) -and (Get-Date $_.date) -ge (Get-Date) -and !$_.discarded_at }
    }
}
