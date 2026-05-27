function Get-PortalAutoAttendantFlow {
    [CmdletBinding()]
    param([string]$AutoAttendantId)

    # Resolve a call target ID to a display name.
    # ExternalPstn IDs are phone numbers — return them directly.
    # ApplicationEndpoint / User IDs are GUIDs resolved via Get-CsOnlineUser.
    function Resolve-AATargetName {
        param([string]$Id, [string]$Type)
        if (-not $Id) { return $null }
        if ($Type -eq 'ExternalPstn' -or $Id -match '^tel:' -or $Id -match '^\+\d') {
            return $Id -replace '^tel:', ''
        }
        try {
            $u = Get-CsOnlineUser -Identity $Id -EA SilentlyContinue
            if ($u) { return $u.DisplayName }
        } catch {}
        return $null
    }

    function ConvertTo-FlowDetail {
        param($Flow)
        if ($null -eq $Flow) { return $null }

        # Greeting
        $greetingType = 'None'
        $greetingText = $null
        $greeting = $Flow.Greetings | Select-Object -First 1
        if ($greeting) {
            if ($null -ne $greeting.TextToSpeechPrompt -and $greeting.TextToSpeechPrompt -ne '') {
                $greetingType = 'TextToSpeech'
                $greetingText = $greeting.TextToSpeechPrompt
            } elseif ($null -ne $greeting.AudioFilePrompt) {
                $greetingType = 'AudioFile'
            } else {
                $greetingType = 'Silence'
            }
        }

        # Menu
        $menuPromptText   = $null
        $enableDialByName = $false
        $directoryMethod  = $null
        $menuOptions      = @()
        $menu = $Flow.Menu
        if ($menu) {
            $menuPrompt = $menu.Prompts | Select-Object -First 1
            if ($menuPrompt) { $menuPromptText = $menuPrompt.TextToSpeechPrompt }
            $enableDialByName = $menu.EnableDialByName -eq $true
            $directoryMethod  = [string]$menu.DirectorySearchMethod
            $menuOptions = @($menu.MenuOptions | ForEach-Object {
                $target = $_.CallTarget
                $tType  = if ($target) { [string]$target.Type } else { $null }
                $tId    = if ($target) { [string]$target.Id   } else { $null }
                @{
                    dtmfResponse   = [string]$_.DtmfResponse
                    voiceResponses = @($_.VoiceResponses)
                    action         = [string]$_.Action
                    targetType     = $tType
                    targetId       = $tId
                    targetName     = Resolve-AATargetName -Id $tId -Type $tType
                }
            })
        }

        return @{
            id               = [string]$Flow.Id
            name             = $Flow.Name
            greetingType     = $greetingType
            greetingText     = $greetingText
            menuPromptText   = $menuPromptText
            enableDialByName = $enableDialByName
            directoryMethod  = $directoryMethod
            menuOptions      = $menuOptions
        }
    }

    try {
        $aa = Get-CsAutoAttendant -Identity $AutoAttendantId -EA Stop

        # Default call flow
        $defaultFlow = ConvertTo-FlowDetail $aa.DefaultCallFlow

        # After-hours call flow + schedule
        $afterHoursFlow = $null
        $scheduleHours  = $null
        $ahAssoc = $aa.CallHandlingAssociations |
            Where-Object { [string]$_.Type -eq 'AfterHours' -and $_.Enabled } |
            Select-Object -First 1

        if ($ahAssoc) {
            $ahCf = $aa.CallFlows | Where-Object { $_.Id -eq $ahAssoc.CallFlowId } | Select-Object -First 1
            if ($ahCf) { $afterHoursFlow = ConvertTo-FlowDetail $ahCf }

            try {
                $sched = Get-CsOnlineSchedule -Id $ahAssoc.ScheduleId -EA SilentlyContinue
                if ($sched -and $sched.WeeklyRecurrentSchedule) {
                    $wrs = $sched.WeeklyRecurrentSchedule
                    $scheduleHours = @{
                        monday    = @($wrs.MondayHours    | ForEach-Object { "$($_.Start)-$($_.End)" })
                        tuesday   = @($wrs.TuesdayHours   | ForEach-Object { "$($_.Start)-$($_.End)" })
                        wednesday = @($wrs.WednesdayHours | ForEach-Object { "$($_.Start)-$($_.End)" })
                        thursday  = @($wrs.ThursdayHours  | ForEach-Object { "$($_.Start)-$($_.End)" })
                        friday    = @($wrs.FridayHours    | ForEach-Object { "$($_.Start)-$($_.End)" })
                        saturday  = @($wrs.SaturdayHours  | ForEach-Object { "$($_.Start)-$($_.End)" })
                        sunday    = @($wrs.SundayHours    | ForEach-Object { "$($_.Start)-$($_.End)" })
                    }
                }
            } catch { Write-Verbose "GetAAFlow/Schedule: $_" }
        }

        # Holiday flows
        $holidayFlows = @()
        $holidayAssocs = $aa.CallHandlingAssociations | Where-Object { [string]$_.Type -eq 'Holiday' }
        foreach ($hAssoc in $holidayAssocs) {
            $hCf = $aa.CallFlows | Where-Object { $_.Id -eq $hAssoc.CallFlowId } | Select-Object -First 1
            if ($hCf) {
                $hSchedName = ''
                try {
                    $hSched = Get-CsOnlineSchedule -Id $hAssoc.ScheduleId -EA SilentlyContinue
                    if ($hSched) { $hSchedName = $hSched.Name }
                } catch {}
                $holidayFlows += @{
                    scheduleName = $hSchedName
                    enabled      = $hAssoc.Enabled
                    flow         = ConvertTo-FlowDetail $hCf
                }
            }
        }

        # Operator
        $operatorInfo = $null
        if ($aa.Operator) {
            $operatorInfo = @{
                type     = [string]$aa.Operator.Type
                identity = [string]$aa.Operator.Identity
            }
        }

        return @{
            id             = $aa.Identity
            name           = $aa.Name
            language       = $aa.LanguageId
            timeZone       = $aa.TimeZoneId
            defaultFlow    = $defaultFlow
            afterHoursFlow = $afterHoursFlow
            scheduleHours  = $scheduleHours
            holidayFlows   = $holidayFlows
            operator       = $operatorInfo
        }
    } catch {
        return @{ error = $_.Exception.Message }
    }
}
