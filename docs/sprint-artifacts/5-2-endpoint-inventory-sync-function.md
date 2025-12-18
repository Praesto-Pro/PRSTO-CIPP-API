# Story 5.2: Endpoint Inventory Sync Function

Status: done

## Story

As a **Technical Lead**,
I want **to sync endpoint inventory from CIPP to Confluence**,
so that **client techs can troubleshoot device issues with context**.

## Acceptance Criteria

### AC1: Create Endpoint Inventory Page
**Given** I have CIPP endpoint data and a target space
**When** I run `Sync-ConfluenceEndpointInventory -SpaceKey 'CONTOSO' -Endpoints $cippEndpoints`
**Then** an "Endpoint Inventory" page is created in the space (FR20)
**And** the page displays all endpoint data in table format
**And** the function returns a PSCustomObject with page details (Id, Title, SpaceKey, Version, Action)

### AC2: Update Existing Page
**Given** an "Endpoint Inventory" page already exists in the space
**When** I run the sync
**Then** the existing page is updated with new content
**And** the page version is incremented
**And** a PSCustomObject is returned with updated page details and Action = 'Updated'

### AC3: Support WhatIf Mode (NFR18)
**Given** I want to preview the sync operation
**When** I run `Sync-ConfluenceEndpointInventory -SpaceKey 'CONTOSO' -Endpoints $cippEndpoints -WhatIf`
**Then** the function shows what would be synced without making changes
**And** no API calls are made to create/update pages

### AC4: Support Verbose Logging (NFR19)
**Given** I want detailed operation logging
**When** I run with `-Verbose`
**Then** the function logs: "Syncing endpoint inventory to space CONTOSO"
**And** the function logs page creation/update operations
**And** the function logs endpoint count being synced

### AC5: Display Device Details (FR21)
**Given** I have CIPP endpoint data with device properties
**When** the page is created/updated
**Then** the page displays: DeviceName, OS, ComplianceStatus, AssignedUser, LastSync
**And** each column maps to the correct CIPP data property

### AC6: Display Device Assignment (FR22)
**Given** I have endpoint data with user assignment
**When** the page is created/updated
**Then** the AssignedUser column shows the primary user's displayName or UPN
**And** unassigned devices show "Unassigned"

### AC7: Handle Missing Space Gracefully
**Given** I specify a space key that doesn't exist
**When** I run the sync
**Then** a terminating error is thrown with message "Space 'INVALID' not found"
**And** the error includes actionable guidance (NFR20)

### AC8: Handle Empty Endpoints Gracefully
**Given** I have empty or null endpoint data
**When** I run the sync
**Then** the page is created with "No endpoint data available" message
**And** no errors are thrown

### AC9: Support Parent Page for Organization
**Given** I want to organize pages under a parent
**When** I run `Sync-ConfluenceEndpointInventory -SpaceKey 'CONTOSO' -Endpoints $data -ParentPageId 12345`
**Then** the page is created/updated as a child of the specified parent page

## Tasks / Subtasks

- [x] Task 1: Create Sync-ConfluenceEndpointInventory Function (AC: 1, 2, 3, 4, 7, 8, 9)
  - [x] Create `Public/Sync-ConfluenceEndpointInventory.ps1` file
  - [x] Implement `[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]`
  - [x] Add `[OutputType([PSCustomObject])]`
  - [x] Add `-SpaceKey` parameter (mandatory string)
  - [x] Add `-Endpoints` parameter for CIPP endpoint objects
  - [x] Add `-PageTitle` parameter with default 'Endpoint Inventory'
  - [x] Add `-ParentPageId` parameter (optional)
  - [x] Validate space exists using `Get-ConfluenceSpace -SpaceKey`
  - [x] Search for existing page using `Search-Confluence -CQL` (with single quote escaping)
  - [x] Use `ConvertTo-ConfluenceEndpointPage` for ADF content generation
  - [x] Create or update page using `New-ConfluencePage` / `Set-ConfluencePage`
  - [x] Implement `$PSCmdlet.ShouldProcess()` for WhatIf support
  - [x] Add `Write-Verbose` logging throughout (including after create/update)
  - [x] Add comment-based help with examples
  - [x] Return PSCustomObject with Id, Title, SpaceKey, Version, Action

- [x] Task 2: Handle Page Create vs Update Logic (AC: 1, 2)
  - [x] Search for existing page: `Search-Confluence -CQL "space = '$escapedSpaceKey' AND title = '$escapedTitle' AND type = page"`
  - [x] Escape single quotes in SpaceKey and PageTitle for CQL injection prevention
  - [x] If page exists: use `Set-ConfluencePage -PageId $existing.Id -Body $adfContent`
  - [x] If page doesn't exist: use `New-ConfluencePage -SpaceKey $SpaceKey -Title $PageTitle -Body $adfContent`
  - [x] Pass `-ParentId` to `New-ConfluencePage` when creating new page with parent
  - [x] Track operation type (Created vs Updated) for verbose logging and return object

- [x] Task 3: Implement Error Handling (AC: 7)
  - [x] Validate space exists before attempting sync
  - [x] Use `$PSCmdlet.ThrowTerminatingError()` for space not found
  - [x] Include actionable message: "Space '$SpaceKey' not found. Use Get-ConfluenceSpace to list available spaces."

- [x] Task 4: Export Function in Module Manifest (AC: 1)
  - [x] Add `Sync-ConfluenceEndpointInventory` to FunctionsToExport in ConfluenceAPI.psd1

- [x] Task 5: Create Unit Tests (AC: 1-9)
  - [x] Create `Tests/Public/Sync-ConfluenceEndpointInventory.Tests.ps1`
  - [x] Define stub functions before mocking (Pester 3.4 requirement)
  - [x] Mock `Get-ConfluenceSpace` for space validation
  - [x] Mock `Search-Confluence` for page existence check
  - [x] Mock `New-ConfluencePage` for page creation
  - [x] Mock `Set-ConfluencePage` for page update
  - [x] Mock `ConvertTo-ConfluenceEndpointPage` for ADF generation
  - [x] Test: Creates new page when none exists
  - [x] Test: Updates existing page when found
  - [x] Test: Returns PSCustomObject with correct properties
  - [x] Test: WhatIf shows operation without executing
  - [x] Test: Verbose logs operation details
  - [x] Test: Throws error for non-existent space
  - [x] Test: Handles empty endpoints gracefully
  - [x] Test: Passes endpoints to ConvertTo-ConfluenceEndpointPage
  - [x] Test: CQL query escapes single quotes
  - [x] Test: Parent page ID passed to New-ConfluencePage

- [x] Task 6: Run Validation (AC: 1-9)
  - [x] Run `Invoke-ScriptAnalyzer -Path ./Modules/ConfluenceAPI/Public/Sync-ConfluenceEndpointInventory.ps1`
  - [x] Run all Pester tests (target: 0 new warnings)
  - [x] Verify all existing tests still pass (regression check)

## Dev Notes

### Architecture Compliance

**Module Location:** `Modules/ConfluenceAPI/Public/`

Per architecture.md (lines 308-312), sync orchestration functions are Public:
- [Source: docs/architecture.md#Project-Structure-Boundaries] - Sync functions in Public/
- [Source: docs/epics.md#Story-5.2] - Acceptance criteria define public function

**Dependencies:**
- `Get-ConfluenceSpace` (Story 2.2) - for space validation
- `Search-Confluence` (Story 2.6) - for finding existing page
- `New-ConfluencePage` (Story 2.3) - for creating new page
- `Set-ConfluencePage` (Story 2.3) - for updating existing page
- `ConvertTo-ConfluenceEndpointPage` (Story 5.1) - for ADF content generation

### CRITICAL: Follow Story 4.2 Pattern EXACTLY

Story 4.2 (User Inventory Sync) is the EXACT template. Copy its structure:

```powershell
function Sync-ConfluenceEndpointInventory {
    <#
    .SYNOPSIS
        Syncs CIPP endpoint inventory to a Confluence page.
    .DESCRIPTION
        Creates or updates an Endpoint Inventory page in the specified Confluence space
        with endpoint data from CIPP. The page displays device information in table format
        including compliance status, assigned user, and last sync time.

        The function:
        - Validates the target space exists
        - Searches for an existing Endpoint Inventory page
        - Creates a new page or updates the existing one
        - Returns a PSCustomObject with page details

        Supports -WhatIf to preview operations without making changes.
    .PARAMETER SpaceKey
        The Confluence space key where the page will be created/updated.
        The space must already exist.
    .PARAMETER Endpoints
        Array of CIPP endpoint objects from Intune/Graph API.
    .PARAMETER PageTitle
        Title for the page. Defaults to 'Endpoint Inventory'.
    .PARAMETER ParentPageId
        Optional parent page ID for hierarchical organization.
    .OUTPUTS
        [PSCustomObject] - Object with Id, Title, SpaceKey, Version, Action properties
    .EXAMPLE
        Sync-ConfluenceEndpointInventory -SpaceKey 'CONTOSO' -Endpoints $cippEndpoints

        Creates or updates the Endpoint Inventory page in the CONTOSO space.
    .EXAMPLE
        Sync-ConfluenceEndpointInventory -SpaceKey 'CONTOSO' -Endpoints $endpoints -WhatIf

        Shows what would be synced without making changes.
    .NOTES
        This is a public function in the ConfluenceAPI module.
        Part of Story 5.2 - Endpoint Inventory Sync Function.

        Dependencies:
        - Get-ConfluenceSpace (Story 2.2)
        - Search-Confluence (Story 2.6)
        - New-ConfluencePage (Story 2.3)
        - Set-ConfluencePage (Story 2.3)
        - ConvertTo-ConfluenceEndpointPage (Story 5.1)
    .LINK
        Get-ConfluenceSpace
    .LINK
        Search-Confluence
    .LINK
        New-ConfluencePage
    .LINK
        Set-ConfluencePage
    .LINK
        ConvertTo-ConfluenceEndpointPage
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string]$SpaceKey,

        [Parameter()]
        [object[]]$Endpoints,

        [Parameter()]
        [string]$PageTitle = 'Endpoint Inventory',

        [Parameter()]
        [string]$ParentPageId
    )

    Write-Verbose "Syncing endpoint inventory to space '$SpaceKey'"

    # Validate space exists
    $space = Get-ConfluenceSpace -SpaceKey $SpaceKey -ErrorAction SilentlyContinue
    if (-not $space) {
        $PSCmdlet.ThrowTerminatingError(
            [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new("Space '$SpaceKey' not found. Use Get-ConfluenceSpace to list available spaces."),
                "SpaceNotFound",
                [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                $SpaceKey
            )
        )
    }

    # Generate ADF content using Story 5.1 transformer
    $adfContent = ConvertTo-ConfluenceEndpointPage -Endpoints $Endpoints
    $endpointCount = if ($Endpoints) { $Endpoints.Count } else { 0 }
    Write-Verbose "Generated ADF content for $endpointCount endpoint(s)"

    # Search for existing page using CQL (escape single quotes to prevent CQL injection)
    $escapedSpaceKey = $SpaceKey -replace "'", "''"
    $escapedTitle = $PageTitle -replace "'", "''"
    $cql = "space = '$escapedSpaceKey' AND title = '$escapedTitle' AND type = page"
    Write-Verbose "Searching for existing page with CQL: $cql"
    $existingPage = Search-Confluence -CQL $cql | Select-Object -First 1

    if ($existingPage) {
        Write-Verbose "Found existing page (ID: $($existingPage.Id)) - updating"
        if ($PSCmdlet.ShouldProcess($PageTitle, "Update Confluence page")) {
            $result = Set-ConfluencePage -PageId $existingPage.Id -Body $adfContent
            Write-Verbose "Successfully updated page '$PageTitle' (ID: $($result.Id), Version: $($result.Version.Number))"
            return [PSCustomObject]@{
                Id       = $result.Id
                Title    = $result.Title
                SpaceKey = $SpaceKey
                Version  = $result.Version.Number
                Action   = 'Updated'
            }
        }
    }
    else {
        Write-Verbose "No existing page found - creating new page"
        if ($PSCmdlet.ShouldProcess($PageTitle, "Create Confluence page")) {
            $createParams = @{
                SpaceKey = $SpaceKey
                Title    = $PageTitle
                Body     = $adfContent
            }
            if ($ParentPageId) {
                $createParams['ParentId'] = $ParentPageId
                Write-Verbose "Creating page under parent ID: $ParentPageId"
            }
            $result = New-ConfluencePage @createParams
            Write-Verbose "Successfully created page '$PageTitle' (ID: $($result.Id))"
            return [PSCustomObject]@{
                Id       = $result.Id
                Title    = $result.Title
                SpaceKey = $SpaceKey
                Version  = $result.Version.Number
                Action   = 'Created'
            }
        }
    }
}
```

### Previous Story Intelligence (Story 4.2 & 5.1)

**Key Learnings to Apply:**

1. **CQL Injection Prevention (CRITICAL from Story 4.2):**
   - Story 4.2 code review found CQL injection vulnerability
   - Fix: Escape single quotes with `$SpaceKey -replace "'", "''"`
   - Apply to BOTH SpaceKey AND PageTitle before CQL query

2. **Verbose Logging After Operations (from Story 4.2):**
   - Story 4.2 code review added logging after create/update
   - Include page ID and version in success messages

3. **Pester 3.4 Syntax (from Story 4.1 & 4.2):**
   - Use `Should Be` (no hyphen) for Windows PS 5.1 compatibility
   - Use `Should Not Be $null` for null checks
   - Use `Assert-MockCalled` (NOT `Should -Invoke`) with `-Scope It`
   - Define stub functions before mocking (required for undefined commands)

4. **Null Handling (from Story 5.1):**
   - Check for null/empty endpoints before counting
   - Use `if ($Endpoints) { $Endpoints.Count } else { 0 }` pattern
   - Empty endpoints handled by ConvertTo-ConfluenceEndpointPage (returns "No endpoint data available")

5. **Error Handling Pattern:**
   - Use `$PSCmdlet.ThrowTerminatingError()` not `throw`
   - Include actionable guidance in error message

### CIPP Endpoint Data Structure

From Story 5.1, expected CIPP endpoint object properties (from Intune/Graph API):

```powershell
[PSCustomObject]@{
    id = 'device-guid'
    deviceName = 'DESKTOP-ABC123'
    operatingSystem = 'Windows 10 Enterprise'
    osVersion = '10.0.19044.1234'
    complianceState = 'compliant'  # compliant, noncompliant, inGracePeriod, configmanager, unknown
    managementState = 'mdm'
    enrolledDateTime = '2024-01-15T10:30:00Z'
    lastSyncDateTime = '2025-12-13T08:00:00Z'
    userPrincipalName = 'user@contoso.com'
    userDisplayName = 'John Smith'
    manufacturer = 'Dell Inc.'
    model = 'Latitude 5520'
    serialNumber = 'ABC123XYZ'
}
```

### Testing Pattern (From Story 4.2)

```powershell
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $here)) 'Public'
$privateDir = Join-Path (Split-Path -Parent (Split-Path -Parent $here)) 'Private'

Describe 'Sync-ConfluenceEndpointInventory' {
    BeforeAll {
        # Define stub functions BEFORE mocking (Pester 3.4 requirement)
        function Get-ConfluenceSpace { param($SpaceKey) }
        function Search-Confluence { param($CQL) }
        function New-ConfluencePage { param($SpaceKey, $Title, $Body, $ParentId) }
        function Set-ConfluencePage { param($PageId, $Body) }
        function ConvertTo-ConfluenceEndpointPage { param($Endpoints) }

        # Dot-source the function
        . "$publicDir\Sync-ConfluenceEndpointInventory.ps1"
    }

    Context 'New Page Creation' {
        BeforeAll {
            Mock Get-ConfluenceSpace { return [PSCustomObject]@{ Id = '123'; Key = 'CONTOSO'; Name = 'Contoso Corp' } }
            Mock Search-Confluence { return $null }  # No existing page
            Mock ConvertTo-ConfluenceEndpointPage { return '{"version":1,"type":"doc","content":[]}' }
            Mock New-ConfluencePage { return [PSCustomObject]@{ Id = '456'; Title = 'Endpoint Inventory'; Version = @{ Number = 1 } } }
        }

        It 'Creates page when none exists' {
            $result = Sync-ConfluenceEndpointInventory -SpaceKey 'CONTOSO' -Endpoints @()

            $result | Should Not Be $null
            $result.Action | Should Be 'Created'
            Assert-MockCalled -CommandName 'New-ConfluencePage' -Times 1 -Scope It
        }

        It 'Returns PSCustomObject with correct properties' {
            $result = Sync-ConfluenceEndpointInventory -SpaceKey 'CONTOSO' -Endpoints @()

            $result.Id | Should Be '456'
            $result.Title | Should Be 'Endpoint Inventory'
            $result.SpaceKey | Should Be 'CONTOSO'
            $result.Version | Should Be 1
            $result.Action | Should Be 'Created'
        }
    }

    Context 'Page Update' {
        BeforeAll {
            Mock Get-ConfluenceSpace { return [PSCustomObject]@{ Id = '123'; Key = 'CONTOSO' } }
            Mock Search-Confluence { return [PSCustomObject]@{ Id = '789'; Title = 'Endpoint Inventory' } }
            Mock ConvertTo-ConfluenceEndpointPage { return '{"version":1,"type":"doc","content":[]}' }
            Mock Set-ConfluencePage { return [PSCustomObject]@{ Id = '789'; Title = 'Endpoint Inventory'; Version = @{ Number = 2 } } }
        }

        It 'Updates page when exists' {
            $result = Sync-ConfluenceEndpointInventory -SpaceKey 'CONTOSO' -Endpoints @()

            $result.Action | Should Be 'Updated'
            Assert-MockCalled -CommandName 'Set-ConfluencePage' -Times 1 -Scope It
        }
    }

    Context 'Error Handling' {
        BeforeAll {
            Mock Get-ConfluenceSpace { return $null }
        }

        It 'Throws error for non-existent space' {
            { Sync-ConfluenceEndpointInventory -SpaceKey 'INVALID' -Endpoints @() } | Should Throw "*not found*"
        }
    }

    Context 'WhatIf Support' {
        BeforeAll {
            Mock Get-ConfluenceSpace { return [PSCustomObject]@{ Id = '123'; Key = 'CONTOSO' } }
            Mock Search-Confluence { return $null }
            Mock ConvertTo-ConfluenceEndpointPage { return '{"version":1,"type":"doc","content":[]}' }
            Mock New-ConfluencePage { }
        }

        It 'Does not create page with WhatIf' {
            Sync-ConfluenceEndpointInventory -SpaceKey 'CONTOSO' -Endpoints @() -WhatIf

            Assert-MockCalled -CommandName 'New-ConfluencePage' -Times 0 -Scope It
        }
    }

    Context 'CQL Injection Prevention' {
        BeforeAll {
            Mock Get-ConfluenceSpace { return [PSCustomObject]@{ Id = '123'; Key = "CONT'OSO" } }
            Mock Search-Confluence { return $null } -Verifiable -ParameterFilter { $CQL -match "''" }
            Mock ConvertTo-ConfluenceEndpointPage { return '{"version":1,"type":"doc","content":[]}' }
            Mock New-ConfluencePage { return [PSCustomObject]@{ Id = '456'; Title = 'Endpoint Inventory'; Version = @{ Number = 1 } } }
        }

        It 'Escapes single quotes in SpaceKey' {
            Sync-ConfluenceEndpointInventory -SpaceKey "CONT'OSO" -Endpoints @()

            Assert-MockCalled -CommandName 'Search-Confluence' -Times 1 -Scope It
        }
    }

    Context 'Empty Endpoints Handling' {
        BeforeAll {
            Mock Get-ConfluenceSpace { return [PSCustomObject]@{ Id = '123'; Key = 'CONTOSO' } }
            Mock Search-Confluence { return $null }
            Mock ConvertTo-ConfluenceEndpointPage { return '{"version":1,"type":"doc","content":[]}' }
            Mock New-ConfluencePage { return [PSCustomObject]@{ Id = '456'; Title = 'Endpoint Inventory'; Version = @{ Number = 1 } } }
        }

        It 'Handles null endpoints gracefully' {
            { Sync-ConfluenceEndpointInventory -SpaceKey 'CONTOSO' -Endpoints $null } | Should Not Throw
        }

        It 'Handles empty array gracefully' {
            { Sync-ConfluenceEndpointInventory -SpaceKey 'CONTOSO' -Endpoints @() } | Should Not Throw
        }
    }

    Context 'Parent Page Support' {
        BeforeAll {
            Mock Get-ConfluenceSpace { return [PSCustomObject]@{ Id = '123'; Key = 'CONTOSO' } }
            Mock Search-Confluence { return $null }
            Mock ConvertTo-ConfluenceEndpointPage { return '{"version":1,"type":"doc","content":[]}' }
            Mock New-ConfluencePage { return [PSCustomObject]@{ Id = '456'; Title = 'Endpoint Inventory'; Version = @{ Number = 1 } } }
        }

        It 'Passes ParentPageId to New-ConfluencePage' {
            Sync-ConfluenceEndpointInventory -SpaceKey 'CONTOSO' -Endpoints @() -ParentPageId '99999'

            Assert-MockCalled -CommandName 'New-ConfluencePage' -Times 1 -Scope It -ParameterFilter {
                $ParentId -eq '99999'
            }
        }
    }
}
```

### Project Structure Notes

**File to Create:**
```text
Modules/ConfluenceAPI/
├── Public/
│   └── Sync-ConfluenceEndpointInventory.ps1    # CREATE
└── Tests/
    └── Public/
        └── Sync-ConfluenceEndpointInventory.Tests.ps1  # CREATE
```

**Module Manifest Update:**
Add to `ConfluenceAPI.psd1`:
```powershell
FunctionsToExport = @(
    # ... existing functions ...
    'Sync-ConfluenceEndpointInventory'
)
```

### Common Mistakes to Avoid

1. **DO NOT** forget to validate space exists before syncing
2. **DO NOT** use `throw` directly - use `$PSCmdlet.ThrowTerminatingError()`
3. **DO NOT** forget `SupportsShouldProcess` for WhatIf support
4. **DO NOT** forget to mock all dependencies in tests
5. **DO NOT** forget to export function in module manifest
6. **DO NOT** return raw API response - return PSCustomObject with selected properties
7. **DO NOT** forget Write-Verbose for all significant operations (INCLUDING after create/update)
8. **DO NOT** hardcode page title - use parameter with default value
9. **DO NOT** forget to handle case where Search-Confluence returns multiple results (use Select-Object -First 1)
10. **DO NOT** forget to escape single quotes in CQL queries (CQL injection prevention)
11. **DO NOT** use `Should -Invoke` - use `Assert-MockCalled` with `-Scope It` (Pester 3.4)
12. **DO NOT** forget to define stub functions before mocking (Pester 3.4 requirement)
13. **DO NOT** forget to pass ParentPageId to New-ConfluencePage when specified

### References

- [Source: docs/architecture.md#Project-Structure-Boundaries] - Sync functions in Public/
- [Source: docs/architecture.md#WhatIf-Verbose-Pattern] - ShouldProcess pattern
- [Source: docs/architecture.md#Error-Handling-Pattern] - ThrowTerminatingError pattern
- [Source: docs/epics.md#Story-5.2] - Acceptance criteria
- [Source: docs/prd.md#Data-Sync-Endpoints] - FR20-22 requirements
- [Source: docs/sprint-artifacts/4-2-user-inventory-sync-function.md] - Previous story pattern (template)
- [Source: docs/sprint-artifacts/5-1-endpoint-data-transformer.md] - Previous story (dependency)

### FRs Covered

- **FR20**: System can sync endpoint inventory from CIPP to Confluence (this story - orchestration)
- **FR21**: System can display device details (name, OS, compliance status) - via Story 5.1 dependency
- **FR22**: System can display device assignment to users - via Story 5.1 dependency
- **NFR18**: Module must include -WhatIf support for all write operations
- **NFR19**: Module must include -Verbose logging for troubleshooting
- **NFR20**: Error messages must include actionable troubleshooting guidance

## Dev Agent Record

### Context Reference

<!-- Story context analysis completed by create-story workflow -->

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

### Completion Notes List

- Implemented `Sync-ConfluenceEndpointInventory` function following Story 4.2 pattern exactly
- All 34 new unit tests pass covering all 9 acceptance criteria
- Full regression suite passes (421 tests total, 0 failures)
- PSScriptAnalyzer passes with 0 warnings
- CQL injection prevention implemented via single quote escaping
- WhatIf support for preview mode without changes
- Verbose logging throughout including after create/update operations
- Parent page support for hierarchical organization
- Empty endpoints handled gracefully via Story 5.1 transformer

### File List

| Path | Action |
|------|--------|
| Modules/ConfluenceAPI/Public/Sync-ConfluenceEndpointInventory.ps1 | Created |
| Modules/ConfluenceAPI/Tests/Public/Sync-ConfluenceEndpointInventory.Tests.ps1 | Created |
| Modules/ConfluenceAPI/ConfluenceAPI.psd1 | Modified (added function export) |

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2025-12-13 | Story created via create-story workflow | Claude Opus 4.5 |
| 2025-12-13 | Implementation complete - all tasks done, 34 tests passing, 421 total tests | Claude Opus 4.5 |
| 2025-12-13 | Code review complete - 3 MEDIUM issues fixed (ParentPageId docs, test isolation, verbose test assertions) | Claude Opus 4.5 |
