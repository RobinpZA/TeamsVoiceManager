function Invoke-PortalDisconnect {
    [CmdletBinding()]
    param()
    Disconnect-TeamsVoiceServices
    return @{ success = $true }
}
