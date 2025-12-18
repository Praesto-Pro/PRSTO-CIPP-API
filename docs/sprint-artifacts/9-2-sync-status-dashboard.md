# Story 9.2: Sync Status Dashboard

Status: done

## Story

As a **Technical Lead**,
I want **to view sync status across all tenants at a glance**,
so that **I can quickly identify any issues and verify successful sync operations**.

## Acceptance Criteria

### AC1: All Tenants Status Retrieval (FR40)
**Given** sync operations have been executed for multiple tenants
**When** I run `Get-ConfluenceSyncStatus`
**Then** status for all tenants is returned
**And** each tenant shows: TenantId, SpaceKey, LastSyncTime, Status (Success/PartialFailure/Failed/Never), LastError (if any)

### AC2: Single Tenant Status Retrieval
**Given** I want status for a specific tenant
**When** I run `Get-ConfluenceSyncStatus -TenantId 'abc-123'`
**Then** detailed status for that tenant is returned
**And** includes: LastSyncTime, Status, Duration, SuccessCount, FailedCount, SkippedCount, UnchangedCount, ErrorCount
**And** includes: LastError message (if status is not Success)

### AC3: Status Summary Counts
**Given** sync status exists for multiple tenants
**When** I run `Get-ConfluenceSyncStatus`
**Then** the output includes a summary (accessible via property):
- TotalTenants: count of all tenants with sync history
- SuccessCount: tenants where last sync was Success
- PartialFailureCount: tenants where last sync was PartialFailure
- FailedCount: tenants where last sync was Failed

### AC4: Never Synced Detection
**Given** a tenant has a mapping but has never been synced
**When** I retrieve sync status for that tenant
**Then** the status shows "Never" with null LastSyncTime
**And** no error is shown (this is not an error condition)

### AC5: PSCustomObject Return Type
**Given** the architecture requires PSCustomObject returns
**When** sync status is retrieved
**Then** results are returned as PSCustomObject array
**And** each object has consistent property names matching established patterns

### AC6: Integration with Sync Logs
**Given** sync logs are created by Story 9.1 `Add-ConfluenceSyncLog`
**When** status is derived
**Then** `Get-ConfluenceSyncStatus` reads from `$script:SyncLogCache` (Story 9.1)
**And** status is based on the most recent log entry per tenant

### AC7: Verbose Logging
**Given** I run `Get-ConfluenceSyncStatus -Verbose`
**When** status is retrieved
**Then** `Write-Verbose` logs the operation: "Retrieving sync status for X tenants"
**And** logs any tenants with issues: "Tenant 'abc-123' last sync: Failed"

## Tasks / Subtasks

- [x] Task 1: Create Get-ConfluenceSyncStatus Public Function (AC: 1, 2, 3, 4, 5, 6, 7)
  - [x] Create `Public/Get-ConfluenceSyncStatus.ps1`
  - [x] Add `[CmdletBinding()]` attribute
  - [x] Add `[OutputType([PSCustomObject[]])]` attribute
  - [x] Add `-TenantId` optional parameter for single tenant lookup
  - [x] Read from `$script:SyncLogCache` to get most recent log per tenant
  - [x] Return status objects with all required properties
  - [x] Calculate summary counts as a separate property or method
  - [x] Handle "Never" status for tenants with no sync history
  - [x] Add Write-Verbose logging throughout

- [x] Task 2: Create Unit Tests for Get-ConfluenceSyncStatus (AC: 1, 2, 3, 4, 5, 6, 7)
  - [x] Create `Tests/Public/Get-ConfluenceSyncStatus.Tests.ps1`
  - [x] Use Pester 3.4 syntax (`Should Be` without hyphen)
  - [x] Test: Returns all tenants when no filter
  - [x] Test: TenantId filter returns single tenant
  - [x] Test: TenantId filter returns null/empty for unknown tenant
  - [x] Test: Status derived from most recent log entry
  - [x] Test: "Never" status for tenants with no logs
  - [x] Test: Summary counts are accurate
  - [x] Test: Properties match expected names (TenantId, SpaceKey, etc.)
  - [x] Test: LastError populated from failed sync logs
  - [x] Test: Verbose logging output
  - [x] Test: Empty cache returns empty array

- [x] Task 3: Update Module Manifest (AC: 5)
  - [x] Add `Get-ConfluenceSyncStatus` to FunctionsToExport in ConfluenceAPI.psd1
  - [x] Place in "# Sync Logging (Epic 9)" section after existing functions

- [x] Task 4: Run Validation
  - [x] Run `Invoke-ScriptAnalyzer` on new file - 0 warnings expected
  - [x] Run all new Pester tests - verify all pass
  - [x] Run full regression tests - verify no breakage
  - [x] Verify integration with Get-ConfluenceSyncLog from Story 9.1

## Dev Notes

### Architecture Compliance

**Module Location:**
- `Modules/ConfluenceAPI/Public/Get-ConfluenceSyncStatus.ps1` - Main function

Per architecture.md:
- [Source: docs/architecture.md#Structure-Patterns] - Public/ for user-facing functions
- [Source: docs/architecture.md#Implementation-Patterns] - Return PSCustomObject
- [Source: docs/architecture.md#WhatIf-Verbose-Pattern] - Verbose logging pattern

### Dependencies (From Story 9.1)

- `$script:SyncLogCache` - In-memory cache containing sync log entries
- Log entry structure from `Add-ConfluenceSyncLog`:
  - LogId, Timestamp, TenantId, SpaceKey, Duration
  - OverallStatus, SuccessCount, FailedCount, SkippedCount, UnchangedCount, ErrorCount
  - SyncResults, Errors arrays

### Status Derivation Logic

The status is derived from the most recent sync log entry for each tenant:

```powershell
# Get most recent log per tenant
$latestLogs = $script:SyncLogCache.Values |
    Group-Object TenantId |
    ForEach-Object {
        $_.Group | Sort-Object Timestamp -Descending | Select-Object -First 1
    }

# Map OverallStatus to dashboard status
# OverallStatus values from Story 8.1:
# - 'Success' → Status: 'Success'
# - 'PartialFailure' → Status: 'PartialFailure'
# - 'Failed' → Status: 'Failed'
```

### Return Object Structure

```powershell
# Individual tenant status (returned by Get-ConfluenceSyncStatus)
[PSCustomObject]@{
    TenantId         = $log.TenantId
    SpaceKey         = $log.SpaceKey
    LastSyncTime     = $log.Timestamp      # null for "Never" synced
    Status           = $log.OverallStatus  # 'Success', 'PartialFailure', 'Failed', 'Never'
    Duration         = $log.Duration
    SuccessCount     = $log.SuccessCount
    FailedCount      = $log.FailedCount
    SkippedCount     = $log.SkippedCount
    UnchangedCount   = $log.UnchangedCount
    ErrorCount       = $log.ErrorCount
    LastError        = if ($log.Errors.Count -gt 0) { $log.Errors[0].Error } else { $null }
}

# Summary available via separate call or property
# Get-ConfluenceSyncStatus -Summary (alternative approach)
[PSCustomObject]@{
    TotalTenants         = $count
    SuccessCount         = $successCount
    PartialFailureCount  = $partialCount
    FailedCount          = $failedCount
}
```

### Function Pattern

```powershell
function Get-ConfluenceSyncStatus {
    <#
    .SYNOPSIS
        Retrieves sync status for tenants.
    .DESCRIPTION
        Returns sync status derived from the most recent sync log entry for each tenant.
        Status can be: Success, PartialFailure, Failed, or Never (if no sync has occurred).

        Note: Status is derived from in-memory sync logs which are cleared on module reload.
        For persistent status tracking, export Get-ConfluenceSyncLog results.
    .PARAMETER TenantId
        Filter to a specific tenant. If not specified, returns status for all tenants.
    .OUTPUTS
        [PSCustomObject[]] Array of status objects.
    .EXAMPLE
        Get-ConfluenceSyncStatus
        Returns sync status for all tenants.
    .EXAMPLE
        Get-ConfluenceSyncStatus -TenantId 'abc-123'
        Returns detailed sync status for tenant abc-123.
    .EXAMPLE
        Get-ConfluenceSyncStatus | Where-Object { $_.Status -ne 'Success' }
        Returns only tenants with sync issues.
    .LINK
        Get-ConfluenceSyncLog
    .LINK
        Sync-CIPPTenantToConfluence
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter()]
        [string]$TenantId
    )

    Write-Verbose "Retrieving sync status"

    # Check if sync logs exist
    if (-not $script:SyncLogCache -or $script:SyncLogCache.Count -eq 0) {
        Write-Verbose "No sync logs found - no status to report"
        return @()
    }

    # Get most recent log per tenant
    $latestLogs = $script:SyncLogCache.Values |
        Group-Object TenantId |
        ForEach-Object {
            $_.Group | Sort-Object Timestamp -Descending | Select-Object -First 1
        }

    Write-Verbose "Found status for $(@($latestLogs).Count) tenants"

    # Filter by TenantId if specified
    if ($TenantId) {
        Write-Verbose "Filtering for tenant '$TenantId'"
        $latestLogs = $latestLogs | Where-Object { $_.TenantId -eq $TenantId }

        if (-not $latestLogs) {
            Write-Verbose "No sync history found for tenant '$TenantId'"
            return @()
        }
    }

    # Convert to status objects
    $results = @($latestLogs | ForEach-Object {
        $lastError = $null
        if ($_.Errors -and @($_.Errors).Count -gt 0) {
            $lastError = $_.Errors[0].Error
        }

        # Log tenants with issues
        if ($_.OverallStatus -ne 'Success') {
            Write-Verbose "Tenant '$($_.TenantId)' last sync: $($_.OverallStatus)"
        }

        [PSCustomObject]@{
            TenantId       = $_.TenantId
            SpaceKey       = $_.SpaceKey
            LastSyncTime   = $_.Timestamp
            Status         = $_.OverallStatus
            Duration       = $_.Duration
            SuccessCount   = $_.SuccessCount
            FailedCount    = $_.FailedCount
            SkippedCount   = $_.SkippedCount
            UnchangedCount = $_.UnchangedCount
            ErrorCount     = $_.ErrorCount
            LastError      = $lastError
        }
    })

    return $results
}
```

### Testing Pattern (Pester 3.4 Compatible)

```powershell
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleRoot = Split-Path -Parent (Split-Path -Parent $here)
$publicDir = Join-Path $moduleRoot 'Public'

Describe 'Get-ConfluenceSyncStatus' {
    BeforeAll {
        . "$publicDir\Get-ConfluenceSyncStatus.ps1"
    }

    BeforeEach {
        # Reset cache for test isolation
        $script:SyncLogCache = @{}
    }

    Context 'Empty Cache' {
        It 'Returns empty array when no logs exist' {
            $result = Get-ConfluenceSyncStatus
            @($result).Count | Should Be 0
        }

        It 'Returns empty array for specific tenant with no logs' {
            $result = Get-ConfluenceSyncStatus -TenantId 'unknown'
            @($result).Count | Should Be 0
        }
    }

    Context 'With Logs' {
        BeforeEach {
            # Seed test data - multiple tenants with multiple logs
            $script:SyncLogCache = @{
                'log-1' = [PSCustomObject]@{
                    LogId = 'log-1'
                    Timestamp = '2025-12-17 10:00:00 UTC'
                    TenantId = 'tenant-a'
                    SpaceKey = 'SPACE-A'
                    Duration = '00:01:00'
                    OverallStatus = 'Success'
                    SuccessCount = 6
                    FailedCount = 0
                    SkippedCount = 0
                    UnchangedCount = 0
                    ErrorCount = 0
                    SyncResults = @()
                    Errors = @()
                }
                'log-2' = [PSCustomObject]@{
                    LogId = 'log-2'
                    Timestamp = '2025-12-17 11:00:00 UTC'
                    TenantId = 'tenant-a'  # Same tenant, newer
                    SpaceKey = 'SPACE-A'
                    Duration = '00:00:45'
                    OverallStatus = 'PartialFailure'
                    SuccessCount = 4
                    FailedCount = 2
                    SkippedCount = 0
                    UnchangedCount = 0
                    ErrorCount = 2
                    SyncResults = @()
                    Errors = @([PSCustomObject]@{ DataType = 'Users'; Error = 'Connection failed' })
                }
                'log-3' = [PSCustomObject]@{
                    LogId = 'log-3'
                    Timestamp = '2025-12-17 09:00:00 UTC'
                    TenantId = 'tenant-b'
                    SpaceKey = 'SPACE-B'
                    Duration = '00:02:00'
                    OverallStatus = 'Failed'
                    SuccessCount = 0
                    FailedCount = 6
                    SkippedCount = 0
                    UnchangedCount = 0
                    ErrorCount = 6
                    SyncResults = @()
                    Errors = @([PSCustomObject]@{ DataType = 'All'; Error = 'Space not found' })
                }
            }
        }

        It 'Returns status for all tenants' {
            $result = Get-ConfluenceSyncStatus
            @($result).Count | Should Be 2  # 2 unique tenants
        }

        It 'Uses most recent log per tenant' {
            $result = Get-ConfluenceSyncStatus | Where-Object { $_.TenantId -eq 'tenant-a' }
            $result.Status | Should Be 'PartialFailure'  # 11:00 log, not 10:00
            $result.LastSyncTime | Should Be '2025-12-17 11:00:00 UTC'
        }

        It 'Filters by TenantId' {
            $result = Get-ConfluenceSyncStatus -TenantId 'tenant-b'
            @($result).Count | Should Be 1
            $result.TenantId | Should Be 'tenant-b'
            $result.Status | Should Be 'Failed'
        }

        It 'Returns expected properties' {
            $result = Get-ConfluenceSyncStatus | Select-Object -First 1
            $result.PSObject.Properties.Name -contains 'TenantId' | Should Be $true
            $result.PSObject.Properties.Name -contains 'SpaceKey' | Should Be $true
            $result.PSObject.Properties.Name -contains 'LastSyncTime' | Should Be $true
            $result.PSObject.Properties.Name -contains 'Status' | Should Be $true
            $result.PSObject.Properties.Name -contains 'Duration' | Should Be $true
            $result.PSObject.Properties.Name -contains 'LastError' | Should Be $true
        }

        It 'Includes LastError from failed syncs' {
            $result = Get-ConfluenceSyncStatus -TenantId 'tenant-b'
            $result.LastError | Should Be 'Space not found'
        }

        It 'Has null LastError for successful syncs' {
            # Need a tenant with only successful sync
            $script:SyncLogCache = @{
                'success-log' = [PSCustomObject]@{
                    LogId = 'success-log'
                    Timestamp = '2025-12-17 12:00:00 UTC'
                    TenantId = 'good-tenant'
                    SpaceKey = 'GOOD'
                    Duration = '00:00:30'
                    OverallStatus = 'Success'
                    SuccessCount = 6
                    FailedCount = 0
                    SkippedCount = 0
                    UnchangedCount = 0
                    ErrorCount = 0
                    SyncResults = @()
                    Errors = @()
                }
            }
            $result = Get-ConfluenceSyncStatus
            $result.LastError | Should BeNullOrEmpty
        }
    }
}
```

### Previous Story Intelligence (Story 9.1 Learnings)

**Key Learnings to Apply:**

1. **Pester 3.4 Syntax (CRITICAL):**
   - Use `Should Be` (no hyphen) for Windows PS 5.1 compatibility
   - Use `Should BeNullOrEmpty` for null/empty checks
   - Use `($result.PSObject.Properties.Name -contains 'Prop') | Should Be $true` for property checks

2. **Script-Scoped Cache Pattern:**
   - Read from `$script:SyncLogCache` (populated by Story 9.1 Add-ConfluenceSyncLog)
   - This is a READ-ONLY function - does not modify cache
   - Reset cache in BeforeEach for test isolation

3. **PS 5.1 Array Compatibility:**
   - Use `@($result).Count` to ensure array for .Count operation
   - Use `@($array | Where-Object {...}).Count` pattern

4. **Error Array Access:**
   - Check `$_.Errors -and @($_.Errors).Count -gt 0` before accessing
   - Use `$_.Errors[0].Error` for first error message

5. **Group-Object for Aggregation:**
   - Use `Group-Object TenantId` to group logs by tenant
   - Select most recent from each group with `Sort-Object Timestamp -Descending | Select-Object -First 1`

### Common Mistakes to Avoid

1. **DO NOT** use `Should -Be` syntax - use Pester 3.4 `Should Be` (no hyphen)
2. **DO NOT** modify `$script:SyncLogCache` - this is a read-only function
3. **DO NOT** return raw log entries - create new status PSCustomObjects
4. **DO NOT** forget to handle empty cache case
5. **DO NOT** forget `@()` wrapper when checking array count
6. **DO NOT** use `throw` - use `$PSCmdlet.ThrowTerminatingError()` if errors needed
7. **DO NOT** forget Write-Verbose logging throughout

### Performance Considerations

- Uses in-memory cache only (fast)
- Group-Object with Sort for most-recent-per-tenant is O(n log n)
- Acceptable for typical tenant counts (<1000)
- Could add `-Last` parameter if needed for large deployments

### Git Commit Pattern

```
feat: implement Story 9.2 Sync Status Dashboard

- Add Get-ConfluenceSyncStatus public function
- Derive status from most recent sync log per tenant
- Create XX unit tests (all passing)
- PSScriptAnalyzer: 0 warnings

Story covers FR40 (view sync status)
```

### Project Structure Notes

**Files to Create:**
```text
Modules/ConfluenceAPI/
├── Public/
│   └── Get-ConfluenceSyncStatus.ps1          # CREATE
└── Tests/
    └── Public/
        └── Get-ConfluenceSyncStatus.Tests.ps1 # CREATE
```

**Files to Modify:**
```text
Modules/ConfluenceAPI/ConfluenceAPI.psd1  # MODIFY (export new function)
```

### References

- [Source: docs/architecture.md#Structure-Patterns] - Public/ for user-facing
- [Source: docs/architecture.md#Implementation-Patterns] - Return PSCustomObject
- [Source: docs/epics.md#Story-9.2] - FR40 requirements
- [Source: docs/sprint-artifacts/9-1-sync-execution-logging.md] - SyncLogCache structure
- [Source: docs/project_context.md] - Pester 3.4 syntax, error handling patterns

### FRs Covered

- **FR40**: Technical Lead can view sync success/failure status per tenant - primary

### Integration with Other Stories

**From Story 9.1:**
- Reads `$script:SyncLogCache` populated by `Add-ConfluenceSyncLog`
- Log entry structure defines available data for status derivation

**For Story 9.3 (Error Reporting):**
- `Get-ConfluenceSyncStatus` provides quick overview
- `Get-ConfluenceSyncError` (Story 9.3) will provide detailed error drill-down

**Relationship to Get-ConfluenceSyncLog:**
- `Get-ConfluenceSyncLog` - Returns raw log history (multiple entries per tenant)
- `Get-ConfluenceSyncStatus` - Returns current status (most recent entry per tenant)

## Dev Agent Record

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

None required - implementation followed story patterns.

### Completion Notes List

- Implemented `Get-ConfluenceSyncStatus` public function following the pattern in Dev Notes
- Function derives status from most recent sync log per tenant using Group-Object
- Returns PSCustomObject array with all required properties (TenantId, SpaceKey, LastSyncTime, Status, Duration, counts, LastError)
- **Code Review Fixes Applied:**
  - Added `-Summary` switch parameter for AC3 summary counts
  - Added `-IncludeNeverSynced` switch parameter for AC4 "Never" status
  - Summary returns: TotalTenants, SuccessCount, PartialFailureCount, FailedCount, NeverSyncedCount
  - IncludeNeverSynced calls Get-ConfluenceTenantMapping to find unmapped tenants
- Created 78 comprehensive unit tests covering all ACs:
  - Empty cache handling
  - Basic status retrieval with property validation
  - Multiple tenants handling
  - Most recent log per tenant selection
  - TenantId filter functionality
  - Error handling (LastError from failed syncs)
  - Partial failure status
  - Null/empty Errors array handling
  - Verbose output logging
  - PSCustomObject return type with pipeline compatibility
  - Large dataset performance (100 tenants with 5 logs each)
  - **Summary parameter tests (AC3)**: 12 tests for summary counts
  - **Never Synced tests (AC4)**: 17 tests for IncludeNeverSynced functionality
- PSScriptAnalyzer: 0 warnings
- All 78 tests pass
- Module manifest updated with new function export

### File List

**Created:**
- Modules/ConfluenceAPI/Public/Get-ConfluenceSyncStatus.ps1
- Modules/ConfluenceAPI/Tests/Public/Get-ConfluenceSyncStatus.Tests.ps1

**Modified:**
- Modules/ConfluenceAPI/ConfluenceAPI.psd1 (added Get-ConfluenceSyncStatus to exports)
- docs/sprint-artifacts/sprint-status.yaml (status: review)
- docs/sprint-artifacts/9-2-sync-status-dashboard.md (this file - code review fixes)

### Change Log

- 2025-12-17: Story 9.2 implementation completed - Get-ConfluenceSyncStatus function with 49 tests
- 2025-12-17: Code review fixes applied:
  - Added `-Summary` parameter for AC3 (summary counts: TotalTenants, SuccessCount, PartialFailureCount, FailedCount, NeverSyncedCount)
  - Added `-IncludeNeverSynced` parameter for AC4 (tenants with mappings but no sync history get Status='Never')
  - Added 29 new tests for Summary and Never Synced functionality
  - Total tests: 78 (all passing)
  - PSScriptAnalyzer: 0 warnings
