# Story 2.6: CQL Search

Status: Done

## Story

As a **Technical Lead**,
I want **to search Confluence content using CQL queries**,
so that **I can find and manage pages programmatically across spaces for automation and reporting**.

## Acceptance Criteria

### AC1: Basic CQL Search
**Given** I want to search for pages using CQL
**When** I run `Search-Confluence -CQL "space = 'CONTOSO' AND type = page"`
**Then** matching results are returned with pagination support via GET to `/wiki/rest/api/search`
**And** results include: Id, Title, Type, SpaceKey, Url, Excerpt
**And** returns PSCustomObject array (empty array if no matches)
**And** `-Verbose` logs "Searching Confluence with CQL: space = 'CONTOSO' AND type = page"

### AC2: Search by Label
**Given** I want to search pages with a specific label
**When** I run `Search-Confluence -CQL "label = 'user-inventory'"`
**Then** all pages with that label are returned
**And** results follow the same property structure (Id, Title, Type, SpaceKey, Url, Excerpt)

### AC3: Text Search
**Given** I want to search for pages containing specific text
**When** I run `Search-Confluence -CQL "text ~ 'john smith'"`
**Then** pages containing the text are returned
**And** Excerpt property contains relevant context around the match

### AC4: Pagination with Limit Parameter
**Given** I want to limit search results
**When** I run `Search-Confluence -CQL "type = page" -Limit 50`
**Then** at most 50 results are returned
**And** pagination is handled automatically via cursor if more results exist

### AC5: Search with Expand Parameter
**Given** I want to include additional content in search results
**When** I run `Search-Confluence -CQL "space = 'TEST'" -Expand 'content.body.view'`
**Then** the expanded properties are included in the response
**And** `-Verbose` logs the expand parameter being used

### AC6: Error Handling
**Given** an operation fails
**When** an error occurs (invalid CQL syntax, permission denied, connection error)
**Then** a terminating error is thrown with actionable guidance (NFR20)
**And** invalid CQL syntax returns "Invalid CQL query" with details
**And** 403 errors return "Access denied" message
**And** generic errors include the CQL query for context

## Tasks / Subtasks

- [x] Task 1: Create Search-Confluence Function (AC: 1-6)
  - [x] Create `Public/Search-Confluence.ps1` file
  - [x] Implement `[CmdletBinding()]`
  - [x] Add `[OutputType([PSCustomObject[]])]`
  - [x] Add `-CQL` parameter (Mandatory, string) with validation
  - [x] Add `-Limit` parameter (Optional, int, default 0 for all results)
  - [x] Add `-Expand` parameter (Optional, string)
  - [x] Build endpoint: `/wiki/rest/api/search?cql={urlEncodedCQL}`
  - [x] URL-encode the CQL query string
  - [x] Handle expand parameter if provided
  - [x] Execute GET request via Invoke-ConfluenceRequest
  - [x] Map v1 API response to PSCustomObject array
  - [x] Return empty array `@()` if no results
  - [x] Add `Write-Verbose` for operation
  - [x] Handle 400 with "Invalid CQL query" error
  - [x] Handle 403 with "Access denied" error
  - [x] Handle generic errors with CQL context
  - [x] Add comment-based help with synopsis, description, examples

- [x] Task 2: Create Unit Tests for Search-Confluence (AC: 1-6)
  - [x] Create `Tests/Public/Search-Confluence.Tests.ps1`
  - [x] Test: Basic search returns results with expected properties
  - [x] Test: Search by label returns matching pages
  - [x] Test: Text search returns pages with excerpts
  - [x] Test: Empty results return empty array
  - [x] Test: Limit parameter restricts result count
  - [x] Test: Expand parameter is included in request
  - [x] Test: CQL is URL-encoded in request
  - [x] Test: Invalid CQL throws with "Invalid CQL query" message
  - [x] Test: 403 throws with "Access denied" message
  - [x] Test: Verbose output logs CQL query
  - [x] Test: Verbose output does not contain API token
  - [x] Test: Requires CQL parameter

- [x] Task 3: Update Module Manifest (AC: 1-6)
  - [x] Update `ConfluenceAPI.psd1` FunctionsToExport array
  - [x] Add: `'Search-Confluence'`
  - [x] Verify module loads with new function via `Test-ModuleManifest`

- [x] Task 4: Validate Implementation (AC: 1-6)
  - [x] Run `Invoke-ScriptAnalyzer -Path ./Modules/ConfluenceAPI/ -Recurse`
  - [x] Run all Pester tests
  - [x] Verify all existing tests still pass (regression check)

## Dev Notes

### Architecture Compliance

**Module Location:** `Modules/ConfluenceAPI/Public/`

Per architecture.md, Search-Confluence goes in `Public/` as it is a user-facing search operation. The function uses `Invoke-ConfluenceRequest` internally for API calls.

**Function Pattern:**
Follows established patterns from previous stories:
- `[CmdletBinding()]` (no ShouldProcess needed - read-only operation)
- `[OutputType([PSCustomObject[]])]` attribute
- Comment-based help
- `Write-Verbose` for operations
- `$PSCmdlet.ThrowTerminatingError()` for errors

### CRITICAL: CQL Search Uses V1 API

**API REQUIRES V1 ENDPOINT - NOT V2**

The Confluence Cloud REST API v2 does NOT have a search endpoint. CQL search MUST use the v1 REST API endpoint. According to [Atlassian community responses](https://community.atlassian.com/forums/Confluence-questions/Confluence-API-v1-versus-v2/qaq-p/2978171), there are no plans to deprecate the v1 search endpoint.

**Search Endpoint:** `GET /wiki/rest/api/search?cql={urlEncodedCQL}`

**Optional Parameters:**
- `cqlcontext` - JSON context for CQL query (space key, content ID)
- `cursor` - Pagination cursor (handled automatically by Invoke-ConfluenceRequest)
- `limit` - Maximum results per page (default 25, max varies by expansion)
- `expand` - Additional properties to include in response
- `includeArchivedSpaces` - Include archived space content (default false)
- `excludeCurrentSpaces` - Exclude current spaces (default false)
- `excerpt` - Excerpt strategy: indexed, highlight, none (default: highlight)

**Response Structure:**
```json
{
  "results": [
    {
      "content": {
        "id": "12345678",
        "type": "page",
        "status": "current",
        "title": "User Inventory",
        "space": {
          "key": "CONTOSO",
          "name": "Contoso Corp"
        },
        "_links": {
          "webui": "/spaces/CONTOSO/pages/12345678/User+Inventory"
        }
      },
      "title": "User Inventory",
      "excerpt": "...matching <b>text</b> context...",
      "url": "/spaces/CONTOSO/pages/12345678/User+Inventory",
      "resultGlobalContainer": {...},
      "lastModified": "2025-12-11T10:30:00.000Z"
    }
  ],
  "start": 0,
  "limit": 25,
  "size": 10,
  "cqlQuery": "space = 'CONTOSO' AND type = page",
  "_links": {
    "base": "https://mycompany.atlassian.net/wiki",
    "next": "/rest/api/search?cql=...&cursor=..."
  }
}
```

### CQL Syntax Reference

**Basic Syntax:** `field operator value`

**Common Fields:**
| Field | Description | Example |
|-------|-------------|---------|
| `space` | Space key | `space = 'CONTOSO'` |
| `type` | Content type (page, blogpost, comment, attachment) | `type = page` |
| `label` | Content labels | `label = 'user-inventory'` |
| `title` | Page title (exact or fuzzy) | `title ~ 'Inventory*'` |
| `text` | Full text search | `text ~ 'john smith'` |
| `creator` | Content creator | `creator = 'user123'` |
| `created` | Creation date | `created > 2025-01-01` |
| `lastModified` | Modification date | `lastModified > startOfMonth()` |
| `ancestor` | Parent content ID | `ancestor = 12345` |
| `parent` | Direct parent ID | `parent = 67890` |

**Operators:**
| Operator | Symbol | Usage |
|----------|--------|-------|
| Equals | `=` | Exact match |
| Not Equals | `!=` | Exclusion |
| Contains | `~` | Fuzzy text match |
| Does Not Contain | `!~` | Text exclusion |
| Greater Than | `>` | Range (dates/numbers) |
| Less Than | `<` | Range |
| IN | `IN` | Multiple values: `type IN (page, blogpost)` |
| NOT IN | `NOT IN` | Multiple exclusions |

**Logical Operators:**
- `AND` - Both conditions must match
- `OR` - Either condition matches
- `NOT` - Negate condition
- `ORDER BY` - Sort results: `ORDER BY created DESC`

**Functions:**
- `currentUser()` - Currently authenticated user
- `startOfDay()`, `endOfDay()` - Date functions
- `startOfMonth()`, `endOfMonth()`
- `startOfYear()`, `endOfYear()`

**Example CQL Queries:**
```cql
space = 'CONTOSO' AND type = page
label = 'user-inventory' AND type = page
text ~ 'john smith' AND space = 'CLIENTS'
creator = currentUser() AND created > startOfMonth()
title ~ 'Inventory*' ORDER BY lastModified DESC
type = page AND space IN ('CONTOSO', 'FABRIKAM', 'LITWARE')
```

### PSCustomObject Mapping

Map the v1 search response to simplified PSCustomObject:

```powershell
[PSCustomObject]@{
    Id       = $result.content.id
    Title    = $result.title
    Type     = $result.content.type
    SpaceKey = $result.content.space.key
    Url      = $result.url
    Excerpt  = $result.excerpt
}
```

**Note:** The `content` property contains the actual Confluence content object, while `title`, `excerpt`, and `url` are search-specific properties at the result level.

### URL Encoding for CQL

CQL queries MUST be URL-encoded before being sent as query parameters:

```powershell
$encodedCQL = [System.Uri]::EscapeDataString($CQL)
$endpoint = "/wiki/rest/api/search?cql=$encodedCQL"
```

**URL Encoding Examples:**
| Original CQL | Encoded |
|--------------|---------|
| `space = 'CONTOSO'` | `space%20%3D%20%27CONTOSO%27` |
| `label = 'user-inventory'` | `label%20%3D%20%27user-inventory%27` |

### Result Limits

Per [Atlassian support documentation](https://support.atlassian.com/confluence/kb/searching-for-content-with-the-rest-api-and-cql-always-limits-results-to-50/):
- Default limit: 25 results per page
- With `body` expansion: max 50 results
- Without `body` expansion: max 200 results (1000 for no expansions)
- Pagination via `cursor` parameter is required for large result sets

### Error Messages (NFR20 Compliance)

| Scenario | Error Message |
|----------|---------------|
| Invalid CQL syntax (400) | "Invalid CQL query: {API error detail}. Check CQL syntax." |
| Permission denied (403) | "Access denied to search. Check your API permissions." |
| Connection error | "Failed to search Confluence: {error message}. CQL: {query}" |

### Previous Story Intelligence (Story 2.5)

**Learnings Applied:**
- v1 API has different response structure than v2 - map appropriately
- Use `InModuleScope ConfluenceAPI { }` for tests with module variables
- `Should Be` (Pester 3.4 syntax, no hyphen)
- Error handling: Use `$PSCmdlet.ThrowTerminatingError()` with proper ErrorRecord
- Include query context in error messages for debugging
- URL-encode all query parameters containing special characters

**Testing Pattern from Story 2.5:**
- Mock `Invoke-ConfluenceRequest` in `InModuleScope`
- Add assertions to prevent PSScriptAnalyzer unused variable warnings
- Use `$null =` for results that intentionally aren't checked

### Project Structure Notes

**Files to Create:**
```text
Modules/ConfluenceAPI/
├── Public/
│   └── Search-Confluence.ps1      # CREATE
└── Tests/
    └── Public/
        └── Search-Confluence.Tests.ps1  # CREATE
```

**Module will export 21 functions after this story:**
- Epic 1 functions (7): New/Get/Remove-ConfluenceAPIKey, New/Get/Remove-ConfluenceBaseURL, Test-ConfluenceConnection
- Story 2.1 (1): Invoke-ConfluenceRequest
- Story 2.2 (4): Get/New/Set/Remove-ConfluenceSpace
- Story 2.3 (4): Get/New/Set/Remove-ConfluencePage
- Story 2.4 (1): Move-ConfluencePage
- Story 2.5 (3): Get/Add/Remove-ConfluenceLabel
- Story 2.6 (1): Search-Confluence

### References

- [Source: docs/architecture.md#Project-Structure-Boundaries] - Search function in Public/
- [Source: docs/architecture.md#Implementation-Patterns] - Naming and error patterns
- [Source: docs/project_context.md#Function-Structure] - CmdletBinding requirements
- [Source: docs/project_context.md#Error-Handling] - ThrowTerminatingError pattern
- [Source: docs/epics.md#Story-2.6] - Acceptance criteria
- [Source: docs/sprint-artifacts/2-5-label-operations.md] - Previous story patterns and v1 API learnings
- [Confluence v1 Search API](https://developer.atlassian.com/cloud/confluence/rest/v1/api-group-search/)
- [Advanced searching using CQL](https://developer.atlassian.com/cloud/confluence/advanced-searching-using-cql/)
- [REST API v2 CQL Discussion](https://community.developer.atlassian.com/t/rest-api-v2-cql-and-expand/68601)
- [Search Result Limits](https://support.atlassian.com/confluence/kb/searching-for-content-with-the-rest-api-and-cql-always-limits-results-to-50/)

### Common Mistakes to Avoid

1. **DO NOT** use v2 API for search - it doesn't exist, use v1 `/wiki/rest/api/search`
2. **DO NOT** forget to URL-encode the CQL query string
3. **DO NOT** use ShouldProcess - this is a read-only GET operation
4. **DO NOT** log API tokens in verbose output (NFR6)
5. **DO NOT** use `throw` directly - use `$PSCmdlet.ThrowTerminatingError()`
6. **DO NOT** return raw API response - map to PSCustomObject
7. **DO NOT** use Pester 4+ syntax in tests (`Should Be` not `Should -Be`)
8. **DO NOT** forget that search results have nested `content` property
9. **DO NOT** forget to return empty array `@()` when no results
10. **DO NOT** assume CQL is safe for URL - always URL-encode

### Search-Confluence Flow Diagram

```text
User calls Search-Confluence -CQL "space = 'CONTOSO' AND type = page" -Limit 100
    │
    ▼
Search-Confluence
    │
    ├── Validate CQL parameter (not empty)
    │
    ├── Write-Verbose "Searching Confluence with CQL: space = 'CONTOSO'..."
    │
    ├── URL-encode CQL: [System.Uri]::EscapeDataString($CQL)
    │       └── Result: "space%20%3D%20%27CONTOSO%27%20AND%20type%20%3D%20page"
    │
    ├── Build endpoint: /wiki/rest/api/search?cql={encoded}&limit={limit}
    │       └── If -Expand: add &expand={expand}
    │
    ├── Invoke-ConfluenceRequest -Endpoint $endpoint -Method GET
    │       │
    │       ├── (handles auth, rate limiting, pagination)
    │       │
    │       └── Returns v1 API search response
    │
    ├── Check if response.results is null or empty → return @()
    │
    ├── Map each result to PSCustomObject
    │   └── { Id, Title, Type, SpaceKey, Url, Excerpt }
    │
    └── Return array of PSCustomObject
```

### Error Handling Flow Diagram

```text
Error occurs in Search-Confluence
    │
    ├── Catch exception
    │
    ├── Extract error message from exception
    │
    ├── Check status code pattern in message:
    │   │
    │   ├── 400 / "Bad Request" / "invalid" / "CQL"
    │   │   └── Throw: "Invalid CQL query: {detail}. Check CQL syntax."
    │   │
    │   ├── 403 / "Forbidden" / "denied"
    │   │   └── Throw: "Access denied to search. Check your API permissions."
    │   │
    │   └── Other errors
    │       └── Throw: "Failed to search Confluence: {message}. CQL: {query}"
    │
    └── Use $PSCmdlet.ThrowTerminatingError() with ErrorRecord
```

## Dev Agent Record

### Context Reference

<!-- Story context analysis completed by create-story workflow -->

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

N/A - Clean implementation with no issues

### Completion Notes List

- Implemented Search-Confluence function using Confluence Cloud REST API v1 search endpoint
- Function supports CQL queries with URL encoding, optional Limit and Expand parameters
- Returns PSCustomObject array with Id, Title, Type, SpaceKey, Url, Excerpt properties
- Returns empty array when no results found
- Error handling for 400 (Invalid CQL), 403 (Access denied), and generic errors with CQL context
- 19 unit tests covering all acceptance criteria (basic search, label search, text search, empty results, limit, expand, URL encoding, error handling, verbose output, parameter validation)
- All 342 module tests pass with no regressions
- PSScriptAnalyzer shows no new warnings in Search-Confluence.ps1
- Module manifest updated and verified - 21 functions exported

### Senior Developer Review (AI)

**Reviewed:** 2025-12-12
**Reviewer:** Claude Opus 4.5 (code-review workflow)
**Outcome:** ✅ APPROVED (after fixes)

**Issues Found & Fixed:**

| Severity | Issue | Resolution |
|----------|-------|------------|
| HIGH | Mock/Reality Mismatch - `Invoke-ConfluenceRequest` returns array directly for paginated responses, but function expected wrapped `@{results=@(...)}` object. Would return empty array in production. | Fixed response handling to detect both array and wrapped object formats |
| MEDIUM | AC5 incomplete - Missing verbose logging for `-Expand` parameter | Added `Write-Verbose "Including expanded properties: $Expand"` |
| LOW | PSScriptAnalyzer informational - `OutputType` mismatch (claims PSCustomObject[], returns Object[]) | Acknowledged - PowerShell behavior, not actionable |

**Tests Added:**

- "Returns results when Invoke-ConfluenceRequest returns array directly (production behavior)"
- "Verbose output logs expand parameter when specified"

**Post-Fix Validation:**

- All 344 module tests pass (21 for Search-Confluence, +2 new tests)
- PSScriptAnalyzer: Only informational issue remains
- All ACs validated against implementation

### File List

**New Files:**
- Modules/ConfluenceAPI/Public/Search-Confluence.ps1
- Modules/ConfluenceAPI/Tests/Public/Search-Confluence.Tests.ps1

**Modified Files:**
- Modules/ConfluenceAPI/ConfluenceAPI.psd1 (added Search-Confluence to FunctionsToExport)
- docs/sprint-artifacts/sprint-status.yaml (2-6-cql-search: ready-for-dev → in-progress → review)
- docs/sprint-artifacts/2-6-cql-search.md (task checkboxes, status, completion notes)

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2025-12-11 | Story created via create-story workflow | Claude Opus 4.5 |
| 2025-12-11 | Implementation completed - Search-Confluence function, 19 tests, manifest updated | Claude Opus 4.5 |
| 2025-12-12 | Code review: Fixed HIGH (mock/reality mismatch) and MEDIUM (expand verbose) issues, added 2 tests | Claude Opus 4.5 |
