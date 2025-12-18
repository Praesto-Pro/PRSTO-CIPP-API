---
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
workflowComplete: true
inputDocuments:
  - docs/analysis/brainstorming-session-2025-12-09.md
  - docs/analysis/product-brief-CIPP-Confluence-2025-12-09.md
documentCounts:
  briefs: 1
  research: 0
  brainstorming: 1
  projectDocs: 0
workflowType: 'prd'
lastStep: 10
project_name: 'CIPP-Confluence'
user_name: 'Matthias Kittok'
date: '2025-12-09'
---

# Product Requirements Document - CIPP-Confluence

**Author:** Matthias Kittok
**Date:** 2025-12-09

## Executive Summary

CIPP-Confluence is a PowerShell module that enables MSPs to automatically sync CIPP tenant data to Atlassian Confluence. CIPP already handles M365 data collection - this module adds Confluence as an output destination, eliminating manual sync scripts and enabling self-serve documentation access for business staff and clients.

### Problem Statement

MSPs using CIPP with Confluence as their documentation platform lack native integration, forcing them to:
- Run manual sync scripts daily to keep documentation current
- Field constant interruptions from business staff and clients asking about policies, assets, and users
- Maintain information silos where valuable M365 data remains trapped in CIPP

### Proposed Solution

A ConfluenceAPI PowerShell module (~34 functions) that:
- Syncs CIPP data to Confluence when CIPP operations occur (event-triggered)
- Supports scheduled sync aligned with CIPP's M365 polling cycles
- Mirrors HuduAPI patterns for familiar developer experience
- Integrates as a CIPP core feature addon via PR

### What Makes This Special

| Differentiator | Value |
|----------------|-------|
| **Built for real need** | Solves internal MSP problem; community contribution is bonus |
| **Confluence-native** | First official CIPP integration for Confluence ecosystem |
| **Free tier friendly** | Enables midmarket MSPs with Confluence's <10 user free tier |
| **Clean scope** | Output layer only - no M365 complexity, just Confluence delivery |
| **HuduAPI pattern parity** | Familiar integration model, lower learning curve |

## Project Classification

**Technical Type:** Developer Tool (PowerShell Module)
**Domain:** General (MSP/IT Management Tooling)
**Complexity:** Low
**Project Context:** Greenfield - new project

This project follows established patterns from CIPP's Hudu module, targeting integration as a CIPP core addon via PR to the main repository, with comprehensive documentation and examples aligned with CIPP ecosystem conventions.

## Success Criteria

### User Success

| Metric | Measurement | Target |
|--------|-------------|--------|
| **Escalation Reduction** | Fewer "info lookup" interruptions to senior techs | Measurable decrease in L1→L2 escalations for data queries |
| **Self-Service Rate** | % of lookup questions answered via Confluence | 80%+ of simple queries resolved without escalation |
| **Time to Answer** | How fast L1/AM gets needed info | Seconds (Confluence search) vs. minutes (ask someone) |
| **Billing Audit Independence** | AM completes user count verification alone | 100% self-serve for standard billing reconciliation |

**Success Moments:**

- **Level 1:** First client question answered without escalation
- **Account Manager:** First billing audit completed without asking a technician
- **Client Staff:** First time finding needed info without submitting a ticket

### Business Success

**Primary Objective:** Eliminate manual sync script maintenance and reduce technician interruptions

**Success is Internal:** Community adoption via PR is a bonus, not a requirement. Internal productivity gains justify the investment regardless of external adoption.

### Technical Success

| Metric | Measurement | Target |
|--------|-------------|--------|
| **Sync Reliability** | Scheduled sync runs without manual intervention | 99%+ uptime, zero manual script runs required |
| **Data Freshness** | Time between CIPP data change and Confluence update | Within scheduled sync window (daily or more frequent) |
| **Setup Time** | Time from install to first successful sync | <1 hour for experienced CIPP admin |
| **Maintenance Overhead** | Ongoing admin effort required | Near-zero ("set and forget") |

### Measurable Outcomes (KPIs)

| KPI | Definition | Target |
|-----|------------|--------|
| **Manual Scripts Retired** | Legacy sync scripts no longer needed | Binary: Yes/No |
| **Data Types Synced** | Coverage of planned data categories | 6 types: Users, Endpoints, Licenses, MFA, Teams, SharePoint |
| **Sync Failures** | Failed sync runs per month | <2 failures/month |
| **Documentation Currency** | Data staleness in Confluence | Max 24 hours behind CIPP |

## Product Scope

### MVP - Minimum Viable Product

**ConfluenceAPI Module (~34 functions):**

- Mirror HuduAPI pattern: `Invoke-ConfluenceRequest` core with Get/New/Set/Remove conventions
- Credential management: API key and base URL configuration
- Resource operations: Spaces, Pages, Templates, Labels, Attachments, Search

**Data Types Synced (6 total):**

| Data Type | Source | Confluence Target |
|-----------|--------|-------------------|
| Users | CIPP user directory | Client space - User inventory page |
| Endpoints | CIPP device inventory | Client space - Endpoint inventory page |
| Licenses | CIPP license data | Client space - License report page |
| MFA Status | CIPP MFA reporting | Client space - Security page |
| Teams Inventory | CIPP Teams data | Client space - Teams inventory page |
| SharePoint Inventory | CIPP SharePoint data | Client space - SharePoint inventory page |

**MVP Success Criteria:**

| Criterion | Validation |
|-----------|------------|
| Sync Reliability | Runs on schedule without manual intervention for 30+ days |
| Data Coverage | All 6 data types syncing correctly |
| Self-Serve Adoption | L1/AM using Confluence instead of asking technicians |
| Legacy Retirement | Manual sync scripts decommissioned |
| Setup Experience | New client space mappable in <15 minutes |

### Growth Features (Post-MVP)

**v1.1 - Additional Data Types:**

- Intune policies and configuration drift
- Secure Score data
- OneDrive usage statistics
- Conditional Access policies

### Vision (Future)

**v2.0 - CIPP Core Integration:**

- PR merged to CIPP repository
- Tenant-to-Space mapping UI in CIPP
- Community adoption and feedback loop
- Documentation and onboarding guides

**Long-term:**

- Parity with HuduAPI feature set where Confluence supports equivalent functionality
- Community-driven feature requests based on MSP adoption

## User Journeys

### Journey 1: Sarah Santos - The First-Contact Hero

Sarah is a Level 1 support technician at a growing MSP, handling the constant stream of "quick questions" from clients. She loves helping people but dreads the interruptions she causes - every time a client asks "Is John Smith still active?" or "What devices does Jane have?", Sarah has to ping a senior tech or wait for someone with CIPP access to look it up. She feels like a bottleneck instead of a solution.

One Monday morning, a client calls asking about a former employee's account status. Instead of her usual routine of messaging the team channel and waiting, Sarah opens Confluence, navigates to the client's space, and searches "John Smith." Within seconds, she sees his user status, last sign-in date, and assigned licenses - all synced automatically from CIPP overnight.

"His account was disabled last Friday," she tells the client confidently. "I can see he had a Business Basic license that's now available."

The client is impressed. Sarah is thrilled. She handles three more similar calls that morning without a single escalation. By the end of her first week using the synced documentation, Sarah realizes she's answering 80% of lookup questions herself. The senior techs notice too - their interruption rate has dropped dramatically, and they're finally getting deep work done.

### Journey 2: Mike Chen - The Self-Sufficient Account Manager

Mike manages relationships with 15 MSP clients and dreads the monthly billing reconciliation ritual. Every month, he needs user counts to verify invoices match actual usage. Every month, he interrupts technicians to pull the numbers. Every month, he feels like he's the annoying non-technical guy bothering the "real" workers.

During a quarterly business review with Contoso Corp, the CFO challenges a license discrepancy. Mike used to panic in these moments - he'd have to say "let me get back to you" and then chase down a technician. Not anymore.

Mike opens the Contoso Confluence space on his laptop, navigates to the License Report page, and shows the CFO exactly what they're paying for: 47 Business Premium licenses, 12 E3 licenses, and the detailed user assignments for each. The data was synced from CIPP that morning.

"Here's your complete license inventory," Mike says, turning his laptop toward the CFO. "And here's the user list with their assigned licenses. Want me to export this for your records?"

The CFO nods approvingly. Mike completes his first billing audit without asking a single technician for help. He starts building client-facing reports directly from Confluence data, transforming from "the guy who asks questions" to "the guy who has answers."

### Journey 3: David Park - The Empowered Client Tech

David handles deskside support for MegaCorp, a mid-sized company whose M365 environment is managed by their MSP. He's technically competent but constantly frustrated - every time he needs to troubleshoot a user issue, he's blind to the M365 side. "Is this user's MFA enabled?" "What groups are they in?" "When did they last sync?" All questions that require a ticket to the MSP and a 4-hour wait.

David's MSP grants him read-only access to MegaCorp's Confluence space. The first time he uses it, a user reports Outlook sync issues. David opens Confluence, finds the user in the inventory page, and immediately sees: last sync was 3 days ago, device is running outdated Outlook, and MFA was recently enabled.

"I see your MFA was just enabled on Monday," David tells the user. "Let's re-authenticate your Outlook - that usually resolves sync issues after MFA changes."

Problem solved in 5 minutes instead of 4 hours. David starts checking Confluence before every troubleshooting session. His ticket quality improves dramatically - when he does need to escalate to the MSP, his tickets now include relevant context: "User shows last sync 3 days ago, MFA enabled Monday, running Outlook 16.0.14326."

The MSP notices the improvement. David feels like a partner instead of a customer begging for scraps of information.

### Journey 4: Alex Torres - The Set-and-Forget Architect

Alex is the senior technical lead responsible for integrations and automation at the MSP. For two years, he's maintained a cobbled-together sync script that pushes CIPP data to Confluence. It works... mostly. But it breaks whenever Confluence updates their API, requires manual runs when the scheduler hiccups, and the error handling is held together with digital duct tape.

Alex hears about the ConfluenceAPI module and decides to give it a try. On a Friday afternoon, he installs the module, configures the API credentials, and maps the first client space. The familiar HuduAPI patterns make the setup intuitive - he's done in 45 minutes.

He enables scheduled sync and goes home for the weekend.

Monday morning, Alex checks the logs. The sync ran perfectly - Friday night, Saturday, Sunday. All client spaces updated. Zero errors. He checks a few pages in Confluence and sees fresh data everywhere.

Over the next month, Alex onboards 20 more clients to the sync. Each one takes about 10-15 minutes - create the space, map it to the CIPP tenant, enable sync. His old scripts sit untouched, then deprecated, then deleted.

Six months later, Alex barely thinks about the Confluence sync. It just works. He's moved on to other projects, occasionally checking the sync health dashboard when he remembers it exists. The "set and forget" dream is real.

### Journey Requirements Summary

These journeys reveal the following capability requirements:

**Core Module Capabilities:**

- Confluence API authentication and connection management
- Space creation and management
- Page creation, update, and content sync
- Scheduled sync execution with logging
- Error handling and retry logic

**Data Sync Capabilities:**

- User inventory sync (status, licenses, last sign-in)
- Endpoint inventory sync (device details, compliance)
- License report sync (assignments, availability)
- MFA status sync (enabled/disabled, methods)
- Teams inventory sync
- SharePoint inventory sync

**Operational Capabilities:**

- Client-to-Space mapping configuration
- Sync scheduling and automation
- Health monitoring and logging
- New client onboarding workflow

**Consumer Experience Capabilities:**

- Searchable documentation in Confluence
- Clean, readable page layouts
- Current data freshness indicators
- Self-serve access for non-technical users

## Developer Tool Specific Requirements

### Project-Type Overview

CIPP-Confluence is a PowerShell module designed as an API integration layer between CIPP (the front-end application) and Atlassian Confluence. The module is not used directly by end users - it serves as infrastructure that CIPP invokes to sync data to Confluence.

### Language & Platform

| Aspect | Specification |
|--------|---------------|
| **Language** | PowerShell 5.1+ / PowerShell 7+ |
| **Platform** | Cross-platform (Windows, Linux, macOS) |
| **Distribution** | CIPP addon module (PR to main repository) |
| **Dependencies** | Minimal - standard PowerShell modules only |

### Installation Methods

```powershell
# As part of CIPP (after PR merge)
# Module is included in CIPP's Modules/ directory

# Development/testing installation
# Copy module folder to PSModulePath or import directly:
Import-Module ./Modules/ConfluenceAPI/ConfluenceAPI.psd1
```

### API Surface

**Core Infrastructure (~8 functions):**

- `Invoke-ConfluenceRequest` - Core API handler (auth, rate limiting, pagination)
- `New-ConfluenceAPIKey` / `Get-ConfluenceAPIKey` / `Remove-ConfluenceAPIKey` - Credential management
- `New-ConfluenceBaseURL` / `Get-ConfluenceBaseURL` - Instance configuration

**Resource Operations (~20 functions):**

| Resource | Get | New | Set | Remove | Special |
|----------|-----|-----|-----|--------|---------|
| Space | ✓ | ✓ | ✓ | ✓ | Permissions |
| Page | ✓ | ✓ | ✓ | ✓ | Move, Copy |
| Page Content | via Page | - | ✓ | - | Convert-ToStorage |
| Template | ✓ | ✓ | ✓ | ✓ | NewFromTemplate |
| Label | ✓ | Add | - | ✓ | - |
| Attachment | ✓ | ✓ | ✓ | ✓ | - |
| Search | ✓ | - | - | - | CQL |

**CIPP Integration Layer (~6 functions):**

- `Sync-CIPPTenantToConfluence` - High-level tenant sync orchestration
- `New-ConfluenceClientSpace` - Space creation with index update
- `Update-ConfluenceClientIndex` - CLIENTS-INDEX maintenance
- `Convert-CIPPDataToConfluencePage` - Data transformation to Storage Format

### Integration Architecture

```
┌─────────────┐     ┌──────────────────┐     ┌─────────────┐
│    CIPP     │────▶│  ConfluenceAPI   │────▶│  Confluence │
│  (Front End)│     │  (This Module)   │     │  REST API   │
└─────────────┘     └──────────────────┘     └─────────────┘
                           │
                    ┌──────┴──────┐
                    │   Features  │
                    ├─────────────┤
                    │ • Auth      │
                    │ • Rate Limit│
                    │ • Pagination│
                    │ • Retry     │
                    │ • Logging   │
                    └─────────────┘
```

### Implementation Considerations

**Pattern Reference:** HuduAPI module structure

- Familiar conventions reduce CIPP integration effort
- Consistent with existing CIPP ecosystem patterns
- Lower learning curve for contributors

**Content Format:** Atlassian Document Format (ADF)

- Modern JSON-based format (Confluence's future direction)
- Better long-term compatibility than legacy Storage Format (XHTML)
- Richer formatting capabilities for data presentation

**Error Handling:**

- 429 rate limit responses with exponential backoff
- Transient failure retry logic
- Detailed error messages for troubleshooting

**Production Features:**

- `-WhatIf` support for preview mode
- `-Verbose` logging for debugging
- Audit trail via CSV logging (optional)

## Project Scoping & Phased Development

### MVP Strategy & Philosophy

**MVP Approach:** Problem-Solving MVP
Solve the core problem (manual sync scripts, technician interruptions) with minimal features that deliver immediate value.

**Scope Classification:** Simple MVP (lean scope, focused execution)

### MVP Feature Set (Phase 1)

**Core User Journeys Supported:**

- Sarah (L1) - User/license lookups without escalation
- Mike (AM) - Self-serve billing data access
- David (Client) - Read-only troubleshooting context
- Alex (Tech Lead) - One-time setup, automated operation

**Must-Have Capabilities:**

| Category | MVP Features |
|----------|--------------|
| **Core Module** | Auth, rate limiting, pagination, retry logic |
| **Resources** | Spaces, Pages, Labels, Search (CQL) |
| **Data Sync** | 6 types: Users, Endpoints, Licenses, MFA, Teams, SharePoint |
| **Operations** | Scheduled sync, client-space mapping, logging |

### Post-MVP Features

**Phase 2 (v1.1) - Additional Data Types:**

- Intune policies and configuration drift
- Secure Score data
- OneDrive usage statistics
- Conditional Access policies

**Phase 3 (v2.0) - CIPP Core Integration:**

- PR merged to CIPP repository
- Tenant-to-Space mapping UI in CIPP
- Community adoption and feedback loop
- Documentation and onboarding guides

### Risk Mitigation Strategy

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| **Confluence API changes** | Medium | High | Version-pinned API calls, monitor Atlassian changelog, automated integration tests, abstract API layer |
| **CIPP front-end changes** | Medium | High | Follow HuduAPI patterns exactly, maintain loose coupling, version compatibility matrix, early integration testing |
| **Rate limiting** | Medium | Medium | Exponential backoff, request batching, configurable delays |
| **ADF format evolution** | Low | Medium | Abstract content generation layer, follow Atlassian documentation |

## Functional Requirements

### Configuration & Credentials

- FR1: Technical Lead can configure Confluence API credentials (API key, base URL)
- FR2: Technical Lead can validate Confluence connection before enabling sync
- FR3: Technical Lead can update or rotate API credentials without data loss
- FR4: System can securely store Confluence credentials

### Space Management

- FR5: Technical Lead can create a new Confluence space for a client
- FR6: Technical Lead can map a CIPP tenant to a Confluence space
- FR7: Technical Lead can view all tenant-to-space mappings
- FR8: Technical Lead can update or remove tenant-to-space mappings
- FR9: System can update CLIENTS-INDEX page when spaces are added/removed

### Page Operations

- FR10: System can create pages within a client space
- FR11: System can update existing page content
- FR12: System can organize pages in hierarchical structure (parent/child)
- FR13: System can apply labels to pages for categorization
- FR14: System can search pages using CQL queries

### Data Sync - Users

- FR15: System can sync user inventory from CIPP to Confluence
- FR16: System can display user status (active/disabled)
- FR17: System can display user license assignments
- FR18: System can display user last sign-in date
- FR19: System can display user MFA status

### Data Sync - Endpoints

- FR20: System can sync endpoint inventory from CIPP to Confluence
- FR21: System can display device details (name, OS, compliance status)
- FR22: System can display device assignment to users

### Data Sync - Licenses

- FR23: System can sync license report from CIPP to Confluence
- FR24: System can display license types and quantities
- FR25: System can display license assignments per user
- FR26: System can display available/used license counts

### Data Sync - Security

- FR27: System can sync MFA status report from CIPP to Confluence
- FR28: System can display MFA enabled/disabled per user
- FR29: System can display MFA methods configured

### Data Sync - Collaboration

- FR30: System can sync Teams inventory from CIPP to Confluence
- FR31: System can display Teams list with membership counts
- FR32: System can sync SharePoint inventory from CIPP to Confluence
- FR33: System can display SharePoint sites with storage usage

### Sync Operations

- FR34: Technical Lead can trigger manual sync for a specific tenant
- FR35: Technical Lead can configure scheduled sync frequency
- FR36: System can execute scheduled sync without manual intervention
- FR37: System can handle sync failures with retry logic
- FR38: System can skip sync for unchanged data (incremental sync)

### Monitoring & Logging

- FR39: Technical Lead can view sync execution logs
- FR40: Technical Lead can view sync success/failure status per tenant
- FR41: System can log detailed error information for troubleshooting
- FR42: Technical Lead can enable verbose logging for debugging

### Content Presentation

- FR43: System can format data as readable tables in Confluence
- FR44: System can display data freshness timestamp on pages
- FR45: System can generate ADF-formatted content for Confluence pages

## Non-Functional Requirements

### Performance

- NFR1: Sync operations must complete within scheduled window (daily sync < 4 hours for 50 tenants)
- NFR2: Individual page updates must complete within 10 seconds
- NFR3: API rate limiting must not cause sync failures (graceful backoff)
- NFR4: Confluence search results must return within 3 seconds for end users

### Security

- NFR5: Confluence API credentials must be stored securely (encrypted at rest)
- NFR6: API tokens must never be logged or exposed in error messages
- NFR7: Module must support credential rotation without sync interruption
- NFR8: No tenant data from one client must be visible to another client's Confluence space

### Reliability

- NFR9: Scheduled sync must achieve 99%+ success rate over 30-day period
- NFR10: Transient failures must retry automatically (up to 3 attempts with backoff)
- NFR11: Sync failures must not corrupt existing Confluence data
- NFR12: System must recover gracefully from Confluence API outages

### Integration

- NFR13: Module must support Confluence Cloud REST API v2
- NFR14: Module must follow HuduAPI patterns for CIPP integration consistency
- NFR15: Module must handle Confluence API pagination for large result sets
- NFR16: Module must support Atlassian Document Format (ADF) for content
- NFR17: Module must work with Confluence free tier (<10 users) and paid tiers

### Maintainability

- NFR18: Module must include `-WhatIf` support for all write operations
- NFR19: Module must include `-Verbose` logging for troubleshooting
- NFR20: Error messages must include actionable troubleshooting guidance
- NFR21: Module must follow PowerShell best practices and CIPP codebase conventions for PR acceptance

