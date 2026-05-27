function Get-AvailableLicenses {
    [CmdletBinding()]
    param()
    try {
        $skus = Get-MgSubscribedSku -ErrorAction Stop
        return @(
            $skus |
                Where-Object { $_.SkuPartNumber -in @('MCOEV', 'PHONESYSTEM_VIRTUALUSER', 'SPE_E5', 'SPE_E3') } |
                ForEach-Object {
                    @{
                        skuPartNumber = $_.SkuPartNumber
                        skuId         = $_.SkuId
                        total         = $_.PrepaidUnits.Enabled
                        consumed      = $_.ConsumedUnits
                        available     = $_.PrepaidUnits.Enabled - $_.ConsumedUnits
                    }
                }
        )
    } catch {
        return @()
    }
}
