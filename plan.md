# TeamsVoiceManager — Project Plan

> **PowerShell module with an embedded local web portal for end-to-end Microsoft Teams Voice (Direct Routing) provisioning.**
> Architecture mirrors [M365UserOffboarding](https://github.com/RobinpZA/M365UserOffboarding) — local HTTP listener, browser-based UI, PowerShell backend.

---

## 1. Overview

**TeamsVoiceManager** is a PowerShell module that launches an interactive browser-based portal (served locally on `http://127.0.0.1:<port>`) to guide an administrator through the complete Vodacom / Direct Routing Teams Voice setup workflow — from domain onboarding through to Call Queue and Auto Attendant creation.

### Core Capabilities

| # | Capability | Description |
|---|-----------|-------------|
| 1 | **Retrieve Existing Config** | Pull current SBC gateways, voice routes, PSTN usages, dial plans, normalization rules, voice routing policies, user phone assignments, resource accounts, call queues, and auto attendants |
| 2 | **Domain Management** | Add SBC domains to the tenant, retrieve required TXT records, verify domains |
| 3 | **SBC & Voice Routing Setup** | Create/edit PSTN gateways, PSTN usages, voice routes, voice routing policies, and tenant dial plans with normalization rules — pre-populated with Vodacom defaults |
| 4 | **User Licensing & Enablement** | Create temporary domain-validation users, assign Teams Phone Standard licenses, assign Direct Routing phone numbers (individual + bulk) |
| 5 | **Phone Number Management** | Upload CSV of phone numbers, view allocation pool, assign/unassign numbers to users individually or in bulk |
| 6 | **Resource Accounts** | Create and license resource accounts (AA type `ce933385-9390-45d1-9512-c8d228086b72` / CQ type `11cd3e2e-fccb-42ad-ad00-878b93575e07`), assign phone numbers |
| 7 | **Auto Attendant & Call Queue Builder** | Visual flow builder to create AAs and CQs — business hours, after-hours, holidays, menu options, agent lists, overflow/timeout — and associate resource accounts |

---

## 2. Architecture & Project Structure

Follows the established pattern from your existing modules — `.psd1` / `.psm1` root, `Public/` for exported functions, `Private/` organised by concern, `Assets/portal/` for the embedded web frontend, `Tests/` for Pester, and a `build.ps1` CI script.

```
TeamsVoiceManager/
│
├── TeamsVoiceManager.psd1              # Module manifest
├── TeamsVoiceManager.psm1              # Root module (dot-sources Private + Public)
├── build.ps1                           # Build / CI script (Analyze → Test → Build)
├── PSScriptAnalyzerSettings.psd1       # Linter configuration
├── README.md
│
├── Config/
│   └── VodacomDefaults.json            # Default SBC config, normalization rules, PSTN usages
│
├── Public/
│   └── Start-TeamsVoiceManager.ps1     # Single exported function — launches the portal
│
├── Private/
│   ├── Auth/
│   │   └── Connect-TeamsVoiceServices.ps1        # MicrosoftTeams + Graph auth
│   │
│   ├── Server/
│   │   ├── Start-HttpListener.ps1                # Blocking HTTP server loop
│   │   ├── Invoke-RequestRouter.ps1              # Routes requests to API handlers
│   │   └── Write-HttpResponse.ps1                # Response helpers (JSON, HTML, errors)
│   │
│   ├── Api/
│   │   ├── # ── Dashboard ──
│   │   ├── Get-PortalDashboard.ps1               # Tenant overview, existing config summary
│   │   │
│   │   ├── # ── Domain Management ──
│   │   ├── Get-PortalDomains.ps1                 # List current tenant domains
│   │   ├── Add-PortalDomain.ps1                  # Add new SBC domain
│   │   ├── Get-PortalDomainTxtRecords.ps1        # Retrieve TXT verification records
│   │   ├── Invoke-PortalDomainVerification.ps1   # Trigger domain verification
│   │   │
│   │   ├── # ── Voice Routing Configuration ──
│   │   ├── Get-PortalVoiceConfig.ps1             # Get existing SBCs, routes, usages, dial plans
│   │   ├── Set-PortalVoiceConfig.ps1             # Create/update full voice routing stack
│   │   ├── Get-PortalNormalizationRules.ps1      # Get current normalization rules
│   │   ├── Set-PortalNormalizationRules.ps1      # Create/update normalization rules
│   │   │
│   │   ├── # ── User Management ──
│   │   ├── Get-PortalUsers.ps1                   # List/search tenant users (paginated)
│   │   ├── Get-PortalUserVoiceStatus.ps1         # Per-user voice config (license, number, policy)
│   │   ├── Set-PortalUserLicense.ps1             # Assign/remove Teams Phone Standard license
│   │   ├── Set-PortalUserPhoneNumber.ps1         # Assign Direct Routing number to user
│   │   ├── Remove-PortalUserPhoneNumber.ps1      # Remove phone number from user
│   │   ├── Invoke-PortalBulkNumberAssignment.ps1 # Bulk assign numbers from uploaded CSV
│   │   │
│   │   ├── # ── Phone Number Pool ──
│   │   ├── Get-PortalNumberPool.ps1              # View uploaded number pool + allocation status
│   │   ├── Import-PortalNumberPool.ps1           # Upload CSV of phone numbers
│   │   ├── Export-PortalNumberPool.ps1           # Export current pool + assignments
│   │   │
│   │   ├── # ── Resource Accounts ──
│   │   ├── Get-PortalResourceAccounts.ps1        # List existing resource accounts
│   │   ├── New-PortalResourceAccount.ps1         # Create AA or CQ resource account
│   │   ├── Set-PortalResourceAccountLicense.ps1  # Assign Teams Phone Resource Account license
│   │   ├── Set-PortalResourceAccountNumber.ps1   # Assign phone number to resource account
│   │   │
│   │   ├── # ── Auto Attendant & Call Queue ──
│   │   ├── Get-PortalAutoAttendants.ps1          # List existing AAs
│   │   ├── New-PortalAutoAttendant.ps1           # Create AA with flows
│   │   ├── Set-PortalAutoAttendant.ps1           # Update existing AA
│   │   ├── Get-PortalCallQueues.ps1              # List existing CQs
│   │   ├── New-PortalCallQueue.ps1               # Create CQ
│   │   ├── Set-PortalCallQueue.ps1               # Update existing CQ
│   │   ├── Set-PortalAAResourceAssociation.ps1   # Associate RA ↔ AA/CQ
│   │   │
│   │   └── # ── Utilities ──
│   │       Import-PortalAudioFile.ps1            # Upload audio files for AA/CQ greetings
│   │       Get-PortalSupportedLanguages.ps1      # Get supported AA languages
│   │       Get-PortalSupportedTimeZones.ps1      # Get supported AA time zones
│   │
│   ├── Helpers/
│   │   ├── ConvertTo-JsonSafe.ps1                # Safe JSON serialisation
│   │   ├── Test-TeamsPhoneLicense.ps1            # Check if user has Teams Phone license
│   │   ├── Get-AvailableLicenses.ps1             # Get tenant SKUs (Phone Standard, RA license)
│   │   └── Format-PhoneNumber.ps1                # E.164 formatting helper (+27...)
│   │
│   └── Logging/
│       ├── Write-AuditEntry.ps1                  # Append to session audit log
│       └── Export-AuditLog.ps1                   # Export CSV + styled HTML audit report
│
├── Assets/
│   └── portal/
│       ├── index.html                  # Main SPA shell
│       ├── css/
│       │   └── styles.css              # Dark theme consistent with your other modules
│       ├── js/
│       │   ├── app.js                  # SPA router, state management
│       │   ├── api.js                  # Fetch wrapper for all API calls
│       │   ├── pages/
│       │   │   ├── dashboard.js        # Dashboard / overview page
│       │   │   ├── domains.js          # Domain management page
│       │   │   ├── voiceConfig.js      # Voice routing configuration page
│       │   │   ├── users.js            # User management + number assignment
│       │   │   ├── numberPool.js       # Phone number pool management
│       │   │   ├── resourceAccounts.js # Resource account management
│       │   │   ├── autoAttendants.js   # Auto Attendant builder
│       │   │   ├── callQueues.js       # Call Queue builder
│       │   │   └── auditLog.js         # Session audit log viewer
│       │   └── components/
│       │       ├── navbar.js           # Sidebar navigation
│       │       ├── modal.js            # Reusable modal dialogs
│       │       ├── toast.js            # Success/error notifications
│       │       ├── table.js            # Sortable, filterable, paginated tables
│       │       ├── fileUpload.js       # CSV upload component
│       │       └── flowBuilder.js      # Visual AA/CQ flow builder component
│       └── img/
│           └── logo.svg                # Module branding
│
├── Templates/
│   ├── PhoneNumbers_Template.csv       # Sample CSV: PhoneNumber, Description
│   ├── BulkAssignment_Template.csv     # Sample CSV: UserPrincipalName, PhoneNumber
│   └── ResourceAccounts_Template.csv   # Sample CSV: DisplayName, UPN, Type, PhoneNumber
│
├── Output/
│   └── AuditLogs/                      # Generated audit reports (git-ignored)
│
└── Tests/
    ├── TeamsVoiceManager.Tests.ps1     # Pester 5 test suite
    ├── Unit/
    │   ├── VoiceConfig.Tests.ps1
    │   ├── DomainManagement.Tests.ps1
    │   ├── UserManagement.Tests.ps1
    │   ├── ResourceAccounts.Tests.ps1
    │   └── NumberPool.Tests.ps1
    └── Integration/
        └── ServerRouting.Tests.ps1
```

---

## 3. Portal Pages & UI Design

The portal follows the same **dark-theme, sidebar-navigation, single-page-application** pattern used in M365UserOffboarding and CA-Reporter. Each page maps to a workflow step.

### 3.1 Sidebar Navigation

```
┌──────────────────────┐
│  🔊 TeamsVoiceManager │
│  Tenant: contoso.com │
├──────────────────────┤
│  📊 Dashboard        │
│  🌐 Domains          │
│  🔀 Voice Routing    │
│  👥 Users            │
│  📞 Number Pool      │
│  🤖 Resource Accounts│
│  📱 Auto Attendants  │
│  📋 Call Queues      │
│  📝 Audit Log        │
├──────────────────────┤
│  ✕ Close Portal      │
└──────────────────────┘
```

### 3.2 Page Breakdown

#### 📊 Dashboard
- **Tenant info** — name, tenant ID, Teams coexistence mode, connected admin UPN
- **Existing voice config summary cards:**
  - SBC gateways (count + names)
  - Voice routes (count)
  - PSTN usages (count)
  - Users with phone numbers (count)
  - Resource accounts (count)
  - Auto Attendants (count)
  - Call Queues (count)
- **Quick-action buttons** — jump to any workflow step
- **License availability** — Teams Phone Standard available/consumed, Teams Phone Resource Account available/consumed

#### 🌐 Domains
- **Table** of current tenant domains with verification status
- **"Add Domain" button** → modal with text field for new SBC domain FQDN
  - Default pattern: `<customername>.mtb.msdr.teams.vodacom.co.za` / `<customername>.cfo.msdr.teams.vodacom.co.za`
- After adding: **TXT record display card** with copy-to-clipboard button
- **"Verify Domain" button** per domain → triggers verification and shows result
- **"Create Validation User" button** → creates a user on each unverified/newly-verified domain with a Teams-included license
- **Status badges**: Pending → TXT Retrieved → Verified → User Created

#### 🔀 Voice Routing Configuration
This is the core setup page. All fields are **pre-populated with Vodacom defaults** from `Config/VodacomDefaults.json` but **fully editable**.

**SBC Gateway Section:**

| Field | Default Value | Editable |
|-------|--------------|----------|
| SBC FQDN 1 | `<customername>.mtb.msdr.teams.vodacom.co.za` | ✅ |
| SBC FQDN 2 | `<customername>.cfo.msdr.teams.vodacom.co.za` | ✅ |
| SIP Signalling Port | `5061` | ✅ |

**PSTN Usage Section:**

| Field | Default Value | Editable |
|-------|--------------|----------|
| PSTN Usage Name | `PSTN Usage for Teams DR VODA-HA-01-VR` | ✅ |

**Voice Route Section:**

| Field | Default Value | Editable |
|-------|--------------|----------|
| Voice Route Identity | `Default-Voice-RouteVODA-HA-01-VR` | ✅ |
| Number Pattern | `.*` | ✅ |
| Priority | `1` | ✅ |
| Gateway List | *(auto-populated from SBC FQDNs above)* | ✅ |

**Voice Routing Policy Section:**

| Field | Default Value | Editable |
|-------|--------------|----------|
| Policy Identity | `Global` | ✅ |

**Tenant Dial Plan & Normalization Rules Section:**

| Field | Default Value | Editable |
|-------|--------------|----------|
| Dial Plan Identity | `Global` | ✅ |

Pre-loaded normalization rules table (editable inline):

| Rule Name | Pattern | Translation |
|-----------|---------|-------------|
| ZA-TollFree | `^0(80\d{7})\d*$` | `+27$1` |
| ZA-Premium | `^0(86[24-9]\d{6})$` | `+27$1` |
| ZA-Mobile | `^0(([7]\d{8}\|8[1-5]\d{7}))$` | `+27$1` |
| ZA-National | `^0(([1-5]\d\d\|8[789]\d\|86[01])\d{6})\d*(\D+\d+)?$` | `+27$1` |
| ZA-Service | `^(1\d{2,4})$` | `$1` |
| ZA-International | *(full Vodacom pattern)* | `+$1$2` |

- **"Add Rule" button** to add custom normalization rules
- **"Remove Rule"** per row
- **"Retrieve Current Config" button** → pulls existing config from tenant and populates all fields (overwriting defaults)
- **"Apply Configuration" button** → executes the full voice routing stack creation:
  1. `Set-CsOnlinePstnUsage`
  2. `New-CsOnlineVoiceRoute` (or `Set-` if exists)
  3. `Set-CsOnlineVoiceRoutingPolicy`
  4. `Set-CsTenantDialPlan` with normalization rules
- **Diff view** — before applying, show what will change vs. current config
- **Status indicators** per section (✅ Configured / ⚠️ Differs / ❌ Not Set)

#### 👥 Users
- **Search & filter** — paginated user list with columns: DisplayName, UPN, License Status, Phone Number, Voice Routing Policy, Enterprise Voice Enabled
- **Individual user actions:**
  - Assign/remove Teams Phone Standard license
  - Assign/change/remove Direct Routing phone number
  - Assign voice routing policy
- **Bulk actions toolbar:**
  - "Bulk License Assignment" → select multiple users → assign Teams Phone Standard
  - "Bulk Number Assignment" → upload CSV (`UserPrincipalName, PhoneNumber`) → preview → execute
  - "Export Users" → download current user list with voice status as CSV
- **User detail panel** (slide-out) — full voice config for selected user:
  - Assigned licenses
  - Phone number + type
  - Voice routing policy
  - Dial plan
  - Enterprise voice enabled status

#### 📞 Number Pool
- **Upload CSV** — drag-and-drop or file picker for phone number list
  - Expected format: `PhoneNumber` column (E.164 format, e.g., `+27xxxxxxxxx`)
  - Optional columns: `Description`, `PreAssignedUser`
- **Number pool table** — sortable/filterable:
  - Phone Number | Status (Available / Assigned / Reserved) | Assigned To | Assigned Date
- **Quick-assign** — click an available number → modal to search and select a user → assign
- **Bulk assign** — upload a mapping CSV (`PhoneNumber, UserPrincipalName`) → preview → execute
- **Statistics bar** — Total numbers | Available | Assigned | Reserved

#### 🤖 Resource Accounts
- **Existing resource accounts table:**
  - DisplayName | UPN | Type (AA/CQ) | License Status | Phone Number | Associated AA/CQ
- **"Create Resource Account" button** → form:

  | Field | Description |
  |-------|-------------|
  | Display Name | e.g., `RA_AA_MainLine` |
  | UPN | e.g., `ra_aa_mainline@contoso.onmicrosoft.com` |
  | Type | Auto Attendant / Call Queue (dropdown) |
  | Assign License | Toggle — auto-assigns Teams Phone Resource Account license |
  | Phone Number | Optional — select from number pool or enter manually |

- **Bulk create** — upload CSV with columns: `DisplayName, UPN, Type, PhoneNumber`
- Application IDs used automatically:
  - Auto Attendant: `ce933385-9390-45d1-9512-c8d228086b72`
  - Call Queue: `11cd3e2e-fccb-42ad-ad00-878b93575e07`

#### 📱 Auto Attendant Builder
- **Existing AAs list** — name, resource account, phone number, status
- **"Create Auto Attendant" button** → multi-step wizard:

  **Step 1 — General Settings:**

  | Field | Description |
  |-------|-------------|
  | Name | AA display name |
  | Resource Account | Select from created RAs (type=AA) |
  | Language | Dropdown (populated from `Get-CsAutoAttendantSupportedLanguage`) |
  | Time Zone | Dropdown (populated from `Get-CsAutoAttendantSupportedTimeZone`) |
  | Voice Response | Enable/disable voice inputs |

  **Step 2 — Business Hours:**
  - Day-of-week grid with start/end time pickers
  - Uses `New-CsOnlineTimeRange` + `New-CsOnlineSchedule`

  **Step 3 — Call Flows:**
  - **Business Hours Flow:**
    - Greeting: Text-to-speech input / upload audio file
    - Menu options: key-press → action (Transfer to User, Transfer to CQ, Transfer to AA, Transfer to External, Disconnect, Operator)
    - Each option configurable via `New-CsAutoAttendantMenuOption` + `New-CsAutoAttendantCallableEntity`
  - **After Hours Flow:** same structure
  - **Holiday Flows:** add holidays with date ranges, each with its own greeting + routing

  **Step 4 — Review & Create:**
  - Summary of all settings
  - "Create" button → executes `New-CsAutoAttendant` + `New-CsAutoAttendantCallHandlingAssociation`
  - Associates resource account via `New-CsOnlineApplicationInstanceAssociation`

- **Edit existing AA** → loads current config into the wizard for modification

#### 📋 Call Queue Builder
- **Existing CQs list** — name, resource account, phone number, agents count, status
- **"Create Call Queue" button** → form:

  | Field | Default | Description |
  |-------|---------|-------------|
  | Name | — | CQ display name |
  | Resource Account | — | Select from created RAs (type=CQ) |
  | Language | `en-ZA` | Language for built-in prompts |
  | Routing Method | `Attendant` | Attendant / Serial / Round Robin / Longest Idle |
  | Use Default Hold Music | ✅ | Toggle, or upload custom audio |
  | Welcome Greeting | — | Text-to-speech or audio file |
  | Agents | — | Search & add users / groups as agents |
  | Agent Alert Time (sec) | `30` | Seconds before moving to next agent |
  | Presence-Based Routing | ✅ | Route only to available agents |
  | Conference Mode | ✅ | Faster call connection |
  | **Overflow Settings** | | |
  | Max Calls in Queue | `50` | |
  | Overflow Action | Disconnect | Disconnect / Redirect to User / Redirect to AA / Voicemail |
  | **Timeout Settings** | | |
  | Timeout (sec) | `1200` | Max wait time |
  | Timeout Action | Disconnect | Same options as overflow |
  | **No Agents Settings** | | |
  | No Agents Action | Queue | Queue / Disconnect / Redirect |

- "Create" button → executes `New-CsCallQueue` + `New-CsOnlineApplicationInstanceAssociation`
- **Edit existing CQ** → loads current config into the form

#### 📝 Audit Log
- **Live session log** — every API action recorded with timestamp, action, target, result, user
- **Colour-coded badges** — ✅ Success / ⚠️ Warning / ❌ Error / ⏭️ Skipped
- **Filter by** action type, status, target
- **Export** → CSV + styled HTML report (same pattern as M365UserOffboarding)

---

## 4. Default Configuration (VodacomDefaults.json)

Based on the Vodacom Voice over Teams Quick Guide, the following defaults are pre-loaded and fully editable from the Voice Routing page:

```json
{
  "sbcConfig": {
    "sipPort": 5061,
    "sbcFqdnTemplate": [
      "{customerName}.mtb.msdr.teams.vodacom.co.za",
      "{customerName}.cfo.msdr.teams.vodacom.co.za"
    ]
  },
  "pstnUsage": {
    "identity": "Global",
    "usageName": "PSTN Usage for Teams DR VODA-HA-01-VR"
  },
  "voiceRoute": {
    "identity": "Default-Voice-RouteVODA-HA-01-VR",
    "numberPattern": ".*",
    "priority": 1
  },
  "voiceRoutingPolicy": {
    "identity": "Global"
  },
  "tenantDialPlan": {
    "identity": "Global"
  },
  "normalizationRules": [
    {
      "name": "ZA-TollFree",
      "pattern": "^0(80\\d{7})\\d*$",
      "translation": "+27$1"
    },
    {
      "name": "ZA-Premium",
      "pattern": "^0(86[24-9]\\d{6})$",
      "translation": "+27$1"
    },
    {
      "name": "ZA-Mobile",
      "pattern": "^0(([7]\\d{8}|8[1-5]\\d{7}))$",
      "translation": "+27$1"
    },
    {
      "name": "ZA-National",
      "pattern": "^0(([1-5]\\d\\d|8[789]\\d|86[01])\\d{6})\\d*(\\D+\\d+)?$",
      "translation": "+27$1"
    },
    {
      "name": "ZA-Service",
      "pattern": "^(1\\d{2,4})$",
      "translation": "$1"
    },
    {
      "name": "ZA-International",
      "pattern": "^(?:\\+|00)(1|7|2[07]|3[0-46]|39\\d|4[013-9]|5[1-8]|6[0-6]|8[1246]|9[0-58]|2[1235689]\\d|24[013-9]|242\\d|3[578]\\d|42\\d|5[09]\\d|6[789]\\d|8[035789]\\d|9[679]\\d)(?:0)?(\\d{6,14})(\\D+\\d+)?$",
      "translation": "+$1$2"
    }
  ],
  "licensing": {
    "teamsPhoneStandard": {
      "skuPartNumber": "MCOEV",
      "description": "Microsoft Teams Phone Standard"
    },
    "teamsPhoneResourceAccount": {
      "skuPartNumber": "PHONESYSTEM_VIRTUALUSER",
      "description": "Microsoft Teams Phone Resource Account"
    }
  },
  "resourceAccountAppIds": {
    "autoAttendant": "ce933385-9390-45d1-9512-c8d228086b72",
    "callQueue": "11cd3e2e-fccb-42ad-ad00-878b93575e07"
  }
}
```

---

## 5. API Route Map

All API calls from the portal frontend hit the local HTTP listener. The router dispatches to the appropriate handler function.

| Method | Route | Handler | Description |
|--------|-------|---------|-------------|
| `GET` | `/` | Static | Serve `index.html` |
| `GET` | `/css/*`, `/js/*`, `/img/*` | Static | Serve static assets |
| `GET` | `/api/dashboard` | `Get-PortalDashboard` | Tenant overview + counts |
| `GET` | `/api/domains` | `Get-PortalDomains` | List tenant domains |
| `POST` | `/api/domains` | `Add-PortalDomain` | Add new domain |
| `GET` | `/api/domains/{name}/txt` | `Get-PortalDomainTxtRecords` | Get TXT records |
| `POST` | `/api/domains/{name}/verify` | `Invoke-PortalDomainVerification` | Verify domain |
| `GET` | `/api/voice-config` | `Get-PortalVoiceConfig` | Get existing voice config |
| `POST` | `/api/voice-config` | `Set-PortalVoiceConfig` | Apply voice routing config |
| `GET` | `/api/voice-config/normalization` | `Get-PortalNormalizationRules` | Get normalization rules |
| `POST` | `/api/voice-config/normalization` | `Set-PortalNormalizationRules` | Set normalization rules |
| `GET` | `/api/users` | `Get-PortalUsers` | List/search users (paginated) |
| `GET` | `/api/users/{id}/voice` | `Get-PortalUserVoiceStatus` | User voice detail |
| `POST` | `/api/users/{id}/license` | `Set-PortalUserLicense` | Assign/remove license |
| `POST` | `/api/users/{id}/phone` | `Set-PortalUserPhoneNumber` | Assign phone number |
| `DELETE` | `/api/users/{id}/phone` | `Remove-PortalUserPhoneNumber` | Remove phone number |
| `POST` | `/api/users/bulk-assign` | `Invoke-PortalBulkNumberAssignment` | Bulk number assignment |
| `GET` | `/api/number-pool` | `Get-PortalNumberPool` | Get number pool |
| `POST` | `/api/number-pool/import` | `Import-PortalNumberPool` | Upload number CSV |
| `GET` | `/api/number-pool/export` | `Export-PortalNumberPool` | Export pool as CSV |
| `GET` | `/api/resource-accounts` | `Get-PortalResourceAccounts` | List resource accounts |
| `POST` | `/api/resource-accounts` | `New-PortalResourceAccount` | Create resource account |
| `POST` | `/api/resource-accounts/{id}/license` | `Set-PortalResourceAccountLicense` | License RA |
| `POST` | `/api/resource-accounts/{id}/phone` | `Set-PortalResourceAccountNumber` | Assign number to RA |
| `GET` | `/api/auto-attendants` | `Get-PortalAutoAttendants` | List AAs |
| `POST` | `/api/auto-attendants` | `New-PortalAutoAttendant` | Create AA |
| `PUT` | `/api/auto-attendants/{id}` | `Set-PortalAutoAttendant` | Update AA |
| `GET` | `/api/call-queues` | `Get-PortalCallQueues` | List CQs |
| `POST` | `/api/call-queues` | `New-PortalCallQueue` | Create CQ |
| `PUT` | `/api/call-queues/{id}` | `Set-PortalCallQueue` | Update CQ |
| `POST` | `/api/associations` | `Set-PortalAAResourceAssociation` | Associate RA ↔ AA/CQ |
| `POST` | `/api/audio-files` | `Import-PortalAudioFile` | Upload audio file |
| `GET` | `/api/languages` | `Get-PortalSupportedLanguages` | AA supported languages |
| `GET` | `/api/timezones` | `Get-PortalSupportedTimeZones` | AA supported time zones |
| `GET` | `/api/audit-log` | Logging | Get session audit entries |
| `GET` | `/api/audit-log/export` | `Export-AuditLog` | Export audit CSV + HTML |

---

## 6. Authentication & Permissions

### 6.1 Modules Required

| Module | Min Version | Purpose |
|--------|-------------|---------|
| `MicrosoftTeams` | 6.0+ | Teams voice cmdlets (SBC, routes, dial plans, CQ, AA, resource accounts) |
| `Microsoft.Graph.Authentication` | 2.0+ | Graph auth + license management |
| `Microsoft.Graph.Users` | 2.0+ | User lookups, license assignment |
| `Microsoft.Graph.Identity.DirectoryManagement` | 2.0+ | Domain management |

### 6.2 Required Permissions

**MicrosoftTeams module** — connects via `Connect-MicrosoftTeams` (interactive):
- Teams Administrator or Teams Communications Administrator role

**Microsoft Graph** — scopes requested via `Connect-MgGraph`:

| Scope | Purpose |
|-------|---------|
| `User.ReadWrite.All` | Read users, assign licenses |
| `Organization.Read.All` | Read tenant info, subscribed SKUs |
| `Domain.ReadWrite.All` | Add, verify, manage domains |
| `Directory.Read.All` | Read directory objects |

### 6.3 Auth Flow

```
Start-TeamsVoiceManager
  │
  ├── Connect-MicrosoftTeams  (interactive browser sign-in)
  ├── Connect-MgGraph -Scopes <required scopes>  (interactive)
  │
  ├── Validate permissions
  ├── Cache tenant context (name, ID, licenses, coexistence mode)
  │
  └── Start HTTP listener → open browser
```

---

## 7. Workflow Sequence (Vodacom Direct Routing)

The portal guides the admin through these steps in order, matching the Vodacom Quick Guide:

```
 ┌─────────────────────────────────────────────────────────────┐
 │  STEP 1: DOMAIN MANAGEMENT                                  │
 │  ► Add SBC domains provided by Vodacom                      │
 │  ► Copy TXT records → send to Vodacom                       │
 │  ► Verify domains once Vodacom confirms                     │
 │  ► Create validation user on each domain + assign license   │
 └──────────────────────┬──────────────────────────────────────┘
                        ▼
 ┌─────────────────────────────────────────────────────────────┐
 │  STEP 2: VOICE ROUTING CONFIGURATION                        │
 │  ► Review/edit SBC FQDNs, PSTN usage, voice route,         │
 │    routing policy, dial plan, normalization rules            │
 │  ► Apply configuration (creates full voice routing stack)   │
 └──────────────────────┬──────────────────────────────────────┘
                        ▼
 ┌─────────────────────────────────────────────────────────────┐
 │  STEP 3: USER LICENSING                                     │
 │  ► Assign Teams Phone Standard license to voice users       │
 │  ► Individual or bulk assignment                            │
 └──────────────────────┬──────────────────────────────────────┘
                        ▼
 ┌─────────────────────────────────────────────────────────────┐
 │  STEP 4: PHONE NUMBER MANAGEMENT                            │
 │  ► Upload phone number pool (CSV)                           │
 │  ► Assign numbers to licensed users                         │
 │  ► Individual: select user → pick number                    │
 │  ► Bulk: upload mapping CSV → preview → execute             │
 └──────────────────────┬──────────────────────────────────────┘
                        ▼
 ┌─────────────────────────────────────────────────────────────┐
 │  STEP 5: RESOURCE ACCOUNTS (optional)                       │
 │  ► Create resource accounts for AA/CQ                       │
 │  ► Assign Teams Phone Resource Account license              │
 │  ► Assign phone numbers from pool                           │
 └──────────────────────┬──────────────────────────────────────┘
                        ▼
 ┌─────────────────────────────────────────────────────────────┐
 │  STEP 6: AUTO ATTENDANTS & CALL QUEUES (optional)           │
 │  ► Build AA flows (business hours, after hours, holidays)   │
 │  ► Build CQs (agents, routing, overflow, timeout)           │
 │  ► Associate resource accounts ↔ AA/CQ                     │
 └──────────────────────┬──────────────────────────────────────┘
                        ▼
 ┌─────────────────────────────────────────────────────────────┐
 │  STEP 7: CLEANUP                                            │
 │  ► Remove licenses from domain-validation users             │
 │  ► (Do NOT delete the users)                                │
 │  ► Export audit log                                         │
 └─────────────────────────────────────────────────────────────┘
```

---

## 8. Key PowerShell Cmdlets Reference

### 8.1 Domain Management (Graph)

```powershell
# Add domain
New-MgDomain -BodyParameter @{ Id = "customer.mtb.msdr.teams.vodacom.co.za" }

# Get TXT verification record
Get-MgDomainVerificationDnsRecord -DomainId "customer.mtb.msdr.teams.vodacom.co.za" |
  Where-Object { $_.RecordType -eq "Txt" }

# Verify domain
Confirm-MgDomain -DomainId "customer.mtb.msdr.teams.vodacom.co.za"
```

### 8.2 Voice Routing (MicrosoftTeams)

```powershell
# PSTN Usage
Set-CsOnlinePstnUsage -Identity Global -Usage @{Add=$pstnusage}

# Voice Route
New-CsOnlineVoiceRoute -Identity $routeName -NumberPattern ".*" `
  -OnlinePstnGatewayList $sbcFqdn1, $sbcFqdn2 `
  -Priority 1 -OnlinePstnUsages $pstnusage

# Voice Routing Policy
Set-CsOnlineVoiceRoutingPolicy -Identity $policyName -OnlinePstnUsages $pstnusage

# Normalization Rules + Dial Plan
$rules = @()
$rules += New-CsVoiceNormalizationRule -Name 'ZA-TollFree' -Parent Global `
  -Pattern '^0(80\d{7})\d*$' -Translation '+27$1' -InMemory
$rules += New-CsVoiceNormalizationRule -Name 'ZA-Premium' -Parent Global `
  -Pattern '^0(86[24-9]\d{6})$' -Translation '+27$1' -InMemory
$rules += New-CsVoiceNormalizationRule -Name 'ZA-Mobile' -Parent Global `
  -Pattern '^0(([7]\d{8}|8[1-5]\d{7}))$' -Translation '+27$1' -InMemory
$rules += New-CsVoiceNormalizationRule -Name 'ZA-National' -Parent Global `
  -Pattern '^0(([1-5]\d\d|8[789]\d|86[01])\d{6})\d*(\D+\d+)?$' -Translation '+27$1' -InMemory
$rules += New-CsVoiceNormalizationRule -Name 'ZA-Service' -Parent Global `
  -Pattern '^(1\d{2,4})$' -Translation '$1' -InMemory
$rules += New-CsVoiceNormalizationRule -Name 'ZA-International' -Parent Global `
  -Pattern '^(?:\+|00)(1|7|2[07]|3[0-46]|39\d|4[013-9]|5[1-8]|6[0-6]|8[1246]|9[0-58]|2[1235689]\d|24[013-9]|242\d|3[578]\d|42\d|5[09]\d|6[789]\d|8[035789]\d|9[679]\d)(?:0)?(\d{6,14})(\D+\d+)?$' `
  -Translation '+$1$2' -InMemory
Set-CsTenantDialPlan -Identity Global -NormalizationRules @{Add=$rules}
```

### 8.3 User Phone Assignment (MicrosoftTeams)

```powershell
# Assign phone number (Direct Routing)
Set-CsPhoneNumberAssignment -Identity $upn `
  -PhoneNumber "+27xxxxxxxxx" -PhoneNumberType DirectRouting

# Remove phone number
Remove-CsPhoneNumberAssignment -Identity $upn `
  -PhoneNumber "+27xxxxxxxxx" -PhoneNumberType DirectRouting

# Get user voice config
Get-CsOnlineUser -Identity $upn | Select-Object `
  DisplayName, UserPrincipalName, LineUri, EnterpriseVoiceEnabled, `
  OnlineVoiceRoutingPolicy, TenantDialPlan, TeamsUpgradeEffectiveMode
```

### 8.4 License Assignment (Graph)

```powershell
# Get available SKUs
$skus = Get-MgSubscribedSku | Select-Object SkuPartNumber, SkuId, `
  @{N='Available';E={$_.PrepaidUnits.Enabled - $_.ConsumedUnits}}

# Assign Teams Phone Standard
Set-MgUserLicense -UserId $upn `
  -AddLicenses @(@{SkuId = $teamsPhoneSkuId}) -RemoveLicenses @()

# Assign Teams Phone Resource Account license
Set-MgUserLicense -UserId $raUpn `
  -AddLicenses @(@{SkuId = $raLicenseSkuId}) -RemoveLicenses @()

# Remove license (cleanup step)
Set-MgUserLicense -UserId $upn `
  -AddLicenses @() -RemoveLicenses @($licenseSkuId)
```

### 8.5 Resource Accounts (MicrosoftTeams)

```powershell
# Create resource account — Auto Attendant
New-CsOnlineApplicationInstance `
  -UserPrincipalName "ra_aa_main@contoso.onmicrosoft.com" `
  -ApplicationId "ce933385-9390-45d1-9512-c8d228086b72" `
  -DisplayName "RA_AA_MainLine"

# Create resource account — Call Queue
New-CsOnlineApplicationInstance `
  -UserPrincipalName "ra_cq_support@contoso.onmicrosoft.com" `
  -ApplicationId "11cd3e2e-fccb-42ad-ad00-878b93575e07" `
  -DisplayName "RA_CQ_Support"

# List all resource accounts
Get-CsOnlineApplicationInstance

# Assign phone number to resource account
Set-CsPhoneNumberAssignment -Identity "ra_aa_main@contoso.onmicrosoft.com" `
  -PhoneNumber "+27xxxxxxxxx" -PhoneNumberType DirectRouting

# Associate resource account with AA or CQ
New-CsOnlineApplicationInstanceAssociation `
  -Identities @($raObjectId) `
  -ConfigurationId $cqOrAaId `
  -ConfigurationType "CallQueue"  # or "AutoAttendant"
```

### 8.6 Auto Attendant (MicrosoftTeams)

```powershell
# Build greeting
$greeting = New-CsAutoAttendantPrompt -TextToSpeechPrompt "Welcome to Contoso."

# Build menu options
$menuOption1 = New-CsAutoAttendantMenuOption -Action TransferCallToTarget `
  -DtmfResponse Tone1 `
  -CallTarget (New-CsAutoAttendantCallableEntity -Identity $cqId -Type ApplicationEndpoint)
$menuOption2 = New-CsAutoAttendantMenuOption -Action TransferCallToTarget `
  -DtmfResponse Tone2 `
  -CallTarget (New-CsAutoAttendantCallableEntity -Identity $userId -Type User)
$menuOption0 = New-CsAutoAttendantMenuOption -Action TransferCallToOperator `
  -DtmfResponse Tone0

# Build menu
$menu = New-CsAutoAttendantMenu -Name "Main Menu" `
  -MenuOptions @($menuOption0, $menuOption1, $menuOption2) `
  -Prompts @($greeting)

# Build call flow
$callFlow = New-CsAutoAttendantCallFlow -Name "Business Hours" -Menu $menu

# Build schedule
$timeRange = New-CsOnlineTimeRange -Start "08:00" -End "17:00"
$schedule = New-CsOnlineSchedule -Name "Business Hours" -WeeklyRecurrentSchedule `
  -MondayHours @($timeRange) -TuesdayHours @($timeRange) `
  -WednesdayHours @($timeRange) -ThursdayHours @($timeRange) `
  -FridayHours @($timeRange) -Complement

# Build after-hours flow
$afterHoursGreeting = New-CsAutoAttendantPrompt `
  -TextToSpeechPrompt "Our office is currently closed. Please call back during business hours."
$afterHoursMenu = New-CsAutoAttendantMenu -Name "After Hours" `
  -MenuOptions @((New-CsAutoAttendantMenuOption -Action DisconnectCall -DtmfResponse Automatic))
$afterHoursFlow = New-CsAutoAttendantCallFlow -Name "After Hours" `
  -Menu $afterHoursMenu -Greetings @($afterHoursGreeting)
$afterHoursCallHandling = New-CsAutoAttendantCallHandlingAssociation `
  -Type AfterHours -ScheduleId $schedule.Id -CallFlowId $afterHoursFlow.Id

# Create the Auto Attendant
$aa = New-CsAutoAttendant -Name "Contoso Main Line" `
  -DefaultCallFlow $callFlow `
  -Language "en-ZA" `
  -TimeZoneId "South Africa Standard Time" `
  -CallHandlingAssociations @($afterHoursCallHandling) `
  -EnableVoiceResponse

# Associate resource account
New-CsOnlineApplicationInstanceAssociation `
  -Identities @($raObjectId) `
  -ConfigurationId $aa.Id `
  -ConfigurationType "AutoAttendant"
```

### 8.7 Call Queue (MicrosoftTeams)

```powershell
# Create Call Queue
$cq = New-CsCallQueue -Name "Support Queue" `
  -RoutingMethod Attendant `
  -Users @($agent1Id, $agent2Id, $agent3Id) `
  -LanguageId "en-ZA" `
  -UseDefaultMusicOnHold $true `
  -AllowOptOut $true `
  -AgentAlertTime 30 `
  -PresenceBasedRouting $true `
  -ConferenceMode $true `
  -OverflowThreshold 50 `
  -OverflowAction DisconnectWithBusy `
  -TimeoutThreshold 1200 `
  -TimeoutAction Disconnect

# Associate resource account
New-CsOnlineApplicationInstanceAssociation `
  -Identities @($raObjectId) `
  -ConfigurationId $cq.Id `
  -ConfigurationType "CallQueue"
```

### 8.8 Retrieve Existing Configuration

```powershell
# SBC Gateways
Get-CsOnlinePSTNGateway

# Voice Routes
Get-CsOnlineVoiceRoute

# PSTN Usages
Get-CsOnlinePstnUsage

# Voice Routing Policies
Get-CsOnlineVoiceRoutingPolicy

# Tenant Dial Plan + Normalization Rules
Get-CsTenantDialPlan

# All users with phone numbers
Get-CsOnlineUser -Filter {LineUri -ne $null} |
  Select-Object DisplayName, UserPrincipalName, LineUri, EnterpriseVoiceEnabled

# Auto Attendants
Get-CsAutoAttendant

# Call Queues
Get-CsCallQueue

# Resource Accounts
Get-CsOnlineApplicationInstance
```

---

## 9. Implementation Phases

### Phase 1 — Foundation (Core Infrastructure)
- [ ] Module scaffolding (`.psd1`, `.psm1`, folder structure)
- [ ] `build.ps1` with Analyze / Test / Build / CI tasks
- [ ] `Connect-TeamsVoiceServices.ps1` — dual auth (Teams + Graph)
- [ ] HTTP server (`Start-HttpListener`, `Invoke-RequestRouter`, `Write-HttpResponse`)
- [ ] Portal shell (`index.html`, sidebar nav, dark theme CSS, SPA router)
- [ ] `Start-TeamsVoiceManager.ps1` — exported entry point
- [ ] Reusable JS components (table, modal, toast, file upload)
- [ ] Audit logging framework
- [ ] Dashboard page with tenant info + existing config retrieval

### Phase 2 — Domain & Voice Routing
- [ ] Domain management API handlers + portal page
- [ ] Domain verification workflow (add → TXT → verify → create user)
- [ ] Voice config retrieval (`Get-PortalVoiceConfig`)
- [ ] Voice config application with Vodacom defaults
- [ ] Normalization rules management (CRUD in UI)
- [ ] Config diff view (current vs. proposed)
- [ ] `VodacomDefaults.json` configuration file
- [ ] Status indicators per config section

### Phase 3 — User & Number Management
- [ ] User list with pagination, search, filtering
- [ ] User voice status detail panel (slide-out)
- [ ] License assignment (individual + bulk)
- [ ] Phone number pool upload + management
- [ ] Number assignment (individual quick-assign + bulk CSV)
- [ ] Number unassignment
- [ ] CSV templates (PhoneNumbers, BulkAssignment)
- [ ] Statistics bar on number pool page
- [ ] Export users with voice status

### Phase 4 — Resource Accounts & AA/CQ
- [ ] Resource account CRUD + licensing + number assignment
- [ ] Bulk resource account creation from CSV
- [ ] Call Queue builder (form-based with all options)
- [ ] Auto Attendant builder (multi-step wizard)
- [ ] Business hours schedule builder (day-of-week grid)
- [ ] Call flow builder (greeting → menu → options)
- [ ] After-hours and holiday flow support
- [ ] Audio file upload for greetings / hold music
- [ ] Resource account ↔ AA/CQ association
- [ ] Language & time zone lookups
- [ ] Edit existing AA/CQ support

### Phase 5 — Polish & Testing
- [ ] Pester tests — unit tests per API handler
- [ ] Pester tests — integration tests for HTTP routing
- [ ] PSScriptAnalyzer compliance
- [ ] Error handling & retry logic for all Teams/Graph calls
- [ ] Toast notifications + loading spinners in UI
- [ ] Responsive layout refinements
- [ ] Export audit log (CSV + styled HTML)
- [ ] Cleanup workflow (remove validation user licenses)
- [ ] README.md with full usage documentation
- [ ] `.gitignore` (Output/, *.log)
- [ ] Gallery publishing prep (`Publish-Module` metadata)

---

## 10. Usage

```powershell
# Install from PSGallery (future)
Install-Module -Name TeamsVoiceManager

# Or import locally during development
Import-Module .\TeamsVoiceManager\TeamsVoiceManager.psd1

# Launch the portal (default port 8080)
Start-TeamsVoiceManager

# Launch on custom port
Start-TeamsVoiceManager -Port 9090

# Launch without auto-opening browser
Start-TeamsVoiceManager -NoBrowser
```

### Launch Sequence

1. Checks for required modules (`MicrosoftTeams`, `Microsoft.Graph.*`) — installs if missing
2. Authenticates to **Microsoft Teams** (interactive browser sign-in)
3. Authenticates to **Microsoft Graph** with required scopes
4. Validates permissions and caches tenant context
5. Starts HTTP listener on `http://127.0.0.1:<port>/`
6. Opens default browser to the portal
7. Displays connection info + port in the console
8. Blocks until **✕ Close Portal** is clicked or `Ctrl+C` is pressed
9. Prompts to export the session audit log before exiting

---

## 11. CSV Templates

### PhoneNumbers_Template.csv (Number Pool Upload)

```csv
PhoneNumber,Description
+27110001001,Main Office Line 1
+27110001002,Main Office Line 2
+27110001003,Reception
+27827001001,Mobile - Sales
+27827001002,Mobile - Support
```

### BulkAssignment_Template.csv (User ↔ Number Mapping)

```csv
UserPrincipalName,PhoneNumber
john.doe@contoso.com,+27110001001
jane.smith@contoso.com,+27110001002
bob.wilson@contoso.com,+27827001001
```

### ResourceAccounts_Template.csv (Bulk RA Creation)

```csv
DisplayName,UPN,Type,PhoneNumber
RA_AA_MainLine,ra_aa_mainline@contoso.onmicrosoft.com,AutoAttendant,+27110001003
RA_CQ_Support,ra_cq_support@contoso.onmicrosoft.com,CallQueue,
RA_CQ_Sales,ra_cq_sales@contoso.onmicrosoft.com,CallQueue,+27827001002
```

---

## 12. Tech Stack Summary

| Layer | Technology |
|-------|-----------|
| **Runtime** | PowerShell 7.2+ (cross-platform) |
| **Backend** | `System.Net.HttpListener` (local HTTP server) |
| **Frontend** | Vanilla HTML5 / CSS3 / JavaScript (no framework — self-contained, no npm) |
| **Auth** | MicrosoftTeams module (interactive) + Microsoft.Graph.Authentication (interactive delegated) |
| **Styling** | Dark theme CSS, consistent with CA-Reporter / CA-BaselineAuditor / M365UserOffboarding |
| **Icons** | Inline SVG or emoji (no external CDN dependencies) |
| **Tables** | Custom JS component — sortable, filterable, paginated |
| **Testing** | Pester 5, PSScriptAnalyzer |
| **Build** | `build.ps1` (Analyze → Test → Build → CI) |
| **Distribution** | PowerShell Gallery (`Publish-Module`) |

---

## 13. Error Handling Strategy

### Backend (PowerShell)
- Every API handler wrapped in `try/catch`
- Teams/Graph errors parsed for friendly messages
- All errors logged to audit log with full exception detail
- Retry logic (3 attempts with exponential backoff) for transient Graph/Teams errors
- License assignment operations wait + verify (poll until effective)

### Frontend (JavaScript)
- Every `fetch()` call checks response status
- Error responses displayed as toast notifications (red badge)
- Success responses displayed as toast notifications (green badge)
- Loading spinners on all async operations
- Disabled buttons during in-flight requests to prevent double-submission
- Form validation before submission (E.164 format, required fields, UPN format)

### Common Error Scenarios Handled

| Scenario | Handling |
|----------|---------|
| Insufficient licenses | Display available vs. required count, block assignment |
| Domain already exists | Show current status, skip to verification |
| Voice route already exists | Offer to update existing route (Set- instead of New-) |
| User already has phone number | Show current number, confirm replacement |
| Resource account creation delay | Poll with retry until account is queryable |
| SBC FQDN not yet verified | Block voice route creation, redirect to domain page |
| Graph token expiry mid-session | Detect 401, prompt re-authentication |

---

## 14. Security Considerations

- **Local-only listener** — binds exclusively to `127.0.0.1`, no external network exposure
- **No stored credentials** — interactive auth only, tokens held in-memory for session duration
- **Audit trail** — every action logged with timestamp, admin UPN, target, and result
- **Least privilege** — Graph scopes and Teams roles are the minimum required
- **No secrets in config** — `VodacomDefaults.json` contains only non-sensitive template values
- **Session isolation** — each `Start-TeamsVoiceManager` invocation is a fresh session

---

## 15. Future Enhancements (Backlog)

- [ ] **Multi-provider support** — configurable defaults for providers beyond Vodacom
- [ ] **Template save/load** — save entire voice config as a reusable template JSON
- [ ] **Bulk AA/CQ creation** — CSV-driven Auto Attendant and Call Queue provisioning
- [ ] **Call flow visualisation** — graphical AA/CQ flow diagram (read-only from existing config)
- [ ] **Health check dashboard** — SBC health, call quality metrics via CQD
- [ ] **Migration assistant** — import from on-prem Skype for Business voice config
- [ ] **Scheduled number porting** — track number port requests with status updates
- [ ] **RBAC in portal** — role-based visibility (e.g., read-only view for non-admins)
- [ ] **Dark/light theme toggle** — user preference stored in localStorage
