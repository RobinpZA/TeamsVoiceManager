# TeamsVoiceManager

> **PowerShell module with an embedded browser-based portal for end-to-end Microsoft Teams Voice (Direct Routing) provisioning.**
> Designed for Vodacom Direct Routing deployments but fully applicable to any Teams Direct Routing environment.

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Portal Pages](#portal-pages)
- [API Reference](#api-reference)
- [Module Structure](#module-structure)
- [Configuration](#configuration)
- [Audit Logging](#audit-logging)
- [Templates](#templates)

---

## Overview

TeamsVoiceManager launches a local web server (`http://127.0.0.1:<port>`) and opens a dark-themed browser portal that guides an administrator through the complete Microsoft Teams Direct Routing setup workflow. The backend is pure PowerShell — no Node.js or third-party runtime required. The frontend is a vanilla JavaScript SPA.

The architecture mirrors the [M365UserOffboarding](https://github.com/RobinpZA/M365UserOffboarding) module — everything self-contained in a single PowerShell module.

---

## Features

| Area | Capabilities |
|------|-------------|
| **Dashboard** | Live tenant summary — domain count, licensed users, assigned numbers, resource accounts, CQs, AAs |
| **Domain Management** | Add SBC domains, retrieve DNS TXT verification records, trigger domain verification, create/clean up temporary validation users |
| **Voice Routing** | Create and update SBC gateways (PSTN gateways), PSTN usages, voice routes, voice routing policies, and tenant dial plans — pre-loaded with Vodacom defaults |
| **Normalization Rules** | View and update tenant dial plan normalization rules per-policy |
| **User Management** | Search users, view per-user voice status (license, phone number, policy), assign/remove Teams Phone Standard licenses, assign/remove Direct Routing phone numbers individually or in bulk |
| **Phone Number Pool** | Import a CSV of numbers, view allocation status, export current assignments |
| **Resource Accounts** | Create AA and CQ resource accounts, assign the free Teams Phone Resource Account (Virtual User) license, assign phone numbers |
| **Auto Attendants** | Full AA builder: greeting & menu prompts (TTS), operator, business-hours call flow with DTMF menu options (Disconnect / Transfer to Operator / Transfer to Target / Announcement), per-day business hours schedule, after-hours call flow, holiday schedules, dial scope (inclusion/exclusion groups), dial-by-name, voice response |
| **Call Queues** | Full CQ builder: individual agents, distribution lists, Teams channel (collaborative calling), routing method (Attendant / Serial / Round Robin / Longest Idle), greeting TTS, music on hold, overflow/timeout/no-agents handling with shared voicemail support, service level threshold, OBO caller ID resource accounts |
| **Audit Log** | Session-scoped audit trail of every action — viewable in-portal and exportable as a styled HTML + CSV report |

---

## Requirements

| Requirement | Version |
|-------------|---------|
| PowerShell | 7.2+ |
| MicrosoftTeams | 6.0.0+ |
| Microsoft.Graph.Authentication | 2.0.0+ |
| Microsoft.Graph.Users | 2.0.0+ |
| Microsoft.Graph.Identity.DirectoryManagement | 2.0.0+ |

The module will attempt to install missing modules automatically on first launch (current user scope).

### Required Admin Permissions

- **Microsoft Teams Admin** — Teams Administrator or Global Administrator in the tenant
- **Microsoft Graph** — `User.Read.All`, `Directory.Read.All`, `Organization.Read.All`, `LicenseAssignment.ReadWrite.All`

---

## Installation

### From Source (Development)

```powershell
# Clone the repository
git clone https://github.com/RobinpZA/TeamsVoiceManager.git

# Import directly from the cloned path
Import-Module .\TeamsVoiceManager\TeamsVoiceManager.psd1
```

### From PowerShell Gallery (when published)

```powershell
Install-Module -Name TeamsVoiceManager -Scope CurrentUser
```

---

## Usage

```powershell
# Launch on default port 8080 (opens browser automatically)
Start-TeamsVoiceManager

# Launch on a custom port
Start-TeamsVoiceManager -Port 9090

# Launch without auto-opening the browser
Start-TeamsVoiceManager -NoBrowser
```

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-Port` | `int` | `8080` | TCP port for the local HTTP server |
| `-NoBrowser` | `switch` | `$false` | Print the URL instead of opening the browser |

Once launched, the portal prints the URL and waits. Authenticate via the **Sign In** button in the portal — this triggers `Connect-MicrosoftTeams` and `Connect-MgGraph` interactive sign-in flows. The portal remains active until you click **Close Portal** or press `Ctrl+C` in the terminal.

On exit, the module offers to export an HTML audit log of the session.

---

## Portal Pages

### Dashboard
Live overview of the tenant voice configuration. Shows counts of domains, licensed users, assigned numbers, resource accounts, call queues, and auto attendants.

### Domains
Add SBC domains to the tenant, view the required DNS TXT record, verify ownership, and create/remove temporary validation users for domains that require a licensed user to verify.

### Voice Configuration
Configure the full Direct Routing stack:
- **PSTN Gateways** — SBC FQDN, SIP port, codec priority, media bypass, concurrent sessions
- **PSTN Usages** — Named call categories linked to routes
- **Voice Routes** — Pattern-matched routes pointing to gateways, ordered by priority
- **Voice Routing Policies** — Collections of PSTN usages assigned to users
- **Dial Plans & Normalization** — Tenant dial plans with regex normalization rules (Vodacom defaults pre-loaded)

### Users
Paginated, searchable list of all tenant users with their current voice status. Actions per user:
- Assign / remove **Teams Phone Standard** license
- Assign / remove a **Direct Routing phone number**
- View per-user dial plan, routing policy, and call forwarding state

### Number Pool
Upload a CSV of E.164 phone numbers and track allocation:
- **Import** — paste or upload a CSV (one number per line or `PhoneNumber,Description` format)
- **View** — see which numbers are assigned, free, or reserved
- **Export** — download the current pool with assignment status

### Resource Accounts
Manage Teams resource accounts (app instances) used to link numbers to Auto Attendants and Call Queues:
- **Create** — choose AA or CQ type, provide a display name and UPN
- **License** — assign the free **Teams Phone Resource Account** (`PHONESYSTEM_VIRTUALUSER`) license
- **Assign Phone** — attach an E.164 Direct Routing number

### Auto Attendants
Full wizard to create Auto Attendants:

| Section | Fields |
|---------|--------|
| General | Name, language, time zone, resource account |
| Operator | Type (User / Resource Account / External PSTN), identity |
| Business Hours Call Flow | Greeting TTS, menu prompt TTS, DTMF menu options, dial-by-name + directory search method |
| Menu Options | Key (0–9, *, #), action, target type + identity; supports Disconnect, Transfer to Operator, Transfer to Target (AA/CQ/User/External/Shared Voicemail), Announcement |
| After Hours | Per-day business hours schedule (Mon–Sun, enable/disable, start/end time), separate after-hours greeting, menu prompt, and menu options |
| Holidays | Named holiday date ranges with individual greeting TTS |
| Dial Scope | AAD group object IDs for dial-by-name inclusion/exclusion |
| Advanced | Voice response (speech input), display-name disambiguation (Office/Department) |

### Call Queues
Full wizard to create Call Queues:

| Section | Fields |
|---------|--------|
| General | Name, language, resource account |
| Agents | Source type (Individual Users / Distribution Lists / Teams Channel), IDs, routing method, alert time, presence-based routing, conference mode, opt-out |
| Greeting & Music | Welcome greeting TTS or audio file ID, default or custom music on hold |
| Overflow | Max queue size, action (Disconnect / Redirect / Shared Voicemail), target, voicemail TTS + transcription |
| Timeout | Timeout seconds, action (Disconnect / Redirect / Shared Voicemail), target, voicemail TTS + transcription |
| No Agents | Action when no agents are logged in (queue / Disconnect / Redirect / Shared Voicemail) |
| Advanced | Service level threshold (0–2400 s), OBO resource accounts for outbound caller ID |

### Audit Log
In-portal log of every action taken this session — create, update, license, assign operations — with timestamps, targets, and results. Export to a styled HTML + CSV report via the **Export** button.

---

## API Reference

The portal backend exposes a local REST API at `http://127.0.0.1:<port>/api/`. All endpoints accept and return JSON.

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/auth/status` | Current auth state (connected/tenant/user) |
| POST | `/api/auth/connect` | Trigger interactive Teams + Graph sign-in |
| POST | `/api/auth/disconnect` | Sign out and reset session |
| GET | `/api/dashboard` | Tenant voice overview stats |
| GET | `/api/domains` | List tenant domains |
| POST | `/api/domains` | Add an SBC domain |
| GET | `/api/domains/{domain}/txt` | Get DNS TXT verification records |
| POST | `/api/domains/{domain}/verify` | Trigger domain verification |
| POST | `/api/domains/validation-user` | Create a temporary licensed validation user |
| POST | `/api/domains/validation-user/license` | Remove the validation user license |
| GET | `/api/voice-config` | Get full voice routing config |
| POST | `/api/voice-config` | Create/update voice routing stack |
| GET | `/api/voice-config/normalization` | Get normalization rules |
| POST | `/api/voice-config/normalization` | Update normalization rules |
| GET | `/api/users` | List/search users (supports `?search=`, `?page=`, `?pageSize=`, `?withNumbers=true`) |
| GET | `/api/users/{id}/voice` | Get per-user voice status |
| POST | `/api/users/{id}/license` | Assign/remove Teams Phone license |
| POST | `/api/users/{id}/phone` | Assign phone number to user |
| DELETE | `/api/users/{id}/phone` | Remove phone number from user |
| POST | `/api/users/bulk-assign` | Bulk assign numbers from array |
| GET | `/api/number-pool` | Get number pool with allocation status |
| POST | `/api/number-pool/import` | Import array of phone numbers |
| GET | `/api/number-pool/export` | Export pool as JSON |
| GET | `/api/resource-accounts` | List all resource accounts |
| POST | `/api/resource-accounts` | Create a new resource account |
| POST | `/api/resource-accounts/{id}/license` | Assign PHONESYSTEM_VIRTUALUSER license |
| POST | `/api/resource-accounts/{id}/phone` | Assign phone number to resource account |
| GET | `/api/auto-attendants` | List all Auto Attendants |
| POST | `/api/auto-attendants` | Create a new Auto Attendant |
| PUT | `/api/auto-attendants/{id}` | Update an existing Auto Attendant |
| GET | `/api/call-queues` | List all Call Queues |
| POST | `/api/call-queues` | Create a new Call Queue |
| PUT | `/api/call-queues/{id}` | Update an existing Call Queue |
| POST | `/api/associations` | Associate a resource account with an AA or CQ |
| POST | `/api/audio-files` | Import an audio file for AA/CQ prompts |
| GET | `/api/languages` | List supported AA languages |
| GET | `/api/timezones` | List supported AA time zones |
| GET | `/api/audit-log` | Get current session audit log entries |
| GET | `/api/audit-log/export` | Export audit log to HTML + CSV |
| POST | `/api/shutdown` | Gracefully stop the portal |

---

## Module Structure

```
TeamsVoiceManager/
├── TeamsVoiceManager.psd1              # Module manifest (v0.1.0)
├── TeamsVoiceManager.psm1              # Root module — dot-sources Private + Public
├── build.ps1                           # PSScriptAnalyzer → Pester → build pipeline
├── PSScriptAnalyzerSettings.psd1       # Linter rules
│
├── Config/
│   └── VodacomDefaults.json            # Default SBC FQDNs, routes, PSTN usages, normalization rules
│
├── Public/
│   └── Start-TeamsVoiceManager.ps1     # Exported entry point
│
├── Private/
│   ├── Auth/
│   │   └── Connect-TeamsVoiceServices.ps1
│   ├── Server/
│   │   ├── Start-HttpListener.ps1      # Blocking HTTP server loop
│   │   ├── Invoke-RequestRouter.ps1    # Switch-based request router
│   │   └── Write-HttpResponse.ps1      # JSON / HTML / static file response helpers
│   ├── Api/                            # One file per API endpoint
│   │   ├── Get-PortalDashboard.ps1
│   │   ├── Get/Add-PortalDomains.ps1 (et al.)
│   │   ├── Get/Set-PortalVoiceConfig.ps1 (et al.)
│   │   ├── Get/Set-PortalUsers.ps1 (et al.)
│   │   ├── Get/Import-PortalNumberPool.ps1 (et al.)
│   │   ├── Get/New/Set-PortalResourceAccount*.ps1
│   │   ├── Get/New/Set-PortalAutoAttendant*.ps1
│   │   ├── Get/New/Set-PortalCallQueue*.ps1
│   │   ├── Set-PortalAAResourceAssociation.ps1
│   │   ├── Import-PortalAudioFile.ps1
│   │   └── Get-PortalSupported{Languages,TimeZones}.ps1
│   ├── Helpers/
│   │   ├── Test-TeamsPhoneLicense.ps1  # Check MCOEV / PHONESYSTEM_VIRTUALUSER
│   │   ├── Get-AvailableLicenses.ps1
│   │   ├── ConvertTo-JsonSafe.ps1
│   │   └── Format-PhoneNumber.ps1      # Normalise to E.164
│   └── Logging/
│       ├── Write-AuditEntry.ps1
│       └── Export-AuditLog.ps1
│
├── Assets/
│   └── portal/
│       ├── index.html                  # SPA shell
│       ├── css/styles.css              # Dark Catppuccin-inspired theme
│       └── js/
│           ├── app.js                  # Router and state
│           ├── api.js                  # Fetch wrapper
│           ├── pages/                  # One JS object per page
│           └── components/             # Modal, Toast, DataTable, etc.
│
├── Templates/
│   ├── PhoneNumbers_Template.csv
│   ├── BulkAssignment_Template.csv
│   └── ResourceAccounts_Template.csv
│
└── Tests/
    └── TeamsVoiceManager.Tests.ps1     # Pester 5 test suite
```

---

## Configuration

### Vodacom Defaults (`Config/VodacomDefaults.json`)

The portal pre-populates the Voice Configuration page with Vodacom Direct Routing defaults including SBC FQDNs, PSTN usage names, voice route patterns, and South Africa normalization rules (E.164 `+27` format). Edit this file to customise defaults for your environment.

### Vodacom SBC Addresses

The default SBC configuration targets Vodacom's production Direct Routing endpoints. Update `Config/VodacomDefaults.json` with the correct FQDNs and SIP ports provided by Vodacom for your account.

---

## Audit Logging

Every write action performed through the portal is recorded to an in-memory audit log:

- Timestamp (UTC)
- Action name (e.g. `CreateAutoAttendant`, `AssignPhoneNumber`)
- Target identifier (UPN, ObjectId, display name)
- Result (`Success` / `Error`)
- Detail (applied values or error message)

The log is viewable in the **Audit Log** page in the portal. On portal exit, the module prompts to export the log as:
- A **styled HTML report** — consistent with the other Turrito Networks reporting modules
- A **CSV** — for import into ticketing systems or documentation

Exported logs are written to `Output/AuditLogs/` (git-ignored).

---

## Templates

Three CSV templates are included in the `Templates/` folder to assist with bulk operations:

| Template | Columns | Usage |
|----------|---------|-------|
| `PhoneNumbers_Template.csv` | `PhoneNumber`, `Description` | Import a block of E.164 numbers into the number pool |
| `BulkAssignment_Template.csv` | `UserPrincipalName`, `PhoneNumber` | Bulk-assign numbers to users |
| `ResourceAccounts_Template.csv` | `DisplayName`, `UPN`, `Type`, `PhoneNumber` | Reference template for RA creation |

---

## Author

**Robin Pieterse** — Turrito Networks  
(c) 2026 Robin Pieterse. All rights reserved.


See `plan.md` for full architecture and documentation.
