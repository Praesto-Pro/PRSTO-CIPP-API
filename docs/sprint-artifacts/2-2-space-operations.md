# Story 2.2: Space Operations

Status: done

## Story

As a **Technical Lead**,
I want **to create, read, update, and delete Confluence spaces**,
so that **I can manage client documentation spaces programmatically**.

## Acceptance Criteria

### AC1: Create Space
**Given** I want to create a new space
**When** I run `New-ConfluenceSpace -SpaceKey 'CONTOSO' -Name 'Contoso Corp' -Description 'Client documentation'`
**Then** the space is created via POST to `/wiki/api/v2/spaces`
**And** the function returns a PSCustomObject with Id, Key, Name, Status
**And** `-WhatIf` shows what would be created without making changes (NFR18)

### AC2: Get Single Space
**Given** I want to retrieve a space
**When** I run `Get-ConfluenceSpace -SpaceKey 'CONTOSO'`
**Then** the space details are returned as PSCustomObject
**And** if the space doesn't exist, a clear error is returned (404 handling)

### AC3: List All Spaces
**Given** I want to list all spaces
**When** I run `Get-ConfluenceSpace` without parameters
**Then** all spaces are returned using cursor-based pagination
**And** results are aggregated automatically via `Invoke-ConfluenceRequest`

### AC4: Update Space
**Given** I want to update a space
**When** I run `Set-ConfluenceSpace -SpaceKey 'CONTOSO' -Name 'Contoso Corporation'`
**Then** the space is updated via PUT request
**And** `-WhatIf` shows changes without applying them
**And** the updated space object is returned

### AC5: Delete Space
**Given** I want to delete a space
**When** I run `Remove-ConfluenceSpace -SpaceKey 'CONTOSO'`
**Then** `-Confirm` prompts for confirmation (ConfirmImpact = High)
**And** `-WhatIf` shows what would be deleted
**And** `-Force` skips confirmation prompt

### AC6: Verbose Logging
**Given** any space operation is performed
**When** `-Verbose` is used
**Then** the operation is logged in format: `Verb-ing space 'SpaceKey'...`
**And** the API token is NEVER logged (NFR6)

### AC7: Error Handling
**Given** an operation fails
**When** an error occurs (invalid key, permission denied, etc.)
**Then** a terminating error is thrown with actionable guidance (NFR20)
**And** error messages include the space key for context

## Tasks / Subtasks

- [ ] Task 1: Create Get-ConfluenceSpace Function (AC: 2, 3, 6, 7)
  - [ ] Create `Public/Get-ConfluenceSpace.ps1` file
  - [ ] Implement `[CmdletBinding()]` with `[OutputType([PSCustomObject], [PSCustomObject[]])]`
  - [ ] Add optional `-SpaceKey` parameter with `[ValidateNotNullOrEmpty()]`
  - [ ] If SpaceKey provided: GET `/wiki/api/v2/spaces/{id}` (lookup by key first)
  - [ ] If no SpaceKey: GET `/wiki/api/v2/spaces` (use pagination via Invoke-ConfluenceRequest)
  - [ ] Map response to PSCustomObject: Id, Key, Name, Type, Status, HomepageId
  - [ ] Add `Write-Verbose` for operations
  - [ ] Handle 404 with clear "Space not found" error
  - [ ] Add comment-based help with synopsis, description, examples

- [ ] Task 2: Create New-ConfluenceSpace Function (AC: 1, 6, 7)
  - [ ] Create `Public/New-ConfluenceSpace.ps1` file
  - [ ] Implement `[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]`
  - [ ] Add `[OutputType([PSCustomObject])]`
  - [ ] Parameters: `-SpaceKey` (Mandatory), `-Name` (Mandatory), `-Description`
  - [ ] Validate SpaceKey format (uppercase alphanumeric, max 255 chars)
  - [ ] Build ADF body for description if provided
  - [ ] POST to `/wiki/api/v2/spaces` with proper JSON body
  - [ ] Implement ShouldProcess check before API call
  - [ ] Map response to PSCustomObject: Id, Key, Name, Type, Status, HomepageId
  - [ ] Add `Write-Verbose` for operation
  - [ ] Add comment-based help

- [ ] Task 3: Create Set-ConfluenceSpace Function (AC: 4, 6, 7)
  - [ ] Create `Public/Set-ConfluenceSpace.ps1` file
  - [ ] Implement `[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]`
  - [ ] Add `[OutputType([PSCustomObject])]`
  - [ ] Parameters: `-SpaceKey` (Mandatory), `-Name`, `-Description`, `-HomepageId`
  - [ ] At least one update parameter required (validate)
  - [ ] Lookup space ID from SpaceKey first (API requires ID for PUT)
  - [ ] PUT to `/wiki/api/v2/spaces/{id}` with updated fields
  - [ ] Implement ShouldProcess check
  - [ ] Return updated space object
  - [ ] Add `Write-Verbose` for operation
  - [ ] Add comment-based help

- [ ] Task 4: Create Remove-ConfluenceSpace Function (AC: 5, 6, 7)
  - [ ] Create `Public/Remove-ConfluenceSpace.ps1` file
  - [ ] Implement `[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]`
  - [ ] Parameters: `-SpaceKey` (Mandatory), `-Force` switch
  - [ ] Lookup space ID from SpaceKey first
  - [ ] DELETE to `/wiki/api/v2/spaces/{id}`
  - [ ] Force parameter bypasses ShouldContinue
  - [ ] WhatIf shows "Would delete space 'CONTOSO'"
  - [ ] Return nothing on success (or success object)
  - [ ] Add `Write-Verbose` for operation
  - [ ] Add comment-based help

- [ ] Task 5: Create Unit Tests for Get-ConfluenceSpace (AC: 2, 3, 6, 7)
  - [ ] Create `Tests/Public/Get-ConfluenceSpace.Tests.ps1`
  - [ ] Test: Single space returns PSCustomObject with correct properties
  - [ ] Test: List all spaces returns array of PSCustomObjects
  - [ ] Test: Pagination is handled automatically
  - [ ] Test: 404 throws with "Space not found" message
  - [ ] Test: Verbose output does not contain token
  - [ ] Test: Properties mapped correctly (Id, Key, Name, Type, Status, HomepageId)

- [ ] Task 6: Create Unit Tests for New-ConfluenceSpace (AC: 1, 6, 7)
  - [ ] Create `Tests/Public/New-ConfluenceSpace.Tests.ps1`
  - [ ] Test: Creates space with required parameters
  - [ ] Test: Optional Description is included when provided
  - [ ] Test: WhatIf does not call API
  - [ ] Test: Returns PSCustomObject with correct properties
  - [ ] Test: Verbose logs operation
  - [ ] Test: Invalid SpaceKey format throws validation error

- [ ] Task 7: Create Unit Tests for Set-ConfluenceSpace (AC: 4, 6, 7)
  - [ ] Create `Tests/Public/Set-ConfluenceSpace.Tests.ps1`
  - [ ] Test: Updates space name
  - [ ] Test: Updates space description
  - [ ] Test: WhatIf does not call API
  - [ ] Test: Returns updated PSCustomObject
  - [ ] Test: Requires at least one update parameter
  - [ ] Test: Looks up space ID from key

- [ ] Task 8: Create Unit Tests for Remove-ConfluenceSpace (AC: 5, 6, 7)
  - [ ] Create `Tests/Public/Remove-ConfluenceSpace.Tests.ps1`
  - [ ] Test: Deletes space with confirmation
  - [ ] Test: WhatIf does not call API
  - [ ] Test: Force bypasses confirmation
  - [ ] Test: 404 throws with clear message
  - [ ] Test: Looks up space ID from key

- [ ] Task 9: Update Module Manifest (AC: 1-5)
  - [ ] Update `ConfluenceAPI.psd1` FunctionsToExport array
  - [ ] Add: `'Get-ConfluenceSpace'`, `'New-ConfluenceSpace'`, `'Set-ConfluenceSpace'`, `'Remove-ConfluenceSpace'`
  - [ ] Verify module loads with new functions via `Test-ModuleManifest`

- [ ] Task 10: Validate Implementation (AC: 1-7)
  - [ ] Run `Invoke-ScriptAnalyzer -Path ./Modules/ConfluenceAPI/ -Recurse`
  - [ ] Run all Pester tests
  - [ ] Verify all existing tests still pass (regression check)

## Dev Notes

### Architecture Compliance

**Module Location:** `Modules/ConfluenceAPI/Public/`

Per architecture.md, space operations functions go in `Public/` as they are user-facing CRUD operations. These functions will use `Invoke-ConfluenceRequest` internally for all API calls.

**Function Pattern:**
All functions follow the established patterns from Epic 1 and Story 2.1:
- `[CmdletBinding()]` with appropriate ShouldProcess/ConfirmImpact
- `[OutputType()]` attribute
- Comment-based help
- `Write-Verbose` for operations
- `$PSCmdlet.ThrowTerminatingError()` for errors

### Confluence API v2 Space Endpoints

**Base URL:** `/wiki/api/v2/spaces`

| Operation | Method | Endpoint | Notes |
|-----------|--------|----------|-------|
| List all | GET | `/wiki/api/v2/spaces` | Returns paginated list with cursor |
| Get by ID | GET | `/wiki/api/v2/spaces/{id}` | Returns single space |
| Get by Key | GET | `/wiki/api/v2/spaces?keys={key}` | Filter by key, returns array |
| Create | POST | `/wiki/api/v2/spaces` | Body: key, name, description |
| Update | PUT | `/wiki/api/v2/spaces/{id}` | Body: name, description, etc. |
| Delete | DELETE | `/wiki/api/v2/spaces/{id}` | Requires space ID |

**CRITICAL:** API v2 uses space `id` (numeric) for PUT/DELETE, NOT space `key`. Functions must look up ID from key first!

### Space Object Structure

**API Response (GET /spaces/{id}):**
```json
{
  "id": "123456",
  "key": "CONTOSO",
  "name": "Contoso Corp",
  "type": "global",
  "status": "current",
  "homepageId": "789012",
  "description": {
    "plain": { "value": "Client documentation" }
  },
  "_links": { ... }
}
```

**PSCustomObject Mapping:**
```powershell
[PSCustomObject]@{
    Id          = $response.id
    Key         = $response.key
    Name        = $response.name
    Type        = $response.type
    Status      = $response.status
    HomepageId  = $response.homepageId
    Description = $response.description.plain.value
}
```

### Create Space Request Body

```json
{
  "key": "CONTOSO",
  "name": "Contoso Corp",
  "description": {
    "representation": "plain",
    "value": "Client documentation"
  }
}
```

**Note:** Description is optional. If not provided, omit from body.

### Update Space Request Body

PUT requests require the space ID in the URL and only include fields to update:

```json
{
  "name": "Contoso Corporation",
  "description": {
    "representation": "plain",
    "value": "Updated description"
  }
}
```

### SpaceKey Validation

Confluence SpaceKey requirements:
- Must be UPPERCASE (will auto-convert lowercase to upper)
- Alphanumeric characters only (A-Z, 0-9)
- Maximum 255 characters
- No special characters or spaces

```powershell
[ValidatePattern('^[A-Z0-9]{1,255}$')]
[string]$SpaceKey
```

Consider: Auto-convert lowercase to uppercase with `$SpaceKey.ToUpper()` before validation.

### Error Messages (NFR20 Compliance)

| Scenario | Error Message |
|----------|---------------|
| Space not found | "Space with key 'CONTOSO' was not found. Verify the space key exists." |
| Permission denied | "Access denied to space 'CONTOSO'. Check your API permissions." |
| Key already exists | "Space key 'CONTOSO' already exists. Choose a unique key." |
| Invalid key format | "Space key 'con toso' is invalid. Use uppercase alphanumeric characters only." |

### Previous Story Intelligence (Story 2.1)

**Learnings Applied:**
- PS 5.1/7 exception handling: parse status from message string as fallback
- Pagination handled by `Invoke-ConfluenceRequest` - no need to implement in each function
- Mock scoping: use `InModuleScope ConfluenceAPI { }` for variable-dependent mocks
- Test patterns: `Should Be` (Pester 3.4 syntax), `Assert-MockCalled`
- OutputType can be array: `[PSCustomObject], [PSCustomObject[]]`

**Code Patterns from Story 2.1:**
```powershell
# Error handling pattern
$PSCmdlet.ThrowTerminatingError(
    [System.Management.Automation.ErrorRecord]::new(
        [System.Exception]::new("Space with key '$SpaceKey' was not found."),
        "SpaceNotFound",
        [System.Management.Automation.ErrorCategory]::ObjectNotFound,
        $SpaceKey
    )
)

# Verbose pattern
Write-Verbose "Getting space '$SpaceKey'..."

# ShouldProcess pattern
if ($PSCmdlet.ShouldProcess($SpaceKey, "Create Confluence space")) {
    # API call here
}
```

### Testing Pattern (Pester 3.4.0+ Compatible)

```powershell
#Requires -Modules Pester

Describe 'Get-ConfluenceSpace' {
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

    Context 'Get Single Space' {
        It 'Returns PSCustomObject with correct properties' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @{
                        results = @(@{
                            id = '123'
                            key = 'TEST'
                            name = 'Test Space'
                            type = 'global'
                            status = 'current'
                            homepageId = '456'
                        })
                    }
                }

                $result = Get-ConfluenceSpace -SpaceKey 'TEST'
                $result.Key | Should Be 'TEST'
                $result.Id | Should Be '123'
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
│   ├── Get-ConfluenceSpace.ps1     # CREATE
│   ├── New-ConfluenceSpace.ps1     # CREATE
│   ├── Set-ConfluenceSpace.ps1     # CREATE
│   └── Remove-ConfluenceSpace.ps1  # CREATE
└── Tests/
    └── Public/
        ├── Get-ConfluenceSpace.Tests.ps1     # CREATE
        ├── New-ConfluenceSpace.Tests.ps1     # CREATE
        ├── Set-ConfluenceSpace.Tests.ps1     # CREATE
        └── Remove-ConfluenceSpace.Tests.ps1  # CREATE
```

**Module will export 12 functions after this story:**
- Epic 1 functions (7): New/Get/Remove-ConfluenceAPIKey, New/Get/Remove-ConfluenceBaseURL, Test-ConfluenceConnection
- Story 2.1 (1): Invoke-ConfluenceRequest
- Story 2.2 (4): Get/New/Set/Remove-ConfluenceSpace

### References

- [Source: docs/architecture.md#Project-Structure-Boundaries] - Space functions in Public/
- [Source: docs/architecture.md#Implementation-Patterns] - Naming and WhatIf patterns
- [Source: docs/project_context.md#Function-Structure] - CmdletBinding requirements
- [Source: docs/project_context.md#Error-Handling] - ThrowTerminatingError pattern
- [Source: docs/epics.md#Story-2.2] - Acceptance criteria
- [Source: docs/sprint-artifacts/2-1-core-api-request-handler.md] - Previous story patterns
- [Confluence REST API v2 - Spaces](https://developer.atlassian.com/cloud/confluence/rest/v2/api-group-space/)

### Common Mistakes to Avoid

1. **DO NOT** use space key directly in PUT/DELETE URLs - must look up space ID first
2. **DO NOT** forget ShouldProcess for New/Set/Remove operations
3. **DO NOT** forget ConfirmImpact = 'High' for Remove-ConfluenceSpace
4. **DO NOT** log API tokens in verbose output (NFR6)
5. **DO NOT** use `throw` directly - use `$PSCmdlet.ThrowTerminatingError()`
6. **DO NOT** return raw API response - map to PSCustomObject
7. **DO NOT** forget to validate SpaceKey format
8. **DO NOT** hardcode URLs - use Invoke-ConfluenceRequest
9. **DO NOT** use Pester 4+ syntax in tests
10. **DO NOT** mock at wrong scope - use InModuleScope for module variables

### Space Operations Flow Diagram

```text
User calls Get-ConfluenceSpace -SpaceKey 'CONTOSO'
    │
    ▼
Get-ConfluenceSpace
    │
    ├── Write-Verbose "Getting space 'CONTOSO'..."
    │
    ├── Invoke-ConfluenceRequest -Endpoint '/wiki/api/v2/spaces?keys=CONTOSO' -Method GET
    │       │
    │       ├── (handles auth, rate limiting, errors)
    │       │
    │       └── Returns raw API response
    │
    ├── Check if results empty → ThrowTerminatingError "Space not found"
    │
    ├── Map response to PSCustomObject
    │
    └── Return PSCustomObject with: Id, Key, Name, Type, Status, HomepageId
```

## Dev Agent Record

### Context Reference

<!-- Story context analysis completed by create-story workflow -->

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2025-12-11 | Story created via create-story workflow | Claude Opus 4.5 |
