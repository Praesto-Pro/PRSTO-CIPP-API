# Story 7.3: CLIENTS-INDEX Maintenance

Status: done

## Story

As a **Technical Lead**,
I want **the CLIENTS-INDEX page to auto-update when spaces change**,
so that **there's always a master list of all client spaces for easy navigation**.

## Acceptance Criteria

### AC1: Update Index on Space Creation (FR9)
**Given** a new client space is created via `New-ConfluenceClientSpace`
**When** the creation completes successfully
**Then** the CLIENTS-INDEX page is updated with the new client entry
**And** the index entry shows: ClientName, SpaceKey, link to space homepage

### AC2: Manual Index Refresh
**Given** I want to rebuild the index from current mappings
**When** I run `Update-ConfluenceClientIndex`
**Then** the CLIENTS-INDEX page is rebuilt from all tenant mappings in Azure Table Storage
**And** stale entries (mappings that no longer exist) are removed
**And** `-WhatIf` shows what would change without making changes

### AC3: Index Reflects Current Mappings
**Given** client space mappings have been modified (added/removed)
**When** `Update-ConfluenceClientIndex` runs
**Then** the index shows exactly the current mappings
**And** the format is an ADF table with columns: Client Name, Space Key, Link

### AC4: Support -Verbose Logging (NFR19)
**Given** I want detailed operation logging
**When** I run `Update-ConfluenceClientIndex -Verbose`
**Then** verbose messages describe:
- Retrieving current tenant mappings
- Generating ADF table content
- Creating/updating CLIENTS-INDEX page
- Number of clients in the index

### AC5: Create Index Page if Not Exists
**Given** the CLIENTS-INDEX page does not exist
**When** `Update-ConfluenceClientIndex` runs
**Then** a new page titled "CLIENTS-INDEX" is created in the root space
**And** the page contains a table of all client mappings

### AC6: Configurable Root Space
**Given** I want to specify where the CLIENTS-INDEX page lives
**When** I run `Update-ConfluenceClientIndex -RootSpaceKey 'MSP'`
**Then** the CLIENTS-INDEX page is created/updated in the specified space
**And** if not specified, a default space (e.g., 'MSP' or configurable) is used

### AC7: Handle Empty Mappings
**Given** no tenant-to-space mappings exist
**When** `Update-ConfluenceClientIndex` runs
**Then** the page shows a message "No client spaces configured"
**And** the function completes without error

### AC8: Space Links Use Correct Format
**Given** the index is being generated
**When** space links are created
**Then** each link uses the Confluence space URL format
**And** links are clickable in the Confluence UI

## Tasks / Subtasks

- [x] Task 1: Create Update-ConfluenceClientIndex Public Function (AC: 1-8)
  - [x] Create `Public/Update-ConfluenceClientIndex.ps1` file
  - [x] Add `[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]`
  - [x] Add `[OutputType([PSCustomObject])]` for return type
  - [x] Add `-RootSpaceKey` parameter (optional string, defaults to 'MSP')
  - [x] Add `-IndexPageTitle` parameter (optional string, defaults to 'CLIENTS-INDEX')
  - [x] Call `Get-ConfluenceTenantMapping` to retrieve all current mappings
  - [x] Call `ConvertTo-ConfluenceClientIndex` to generate ADF content
  - [x] Check if index page exists using `Search-Confluence -CQL "title = '...' and space = '...'"`
  - [x] Create page if not exists using `New-ConfluencePage`
  - [x] Update page if exists using `Set-ConfluencePage`
  - [x] Implement `$PSCmdlet.ShouldProcess` for WhatIf support
  - [x] Add `Write-Verbose` logging throughout
  - [x] Return PSCustomObject with PageId, ClientCount, Status
  - [x] Add comment-based help with examples

- [x] Task 2: Create ConvertTo-ConfluenceClientIndex Private Function (AC: 3, 7, 8)
  - [x] Create `Private/ConvertTo-ConfluenceClientIndex.ps1` file
  - [x] Add `[CmdletBinding()]` attribute with Verbose support
  - [x] Add `-Mappings` parameter (array of mapping objects)
  - [x] Add `-BaseURL` parameter (for generating space links)
  - [x] Generate ADF heading "Client Spaces Index"
  - [x] Generate ADF paragraph with timestamp
  - [x] If no mappings, generate "No client spaces configured" message
  - [x] If mappings exist, generate ADF table with columns: Client Name, Space Key, Link
  - [x] Generate space links in format: `{BaseURL}/wiki/spaces/{SpaceKey}`
  - [x] Add `Write-Verbose` logging
  - [x] Return valid ADF JSON string via `ConvertTo-ADF`

- [x] Task 3: Update New-ConfluenceClientSpace to Call Index Update (AC: 1)
  - [x] Open `Public/New-ConfluenceClientSpace.ps1`
  - [x] After successful mapping storage, call `Update-ConfluenceClientIndex`
  - [x] Wrap in try/catch - index update failure should NOT fail space creation
  - [x] Log warning if index update fails, but still return success
  - [x] Add `Write-Verbose` for "Updating CLIENTS-INDEX with new client"

- [x] Task 4: Create Unit Tests for Update-ConfluenceClientIndex (AC: 1-8)
  - [x] Create `Tests/Public/Update-ConfluenceClientIndex.Tests.ps1`
  - [x] Test: Creates index page when not exists (AC5)
  - [x] Test: Updates existing index page (AC2)
  - [x] Test: Calls Get-ConfluenceTenantMapping to get current mappings (AC2, AC3)
  - [x] Test: Does not modify with WhatIf (AC2)
  - [x] Test: Returns PSCustomObject with PageId, ClientCount, Status
  - [x] Test: Writes verbose messages (AC4)
  - [x] Test: Handles empty mappings gracefully (AC7)
  - [x] Test: Uses correct search CQL for finding existing page
  - [x] Test: Accepts custom RootSpaceKey parameter (AC6)
  - [x] Test: Accepts custom IndexPageTitle parameter

- [x] Task 5: Create Unit Tests for ConvertTo-ConfluenceClientIndex (AC: 3, 7, 8)
  - [x] Create `Tests/Private/ConvertTo-ConfluenceClientIndex.Tests.ps1`
  - [x] Test: Returns valid ADF JSON string
  - [x] Test: Includes "Client Spaces Index" heading
  - [x] Test: Includes timestamp paragraph
  - [x] Test: Generates table with 3 columns when mappings provided
  - [x] Test: Includes all mapping entries in table
  - [x] Test: Generates correct space links (AC8)
  - [x] Test: Shows "No client spaces configured" when no mappings (AC7)
  - [x] Test: Verbose output logs generation progress

- [x] Task 6: Create Integration Test for Space Creation with Index Update (AC: 1)
  - [x] Create `Tests/Integration/New-ConfluenceClientSpace.Integration.Tests.ps1` (or extend existing)
  - [x] Test: Creating space updates CLIENTS-INDEX (mock API calls)
  - [x] Test: Index update failure does not fail space creation

- [x] Task 7: Run Validation (AC: 1-8)
  - [x] Run `Invoke-ScriptAnalyzer` on all new functions - 0 warnings
  - [x] Run all new Pester tests - all passing (56 new tests)
  - [x] Verify all existing tests still pass (full regression passed)
  - [x] Verify module loads correctly after adding new functions

## Dev Notes

### Architecture Compliance

**Module Locations:**
- `Modules/ConfluenceAPI/Public/Update-ConfluenceClientIndex.ps1` - Main public function
- `Modules/ConfluenceAPI/Private/ConvertTo-ConfluenceClientIndex.ps1` - ADF content generator

Per architecture.md (lines 308-312), CIPP integration functions go in Public/:
- [Source: docs/architecture.md#Project-Structure-Boundaries] - `Update-ConfluenceClientIndex` in Public/
- [Source: docs/epics.md#Story-7.3] - FR9 CLIENTS-INDEX maintenance requirement

**Dependencies:**
- `Get-ConfluenceTenantMapping` (Story 7.2) - to retrieve all current mappings
- `Get-ConfluenceBaseURL` (Story 1.3) - for constructing space links
- `Search-Confluence` (Story 2.6) - for finding existing index page
- `New-ConfluencePage` (Story 2.3) - for creating index page if not exists
- `Set-ConfluencePage` (Story 2.3) - for updating existing index page
- `New-ADFDocument` (Story 3.1) - for creating ADF root structure
- `Add-ADFContent` (Story 3.1) - for adding content nodes
- `ConvertTo-ADF` (Story 3.1) - for JSON serialization
- `New-ADFHeading` (Story 3.3) - for page heading
- `New-ADFParagraph` (Story 3.3) - for timestamp and empty message
- `New-ADFTable` (Story 3.2) - for client list table

### CRITICAL: ADF Table with Links

The CLIENTS-INDEX page must contain clickable links to each client space. ADF supports inline links within table cells.

**ADF Link Format (within text):**

```json
{
  "type": "text",
  "text": "View Space",
  "marks": [
    {
      "type": "link",
      "attrs": {
        "href": "https://example.atlassian.net/wiki/spaces/CONTOSO"
      }
    }
  ]
}
```

**Table Cell with Link:**

```json
{
  "type": "tableCell",
  "content": [
    {
      "type": "paragraph",
      "content": [
        {
          "type": "text",
          "text": "CONTOSO",
          "marks": [
            {
              "type": "link",
              "attrs": {
                "href": "https://example.atlassian.net/wiki/spaces/CONTOSO"
              }
            }
          ]
        }
      ]
    }
  ]
}
```

### Update-ConfluenceClientIndex Pattern

```powershell
function Update-ConfluenceClientIndex {
    <#
    .SYNOPSIS
        Updates the CLIENTS-INDEX page with current tenant-to-space mappings.
    .DESCRIPTION
        Retrieves all tenant-to-space mappings from Azure Table Storage and
        updates (or creates) the CLIENTS-INDEX page with a table listing all
        client spaces with clickable links.
    .PARAMETER RootSpaceKey
        The space key where the CLIENTS-INDEX page lives. Defaults to 'MSP'.
    .PARAMETER IndexPageTitle
        The title of the index page. Defaults to 'CLIENTS-INDEX'.
    .OUTPUTS
        [PSCustomObject] Object with PageId, ClientCount, Status properties.
    .EXAMPLE
        Update-ConfluenceClientIndex
        Updates the CLIENTS-INDEX page in the default MSP space.
    .EXAMPLE
        Update-ConfluenceClientIndex -RootSpaceKey 'DOCS' -Verbose
        Updates the index in the DOCS space with verbose logging.
    .EXAMPLE
        Update-ConfluenceClientIndex -WhatIf
        Shows what would be updated without making changes.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$RootSpaceKey = 'MSP',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$IndexPageTitle = 'CLIENTS-INDEX'
    )

    Write-Verbose "Updating CLIENTS-INDEX in space '$RootSpaceKey'"

    # Get all current tenant-to-space mappings
    Write-Verbose "Retrieving current tenant-to-space mappings"
    $mappings = @(Get-ConfluenceTenantMapping)
    Write-Verbose "Found $($mappings.Count) client mappings"

    # Get base URL for generating space links
    $baseURL = Get-ConfluenceBaseURL

    # Generate ADF content
    Write-Verbose "Generating CLIENTS-INDEX page content"
    $indexContent = ConvertTo-ConfluenceClientIndex -Mappings $mappings -BaseURL $baseURL

    # Check if index page already exists
    Write-Verbose "Searching for existing CLIENTS-INDEX page"
    $cql = "title = '$IndexPageTitle' and space = '$RootSpaceKey' and type = page"
    $existingPage = Search-Confluence -CQL $cql | Select-Object -First 1

    if ($PSCmdlet.ShouldProcess("CLIENTS-INDEX in $RootSpaceKey", "Update client index page")) {
        if ($existingPage) {
            Write-Verbose "Updating existing CLIENTS-INDEX page (ID: $($existingPage.Id))"
            Set-ConfluencePage -PageId $existingPage.Id -Body $indexContent | Out-Null
            $pageId = $existingPage.Id
            $status = 'Updated'
        }
        else {
            Write-Verbose "Creating new CLIENTS-INDEX page in space '$RootSpaceKey'"
            $newPage = New-ConfluencePage -SpaceKey $RootSpaceKey -Title $IndexPageTitle -Body $indexContent
            $pageId = $newPage.Id
            $status = 'Created'
        }

        Write-Verbose "Successfully $($status.ToLower()) CLIENTS-INDEX with $($mappings.Count) clients"

        return [PSCustomObject]@{
            PageId      = $pageId
            ClientCount = $mappings.Count
            Status      = $status
        }
    }
}
```

### ConvertTo-ConfluenceClientIndex Pattern

```powershell
function ConvertTo-ConfluenceClientIndex {
    <#
    .SYNOPSIS
        Generates ADF content for the CLIENTS-INDEX page.
    .DESCRIPTION
        Takes tenant-to-space mappings and generates an ADF document with
        a table of all client spaces including clickable links.
    .PARAMETER Mappings
        Array of mapping objects with TenantId, SpaceKey, SpaceName properties.
    .PARAMETER BaseURL
        The Confluence base URL for generating space links.
    .OUTPUTS
        [string] ADF JSON content.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [array]$Mappings,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$BaseURL
    )

    Write-Verbose "Generating CLIENTS-INDEX content for $($Mappings.Count) clients"

    $doc = New-ADFDocument

    # Page heading
    $heading = New-ADFHeading -Level 1 -Text 'Client Spaces Index'

    # Timestamp
    $timestamp = New-ADFParagraph -Text "Last updated: $(Get-Date -Format 'yyyy-MM-dd HH:mm UTC')"

    if (-not $Mappings -or $Mappings.Count -eq 0) {
        Write-Verbose "No mappings found, generating empty state message"
        $emptyMessage = New-ADFParagraph -Text 'No client spaces configured. Use New-ConfluenceClientSpace to create your first client.'

        $doc = Add-ADFContent -Document $doc -Content @($heading, $timestamp, $emptyMessage)
    }
    else {
        Write-Verbose "Generating table with $($Mappings.Count) client entries"

        # Build table data with links
        $tableData = foreach ($mapping in $Mappings) {
            $spaceURL = "$BaseURL/wiki/spaces/$($mapping.SpaceKey)"

            [PSCustomObject]@{
                'Client Name' = $mapping.SpaceName
                'Space Key'   = $mapping.SpaceKey
                'Link'        = $spaceURL  # Will be converted to clickable link
            }
        }

        # Generate table with link support
        $table = New-ADFTable -InputObject $tableData -Property 'Client Name', 'Space Key', 'Link' -LinkColumn 'Link'

        $doc = Add-ADFContent -Document $doc -Content @($heading, $timestamp, $table)
    }

    Write-Verbose "Generated CLIENTS-INDEX ADF content"
    return ConvertTo-ADF -InputObject $doc
}
```

### Modification to New-ConfluenceClientSpace

Add this code block after the existing `Set-ConfluenceTenantMapping` call in `New-ConfluenceClientSpace.ps1`:

```powershell
# Update CLIENTS-INDEX (non-blocking - failure should not fail space creation)
Write-Verbose "Updating CLIENTS-INDEX with new client '$ClientName'"
try {
    Update-ConfluenceClientIndex | Out-Null
    Write-Verbose "Successfully updated CLIENTS-INDEX"
}
catch {
    Write-Warning "Failed to update CLIENTS-INDEX: $($_.Exception.Message). Space creation succeeded, but index may be stale."
}
```

### Previous Story Intelligence (Story 7.2 Learnings)

**Key Learnings to Apply:**

1. **Pester 3.4 Syntax (CRITICAL):**
   - Use `Should Be` (no hyphen) for Windows PS 5.1 compatibility
   - Use `Should Not Be $null` for null checks
   - Use `Assert-MockCalled` (NOT `Should -Invoke`) with `-Scope It`
   - Define stub functions before mocking
   - Dot-source function under test in BeforeAll

2. **Parameter Sets (from Code Review):**
   - If parameters are mutually exclusive, use parameter sets
   - This story doesn't have conflicting params, but keep in mind for future

3. **Error Handling Pattern:**
   - Use `$PSCmdlet.ThrowTerminatingError()` - NEVER `throw` directly
   - Include actionable guidance in error messages
   - Use `Write-Warning` for non-fatal issues (like index update failures)

4. **Test Isolation Pattern:**
   - Mock all dependencies (Get-ConfluenceTenantMapping, Search-Confluence, New-ConfluencePage, Set-ConfluencePage)
   - Mock Get-ConfluenceBaseURL to return test URL
   - Use `$script:capturedX` pattern to verify parameters passed

5. **WhatIf Support:**
   - Return nothing when WhatIf is used (or return result with Status='WhatIf')
   - Ensure no API calls occur with WhatIf

### ADF Table with Link Column Enhancement

The `New-ADFTable` function (Story 3.2) may need a `-LinkColumn` parameter to support clickable links. Check if this exists or if custom ADF needs to be constructed manually.

**If New-ADFTable doesn't support links**, construct the table manually:

```powershell
function New-ADFTableWithLinks {
    # Build ADF table structure manually with link marks
    # See ADF Link Format above for cell structure
}
```

**Alternative: Use -LinkColumn pattern** if supported, or create link nodes inline.

### Testing Pattern

```powershell
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $here)) 'Public'
$privateDir = Join-Path (Split-Path -Parent (Split-Path -Parent $here)) 'Private'

Describe 'Update-ConfluenceClientIndex' {
    BeforeAll {
        # Define stub functions for dependencies
        function Get-ConfluenceTenantMapping { }
        function Get-ConfluenceBaseURL { }
        function Search-Confluence { param($CQL) }
        function New-ConfluencePage { param($SpaceKey, $Title, $Body) }
        function Set-ConfluencePage { param($PageId, $Body) }

        # Dot-source private and public functions
        . "$privateDir\ConvertTo-ConfluenceClientIndex.ps1"
        . "$publicDir\Update-ConfluenceClientIndex.ps1"
    }

    Context 'Create New Index' {
        BeforeEach {
            Mock Get-ConfluenceBaseURL { return 'https://example.atlassian.net' }
            Mock Get-ConfluenceTenantMapping {
                @(
                    [PSCustomObject]@{ TenantId = 't1'; SpaceKey = 'SPACE1'; SpaceName = 'Client One' },
                    [PSCustomObject]@{ TenantId = 't2'; SpaceKey = 'SPACE2'; SpaceName = 'Client Two' }
                )
            }
            Mock Search-Confluence { return $null }  # No existing page
            Mock New-ConfluencePage {
                [PSCustomObject]@{ Id = 'new-page-123'; Title = $Title }
            }
        }

        It 'Creates index page when not exists' {
            $result = Update-ConfluenceClientIndex
            Assert-MockCalled New-ConfluencePage -Scope It -Times 1
            $result.Status | Should Be 'Created'
        }

        It 'Returns PSCustomObject with expected properties' {
            $result = Update-ConfluenceClientIndex
            $result.PageId | Should Be 'new-page-123'
            $result.ClientCount | Should Be 2
        }
    }

    Context 'Update Existing Index' {
        BeforeEach {
            Mock Get-ConfluenceBaseURL { return 'https://example.atlassian.net' }
            Mock Get-ConfluenceTenantMapping {
                @([PSCustomObject]@{ TenantId = 't1'; SpaceKey = 'SPACE1'; SpaceName = 'Client One' })
            }
            Mock Search-Confluence {
                [PSCustomObject]@{ Id = 'existing-123'; Title = 'CLIENTS-INDEX' }
            }
            Mock Set-ConfluencePage { }
        }

        It 'Updates existing page instead of creating' {
            $result = Update-ConfluenceClientIndex
            Assert-MockCalled Set-ConfluencePage -Scope It -Times 1 -ParameterFilter {
                $PageId -eq 'existing-123'
            }
            Assert-MockCalled New-ConfluencePage -Times 0 -Scope It
            $result.Status | Should Be 'Updated'
        }
    }

    Context 'WhatIf Support' {
        BeforeEach {
            Mock Get-ConfluenceBaseURL { return 'https://example.atlassian.net' }
            Mock Get-ConfluenceTenantMapping { return @() }
            Mock Search-Confluence { return $null }
            Mock New-ConfluencePage { }
        }

        It 'Does not create page with WhatIf' {
            Update-ConfluenceClientIndex -WhatIf
            Assert-MockCalled New-ConfluencePage -Times 0 -Scope It
        }
    }

    Context 'Empty Mappings' {
        BeforeEach {
            Mock Get-ConfluenceBaseURL { return 'https://example.atlassian.net' }
            Mock Get-ConfluenceTenantMapping { return @() }
            Mock Search-Confluence { return $null }
            Mock New-ConfluencePage {
                [PSCustomObject]@{ Id = 'empty-page'; Title = $Title }
            }
        }

        It 'Creates page even with no mappings' {
            $result = Update-ConfluenceClientIndex
            Assert-MockCalled New-ConfluencePage -Scope It -Times 1
            $result.ClientCount | Should Be 0
        }
    }
}
```

### Project Structure Notes

**Files to Create:**
```text
Modules/ConfluenceAPI/
├── Private/
│   └── ConvertTo-ConfluenceClientIndex.ps1    # CREATE
├── Public/
│   └── Update-ConfluenceClientIndex.ps1       # CREATE
└── Tests/
    ├── Private/
    │   └── ConvertTo-ConfluenceClientIndex.Tests.ps1  # CREATE
    └── Public/
        └── Update-ConfluenceClientIndex.Tests.ps1     # CREATE
```

**Files to Modify:**
```text
Modules/ConfluenceAPI/
└── Public/
    └── New-ConfluenceClientSpace.ps1          # MODIFY - add index update call
```

**No manifest update needed** - Module exports are auto-handled by psm1 loader.

### Common Mistakes to Avoid

1. **DO NOT** make index update failure cause space creation to fail
2. **DO NOT** forget to handle empty mappings gracefully
3. **DO NOT** forget to wrap space URL in ADF link marks for clickability
4. **DO NOT** hardcode the base URL - use `Get-ConfluenceBaseURL`
5. **DO NOT** use `throw` directly - use `$PSCmdlet.ThrowTerminatingError()`
6. **DO NOT** forget `-WhatIf` and `-Verbose` support
7. **DO NOT** use `Should -Invoke` in tests - use `Assert-MockCalled` (Pester 3.4)
8. **DO NOT** forget to search for existing page before creating
9. **DO NOT** forget the timestamp on the index page
10. **DO NOT** return raw JSON - always return `[PSCustomObject]`

### Git Commit Pattern

```
feat: implement Story 7.3 CLIENTS-INDEX Maintenance

- Add Update-ConfluenceClientIndex public function
- Add ConvertTo-ConfluenceClientIndex private transformer
- Update New-ConfluenceClientSpace to auto-update index
- Create XX unit tests (all passing)
- PSScriptAnalyzer: 0 warnings

Story covers FR9 (CLIENTS-INDEX maintenance)
```

### References

- [Source: docs/architecture.md#Project-Structure-Boundaries] - Public function location
- [Source: docs/epics.md#Story-7.3] - FR9 requirements
- [Source: docs/prd.md#Space-Management] - FR9 CLIENTS-INDEX requirement
- [Source: docs/sprint-artifacts/7-2-tenant-space-mapping-management.md] - Previous story patterns
- [Source: docs/sprint-artifacts/7-1-client-space-creation.md] - New-ConfluenceClientSpace patterns
- [Confluence REST API - Search](https://developer.atlassian.com/cloud/confluence/rest/v2/api-group-search/)
- [ADF Link Marks](https://developer.atlassian.com/cloud/confluence/adf/marks/link/)

### FRs Covered

- **FR9**: System can update CLIENTS-INDEX page when spaces are added/removed (primary)
- **NFR18**: Module must include -WhatIf support for all write operations
- **NFR19**: Module must include -Verbose logging for troubleshooting

## Dev Agent Record

### Context Reference

<!-- Story context analysis completed by create-story workflow -->

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

- PSScriptAnalyzer: 0 warnings on all new functions
- ConvertTo-ConfluenceClientIndex: 30 tests passing (after code review)
- Update-ConfluenceClientIndex: 21 tests passing (after code review)
- Integration tests: 7 tests passing
- Full regression suite: All passing

### Completion Notes List

1. Implemented custom ADF table structure with link marks since New-ADFTable doesn't support links natively
2. Table cells contain text nodes with link marks for clickable space URLs
3. Non-blocking index update in New-ConfluenceClientSpace using try/catch with Write-Warning
4. Error handling includes check for missing base URL configuration
5. All tests use Pester 3.4 syntax (Should Be, Assert-MockCalled)

### Code Review Fixes Applied

1. **HIGH: Timestamp UTC fix** - Changed `Get-Date` to `(Get-Date).ToUniversalTime()` so timestamp actually shows UTC
2. **MEDIUM: Trailing slash handling** - Added `$BaseURL.TrimEnd('/')` to prevent malformed URLs
3. **MEDIUM: CQL injection prevention** - Added single quote escaping for IndexPageTitle and RootSpaceKey
4. **Added tests** - New test for BaseURL with trailing slash, new test for CQL quote escaping

### File List

**Created:**

- `Modules/ConfluenceAPI/Public/Update-ConfluenceClientIndex.ps1` (90 lines)
- `Modules/ConfluenceAPI/Private/ConvertTo-ConfluenceClientIndex.ps1` (156 lines)
- `Modules/ConfluenceAPI/Tests/Public/Update-ConfluenceClientIndex.Tests.ps1` (187 lines)
- `Modules/ConfluenceAPI/Tests/Private/ConvertTo-ConfluenceClientIndex.Tests.ps1` (220 lines)
- `Modules/ConfluenceAPI/Tests/Integration/New-ConfluenceClientSpace.Integration.Tests.ps1` (95 lines)

**Modified:**

- `Modules/ConfluenceAPI/Public/New-ConfluenceClientSpace.ps1` (+10 lines - index update call)

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2025-12-15 | Story created via create-story workflow | Claude Opus 4.5 |
| 2025-12-15 | Implementation complete - 56 new tests passing | Claude Opus 4.5 |
| 2025-12-15 | Code review: Fixed UTC timestamp, trailing slash, CQL escaping - 58 tests now | Claude Opus 4.5 |
