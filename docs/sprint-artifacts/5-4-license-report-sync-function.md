# Story 5.4: License Report Sync Function

Status: Done

## Story

As a **Technical Lead**,
I want **to sync license reports from CIPP to Confluence**,
so that **Account Managers can perform billing audits self-serve**.

## Acceptance Criteria

### AC1: Create License Report Page (FR23)
**Given** I have CIPP license data and a target space
**When** I run `Sync-ConfluenceLicenseReport -SpaceKey 'CONTOSO' -Licenses $cippLicenses`
**Then** a "License Report" page is created in the space
**And** the function returns a PSCustomObject with Id, Title, SpaceKey, Version, Action

### AC2: Update Existing License Report Page
**Given** a License Report page already exists in the space
**When** I run `Sync-ConfluenceLicenseReport`
**Then** the existing page is updated with new content
**And** the page version is incremented
**And** Action returns 'Updated'

### AC3: Display License Types and Quantities (FR24)
**Given** I have license inventory data
**When** the page content is generated
**Then** the page shows license types with Total, Used, Available columns
**And** each row shows one license type with its quantities

### AC4: Display License Assignments (FR25)
**Given** I provide both license data and user data
**When** I run `Sync-ConfluenceLicenseReport -Licenses $licenses -Users $users`
**Then** the page includes a user-to-license assignments table
**And** users with multiple licenses appear on multiple rows

### AC5: Display Available/Used Counts (FR26)
**Given** license data has prepaidUnits and consumedUnits
**When** the summary table is generated
**Then** Available = prepaidUnits.enabled - consumedUnits
**And** negative values show as 0 (over-allocation)

### AC6: Support -WhatIf (NFR18)
**Given** I want to preview sync operations
**When** I run `Sync-ConfluenceLicenseReport -WhatIf`
**Then** no changes are made to Confluence
**And** the function returns null

### AC7: Support -Verbose Logging (NFR19)
**Given** I want detailed operation logging
**When** I run with `-Verbose`
**Then** the function logs: "Syncing license report to space 'X'"
**And** logs search results and page creation/update operations

### AC8: Validate Space Exists (Error Handling)
**Given** I specify a space that doesn't exist
**When** I run `Sync-ConfluenceLicenseReport -SpaceKey 'INVALID'`
**Then** a terminating error is thrown
**And** the error message includes actionable guidance mentioning Get-ConfluenceSpace

### AC9: Handle Empty License Data
**Given** I have null or empty license data
**When** I run `Sync-ConfluenceLicenseReport -Licenses $null`
**Then** a page is still created with "No license data available" message
**And** no errors are thrown

### AC10: Support Parent Page Hierarchy
**Given** I want the page under a specific parent
**When** I run `Sync-ConfluenceLicenseReport -ParentPageId '12345'`
**Then** the new page is created as a child of the parent
**And** existing pages are not moved (only applies to creation)

## Tasks / Subtasks

- [x] Task 1: Create Sync-ConfluenceLicenseReport Function (AC: 1, 2, 6, 7, 8, 9, 10)
  - [x] Create `Public/Sync-ConfluenceLicenseReport.ps1` file
  - [x] Add `[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]`
  - [x] Add `[OutputType([PSCustomObject])]` for return type
  - [x] Add `-SpaceKey` parameter (Mandatory string)
  - [x] Add `-Licenses` parameter (object array) - license inventory
  - [x] Add `-Users` parameter (object array, optional) - for assignments table
  - [x] Add `-PageTitle` parameter (default: 'License Report')
  - [x] Add `-ParentPageId` parameter (optional string)
  - [x] Validate space exists using `Get-ConfluenceSpace`
  - [x] Generate ADF content using `ConvertTo-ConfluenceLicensePage` (Story 5.3)
  - [x] Search for existing page using CQL with quote escaping
  - [x] Create page with `New-ConfluencePage` if not exists
  - [x] Update page with `Set-ConfluencePage` if exists
  - [x] Implement `$PSCmdlet.ShouldProcess` for WhatIf support
  - [x] Add `Write-Verbose` logging throughout
  - [x] Return PSCustomObject with Id, Title, SpaceKey, Version, Action
  - [x] Add comment-based help with examples

- [x] Task 2: Create Unit Tests (AC: 1-10)
  - [x] Create `Tests/Public/Sync-ConfluenceLicenseReport.Tests.ps1`
  - [x] Test: Creates page when none exists (AC1)
  - [x] Test: Returns PSCustomObject with correct properties (AC1)
  - [x] Test: Updates page when exists (AC2)
  - [x] Test: Increments version on update (AC2)
  - [x] Test: Passes Users parameter to transformer (AC4)
  - [x] Test: Does not create page with WhatIf (AC6)
  - [x] Test: Returns null with WhatIf (AC6)
  - [x] Test: Writes verbose messages (AC7)
  - [x] Test: Throws error for non-existent space (AC8)
  - [x] Test: Error message includes actionable guidance (AC8)
  - [x] Test: Handles null licenses without error (AC9)
  - [x] Test: Handles empty array without error (AC9)
  - [x] Test: Accepts ParentPageId parameter (AC10)
  - [x] Test: Passes ParentPageId to New-ConfluencePage (AC10)
  - [x] Test: Uses correct CQL query format
  - [x] Test: Escapes single quotes in CQL for safety

- [x] Task 3: Run Validation (AC: 1-10)
  - [x] Run `Invoke-ScriptAnalyzer -Path ./Modules/ConfluenceAPI/Public/Sync-ConfluenceLicenseReport.ps1`
  - [x] Run all Pester tests (target: 0 new warnings)
  - [x] Verify all existing tests still pass (regression check)

## Dev Notes

### Architecture Compliance

**Module Location:** `Modules/ConfluenceAPI/Public/`

Per architecture.md (lines 309-312), sync functions are Public orchestration functions:
- [Source: docs/architecture.md#Project-Structure-Boundaries] - `Sync-*` functions in Public/
- [Source: docs/epics.md#Story-5.4] - Acceptance criteria define public function

**Dependencies:**
- `Get-ConfluenceSpace` (Story 2.2) - for space validation
- `Search-Confluence` (Story 2.6) - for existing page lookup
- `New-ConfluencePage` (Story 2.3) - for page creation
- `Set-ConfluencePage` (Story 2.3) - for page updates
- `ConvertTo-ConfluenceLicensePage` (Story 5.3) - for ADF content generation

### CRITICAL: Follow Story 5.2 Pattern Exactly

Story 5.2 (Endpoint Inventory Sync Function) is the template for this story. The implementation pattern is nearly identical - just swap endpoints for licenses and add the Users parameter.

**Key differences from Story 5.2:**
1. Additional `-Users` parameter for license assignments table
2. Uses `ConvertTo-ConfluenceLicensePage` instead of `ConvertTo-ConfluenceEndpointPage`
3. Default page title is 'License Report' instead of 'Endpoint Inventory'

```powershell
function Sync-ConfluenceLicenseReport {
    <#
    .SYNOPSIS
        Syncs CIPP license report to a Confluence page.
    .DESCRIPTION
        Creates or updates a License Report page in the specified Confluence space
        with license data from CIPP. The page displays license summary with
        quantities and optionally user assignments.

        The function:
        - Validates the target space exists
        - Searches for an existing License Report page
        - Creates a new page or updates the existing one
        - Returns a PSCustomObject with page details

        Supports -WhatIf to preview operations without making changes.
    .PARAMETER SpaceKey
        The Confluence space key where the page will be created/updated.
        The space must already exist.
    .PARAMETER Licenses
        Array of CIPP license inventory objects from ListLicenses API.
        Expected properties: skuId, skuPartNumber, prepaidUnits, consumedUnits.
    .PARAMETER Users
        Optional array of CIPP user objects with assignedLicenses for
        generating the license assignments table.
    .PARAMETER PageTitle
        Title for the page. Defaults to 'License Report'.
    .PARAMETER ParentPageId
        Optional parent page ID for hierarchical organization.
        Note: Only applies when creating new pages. Existing pages are not moved.
        Use Move-ConfluencePage to relocate an existing page.
    .OUTPUTS
        [PSCustomObject] - Object with Id, Title, SpaceKey, Version, Action properties
    .EXAMPLE
        Sync-ConfluenceLicenseReport -SpaceKey 'CONTOSO' -Licenses $cippLicenses

        Creates or updates the License Report page in the CONTOSO space.
    .EXAMPLE
        Sync-ConfluenceLicenseReport -SpaceKey 'CONTOSO' -Licenses $licenses -Users $users

        Creates page with both license summary and user assignments tables.
    .EXAMPLE
        Sync-ConfluenceLicenseReport -SpaceKey 'CONTOSO' -Licenses $licenses -WhatIf

        Shows what would be synced without making changes.
    .NOTES
        This is a public function in the ConfluenceAPI module.
        Part of Story 5.4 - License Report Sync Function.

        Dependencies:
        - Get-ConfluenceSpace (Story 2.2)
        - Search-Confluence (Story 2.6)
        - New-ConfluencePage (Story 2.3)
        - Set-ConfluencePage (Story 2.3)
        - ConvertTo-ConfluenceLicensePage (Story 5.3)
    .LINK
        Get-ConfluenceSpace
    .LINK
        Search-Confluence
    .LINK
        New-ConfluencePage
    .LINK
        Set-ConfluencePage
    .LINK
        ConvertTo-ConfluenceLicensePage
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string]$SpaceKey,

        [Parameter()]
        [object[]]$Licenses,

        [Parameter()]
        [object[]]$Users,

        [Parameter()]
        [string]$PageTitle = 'License Report',

        [Parameter()]
        [string]$ParentPageId
    )

    Write-Verbose "Syncing license report to space '$SpaceKey'"

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

    # Generate ADF content using Story 5.3 transformer
    $adfContent = ConvertTo-ConfluenceLicensePage -Licenses $Licenses -Users $Users
    $licenseCount = if ($Licenses) { $Licenses.Count } else { 0 }
    Write-Verbose "Generated ADF content for $licenseCount license type(s)"

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

### Previous Story Intelligence (Story 5.2, 5.3)

**Key Learnings to Apply:**

1. **Exact Pattern from Story 5.2:**
   - Follow `Sync-ConfluenceEndpointInventory.ps1` structure exactly
   - Use same CQL escaping pattern for security
   - Use same space validation pattern with actionable error
   - Use same ShouldProcess pattern for WhatIf

2. **From Story 5.3 Code Review:**
   - `ConvertTo-ConfluenceLicensePage` now properly handles empty state with timestamp
   - Users parameter is passed through for license assignments table
   - Pipeline-based array building was fixed for performance

3. **Pester 3.4 Syntax (CRITICAL):**
   - Use `Should Be` (no hyphen) for Windows PS 5.1 compatibility
   - Use `Should Not Be $null` for null checks
   - Use `Assert-MockCalled` (NOT `Should -Invoke`) with `-Scope It`
   - Define stub functions before mocking
   - Dot-source function under test in BeforeAll

4. **Test Isolation Pattern (from Story 5.2):**
   - Mock all dependencies (Get-ConfluenceSpace, Search-Confluence, etc.)
   - Mock the private transformer function
   - Use `$script:capturedX` pattern to verify parameters passed

### Testing Pattern

```powershell
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $here)) 'Public'

Describe 'Sync-ConfluenceLicenseReport' {
    BeforeAll {
        # Define stub functions for dependencies that will be mocked (Pester 3.4 requirement)
        # Public dependencies
        function Get-ConfluenceSpace { param($SpaceKey) }
        function Search-Confluence { param($CQL) }
        function New-ConfluencePage { param($SpaceKey, $Title, $Body, $ParentId) }
        function Set-ConfluencePage { param($PageId, $Body) }
        # Private dependency - stub for isolation
        function ConvertTo-ConfluenceLicensePage { param($Licenses, $Users) }

        # Dot-source the function under test
        . "$publicDir\Sync-ConfluenceLicenseReport.ps1"
    }

    Context 'New Page Creation (AC1)' {
        BeforeAll {
            Mock Get-ConfluenceSpace { return [PSCustomObject]@{ Id = '123'; Key = 'CONTOSO'; Name = 'Contoso Corp' } }
            Mock Search-Confluence { return $null }
            Mock ConvertTo-ConfluenceLicensePage { return '{"version":1,"type":"doc","content":[]}' }
            Mock New-ConfluencePage { return [PSCustomObject]@{ Id = '456'; Title = 'License Report'; Version = @{ Number = 1 } } }
        }

        It 'Creates page when none exists' {
            $result = Sync-ConfluenceLicenseReport -SpaceKey 'CONTOSO' -Licenses @()

            $result | Should Not Be $null
            $result.Action | Should Be 'Created'
        }
    }

    # ... more tests following Story 5.2 pattern ...
}
```

### Project Structure Notes

**File to Create:**
```text
Modules/ConfluenceAPI/
├── Public/
│   └── Sync-ConfluenceLicenseReport.ps1    # CREATE
└── Tests/
    └── Public/
        └── Sync-ConfluenceLicenseReport.Tests.ps1  # CREATE
```

**No manifest update needed** - Public functions are auto-exported by psm1 module loader.

### Common Mistakes to Avoid

1. **DO NOT** forget to pass `-Users` parameter to `ConvertTo-ConfluenceLicensePage`
2. **DO NOT** forget CQL single quote escaping for security
3. **DO NOT** forget space validation with actionable error message
4. **DO NOT** forget `SupportsShouldProcess` attribute
5. **DO NOT** return anything when WhatIf is used (ShouldProcess returns false)
6. **DO NOT** use `Should -Invoke` - use `Assert-MockCalled` (Pester 3.4)
7. **DO NOT** forget `Write-Verbose` for all significant operations
8. **DO NOT** move existing pages when ParentPageId is provided (creation only)
9. **DO NOT** forget to handle null licenses gracefully (transformer handles this)
10. **DO NOT** use `throw` directly - use `$PSCmdlet.ThrowTerminatingError()`

### References

- [Source: docs/architecture.md#Project-Structure-Boundaries] - Public function location
- [Source: docs/architecture.md#Data-Flow] - Sync orchestration layer
- [Source: docs/epics.md#Story-5.4] - Acceptance criteria
- [Source: docs/prd.md#Data-Sync-Licenses] - FR23-26 requirements
- [Source: docs/sprint-artifacts/5-2-endpoint-inventory-sync-function.md] - Sync function pattern template
- [Source: docs/sprint-artifacts/5-3-license-data-transformer.md] - License transformer (dependency)
- [Source: Modules/ConfluenceAPI/Public/Sync-ConfluenceEndpointInventory.ps1] - Direct pattern to follow

### FRs Covered

- **FR23**: System can sync license report from CIPP to Confluence (primary)
- **FR24**: System can display license types and quantities (via transformer)
- **FR25**: System can display license assignments per user (via transformer + Users param)
- **FR26**: System can display available/used license counts (via transformer)
- **NFR18**: Module must include -WhatIf support for all write operations
- **NFR19**: Module must include -Verbose logging for troubleshooting
- **NFR20**: Error messages must include actionable troubleshooting guidance

## Dev Agent Record

### Context Reference

<!-- Story context analysis completed by create-story workflow -->

### Agent Model Used

Claude Opus 4.5

### Debug Log References

- ScriptAnalyzer: 0 warnings
- Pester: 33 new tests, all passing
- Full regression suite: All tests passing (no regressions)

### Completion Notes List

- Implemented `Sync-ConfluenceLicenseReport` following exact Story 5.2 pattern
- Added `-Users` parameter to pass to `ConvertTo-ConfluenceLicensePage` for license assignments table
- CQL injection protection via single quote escaping
- Full `-WhatIf` and `-Verbose` support
- Comprehensive Pester 3.4 test suite with 33 tests across 12 contexts
- All 10 acceptance criteria covered by tests

### File List

| Path | Action |
|------|--------|
| Modules/ConfluenceAPI/Public/Sync-ConfluenceLicenseReport.ps1 | Created |
| Modules/ConfluenceAPI/Tests/Public/Sync-ConfluenceLicenseReport.Tests.ps1 | Created |

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2025-12-13 | Story created via create-story workflow | Claude Opus 4.5 |
| 2025-12-13 | Implementation complete - all tasks done, 33 tests passing | Claude Opus 4.5 |
