# Story 2.3: Page CRUD Operations

Status: Done

## Story

As a **Technical Lead**,
I want **to create, read, update, and delete Confluence pages**,
so that **I can manage client documentation pages programmatically**.

## Acceptance Criteria

### AC1: Create Page
**Given** I want to create a page
**When** I run `New-ConfluencePage -SpaceId '123456' -Title 'User Inventory' -Body $htmlContent`
**Then** the page is created via POST to `/wiki/api/v2/pages`
**And** the Body parameter accepts Storage Format (XHTML) content
**And** returns PSCustomObject with Id, Title, SpaceId, Version, Status, ParentId

### AC2: Create Child Page
**Given** I want to create a child page
**When** I run `New-ConfluencePage -SpaceId '123456' -Title 'Active Users' -ParentId 12345`
**Then** the page is created as a child of the specified parent (FR12)
**And** the parent-child hierarchy is properly established

### AC3: Get Single Page
**Given** I want to retrieve a page
**When** I run `Get-ConfluencePage -PageId 12345`
**Then** the page content and metadata are returned as PSCustomObject
**And** if the page doesn't exist, a clear error is returned (404 handling)

### AC4: Get Page with Body Content
**Given** I want to retrieve a page with its body content
**When** I run `Get-ConfluencePage -PageId 12345 -IncludeBody`
**Then** the page is returned with Body property containing the content
**And** the body format is controlled by `-BodyFormat` parameter (default: 'storage')

### AC5: List Pages in Space
**Given** I want to list all pages in a space
**When** I run `Get-ConfluencePage -SpaceId '123456'`
**Then** all pages in the space are returned using cursor-based pagination
**And** results are aggregated automatically via `Invoke-ConfluenceRequest`

### AC6: Update Page Content
**Given** I want to update page content
**When** I run `Set-ConfluencePage -PageId 12345 -Body $newAdfContent`
**Then** the page is updated with new version number via PUT to `/wiki/api/v2/pages/{id}`
**And** `-WhatIf` shows what would change
**And** the version is automatically incremented

### AC7: Update Page Title
**Given** I want to update only the page title
**When** I run `Set-ConfluencePage -PageId 12345 -Title 'New Title'`
**Then** the page title is updated preserving existing content
**And** the version is automatically incremented

### AC8: Delete Page
**Given** I want to delete a page
**When** I run `Remove-ConfluencePage -PageId 12345`
**Then** `-Confirm` prompts for confirmation (ConfirmImpact = High)
**And** `-WhatIf` shows what would be deleted
**And** `-Force` skips confirmation prompt
**And** the page is moved to trash (not permanently deleted)

### AC9: Verbose Logging
**Given** any page operation is performed
**When** `-Verbose` is used
**Then** the operation is logged in format: `Verb-ing page 'PageId/Title'...`
**And** the API token is NEVER logged (NFR6)

### AC10: Error Handling
**Given** an operation fails
**When** an error occurs (invalid ID, permission denied, version conflict, etc.)
**Then** a terminating error is thrown with actionable guidance (NFR20)
**And** error messages include the page ID for context

## Tasks / Subtasks

- [x] Task 1: Create Get-ConfluencePage Function (AC: 3, 4, 5, 9, 10)
  - [x] Create `Public/Get-ConfluencePage.ps1` file
  - [x] Implement `[CmdletBinding()]` with `[OutputType([PSCustomObject], [PSCustomObject[]])]`
  - [x] Add `-PageId` parameter (optional, string) for single page retrieval
  - [x] Add `-SpaceId` parameter (optional, string) for listing pages in space
  - [x] Add `-IncludeBody` switch parameter to fetch body content
  - [x] Add `-BodyFormat` parameter with `[ValidateSet('storage', 'atlas_doc_format', 'view')]` default 'storage'
  - [x] If PageId provided: GET `/wiki/api/v2/pages/{id}` with optional `?body-format=storage`
  - [x] If SpaceId provided: GET `/wiki/api/v2/spaces/{id}/pages` (use pagination)
  - [x] Map response to PSCustomObject: Id, Title, SpaceId, Status, Version, ParentId, ParentType, AuthorId, CreatedAt, Body (if requested)
  - [x] Add `Write-Verbose` for operations
  - [x] Handle 404 with clear "Page not found" error
  - [x] Add comment-based help with synopsis, description, examples

- [x] Task 2: Create New-ConfluencePage Function (AC: 1, 2, 9, 10)
  - [x] Create `Public/New-ConfluencePage.ps1` file
  - [x] Implement `[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]`
  - [x] Add `[OutputType([PSCustomObject])]`
  - [x] Parameters: `-SpaceId` (Mandatory), `-Title` (Mandatory), `-Body` (optional ADF JSON), `-ParentId` (optional for child pages)
  - [x] Build request body with spaceId, status='current', title, body (if provided)
  - [x] If ParentId provided, add parentId to request body
  - [x] POST to `/wiki/api/v2/pages` with proper JSON body
  - [x] Implement ShouldProcess check before API call
  - [x] Map response to PSCustomObject: Id, Title, SpaceId, Status, Version, ParentId, ParentType, AuthorId, CreatedAt
  - [x] Add `Write-Verbose` for operation
  - [x] Add comment-based help

- [x] Task 3: Create Set-ConfluencePage Function (AC: 6, 7, 9, 10)
  - [x] Create `Public/Set-ConfluencePage.ps1` file
  - [x] Implement `[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]`
  - [x] Add `[OutputType([PSCustomObject])]`
  - [x] Parameters: `-PageId` (Mandatory), `-Title`, `-Body`, `-Status`
  - [x] At least one update parameter required (validate in process block)
  - [x] Fetch current page version via GET first (API requires version.number for PUT)
  - [x] Build PUT body with id, status, title, body, and version.number (current + 1)
  - [x] PUT to `/wiki/api/v2/pages/{id}` with updated fields
  - [x] Handle 409 Conflict (version mismatch) with clear error message
  - [x] Implement ShouldProcess check
  - [x] Return updated page object
  - [x] Add `Write-Verbose` for operation
  - [x] Add comment-based help

- [x] Task 4: Create Remove-ConfluencePage Function (AC: 8, 9, 10)
  - [x] Create `Public/Remove-ConfluencePage.ps1` file
  - [x] Implement `[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]`
  - [x] Parameters: `-PageId` (Mandatory), `-Force` switch
  - [x] DELETE to `/wiki/api/v2/pages/{id}` (moves to trash)
  - [x] Force parameter bypasses ShouldContinue
  - [x] WhatIf shows "Would delete page 'PageId'"
  - [x] Return nothing on success (or $null)
  - [x] Handle 404 with clear "Page not found" error
  - [x] Add `Write-Verbose` for operation
  - [x] Add comment-based help

- [x] Task 5: Create Unit Tests for Get-ConfluencePage (AC: 3, 4, 5, 9, 10)
  - [x] Create `Tests/Public/Get-ConfluencePage.Tests.ps1`
  - [x] Test: Single page returns PSCustomObject with correct properties
  - [x] Test: Page with body content returns Body property
  - [x] Test: List pages in space returns array of PSCustomObjects
  - [x] Test: Pagination is handled automatically
  - [x] Test: 404 throws with "Page not found" message
  - [x] Test: Verbose output does not contain token
  - [x] Test: Properties mapped correctly (Id, Title, SpaceId, Status, Version, ParentId)

- [x] Task 6: Create Unit Tests for New-ConfluencePage (AC: 1, 2, 9, 10)
  - [x] Create `Tests/Public/New-ConfluencePage.Tests.ps1`
  - [x] Test: Creates page with required parameters (SpaceId, Title)
  - [x] Test: Optional Body content is included when provided
  - [x] Test: ParentId creates child page relationship
  - [x] Test: WhatIf does not call API
  - [x] Test: Returns PSCustomObject with correct properties
  - [x] Test: Verbose logs operation

- [x] Task 7: Create Unit Tests for Set-ConfluencePage (AC: 6, 7, 9, 10)
  - [x] Create `Tests/Public/Set-ConfluencePage.Tests.ps1`
  - [x] Test: Updates page title (fetches version first, then updates)
  - [x] Test: Updates page body content
  - [x] Test: Auto-increments version number
  - [x] Test: WhatIf does not call PUT API (but may call GET for version)
  - [x] Test: Returns updated PSCustomObject
  - [x] Test: Handles 409 version conflict with clear error
  - [x] Test: Requires at least one update parameter

- [x] Task 8: Create Unit Tests for Remove-ConfluencePage (AC: 8, 9, 10)
  - [x] Create `Tests/Public/Remove-ConfluencePage.Tests.ps1`
  - [x] Test: Deletes page with confirmation
  - [x] Test: WhatIf does not call API
  - [x] Test: Force bypasses confirmation
  - [x] Test: 404 throws with clear message
  - [x] Test: Returns null on success

- [x] Task 9: Update Module Manifest (AC: 1-8)
  - [x] Update `ConfluenceAPI.psd1` FunctionsToExport array
  - [x] Add: `'Get-ConfluencePage'`, `'New-ConfluencePage'`, `'Set-ConfluencePage'`, `'Remove-ConfluencePage'`
  - [x] Verify module loads with new functions via `Test-ModuleManifest`

- [x] Task 10: Validate Implementation (AC: 1-10)
  - [x] Run `Invoke-ScriptAnalyzer -Path ./Modules/ConfluenceAPI/ -Recurse`
  - [x] Run all Pester tests
  - [x] Verify all existing tests still pass (regression check)

## Dev Notes

### Architecture Compliance

**Module Location:** `Modules/ConfluenceAPI/Public/`

Per architecture.md, page operations functions go in `Public/` as they are user-facing CRUD operations. These functions will use `Invoke-ConfluenceRequest` internally for all API calls.

**Function Pattern:**
All functions follow the established patterns from Epic 1, Story 2.1, and Story 2.2:
- `[CmdletBinding()]` with appropriate ShouldProcess/ConfirmImpact
- `[OutputType()]` attribute
- Comment-based help
- `Write-Verbose` for operations
- `$PSCmdlet.ThrowTerminatingError()` for errors

### Confluence API v2 Page Endpoints

**Base URL:** `/wiki/api/v2/pages`

| Operation | Method | Endpoint | Notes |
|-----------|--------|----------|-------|
| List in space | GET | `/wiki/api/v2/spaces/{space-id}/pages` | Returns paginated list |
| Get by ID | GET | `/wiki/api/v2/pages/{id}` | Returns single page |
| Get with body | GET | `/wiki/api/v2/pages/{id}?body-format=storage` | Includes body content |
| Create | POST | `/wiki/api/v2/pages` | Body: spaceId, title, body, parentId |
| Update | PUT | `/wiki/api/v2/pages/{id}` | Body: id, status, title, body, version |
| Delete | DELETE | `/wiki/api/v2/pages/{id}` | Moves to trash (not permanent) |

**CRITICAL:** API v2 Update (PUT) requires current version number. You MUST fetch the page first to get the version, then increment it for the PUT request. Failure to do so results in 409 Conflict error: "Version must be incremented when updating a page."

### Page Object Structure

**API Response (GET /pages/{id}?body-format=storage):**
```json
{
  "id": "123456",
  "status": "current",
  "title": "User Inventory",
  "spaceId": "789012",
  "parentId": "111222",
  "parentType": "page",
  "authorId": "5b10a2844c20165700ede21g",
  "createdAt": "2025-12-11T10:30:00.000Z",
  "version": {
    "number": 1,
    "message": "",
    "minorEdit": false,
    "authorId": "5b10a2844c20165700ede21g",
    "createdAt": "2025-12-11T10:30:00.000Z"
  },
  "body": {
    "storage": {
      "representation": "storage",
      "value": "<p>Content here</p>"
    }
  },
  "_links": { ... }
}
```

**PSCustomObject Mapping:**
```powershell
[PSCustomObject]@{
    Id         = $response.id
    Title      = $response.title
    SpaceId    = $response.spaceId
    Status     = $response.status
    ParentId   = $response.parentId
    ParentType = $response.parentType
    AuthorId   = $response.authorId
    CreatedAt  = $response.createdAt
    Version    = $response.version.number
    Body       = if ($response.body.storage) { $response.body.storage.value } else { $null }
}
```

### Create Page Request Body

```json
{
  "spaceId": "789012",
  "status": "current",
  "title": "User Inventory",
  "parentId": "111222",
  "body": {
    "representation": "storage",
    "value": "<p>This is the content of the new page.</p>"
  }
}
```

**Notes:**
- `spaceId` is REQUIRED (string, not key)
- `parentId` is optional - omit for top-level pages
- `body` is optional - can create blank page
- `status` should be "current" for published pages

### Update Page Request Body

**CRITICAL:** PUT requires the current version number incremented by 1:

```json
{
  "id": "123456",
  "status": "current",
  "title": "Updated Title",
  "body": {
    "representation": "storage",
    "value": "<p>Updated content</p>"
  },
  "version": {
    "number": 2,
    "message": "Updated via API"
  }
}
```

**Version Handling Flow:**
1. GET `/wiki/api/v2/pages/{id}` to get current version.number
2. Increment version.number by 1
3. PUT with the new version.number

**Error 409:** If version.number is not incremented properly:
```
"Version must be incremented when updating a page. Current Version: 1. Provided version: 1"
```

### Error Messages (NFR20 Compliance)

| Scenario | Error Message |
|----------|---------------|
| Page not found | "Page with ID '123456' was not found. Verify the page ID exists." |
| Permission denied | "Access denied to page '123456'. Check your API permissions." |
| Version conflict | "Version conflict updating page '123456'. Current version is X, please retry with updated version." |
| Invalid space | "Space ID '789012' is invalid or you don't have access." |
| Missing body format | "Body format 'X' is not supported. Use 'storage', 'atlas_doc_format', or 'view'." |

### Previous Story Intelligence (Story 2.2)

**Learnings Applied:**
- PowerShell pipeline array unwrapping: Use `, @()` comma operator in mocks to preserve single-item arrays
- Use `$response -isnot [hashtable]` check when determining if response is enumerable
- Mock scoping: use `InModuleScope ConfluenceAPI { }` for variable-dependent mocks
- `$script:mockCallCount` pattern for multi-call mocks (lookup + action)
- Test patterns: `Should Be` (Pester 3.4 syntax), `Assert-MockCalled`
- API v2 requires numeric ID for most operations, not keys

**Code Patterns from Story 2.2:**
```powershell
# Space lookup pattern (used for space operations, page needs similar for version fetch)
$script:mockCallCount = 0
Mock Invoke-ConfluenceRequest {
    $script:mockCallCount++
    if ($script:mockCallCount -eq 1) {
        # First call - GET for current state
        @{ id = '123'; version = @{ number = 1 } }
    } else {
        # Second call - PUT/POST action
        @{ id = '123'; version = @{ number = 2 } }
    }
}

# Error handling pattern
$PSCmdlet.ThrowTerminatingError(
    [System.Management.Automation.ErrorRecord]::new(
        [System.Exception]::new("Page with ID '$PageId' was not found."),
        "PageNotFound",
        [System.Management.Automation.ErrorCategory]::ObjectNotFound,
        $PageId
    )
)

# Version fetch + update pattern for Set-ConfluencePage
$currentPage = Invoke-ConfluenceRequest -Endpoint "/wiki/api/v2/pages/$PageId" -Method GET
$newVersion = $currentPage.version.number + 1
# ... build body with version.number = $newVersion
$response = Invoke-ConfluenceRequest -Endpoint "/wiki/api/v2/pages/$PageId" -Method PUT -Body $jsonBody
```

### Testing Pattern (Pester 3.4.0+ Compatible)

```powershell
#Requires -Modules Pester

Describe 'Get-ConfluencePage' {
    BeforeAll {
        $ModulePath = (Get-Item "$PSScriptRoot\..\..\ConfluenceAPI.psd1").FullName
        Import-Module $ModulePath -Force
    }

    BeforeEach {
        # Set up credentials
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

    Context 'Get Single Page' {
        It 'Returns PSCustomObject with correct properties' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @{
                        id = '123456'
                        title = 'Test Page'
                        spaceId = '789'
                        status = 'current'
                        parentId = $null
                        parentType = $null
                        authorId = 'user123'
                        createdAt = '2025-12-11T10:00:00Z'
                        version = @{ number = 1 }
                    }
                }

                $result = Get-ConfluencePage -PageId '123456'
                $result.Id | Should Be '123456'
                $result.Title | Should Be 'Test Page'
                $result.Version | Should Be 1
            }
        }
    }

    Context 'Update Page with Version' {
        It 'Fetches current version before update' {
            InModuleScope ConfluenceAPI {
                $script:mockCallCount = 0
                Mock Invoke-ConfluenceRequest {
                    $script:mockCallCount++
                    if ($script:mockCallCount -eq 1) {
                        # GET call
                        @{ id = '123'; title = 'Old'; spaceId = '789'; status = 'current'; version = @{ number = 1 } }
                    } else {
                        # PUT call
                        @{ id = '123'; title = 'New'; spaceId = '789'; status = 'current'; version = @{ number = 2 } }
                    }
                }

                $result = Set-ConfluencePage -PageId '123' -Title 'New'
                $result.Version | Should Be 2
                Assert-MockCalled Invoke-ConfluenceRequest -Times 2
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
│   ├── Get-ConfluencePage.ps1     # CREATE
│   ├── New-ConfluencePage.ps1     # CREATE
│   ├── Set-ConfluencePage.ps1     # CREATE
│   └── Remove-ConfluencePage.ps1  # CREATE
└── Tests/
    └── Public/
        ├── Get-ConfluencePage.Tests.ps1     # CREATE
        ├── New-ConfluencePage.Tests.ps1     # CREATE
        ├── Set-ConfluencePage.Tests.ps1     # CREATE
        └── Remove-ConfluencePage.Tests.ps1  # CREATE
```

**Module will export 16 functions after this story:**
- Epic 1 functions (7): New/Get/Remove-ConfluenceAPIKey, New/Get/Remove-ConfluenceBaseURL, Test-ConfluenceConnection
- Story 2.1 (1): Invoke-ConfluenceRequest
- Story 2.2 (4): Get/New/Set/Remove-ConfluenceSpace
- Story 2.3 (4): Get/New/Set/Remove-ConfluencePage

### References

- [Source: docs/architecture.md#Project-Structure-Boundaries] - Page functions in Public/
- [Source: docs/architecture.md#Implementation-Patterns] - Naming and WhatIf patterns
- [Source: docs/project_context.md#Function-Structure] - CmdletBinding requirements
- [Source: docs/project_context.md#Error-Handling] - ThrowTerminatingError pattern
- [Source: docs/epics.md#Story-2.3] - Acceptance criteria
- [Source: docs/sprint-artifacts/2-2-space-operations.md] - Previous story patterns (array handling, mocks)
- [Confluence REST API v2 - Pages](https://developer.atlassian.com/cloud/confluence/rest/v2/api-group-page/)

### Common Mistakes to Avoid

1. **DO NOT** update a page without fetching current version first - will get 409 Conflict
2. **DO NOT** forget to increment version.number by 1 for PUT requests
3. **DO NOT** use SpaceKey for page operations - API requires SpaceId (numeric)
4. **DO NOT** forget ShouldProcess for New/Set/Remove operations
5. **DO NOT** forget ConfirmImpact = 'High' for Remove-ConfluencePage
6. **DO NOT** log API tokens in verbose output (NFR6)
7. **DO NOT** use `throw` directly - use `$PSCmdlet.ThrowTerminatingError()`
8. **DO NOT** return raw API response - map to PSCustomObject
9. **DO NOT** forget to handle the body format parameter when fetching content
10. **DO NOT** use Pester 4+ syntax in tests (`Should Be` not `Should -Be`)
11. **DO NOT** forget comma operator `, @()` in mocks for single-item arrays
12. **DO NOT** forget `$response -isnot [hashtable]` check for enumerable detection

### Page Operations Flow Diagrams

**Get Page Flow:**
```text
User calls Get-ConfluencePage -PageId '123456'
    │
    ▼
Get-ConfluencePage
    │
    ├── Write-Verbose "Getting page '123456'..."
    │
    ├── Invoke-ConfluenceRequest -Endpoint '/wiki/api/v2/pages/123456' -Method GET
    │       │
    │       ├── (handles auth, rate limiting, errors)
    │       │
    │       └── Returns raw API response
    │
    ├── Check if response null → ThrowTerminatingError "Page not found"
    │
    ├── Map response to PSCustomObject
    │
    └── Return PSCustomObject with: Id, Title, SpaceId, Status, Version, ParentId, etc.
```

**Update Page Flow (CRITICAL - Version Handling):**
```text
User calls Set-ConfluencePage -PageId '123456' -Title 'New Title'
    │
    ▼
Set-ConfluencePage
    │
    ├── Write-Verbose "Updating page '123456'..."
    │
    ├── STEP 1: Fetch current page (for version)
    │   └── GET /wiki/api/v2/pages/123456
    │       └── Extract version.number (e.g., 5)
    │
    ├── STEP 2: Increment version
    │   └── newVersion = 5 + 1 = 6
    │
    ├── STEP 3: Build PUT body
    │   └── { id, status, title, version: { number: 6 } }
    │
    ├── ShouldProcess check
    │
    ├── STEP 4: PUT request
    │   └── PUT /wiki/api/v2/pages/123456
    │
    ├── Handle 409 → ThrowTerminatingError "Version conflict"
    │
    └── Return updated PSCustomObject
```

## Dev Agent Record

### Context Reference

<!-- Story context analysis completed by create-story workflow -->

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

None - implementation completed without issues.

### Completion Notes List

- Implemented all 4 Page CRUD functions: Get-ConfluencePage, New-ConfluencePage, Set-ConfluencePage, Remove-ConfluencePage
- Set-ConfluencePage correctly handles version fetching before update (API v2 requires version increment)
- All functions follow established patterns from Epic 1 and Story 2.2
- 232 total tests pass (61 new tests for page operations, no regressions)
- PSScriptAnalyzer passes with 0 warnings on all new files
- Module manifest updated to export 16 functions total

### Senior Developer Review (AI)

**Review Date:** 2025-12-11
**Reviewer:** Claude Opus 4.5 (code-review workflow)
**Outcome:** APPROVED with fixes applied

**Issues Found and Fixed:**

| Severity | Issue | Resolution |
|----------|-------|------------|
| HIGH | project_context.md stated Pester 5.x but code uses Pester 3.4 syntax | Fixed documentation to match actual PS 5.1 compatible syntax |
| HIGH | AC9 verbose format partially implemented | Enhanced Set-ConfluencePage to include PageId/Title in verbose |
| MEDIUM | Redundant array handling code in Get-ConfluencePage | Simplified to `$pages = @($response)` |
| MEDIUM | Empty Force block in Remove-ConfluencePage | Removed dead code, added explanatory comment |
| MEDIUM | AC1 mentioned ADF JSON but code uses Storage Format | Clarified AC1 to reflect Storage Format implementation |
| LOW | Missing test for BodyFormat 'view' option | Added test case |

**Files Modified During Review:**
- docs/project_context.md (Pester version correction)
- docs/sprint-artifacts/2-3-page-crud-operations.md (AC1 clarification, review notes)
- Modules/ConfluenceAPI/Public/Get-ConfluencePage.ps1 (simplified array handling)
- Modules/ConfluenceAPI/Public/Set-ConfluencePage.ps1 (enhanced verbose logging)
- Modules/ConfluenceAPI/Public/Remove-ConfluencePage.ps1 (removed dead code)
- Modules/ConfluenceAPI/Tests/Public/Get-ConfluencePage.Tests.ps1 (added view format test)

### File List

**Created:**
- Modules/ConfluenceAPI/Public/Get-ConfluencePage.ps1
- Modules/ConfluenceAPI/Public/New-ConfluencePage.ps1
- Modules/ConfluenceAPI/Public/Set-ConfluencePage.ps1
- Modules/ConfluenceAPI/Public/Remove-ConfluencePage.ps1
- Modules/ConfluenceAPI/Tests/Public/Get-ConfluencePage.Tests.ps1
- Modules/ConfluenceAPI/Tests/Public/New-ConfluencePage.Tests.ps1
- Modules/ConfluenceAPI/Tests/Public/Set-ConfluencePage.Tests.ps1
- Modules/ConfluenceAPI/Tests/Public/Remove-ConfluencePage.Tests.ps1

**Modified:**
- Modules/ConfluenceAPI/ConfluenceAPI.psd1 (added 4 functions to FunctionsToExport)

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2025-12-11 | Story created via create-story workflow | Claude Opus 4.5 |
| 2025-12-11 | Implementation complete - all 10 tasks done, 231 tests pass | Claude Opus 4.5 |
| 2025-12-11 | Code review complete - 6 issues fixed, 232 tests pass | Claude Opus 4.5 |
