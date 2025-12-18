# Story 4.2: User Inventory Sync Function

Status: done

## Story

As a **Technical Lead**,
I want **to sync user inventory from CIPP data to a Confluence page**,
so that **L1 techs can look up user information without escalation**.

## Acceptance Criteria

### AC1: Create User Inventory Page
**Given** I have CIPP user data and a target space
**When** I run `Sync-ConfluenceUserInventory -SpaceKey 'CONTOSO' -Users $cippUsers`
**Then** a "User Inventory" page is created in the space
**And** the page displays all user data in table format (FR15-19)
**And** the function returns a PSCustomObject with page details (Id, Title, Version)

### AC2: Update Existing Page
**Given** a "User Inventory" page already exists in the space
**When** I run the sync
**Then** the existing page is updated with new content
**And** the page version is incremented
**And** a PSCustomObject is returned with updated page details

### AC3: Support WhatIf Mode (NFR18)
**Given** I want to preview the sync operation
**When** I run `Sync-ConfluenceUserInventory -SpaceKey 'CONTOSO' -Users $cippUsers -WhatIf`
**Then** the function shows what would be synced without making changes
**And** no API calls are made to create/update pages

### AC4: Support Verbose Logging (NFR19)
**Given** I want detailed operation logging
**When** I run with `-Verbose`
**Then** the function logs: "Syncing user inventory to space CONTOSO"
**And** the function logs page creation/update operations
**And** the function logs user count being synced

### AC5: Handle Optional License Data (FR17)
**Given** I have CIPP user data and license inventory
**When** I run `Sync-ConfluenceUserInventory -SpaceKey 'CONTOSO' -Users $users -Licenses $licenses`
**Then** the page displays license names (not SKU IDs) for each user

### AC6: Handle Optional MFA Data (FR19)
**Given** I have CIPP user data and MFA report
**When** I run `Sync-ConfluenceUserInventory -SpaceKey 'CONTOSO' -Users $users -MFAData $mfa`
**Then** the page displays MFA status (Registered/Not Registered) for each user

### AC7: Handle Missing Space Gracefully
**Given** I specify a space key that doesn't exist
**When** I run the sync
**Then** a terminating error is thrown with message "Space 'INVALID' not found"
**And** the error includes actionable guidance (NFR20)

### AC8: Handle Empty Users Gracefully
**Given** I have empty or null user data
**When** I run the sync
**Then** the page is created with "No user data available" message
**And** no errors are thrown

## Tasks / Subtasks

- [x] Task 1: Create Sync-ConfluenceUserInventory Function (AC: 1, 2, 3, 4, 7, 8)
  - [x] Create `Public/Sync-ConfluenceUserInventory.ps1` file
  - [x] Implement `[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]`
  - [x] Add `[OutputType([PSCustomObject])]`
  - [x] Add `-SpaceKey` parameter (mandatory string)
  - [x] Add `-Users` parameter for CIPP user objects
  - [x] Add `-Licenses` parameter (optional)
  - [x] Add `-MFAData` parameter (optional)
  - [x] Add `-PageTitle` parameter with default 'User Inventory'
  - [x] Validate space exists using `Get-ConfluenceSpace -SpaceKey`
  - [x] Search for existing page using `Search-Confluence -CQL`
  - [x] Use `ConvertTo-ConfluenceUserPage` for ADF content generation
  - [x] Create or update page using `New-ConfluencePage` / `Set-ConfluencePage`
  - [x] Implement `$PSCmdlet.ShouldProcess()` for WhatIf support
  - [x] Add `Write-Verbose` logging throughout
  - [x] Add comment-based help with examples
  - [x] Return PSCustomObject with Id, Title, SpaceKey, Version, Created/Updated flag

- [x] Task 2: Handle Page Create vs Update Logic (AC: 1, 2)
  - [x] Search for existing page: `Search-Confluence -CQL "space = '$SpaceKey' AND title = '$PageTitle' AND type = page"`
  - [x] If page exists: use `Set-ConfluencePage -PageId $existing.Id -Body $adfContent`
  - [x] If page doesn't exist: use `New-ConfluencePage -SpaceKey $SpaceKey -Title $PageTitle -Body $adfContent`
  - [x] Track operation type (Created vs Updated) for verbose logging and return object

- [x] Task 3: Implement Error Handling (AC: 7)
  - [x] Validate space exists before attempting sync
  - [x] Use `$PSCmdlet.ThrowTerminatingError()` for space not found
  - [x] Include actionable message: "Space '$SpaceKey' not found. Use Get-ConfluenceSpace to list available spaces."

- [x] Task 4: Export Function in Module Manifest (AC: 1)
  - [x] Add `Sync-ConfluenceUserInventory` to FunctionsToExport in ConfluenceAPI.psd1

- [x] Task 5: Create Unit Tests (AC: 1-8)
  - [x] Create `Tests/Public/Sync-ConfluenceUserInventory.Tests.ps1`
  - [x] Mock `Get-ConfluenceSpace` for space validation
  - [x] Mock `Search-Confluence` for page existence check
  - [x] Mock `New-ConfluencePage` for page creation
  - [x] Mock `Set-ConfluencePage` for page update
  - [x] Mock `ConvertTo-ConfluenceUserPage` for ADF generation
  - [x] Test: Creates new page when none exists
  - [x] Test: Updates existing page when found
  - [x] Test: Returns PSCustomObject with correct properties
  - [x] Test: WhatIf shows operation without executing
  - [x] Test: Verbose logs operation details
  - [x] Test: Throws error for non-existent space
  - [x] Test: Handles empty users gracefully
  - [x] Test: Passes Licenses to ConvertTo-ConfluenceUserPage
  - [x] Test: Passes MFAData to ConvertTo-ConfluenceUserPage

- [x] Task 6: Run Validation (AC: 1-8)
  - [x] Run `Invoke-ScriptAnalyzer -Path ./Modules/ConfluenceAPI/Public/Sync-ConfluenceUserInventory.ps1`
  - [x] Run all Pester tests (target: 0 new warnings)
  - [x] Verify all existing tests still pass (regression check)

## Dev Notes

### Architecture Compliance

**Module Location:** `Modules/ConfluenceAPI/Public/`

Per architecture.md (lines 308-312), sync orchestration functions are Public:
- [Source: docs/architecture.md#Project-Structure-Boundaries] - `Sync-CIPPTenantToConfluence` and related sync functions in Public/
- [Source: docs/epics.md#Story-4.2] - Acceptance criteria define public function

**Dependencies:**
- `Get-ConfluenceSpace` (Story 2.2) - for space validation
- `Search-Confluence` (Story 2.6) - for finding existing page
- `New-ConfluencePage` (Story 2.3) - for creating new page
- `Set-ConfluencePage` (Story 2.3) - for updating existing page
- `ConvertTo-ConfluenceUserPage` (Story 4.1) - for ADF content generation

### CRITICAL: Function Pattern from HuduAPI

Follow HuduAPI pattern for sync functions:

```powershell
function Sync-ConfluenceUserInventory {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string]$SpaceKey,

        [Parameter()]
        [object[]]$Users,

        [Parameter()]
        [object[]]$Licenses,

        [Parameter()]
        [object[]]$MFAData,

        [Parameter()]
        [string]$PageTitle = 'User Inventory'
    )

    Write-Verbose "Syncing user inventory to space '$SpaceKey'"

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

    # Generate ADF content
    $adfContent = ConvertTo-ConfluenceUserPage -Users $Users -Licenses $Licenses -MFAData $MFAData
    Write-Verbose "Generated ADF content for $($Users.Count) user(s)"

    # Search for existing page
    $cql = "space = '$SpaceKey' AND title = '$PageTitle' AND type = page"
    $existingPage = Search-Confluence -CQL $cql | Select-Object -First 1

    if ($existingPage) {
        Write-Verbose "Found existing page (ID: $($existingPage.Id)) - updating"
        if ($PSCmdlet.ShouldProcess($PageTitle, "Update Confluence page")) {
            $result = Set-ConfluencePage -PageId $existingPage.Id -Body $adfContent
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
            $result = New-ConfluencePage -SpaceKey $SpaceKey -Title $PageTitle -Body $adfContent
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

### Previous Story Intelligence (Story 4.1)

**Key Learnings to Apply:**

1. **Case-Insensitive UPN Matching:**
   - Story 4.1 code review found case-sensitivity issue in MFA lookup
   - Fix was to use `.ToLower()` normalization
   - This is already implemented in `ConvertTo-ConfluenceUserPage`
   - No changes needed here - just consume the function

2. **Pester 3.4 Syntax:**
   - Use `Should Be` (no hyphen) for Windows PS 5.1 compatibility
   - Use `Should Not Be $null` for null checks
   - Use `Should -Invoke` for mock verification (Pester 5 syntax also works)

3. **Mocking Pattern for Public Functions:**
   - Dot-source dependencies or mock them
   - Use `Mock` command in BeforeAll
   - Verify with `Should -Invoke -CommandName 'Get-ConfluenceSpace' -Times 1`

4. **PSScriptAnalyzer Compliance:**
   - `Sync-*` is an approved verb
   - Use `[CmdletBinding(SupportsShouldProcess)]` for write operations
   - Use `$PSCmdlet.ThrowTerminatingError()` not `throw`

### CQL Search Pattern

From Epic 2 Story 2.6, use CQL for page search:

```powershell
# Search for page by title in specific space
$cql = "space = '$SpaceKey' AND title = '$PageTitle' AND type = page"
$existingPage = Search-Confluence -CQL $cql | Select-Object -First 1
```

### PRD Requirements Mapping

| Requirement | Implementation | Status |
|-------------|----------------|--------|
| FR15: Sync user inventory | `Sync-ConfluenceUserInventory` creates/updates page | This Story |
| FR16: Display user status | Via `ConvertTo-ConfluenceUserPage` (Story 4.1) | Dependency |
| FR17: Display license assignments | Via `-Licenses` parameter | This Story |
| FR19: Display MFA status | Via `-MFAData` parameter | This Story |
| FR44: Display timestamp | Via `ConvertTo-ConfluenceUserPage` (Story 4.1) | Dependency |
| NFR18: WhatIf support | `SupportsShouldProcess` attribute | This Story |
| NFR19: Verbose logging | `Write-Verbose` throughout | This Story |
| NFR20: Actionable errors | Error message includes guidance | This Story |

### Testing Pattern

```powershell
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $here)) 'Public'

Describe 'Sync-ConfluenceUserInventory' {
    BeforeAll {
        # Dot-source the function
        . "$publicDir\Sync-ConfluenceUserInventory.ps1"

        # Mock dependencies
        Mock Get-ConfluenceSpace { return [PSCustomObject]@{ Id = '123'; Key = 'CONTOSO'; Name = 'Contoso Corp' } }
        Mock Search-Confluence { return $null }  # No existing page
        Mock ConvertTo-ConfluenceUserPage { return '{"version":1,"type":"doc","content":[]}' }
        Mock New-ConfluencePage { return [PSCustomObject]@{ Id = '456'; Title = 'User Inventory'; Version = @{ Number = 1 } } }
        Mock Set-ConfluencePage { return [PSCustomObject]@{ Id = '456'; Title = 'User Inventory'; Version = @{ Number = 2 } } }
    }

    Context 'New Page Creation' {
        It 'Creates page when none exists' {
            $result = Sync-ConfluenceUserInventory -SpaceKey 'CONTOSO' -Users @()

            $result | Should Not Be $null
            $result.Action | Should Be 'Created'
            Should -Invoke -CommandName 'New-ConfluencePage' -Times 1
        }
    }

    Context 'Page Update' {
        BeforeAll {
            Mock Search-Confluence { return [PSCustomObject]@{ Id = '789'; Title = 'User Inventory' } }
        }

        It 'Updates page when exists' {
            $result = Sync-ConfluenceUserInventory -SpaceKey 'CONTOSO' -Users @()

            $result.Action | Should Be 'Updated'
            Should -Invoke -CommandName 'Set-ConfluencePage' -Times 1
        }
    }

    Context 'Error Handling' {
        BeforeAll {
            Mock Get-ConfluenceSpace { return $null }
        }

        It 'Throws error for non-existent space' {
            { Sync-ConfluenceUserInventory -SpaceKey 'INVALID' -Users @() } | Should Throw "*not found*"
        }
    }

    Context 'WhatIf Support' {
        It 'Does not create page with WhatIf' {
            Sync-ConfluenceUserInventory -SpaceKey 'CONTOSO' -Users @() -WhatIf

            Should -Invoke -CommandName 'New-ConfluencePage' -Times 0
        }
    }
}
```

### Project Structure Notes

**File to Create:**
```text
Modules/ConfluenceAPI/
├── Public/
│   └── Sync-ConfluenceUserInventory.ps1    # CREATE
└── Tests/
    └── Public/
        └── Sync-ConfluenceUserInventory.Tests.ps1  # CREATE
```

**Module Manifest Update:**
Add to `ConfluenceAPI.psd1`:
```powershell
FunctionsToExport = @(
    # ... existing functions ...
    'Sync-ConfluenceUserInventory'
)
```

### Common Mistakes to Avoid

1. **DO NOT** forget to validate space exists before syncing
2. **DO NOT** use `throw` directly - use `$PSCmdlet.ThrowTerminatingError()`
3. **DO NOT** forget `SupportsShouldProcess` for WhatIf support
4. **DO NOT** forget to mock all dependencies in tests
5. **DO NOT** forget to export function in module manifest
6. **DO NOT** return raw API response - return PSCustomObject with selected properties
7. **DO NOT** forget Write-Verbose for all significant operations
8. **DO NOT** hardcode page title - use parameter with default value
9. **DO NOT** forget to handle case where Search-Confluence returns multiple results (use Select-Object -First 1)
10. **DO NOT** forget to pass Licenses and MFAData to ConvertTo-ConfluenceUserPage

### References

- [Source: docs/architecture.md#Project-Structure-Boundaries] - Sync functions in Public/
- [Source: docs/architecture.md#WhatIf-Verbose-Pattern] - ShouldProcess pattern
- [Source: docs/architecture.md#Error-Handling-Pattern] - ThrowTerminatingError pattern
- [Source: docs/epics.md#Story-4.2] - Acceptance criteria
- [Source: docs/prd.md#Data-Sync-Users] - FR15-19 requirements
- [Source: docs/sprint-artifacts/4-1-user-data-transformer.md] - Previous story learnings

### FRs Covered

- **FR15**: System can sync user inventory from CIPP to Confluence (this story - orchestration)
- **FR16**: System can display user status (via Story 4.1 dependency)
- **FR17**: System can display user license assignments (via Licenses parameter)
- **FR19**: System can display user MFA status (via MFAData parameter)
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

1. All 26 unit tests pass covering all 8 acceptance criteria
2. PSScriptAnalyzer reports no warnings
3. Full regression test suite passes (450+ tests)
4. Function exported in module manifest
5. Pester 3.4 compatible test syntax used (Assert-MockCalled with -Scope It)
6. Stub functions required for mocking undefined commands in Pester 3.4

**Code Review Fixes Applied (2025-12-13):**
7. Fixed CQL injection vulnerability - single quotes now escaped in SpaceKey/PageTitle
8. Added verbose logging after page create/update operations (AC4 compliance)
9. Added tests for License and MFA data passthrough verification
10. Added tests for CQL query format and single quote escaping
11. Marked all subtasks as complete

### File List

| Path | Action |
|------|--------|
| Modules/ConfluenceAPI/Public/Sync-ConfluenceUserInventory.ps1 | Created |
| Modules/ConfluenceAPI/Tests/Public/Sync-ConfluenceUserInventory.Tests.ps1 | Created |
| Modules/ConfluenceAPI/ConfluenceAPI.psd1 | Modified (added function export) |

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2025-12-13 | Story created via create-story workflow | Claude Opus 4.5 |
| 2025-12-13 | Implementation completed, ready for code review | Claude Opus 4.5 |
| 2025-12-13 | Code review: Fixed 5 issues (2 HIGH, 3 MEDIUM), story marked done | Claude Opus 4.5 |
