function Initialize-PsaApi {
    [cmdletbinding()]
    Param()

    switch ($env:HuduPSAIntegration) {
        "cw_manage" {
            Import-Module ConnectWiseManageAPI
            $CWMConnectionInfo = @{
                Server     = $env:CWM_Server
                Company    = $env:CWM_CompanyID
                pubkey     = $env:CWM_PublicKey
                privatekey = $env:CWM_PrivateKey
                clientid   = $env:CWM_ClientID
            }
            Connect-CWM @CWMConnectionInfo
        }
    }
}
