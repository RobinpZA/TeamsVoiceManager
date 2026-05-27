function Get-PortalCallQueues {
    [CmdletBinding()]
    param()

    # Inline helper scriptblock — captures $nameCache via scope
    $nameCache = @{}
    $resolveTargetName = [scriptblock] {
        param([string]$Id, [string]$Type)
        if (-not $Id) { return $null }
        if ($Type -eq 'ExternalPstn' -or $Id -match '^tel:' -or $Id -match '^\+\d') {
            return $Id -replace '^tel:', ''
        }
        if ($nameCache.ContainsKey($Id)) { return $nameCache[$Id] }
        try {
            $u = Get-CsOnlineUser -Identity $Id -EA SilentlyContinue
            $nameCache[$Id] = if ($u) { $u.DisplayName } else { $null }
        } catch {
            $nameCache[$Id] = $null
        }
        return $nameCache[$Id]
    }

    try {
        $cqs = Get-CsCallQueue -EA SilentlyContinue
        $cqList = @($cqs)
        Write-Verbose "GetCallQueues: found $($cqList.Count) call queue(s)"

        $result = @($cqList | ForEach-Object {
            $cq = $_
            try {
                # Pre-compute handler target IDs/types/names before building the hashtable
                $ovfId   = if ($cq.OverflowActionTarget) { [string]$cq.OverflowActionTarget.Id   } else { $null }
                $ovfType = if ($cq.OverflowActionTarget) { [string]$cq.OverflowActionTarget.Type } else { $null }
                $toId    = if ($cq.TimeoutActionTarget)  { [string]$cq.TimeoutActionTarget.Id    } else { $null }
                $toType  = if ($cq.TimeoutActionTarget)  { [string]$cq.TimeoutActionTarget.Type  } else { $null }
                $naId    = if ($cq.NoAgentActionTarget)  { [string]$cq.NoAgentActionTarget.Id    } else { $null }
                $naType  = if ($cq.NoAgentActionTarget)  { [string]$cq.NoAgentActionTarget.Type  } else { $null }
                $ovfName = & $resolveTargetName -Id $ovfId -Type $ovfType
                $toName  = & $resolveTargetName -Id $toId  -Type $toType
                $naName  = & $resolveTargetName -Id $naId  -Type $naType

                # Agent list — guard against null ObjectId
                $agents = @($cq.Agents | Where-Object { $_ } | ForEach-Object {
                    if ($null -ne $_.ObjectId) { [string]$_.ObjectId } else { $null }
                } | Where-Object { $_ })

                # Distribution lists / M365 group IDs
                $distributionLists = @($cq.DistributionLists | Where-Object { $_ } | ForEach-Object { [string]$_ })

                # OBO resource account IDs
                $oboRaIds = @($cq.OboResourceAccountIds | Where-Object { $_ } | ForEach-Object { [string]$_ })

                # Associated resource accounts — extract only the GUID string, never include raw PS objects
                $associatedRAs = @()
                try {
                    $assoc = Get-CsOnlineApplicationInstanceAssociation -Identity $cq.Identity -EA SilentlyContinue
                    if ($assoc) {
                        $associatedRAs = @($assoc | Where-Object { $_ } | ForEach-Object {
                            if ($null -ne $_.ObjectId) { [string]$_.ObjectId } else { $null }
                        } | Where-Object { $_ })
                    }
                } catch { Write-Verbose "GetCallQueues/Association ($($cq.Identity)): $_" }

                @{
                    id                           = [string]$cq.Identity
                    name                         = [string]$cq.Name
                    languageId                   = [string]$cq.LanguageId
                    routingMethod                = [string]$cq.RoutingMethod
                    agentAlertTime               = [int]$cq.AgentAlertTime
                    allowOptOut                  = [bool]$cq.AllowOptOut
                    conferenceMode               = [bool]$cq.ConferenceMode
                    presenceRouting              = [bool]$cq.PresenceBasedRouting
                    useDefaultMusic              = [bool]$cq.UseDefaultMusicOnHold
                    musicOnHoldAudioFileId       = if ($cq.MusicOnHoldAudioFileId)  { [string]$cq.MusicOnHoldAudioFileId  } else { $null }
                    welcomeMusicAudioFileId      = if ($cq.WelcomeMusicAudioFileId) { [string]$cq.WelcomeMusicAudioFileId } else { $null }
                    welcomeTtsPrompt             = [string]$cq.WelcomeTextToSpeechPrompt
                    agentCount                   = $agents.Count
                    agents                       = $agents
                    distributionLists            = $distributionLists
                    channelId                    = if ($cq.ChannelId)            { [string]$cq.ChannelId            } else { $null }
                    channelUserObjectId          = if ($cq.ChannelUserObjectId)  { [string]$cq.ChannelUserObjectId  } else { $null }
                    oboResourceAccountIds        = $oboRaIds
                    overflowThreshold            = $cq.OverflowThreshold
                    overflowAction               = [string]$cq.OverflowAction
                    overflowActionTarget         = $ovfId
                    overflowActionTargetType     = $ovfType
                    overflowActionTargetName     = $ovfName
                    timeoutThreshold             = $cq.TimeoutThreshold
                    timeoutAction                = [string]$cq.TimeoutAction
                    timeoutActionTarget          = $toId
                    timeoutActionTargetType      = $toType
                    timeoutActionTargetName      = $toName
                    noAgentAction                = [string]$cq.NoAgentAction
                    noAgentActionTarget          = $naId
                    noAgentActionTargetType      = $naType
                    noAgentActionTargetName      = $naName
                    serviceLevelThresholdSeconds = $cq.ServiceLevelThresholdResponseTimeInSecond
                    associatedResourceAccounts   = $associatedRAs
                }
            } catch {
                Write-Verbose "GetCallQueues/Item ($($cq.Identity)): $_"
                $null
            }
        } | Where-Object { $_ })

        Write-AuditEntry -Action 'GetCallQueues' -Target 'CallQueues' -Result 'Success' -Detail "Returned $($result.Count) call queue(s)"
        return @{ callQueues = $result }
    } catch {
        Write-AuditEntry -Action 'GetCallQueues' -Target 'CallQueues' -Result 'Error' -Detail $_.Exception.Message
        return @{ callQueues = @(); error = $_.Exception.Message }
    }
}
