function Format-PhoneNumber {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Number
    )
    $cleaned = $Number.Trim()
    if ($cleaned -match '^\+\d{10,15}$') { return $cleaned }
    if ($cleaned -match '^0(\d{9})$')    { return "+27$($Matches[1])" }
    if ($cleaned -match '^27(\d{9})$')   { return "+$cleaned" }
    Write-Warning "Phone number '$Number' format unrecognised. Returning as-is."
    return $cleaned
}
