function Get-PortalAutoAttendants {
    [CmdletBinding()]
    param()
    try {
        $aas = Get-CsAutoAttendant -EA SilentlyContinue
        $result = @($aas | ForEach-Object {
            $aa = $_

            # Operator details
            $operatorInfo = $null
            if ($aa.Operator) {
                $operatorInfo = @{
                    identity = $aa.Operator.Identity
                    type     = [string]$aa.Operator.Type
                }
            }

            # Call handling associations (after-hours + holidays)
            $handlingAssociations = @($aa.CallHandlingAssociations | ForEach-Object {
                @{
                    type       = [string]$_.Type
                    scheduleId = $_.ScheduleId
                    callFlowId = $_.CallFlowId
                    enabled    = $_.Enabled
                }
            })

            # Extra call flows (after-hours, holiday flows)
            $callFlows = @($aa.CallFlows | ForEach-Object {
                @{
                    id   = $_.Id
                    name = $_.Name
                }
            })

            # Dial scope (inclusion/exclusion group IDs)
            $inclusionGroups = if ($aa.InclusionScope) {
                @($aa.InclusionScope.GroupIds | ForEach-Object { $_.ToString() })
            } else { @() }

            $exclusionGroups = if ($aa.ExclusionScope) {
                @($aa.ExclusionScope.GroupIds | ForEach-Object { $_.ToString() })
            } else { @() }

            # Associated resource accounts
            $associatedRAs = @()
            try {
                $assoc = Get-CsOnlineApplicationInstanceAssociation -Identity $aa.Identity -EA SilentlyContinue
                if ($assoc) {
                    $associatedRAs = @($assoc | ForEach-Object { $_.ApplicationInstance })
                }
            } catch { Write-Verbose "GetAutoAttendants/Association ($($aa.Identity)): $_" }

            @{
                id                       = $aa.Identity
                name                     = $aa.Name
                language                 = $aa.LanguageId
                timeZone                 = $aa.TimeZoneId
                voiceResponseEnabled     = $aa.EnableVoiceResponse
                defaultCallFlowName      = $aa.DefaultCallFlow.Name
                operator                 = $operatorInfo
                callHandlingAssociations = $handlingAssociations
                callFlows                = $callFlows
                inclusionScopeGroupIds   = $inclusionGroups
                exclusionScopeGroupIds   = $exclusionGroups
                associatedResourceAccounts = $associatedRAs
                holidayCount             = @($handlingAssociations | Where-Object { $_.type -eq 'Holiday' }).Count
                hasAfterHours            = ($handlingAssociations | Where-Object { $_.type -eq 'AfterHours' }).Count -gt 0
            }
        })
        return @{ autoAttendants = $result }
    } catch {
        return @{ autoAttendants = @(); error = $_.Exception.Message }
    }
}
