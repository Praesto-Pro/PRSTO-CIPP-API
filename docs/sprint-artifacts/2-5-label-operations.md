# Story 2.5: Label Operations

Status: Done

## Story

As a **Technical Lead**,
I want **to add, view, and remove labels from Confluence content**,
so that **I can categorize and organize pages for easy discovery and filtering**.

## Acceptance Criteria

### AC1: Get Labels from Page
**Given** I want to view labels on a page
**When** I run `Get-ConfluenceLabel -PageId '12345'`
**Then** all labels on the page are returned via GET to `/wiki/rest/api/content/{id}/label`
**And** each label includes: Id, Name, Prefix
**And** returns an empty array `@()` if no labels exist
**And** `-Verbose` logs "Retrieving labels for page '12345'"

### AC2: Add Label to Page
**Given** I want to add a label to a page
**When** I run `Add-ConfluenceLabel -PageId '12345' -Label 'user-inventory'`
**Then** the label is added via POST to `/wiki/rest/api/content/{id}/label`
**And** the request body contains `[{prefix: "global", name: "user-inventory"}]`
**And** returns PSCustomObject with the added label(s) including Id, Name, Prefix
**And** `-WhatIf` shows what would be added without making changes
**And** `-Verbose` logs "Adding label 'user-inventory' to page '12345'"

### AC3: Add Multiple Labels
**Given** I want to add multiple labels at once
**When** I run `Add-ConfluenceLabel -PageId '12345' -Label 'label1', 'label2', 'label3'`
**Then** all labels are added in a single API call
**And** returns array of all added label objects

### AC4: Remove Label from Page
**Given** I want to remove a label from a page
**When** I run `Remove-ConfluenceLabel -PageId '12345' -Label 'old-label'`
**Then** the label is removed via DELETE to `/wiki/rest/api/content/{id}/label/{label}`
**And** `-WhatIf` shows what would be removed without making changes
**And** `-Confirm` prompts for confirmation (ConfirmImpact = Medium)
**And** `-Verbose` logs "Removing label 'old-label' from page '12345'"

### AC5: Remove Label with Special Characters
**Given** I want to remove a label containing "/" characters
**When** I run `Remove-ConfluenceLabel -PageId '12345' -Label 'category/subcategory'`
**Then** the label is removed via DELETE to `/wiki/rest/api/content/{id}/label?name={label}` (query param method)
**And** the label name is properly URL-encoded

### AC6: Error Handling
**Given** an operation fails
**When** an error occurs (invalid page ID, permission denied, label not found, etc.)
**Then** a terminating error is thrown with actionable guidance (NFR20)
**And** error messages include the page ID and label name for context
**And** 404 errors distinguish between "page not found" and "label not found"
**And** 403 errors indicate "Access denied to modify labels on page"

## Tasks / Subtasks

- [x] Task 1: Create Get-ConfluenceLabel Function (AC: 1, 6)
  - [x] Create `Public/Get-ConfluenceLabel.ps1` file
  - [x] Implement `[CmdletBinding()]`
  - [x] Add `[OutputType([PSCustomObject[]])]`
  - [x] Add `-PageId` parameter (Mandatory, string)
  - [x] Build endpoint: `/wiki/rest/api/content/{PageId}/label` (v1 API)
  - [x] Execute GET request via Invoke-ConfluenceRequest
  - [x] Map v1 response to PSCustomObject array: Id, Name, Prefix
  - [x] Return empty array `@()` if no labels
  - [x] Add `Write-Verbose` for operation
  - [x] Handle 404 with "Page not found" error
  - [x] Handle 403 with "Access denied" error
  - [x] Add comment-based help with synopsis, description, examples

- [x] Task 2: Create Add-ConfluenceLabel Function (AC: 2, 3, 6)
  - [x] Create `Public/Add-ConfluenceLabel.ps1` file
  - [x] Implement `[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]`
  - [x] Add `[OutputType([PSCustomObject[]])]`
  - [x] Add `-PageId` parameter (Mandatory, string)
  - [x] Add `-Label` parameter (Mandatory, string[], accepts multiple values)
  - [x] Build request body: array of `@{prefix = 'global'; name = $label}`
  - [x] Execute POST to `/wiki/rest/api/content/{PageId}/label` (v1 API)
  - [x] Implement ShouldProcess check before API call
  - [x] Map v1 response to PSCustomObject array
  - [x] Add `Write-Verbose` for operation
  - [x] Handle 404 with "Page not found" error
  - [x] Handle 403 with "Access denied" error
  - [x] Add comment-based help with synopsis, description, examples

- [x] Task 3: Create Remove-ConfluenceLabel Function (AC: 4, 5, 6)
  - [x] Create `Public/Remove-ConfluenceLabel.ps1` file
  - [x] Implement `[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]`
  - [x] Add `-PageId` parameter (Mandatory, string)
  - [x] Add `-Label` parameter (Mandatory, string)
  - [x] Check if label contains "/" - use query param method if so
  - [x] Build endpoint: `/wiki/rest/api/content/{PageId}/label/{Label}` or `?name={Label}`
  - [x] URL-encode the label name for query param method
  - [x] Execute DELETE request via Invoke-ConfluenceRequest
  - [x] Implement ShouldProcess check before API call
  - [x] Add `Write-Verbose` for operation
  - [x] Handle 404 with context-aware error (page vs label not found)
  - [x] Handle 403 with "Access denied" error
  - [x] Add comment-based help with synopsis, description, examples

- [x] Task 4: Create Unit Tests for Get-ConfluenceLabel (AC: 1, 6)
  - [x] Create `Tests/Public/Get-ConfluenceLabel.Tests.ps1`
  - [x] Test: Returns labels with expected properties
  - [x] Test: Returns empty array when no labels
  - [x] Test: 404 throws with "Page not found" message
  - [x] Test: 403 throws with "Access denied" message
  - [x] Test: Verbose output logs page ID
  - [x] Test: Verbose output does not contain token

- [x] Task 5: Create Unit Tests for Add-ConfluenceLabel (AC: 2, 3, 6)
  - [x] Create `Tests/Public/Add-ConfluenceLabel.Tests.ps1`
  - [x] Test: Adds single label successfully
  - [x] Test: Adds multiple labels in single call
  - [x] Test: Request body format is correct (array of prefix/name objects)
  - [x] Test: WhatIf does not call API
  - [x] Test: Returns PSCustomObject with label properties
  - [x] Test: 404 throws with "Page not found" message
  - [x] Test: 403 throws with "Access denied" message
  - [x] Test: Verbose output logs label being added

- [x] Task 6: Create Unit Tests for Remove-ConfluenceLabel (AC: 4, 5, 6)
  - [x] Create `Tests/Public/Remove-ConfluenceLabel.Tests.ps1`
  - [x] Test: Removes label using path parameter (normal label)
  - [x] Test: Removes label using query parameter (label with "/" character)
  - [x] Test: URL-encodes label name for query parameter
  - [x] Test: WhatIf does not call API
  - [x] Test: Confirm prompts (ConfirmImpact = Medium)
  - [x] Test: 404 throws with appropriate error message
  - [x] Test: 403 throws with "Access denied" message
  - [x] Test: Verbose output logs label being removed

- [x] Task 7: Update Module Manifest (AC: 1-6)
  - [x] Update `ConfluenceAPI.psd1` FunctionsToExport array
  - [x] Add: `'Get-ConfluenceLabel'`
  - [x] Add: `'Add-ConfluenceLabel'`
  - [x] Add: `'Remove-ConfluenceLabel'`
  - [x] Verify module loads with new functions via `Test-ModuleManifest`

- [x] Task 8: Validate Implementation (AC: 1-6)
  - [x] Run `Invoke-ScriptAnalyzer -Path ./Modules/ConfluenceAPI/ -Recurse`
  - [x] Run all Pester tests
  - [x] Verify all existing tests still pass (regression check)

## Dev Notes

### Architecture Compliance

**Module Location:** `Modules/ConfluenceAPI/Public/`

Per architecture.md, label functions go in `Public/` as they are user-facing operations. All functions will use `Invoke-ConfluenceRequest` internally for API calls.

**Function Pattern:**
Follows established patterns from Epic 1, Story 2.3, and Story 2.4:
- `[CmdletBinding()]` with ShouldProcess/ConfirmImpact
- `[OutputType()]` attribute
- Comment-based help
- `Write-Verbose` for operations
- `$PSCmdlet.ThrowTerminatingError()` for errors

### CRITICAL: Confluence Label API Requires V1

**API REQUIRES V1 ENDPOINT - NOT V2**

The Confluence Cloud REST API v2 does NOT support adding or removing labels. You MUST use the v1 REST API (same pattern as Story 2.4 Move-ConfluencePage).

**Get Labels Endpoint:** `GET /wiki/rest/api/content/{id}/label`

**Response:**
```json
{
  "results": [
    {
      "id": "123456",
      "prefix": "global",
      "name": "user-inventory",
      "label": "user-inventory"
    }
  ],
  "_links": { ... }
}
```

**Add Labels Endpoint:** `POST /wiki/rest/api/content/{id}/label`

**Request Body:**
```json
[
  { "prefix": "global", "name": "label1" },
  { "prefix": "global", "name": "label2" }
]
```

**Response:** Returns the labels that were added.

**Remove Label Endpoints:**
1. Path parameter (standard): `DELETE /wiki/rest/api/content/{id}/label/{label}`
2. Query parameter (for labels with "/"): `DELETE /wiki/rest/api/content/{id}/label?name={label}`

Both return 204 No Content on success.

### Label Prefix

The `prefix` field is always `"global"` for user-created labels. Confluence also supports:
- `"my"` - Personal labels (user-specific)
- `"team"` - Team labels (Confluence Data Center only)

For CIPP integration purposes, always use `"global"` prefix.

### PSCustomObject Mapping

Map the v1 response to PSCustomObject for consistency:

```powershell
[PSCustomObject]@{
    Id     = $label.id
    Name   = $label.name
    Prefix = $label.prefix
}
```

### Error Messages (NFR20 Compliance)

| Scenario | Error Message |
|----------|---------------|
| Page not found (404) | "Page with ID '12345' was not found. Verify the page ID exists." |
| Label not found (404 on DELETE) | "Label 'old-label' was not found on page '12345'." |
| Permission denied (403) | "Access denied to modify labels on page '12345'. Check your API permissions." |
| Invalid request (400) | "Failed to add label 'label' to page '12345': {API error message}" |

### URL Encoding for Special Characters

Labels containing "/" characters MUST use the query parameter method with URL encoding:

```powershell
# Standard label (no special chars)
$endpoint = "/wiki/rest/api/content/$PageId/label/$Label"

# Label with "/" - use query param
if ($Label -match '/') {
    $encodedLabel = [System.Uri]::EscapeDataString($Label)
    $endpoint = "/wiki/rest/api/content/$PageId/label?name=$encodedLabel"
}
```

### Previous Story Intelligence (Story 2.4)

**Learnings Applied:**
- v1 API has different response structure than v2 - map appropriately
- Use `InModuleScope ConfluenceAPI { }` for tests with module variables
- `Should Be` (Pester 3.4 syntax, no hyphen)
- Error handling: Use `$PSCmdlet.ThrowTerminatingError()` with proper ErrorRecord
- Include both identifiers (PageId and Label) in error messages for context

**Testing Pattern from Story 2.4:**
- Mock `Invoke-ConfluenceRequest` in `InModuleScope`
- Add assertions to prevent PSScriptAnalyzer unused variable warnings
- Use `$null =` for results that intentionally aren't checked

### Project Structure Notes

**Files to Create:**
```text
Modules/ConfluenceAPI/
├── Public/
│   ├── Get-ConfluenceLabel.ps1     # CREATE
│   ├── Add-ConfluenceLabel.ps1     # CREATE
│   └── Remove-ConfluenceLabel.ps1  # CREATE
└── Tests/
    └── Public/
        ├── Get-ConfluenceLabel.Tests.ps1     # CREATE
        ├── Add-ConfluenceLabel.Tests.ps1     # CREATE
        └── Remove-ConfluenceLabel.Tests.ps1  # CREATE
```

**Module will export 20 functions after this story:**
- Epic 1 functions (7): New/Get/Remove-ConfluenceAPIKey, New/Get/Remove-ConfluenceBaseURL, Test-ConfluenceConnection
- Story 2.1 (1): Invoke-ConfluenceRequest
- Story 2.2 (4): Get/New/Set/Remove-ConfluenceSpace
- Story 2.3 (4): Get/New/Set/Remove-ConfluencePage
- Story 2.4 (1): Move-ConfluencePage
- Story 2.5 (3): Get/Add/Remove-ConfluenceLabel

### References

- [Source: docs/architecture.md#Project-Structure-Boundaries] - Label functions in Public/
- [Source: docs/architecture.md#Implementation-Patterns] - Naming and WhatIf patterns
- [Source: docs/project_context.md#Function-Structure] - CmdletBinding requirements
- [Source: docs/project_context.md#Error-Handling] - ThrowTerminatingError pattern
- [Source: docs/epics.md#Story-2.5] - Acceptance criteria
- [Source: docs/sprint-artifacts/2-4-page-movement-hierarchy.md] - Previous story patterns and v1 API learnings
- [Confluence v1 Content Labels API](https://developer.atlassian.com/cloud/confluence/rest/v1/api-group-content-labels/)
- [Atlassian Community: v2 API label limitations](https://community.atlassian.com/forums/Confluence-questions/How-do-i-use-the-Confluence-v2-REST-api-to-create-labels-on-new/qaq-p/2720407)

### Common Mistakes to Avoid

1. **DO NOT** use v2 API for label operations - it doesn't support add/remove, use v1
2. **DO NOT** forget to URL-encode labels with "/" characters when using query param method
3. **DO NOT** forget ShouldProcess for Add and Remove operations
4. **DO NOT** log API tokens in verbose output (NFR6)
5. **DO NOT** use `throw` directly - use `$PSCmdlet.ThrowTerminatingError()`
6. **DO NOT** return raw API response - map to PSCustomObject
7. **DO NOT** use Pester 4+ syntax in tests (`Should Be` not `Should -Be`)
8. **DO NOT** forget that Add-ConfluenceLabel accepts multiple labels as array
9. **DO NOT** forget to return empty array `@()` from Get-ConfluenceLabel when no labels
10. **DO NOT** assume label name is safe for path - check for "/" characters

### Get-ConfluenceLabel Flow Diagram

```text
User calls Get-ConfluenceLabel -PageId '12345'
    │
    ▼
Get-ConfluenceLabel
    │
    ├── Write-Verbose "Retrieving labels for page '12345'..."
    │
    ├── Invoke-ConfluenceRequest -Endpoint '/wiki/rest/api/content/12345/label' -Method GET
    │       │
    │       ├── (handles auth, rate limiting, errors)
    │       │
    │       └── Returns v1 API response
    │
    ├── Check if response.results is null or empty → return @()
    │
    ├── Map each label to PSCustomObject
    │   └── { Id, Name, Prefix }
    │
    └── Return array of PSCustomObject
```

### Add-ConfluenceLabel Flow Diagram

```text
User calls Add-ConfluenceLabel -PageId '12345' -Label 'label1', 'label2'
    │
    ▼
Add-ConfluenceLabel
    │
    ├── Write-Verbose "Adding label(s) 'label1, label2' to page '12345'..."
    │
    ├── Build request body:
    │   └── [{ prefix: 'global', name: 'label1' }, { prefix: 'global', name: 'label2' }]
    │
    ├── ShouldProcess check
    │       │
    │       └── If WhatIf → return $null
    │
    ├── Invoke-ConfluenceRequest -Endpoint '/wiki/rest/api/content/12345/label' -Method POST -Body $json
    │       │
    │       └── Returns v1 API response (added labels)
    │
    └── Map response to PSCustomObject array and return
```

### Remove-ConfluenceLabel Flow Diagram

```text
User calls Remove-ConfluenceLabel -PageId '12345' -Label 'category/item'
    │
    ▼
Remove-ConfluenceLabel
    │
    ├── Write-Verbose "Removing label 'category/item' from page '12345'..."
    │
    ├── Check if Label contains "/"
    │       │
    │       ├── YES → Use query param: /wiki/rest/api/content/12345/label?name=category%2Fitem
    │       │
    │       └── NO → Use path param: /wiki/rest/api/content/12345/label/simple-label
    │
    ├── ShouldProcess check
    │       │
    │       └── If WhatIf → return $null
    │
    ├── Invoke-ConfluenceRequest -Endpoint $endpoint -Method DELETE
    │       │
    │       └── Returns empty (204 No Content)
    │
    └── Return (no output on successful delete)
```

## Dev Agent Record

### Context Reference

<!-- Story context analysis completed by create-story workflow -->

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

- Fixed PowerShell parameter scope issue where `$label` foreach variable conflicted with `$Label` function parameter
- Changed Add-ConfluenceLabel.ps1 foreach variable from `$label` to `$item` to avoid scope conflict
- Fixed test assertion for empty array results using `@()` wrapper

### Completion Notes List

- Implemented Get-ConfluenceLabel using v1 API endpoint `/wiki/rest/api/content/{id}/label`
- Implemented Add-ConfluenceLabel with support for single and multiple labels in one API call
- Implemented Remove-ConfluenceLabel with intelligent path vs query param detection for labels containing "/"
- All three functions use Invoke-ConfluenceRequest internally for consistent auth/rate-limiting
- 66 new tests added for label operations (16 for Get, 24 for Add, 26 for Remove)
- All 320 module tests pass with no regressions
- PSScriptAnalyzer passes with no warnings on new functions
- Module now exports 20 functions total

**Code Review Fixes (2025-12-11):**

- Added `[OutputType([void])]` to Remove-ConfluenceLabel for consistency with Remove-ConfluencePage
- Added pipeline support to Remove-ConfluenceLabel with `ValueFromPipelineByPropertyName` and `[Alias('Name')]`
- Added `process {}` block to Remove-ConfluenceLabel for proper pipeline processing
- Added pipeline example to Remove-ConfluenceLabel help documentation
- Added 3 new tests for pipeline support (69 total tests for label operations)

### File List

**New Files:**
- Modules/ConfluenceAPI/Public/Get-ConfluenceLabel.ps1
- Modules/ConfluenceAPI/Public/Add-ConfluenceLabel.ps1
- Modules/ConfluenceAPI/Public/Remove-ConfluenceLabel.ps1
- Modules/ConfluenceAPI/Tests/Public/Get-ConfluenceLabel.Tests.ps1
- Modules/ConfluenceAPI/Tests/Public/Add-ConfluenceLabel.Tests.ps1
- Modules/ConfluenceAPI/Tests/Public/Remove-ConfluenceLabel.Tests.ps1

**Modified Files:**
- Modules/ConfluenceAPI/ConfluenceAPI.psd1 (added 3 new function exports)
- docs/sprint-artifacts/sprint-status.yaml (2-5-label-operations: in-progress → review)

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2025-12-11 | Story created via create-story workflow | Claude Opus 4.5 |
| 2025-12-11 | Implemented Get/Add/Remove-ConfluenceLabel with 66 tests, all passing | Claude Opus 4.5 |
| 2025-12-11 | Code review: Added OutputType, pipeline support, 3 new tests | Claude Opus 4.5 |
