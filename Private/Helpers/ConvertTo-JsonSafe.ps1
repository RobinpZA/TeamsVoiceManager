function ConvertTo-JsonSafe {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [object]$InputObject,

        [int]$Depth = 10
    )
    process {
        try {
            $InputObject | ConvertTo-Json -Depth $Depth -Compress -ErrorAction Stop
        } catch {
            try {
                $InputObject | ConvertTo-Json -Depth 3 -Compress -ErrorAction Stop
            } catch {
                '{"error":"JSON serialization failed"}'
            }
        }
    }
}
