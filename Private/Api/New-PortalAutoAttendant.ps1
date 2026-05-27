function New-PortalAutoAttendant {
    [CmdletBinding()]
    param([hashtable]$Body)

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

    # Helper: build callable entity, supporting SharedVoicemail type
    function Build-CallableEntity {
        param([string]$Identity, [string]$Type, [bool]$EnableTranscription, [bool]$SuppressSystemPrompt)
        $params = @{ Identity = $Identity; Type = $Type }
        if ($Type -in 'SharedVoiceMail', 'SharedVoicemail') {
            if ($EnableTranscription)  { $params.EnableTranscription = $true }
            if ($SuppressSystemPrompt) { $params.EnableSharedVoicemailSystemPromptSuppression = $true }
        }
        return New-CsAutoAttendantCallableEntity @params
    }

    # Helper: build menu options array from a structured options list
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
                'DisconnectCall' {
                    $built += New-CsAutoAttendantMenuOption -Action DisconnectCall -DtmfResponse $tone
                }
                'TransferCallToOperator' {
                    $built += New-CsAutoAttendantMenuOption -Action TransferCallToOperator -DtmfResponse $tone
                }
                'Announcement' {
                    $prompt = Build-AAPrompt -Text $opt.announcementText -AudioFileId $opt.announcementAudioFileId
                    if ($prompt) {
                        $built += New-CsAutoAttendantMenuOption -Action Announcement -DtmfResponse $tone -Prompt $prompt
                    }
                }
                default {
                    # TransferCallToTarget — supports User, ApplicationEndpoint, ExternalPstn, SharedVoicemail
                    if ($opt.targetId) {
                        $targetType = switch ($opt.targetType) {
                            'User'                { 'User' }
                            'ApplicationEndpoint' { 'ApplicationEndpoint' }
                            'ExternalPstn'        { 'ExternalPstn' }
                            'SharedVoicemail'     { 'SharedVoiceMail' }
                            default               { 'ApplicationEndpoint' }
                        }
                        $entity = Build-CallableEntity -Identity $opt.targetId -Type $targetType `
                            -EnableTranscription ([bool]$opt.enableTranscription) `
                            -SuppressSystemPrompt ([bool]$opt.suppressSystemPrompt)
                        $built += New-CsAutoAttendantMenuOption -Action TransferCallToTarget -DtmfResponse $tone -CallTarget $entity
                    }
                }
            }
        }
        return $built
    }

    # Helper: build a complete call flow from a flow definition hashtable
    function Build-CallFlow {
        param([string]$FlowName, [hashtable]$FlowDef)
        # Greeting (welcome message before menu)
        $greetings = @()
        $g = Build-AAPrompt -Text $FlowDef.greetingText -AudioFileId $FlowDef.greetingAudioFileId
        if ($g) { $greetings += $g }

        # Menu prompt (read out menu choices)
        $menuPrompt = Build-AAPrompt -Text $FlowDef.menuPromptText -AudioFileId $FlowDef.menuPromptAudioFileId

        # Menu options
        $opts = if ($FlowDef.menuOptions -and $FlowDef.menuOptions.Count -gt 0) {
            Build-MenuOptions -Options $FlowDef.menuOptions
        } else {
            @(New-CsAutoAttendantMenuOption -Action DisconnectCall -DtmfResponse Automatic)
        }

        # Menu
        $menuParams = @{ Name = "$FlowName Menu"; MenuOptions = $opts }
        if ($menuPrompt) { $menuParams.Prompt = $menuPrompt }
        if ($FlowDef.enableDialByName) {
            $menuParams.EnableDialByName = $true
            $searchMethod = if ($FlowDef.directorySearchMethod -in 'ByExtension','ByName') { $FlowDef.directorySearchMethod } else { 'ByName' }
            $menuParams.DirectorySearchMethod = $searchMethod
        }
        $menu = New-CsAutoAttendantMenu @menuParams

        # Call flow
        $cfParams = @{ Name = $FlowName; Menu = $menu }
        if ($greetings.Count -gt 0) { $cfParams.Greetings = $greetings }
        return New-CsAutoAttendantCallFlow @cfParams
    }

    try {
        # ── Operator ──────────────────────────────────────────────────────────────
        $operatorEntity = $null
        if ($Body.operatorId) {
            $opType = switch ($Body.operatorType) {
                'User'                { 'User' }
                'ApplicationEndpoint' { 'ApplicationEndpoint' }
                'ExternalPstn'        { 'ExternalPstn' }
                default               { 'User' }
            }
            $operatorEntity = New-CsAutoAttendantCallableEntity -Identity $Body.operatorId -Type $opType
        }

        # ── Default (business hours) call flow ────────────────────────────────────
        $defaultFlow = Build-CallFlow -FlowName ($Body.name + ' Default Flow') -FlowDef (
            if ($Body.defaultFlow) { $Body.defaultFlow } else { $Body }
        )

        # ── AA base params ────────────────────────────────────────────────────────
        $aaParams = @{
            Name            = $Body.name
            DefaultCallFlow = $defaultFlow
            LanguageId      = ($Body.language ?? 'en-ZA')
            TimeZoneId      = ($Body.timeZone ?? 'South Africa Standard Time')
        }
        if ($Body.enableVoiceResponse) { $aaParams.EnableVoiceResponse = $true }
        if ($operatorEntity)            { $aaParams.Operator = $operatorEntity }

        # ── After-hours handling ──────────────────────────────────────────────────
        $associations = @()
        $extraFlows   = @()

        if ($Body.afterHours) {
            $ah = $Body.afterHours
            # Build weekly recurrent schedule (complement = after-hours is the complement of business hours)
            $scheduleParams = @{
                Name                   = ($Body.name + ' Business Hours Schedule')
                WeeklyRecurrentSchedule = $true
                Complement             = $true
            }
            $dayMap = @{
                monday    = 'MondayHours';    tuesday   = 'TuesdayHours'
                wednesday = 'WednesdayHours'; thursday  = 'ThursdayHours'
                friday    = 'FridayHours';    saturday  = 'SaturdayHours'
                sunday    = 'SundayHours'
            }
            foreach ($day in ($ah.businessHours ?? @{}).Keys) {
                $bh = $ah.businessHours[$day]
                if ($bh.start -and $bh.end) {
                    $tr = New-CsOnlineTimeRange -Start $bh.start -End $bh.end
                    $scheduleParams[$dayMap[$day]] = @($tr)
                }
            }
            $schedule = New-CsOnlineSchedule @scheduleParams

            $ahFlowDef = if ($ah.flow) { $ah.flow } else { $ah }
            $ahFlow    = Build-CallFlow -FlowName ($Body.name + ' After Hours Flow') -FlowDef $ahFlowDef

            $extraFlows   += $ahFlow
            $associations += New-CsAutoAttendantCallHandlingAssociation -Type AfterHours -ScheduleId $schedule.Id -CallFlowId $ahFlow.Id
        }

        # ── Holiday handling ──────────────────────────────────────────────────────
        # Body.holidays: array of { name, dateRanges: [{start,end}], flow: {greetingText,...} }
        if ($Body.holidays -and $Body.holidays.Count -gt 0) {
            foreach ($holiday in $Body.holidays) {
                $dtRanges = @()
                foreach ($dr in $holiday.dateRanges) {
                    $dtRanges += New-CsOnlineDateTimeRange -Start $dr.start -End $dr.end
                }
                $holidaySchedule = New-CsOnlineSchedule -Name ($holiday.name + ' Schedule') -FixedSchedule -DateTimeRanges $dtRanges

                $holFlowDef = if ($holiday.flow) { $holiday.flow } else { $holiday }
                $holFlow    = Build-CallFlow -FlowName ($holiday.name + ' Flow') -FlowDef $holFlowDef

                $extraFlows   += $holFlow
                $associations += New-CsAutoAttendantCallHandlingAssociation -Type Holiday -ScheduleId $holidaySchedule.Id -CallFlowId $holFlow.Id
            }
        }

        if ($associations.Count -gt 0) { $aaParams.CallHandlingAssociations = $associations }
        if ($extraFlows.Count -gt 0)   { $aaParams.CallFlows = $extraFlows }

        # ── Dial scope ────────────────────────────────────────────────────────────
        # Body.inclusionScope / Body.exclusionScope: array of AAD group IDs
        if ($Body.inclusionScopeGroupIds -and $Body.inclusionScopeGroupIds.Count -gt 0) {
            $aaParams.InclusionScope = New-CsAutoAttendantDialScope -GroupScope -GroupIds $Body.inclusionScopeGroupIds
        }
        if ($Body.exclusionScopeGroupIds -and $Body.exclusionScopeGroupIds.Count -gt 0) {
            $aaParams.ExclusionScope = New-CsAutoAttendantDialScope -GroupScope -GroupIds $Body.exclusionScopeGroupIds
        }

        # ── UserNameExtension (dial-by-name disambiguation) ───────────────────────
        # Values: 'None', 'Office', 'Department'
        if ($Body.userNameExtension -and $Body.userNameExtension -ne 'None') {
            $aaParams.UserNameExtension = $Body.userNameExtension
        }

        # ── Create the AA ─────────────────────────────────────────────────────────
        $aa = New-CsAutoAttendant @aaParams -EA Stop

        # ── Associate resource accounts ───────────────────────────────────────────
        $raIds = @()
        if ($Body.resourceAccountId)  { $raIds += $Body.resourceAccountId }
        if ($Body.resourceAccountIds) { $raIds += $Body.resourceAccountIds }
        if ($raIds.Count -gt 0) {
            $uniqueRaIds = $raIds | Select-Object -Unique
            try {
                New-CsOnlineApplicationInstanceAssociation -Identities $uniqueRaIds -ConfigurationId $aa.Identity -ConfigurationType AutoAttendant -EA Stop
                Write-AuditEntry -Action 'AssociateRA_AA' -Target ($uniqueRaIds -join ',') -Result 'Success' -Detail $aa.Name
            } catch {
                Write-AuditEntry -Action 'AssociateRA_AA' -Target ($uniqueRaIds -join ',') -Result 'Error' -Detail $_.Exception.Message
            }
        }

        Write-AuditEntry -Action 'CreateAA' -Target $aa.Name -Result 'Success' -Detail "ID: $($aa.Identity)"
        return @{ success = $true; id = $aa.Identity; name = $aa.Name }
    } catch {
        Write-AuditEntry -Action 'CreateAA' -Target ($Body.name) -Result 'Error' -Detail $_.Exception.Message
        return @{ success = $false; error = $_.Exception.Message }
    }
}
