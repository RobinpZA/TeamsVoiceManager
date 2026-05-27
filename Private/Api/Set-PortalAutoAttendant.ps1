function Set-PortalAutoAttendant {
    [CmdletBinding()]
    param([string]$AutoAttendantId, [hashtable]$Body)

    # Helper: build a prompt from TTS text or audio file ID
    function Build-AAPrompt {
        param([string]$Text, [string]$AudioFileId)
        if ($AudioFileId) {
            $af = Get-CsOnlineAudioFile -Identity $AudioFileId -ApplicationId OrgAutoAttendant -EA SilentlyContinue
            if ($af) { return New-CsAutoAttendantPrompt -AudioFilePrompt $af }
        }
        if ($Text) { return New-CsAutoAttendantPrompt -TextToSpeechPrompt $Text }
        return $null
    }

    # Helper: build callable entity
    function Build-CallableEntity {
        param([string]$Identity, [string]$Type, [bool]$EnableTranscription, [bool]$SuppressSystemPrompt)
        $params = @{ Identity = $Identity; Type = $Type }
        if ($Type -in 'SharedVoiceMail', 'SharedVoicemail') {
            if ($EnableTranscription)  { $params.EnableTranscription = $true }
            if ($SuppressSystemPrompt) { $params.EnableSharedVoicemailSystemPromptSuppression = $true }
        }
        return New-CsAutoAttendantCallableEntity @params
    }

    # Helper: build menu options
    function Build-MenuOptions {
        param([array]$Options)
        $built = @()
        foreach ($opt in $Options) {
            $tone = switch ($opt.key) {
                '0' { 'Tone0' } '1' { 'Tone1' } '2' { 'Tone2' } '3' { 'Tone3' }
                '4' { 'Tone4' } '5' { 'Tone5' } '6' { 'Tone6' } '7' { 'Tone7' }
                '8' { 'Tone8' } '9' { 'Tone9' } '*' { 'ToneStar' } '#' { 'TonePound' }
                default { 'Automatic' }
            }
            switch ($opt.action) {
                'DisconnectCall'         { $built += New-CsAutoAttendantMenuOption -Action DisconnectCall -DtmfResponse $tone }
                'TransferCallToOperator' { $built += New-CsAutoAttendantMenuOption -Action TransferCallToOperator -DtmfResponse $tone }
                'Announcement' {
                    $p = Build-AAPrompt -Text $opt.announcementText -AudioFileId $opt.announcementAudioFileId
                    if ($p) { $built += New-CsAutoAttendantMenuOption -Action Announcement -DtmfResponse $tone -Prompt $p }
                }
                default {
                    if ($opt.targetId) {
                        $tType = switch ($opt.targetType) {
                            'User'                { 'User' }
                            'ApplicationEndpoint' { 'ApplicationEndpoint' }
                            'ExternalPstn'        { 'ExternalPstn' }
                            'SharedVoicemail'     { 'SharedVoiceMail' }
                            default               { 'ApplicationEndpoint' }
                        }
                        $entity = Build-CallableEntity -Identity $opt.targetId -Type $tType `
                            -EnableTranscription ([bool]$opt.enableTranscription) `
                            -SuppressSystemPrompt ([bool]$opt.suppressSystemPrompt)
                        $built += New-CsAutoAttendantMenuOption -Action TransferCallToTarget -DtmfResponse $tone -CallTarget $entity
                    }
                }
            }
        }
        return $built
    }

    # Helper: build a complete call flow
    function Build-CallFlow {
        param([string]$FlowName, [hashtable]$FlowDef)
        $greetings = @()
        $g = Build-AAPrompt -Text $FlowDef.greetingText -AudioFileId $FlowDef.greetingAudioFileId
        if ($g) { $greetings += $g }

        $menuPrompt = Build-AAPrompt -Text $FlowDef.menuPromptText -AudioFileId $FlowDef.menuPromptAudioFileId

        $opts = if ($FlowDef.menuOptions -and $FlowDef.menuOptions.Count -gt 0) {
            Build-MenuOptions -Options $FlowDef.menuOptions
        } else {
            @(New-CsAutoAttendantMenuOption -Action DisconnectCall -DtmfResponse Automatic)
        }

        $menuParams = @{ Name = "$FlowName Menu"; MenuOptions = $opts }
        if ($menuPrompt) { $menuParams.Prompt = $menuPrompt }
        if ($FlowDef.enableDialByName) {
            $menuParams.EnableDialByName = $true
            $menuParams.DirectorySearchMethod = if ($FlowDef.directorySearchMethod -in 'ByExtension','ByName') { $FlowDef.directorySearchMethod } else { 'ByName' }
        }
        $menu = New-CsAutoAttendantMenu @menuParams

        $cfParams = @{ Name = $FlowName; Menu = $menu }
        if ($greetings.Count -gt 0) { $cfParams.Greetings = $greetings }
        return New-CsAutoAttendantCallFlow @cfParams
    }

    try {
        # Retrieve the existing AA object so we can do a full replace
        $aa = Get-CsAutoAttendant -Identity $AutoAttendantId -EA Stop

        # ── Simple scalar fields ───────────────────────────────────────────────────
        if ($Body.name)     { $aa.Name       = $Body.name }
        if ($Body.language) { $aa.LanguageId = $Body.language }
        if ($Body.timeZone) { $aa.TimeZoneId = $Body.timeZone }
        if ($null -ne $Body.enableVoiceResponse) { $aa.EnableVoiceResponse = [bool]$Body.enableVoiceResponse }

        # ── Operator ──────────────────────────────────────────────────────────────
        if ($Body.operatorId) {
            $opType = switch ($Body.operatorType) {
                'User'                { 'User' }
                'ApplicationEndpoint' { 'ApplicationEndpoint' }
                'ExternalPstn'        { 'ExternalPstn' }
                default               { 'User' }
            }
            $aa.Operator = New-CsAutoAttendantCallableEntity -Identity $Body.operatorId -Type $opType
        }

        # ── Default (business hours) call flow ────────────────────────────────────
        if ($Body.defaultFlow) {
            $aa.DefaultCallFlow = Build-CallFlow -FlowName ($aa.Name + ' Default Flow') -FlowDef $Body.defaultFlow
        }

        # ── After-hours and holidays ──────────────────────────────────────────────
        # Rebuild all associations and extra flows when either is supplied
        if ($Body.afterHours -or ($Body.holidays -and $Body.holidays.Count -gt 0)) {
            $associations = @()
            $extraFlows   = @()

            if ($Body.afterHours) {
                $ah = $Body.afterHours
                $scheduleParams = @{
                    Name                    = ($aa.Name + ' Business Hours Schedule')
                    WeeklyRecurrentSchedule = $true
                    Complement              = $true
                }
                $dayMap = @{
                    monday='MondayHours'; tuesday='TuesdayHours'; wednesday='WednesdayHours'
                    thursday='ThursdayHours'; friday='FridayHours'; saturday='SaturdayHours'; sunday='SundayHours'
                }
                foreach ($day in ($ah.businessHours ?? @{}).Keys) {
                    $bh = $ah.businessHours[$day]
                    if ($bh.start -and $bh.end) {
                        $tr = New-CsOnlineTimeRange -Start $bh.start -End $bh.end
                        $scheduleParams[$dayMap[$day]] = @($tr)
                    }
                }
                $schedule  = New-CsOnlineSchedule @scheduleParams
                $ahFlowDef = if ($ah.flow) { $ah.flow } else { $ah }
                $ahFlow    = Build-CallFlow -FlowName ($aa.Name + ' After Hours Flow') -FlowDef $ahFlowDef
                $extraFlows   += $ahFlow
                $associations += New-CsAutoAttendantCallHandlingAssociation -Type AfterHours -ScheduleId $schedule.Id -CallFlowId $ahFlow.Id
            }

            if ($Body.holidays -and $Body.holidays.Count -gt 0) {
                foreach ($holiday in $Body.holidays) {
                    $dtRanges = @()
                    foreach ($dr in $holiday.dateRanges) {
                        $dtRanges += New-CsOnlineDateTimeRange -Start $dr.start -End $dr.end
                    }
                    $holSchedule = New-CsOnlineSchedule -Name ($holiday.name + ' Schedule') -FixedSchedule -DateTimeRanges $dtRanges
                    $holFlowDef  = if ($holiday.flow) { $holiday.flow } else { $holiday }
                    $holFlow     = Build-CallFlow -FlowName ($holiday.name + ' Flow') -FlowDef $holFlowDef
                    $extraFlows   += $holFlow
                    $associations += New-CsAutoAttendantCallHandlingAssociation -Type Holiday -ScheduleId $holSchedule.Id -CallFlowId $holFlow.Id
                }
            }

            $aa.CallFlows = $extraFlows
            $aa.CallHandlingAssociations = $associations
        }

        # ── Dial scope ────────────────────────────────────────────────────────────
        if ($Body.inclusionScopeGroupIds -and $Body.inclusionScopeGroupIds.Count -gt 0) {
            $aa.InclusionScope = New-CsAutoAttendantDialScope -GroupScope -GroupIds $Body.inclusionScopeGroupIds
        }
        if ($Body.exclusionScopeGroupIds -and $Body.exclusionScopeGroupIds.Count -gt 0) {
            $aa.ExclusionScope = New-CsAutoAttendantDialScope -GroupScope -GroupIds $Body.exclusionScopeGroupIds
        }

        # ── Apply ─────────────────────────────────────────────────────────────────
        Set-CsAutoAttendant -Instance $aa -EA Stop

        # ── Resource account re-association ───────────────────────────────────────
        $raIds = @()
        if ($Body.resourceAccountId)  { $raIds += $Body.resourceAccountId }
        if ($Body.resourceAccountIds) { $raIds += $Body.resourceAccountIds }
        if ($raIds.Count -gt 0) {
            $uniqueRaIds = $raIds | Select-Object -Unique
            try {
                New-CsOnlineApplicationInstanceAssociation -Identities $uniqueRaIds -ConfigurationId $AutoAttendantId -ConfigurationType AutoAttendant -EA Stop
                Write-AuditEntry -Action 'AssociateRA_AA' -Target ($uniqueRaIds -join ',') -Result 'Success' -Detail $aa.Name
            } catch {
                Write-AuditEntry -Action 'AssociateRA_AA' -Target ($uniqueRaIds -join ',') -Result 'Error' -Detail $_.Exception.Message
            }
        }

        Write-AuditEntry -Action 'UpdateAA' -Target $AutoAttendantId -Result 'Success' -Detail $aa.Name
        return @{ success = $true; id = $AutoAttendantId }
    } catch {
        Write-AuditEntry -Action 'UpdateAA' -Target $AutoAttendantId -Result 'Error' -Detail $_.Exception.Message
        return @{ success = $false; error = $_.Exception.Message }
    }
}
