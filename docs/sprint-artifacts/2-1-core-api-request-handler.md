# Story 2.1: Core API Request Handler

Status: done

## Story

As a **Technical Lead**,
I want **a centralized API request handler with rate limiting and retry logic**,
so that **all Confluence operations are reliable and respect API limits**.

## Acceptance Criteria

### AC1: Basic API Request
**Given** valid credentials are configured
**When** I call `Invoke-ConfluenceRequest -Endpoint '/wiki/api/v2/spaces' -Method GET`
**Then** the request is sent with proper Basic Auth headers
**And** the response is returned as PSCustomObject (not raw JSON)
**And** `Write-Verbose` logs the endpoint being called

### AC2: Rate Limiting - Retry-After Header
**Given** the API returns a 429 rate limit response
**When** a request is made
**Then** the function reads the `Retry-After` header
**And** waits the specified time before retrying
**And** retries up to 3 times with exponential backoff (NFR10)
**And** `Write-Verbose` logs "Rate limited. Waiting X seconds before retry"

### AC3: Transient Failure Retry
**Given** a transient failure occurs (5xx error)
**When** a request is made
**Then** the function retries up to 3 times
**And** uses exponential backoff (1s, 2s, 4s delays)
**And** logs each retry attempt with `Write-Verbose`
**And** throws terminating error after all retries exhausted

### AC4: Cursor-Based Pagination
**Given** pagination is needed
**When** the response includes `_links.next` cursor
**Then** the function can follow cursor-based pagination (NFR15)
**And** aggregates all results into single response
**And** respects optional `-Limit` parameter to cap results

### AC5: HTTP Method Support
**Given** I need to make different types of requests
**When** I specify `-Method GET`, `POST`, `PUT`, or `DELETE`
**Then** the appropriate HTTP method is used
**And** POST/PUT requests accept `-Body` parameter for JSON payload

### AC6: WhatIf Support for Write Operations
**Given** I call a write operation (POST, PUT, DELETE)
**When** I use `-WhatIf`
**Then** the function shows what would be called without making the request
**And** returns $null without side effects

### AC7: Error Handling with Actionable Messages
**Given** an API error occurs
**When** the error is non-retryable (400, 401, 403, 404)
**Then** a terminating error is thrown immediately (no retry)
**And** the error message includes the HTTP status and actionable guidance
**And** 401 -> "Authentication failed. Verify API key."
**And** 403 -> "Access forbidden. Check permissions."
**And** 404 -> "Resource not found. Verify endpoint or ID."

### AC8: Token Security
**Given** any request is made
**When** verbose logging or error handling occurs
**Then** the API token is NEVER logged or exposed (NFR6)
**And** only the endpoint URL (without auth) is shown in verbose output

## Tasks / Subtasks

- [x] Task 1: Create Invoke-ConfluenceRequest Function (AC: 1, 5, 6, 7, 8)
  - [x] Create `Public/Invoke-ConfluenceRequest.ps1` file
  - [x] Implement `[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]`
  - [x] Add `[OutputType([PSCustomObject])]` attribute
  - [x] Add parameters: `-Endpoint`, `-Method`, `-Body`, `-Limit`
  - [x] Validate credentials before request (`$script:ConfluenceAPIKey`, `$script:ConfluenceBaseURL`)
  - [x] Build full URL from base URL + endpoint
  - [x] Construct Basic Auth header (`:token` format from Story 1.4)
  - [x] Implement ShouldProcess for POST/PUT/DELETE methods
  - [x] Convert response JSON to PSCustomObject
  - [x] Add comment-based help with synopsis, description, examples

- [x] Task 2: Implement Rate Limiting Handler (AC: 2)
  - [x] Create `Private/Get-RateLimitDelay.ps1` helper function
  - [x] Parse `Retry-After` header from 429 responses
  - [x] Return delay in seconds (default to 5s if header missing)
  - [x] Log rate limit events with Write-Verbose

- [x] Task 3: Implement Retry Logic (AC: 2, 3)
  - [x] Create retry loop in Invoke-ConfluenceRequest
  - [x] Implement exponential backoff: 1s, 2s, 4s base delays
  - [x] Use Retry-After header when available (overrides backoff)
  - [x] Retry on: 429, 5xx errors
  - [x] Do NOT retry on: 400, 401, 403, 404 (immediate fail)
  - [x] Maximum 3 retry attempts
  - [x] Log each retry attempt with Write-Verbose

- [x] Task 4: Implement Pagination Support (AC: 4)
  - [x] Check response for `_links.next` property
  - [x] Extract cursor parameter from next link
  - [x] Make follow-up requests until no more pages
  - [x] Aggregate `results` arrays across all pages
  - [x] Respect `-Limit` parameter to cap total results
  - [x] Log pagination progress with Write-Verbose

- [x] Task 5: Implement Error Handling (AC: 7, 8)
  - [x] Map HTTP status codes to user-friendly messages
  - [x] Use `$PSCmdlet.ThrowTerminatingError()` for failures
  - [x] Include endpoint in error message (not token!)
  - [x] Include actionable troubleshooting guidance (NFR20)
  - [x] Ensure PS 5.1 and PS 7 exception compatibility

- [x] Task 6: Create Unit Tests (AC: 1-8)
  - [x] Create `Tests/Public/Invoke-ConfluenceRequest.Tests.ps1`
  - [x] Test: GET request returns PSCustomObject
  - [x] Test: POST request with Body sends JSON
  - [x] Test: Proper Authorization header sent
  - [x] Test: Verbose logs endpoint (not token)
  - [x] Test: 429 response triggers retry with delay
  - [x] Test: 5xx response triggers retry with backoff
  - [x] Test: 401 response throws immediately (no retry)
  - [x] Test: 403 response throws with permission message
  - [x] Test: 404 response throws with resource not found
  - [x] Test: Pagination aggregates multiple pages
  - [x] Test: WhatIf does not make actual request
  - [x] Test: Throws after 3 retries exhausted

- [x] Task 7: Update Module Manifest (AC: 1)
  - [x] Update `ConfluenceAPI.psd1` FunctionsToExport array
  - [x] Add: `'Invoke-ConfluenceRequest'`
  - [x] Verify module loads with new function via `Test-ModuleManifest`

- [x] Task 8: Validate Implementation (AC: 1-8)
  - [x] Run `Invoke-ScriptAnalyzer -Path ./Modules/ConfluenceAPI/ -Recurse`
  - [x] Run all Pester tests
  - [x] Manual verification with actual Confluence credentials (optional)

## Dev Notes

### Architecture Compliance

**Module Location:** `Modules/ConfluenceAPI/Public/`

Per architecture.md, `Invoke-ConfluenceRequest` is explicitly PUBLIC (matches HuduAPI's `Invoke-HuduRequest` pattern). This is the foundational API wrapper that ALL other API functions will use.

**Why Public?**
- Allows advanced users to make direct API calls
- Enables debugging and troubleshooting
- Matches HuduAPI convention for ecosystem consistency
- Called by: `Get-ConfluenceSpace`, `New-ConfluencePage`, `Search-Confluence`, etc.

### Technical Implementation

**URL Construction:**
```powershell
# Base URL already includes /wiki if needed
# Endpoint should start with /wiki/api/v2/
$fullUrl = "$script:ConfluenceBaseURL$Endpoint"

# Example:
# BaseURL: https://mycompany.atlassian.net
# Endpoint: /wiki/api/v2/spaces
# Result: https://mycompany.atlassian.net/wiki/api/v2/spaces
```

**Important:** Support BOTH URL formats from architecture.md:
- Standard: `https://{domain}.atlassian.net/wiki/api/v2/...`
- Service Account: `https://api.atlassian.com/ex/confluence/{cloudId}/wiki/api/v2/...`

The `$script:ConfluenceBaseURL` handles this - endpoint is always appended directly.

**Authentication Header (from Story 1.4):**
```powershell
# Token-only Basic Auth with empty username
$base64Auth = [System.Convert]::ToBase64String(
    [System.Text.Encoding]::ASCII.GetBytes(":$($script:ConfluenceAPIKey)")
)
$headers = @{
    "Authorization" = "Basic $base64Auth"
    "Accept"        = "application/json"
    "Content-Type"  = "application/json"  # For POST/PUT
}
```

**Rate Limiting (Confluence API Behavior):**
- Confluence returns `429 Too Many Requests` when rate limited
- `Retry-After` header specifies wait time in seconds
- If header missing, default to 5 second wait
- NFR3 requires "graceful backoff"

**Exponential Backoff Pattern:**
```powershell
$retryCount = 0
$maxRetries = 3
$baseDelay = 1  # seconds

while ($retryCount -lt $maxRetries) {
    try {
        $response = Invoke-RestMethod ...
        return $response
    }
    catch {
        $statusCode = Extract-StatusCode $_

        # Check if retryable
        if ($statusCode -eq 429) {
            $delay = Get-RateLimitDelay -Response $_.Exception.Response
        }
        elseif ($statusCode -ge 500) {
            $delay = [math]::Pow(2, $retryCount) * $baseDelay  # 1, 2, 4 seconds
        }
        else {
            # Non-retryable - throw immediately
            throw
        }

        Write-Verbose "Retry $($retryCount + 1) of $maxRetries after ${delay}s delay"
        Start-Sleep -Seconds $delay
        $retryCount++
    }
}
```

**Pagination (Confluence API v2):**
```powershell
# Confluence API v2 uses cursor-based pagination
# Response structure:
# {
#     "results": [...],
#     "_links": {
#         "next": "/wiki/api/v2/spaces?cursor=xyz123"
#     }
# }

# Follow pagination:
$allResults = @()
$cursor = $null

do {
    $endpoint = if ($cursor) { "$Endpoint?cursor=$cursor" } else { $Endpoint }
    $response = Make-Request -Endpoint $endpoint
    $allResults += $response.results

    # Extract cursor from next link
    if ($response._links.next) {
        $cursor = [System.Web.HttpUtility]::ParseQueryString(
            [Uri]::new($response._links.next).Query
        )['cursor']
    } else {
        $cursor = $null
    }
} while ($cursor -and ($allResults.Count -lt $Limit -or -not $Limit))
```

**CRITICAL: Do NOT use offset/limit pagination - API v2 uses cursors!**

**Error Response Format (Confluence API):**
```json
{
    "statusCode": 404,
    "message": "Space with key 'INVALID' was not found."
}
```

Parse this for better error messages when available.

### PowerShell Compatibility (PS 5.1 + PS 7)

**Exception Handling Differences:**
```powershell
# PS 5.1: System.Net.WebException
# PS 7: Microsoft.PowerShell.Commands.HttpResponseException

try {
    $response = Invoke-RestMethod -Uri $uri ...
}
catch {
    # Extract status code - handle both PowerShell versions
    $statusCode = $null

    if ($_.Exception.Response) {
        $statusCode = [int]$_.Exception.Response.StatusCode
    }

    # Fallback: Parse from exception message (PS 5.1 compatibility)
    if (-not $statusCode -and $_.Exception.Message) {
        if ($_.Exception.Message -match '\((\d{3})\)') {
            $statusCode = [int]$Matches[1]
        }
    }
}
```

**System.Web.HttpUtility (PS 5.1):**
- May not be loaded by default on PS 5.1
- Use `Add-Type -AssemblyName System.Web` if needed
- Or parse cursor manually from URL string

### Previous Story Intelligence

**Story 1.4 (Test-ConfluenceConnection) Learnings:**
- Token-only Basic Auth works (`:token` format)
- PS 5.1 exception handling requires parsing message string for status codes
- `Write-Verbose` used for connection status logging
- CloudId extraction from `_links.base` pattern
- Error messages mapped per AC6 spec

**Code Patterns Established:**
- `$PSCmdlet.ThrowTerminatingError()` for proper error handling
- Script-scoped credential variables: `$script:ConfluenceAPIKey`, `$script:ConfluenceBaseURL`
- Pester 3.4.0 syntax: `Should Be`, `Should Match`, `Should Throw`
- Mock scoping: `-ModuleName ConfluenceAPI`

### Testing Pattern (Pester 3.4.0+ Compatible)

```powershell
#Requires -Modules Pester

Describe 'Invoke-ConfluenceRequest' {
    BeforeAll {
        $ModulePath = (Get-Item "$PSScriptRoot\..\..\ConfluenceAPI.psd1").FullName
        Import-Module $ModulePath -Force
    }

    BeforeEach {
        Remove-ConfluenceAPIKey -ErrorAction SilentlyContinue
        Remove-ConfluenceBaseURL -ErrorAction SilentlyContinue
        New-ConfluenceAPIKey -ApiKey 'test-token'
        New-ConfluenceBaseURL -BaseURL 'https://test.atlassian.net'
    }

    AfterEach {
        Remove-ConfluenceAPIKey -ErrorAction SilentlyContinue
        Remove-ConfluenceBaseURL -ErrorAction SilentlyContinue
    }

    Context 'Basic Request' {
        It 'Returns PSCustomObject on success' {
            Mock Invoke-RestMethod {
                @{ id = '123'; name = 'Test' }
            } -ModuleName ConfluenceAPI

            $result = Invoke-ConfluenceRequest -Endpoint '/wiki/api/v2/spaces/TEST'
            $result | Should BeOfType 'PSCustomObject'
        }

        It 'Sends Authorization header' {
            Mock Invoke-RestMethod {
                @{ id = '123' }
            } -ModuleName ConfluenceAPI

            Invoke-ConfluenceRequest -Endpoint '/wiki/api/v2/spaces/TEST'

            Assert-MockCalled Invoke-RestMethod -ModuleName ConfluenceAPI -ParameterFilter {
                $Headers -and $Headers.ContainsKey('Authorization')
            }
        }
    }

    Context 'Rate Limiting' {
        It 'Retries on 429 with Retry-After delay' {
            $callCount = 0
            Mock Invoke-RestMethod {
                $callCount++
                if ($callCount -eq 1) {
                    throw [System.Net.WebException]::new('429 Too Many Requests')
                }
                @{ id = '123' }
            } -ModuleName ConfluenceAPI

            Mock Start-Sleep {} -ModuleName ConfluenceAPI

            $result = Invoke-ConfluenceRequest -Endpoint '/wiki/api/v2/spaces'
            $result.id | Should Be '123'
        }
    }

    Context 'Error Handling' {
        It 'Throws immediately on 401' {
            Mock Invoke-RestMethod {
                throw [System.Net.WebException]::new('401 Unauthorized')
            } -ModuleName ConfluenceAPI

            { Invoke-ConfluenceRequest -Endpoint '/wiki/api/v2/spaces' } | Should Throw
        }

        It 'Error message includes actionable guidance for 401' {
            Mock Invoke-RestMethod {
                throw [System.Net.WebException]::new('401 Unauthorized')
            } -ModuleName ConfluenceAPI

            $errorThrown = $null
            try {
                Invoke-ConfluenceRequest -Endpoint '/wiki/api/v2/spaces'
            } catch {
                $errorThrown = $_.Exception.Message
            }
            $errorThrown | Should Match 'Authentication|API key'
        }
    }

    Context 'Pagination' {
        It 'Aggregates results across multiple pages' {
            $callCount = 0
            Mock Invoke-RestMethod {
                $callCount++
                if ($callCount -eq 1) {
                    @{
                        results = @(@{ id = '1' }, @{ id = '2' })
                        _links = @{ next = '/wiki/api/v2/spaces?cursor=abc' }
                    }
                } else {
                    @{
                        results = @(@{ id = '3' })
                        _links = @{}
                    }
                }
            } -ModuleName ConfluenceAPI

            $result = Invoke-ConfluenceRequest -Endpoint '/wiki/api/v2/spaces'
            $result.Count | Should Be 3
        }
    }

    Context 'WhatIf Support' {
        It 'Does not make request when WhatIf used on POST' {
            Mock Invoke-RestMethod { } -ModuleName ConfluenceAPI

            Invoke-ConfluenceRequest -Endpoint '/wiki/api/v2/spaces' -Method POST -Body '{}' -WhatIf

            Assert-MockCalled Invoke-RestMethod -ModuleName ConfluenceAPI -Times 0
        }
    }
}
```

### Project Structure Notes

**Alignment with Module Structure:**
```text
Modules/ConfluenceAPI/
├── ConfluenceAPI.psd1          # Update FunctionsToExport
├── ConfluenceAPI.psm1          # Auto-loads Public/*.ps1
├── Public/
│   ├── New-ConfluenceAPIKey.ps1    # Existing (Epic 1)
│   ├── Get-ConfluenceAPIKey.ps1    # Existing (Epic 1)
│   ├── Remove-ConfluenceAPIKey.ps1 # Existing (Epic 1)
│   ├── New-ConfluenceBaseURL.ps1   # Existing (Epic 1)
│   ├── Get-ConfluenceBaseURL.ps1   # Existing (Epic 1)
│   ├── Remove-ConfluenceBaseURL.ps1# Existing (Epic 1)
│   ├── Test-ConfluenceConnection.ps1 # Existing (Epic 1)
│   └── Invoke-ConfluenceRequest.ps1  # CREATE
├── Private/
│   └── Get-RateLimitDelay.ps1    # CREATE (helper)
└── Tests/
    ├── Public/
    │   ├── ... (existing tests)
    │   └── Invoke-ConfluenceRequest.Tests.ps1 # CREATE
    └── Private/
        └── Get-RateLimitDelay.Tests.ps1 # CREATE
```

### References

- [Source: docs/architecture.md#API-Communication-Patterns] - Rate limiting, retry, pagination
- [Source: docs/architecture.md#Project-Structure-Boundaries] - Invoke-ConfluenceRequest in Public/
- [Source: docs/architecture.md#Error-Handling-Pattern] - ThrowTerminatingError example
- [Source: docs/project_context.md#API-Gotchas] - Cursor pagination, NOT offset/limit
- [Source: docs/project_context.md#Error-Handling] - ThrowTerminatingError pattern
- [Source: docs/epics.md#Story-2.1] - Acceptance criteria
- [Source: docs/prd.md#NFR3] - Graceful rate limiting backoff
- [Source: docs/prd.md#NFR10] - 3-retry with backoff
- [Source: docs/prd.md#NFR15] - Cursor-based pagination
- [Source: docs/prd.md#NFR6] - Token never logged
- [Source: docs/prd.md#NFR20] - Actionable error messages
- [Source: docs/sprint-artifacts/1-4-connection-validation.md] - Previous story patterns
- [Confluence REST API v2 Docs](https://developer.atlassian.com/cloud/confluence/rest/v2/intro/)
- [Confluence API Rate Limiting](https://developer.atlassian.com/cloud/confluence/rate-limiting/)

### Code Template

**Invoke-ConfluenceRequest.ps1:**
```powershell
function Invoke-ConfluenceRequest {
    <#
    .SYNOPSIS
        Makes authenticated requests to the Confluence REST API v2.
    .DESCRIPTION
        Central API wrapper for all Confluence operations. Handles authentication,
        rate limiting, retry logic, and pagination automatically.

        All other Confluence functions use this internally for API communication.
    .PARAMETER Endpoint
        The API endpoint path (e.g., '/wiki/api/v2/spaces')
    .PARAMETER Method
        HTTP method: GET, POST, PUT, DELETE (default: GET)
    .PARAMETER Body
        JSON body for POST/PUT requests
    .PARAMETER Limit
        Maximum number of results to return (for paginated endpoints)
    .EXAMPLE
        Invoke-ConfluenceRequest -Endpoint '/wiki/api/v2/spaces'

        Gets all spaces (with automatic pagination).
    .EXAMPLE
        Invoke-ConfluenceRequest -Endpoint '/wiki/api/v2/spaces' -Method POST -Body $jsonBody

        Creates a new space.
    .EXAMPLE
        Invoke-ConfluenceRequest -Endpoint '/wiki/api/v2/pages/12345' -Method DELETE -WhatIf

        Shows what would happen without actually deleting.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Endpoint,

        [Parameter()]
        [ValidateSet('GET', 'POST', 'PUT', 'DELETE')]
        [string]$Method = 'GET',

        [Parameter()]
        [string]$Body,

        [Parameter()]
        [int]$Limit
    )

    # Implementation follows...
}
```

**Get-RateLimitDelay.ps1 (Private):**
```powershell
function Get-RateLimitDelay {
    <#
    .SYNOPSIS
        Extracts delay seconds from rate limit response.
    .DESCRIPTION
        Parses the Retry-After header from a 429 response.
        Returns default delay if header not present.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter()]
        $Response,

        [Parameter()]
        [int]$DefaultDelay = 5
    )

    $delay = $DefaultDelay

    if ($Response -and $Response.Headers) {
        $retryAfter = $Response.Headers['Retry-After']
        if ($retryAfter) {
            if ([int]::TryParse($retryAfter, [ref]$delay)) {
                Write-Verbose "Retry-After header: $delay seconds"
            }
        }
    }

    return $delay
}
```

### Common Mistakes to Avoid

1. **DO NOT** use offset/limit pagination - Confluence API v2 uses cursor-based pagination only
2. **DO NOT** retry on 401, 403, 404 errors - these are non-retryable
3. **DO NOT** log or expose the API token in verbose output or errors (NFR6)
4. **DO NOT** use `throw` directly - use `$PSCmdlet.ThrowTerminatingError()`
5. **DO NOT** return raw JSON - always return PSCustomObject
6. **DO NOT** forget to handle both PS 5.1 and PS 7 exception types
7. **DO NOT** hardcode URLs - use `$script:ConfluenceBaseURL` + endpoint
8. **DO NOT** forget ShouldProcess for write operations (POST/PUT/DELETE)
9. **DO NOT** use Pester 4+ syntax - use Pester 3.4.0 compatible syntax
10. **DO NOT** forget to aggregate results across pagination pages

### Epic 2 Context

This is the **first story in Epic 2: Core API Operations**.

`Invoke-ConfluenceRequest` is the foundational function that ALL subsequent stories depend on:
- Story 2.2 (Space Operations) - uses this for space CRUD
- Story 2.3 (Page CRUD) - uses this for page operations
- Story 2.4 (Page Movement) - uses this for hierarchy changes
- Story 2.5 (Label Operations) - uses this for label management
- Story 2.6 (CQL Search) - uses this for search queries

Getting this function right is CRITICAL - all API reliability depends on proper rate limiting, retry logic, and error handling implemented here.

**Module will export 8 functions after this story:**
- Epic 1 functions (7): New/Get/Remove-ConfluenceAPIKey, New/Get/Remove-ConfluenceBaseURL, Test-ConfluenceConnection
- Epic 2 functions (1): Invoke-ConfluenceRequest

## Dev Agent Record

### Context Reference

<!-- Story context analysis completed by create-story workflow -->

### Agent Model Used

Claude Opus 4.5

### Debug Log References

- Fixed ScriptAnalyzer warnings: removed unused `$lastError` variable, replaced empty catch blocks
- Fixed Pester test scoping issues: moved variable-dependent mocks inside `InModuleScope` blocks for proper module boundary handling

### Completion Notes List

- All 8 acceptance criteria validated through comprehensive unit tests
- Cross-platform exception handling implemented for PS 5.1 and PS 7
- Rate limiting respects Retry-After header with 5s default fallback
- Exponential backoff: 1s, 2s, 4s delays for transient failures
- Cursor-based pagination aggregates results correctly
- Token security ensured - API key never logged in verbose output

### Code Review Fixes Applied

- **[HIGH] Pagination cursor URL building bug** - Fixed: always use original `$Endpoint` as base when appending cursor parameter
- **[HIGH] Missing 400 Bad Request test** - Added 2 tests for 400 error handling (no-retry + message validation)
- **[HIGH] OutputType contract violation** - Updated `[OutputType]` to `[PSCustomObject], [PSCustomObject[]]` to reflect actual return types
- **[MEDIUM] Empty array edge case** - Added test to verify behavior when API returns empty results
- **[MEDIUM] Limit parameter edge cases** - Added tests for `Limit 0` (disabled) and `Limit > total` scenarios

### File List

- `Modules/ConfluenceAPI/Public/Invoke-ConfluenceRequest.ps1` - Main API wrapper function
- `Modules/ConfluenceAPI/Private/Get-RateLimitDelay.ps1` - Rate limit helper function
- `Modules/ConfluenceAPI/Tests/Public/Invoke-ConfluenceRequest.Tests.ps1` - 38 comprehensive tests (5 added in review)
- `Modules/ConfluenceAPI/Tests/Private/Get-RateLimitDelay.Tests.ps1` - 6 unit tests
- `Modules/ConfluenceAPI/ConfluenceAPI.psd1` - Updated FunctionsToExport

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2025-12-11 | Story created via create-story workflow | Claude Opus 4.5 |
| 2025-12-11 | Implementation completed - all 112 tests passing | Claude Opus 4.5 |
| 2025-12-11 | Code review fixes applied - all 117 tests passing | Claude Opus 4.5 |
