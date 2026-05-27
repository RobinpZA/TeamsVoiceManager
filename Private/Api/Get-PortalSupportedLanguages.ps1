function Get-PortalSupportedLanguages {
    [CmdletBinding()]
    param()
    try {
        $langs = Get-CsAutoAttendantSupportedLanguage -EA SilentlyContinue
        return @{ languages = @($langs | ForEach-Object { @{id=$_.Id;displayName=$_.DisplayName} }) }
    } catch {
        return @{ languages = @(
            @{id='en-ZA';displayName='English (South Africa)'}
            @{id='en-US';displayName='English (United States)'}
            @{id='en-GB';displayName='English (United Kingdom)'}
            @{id='af-ZA';displayName='Afrikaans (South Africa)'}
        ) }
    }
}
