---
stepsCompleted: [1, 2, 3, 4]
workflowComplete: true
inputDocuments:
  - docs/prd.md
  - docs/architecture.md
  - docs/sprint-artifacts/epic-9-retro-2025-12-18.md
  - docs/sprint-artifacts/epic-10-retro-2025-12-18.md
  - docs/analysis/research/technical-cipp-extension-integration-research-2025-12-18.md
---

# CIPP-Confluence - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for CIPP-Confluence, a PowerShell module that syncs CIPP tenant data to Atlassian Confluence. The module follows HuduAPI patterns for CIPP ecosystem consistency.

**Project Status:** Epics 1-9 complete (ConfluenceAPI module). Epic 10 in progress (CIPP extension integration).

## Requirements Inventory

### Functional Requirements (45 FRs)

| Category | FRs | Description |
|----------|-----|-------------|
| Configuration & Credentials | FR1-FR4 | API key, base URL, connection validation, secure storage |
| Space Management | FR5-FR9 | Create spaces, tenant mapping, CLIENTS-INDEX |
| Page Operations | FR10-FR14 | CRUD, hierarchy, labels, CQL search |
| Data Sync - Users | FR15-FR19 | User inventory, status, licenses, sign-in, MFA |
| Data Sync - Endpoints | FR20-FR22 | Device inventory, details, assignment |
| Data Sync - Licenses | FR23-FR26 | License report, types, assignments, counts |
| Data Sync - Security | FR27-FR29 | MFA status report, methods |
| Data Sync - Collaboration | FR30-FR33 | Teams inventory, SharePoint sites |
| Sync Operations | FR34-FR38 | Manual sync, scheduling, retry, incremental |
| Monitoring & Logging | FR39-FR42 | Logs, status, errors, verbose |
| Content Presentation | FR43-FR45 | Tables, timestamps, ADF format |

### Non-Functional Requirements (21 NFRs)

| Category | NFRs | Key Requirements |
|----------|------|------------------|
| Performance | NFR1-NFR4 | <4hrs/50 tenants, <10s page updates, graceful rate limiting |
| Security | NFR5-NFR8 | Encrypted credentials, no token logging, tenant isolation |
| Reliability | NFR9-NFR12 | 99%+ success, 3 retries, no data corruption |
| Integration | NFR13-NFR17 | Confluence API v2, HuduAPI patterns, ADF, pagination |
| Maintainability | NFR18-NFR21 | -WhatIf, -Verbose, actionable errors |

## FR Coverage Map

| Epic | FRs Covered | Status |
|------|-------------|--------|
| Epic 1 | FR1, FR2, FR3, FR4 | ✅ Done |
| Epic 2 | FR10, FR11, FR12, FR13, FR14 | ✅ Done |
| Epic 3 | FR43, FR44, FR45 | ✅ Done |
| Epic 4 | FR15, FR16, FR17, FR18, FR19 | ✅ Done |
| Epic 5 | FR20, FR21, FR22, FR23, FR24, FR25, FR26 | ✅ Done |
| Epic 6 | FR27, FR28, FR29, FR30, FR31, FR32, FR33 | ✅ Done |
| Epic 7 | FR5, FR6, FR7, FR8, FR9 | ✅ Done |
| Epic 8 | FR34, FR35, FR36, FR37, FR38 | ✅ Done |
| Epic 9 | FR39, FR40, FR41, FR42 | ✅ Done |
| Epic 10 | Integration requirements (Epic 9 Retro) | 🔄 In Progress |

**All 45 FRs covered.**

---

## Epic List

### Epic 1: Module Foundation & API Connection ✅

Technical Lead can install the module, configure Confluence credentials, and validate the API connection works.

| Story | Title | Status |
|-------|-------|--------|
| 1.1 | Module Scaffold & Manifest | done |
| 1.2 | API Key Credential Management | done |
| 1.3 | Base URL Configuration | done |
| 1.4 | Connection Validation | done |

**FRs covered:** FR1, FR2, FR3, FR4

---

### Epic 2: Core API Operations ✅

Technical Lead can create/read/update/delete Confluence spaces and pages programmatically.

| Story | Title | Status |
|-------|-------|--------|
| 2.1 | Core API Request Handler | done |
| 2.2 | Space Operations | done |
| 2.3 | Page CRUD Operations | done |
| 2.4 | Page Movement & Hierarchy | done |
| 2.5 | Label Operations | done |
| 2.6 | CQL Search | done |

**FRs covered:** FR10, FR11, FR12, FR13, FR14

---

### Epic 3: ADF Content Generation ✅

Technical Lead can generate properly formatted Confluence content (tables, text, timestamps) in Atlassian Document Format.

| Story | Title | Status |
|-------|-------|--------|
| 3.1 | ADF Document Builder | done |
| 3.2 | ADF Table Generation | done |
| 3.3 | ADF Text Elements | done |

**FRs covered:** FR43, FR44, FR45

---

### Epic 4: User Data Sync ✅

Technical Lead can sync CIPP user data to Confluence pages (status, licenses, sign-in, MFA).

| Story | Title | Status |
|-------|-------|--------|
| 4.1 | User Data Transformer | done |
| 4.2 | User Inventory Sync Function | done |

**FRs covered:** FR15, FR16, FR17, FR18, FR19

---

### Epic 5: Endpoint & License Data Sync ✅

Technical Lead can sync device inventory and license reports to Confluence.

| Story | Title | Status |
|-------|-------|--------|
| 5.1 | Endpoint Data Transformer | done |
| 5.2 | Endpoint Inventory Sync Function | done |
| 5.3 | License Data Transformer | done |
| 5.4 | License Report Sync Function | done |

**FRs covered:** FR20, FR21, FR22, FR23, FR24, FR25, FR26

---

### Epic 6: Security & Collaboration Data Sync ✅

Technical Lead can sync MFA status, Teams inventory, and SharePoint data to Confluence.

| Story | Title | Status |
|-------|-------|--------|
| 6.1 | MFA Status Transformer & Sync | done |
| 6.2 | Teams Inventory Transformer & Sync | done |
| 6.3 | SharePoint Inventory Transformer & Sync | done |

**FRs covered:** FR27, FR28, FR29, FR30, FR31, FR32, FR33

---

### Epic 7: Client Space Management ✅

Technical Lead can create client spaces, manage tenant-to-space mappings, and maintain the CLIENTS-INDEX.

| Story | Title | Status |
|-------|-------|--------|
| 7.1 | Client Space Creation | done |
| 7.2 | Tenant-Space Mapping Management | done |
| 7.3 | CLIENTS-INDEX Maintenance | done |

**FRs covered:** FR5, FR6, FR7, FR8, FR9

---

### Epic 8: Sync Orchestration & Automation ✅

Technical Lead can trigger manual syncs, configure schedules, and rely on automatic sync with retry logic.

| Story | Title | Status |
|-------|-------|--------|
| 8.1 | Manual Tenant Sync | done |
| 8.2 | Sync Configuration | done |
| 8.3 | Retry Logic & Error Recovery | done |
| 8.4 | Incremental Sync Support | done |

**FRs covered:** FR34, FR35, FR36, FR37, FR38

---

### Epic 9: Monitoring & Observability ✅

Technical Lead can view sync logs, monitor status, troubleshoot errors, and enable verbose debugging.

| Story | Title | Status |
|-------|-------|--------|
| 9.1 | Sync Execution Logging | done |
| 9.2 | Sync Status Dashboard | done |
| 9.3 | Error Reporting & Troubleshooting | done |

**FRs covered:** FR39, FR40, FR41, FR42

---

### Epic 10: CIPP Extension Framework Integration 🔄

Technical Lead can use the ConfluenceAPI module as a fully-integrated CIPP extension - with automatic scheduled syncs, configuration management, and cache-based data flow matching the Hudu pattern.

| Story | Title | Priority | Status |
|-------|-------|----------|--------|
| 10.1 | Extension Sync Orchestrator | HIGH | done |
| 10.2 | Scheduled Task Registration | HIGH | ready-for-dev |
| 10.3 | Configuration Management | MEDIUM | backlog |
| 10.4 | Cache Integration | MEDIUM | backlog |
| 10.5 | API Key Framework Integration | LOW | backlog |

**Integration Requirements (from Epic 9 Retrospective):**

| Capability | Hudu Pattern | Confluence Status |
|------------|--------------|-------------------|
| Extension Sync Orchestrator | `Invoke-HuduExtensionSync` | ✅ Story 10.1 done |
| Scheduled Task Registration | `Register-CippExtensionScheduledTasks` | 📋 Story 10.2 ready |
| Configuration Storage | `Extensionsconfig` table | 📋 Story 10.3 backlog |
| Cache Integration | `CacheExtensionSync` table | 📋 Story 10.4 backlog |
| API Key Framework | `Get-ExtensionAPIKey -Extension 'Confluence'` | 📋 Story 10.5 backlog |

**Key Deliverables:**
- Confluence appears alongside Hudu in CIPP's extension dropdown
- Scheduled syncs auto-register for mapped tenants
- Data flows from CIPP cache → Confluence pages without manual intervention

**Dependencies:**
- All of Epic 1-9 (ConfluenceAPI module) ✅ Complete
- Hudu implementation as reference pattern ✅ Available in `Modules/CippExtensions/Public/Hudu/`

---

## Epic 10 Story Details

### Story 10.1: Extension Sync Orchestrator ✅

**As a** Technical Lead,
**I want** a single orchestrator function that reads from CIPP cache and syncs to Confluence,
**So that** Confluence integration follows the same data flow pattern as Hudu.

**Acceptance Criteria:**

**AC1: Cache Data Source**
**Given** `CacheExtensionSync` table contains tenant data
**When** `Invoke-ConfluenceExtensionSync` is called
**Then** it reads from `Get-ExtensionCacheData -TenantFilter $TenantFilter`
**And** does NOT call Microsoft Graph API directly

**AC2: Tenant Mapping Resolution**
**Given** a tenant filter is provided
**When** the orchestrator runs
**Then** it resolves the Confluence space from `CippMapping` table
**And** uses `PartitionKey = 'ConfluenceMapping'`

**AC3: Sync Function Delegation**
**Given** cached data is loaded
**When** sync operations execute
**Then** existing `Sync-Confluence*` functions are called with transformed data
**And** data is transformed to match expected input formats

**AC4: Standardized Result Object**
**Given** sync operations complete
**When** the function returns
**Then** it returns `[PSCustomObject]@{ Name; Users; Devices; Errors; Logs }`
**And** `Errors` and `Logs` are Generic Lists for O(1) append

**AC5: Error Isolation**
**Given** multiple data types are being synced
**When** one data type sync fails
**Then** other data types continue to sync
**And** the error is captured in the `Errors` list

**Status:** Done (implemented in `Modules/CippExtensions/Public/Confluence/`)

---

### Story 10.2: Scheduled Task Registration

**As a** Technical Lead,
**I want** Confluence to be registered in CIPP's scheduled task system like Hudu,
**So that** tenant syncs run automatically without manual intervention.

**Acceptance Criteria:**

**AC1: Extension List Registration**
**Given** the `Register-CIPPExtensionScheduledTasks` function exists
**When** it processes extension registrations
**Then** 'Confluence' is included in the default extensions list
**And** it appears alongside 'Hudu', 'NinjaOne', and 'CustomData'

**AC2: Sync Task Creation for Mapped Tenants**
**Given** Confluence extension is enabled in Extensionsconfig
**And** tenant mappings exist in CippMapping with PartitionKey = 'ConfluenceMapping'
**When** `Register-CIPPExtensionScheduledTasks` runs
**Then** a Push task is created for each mapped tenant
**And** the task calls `Push-CippExtensionData -Extension 'Confluence' -TenantFilter $TenantFilter`
**And** the task is hidden from the UI (`Hidden = $true`)

**AC3: Task Scheduling Parameters**
**Given** a Confluence push task is created
**When** the task parameters are set
**Then** `Recurrence` is set to '1d' (daily)
**And** `ScheduledTime` is set to `$NextSync`
**And** `SyncType` is set to 'Confluence'

**AC4: Disabled Extension Cleanup**
**Given** Confluence extension was enabled but is now disabled
**When** `Register-CIPPExtensionScheduledTasks` runs
**Then** existing Confluence push tasks are removed from ScheduledTasks table

**AC5: Removed Tenant Cleanup**
**Given** a tenant mapping was removed from CippMapping
**When** `Register-CIPPExtensionScheduledTasks` runs
**Then** the push task for that tenant is removed

**AC6: Idempotent Registration**
**Given** a push task already exists for a tenant
**When** `Register-CIPPExtensionScheduledTasks` runs (without `-Reschedule`)
**Then** the existing task is NOT recreated or duplicated

**AC7: Reschedule Support**
**Given** existing push tasks need to be rescheduled
**When** `Register-CIPPExtensionScheduledTasks -Reschedule` is called
**Then** existing Confluence tasks are updated with new `ScheduledTime`

**Status:** Ready for dev

---

### Story 10.3: Configuration Management

**As a** Technical Lead,
**I want** Confluence settings stored in CIPP's `Extensionsconfig` table,
**So that** configuration persists and follows the Hudu pattern.

**Acceptance Criteria:**

**AC1: Configuration Schema**
**Given** the Extensionsconfig table exists
**When** Confluence configuration is stored
**Then** a 'Confluence' section exists in the JSON structure
**And** it includes: Enabled, BaseURL, CloudId, SyncUsers, SyncDevices, SyncLicenses, SyncMFA, SyncTeams, SyncSharePoint, NextSync

**AC2: Enable/Disable Control**
**Given** Confluence section exists in Extensionsconfig
**When** `Enabled` is set to `$true`
**Then** the extension is activated for sync operations
**And** when `Enabled` is set to `$false`, sync operations are skipped

**AC3: BaseURL Configuration**
**Given** Confluence BaseURL is configured
**When** `Connect-ConfluenceAPI` is called
**Then** it uses the BaseURL from Extensionsconfig
**And** supports both standard and scoped URL formats

**AC4: Sync Type Toggle**
**Given** individual sync options exist (SyncUsers, SyncDevices, etc.)
**When** a sync option is set to `$false`
**Then** that data type is skipped during sync
**And** other enabled data types continue to sync

**AC5: NextSync Timestamp**
**Given** a sync operation completes
**When** the next sync is scheduled
**Then** `NextSync` is updated with the scheduled timestamp
**And** this timestamp is used by `Register-CIPPExtensionScheduledTasks`

**Status:** Backlog

---

### Story 10.4: Cache Integration

**As a** Technical Lead,
**I want** page content hashes cached for change detection,
**So that** incremental sync avoids redundant Confluence API calls.

**Acceptance Criteria:**

**AC1: Cache Table Creation**
**Given** the Azure Table Storage is accessible
**When** the first page sync occurs
**Then** `CacheConfluencePages` table is created if not exists
**And** entries use PartitionKey = 'ConfluencePage', RowKey = PageId

**AC2: Hash Storage**
**Given** a page is synced to Confluence
**When** the sync completes successfully
**Then** the content hash is stored in `CacheConfluencePages`
**And** the hash is a SHA1 of the page content

**AC3: Change Detection**
**Given** a page sync is requested
**When** the new content hash matches the cached hash
**Then** the Confluence API update is skipped
**And** a log entry indicates "Page unchanged, skipping update"

**AC4: Hash Mismatch Update**
**Given** a page sync is requested
**When** the new content hash differs from the cached hash
**Then** the Confluence API update is performed
**And** the cache is updated with the new hash

**AC5: Cache Invalidation**
**Given** a tenant mapping is removed
**When** cleanup runs
**Then** related cache entries are removed from `CacheConfluencePages`

**Status:** Backlog

---

### Story 10.5: API Key Framework Integration

**As a** Technical Lead,
**I want** Confluence API key managed via CIPP's Key Vault integration,
**So that** credentials are stored securely following the Hudu pattern.

**Acceptance Criteria:**

**AC1: Key Vault Storage (Production)**
**Given** the environment is production
**When** `Get-ExtensionAPIKey -Extension 'Confluence'` is called
**Then** the API key is retrieved from Azure Key Vault
**And** the secret name is 'Confluence'

**AC2: DevSecrets Fallback (Development)**
**Given** the environment is development (`UseDevelopmentStorage=true`)
**When** `Get-ExtensionAPIKey -Extension 'Confluence'` is called
**Then** the API key is retrieved from the DevSecrets table
**And** the PartitionKey is 'Confluence'

**AC3: Environment Caching**
**Given** an API key is retrieved
**When** subsequent calls request the same key
**Then** the key is returned from environment variable cache (`$env:Ext_Confluence`)
**And** Key Vault/DevSecrets is not called again

**AC4: Connect-ConfluenceAPI Integration**
**Given** `Connect-ConfluenceAPI` is called
**When** it needs the API key
**Then** it uses `Get-ExtensionAPIKey -Extension 'Confluence'`
**And** does NOT use the module's internal `$script:ConfluenceAPIKey`

**AC5: Token Rotation Support**
**Given** the API key in Key Vault is rotated
**When** the environment cache is cleared or expires
**Then** the new key is retrieved and used
**And** existing sync operations are not interrupted

**Status:** Backlog

---

## Module Completion Status

### ConfluenceAPI Module (Epics 1-9): ✅ COMPLETE

| Epic | Description | Stories | Status |
|------|-------------|---------|--------|
| 1 | Module Foundation & API Connection | 4 | Done |
| 2 | Core API Operations | 6 | Done |
| 3 | ADF Content Generation | 3 | Done |
| 4 | User Data Sync | 2 | Done |
| 5 | Endpoint & License Data Sync | 4 | Done |
| 6 | Security & Collaboration Data Sync | 3 | Done |
| 7 | Client Space Management | 3 | Done |
| 8 | Sync Orchestration & Automation | 4 | Done |
| 9 | Monitoring & Observability | 3 | Done |

**Total:** 27 stories, 45 FRs covered, 1,657+ tests passing

### CIPP Integration (Epic 10): 🔄 IN PROGRESS

| Story | Description | Priority | Status |
|-------|-------------|----------|--------|
| 10.1 | Extension Sync Orchestrator | HIGH | Done |
| 10.2 | Scheduled Task Registration | HIGH | Ready for dev |
| 10.3 | Configuration Management | MEDIUM | Backlog |
| 10.4 | Cache Integration | MEDIUM | Backlog |
| 10.5 | API Key Framework Integration | LOW | Backlog |

**Total:** 5 stories, 1 done, 4 remaining

---


### Epic 11: Production Readiness & Process Improvements

**Status:** ? Pending
**Details:** See [Epic 11: Production Readiness & Process Improvements](epics/epic-11-production-readiness.md)

**Story Overview:**

| Story | Title | Priority | Status |
|-------|-------|----------|--------|
| 11.1 | Comprehensive Security Code Review | CRITICAL | backlog |
| 11.2 | Live Integration Testing | CRITICAL | backlog |
| 11.3 | CI/CD Pipeline Verification | HIGH | backlog |
| 11.4 | Deployment Documentation | HIGH | backlog |
| 11.5 | Stakeholder Demo and Acceptance | CRITICAL | backlog |
| 11.6 | Document PS 5.1 Compatibility Patterns | Process | backlog |
| 11.7 | Create Story Title Guidelines | Process | backlog |

**Key Deliverables:**
- Security issues identified and resolved
- Live testing validates all sync operations
- CI/CD pipeline verified or manual procedure documented
- Complete deployment documentation ready
- Stakeholder acceptance obtained
- Process documentation prevents future friction

**Dependencies:**
- Epic 10 complete ?
- Test CIPP environment available
- Stakeholder availability for demo
- **Production deployment blocked until Epic 11 complete**
