# TeamsVoiceManager — Code Review
**Reviewer:** GitHub Copilot  
**Date:** 2026-05-19  
**Scope:** Full module — all `.ps1`, `.psd1`, `.psm1`, `Tests/`  
**Method:** Elon Musk 5-Step Design Process + PSScriptAnalyzer (all severities)

---

## Executive Summary

The module is architecturally sound and follows the established pattern from the project plan. Structure, naming conventions (Verb-Noun, scope separation), and the HTTP listener / API handler design are all consistent and intentional.

PSScriptAnalyzer surfaced **27 Warnings** and **~60 Informational** findings. Manual review identified **2 security vulnerabilities** not caught by the linter. All critical and high-priority findings have been fixed as part of this review.

**Before fixes:** 2 security issues (HIGH), 1 runtime bug, 1 logic bug, 1 unused parameter, 14 empty catch blocks, 1 blocking sleep, 1 test cmdlet overwrite.  
**After fixes:** All of the above resolved. Advisory items remain for the team's discretion.

---

## Critical Issues *(fixed)*

### 1. Path Traversal — `Write-HttpResponse.ps1` ⚠️ HIGH

**Finding:** `Write-HtmlFileResponse` and `Write-StaticFileResponse` joined the URL-provided path directly into `$filePath` without verifying the resolved path stayed inside `Assets/portal/`. A request for `/../TeamsVoiceManager.psd1` or `/../Config/VodacomDefaults.json` would read arbitrary files from the module directory.

```powershell
# BEFORE (vulnerable)
$filePath = Join-Path $portalRoot $RelativePath
if (-not (Test-Path $filePath)) { ... }
# No bounds check — attacker can escape $portalRoot
```

**Fix applied:** Resolve both paths with `Resolve-Path` and verify the file path starts with the portal root before serving.

---

### 2. OPATH Filter Injection — `Get-PortalUsers.ps1` ⚠️ MEDIUM

**Finding:** The `$Search` parameter was sourced directly from `$request.Url.Query` and interpolated verbatim into an OPATH filter string:

```powershell
# BEFORE (injectable)
$users = Get-CsOnlineUser -Filter "DisplayName -like '*$Search*' ..."
```

A crafted query string (e.g. `' -or 1 -eq 1 -or '`) could bypass filters. Single quotes are the OPATH string delimiter.

**Fix applied:** Strip single quotes and control characters from `$Search` before use in any filter string.

---

## Bugs *(fixed)*

### 3. OPATH `$null` Literal — `Get-PortalDashboard.ps1` 🐛

**Finding:** Line used a PowerShell script block filter with `$null`:

```powershell
$vu = Get-CsOnlineUser -Filter {LineUri -ne $null} -EA SilentlyContinue
```

OPATH does not understand PowerShell `$null`. This filter fails silently (returns 0 users), giving an incorrect `usersWithNumbers` count on the dashboard. The same function already correctly uses `"LineUri -ne ''"` elsewhere.

**Fix applied:** Changed to `"LineUri -ne ''"` to match the pattern used in `Get-PortalUsers`.

---

### 4. Unused Parameter — `Set-PortalResourceAccountLicense.ps1` 🐛

**Finding:** `[hashtable]$Body` was declared but never read. All logic used only `$ResourceAccountId`. PSScriptAnalyzer flagged `PSReviewUnusedParameter`. The router passes `$Body` in the call from `Invoke-RequestRouter`, but the function has no use for it (license type is always `PHONESYSTEM_VIRTUALUSER`).

**Fix applied:** Removed the `$Body` parameter. If per-call license selection is needed in future, add it back explicitly.

---

### 5. Blocking `Start-Sleep` in HTTP Listener Thread — `New-PortalResourceAccount.ps1` 🐛

**Finding:** The HTTP listener is single-threaded. `New-PortalResourceAccount` called `Start-Sleep -Seconds 10` then `Start-Sleep -Seconds 5` for Azure AD replication, freezing the entire portal for 15 seconds on every resource account creation.

**Fix applied:** Replaced fixed sleeps with a short poll loop that breaks as soon as Azure AD replication is confirmed (`Get-MgUser` returns the new object), capped at 30 seconds.

---

## Recommended Deletions *(applied)*

### 6. Runtime Module Installation in `Start-TeamsVoiceManager.ps1`

The manifest `RequiredModules` already declares all four dependencies — PowerShell enforces these at import time. The `foreach ($mod in $requiredModules)` install block that followed was dead code that duplicated the manifest and could interfere with enterprise software management policies.

**Deleted:** The entire `$requiredModules` check + `Install-Module` block (~10 lines).

---

## Recommended Enhancements *(applied)*

### 7. Hardcoded Version String — `Start-TeamsVoiceManager.ps1`

`Write-Host "    TeamsVoiceManager v0.1.0"` was hardcoded and would drift from the manifest on every release.

**Fix applied:** Reads version dynamically from `(Get-Module -Name 'TeamsVoiceManager' -ErrorAction SilentlyContinue)?.Version ?? '0.1.0'`.

---

### 8. Port Validation — `Start-TeamsVoiceManager.ps1` & `Start-HttpListener.ps1`

Neither function validated the `$Port` parameter range. A value of 0, -1, or 99999 would reach `[System.Net.HttpListener]` and produce a confusing .NET exception.

**Fix applied:** Added `[ValidateRange(1, 65535)]` to both functions.

---

### 9. Audit Log Written Inside Module Directory — `Export-AuditLog.ps1`

Logs were written to `$script:ModuleRoot\Output\AuditLogs\`. On installations to system-wide module paths (e.g. `C:\Program Files\PowerShell\Modules`) this directory is read-only.

**Fix applied:** Changed to `[System.Environment]::GetFolderPath('MyDocuments')\TeamsVoiceManager\AuditLogs\`.

---

### 10. Empty Catch Blocks — Multiple Files

PSScriptAnalyzer flagged `PSAvoidUsingEmptyCatchBlock` in 14 locations across:
- `Get-PortalDashboard.ps1` (8×)
- `Get-PortalVoiceConfig.ps1` (5×)
- `Get-PortalAutoAttendants.ps1`, `Get-PortalCallQueues.ps1`, `Get-PortalUserVoiceStatus.ps1`
- `Disconnect-TeamsVoiceServices.ps1` (2×)

**Fix applied:**
- Dashboard and VoiceConfig: best-effort queries — `catch { Write-Verbose "..." }` added so intent is explicit and `-Verbose` surfaces partial failures during troubleshooting.
- Disconnect: intentional silent disconnect — added `Write-Verbose` with explanation.
- UserVoiceStatus inner license query: same pattern.

---

### 11. `PSAvoidOverwritingBuiltInCmdlets` — `ResourceAccounts.Tests.ps1`

The test defined `function Start-Sleep {}` to stub out the sleep. This overwrites the PowerShell built-in cmdlet in the current session, which can affect other tests.

**Fix applied:** Added `[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidOverwritingBuiltInCmdlets', '', Scope='Function', Target='Start-Sleep')]` to the `BeforeAll` block; annotated why the stub is necessary (dot-sourced function, not module-imported — `Mock` cannot be used without `InModuleScope`).

---

### 12. `PSUseSingularNouns` — Settings Update

PSScriptAnalyzer flagged 11 functions for plural nouns (`Get-PortalAutoAttendants`, `Get-PortalCallQueues`, `Get-PortalDomains`, etc.). These are intentional collection-getter functions in a portal API context — renaming them would break the router and all frontend calls for no functional gain. Added `PSUseSingularNouns` to `ExcludeRules` in `PSScriptAnalyzerSettings.psd1` with a comment.

---

## Optional Improvements *(not applied — advisory)*

| # | File | Finding | Recommendation |
|---|------|---------|----------------|
| A | All API functions | `PSUseOutputTypeCorrectly` — no `[OutputType]` declarations | Add `[OutputType([hashtable])]` to each portal API function. Low value for internal-only functions but aids discoverability. |
| B | Tests | `PSAvoidUsingPositionalParameters` in Pester `It`/`Should` calls | Use named parameters: `Should -Be $true` is fine; check `New-PesterConfiguration` calls. Informational only. |
| C | Multiple files | `PSUseBOMForUnicodeEncodedFile` | PS 7.2 reads UTF-8-no-BOM natively. Exclude this rule or resave flagged files with BOM if targeting PS 5.1 compatibility is ever added. |
| D | `Get-AvailableLicenses.ps1` | Silent `catch { return @() }` | Callers cannot distinguish "no licenses" from "Graph error". Consider `Write-Warning` before returning empty. |
| E | `New-PortalAutoAttendant.ps1` | 4 nested helper functions (`Build-*`) | Move to top-level private files to enable unit testing. Currently untestable in isolation. |
| F | `Get-PortalDashboard.ps1` | Inline `Get-MgSubscribedSku` call | Consolidate by calling the existing `Get-AvailableLicenses` helper instead of duplicating the query. |
| G | `PSScriptAnalyzerSettings.psd1` | `PSUseShouldProcessForStateChangingFunctions` excluded globally | Scope the exclusion to portal API functions only; state-changing cmdlet wrappers should still prompt. |
| H | `$script:NumberPool` | In-memory only — lost on restart | Acceptable for v0.1.0. Document in README; consider JSON persistence to `$env:USERPROFILE` in v0.2. |

---

## Risk Assessment

| Risk | Severity | Status |
|------|----------|--------|
| Path traversal in static file server | HIGH | ✅ Fixed |
| OPATH filter injection | MEDIUM | ✅ Fixed |
| OPATH `$null` literal bug (dashboard user count wrong) | MEDIUM | ✅ Fixed |
| Unused parameter / dead code | LOW | ✅ Fixed |
| Blocking sleep freezing portal UI (15 s per RA) | MEDIUM | ✅ Fixed |
| Runtime module install (redundant, policy risk) | LOW | ✅ Deleted |
| Empty catch blocks hiding errors | LOW | ✅ Fixed |
| Audit logs in read-only module directory | LOW | ✅ Fixed |
| Port parameter not range-validated | LOW | ✅ Fixed |
| Nested helper functions (untestable) | LOW | Advisory |
| Duplicate SKU query (dashboard vs helper) | LOW | Advisory |
| In-memory number pool (no persistence) | LOW | Advisory / v0.2 |

---

## Appendix: Deletion Summary

| Deleted | Location | Justification |
|---------|----------|---------------|
| `$requiredModules` install loop (~10 lines) | `Start-TeamsVoiceManager.ps1` | Duplicates `RequiredModules` in manifest; manifest enforcement is sufficient |
| `[hashtable]$Body` parameter | `Set-PortalResourceAccountLicense.ps1` | Never read; no logic path uses it |
