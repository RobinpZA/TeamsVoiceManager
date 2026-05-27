@{
    Severity     = @('Error', 'Warning', 'Information')
    ExcludeRules = @(
        # Portal uses Write-Host intentionally — it is an interactive console tool
        'PSAvoidUsingWriteHost',
        # All state-changing portal API functions deliberately bypass ShouldProcess;
        # they are invoked by the HTTP router, not interactively by end users
        'PSUseShouldProcessForStateChangingFunctions',
        # Portal API functions use plural nouns (e.g. Get-PortalAutoAttendants) to reflect
        # the resource collections they return — renaming would break the HTTP router
        'PSUseSingularNouns',
        # Module requires PowerShell 7.2 which reads UTF-8 without BOM natively;
        # BOM is not required and is excluded to avoid editor encoding noise
        'PSUseBOMForUnicodeEncodedFile'
    )
}
