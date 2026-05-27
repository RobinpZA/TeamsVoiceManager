function Get-PortalSupportedTimeZones {
    [CmdletBinding()]
    param()
    try {
        $tzs = Get-CsAutoAttendantSupportedTimeZone -EA SilentlyContinue
        return @{ timezones = @($tzs | ForEach-Object { @{id=$_.Id;displayName=$_.DisplayName} }) }
    } catch {
        return @{ timezones = @(
            @{id='South Africa Standard Time';displayName='(UTC+02:00) Harare, Pretoria'}
            @{id='GMT Standard Time';displayName='(UTC+00:00) Dublin, Edinburgh, Lisbon, London'}
            @{id='Eastern Standard Time';displayName='(UTC-05:00) Eastern Time (US & Canada)'}
        ) }
    }
}
