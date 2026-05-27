function New-PortalCallQueue {
    [CmdletBinding()]
    param([hashtable]$Body)
    try {
        # ── Core params ───────────────────────────────────────────────────────────
        $cqParams = @{
            Name             = $Body.name
            LanguageId       = ($Body.languageId ?? 'en-ZA')
            RoutingMethod    = ($Body.routingMethod ?? 'Attendant')
            AllowOptOut      = [bool]($Body.allowOptOut ?? $true)
            AgentAlertTime   = [int]($Body.agentAlertTime ?? 30)
            PresenceBasedRouting = [bool]($Body.presenceRouting ?? $true)
            ConferenceMode   = [bool]($Body.conferenceMode ?? $true)
        }

        # ── Music on hold ─────────────────────────────────────────────────────────
        if ($Body.musicOnHoldAudioFileId) {
            $cqParams.MusicOnHoldAudioFileId = $Body.musicOnHoldAudioFileId
        } else {
            $cqParams.UseDefaultMusicOnHold = [bool]($Body.useDefaultMusic ?? $true)
        }

        # ── Welcome greeting ──────────────────────────────────────────────────────
        if ($Body.welcomeGreetingAudioFileId) {
            $cqParams.WelcomeMusicAudioFileId = $Body.welcomeGreetingAudioFileId
        } elseif ($Body.welcomeGreetingText) {
            $cqParams.WelcomeTextToSpeechPrompt = $Body.welcomeGreetingText
        }

        # ── Agents: individual users ──────────────────────────────────────────────
        if ($Body.agentIds -and $Body.agentIds.Count -gt 0) {
            $cqParams.Users = @($Body.agentIds)
        }

        # ── Agents: distribution lists / M365 groups / Teams ──────────────────────
        # Body.distributionListIds: array of group/DL object IDs
        if ($Body.distributionListIds -and $Body.distributionListIds.Count -gt 0) {
            $cqParams.DistributionLists = @($Body.distributionListIds)
        }

        # ── Agents: Teams channel (collaborative calling) ─────────────────────────
        # Body.channelId + Body.channelUserObjectId (channel owner UPN/ObjectId)
        if ($Body.channelId -and $Body.channelUserObjectId) {
            $cqParams.ChannelId             = $Body.channelId
            $cqParams.ChannelUserObjectId   = $Body.channelUserObjectId
        }

        # ── On-behalf-of (OBO) resource accounts for calling ID ───────────────────
        # Body.oboResourceAccountIds: array of resource account identities
        if ($Body.oboResourceAccountIds -and $Body.oboResourceAccountIds.Count -gt 0) {
            $cqParams.OboResourceAccountIds = @($Body.oboResourceAccountIds)
        }

        # ── Service level threshold ───────────────────────────────────────────────
        if ($null -ne $Body.serviceLevelThresholdSeconds) {
            $cqParams.ServiceLevelThresholdResponseTimeInSecond = [int]$Body.serviceLevelThresholdSeconds
        }

        # ── Overflow handling ─────────────────────────────────────────────────────
        $cqParams.OverflowThreshold = [int]($Body.overflowThreshold ?? 50)
        $overflowAction = $Body.overflowAction ?? 'DisconnectWithBusy'
        $cqParams.OverflowAction = $overflowAction

        switch ($overflowAction) {
            'Forward' {
                if ($Body.overflowActionTarget) { $cqParams.OverflowActionTarget = $Body.overflowActionTarget }
            }
            'SharedVoicemail' {
                if ($Body.overflowActionTarget) { $cqParams.OverflowActionTarget = $Body.overflowActionTarget }
                if ($Body.overflowSharedVoicemailAudioFileId) {
                    $cqParams.OverflowSharedVoicemailAudioFilePrompt = $Body.overflowSharedVoicemailAudioFileId
                } elseif ($Body.overflowSharedVoicemailText) {
                    $cqParams.OverflowSharedVoicemailTextToSpeechPrompt = $Body.overflowSharedVoicemailText
                }
                if ($Body.enableOverflowSharedVoicemailTranscription) {
                    $cqParams.EnableOverflowSharedVoicemailTranscription = $true
                }
                if ($Body.enableOverflowSharedVoicemailSystemPromptSuppression) {
                    $cqParams.EnableOverflowSharedVoicemailSystemPromptSuppression = $true
                }
            }
        }

        # ── Timeout handling ──────────────────────────────────────────────────────
        $cqParams.TimeoutThreshold = [int]($Body.timeoutThreshold ?? 1200)
        $timeoutAction = $Body.timeoutAction ?? 'Disconnect'
        $cqParams.TimeoutAction = $timeoutAction

        switch ($timeoutAction) {
            'Forward' {
                if ($Body.timeoutActionTarget) { $cqParams.TimeoutActionTarget = $Body.timeoutActionTarget }
            }
            'SharedVoicemail' {
                if ($Body.timeoutActionTarget) { $cqParams.TimeoutActionTarget = $Body.timeoutActionTarget }
                if ($Body.timeoutSharedVoicemailAudioFileId) {
                    $cqParams.TimeoutSharedVoicemailAudioFilePrompt = $Body.timeoutSharedVoicemailAudioFileId
                } elseif ($Body.timeoutSharedVoicemailText) {
                    $cqParams.TimeoutSharedVoicemailTextToSpeechPrompt = $Body.timeoutSharedVoicemailText
                }
                if ($Body.enableTimeoutSharedVoicemailTranscription) {
                    $cqParams.EnableTimeoutSharedVoicemailTranscription = $true
                }
                if ($Body.enableTimeoutSharedVoicemailSystemPromptSuppression) {
                    $cqParams.EnableTimeoutSharedVoicemailSystemPromptSuppression = $true
                }
            }
        }

        # ── No-agents handling ────────────────────────────────────────────────────
        # Body.noAgentAction: 'Queue' (default), 'Disconnect', 'Forward', 'SharedVoicemail'
        if ($Body.noAgentAction -and $Body.noAgentAction -ne 'Queue') {
            $cqParams.NoAgentAction = $Body.noAgentAction
            switch ($Body.noAgentAction) {
                'Forward' {
                    if ($Body.noAgentActionTarget) { $cqParams.NoAgentActionTarget = $Body.noAgentActionTarget }
                }
                'SharedVoicemail' {
                    if ($Body.noAgentActionTarget) { $cqParams.NoAgentActionTarget = $Body.noAgentActionTarget }
                    if ($Body.noAgentSharedVoicemailAudioFileId) {
                        $cqParams.NoAgentSharedVoicemailAudioFilePrompt = $Body.noAgentSharedVoicemailAudioFileId
                    } elseif ($Body.noAgentSharedVoicemailText) {
                        $cqParams.NoAgentSharedVoicemailTextToSpeechPrompt = $Body.noAgentSharedVoicemailText
                    }
                    if ($Body.enableNoAgentSharedVoicemailTranscription) {
                        $cqParams.EnableNoAgentSharedVoicemailTranscription = $true
                    }
                    if ($Body.enableNoAgentSharedVoicemailSystemPromptSuppression) {
                        $cqParams.EnableNoAgentSharedVoicemailSystemPromptSuppression = $true
                    }
                }
            }
        }

        # ── Create the call queue ─────────────────────────────────────────────────
        $cq = New-CsCallQueue @cqParams -EA Stop

        # ── Associate resource accounts ───────────────────────────────────────────
        $raIds = @()
        if ($Body.resourceAccountId)  { $raIds += $Body.resourceAccountId }
        if ($Body.resourceAccountIds) { $raIds += $Body.resourceAccountIds }
        if ($raIds.Count -gt 0) {
            $uniqueRaIds = $raIds | Select-Object -Unique
            try {
                New-CsOnlineApplicationInstanceAssociation -Identities $uniqueRaIds -ConfigurationId $cq.Identity -ConfigurationType CallQueue -EA Stop
                Write-AuditEntry -Action 'AssociateRA_CQ' -Target ($uniqueRaIds -join ',') -Result 'Success' -Detail $cq.Name
            } catch {
                Write-AuditEntry -Action 'AssociateRA_CQ' -Target ($uniqueRaIds -join ',') -Result 'Error' -Detail $_.Exception.Message
            }
        }

        Write-AuditEntry -Action 'CreateCQ' -Target $cq.Name -Result 'Success' -Detail "ID: $($cq.Identity)"
        return @{ success = $true; id = $cq.Identity; name = $cq.Name }
    } catch {
        Write-AuditEntry -Action 'CreateCQ' -Target ($Body.name) -Result 'Error' -Detail $_.Exception.Message
        return @{ success = $false; error = $_.Exception.Message }
    }
}
