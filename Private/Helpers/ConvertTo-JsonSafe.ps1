function ConvertTo-JsonSafe {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [object]$InputObject,

        [int]$Depth = 10
    )
    begin { $items = [System.Collections.Generic.List[object]]::new() }
    process { $items.Add($InputObject) }
    end {
        # Collapse to the single piped object when there was only one — wrapping every
        # call site's output in an array would break existing callers that expect an object.
        # A count other than 1 means a cmdlet upstream leaked extra pipeline output; surfacing
        # it as a JSON array keeps the response valid instead of concatenating raw JSON fragments.
        $value = if ($items.Count -eq 1) { $items[0] } else { , $items.ToArray() }
        try {
            $value | ConvertTo-Json -Depth $Depth -Compress -ErrorAction Stop
        } catch {
            try {
                $value | ConvertTo-Json -Depth 3 -Compress -ErrorAction Stop
            } catch {
                '{"error":"JSON serialization failed"}'
            }
        }
    }
}
