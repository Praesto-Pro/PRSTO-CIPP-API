---
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8]
inputDocuments:
  - docs/prd.md
workflowType: 'architecture'
lastStep: 8
status: 'complete'
completedAt: '2025-12-09'
project_name: 'CIPP-Confluence'
user_name: 'Matthias Kittok'
date: '2025-12-09'
---

# Architecture Decision Document

_This document builds collaboratively through step-by-step discovery. Sections are appended as we work through each architectural decision together._

## Project Context Analysis

### Requirements Overview

**Functional Requirements:**
45 FRs across 8 capability areas defining a PowerShell module that syncs CIPP tenant data to Confluence Cloud. The module serves as infrastructure consumed by CIPP's front-end, not direct end-user tooling.

Key FR categories:

- Configuration & Credentials (FR1-4): API key management, connection validation
- Space Management (FR5-9): Tenant-to-space mapping, CLIENTS-INDEX maintenance
- Page Operations (FR10-14): CRUD operations, hierarchy, labels, CQL search
- Data Sync - 6 types (FR15-33): Users, Endpoints, Licenses, MFA, Teams, SharePoint
- Sync Operations (FR34-38): Manual/scheduled sync, retry logic, incremental updates
- Monitoring & Logging (FR39-42): Execution logs, status tracking, verbose debugging
- Content Presentation (FR43-45): ADF formatting, tables, timestamps

**Non-Functional Requirements:**
21 NFRs driving architectural decisions:

| Category | Key Requirements |
|----------|------------------|
| Performance | Daily sync < 4hrs/50 tenants, page updates < 10s, graceful rate limiting |
| Security | Encrypted credential storage, no token logging, tenant isolation |
| Reliability | 99%+ sync success, 3-retry with backoff, no data corruption |
| Integration | Confluence Cloud REST API v2, HuduAPI patterns, ADF format, pagination |
| Maintainability | -WhatIf/-Verbose support, actionable errors |

**Scale & Complexity:**

- Primary domain: PowerShell Module / API Integration Layer
- Complexity level: Low-Medium
- Estimated architectural components: ~34 functions across 3 layers (Core, Resources, CIPP Integration)

### Technical Constraints & Dependencies

- **Platform**: PowerShell 5.1+ and 7+ cross-platform compatibility
- **Dependencies**: Minimal - standard PowerShell modules only
- **API Target**: Confluence Cloud REST API v2
- **Content Format**: Atlassian Document Format (ADF) - JSON-based
- **Pattern Reference**: HuduAPI module structure for CIPP ecosystem consistency

### Cross-Cutting Concerns Identified

1. **Authentication & Credentials**: Secure storage, rotation support, connection validation
2. **Rate Limiting**: 429 handling with exponential backoff across all API calls
3. **Error Handling**: Transient failure retry, detailed logging, actionable messages
4. **Pagination**: Large result set handling for all list operations
5. **Content Transformation**: CIPP data → ADF format conversion pipeline
6. **Logging**: Verbose mode, audit trails, sync status tracking
7. **Testing**: -WhatIf support for all write operations

## Starter Template Evaluation

### Primary Technology Domain

PowerShell Module / API Integration Layer - requires PowerShell-specific scaffolding approach rather than traditional web application starters.

### Starter Options Considered

| Option | Description | Fit |
|--------|-------------|-----|
| **Catesta** | Modern Plaster-based generator with CI/CD, Pester 5, cross-platform | Good - but adds complexity beyond project needs |
| **PSStucco** | Opinionated high-quality module template | Good - community patterns |
| **Manual + HuduAPI Pattern** | Mirror HuduAPI structure directly | Best - explicit PRD requirement |

### Selected Approach: HuduAPI Pattern Parity (Manual Structure)

**Rationale for Selection:**

- PRD explicitly requires "HuduAPI pattern parity" for CIPP ecosystem consistency
- Reduces CIPP integration effort with familiar conventions
- Lower learning curve for contributors already familiar with HuduAPI
- Simpler than Plaster-generated complexity for this focused module

**Reference Implementation:** CIPP's Hudu module (internal to CIPP codebase)

### Architectural Decisions - Module Structure

**Language & Runtime:**

- PowerShell 5.1+ and 7+ cross-platform compatibility
- No external dependencies beyond standard PowerShell modules

**Module Organization:**

```text
Modules/ConfluenceAPI/
├── ConfluenceAPI.psd1          # Module manifest
├── ConfluenceAPI.psm1          # Module loader
├── Public/                      # Exported functions
│   ├── Invoke-ConfluenceRequest.ps1
│   ├── New-ConfluenceAPIKey.ps1
│   ├── Get-ConfluenceSpace.ps1
│   └── ...
├── Private/                     # Internal helper functions
│   ├── ConvertTo-ADF.ps1
│   └── ...
├── Tests/                       # Pester tests
│   ├── Public/
│   └── Private/
└── Docs/                        # Documentation
```

**Code Quality:**

- PSScriptAnalyzer for linting
- Pester 5 for testing

**Development Experience:**

- `-WhatIf` and `-Verbose` support on all write operations
- Standard PowerShell parameter validation
- Consistent error handling patterns matching HuduAPI

**Note:** Module initialization will be the first implementation story - creating the folder structure and manifest files.

## Core Architectural Decisions

### Authentication & Security

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Auth Method** | Basic Auth + API Token | HuduAPI pattern; supports both user and service account tokens |
| **Service Accounts** | Supported | Atlassian service accounts with scoped tokens for production use |
| **URL Formats** | Dual support | Standard (`{domain}.atlassian.net`) and scoped (`api.atlassian.com/ex/confluence/{cloudId}`) |
| **Credential Storage** | Script-scoped variable | `$script:ConfluenceAPIKey` - memory only, matches HuduAPI pattern |
| **Token Expiry** | Document in help | Tokens expire after 1 year (March 2025+ Atlassian policy) |

### API & Communication Patterns

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Rate Limiting** | Retry-After header + exponential backoff fallback | Respects Confluence's suggested wait time |
| **Retry Logic** | 3 attempts max | NFR10 requirement |
| **Pagination** | Cursor-based (API v2 default) | Follow Confluence API patterns |

### Content Transformation

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **ADF Generation** | Helper functions in Private/ | `ConvertTo-ADF`, `New-ADFTable`, `New-ADFParagraph` - type-safe, testable |
| **Data Mapping** | CIPP object → ADF document pipeline | Separate transformation from API calls |

### Error Handling

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Error Pattern** | Standard PowerShell ErrorRecord | Works with `-ErrorAction`, pipelines, `$Error` variable |
| **Logging** | Write-Verbose throughout | NFR19 requirement |
| **WhatIf Support** | All write operations | NFR18 requirement |

### Deferred Decisions (Post-MVP)

- OAuth 2.0 support (announced November 2025)
- Webhook integration for real-time sync triggers

## Implementation Patterns & Consistency Rules

### Naming Patterns

| Element | Convention | Example |
|---------|------------|---------|
| **Functions** | Verb-ConfluenceNoun (approved verbs) | `Get-ConfluenceSpace`, `New-ConfluencePage` |
| **Parameters** | PascalCase | `-SpaceKey`, `-PageTitle`, `-ContentBody` |
| **Files** | Match function name | `Get-ConfluenceSpace.ps1` |
| **Local Variables** | camelCase | `$response`, `$pageContent` |
| **Script Variables** | script:PascalCase | `$script:ConfluenceAPIKey` |

### Structure Patterns

| Location | Purpose | Example |
|----------|---------|---------|
| `Public/` | Exported user-facing functions | `Get-ConfluenceSpace.ps1` |
| `Private/` | Internal helpers | `ConvertTo-ADF.ps1`, `Invoke-RetryRequest.ps1` |
| `Tests/Public/` | Tests for public functions | `Get-ConfluenceSpace.Tests.ps1` |
| `Tests/Private/` | Tests for internal functions | `ConvertTo-ADF.Tests.ps1` |

### API Response Patterns

**Return Format:** Native PSCustomObject (not raw JSON)

```powershell
# Good - returns typed object
[PSCustomObject]@{
    Id = $response.id
    Title = $response.title
    SpaceKey = $response.spaceKey
}

# Bad - returns raw response
return $response
```

### Error Handling Pattern

```powershell
try {
    $response = Invoke-ConfluenceRequest -Endpoint $endpoint
}
catch {
    $PSCmdlet.ThrowTerminatingError(
        [System.Management.Automation.ErrorRecord]::new(
            [System.Exception]::new("Failed to get space '$SpaceKey': $($_.Exception.Message)"),
            "ConfluenceAPIError",
            [System.Management.Automation.ErrorCategory]::ConnectionError,
            $SpaceKey
        )
    )
}
```

### WhatIf/Verbose Pattern

```powershell
function New-ConfluencePage {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory)]
        [string]$SpaceKey,
        [Parameter(Mandatory)]
        [string]$Title
    )

    Write-Verbose "Creating page '$Title' in space '$SpaceKey'"

    if ($PSCmdlet.ShouldProcess($Title, "Create Confluence page")) {
        # API call here
    }
}
```

### Enforcement Guidelines

**All Functions MUST:**

- Use approved PowerShell verbs
- Include `-Verbose` logging for all API operations
- Include `-WhatIf` support for write operations
- Return PSCustomObject (not raw JSON)
- Follow HuduAPI parameter naming conventions

## Project Structure & Boundaries

### Complete Project Directory Structure

```text
Modules/ConfluenceAPI/
├── ConfluenceAPI.psd1                    # Module manifest
├── ConfluenceAPI.psm1                    # Module loader (dot-sources Public/Private)
├── README.md                             # Module documentation (future)
├── CHANGELOG.md                          # Version history (future)
├── LICENSE                               # MIT License (future)
│
├── Public/                               # Exported functions (~28 functions)
│   │
│   ├── # Core Infrastructure (FR1-4)
│   ├── New-ConfluenceAPIKey.ps1          # Store API token in script scope
│   ├── Get-ConfluenceAPIKey.ps1          # Retrieve current API key
│   ├── Remove-ConfluenceAPIKey.ps1       # Clear stored credentials
│   ├── New-ConfluenceBaseURL.ps1         # Set instance URL (supports both formats)
│   ├── Get-ConfluenceBaseURL.ps1         # Retrieve current base URL
│   ├── Test-ConfluenceConnection.ps1     # Validate API connectivity (FR2)
│   │
│   ├── # Space Management (FR5-9)
│   ├── Get-ConfluenceSpace.ps1           # Get space(s) by key or list all
│   ├── New-ConfluenceSpace.ps1           # Create new space
│   ├── Set-ConfluenceSpace.ps1           # Update space properties
│   ├── Remove-ConfluenceSpace.ps1        # Delete space
│   │
│   ├── # Page Operations (FR10-14)
│   ├── Get-ConfluencePage.ps1            # Get page by ID or search
│   ├── New-ConfluencePage.ps1            # Create page with ADF content
│   ├── Set-ConfluencePage.ps1            # Update page content
│   ├── Remove-ConfluencePage.ps1         # Delete page
│   ├── Move-ConfluencePage.ps1           # Change page parent/location
│   │
│   ├── # Labels (FR13)
│   ├── Get-ConfluenceLabel.ps1           # Get labels on content
│   ├── Add-ConfluenceLabel.ps1           # Add label to content
│   ├── Remove-ConfluenceLabel.ps1        # Remove label from content
│   │
│   ├── # Search (FR14)
│   ├── Search-Confluence.ps1             # CQL-based search
│   │
│   ├── # Attachments
│   ├── Get-ConfluenceAttachment.ps1      # Get attachments on page
│   ├── New-ConfluenceAttachment.ps1      # Upload attachment
│   ├── Remove-ConfluenceAttachment.ps1   # Delete attachment
│   │
│   ├── # CIPP Integration Layer (FR15-45)
│   ├── Sync-CIPPTenantToConfluence.ps1   # High-level sync orchestration (FR34-38)
│   ├── New-ConfluenceClientSpace.ps1     # Create client space + index update (FR5, FR9)
│   ├── Update-ConfluenceClientIndex.ps1  # CLIENTS-INDEX maintenance (FR9)
│   └── Invoke-ConfluenceRequest.ps1      # Core API wrapper (rate limit, retry, pagination)
│
├── Private/                              # Internal helper functions (~10 functions)
│   │
│   ├── # ADF Content Transformation (FR43-45)
│   ├── ConvertTo-ADF.ps1                 # Main ADF document builder
│   ├── New-ADFDocument.ps1               # Create root ADF structure
│   ├── New-ADFTable.ps1                  # Create ADF table from objects
│   ├── New-ADFParagraph.ps1              # Create ADF paragraph
│   ├── New-ADFHeading.ps1                # Create ADF heading
│   │
│   ├── # HTTP Handling
│   ├── Invoke-RetryRequest.ps1           # Retry logic with backoff (NFR10)
│   ├── Get-RateLimitDelay.ps1            # Parse Retry-After header
│   │
│   ├── # Data Transformation
│   ├── ConvertTo-ConfluenceUserPage.ps1  # CIPP user data → ADF (FR15-19)
│   ├── ConvertTo-ConfluenceEndpointPage.ps1  # CIPP endpoint → ADF (FR20-22)
│   └── ConvertTo-ConfluenceLicensePage.ps1   # CIPP license → ADF (FR23-26)
│
├── Tests/                                # Pester 5 tests
│   ├── Public/
│   │   ├── New-ConfluenceAPIKey.Tests.ps1
│   │   ├── Get-ConfluenceSpace.Tests.ps1
│   │   ├── New-ConfluencePage.Tests.ps1
│   │   └── ...
│   ├── Private/
│   │   ├── ConvertTo-ADF.Tests.ps1
│   │   ├── New-ADFTable.Tests.ps1
│   │   └── ...
│   └── Integration/
│       └── ConfluenceAPI.Integration.Tests.ps1
│
└── Docs/
    ├── about_ConfluenceAPI.help.txt      # Module overview help
    └── Examples/
        ├── Basic-Usage.md
        └── CIPP-Integration.md
```

### Architectural Boundaries

**API Boundaries:**

| Boundary | Functions | Responsibility |
|----------|-----------|----------------|
| **External API** | `Invoke-ConfluenceRequest` | All Confluence REST API v2 calls |
| **Authentication** | `New-ConfluenceAPIKey`, `New-ConfluenceBaseURL` | Credential management |
| **CIPP Integration** | `Sync-CIPPTenantToConfluence` | Orchestration layer |

**Data Flow:**

```text
CIPP Front-end
    │
    ▼
Sync-CIPPTenantToConfluence (orchestration)
    │
    ├── ConvertTo-ConfluenceUserPage (Private/)
    ├── ConvertTo-ConfluenceEndpointPage (Private/)
    └── ConvertTo-ConfluenceLicensePage (Private/)
            │
            ▼
        ConvertTo-ADF (Private/)
            │
            ▼
        New-ConfluencePage (Public/)
            │
            ▼
        Invoke-ConfluenceRequest (Public/)
            │
            ▼
    Confluence Cloud REST API v2
```

### Requirements to Structure Mapping

| FR Category | Primary Location | Key Functions |
|-------------|------------------|---------------|
| **Configuration (FR1-4)** | `Public/` | `*-ConfluenceAPIKey`, `*-ConfluenceBaseURL` |
| **Space Management (FR5-9)** | `Public/` | `*-ConfluenceSpace`, `*-ConfluenceClientIndex` |
| **Page Operations (FR10-14)** | `Public/` | `*-ConfluencePage`, `*-ConfluenceLabel`, `Search-Confluence` |
| **Data Sync (FR15-33)** | `Private/` | `ConvertTo-Confluence*Page` |
| **Sync Operations (FR34-38)** | `Public/` | `Sync-CIPPTenantToConfluence` |
| **Monitoring (FR39-42)** | All functions | `Write-Verbose` throughout |
| **Content (FR43-45)** | `Private/` | `ConvertTo-ADF`, `New-ADF*` |

### Integration Points

**CIPP Integration:**

- Module is consumed by CIPP front-end
- `Sync-CIPPTenantToConfluence` is the primary entry point
- Accepts CIPP data objects as pipeline input

**Confluence API Integration:**

- All API calls through `Invoke-ConfluenceRequest`
- Handles both URL formats (standard and scoped)
- Centralized rate limiting and retry logic

## Architecture Validation Results

### Coherence Validation ✅

**Decision Compatibility:**
All technology choices work together without conflicts:

- PowerShell 5.1+/7+ provides cross-platform execution
- Confluence Cloud REST API v2 is the current stable API
- ADF (JSON) integrates naturally with PowerShell's `ConvertTo-Json`/`ConvertFrom-Json`
- HuduAPI patterns are PowerShell-native and well-established in CIPP ecosystem

**Pattern Consistency:**
Implementation patterns fully support architectural decisions:

- Verb-ConfluenceNoun naming aligns with PowerShell standards
- Public/Private structure matches HuduAPI reference implementation
- Error handling via ErrorRecord integrates with PowerShell pipeline

**Structure Alignment:**
Project structure enables all architectural decisions:

- Public/ exposes 28 user-facing functions
- Private/ contains ADF transformation and HTTP retry logic
- Tests/ mirrors source structure for maintainability
- Clear boundaries between CIPP integration and core API functions

### Requirements Coverage Validation ✅

**Functional Requirements Coverage:**
All 45 FRs have architectural support:

- FR1-4: Core infrastructure functions defined
- FR5-9: Space management with CLIENTS-INDEX support
- FR10-14: Full CRUD + search capabilities
- FR15-33: Data transformation pipeline in Private/
- FR34-38: Sync orchestration in Public/
- FR39-42: Write-Verbose throughout
- FR43-45: ADF helper functions

**Non-Functional Requirements Coverage:**
All 21 NFRs are architecturally addressed:

- Performance: Rate limiting, pagination, backoff
- Security: Script-scoped credentials, no logging of tokens
- Reliability: 3-retry with exponential backoff
- Integration: Dual URL support, HuduAPI patterns
- Maintainability: -WhatIf/-Verbose, PSScriptAnalyzer

### Implementation Readiness Validation ✅

**Decision Completeness:**

- All critical decisions documented with rationale
- Technology versions verified (Confluence API v2, ADF v1)
- Integration patterns specified (Basic Auth, both URL formats)

**Structure Completeness:**

- Complete 38-function module structure defined
- All files mapped to FR categories
- Clear Public/Private boundaries

**Pattern Completeness:**

- Naming conventions comprehensive
- Error handling pattern with examples
- WhatIf/Verbose pattern with code samples

### Architecture Completeness Checklist

**✅ Requirements Analysis**

- [x] Project context thoroughly analyzed (45 FRs, 21 NFRs)
- [x] Scale and complexity assessed (Low-Medium)
- [x] Technical constraints identified (PS 5.1+/7+, no dependencies)
- [x] Cross-cutting concerns mapped (7 concerns)

**✅ Architectural Decisions**

- [x] Critical decisions documented (Auth, Rate Limiting, ADF, Error Handling)
- [x] Technology stack fully specified (PowerShell, Confluence API v2, ADF)
- [x] Integration patterns defined (Basic Auth, dual URL, HuduAPI patterns)
- [x] Performance considerations addressed (backoff, pagination, retry)

**✅ Implementation Patterns**

- [x] Naming conventions established (Verb-ConfluenceNoun)
- [x] Structure patterns defined (Public/Private/Tests)
- [x] Communication patterns specified (PSCustomObject returns)
- [x] Process patterns documented (Error handling, WhatIf/Verbose)

**✅ Project Structure**

- [x] Complete directory structure defined (~38 functions)
- [x] Component boundaries established (Core/Resources/CIPP Integration)
- [x] Integration points mapped (CIPP → Module → Confluence API)
- [x] Requirements to structure mapping complete

### Architecture Readiness Assessment

**Overall Status:** READY FOR IMPLEMENTATION

**Confidence Level:** High

**Key Strengths:**

- Clear HuduAPI pattern parity reduces CIPP integration risk
- Comprehensive FR-to-function mapping ensures no gaps
- Well-documented patterns prevent AI agent conflicts
- Dual URL support future-proofs for service account migration

**Areas for Future Enhancement:**

- OAuth 2.0 support (post-MVP, when Atlassian finalizes)
- Additional data transformers for Phase 2 data types
- Webhook triggers for real-time sync (post-MVP)

### Implementation Handoff

**AI Agent Guidelines:**

- Follow all architectural decisions exactly as documented
- Use implementation patterns consistently across all components
- Respect Public/Private boundaries
- Refer to this document for all architectural questions

**First Implementation Priority:**
Create module scaffold (ConfluenceAPI.psd1, ConfluenceAPI.psm1, folder structure)
