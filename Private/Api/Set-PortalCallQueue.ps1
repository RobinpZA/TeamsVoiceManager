function Set-PortalCallQueue {
    [CmdletBinding()]
    param([string]$CallQueueId, [hashtable]$Body)
    try {
        $setParams = @{}

        # ── Core scalar fields ────────────────────────────────────────────────────
        if ($Body.name)          { $setParams.Name          = $Body.name }
        if ($Body.routingMethod) { $setParams.RoutingMethod = $Body.routingMethod }
        if ($Body.languageId)    { $setParams.LanguageId    = $Body.languageId }
        if ($null -ne $Body.agentAlertTime)      { $setParams.AgentAlertTime      = [int]$Body.agentAlertTime }
        if ($null -ne $Body.allowOptOut)         { $setParams.AllowOptOut         = [bool]$Body.allowOptOut }
        if ($null -ne $Body.presenceRouting)     { $setParams.PresenceBasedRouting = [bool]$Body.presenceRouting }
        if ($null -ne $Body.conferenceMode)      { $setParams.ConferenceMode      = [bool]$Body.conferenceMode }

        # ── Music on hold ─────────────────────────────────────────────────────────
        if ($Body.musicOnHoldAudioFileId) {
            $setParams.MusicOnHoldAudioFileId = $Body.musicOnHoldAudioFileId
        } elseif ($null -ne $Body.useDefaultMusic) {
            $setParams.UseDefaultMusicOnHold = [bool]$Body.useDefaultMusic
        }

        # ── Welcome greeting ──────────────────────────────────────────────────────
        if ($Body.welcomeGreetingAudioFileId) {
            $setParams.WelcomeMusicAudioFileId = $Body.welcomeGreetingAudioFileId
        } elseif ($Body.welcomeGreetingText) {
            $setParams.WelcomeTextToSpeechPrompt = $Body.welcomeGreetingText
        }

        # ── Agents: individual users ──────────────────────────────────────────────
        if ($Body.agentIds) { $setParams.Users = @($Body.agentIds) }

        # ── Agents: distribution lists / M365 groups / Teams ──────────────────────
        if ($Body.distributionListIds -and $Body.distributionListIds.Count -gt 0) {
            $setParams.DistributionLists = @($Body.distributionListIds)
        }

        # ── Agents: Teams channel ─────────────────────────────────────────────────
        if ($Body.channelId -and $Body.channelUserObjectId) {
            $setParams.ChannelId           = $Body.channelId
            $setParams.ChannelUserObjectId = $Body.channelUserObjectId
        }

        # ── OBO resource accounts ─────────────────────────────────────────────────
        if ($Body.oboResourceAccountIds -and $Body.oboResourceAccountIds.Count -gt 0) {
            $setParams.OboResourceAccountIds = @($Body.oboResourceAccountIds)
        }

        # ── Service level threshold ───────────────────────────────────────────────
        if ($null -ne $Body.serviceLevelThresholdSeconds) {
            $setParams.ServiceLevelThresholdResponseTimeInSecond = [int]$Body.serviceLevelThresholdSeconds
        }

        # ── Overflow handling ─────────────────────────────────────────────────────
        if ($null -ne $Body.overflowThreshold) { $setParams.OverflowThreshold = [int]$Body.overflowThreshold }
        if ($Body.overflowAction) {
            $setParams.OverflowAction = $Body.overflowAction
            switch ($Body.overflowAction) {
                'Forward' {
                    if ($Body.overflowActionTarget) { $setParams.OverflowActionTarget = $Body.overflowActionTarget }
                }
                'SharedVoicemail' {
                    if ($Body.overflowActionTarget) { $setParams.OverflowActionTarget = $Body.overflowActionTarget }
                    if ($Body.overflowSharedVoicemailAudioFileId) {
                        $setParams.OverflowSharedVoicemailAudioFilePrompt = $Body.overflowSharedVoicemailAudioFileId
                    } elseif ($Body.overflowSharedVoicemailText) {
                        $setParams.OverflowSharedVoicemailTextToSpeechPrompt = $Body.overflowSharedVoicemailText
                    }
                    if ($Body.enableOverflowSharedVoicemailTranscription) {
                        $setParams.EnableOverflowSharedVoicemailTranscription = $true
                    }
                    if ($Body.enableOverflowSharedVoicemailSystemPromptSuppression) {
                        $setParams.EnableOverflowSharedVoicemailSystemPromptSuppression = $true
                    }
                }
            }
        }

        # ── Timeout handling ──────────────────────────────────────────────────────
        if ($null -ne $Body.timeoutThreshold) { $setParams.TimeoutThreshold = [int]$Body.timeoutThreshold }
        if ($Body.timeoutAction) {
            $setParams.TimeoutAction = $Body.timeoutAction
            switch ($Body.timeoutAction) {
                'Forward' {
                    if ($Body.timeoutActionTarget) { $setParams.TimeoutActionTarget = $Body.timeoutActionTarget }
                }
                'SharedVoicemail' {
                    if ($Body.timeoutActionTarget) { $setParams.TimeoutActionTarget = $Body.timeoutActionTarget }
                    if ($Body.timeoutSharedVoicemailAudioFileId) {
                        $setParams.TimeoutSharedVoicemailAudioFilePrompt = $Body.timeoutSharedVoicemailAudioFileId
                    } elseif ($Body.timeoutSharedVoicemailText) {
                        $setParams.TimeoutSharedVoicemailTextToSpeechPrompt = $Body.timeoutSharedVoicemailText
                    }
                    if ($Body.enableTimeoutSharedVoicemailTranscription) {
                        $setParams.EnableTimeoutSharedVoicemailTranscription = $true
                    }
                    if ($Body.enableTimeoutSharedVoicemailSystemPromptSuppression) {
                        $setParams.EnableTimeoutSharedVoicemailSystemPromptSuppression = $true
                    }
                }
            }
        }

        # ── No-agents handling ────────────────────────────────────────────────────
        if ($Body.noAgentAction) {
            $setParams.NoAgentAction = $Body.noAgentAction
            switch ($Body.noAgentAction) {
                'Forward' {
                    if ($Body.noAgentActionTarget) { $setParams.NoAgentActionTarget = $Body.noAgentActionTarget }
                }
                'SharedVoicemail' {
                    if ($Body.noAgentActionTarget) { $setParams.NoAgentActionTarget = $Body.noAgentActionTarget }
                    if ($Body.noAgentSharedVoicemailAudioFileId) {
                        $setParams.NoAgentSharedVoicemailAudioFilePrompt = $Body.noAgentSharedVoicemailAudioFileId
                    } elseif ($Body.noAgentSharedVoicemailText) {
                        $setParams.NoAgentSharedVoicemailTextToSpeechPrompt = $Body.noAgentSharedVoicemailText
                    }
                    if ($Body.enableNoAgentSharedVoicemailTranscription) {
                        $setParams.EnableNoAgentSharedVoicemailTranscription = $true
                    }
                    if ($Body.enableNoAgentSharedVoicemailSystemPromptSuppression) {
                        $setParams.EnableNoAgentSharedVoicemailSystemPromptSuppression = $true
                    }
                }
            }
        }

        # ── Apply ─────────────────────────────────────────────────────────────────
        Set-CsCallQueue -Identity $CallQueueId @setParams -EA Stop

        # ── Resource account re-association ───────────────────────────────────────
        $raIds = @()
        if ($Body.resourceAccountId)  { $raIds += $Body.resourceAccountId }
        if ($Body.resourceAccountIds) { $raIds += $Body.resourceAccountIds }
        if ($raIds.Count -gt 0) {
            $uniqueRaIds = $raIds | Select-Object -Unique
            try {
                New-CsOnlineApplicationInstanceAssociation -Identities $uniqueRaIds -ConfigurationId $CallQueueId -ConfigurationType CallQueue -EA Stop
                Write-AuditEntry -Action 'AssociateRA_CQ' -Target ($uniqueRaIds -join ',') -Result 'Success' -Detail $CallQueueId
            } catch {
                Write-AuditEntry -Action 'AssociateRA_CQ' -Target ($uniqueRaIds -join ',') -Result 'Error' -Detail $_.Exception.Message
            }
        }

        Write-AuditEntry -Action 'UpdateCQ' -Target $CallQueueId -Result 'Success'
        return @{ success = $true; id = $CallQueueId }
    } catch {
        Write-AuditEntry -Action 'UpdateCQ' -Target $CallQueueId -Result 'Error' -Detail $_.Exception.Message
        return @{ success = $false; error = $_.Exception.Message }
    }
}
