function Test-TeamsPhoneLicense {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$UserId
    )
    try {
        $licenses = Get-MgUserLicenseDetail -UserId $UserId -ErrorAction Stop
        return [bool]($licenses | Where-Object {
            $_.SkuPartNumber -eq 'MCOEV' -or $_.SkuPartNumber -like '*PHONE*'
        })
    } catch {
        return $false
    }
}
