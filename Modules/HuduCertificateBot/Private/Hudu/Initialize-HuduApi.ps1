function Initialize-HuduApi {
    if ($env:HuduAPIKey) {
        New-HuduAPIKey -ApiKey $env:HuduAPIKey
    }
    else {
        return $false
    }
    if ($env:HuduBaseDomain) {
        New-HuduBaseURL -BaseURL $env:HuduBaseDomain
    }
    else { 
        return $false 
    }
    return $true
}