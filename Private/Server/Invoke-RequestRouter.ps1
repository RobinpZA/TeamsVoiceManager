function Invoke-RequestRouter {
    [CmdletBinding()]
    param([System.Net.HttpListenerContext]$Context)
    $request  = $Context.Request
    $method   = $request.HttpMethod
    $path     = $request.Url.AbsolutePath.TrimEnd('/')
    if ([string]::IsNullOrEmpty($path)) { $path = '/' }
    $body = $null
    if ($method -in @('POST','PUT','DELETE') -and $request.HasEntityBody) {
        $reader = [System.IO.StreamReader]::new($request.InputStream, $request.ContentEncoding)
        $bodyRaw = $reader.ReadToEnd(); $reader.Close()
        try { $body = $bodyRaw | ConvertFrom-Json -AsHashtable } catch { $body = $bodyRaw }
    }
    try {
        switch -Regex ($path) {
            '^/$'                              { Write-HtmlFileResponse -Context $Context -RelativePath 'index.html'; return }
            '^/(css|js|img)/.+'                { Write-StaticFileResponse -Context $Context -RelativePath ($path -replace '^/',''); return }
            '^/api/auth/status$'               { Write-JsonResponse -Context $Context -Data (Get-PortalAuthStatus); return }
            '^/api/auth/connect$'              { Write-JsonResponse -Context $Context -Data (Invoke-PortalConnect); return }
            '^/api/auth/disconnect$'           { Write-JsonResponse -Context $Context -Data (Invoke-PortalDisconnect); return }
            '^/api/dashboard$'                 { Write-JsonResponse -Context $Context -Data (Get-PortalDashboard); return }
            '^/api/domains/validation-user$' {
                if ($method -eq 'POST') { Write-JsonResponse -Context $Context -Data (New-PortalDomainValidationUser -Body $body) }
                return
            }
            '^/api/domains/validation-user/license$' {
                if ($method -eq 'POST') { Write-JsonResponse -Context $Context -Data (Remove-PortalDomainValidationUserLicense -Body $body) }
                return
            }
            '^/api/domains$' {
                if ($method -eq 'GET') { Write-JsonResponse -Context $Context -Data (Get-PortalDomains) }
                elseif ($method -eq 'POST') { Write-JsonResponse -Context $Context -Data (Add-PortalDomain -Body $body) }
                return
            }
            '^/api/domains/([^/]+)/txt$'       { Write-JsonResponse -Context $Context -Data (Get-PortalDomainTxtRecords -DomainName $Matches[1]); return }
            '^/api/domains/([^/]+)/verify$'    { Write-JsonResponse -Context $Context -Data (Invoke-PortalDomainVerification -DomainName $Matches[1]); return }
            '^/api/voice-config$' {
                if ($method -eq 'GET') { Write-JsonResponse -Context $Context -Data (Get-PortalVoiceConfig) }
                elseif ($method -eq 'POST') { Write-JsonResponse -Context $Context -Data (Set-PortalVoiceConfig -Body $body) }
                return
            }
            '^/api/voice-config/normalization$' {
                if ($method -eq 'GET') { Write-JsonResponse -Context $Context -Data (Get-PortalNormalizationRules) }
                elseif ($method -eq 'POST') { Write-JsonResponse -Context $Context -Data (Set-PortalNormalizationRules -Body $body) }
                return
            }
            '^/api/users$' {
                $q = [System.Web.HttpUtility]::ParseQueryString($request.Url.Query)
                Write-JsonResponse -Context $Context -Data (Get-PortalUsers -Search $q['search'] -Page $q['page'] -PageSize $q['pageSize'] -WithPhoneNumbers $q['withNumbers'] -WithoutPhoneNumbers $q['withoutNumbers'])
                return
            }
            '^/api/users/([^/]+)/voice$'       { Write-JsonResponse -Context $Context -Data (Get-PortalUserVoiceStatus -UserId $Matches[1]); return }
            '^/api/users/([^/]+)/license$'     { Write-JsonResponse -Context $Context -Data (Set-PortalUserLicense -UserId $Matches[1] -Body $body); return }
            '^/api/users/([^/]+)/phone$' {
                if ($method -eq 'POST') { Write-JsonResponse -Context $Context -Data (Set-PortalUserPhoneNumber -UserId $Matches[1] -Body $body) }
                elseif ($method -eq 'DELETE') { Write-JsonResponse -Context $Context -Data (Remove-PortalUserPhoneNumber -UserId $Matches[1] -Body $body) }
                return
            }
            '^/api/users/bulk-assign$'         { Write-JsonResponse -Context $Context -Data (Invoke-PortalBulkNumberAssignment -Body $body); return }
            '^/api/number-pool$'               { Write-JsonResponse -Context $Context -Data (Get-PortalNumberPool); return }
            '^/api/number-pool/available$'     { Write-JsonResponse -Context $Context -Data (Get-PortalAvailableNumbers); return }
            '^/api/number-pool/sync$'          { Write-JsonResponse -Context $Context -Data (Sync-PortalNumberPool); return }
            '^/api/number-pool/import$'        { Write-JsonResponse -Context $Context -Data (Import-PortalNumberPool -Body $body); return }
            '^/api/number-pool/export$'        { Write-JsonResponse -Context $Context -Data (Export-PortalNumberPool); return }
            '^/api/resource-accounts$' {
                if ($method -eq 'GET') { Write-JsonResponse -Context $Context -Data (Get-PortalResourceAccounts) }
                elseif ($method -eq 'POST') { Write-JsonResponse -Context $Context -Data (New-PortalResourceAccount -Body $body) }
                return
            }
            '^/api/resource-accounts/([^/]+)/license$' { Write-JsonResponse -Context $Context -Data (Set-PortalResourceAccountLicense -ResourceAccountId $Matches[1] -Body $body); return }
            '^/api/resource-accounts/([^/]+)/phone$'   { Write-JsonResponse -Context $Context -Data (Set-PortalResourceAccountNumber -ResourceAccountId $Matches[1] -Body $body); return }
            '^/api/auto-attendants$' {
                if ($method -eq 'GET') { Write-JsonResponse -Context $Context -Data (Get-PortalAutoAttendants) }
                elseif ($method -eq 'POST') { Write-JsonResponse -Context $Context -Data (New-PortalAutoAttendant -Body $body) }
                return
            }
            '^/api/auto-attendants/([^/]+)/flow$' { Write-JsonResponse -Context $Context -Data (Get-PortalAutoAttendantFlow -AutoAttendantId $Matches[1]); return }
            '^/api/auto-attendants/([^/]+)$'   { Write-JsonResponse -Context $Context -Data (Set-PortalAutoAttendant -AutoAttendantId $Matches[1] -Body $body); return }
            '^/api/call-queues$' {
                if ($method -eq 'GET') { Write-JsonResponse -Context $Context -Data (Get-PortalCallQueues) }
                elseif ($method -eq 'POST') { Write-JsonResponse -Context $Context -Data (New-PortalCallQueue -Body $body) }
                return
            }
            '^/api/call-queues/([^/]+)$'       { Write-JsonResponse -Context $Context -Data (Set-PortalCallQueue -CallQueueId $Matches[1] -Body $body); return }
            '^/api/associations$'              { Write-JsonResponse -Context $Context -Data (Set-PortalAAResourceAssociation -Body $body); return }
            '^/api/audio-files$'               { Write-JsonResponse -Context $Context -Data (Import-PortalAudioFile -Body $body); return }
            '^/api/languages$'                 { Write-JsonResponse -Context $Context -Data (Get-PortalSupportedLanguages); return }
            '^/api/timezones$'                 { Write-JsonResponse -Context $Context -Data (Get-PortalSupportedTimeZones); return }
            '^/api/audit-log$'                 { Write-JsonResponse -Context $Context -Data @{entries=$script:AuditLog.ToArray()}; return }
            '^/api/audit-log/export$'          { $p = Export-AuditLog; Write-JsonResponse -Context $Context -Data @{path=$p;count=$script:AuditLog.Count}; return }
            '^/api/shutdown$'                  { Write-JsonResponse -Context $Context -Data @{message='Shutting down...'}; $script:HttpListener.Stop(); return }
            default                            { Write-JsonResponse -Context $Context -Data @{error="Not found: $method $path"} -StatusCode 404 }
        }
    } catch {
        Write-Warning "Router error for $method $path : $_"
        Write-JsonResponse -Context $Context -Data @{error=$_.Exception.Message} -StatusCode 500
    }
}
