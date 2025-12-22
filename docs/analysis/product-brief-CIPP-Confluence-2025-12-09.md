---
stepsCompleted: [1, 2, 3, 4, 5, 6]
workflowComplete: true
inputDocuments:
  - docs/analysis/brainstorming-session-2025-12-09.md
workflowType: 'product-brief'
lastStep: 0
project_name: 'CIPP-Confluence'
user_name: 'Matthias Kittok'
date: '2025-12-09'
---

# Product Brief: CIPP-Confluence

**Date:** 2025-12-09
**Author:** Matthias Kittok

---

## Executive Summary

CIPP-Confluence is a PowerShell module that enables MSPs to automatically sync CIPP tenant data to Atlassian Confluence. CIPP already handles M365 data collection - this module adds Confluence as an output destination, eliminating manual sync scripts and enabling self-serve documentation access for business staff and clients.

Built to solve an internal MSP need, this module will be contributed to CIPP core as a feature addon - expanding documentation platform options for MSPs who chose Confluence over alternatives like Hudu.

---

## Core Vision

### Problem Statement

MSPs using CIPP with Confluence as their documentation platform lack native integration, forcing them to:

- Run manual sync scripts daily to keep documentation current
- Field constant interruptions from business staff and clients asking about policies, assets, and users
- Maintain information silos where valuable M365 data remains trapped in CIPP

### Problem Impact

- **Daily interruptions** disrupt technical staff workflow
- **Stale documentation** creates confusion and incorrect information
- **Access bottleneck** - only CIPP users can answer basic client questions
- **Manual overhead** - sync scripts require human intervention

### Why Existing Solutions Fall Short

The HuduAPI module provides documentation sync for Hudu users, but no equivalent exists for Confluence. MSPs who chose Confluence (often for its free tier under 10 users and enterprise features appealing to midmarket clients) have no automated path.

### Proposed Solution

A ConfluenceAPI PowerShell module (~34 functions) that:

- Syncs CIPP data to Confluence when CIPP operations occur (event-triggered)
- Supports scheduled sync aligned with CIPP's M365 polling cycles
- Mirrors HuduAPI patterns for familiar developer experience
- Integrates as a CIPP core feature addon via PR

**Scope Clarity:** CIPP handles all M365 data collection. This module handles Confluence output only.

**MVP Focus:** User directory, endpoint inventory, and license data.

### Key Differentiators

| Differentiator | Value |
|----------------|-------|
| **Built for real need** | Solves internal MSP problem; community contribution is bonus |
| **Confluence-native** | First official CIPP integration for Confluence ecosystem |
| **Free tier friendly** | Enables midmarket MSPs with Confluence's <10 user free tier |
| **Clean scope** | Output layer only - no M365 complexity, just Confluence delivery |
| **HuduAPI pattern parity** | Familiar integration model, lower learning curve |

---

## Target Users

### Primary Users

#### Level 1 Support Technician - "Sarah"

**Context:** Entry-level support tech handling first-contact client requests. Needs quick answers without deep technical tool access.

**Current Pain:**

- Has to interrupt senior techs or dig into CIPP for simple lookups
- "Is this user active?" or "What's their contact info?" requires tool access she may not have or isn't trained on
- Delays in response time while waiting for answers

**Success State:**

- Opens Confluence, searches client space, finds user status in seconds
- Answers client questions on first contact without escalation
- Self-sufficient for 80% of lookup-type queries

**Frequency:** Daily lookups

---

#### Account Manager - "Mike"

**Context:** Client relationship owner responsible for billing accuracy, reporting, and client communication. Not technical, shouldn't need CIPP access.

**Current Pain:**

- Asks technicians for user counts to verify billing
- Manually compiles data for client-facing reports
- Training overhead if given CIPP access directly

**Success State:**

- Pulls user/license counts directly from Confluence for billing audits
- Creates client reports from documented data without technical assistance
- "Active users vs. billed seats" reconciliation is self-serve

**Frequency:** Weekly/Monthly reporting cycles, ad-hoc client requests

---

### Secondary Users

#### Client Technical Staff - "David" (On-Premise Deskside Support)

**Context:** Client's internal IT or deskside support. MSP manages M365, but David handles local issues. Currently blind to M365 environment details.

**Current Pain:**

- Can't troubleshoot effectively without knowing user/device state
- Submits tickets to MSP for information he could self-serve
- Delays in resolution while waiting for MSP response

**Success State:**

- Has read-only Confluence access to his company's documentation
- Looks up user info, device assignments, policies independently
- Submits better-informed tickets when escalation is needed

**Frequency:** As-needed during troubleshooting

---

#### MSP Technical Lead - "Alex" (Configuration User)

**Context:** Sets up CIPP-Confluence integration. One-time configuration, minimal ongoing maintenance.

**Current Pain:**

- Running manual sync scripts daily
- Maintaining custom integration code

**Success State:**

- Configures integration once, enables scheduled sync
- Ongoing maintenance limited to: ensuring sync runs, mapping new client accounts
- "Set and forget" operational model

**Frequency:** Initial setup + occasional new client onboarding

---

### User Journey

**Discovery:** MSP Technical Lead finds CIPP-Confluence module in CIPP documentation or community

**Onboarding:**

1. Technical Lead configures Confluence connection in CIPP
2. Maps existing clients to Confluence spaces
3. Enables scheduled sync
4. Verifies data appears in Confluence

**Core Usage:**

- Level 1 and Account Managers consume documentation daily/weekly
- Client staff access their space as needed
- Technical Lead monitors sync health occasionally

**Success Moment:**

- Level 1: First client question answered without escalation
- Account Manager: First billing audit completed without asking a technician
- Client Staff: First time finding needed info without submitting a ticket

**Long-term:** Documentation becomes trusted source of truth; manual sync scripts retired; interruptions to technical staff measurably reduced

---

## Success Metrics

### User Success Metrics

| Metric | Measurement | Target |
|--------|-------------|--------|
| **Escalation Reduction** | Fewer "info lookup" interruptions to senior techs | Measurable decrease in L1→L2 escalations for data queries |
| **Self-Service Rate** | % of lookup questions answered via Confluence | 80%+ of simple queries resolved without escalation |
| **Time to Answer** | How fast L1/AM gets needed info | Seconds (Confluence search) vs. minutes (ask someone) |
| **Billing Audit Independence** | AM completes user count verification alone | 100% self-serve for standard billing reconciliation |

### Technical Success Metrics

| Metric | Measurement | Target |
|--------|-------------|--------|
| **Sync Reliability** | Scheduled sync runs without manual intervention | 99%+ uptime, zero manual script runs required |
| **Data Freshness** | Time between CIPP data change and Confluence update | Within scheduled sync window (daily or more frequent) |
| **Setup Time** | Time from install to first successful sync | <1 hour for experienced CIPP admin |
| **Maintenance Overhead** | Ongoing admin effort required | Near-zero ("set and forget") |

### Business Objectives

**Primary Objective:** Eliminate manual sync script maintenance and reduce technician interruptions

**MVP Success Criteria:**

- Sync runs reliably on schedule without manual intervention
- Core data synced: Users, Endpoints, Licenses, MFA Status, Teams inventory, SharePoint inventory
- L1 and Account Managers actively using Confluence for lookups instead of asking technicians

**Success is Internal:** Community adoption via PR is a bonus, not a requirement. Internal productivity gains justify the investment regardless of external adoption.

### Key Performance Indicators

| KPI | Definition | How Measured |
|-----|------------|--------------|
| **Manual Scripts Retired** | Legacy sync scripts no longer needed | Binary: Yes/No |
| **Data Types Synced** | Coverage of planned data categories | 6 types: Users, Endpoints, Licenses, MFA, Teams, SharePoint |
| **Sync Failures** | Failed sync runs per month | Target: <2 failures/month |
| **Documentation Currency** | Data staleness in Confluence | Max 24 hours behind CIPP |

---

## MVP Scope

### Core Features

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

**Sync Capabilities:**

- Scheduled sync aligned with CIPP's M365 polling cycles
- Event-triggered sync for CIPP-initiated operations (pattern TBD per HuduAPI review)
- Client-to-Confluence-Space mapping (approach TBD per HuduAPI review)

**Integration Approach:**

- Self-contained module - no modifications to CIPP core code required
- Follows HuduAPI integration patterns for consistency
- PR contribution to CIPP core as feature addon

### Implementation Discovery Required

> **Prerequisite:** Review HuduAPI module code before finalizing implementation patterns for:
>
> - Tenant-to-company mapping approach
> - Sync trigger mechanisms
> - Test patterns (Pester tests)
> - Rate limiting and error handling

This discovery ensures we follow established CIPP patterns, reducing PR review friction and maintaining codebase consistency.

### Out of Scope for MVP

| Exclusion | Rationale |
|-----------|-----------|
| Bi-directional sync | Not needed; CIPP is source of truth |
| Graph API webhooks | CIPP handles M365 data collection; module is output layer only |
| Website monitoring | Confluence platform limitation, not CIPP-related |
| Intune policies/drift | Future data type expansion |
| Secure Score | Future data type expansion |
| OneDrive usage | Future data type expansion |
| CIPP core code modifications | Module must be self-contained |

### MVP Success Criteria

| Criterion | Validation |
|-----------|------------|
| **Sync Reliability** | Runs on schedule without manual intervention for 30+ days |
| **Data Coverage** | All 6 data types syncing correctly |
| **Self-Serve Adoption** | L1/AM using Confluence instead of asking technicians |
| **Legacy Retirement** | Manual sync scripts decommissioned |
| **Setup Experience** | New client space mappable in <15 minutes |

### Future Vision

**v1.1 - Additional Data Types:**

- Intune policies and configuration drift
- Secure Score data
- OneDrive usage statistics
- Conditional Access policies

**v2.0 - CIPP Core Integration:**

- PR merged to CIPP repository
- Tenant-to-Space mapping UI in CIPP
- Community adoption and feedback loop
- Documentation and onboarding guides

**Long-term:**

- Parity with HuduAPI feature set where Confluence supports equivalent functionality
- Community-driven feature requests based on MSP adoption

