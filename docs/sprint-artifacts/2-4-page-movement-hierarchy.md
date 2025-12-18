# Story 2.4: Page Movement & Hierarchy

Status: done

## Story

As a **Technical Lead**,
I want **to move pages within the Confluence hierarchy**,
so that **I can organize documentation structure programmatically**.

## Acceptance Criteria

### AC1: Move Page to New Parent
**Given** I want to move a page to a new parent
**When** I run `Move-ConfluencePage -PageId '12345' -TargetId '67890'`
**Then** the page hierarchy is updated via PUT to `/wiki/rest/api/content/{id}/move/append/{targetId}`
**And** the page becomes a child of the target parent
**And** `-WhatIf` shows the move without executing
**And** returns PSCustomObject with Id, Title, SpaceId, ParentId (new parent)

### AC2: Move Page to Different Space
**Given** I want to move a page to a different space
**When** I run `Move-ConfluencePage -PageId '12345' -TargetId '99999'` (where 99999 is target space's home page)
**Then** the page is moved to the new space as a child of the target
**And** the page's SpaceId reflects the new space

### AC3: Move Page Before/After Sibling
**Given** I want to position a page before or after another page
**When** I run `Move-ConfluencePage -PageId '12345' -TargetId '67890' -Position 'before'`
**Then** the page is placed before the target sibling page
**And** position options include 'append' (default), 'before', 'after'

### AC4: Verbose Logging
**Given** any page move operation is performed
**When** `-Verbose` is used
**Then** the operation is logged in format: `Moving page 'PageId' to target 'TargetId' with position 'Position'...`
**And** the API token is NEVER logged (NFR6)

### AC5: Error Handling
**Given** an operation fails
**When** an error occurs (invalid page ID, permission denied, invalid target, circular reference, etc.)
**Then** a terminating error is thrown with actionable guidance (NFR20)
**And** error messages include the page ID and target ID for context

### AC6: ShouldProcess Support
**Given** a move operation is requested
**When** the function is called
**Then** `-WhatIf` shows what would be moved without making changes
**And** `-Confirm` prompts for confirmation (ConfirmImpact = Medium)
**And** the operation respects ShouldProcess patterns

## Tasks / Subtasks

- [x] Task 1: Create Move-ConfluencePage Function (AC: 1, 2, 3, 4, 5, 6)
  - [x] Create `Public/Move-ConfluencePage.ps1` file
  - [x] Implement `[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]`
  - [x] Add `[OutputType([PSCustomObject])]`
  - [x] Add `-PageId` parameter (Mandatory, string) for page to move
  - [x] Add `-TargetId` parameter (Mandatory, string) for target parent/sibling
  - [x] Add `-Position` parameter with `[ValidateSet('append', 'before', 'after')]` default 'append'
  - [x] Build endpoint: `/wiki/rest/api/content/{PageId}/move/{Position}/{TargetId}` (v1 API)
  - [x] Execute PUT request via Invoke-ConfluenceRequest
  - [x] Implement ShouldProcess check before API call
  - [x] Map v1 response to PSCustomObject (used v1 response directly per Dev Notes decision)
  - [x] Map response to PSCustomObject: Id, Title, SpaceId, SpaceKey, Status, ParentId, ParentType, Version
  - [x] Add `Write-Verbose` for operation
  - [x] Handle 404 with "Page not found" error
  - [x] Handle 403 with "Access denied" error
  - [x] Handle 400 with "Invalid move" error (circular reference, invalid target)
  - [x] Add comment-based help with synopsis, description, examples

- [x] Task 2: Create Unit Tests for Move-ConfluencePage (AC: 1, 2, 3, 4, 5, 6)
  - [x] Create `Tests/Public/Move-ConfluencePage.Tests.ps1`
  - [x] Test: Move page with default position (append)
  - [x] Test: Move page with 'before' position
  - [x] Test: Move page with 'after' position
  - [x] Test: WhatIf does not call API
  - [x] Test: Returns PSCustomObject with updated ParentId
  - [x] Test: 404 throws with "Page not found" message
  - [x] Test: 403 throws with "Access denied" message
  - [x] Test: 400 throws with "Invalid move" message
  - [x] Test: Verbose output does not contain token
  - [x] Test: Correct endpoint format is used (/wiki/rest/api/content/{id}/move/{position}/{targetId})

- [x] Task 3: Update Module Manifest (AC: 1-6)
  - [x] Update `ConfluenceAPI.psd1` FunctionsToExport array
  - [x] Add: `'Move-ConfluencePage'`
  - [x] Verify module loads with new function via `Test-ModuleManifest`

- [x] Task 4: Validate Implementation (AC: 1-6)
  - [x] Run `Invoke-ScriptAnalyzer -Path ./Modules/ConfluenceAPI/ -Recurse`
  - [x] Run all Pester tests
  - [x] Verify all existing tests still pass (regression check)

## Dev Notes

### Architecture Compliance

**Module Location:** `Modules/ConfluenceAPI/Public/`

Per architecture.md, page movement functions go in `Public/` as they are user-facing operations. The function will use `Invoke-ConfluenceRequest` internally for API calls.

**Function Pattern:**
Follows established patterns from Epic 1 and Story 2.3:
- `[CmdletBinding()]` with ShouldProcess/ConfirmImpact
- `[OutputType()]` attribute
- Comment-based help
- `Write-Verbose` for operations
- `$PSCmdlet.ThrowTerminatingError()` for errors

### CRITICAL: Confluence Page Movement API

**API REQUIRES V1 ENDPOINT - NOT V2**

The Confluence Cloud REST API **v2 does NOT have a move page endpoint**. You MUST use the v1 REST API:

**Endpoint:** `PUT /wiki/rest/api/content/{id}/move/{position}/{targetId}`

| Parameter | Description | Values |
|-----------|-------------|--------|
| `{id}` | The ID of the page to move | Page ID string |
| `{position}` | Where to place the page relative to target | `append`, `before`, `after` |
| `{targetId}` | The target content ID | Parent page ID or sibling page ID |

**Position Values:**
- `append` - Make the page a child of the target (most common for re-parenting)
- `before` - Place page before the target sibling
- `after` - Place page after the target sibling

**Moving to Different Space:**
To move a page to a different space's root, use the space's home page ID as the targetId with position 'append'.

### API Response (v1 Move Endpoint)

The v1 move endpoint returns the moved page content object:

```json
{
  "id": "12345",
  "type": "page",
  "status": "current",
  "title": "Moved Page",
  "space": {
    "id": 789012,
    "key": "NEWSPACE",
    "name": "New Space"
  },
  "ancestors": [
    {
      "id": "67890",
      "type": "page",
      "title": "New Parent Page"
    }
  ],
  "version": {
    "number": 2
  },
  "_links": { ... }
}
```

**Note:** The v1 response has a different structure than v2. The parent info is in `ancestors[0]` (last ancestor is immediate parent).

### PSCustomObject Mapping

Map the v1 response to our standard object format:

```powershell
[PSCustomObject]@{
    Id         = $response.id
    Title      = $response.title
    SpaceId    = $response.space.id
    SpaceKey   = $response.space.key
    Status     = $response.status
    ParentId   = if ($response.ancestors.Count -gt 0) { $response.ancestors[-1].id } else { $null }
    ParentType = if ($response.ancestors.Count -gt 0) { $response.ancestors[-1].type } else { $null }
    Version    = $response.version.number
}
```

### Error Messages (NFR20 Compliance)

| Scenario | Error Message |
|----------|---------------|
| Page not found | "Page with ID '12345' was not found. Verify the page ID exists." |
| Target not found | "Target content with ID '67890' was not found. Verify the target ID exists." |
| Permission denied | "Access denied to move page '12345'. Check your API permissions." |
| Invalid move | "Cannot move page '12345' to target '67890'. The move operation is invalid (check for circular references or invalid target type)." |

### Previous Story Intelligence (Story 2.3)

**Learnings Applied:**
- Mock scoping: use `InModuleScope ConfluenceAPI { }` for variable-dependent mocks
- Test patterns: `Should Be` (Pester 3.4 syntax), `Assert-MockCalled`
- Error handling: Use `$PSCmdlet.ThrowTerminatingError()` with proper ErrorRecord
- Response mapping: Always return PSCustomObject, never raw API response
- WhatIf testing: Mock returns even when -WhatIf is used, just don't call the API

**Key Pattern - Dual API Call (Move then Get):**
Since the v1 move endpoint returns v1 format, consider fetching the page via v2 GET after a successful move to return consistent v2-style data:

```powershell
# Execute v1 move
$null = Invoke-ConfluenceRequest -Endpoint "/wiki/rest/api/content/$PageId/move/$Position/$TargetId" -Method PUT

# Fetch v2 state for consistent return object
$response = Invoke-ConfluenceRequest -Endpoint "/wiki/api/v2/pages/$PageId" -Method GET
```

**Alternative - Use v1 response directly:**
If you prefer to avoid the extra API call, map the v1 response format:

```powershell
# Use v1 response directly
$response = Invoke-ConfluenceRequest -Endpoint "/wiki/rest/api/content/$PageId/move/$Position/$TargetId" -Method PUT

# Map v1 format to PSCustomObject
[PSCustomObject]@{
    Id         = $response.id
    Title      = $response.title
    SpaceId    = $response.space.id
    ...
}
```

**Decision:** Use the v1 response directly to avoid extra API calls. Document that this function returns slightly different properties (SpaceKey in addition to SpaceId) compared to other page functions.

### Testing Pattern (Pester 3.4.0+ Compatible)

```powershell
#Requires -Modules Pester

Describe 'Move-ConfluencePage' {
    BeforeAll {
        $ModulePath = (Get-Item "$PSScriptRoot\..\..\ConfluenceAPI.psd1").FullName
        Import-Module $ModulePath -Force
    }

    BeforeEach {
        InModuleScope ConfluenceAPI {
            $script:ConfluenceAPIKey = 'test-token'
            $script:ConfluenceBaseURL = 'https://test.atlassian.net'
        }
    }

    AfterEach {
        InModuleScope ConfluenceAPI {
            $script:ConfluenceAPIKey = $null
            $script:ConfluenceBaseURL = $null
        }
    }

    Context 'Move Page to New Parent' {
        It 'Moves page with append position by default' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @{
                        id = '12345'
                        title = 'Moved Page'
                        status = 'current'
                        space = @{
                            id = 789
                            key = 'TEST'
                            name = 'Test Space'
                        }
                        ancestors = @(
                            @{ id = '67890'; type = 'page'; title = 'Parent Page' }
                        )
                        version = @{ number = 2 }
                    }
                }

                $result = Move-ConfluencePage -PageId '12345' -TargetId '67890'
                $result.Id | Should Be '12345'
                $result.ParentId | Should Be '67890'
                Assert-MockCalled Invoke-ConfluenceRequest -ParameterFilter {
                    $Endpoint -eq '/wiki/rest/api/content/12345/move/append/67890'
                }
            }
        }

        It 'Supports before position' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @{
                        id = '12345'
                        title = 'Moved Page'
                        status = 'current'
                        space = @{ id = 789; key = 'TEST'; name = 'Test' }
                        ancestors = @(@{ id = '999'; type = 'page'; title = 'Parent' })
                        version = @{ number = 2 }
                    }
                }

                $result = Move-ConfluencePage -PageId '12345' -TargetId '67890' -Position 'before'
                Assert-MockCalled Invoke-ConfluenceRequest -ParameterFilter {
                    $Endpoint -eq '/wiki/rest/api/content/12345/move/before/67890'
                }
            }
        }
    }

    Context 'WhatIf Support' {
        It 'Does not call API when WhatIf is used' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest { }

                $result = Move-ConfluencePage -PageId '12345' -TargetId '67890' -WhatIf
                Assert-MockCalled Invoke-ConfluenceRequest -Times 0
            }
        }
    }
}
```

### Project Structure Notes

**Files to Create:**
```text
Modules/ConfluenceAPI/
├── Public/
│   └── Move-ConfluencePage.ps1     # CREATE
└── Tests/
    └── Public/
        └── Move-ConfluencePage.Tests.ps1  # CREATE
```

**Module will export 17 functions after this story:**
- Epic 1 functions (7): New/Get/Remove-ConfluenceAPIKey, New/Get/Remove-ConfluenceBaseURL, Test-ConfluenceConnection
- Story 2.1 (1): Invoke-ConfluenceRequest
- Story 2.2 (4): Get/New/Set/Remove-ConfluenceSpace
- Story 2.3 (4): Get/New/Set/Remove-ConfluencePage
- Story 2.4 (1): Move-ConfluencePage

### References

- [Source: docs/architecture.md#Project-Structure-Boundaries] - Page functions in Public/
- [Source: docs/architecture.md#Implementation-Patterns] - Naming and WhatIf patterns
- [Source: docs/project_context.md#Function-Structure] - CmdletBinding requirements
- [Source: docs/project_context.md#Error-Handling] - ThrowTerminatingError pattern
- [Source: docs/epics.md#Story-2.4] - Acceptance criteria
- [Source: docs/sprint-artifacts/2-3-page-crud-operations.md] - Previous story patterns
- [Confluence v1 Move Page API](https://developer.atlassian.com/cloud/confluence/rest/v1/api-group-content---children-and-descendants/)
- [Atlassian KB: Bulk Move Pages](https://confluence.atlassian.com/confkb/bulk-move-pages-using-the-confluence-cloud-api-1540735700.html)

### Common Mistakes to Avoid

1. **DO NOT** use v2 API for page movement - it doesn't exist, use v1 `/wiki/rest/api/content/{id}/move/...`
2. **DO NOT** confuse position values - 'append' makes target the parent, 'before'/'after' make target a sibling
3. **DO NOT** forget ShouldProcess for move operations
4. **DO NOT** log API tokens in verbose output (NFR6)
5. **DO NOT** use `throw` directly - use `$PSCmdlet.ThrowTerminatingError()`
6. **DO NOT** return raw API response - map to PSCustomObject
7. **DO NOT** use Pester 4+ syntax in tests (`Should Be` not `Should -Be`)
8. **DO NOT** forget to handle the v1 response format (ancestors array, space object)
9. **DO NOT** assume ancestors array exists - check before accessing
10. **DO NOT** forget that the target ID meaning changes based on position (parent vs sibling)

### Move Operation Flow Diagram

**Move Page Flow:**
```text
User calls Move-ConfluencePage -PageId '12345' -TargetId '67890' -Position 'append'
    │
    ▼
Move-ConfluencePage
    │
    ├── Write-Verbose "Moving page '12345' to target '67890' with position 'append'..."
    │
    ├── ShouldProcess check
    │       │
    │       └── If WhatIf → return $null
    │
    ├── Invoke-ConfluenceRequest -Endpoint '/wiki/rest/api/content/12345/move/append/67890' -Method PUT
    │       │
    │       ├── (handles auth, rate limiting, errors)
    │       │
    │       └── Returns v1 API response (different format!)
    │
    ├── Check if response null → ThrowTerminatingError "Move failed"
    │
    ├── Map v1 response to PSCustomObject
    │   └── Extract ancestors[-1] for ParentId
    │
    └── Return PSCustomObject with: Id, Title, SpaceId, SpaceKey, Status, ParentId, ParentType, Version
```

## Dev Agent Record

### Context Reference

<!-- Story context analysis completed by create-story workflow -->

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

- ScriptAnalyzer: No warnings/errors on Move-ConfluencePage.ps1
- Pester: 254 tests pass (22 tests for Move-ConfluencePage after code review fixes)
- Module manifest validated with Test-ModuleManifest

### Completion Notes List

- Implemented Move-ConfluencePage using Confluence v1 REST API (v2 has no move endpoint)
- Used v1 API response directly to avoid extra API call (per Dev Notes decision)
- Returns PSCustomObject with SpaceKey property (unique to this function due to v1 response)
- Parent info extracted from ancestors[-1] (last ancestor is immediate parent)
- All 6 acceptance criteria satisfied with comprehensive test coverage
- Function follows established patterns from Story 2.3

### Code Review Fixes Applied

- **M1**: Improved 404 error message to include both PageId and TargetId (API doesn't distinguish which is invalid)
- **M2/L3**: Fixed unused variable warnings in tests by adding assertions or using `$null =`
- **M3**: Added code comments documenting that SpaceKey is unique to this function due to v1 API
- Added new test: "Includes both PageId and TargetId in 404 error message"

### File List

- `Modules/ConfluenceAPI/Public/Move-ConfluencePage.ps1` - NEW
- `Modules/ConfluenceAPI/Tests/Public/Move-ConfluencePage.Tests.ps1` - NEW
- `Modules/ConfluenceAPI/ConfluenceAPI.psd1` - MODIFIED (added Move-ConfluencePage to FunctionsToExport)

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2025-12-11 | Story created via create-story workflow | Claude Opus 4.5 |
| 2025-12-11 | Implementation complete - all tasks done, 253 tests pass | Claude Opus 4.5 |
| 2025-12-11 | Code review fixes applied - 254 tests pass, status → done | Claude Opus 4.5 |
