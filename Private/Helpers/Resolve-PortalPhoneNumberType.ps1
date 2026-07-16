function Resolve-PortalPhoneNumberType {
    <#
    .SYNOPSIS
        Resolves the Teams-side provisioning type for a phone number.
    .DESCRIPTION
        Set-CsPhoneNumberAssignment and Remove-CsPhoneNumberAssignment reject the call with a BadRequest
        if -PhoneNumberType doesn't match how the number is actually provisioned (DirectRouting, CallingPlan,
        OperatorConnect, etc). This looks up the real type instead of assuming DirectRouting.
    .PARAMETER PhoneNumber
        The E.164-formatted number to look up.
    .EXAMPLE
        Resolve-PortalPhoneNumberType -PhoneNumber '+27101234567'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$PhoneNumber
    )
    $assignment = Get-CsPhoneNumberAssignment -TelephoneNumber $PhoneNumber -EA Stop
    if (-not $assignment) {
        throw "Phone number '$PhoneNumber' was not found in the Teams phone number inventory"
    }
    return ($assignment | Select-Object -First 1).NumberType
}
