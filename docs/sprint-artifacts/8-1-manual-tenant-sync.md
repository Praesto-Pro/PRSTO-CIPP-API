# Story 8.1: Manual Tenant Sync

Status: done

## Story

As a **Technical Lead**,
I want **to trigger a complete sync for a specific tenant**,
so that **I can update all documentation pages on demand without waiting for scheduled sync**.

## Acceptance Criteria

### AC1: Complete Tenant Sync Operation (FR34)
**Given** I have CIPP data for a tenant
**When** I run `Sync-CIPPTenantToConfluence -TenantId 'abc-123' -CIPPData $allData`
**Then** all 6 data types are synced to the tenant's Confluence space:
- User Inventory
- Endpoint Inventory
- License Report
- MFA Status Report
- Teams Inventory
- SharePoint Inventory
**And** each sync operation returns success/failure status

### AC2: Tenant-to-Space Resolution
**Given** a tenant ID is provided
**When** the sync operation begins
**Then** the function calls `Get-ConfluenceTenantMapping -TenantId` to resolve the SpaceKey
**And** if no mapping exists, a terminating error is thrown with guidance

### AC3: Verbose Logging (NFR19)
**Given** I want detailed operation logging
**When** I run the sync with `-Verbose`
**Then** verbose messages describe:
- Starting sync for tenant
- Resolving tenant to space mapping
- Progress for each data type (starting, completed, skipped, failed)
- Total sync summary at completion

### AC4: WhatIf Support (NFR18)
**Given** I want to preview sync operations
**When** I run `Sync-CIPPTenantToConfluence -TenantId 'abc-123' -CIPPData $data -WhatIf`
**Then** all pages that would be created/updated are shown
**And** no actual API calls are made

### AC5: Partial Failure Handling (FR37 related)
**Given** an error occurs during sync of one data type
**When** the sync operation continues
**Then** other data types continue syncing
**And** the failed data type is recorded with error details
**And** the final summary includes all errors

### AC6: Sync Results Summary
**Given** a sync operation completes (success or partial failure)
**When** the function returns
**Then** a PSCustomObject is returned with:
- TenantId
- SpaceKey
- StartTime, EndTime, Duration
- SyncResults (array of per-datatype results)
- OverallStatus (Success, PartialFailure, Failed)
- ErrorCount
- Errors (array of error details)

### AC7: Selective Data Type Sync
**Given** I only want to sync specific data types
**When** I run `Sync-CIPPTenantToConfluence -TenantId 'abc-123' -Users $users -Endpoints $endpoints`
**Then** only User Inventory and Endpoint Inventory are synced
**And** other data types are skipped
**And** verbose logs indicate which types were skipped

### AC8: Empty Data Handling
**Given** a data type parameter is provided but empty/null
**When** the sync runs
**Then** the sync function for that type is still called (to update with "no data" state)
**And** verbose logs indicate empty data being synced

## Tasks / Subtasks

- [x] Task 1: Create Sync-CIPPTenantToConfluence Public Function (AC: 1-8)
  - [x] Create `Public/Sync-CIPPTenantToConfluence.ps1` file
  - [x] Add `[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]`
  - [x] Add `[OutputType([PSCustomObject])]` for return type
  - [x] Add `-TenantId` parameter (mandatory string)
  - [x] Add `-Users` parameter (optional array - CIPP user data)
  - [x] Add `-Endpoints` parameter (optional array - CIPP endpoint data)
  - [x] Add `-Licenses` parameter (optional array - CIPP license data)
  - [x] Add `-MFAData` parameter (optional array - CIPP MFA status data)
  - [x] Add `-Teams` parameter (optional array - CIPP Teams data)
  - [x] Add `-SharePointSites` parameter (optional array - CIPP SharePoint data)
  - [x] Call `Get-ConfluenceTenantMapping -TenantId` to resolve SpaceKey
  - [x] If no mapping found, throw terminating error with guidance
  - [x] For each provided data type, call respective Sync function with try/catch
  - [x] Collect sync results and errors for each data type
  - [x] Implement `$PSCmdlet.ShouldProcess` for WhatIf support
  - [x] Add `Write-Verbose` logging throughout
  - [x] Return PSCustomObject with comprehensive sync summary
  - [x] Add comment-based help with examples

- [x] Task 2: Create Unit Tests for Sync-CIPPTenantToConfluence (AC: 1-8)
  - [x] Create `Tests/Public/Sync-CIPPTenantToConfluence.Tests.ps1`
  - [x] Test: Resolves tenant to space via Get-ConfluenceTenantMapping (AC2)
  - [x] Test: Throws error when no mapping exists (AC2)
  - [x] Test: Calls all 6 sync functions when all data provided (AC1)
  - [x] Test: Only calls sync functions for provided data types (AC7)
  - [x] Test: Continues on partial failure (AC5)
  - [x] Test: Returns PSCustomObject with expected properties (AC6)
  - [x] Test: Includes error details in result (AC5, AC6)
  - [x] Test: Does not call sync functions with WhatIf (AC4)
  - [x] Test: Writes verbose messages (AC3)
  - [x] Test: Handles empty data arrays (AC8)
  - [x] Test: Returns OverallStatus 'Success' when all succeed (AC6)
  - [x] Test: Returns OverallStatus 'PartialFailure' when some fail (AC5, AC6)
  - [x] Test: Returns OverallStatus 'Failed' when mapping not found (AC2)

- [x] Task 3: Run Validation (AC: 1-8)
  - [x] Run `Invoke-ScriptAnalyzer` on new function - 0 warnings
  - [x] Run all new Pester tests - all passing (44 tests)
  - [x] Verify all existing tests still pass (full regression: 1182 tests)
  - [x] Verify module loads correctly after adding new function

## Dev Notes

### Architecture Compliance

**Module Location:**
- `Modules/ConfluenceAPI/Public/Sync-CIPPTenantToConfluence.ps1` - Main orchestration function

Per architecture.md, sync orchestration functions go in Public/:
- [Source: docs/architecture.md#Project-Structure-Boundaries]
- [Source: docs/epics.md#Story-8.1] - FR34 manual sync requirement

**Dependencies (All Exist):**
- `Get-ConfluenceTenantMapping` (Story 7.2) - resolve TenantId to SpaceKey
- `Sync-ConfluenceUserInventory` (Story 4.2) - user data sync
- `Sync-ConfluenceEndpointInventory` (Story 5.2) - endpoint data sync
- `Sync-ConfluenceLicenseReport` (Story 5.4) - license data sync
- `Sync-ConfluenceMFAReport` (Story 6.1) - MFA data sync
- `Sync-ConfluenceTeamsInventory` (Story 6.2) - Teams data sync
- `Sync-ConfluenceSharePointInventory` (Story 6.3) - SharePoint data sync

### Sync-CIPPTenantToConfluence Function Pattern

```powershell
function Sync-CIPPTenantToConfluence {
    <#
    .SYNOPSIS
        Syncs all CIPP data for a tenant to their Confluence space.
    .DESCRIPTION
        Orchestrates the sync of all 6 data types (Users, Endpoints, Licenses,
        MFA, Teams, SharePoint) for a specific tenant to their mapped Confluence
        space. Continues on partial failures and reports comprehensive results.
    .PARAMETER TenantId
        The CIPP tenant ID to sync. Required.
    .PARAMETER Users
        Array of user data objects from CIPP.
    .PARAMETER Endpoints
        Array of endpoint data objects from CIPP.
    .PARAMETER Licenses
        Array of license data objects from CIPP.
    .PARAMETER MFAData
        Array of MFA status data objects from CIPP.
    .PARAMETER Teams
        Array of Teams data objects from CIPP.
    .PARAMETER SharePointSites
        Array of SharePoint site data objects from CIPP.
    .OUTPUTS
        [PSCustomObject] Comprehensive sync result with status per data type.
    .EXAMPLE
        $result = Sync-CIPPTenantToConfluence -TenantId 'abc-123' -Users $users -Endpoints $endpoints
        Syncs only user and endpoint data for the tenant.
    .EXAMPLE
        Sync-CIPPTenantToConfluence -TenantId 'abc-123' -Users $u -Endpoints $e -Licenses $l -MFAData $m -Teams $t -SharePointSites $s
        Syncs all data types for the tenant.
    .EXAMPLE
        Sync-CIPPTenantToConfluence -TenantId 'abc-123' -Users $users -WhatIf
        Shows what would be synced without making changes.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$TenantId,

        [Parameter()]
        [array]$Users,

        [Parameter()]
        [array]$Endpoints,

        [Parameter()]
        [array]$Licenses,

        [Parameter()]
        [array]$MFAData,

        [Parameter()]
        [array]$Teams,

        [Parameter()]
        [array]$SharePointSites
    )

    $startTime = (Get-Date).ToUniversalTime()
    Write-Verbose "Starting sync for tenant '$TenantId' at $($startTime.ToString('yyyy-MM-dd HH:mm:ss')) UTC"

    # Resolve tenant to space mapping
    Write-Verbose "Resolving tenant '$TenantId' to Confluence space"
    $mapping = Get-ConfluenceTenantMapping -TenantId $TenantId

    if (-not $mapping) {
        $errorMessage = "No Confluence space mapping found for tenant '$TenantId'. Run Set-ConfluenceTenantMapping first."
        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
            [System.InvalidOperationException]::new($errorMessage),
            'TenantMappingNotFound',
            [System.Management.Automation.ErrorCategory]::ObjectNotFound,
            $TenantId
        )
        $PSCmdlet.ThrowTerminatingError($errorRecord)
    }

    $spaceKey = $mapping.SpaceKey
    Write-Verbose "Tenant '$TenantId' maps to space '$spaceKey'"

    # Initialize results tracking
    $syncResults = @()
    $errors = @()

    # Define sync operations with correct parameter names for each function
    $syncOperations = @(
        @{ Name = 'UserInventory'; ParamName = 'Users'; Data = $Users; Function = 'Sync-ConfluenceUserInventory'; DataParam = 'Users' },
        @{ Name = 'EndpointInventory'; ParamName = 'Endpoints'; Data = $Endpoints; Function = 'Sync-ConfluenceEndpointInventory'; DataParam = 'Endpoints' },
        @{ Name = 'LicenseReport'; ParamName = 'Licenses'; Data = $Licenses; Function = 'Sync-ConfluenceLicenseReport'; DataParam = 'Licenses' },
        @{ Name = 'MFAReport'; ParamName = 'MFAData'; Data = $MFAData; Function = 'Sync-ConfluenceMFAReport'; DataParam = 'MFAData' },
        @{ Name = 'TeamsInventory'; ParamName = 'Teams'; Data = $Teams; Function = 'Sync-ConfluenceTeamsInventory'; DataParam = 'TeamsData' },
        @{ Name = 'SharePointInventory'; ParamName = 'SharePointSites'; Data = $SharePointSites; Function = 'Sync-ConfluenceSharePointInventory'; DataParam = 'SharePointData' }
    )

    foreach ($op in $syncOperations) {
        # Check if this data type was provided
        if (-not $PSBoundParameters.ContainsKey($op.ParamName)) {
            Write-Verbose "Skipping $($op.Name) - no data provided"
            $syncResults += [PSCustomObject]@{
                DataType = $op.Name
                Status   = 'Skipped'
                PageId   = $null
                Message  = 'No data provided'
            }
            continue
        }

        Write-Verbose "Syncing $($op.Name) to space '$spaceKey'"

        if ($PSCmdlet.ShouldProcess("$($op.Name) in $spaceKey", "Sync CIPP data")) {
            try {
                # Build parameters for sync function
                $syncParams = @{
                    SpaceKey = $spaceKey
                }
                $syncParams[$op.DataParam] = $op.Data

                # Call sync function
                $syncFunctionResult = & $op.Function @syncParams

                $syncResults += [PSCustomObject]@{
                    DataType = $op.Name
                    Status   = 'Success'
                    PageId   = $syncFunctionResult.Id
                    Message  = "Synced successfully"
                }
                Write-Verbose "$($op.Name) sync completed successfully"
            }
            catch {
                Write-Warning "$($op.Name) sync failed: $($_.Exception.Message)"
                $syncResults += [PSCustomObject]@{
                    DataType = $op.Name
                    Status   = 'Failed'
                    PageId   = $null
                    Message  = $_.Exception.Message
                }
                $errors += [PSCustomObject]@{
                    DataType  = $op.Name
                    Error     = $_.Exception.Message
                    Timestamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss')
                }
            }
        }
        else {
            $syncResults += [PSCustomObject]@{
                DataType = $op.Name
                Status   = 'WhatIf'
                PageId   = $null
                Message  = 'Would sync'
            }
        }
    }

    $endTime = (Get-Date).ToUniversalTime()
    $duration = $endTime - $startTime

    # Determine overall status (use @() to ensure array for .Count in PS 5.1)
    $successCount = @($syncResults | Where-Object { $_.Status -eq 'Success' }).Count
    $failedCount = @($syncResults | Where-Object { $_.Status -eq 'Failed' }).Count
    $skippedCount = @($syncResults | Where-Object { $_.Status -eq 'Skipped' }).Count
    $whatIfCount = @($syncResults | Where-Object { $_.Status -eq 'WhatIf' }).Count

    if ($whatIfCount -gt 0) {
        $overallStatus = 'WhatIf'
    }
    elseif ($failedCount -eq 0 -and $successCount -gt 0) {
        $overallStatus = 'Success'
    }
    elseif ($failedCount -gt 0 -and $successCount -gt 0) {
        $overallStatus = 'PartialFailure'
    }
    elseif ($failedCount -gt 0 -and $successCount -eq 0) {
        $overallStatus = 'Failed'
    }
    else {
        $overallStatus = 'NoOperation'
    }

    Write-Verbose "Sync completed for tenant '$TenantId': $overallStatus ($successCount succeeded, $failedCount failed, $skippedCount skipped)"

    return [PSCustomObject]@{
        TenantId      = $TenantId
        SpaceKey      = $spaceKey
        StartTime     = $startTime.ToString('yyyy-MM-dd HH:mm:ss UTC')
        EndTime       = $endTime.ToString('yyyy-MM-dd HH:mm:ss UTC')
        Duration      = $duration.ToString('hh\:mm\:ss')
        SyncResults   = $syncResults
        OverallStatus = $overallStatus
        SuccessCount  = $successCount
        FailedCount   = $failedCount
        SkippedCount  = $skippedCount
        ErrorCount    = $errors.Count
        Errors        = $errors
    }
}
```

### Testing Pattern

```powershell
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleRoot = Split-Path -Parent (Split-Path -Parent $here)
$publicDir = Join-Path $moduleRoot 'Public'

Describe 'Sync-CIPPTenantToConfluence' {
    BeforeAll {
        # Define stub functions for all dependencies
        function Get-ConfluenceTenantMapping { param($TenantId) }
        function Sync-ConfluenceUserInventory { param($SpaceKey, $Users) }
        function Sync-ConfluenceEndpointInventory { param($SpaceKey, $Endpoints) }
        function Sync-ConfluenceLicenseReport { param($SpaceKey, $Licenses) }
        function Sync-ConfluenceMFAReport { param($SpaceKey, $MFAData) }
        function Sync-ConfluenceTeamsInventory { param($SpaceKey, $Teams) }
        function Sync-ConfluenceSharePointInventory { param($SpaceKey, $Sites) }

        # Dot-source function under test
        . "$publicDir\Sync-CIPPTenantToConfluence.ps1"
    }

    Context 'Tenant Resolution' {
        BeforeEach {
            Mock Get-ConfluenceTenantMapping {
                [PSCustomObject]@{ TenantId = $TenantId; SpaceKey = 'CONTOSO'; SpaceName = 'Contoso Corp' }
            }
            Mock Sync-ConfluenceUserInventory { [PSCustomObject]@{ PageId = 'user-page-123' } }
        }

        It 'Resolves tenant to space via Get-ConfluenceTenantMapping' {
            Sync-CIPPTenantToConfluence -TenantId 'test-tenant' -Users @()
            Assert-MockCalled Get-ConfluenceTenantMapping -Scope It -Times 1 -ParameterFilter {
                $TenantId -eq 'test-tenant'
            }
        }

        It 'Throws error when no mapping exists' {
            Mock Get-ConfluenceTenantMapping { return $null }
            { Sync-CIPPTenantToConfluence -TenantId 'unknown-tenant' -Users @() } | Should Throw
        }

        It 'Error message suggests Set-ConfluenceTenantMapping' {
            Mock Get-ConfluenceTenantMapping { return $null }
            try {
                Sync-CIPPTenantToConfluence -TenantId 'unknown-tenant' -Users @()
            }
            catch {
                $_.Exception.Message | Should Match 'Set-ConfluenceTenantMapping'
            }
        }
    }

    Context 'Sync Operations' {
        BeforeEach {
            Mock Get-ConfluenceTenantMapping {
                [PSCustomObject]@{ TenantId = 'test-tenant'; SpaceKey = 'TEST'; SpaceName = 'Test' }
            }
            Mock Sync-ConfluenceUserInventory { [PSCustomObject]@{ PageId = 'user-123' } }
            Mock Sync-ConfluenceEndpointInventory { [PSCustomObject]@{ PageId = 'endpoint-123' } }
            Mock Sync-ConfluenceLicenseReport { [PSCustomObject]@{ PageId = 'license-123' } }
            Mock Sync-ConfluenceMFAReport { [PSCustomObject]@{ PageId = 'mfa-123' } }
            Mock Sync-ConfluenceTeamsInventory { [PSCustomObject]@{ PageId = 'teams-123' } }
            Mock Sync-ConfluenceSharePointInventory { [PSCustomObject]@{ PageId = 'sp-123' } }
        }

        It 'Calls all 6 sync functions when all data provided' {
            Sync-CIPPTenantToConfluence -TenantId 'test' -Users @() -Endpoints @() -Licenses @() -MFAData @() -Teams @() -SharePointSites @()
            Assert-MockCalled Sync-ConfluenceUserInventory -Scope It -Times 1
            Assert-MockCalled Sync-ConfluenceEndpointInventory -Scope It -Times 1
            Assert-MockCalled Sync-ConfluenceLicenseReport -Scope It -Times 1
            Assert-MockCalled Sync-ConfluenceMFAReport -Scope It -Times 1
            Assert-MockCalled Sync-ConfluenceTeamsInventory -Scope It -Times 1
            Assert-MockCalled Sync-ConfluenceSharePointInventory -Scope It -Times 1
        }

        It 'Only calls sync functions for provided data types' {
            Sync-CIPPTenantToConfluence -TenantId 'test' -Users @() -Endpoints @()
            Assert-MockCalled Sync-ConfluenceUserInventory -Scope It -Times 1
            Assert-MockCalled Sync-ConfluenceEndpointInventory -Scope It -Times 1
            Assert-MockCalled Sync-ConfluenceLicenseReport -Scope It -Times 0
            Assert-MockCalled Sync-ConfluenceMFAReport -Scope It -Times 0
            Assert-MockCalled Sync-ConfluenceTeamsInventory -Scope It -Times 0
            Assert-MockCalled Sync-ConfluenceSharePointInventory -Scope It -Times 0
        }

        It 'Passes SpaceKey to sync functions' {
            $script:capturedSpaceKey = $null
            Mock Sync-ConfluenceUserInventory {
                param($SpaceKey, $Users)
                $script:capturedSpaceKey = $SpaceKey
                [PSCustomObject]@{ PageId = 'user-123' }
            }
            Sync-CIPPTenantToConfluence -TenantId 'test' -Users @()
            $script:capturedSpaceKey | Should Be 'TEST'
        }
    }

    Context 'Partial Failure Handling' {
        BeforeEach {
            Mock Get-ConfluenceTenantMapping {
                [PSCustomObject]@{ TenantId = 'test'; SpaceKey = 'TEST'; SpaceName = 'Test' }
            }
            Mock Sync-ConfluenceUserInventory { [PSCustomObject]@{ PageId = 'user-123' } }
            Mock Sync-ConfluenceEndpointInventory { throw "API Error" }
            Mock Sync-ConfluenceLicenseReport { [PSCustomObject]@{ PageId = 'license-123' } }
        }

        It 'Continues syncing after failure' {
            $result = Sync-CIPPTenantToConfluence -TenantId 'test' -Users @() -Endpoints @() -Licenses @()
            Assert-MockCalled Sync-ConfluenceUserInventory -Scope It -Times 1
            Assert-MockCalled Sync-ConfluenceEndpointInventory -Scope It -Times 1
            Assert-MockCalled Sync-ConfluenceLicenseReport -Scope It -Times 1
        }

        It 'Returns PartialFailure status' {
            $result = Sync-CIPPTenantToConfluence -TenantId 'test' -Users @() -Endpoints @() -Licenses @()
            $result.OverallStatus | Should Be 'PartialFailure'
        }

        It 'Includes error details in result' {
            $result = Sync-CIPPTenantToConfluence -TenantId 'test' -Users @() -Endpoints @() -Licenses @()
            $result.ErrorCount | Should Be 1
            $result.Errors[0].DataType | Should Be 'EndpointInventory'
        }
    }

    Context 'Result Object' {
        BeforeEach {
            Mock Get-ConfluenceTenantMapping {
                [PSCustomObject]@{ TenantId = 'test'; SpaceKey = 'TEST'; SpaceName = 'Test' }
            }
            Mock Sync-ConfluenceUserInventory { [PSCustomObject]@{ PageId = 'user-123' } }
        }

        It 'Returns PSCustomObject with expected properties' {
            $result = Sync-CIPPTenantToConfluence -TenantId 'test' -Users @()
            $result.TenantId | Should Be 'test'
            $result.SpaceKey | Should Be 'TEST'
            $result.OverallStatus | Should Be 'Success'
            $result.SyncResults | Should Not Be $null
        }

        It 'Includes duration in result' {
            $result = Sync-CIPPTenantToConfluence -TenantId 'test' -Users @()
            $result.Duration | Should Match '\d{2}:\d{2}:\d{2}'
        }
    }

    Context 'WhatIf Support' {
        BeforeEach {
            Mock Get-ConfluenceTenantMapping {
                [PSCustomObject]@{ TenantId = 'test'; SpaceKey = 'TEST'; SpaceName = 'Test' }
            }
            Mock Sync-ConfluenceUserInventory { }
        }

        It 'Does not call sync functions with WhatIf' {
            Sync-CIPPTenantToConfluence -TenantId 'test' -Users @() -WhatIf
            Assert-MockCalled Sync-ConfluenceUserInventory -Scope It -Times 0
        }

        It 'Returns WhatIf status' {
            $result = Sync-CIPPTenantToConfluence -TenantId 'test' -Users @() -WhatIf
            $result.OverallStatus | Should Be 'WhatIf'
        }
    }

    Context 'Verbose Logging' {
        BeforeEach {
            Mock Get-ConfluenceTenantMapping {
                [PSCustomObject]@{ TenantId = 'test'; SpaceKey = 'TEST'; SpaceName = 'Test' }
            }
            Mock Sync-ConfluenceUserInventory { [PSCustomObject]@{ PageId = 'user-123' } }
        }

        It 'Writes verbose messages during execution' {
            $verboseOutput = Sync-CIPPTenantToConfluence -TenantId 'test' -Users @() -Verbose 4>&1
            $verboseMessages = $verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }
            $verboseMessages.Count | Should BeGreaterThan 0
        }
    }
}
```

### Previous Story Intelligence (Story 7.3 Learnings)

**Key Learnings to Apply:**

1. **Pester 3.4 Syntax (CRITICAL):**
   - Use `Should Be` (no hyphen) for Windows PS 5.1 compatibility
   - Use `Should Not Be $null` for null checks
   - Use `Assert-MockCalled` (NOT `Should -Invoke`) with `-Scope It`
   - Define stub functions before mocking
   - Dot-source function under test in BeforeAll

2. **Error Handling Pattern:**
   - Use `$PSCmdlet.ThrowTerminatingError()` - NEVER `throw` directly
   - Include actionable guidance in error messages
   - Use `Write-Warning` for non-fatal issues (sync failures that don't stop others)

3. **UTC Timestamps:**
   - Use `(Get-Date).ToUniversalTime()` for all timestamps
   - Format as `'yyyy-MM-dd HH:mm:ss UTC'`

4. **Test Isolation Pattern:**
   - Mock all dependencies
   - Use `$script:capturedX` pattern to verify parameters passed

5. **WhatIf Support:**
   - Check `$PSCmdlet.ShouldProcess()` before each API call
   - Return meaningful result even with WhatIf

### Project Structure Notes

**File to Create:**
```text
Modules/ConfluenceAPI/
├── Public/
│   └── Sync-CIPPTenantToConfluence.ps1    # CREATE
└── Tests/
    └── Public/
        └── Sync-CIPPTenantToConfluence.Tests.ps1  # CREATE
```

**Note:** The module manifest (`ConfluenceAPI.psd1`) requires explicit `FunctionsToExport` entries for new public functions.

### Common Mistakes to Avoid

1. **DO NOT** stop entire sync if one data type fails - continue with others
2. **DO NOT** forget to check if data parameter was provided vs empty
3. **DO NOT** use `throw` directly - use `$PSCmdlet.ThrowTerminatingError()`
4. **DO NOT** forget UTC timestamps on start/end times
5. **DO NOT** forget `-WhatIf` and `-Verbose` support
6. **DO NOT** use `Should -Invoke` in tests - use `Assert-MockCalled` (Pester 3.4)
7. **DO NOT** hardcode SpaceKey - always resolve from tenant mapping
8. **DO NOT** forget to return sync results even on partial failure
9. **DO NOT** silently swallow errors - log with `Write-Warning` and collect in errors array
10. **DO NOT** forget to check `$PSBoundParameters.ContainsKey()` for selective sync

### Git Commit Pattern

```
feat: implement Story 8.1 Manual Tenant Sync

- Add Sync-CIPPTenantToConfluence orchestration function
- Support selective data type sync (any combination of 6 types)
- Continue on partial failures with error collection
- Return comprehensive sync summary with timing
- Create XX unit tests (all passing)
- PSScriptAnalyzer: 0 warnings

Story covers FR34 (manual sync trigger)
```

### References

- [Source: docs/architecture.md#Project-Structure-Boundaries] - Public function location
- [Source: docs/epics.md#Story-8.1] - FR34 requirements
- [Source: docs/prd.md#Sync-Operations] - FR34 manual sync requirement
- [Source: docs/sprint-artifacts/7-3-clients-index-maintenance.md] - Previous story patterns
- [Source: docs/sprint-artifacts/4-2-user-inventory-sync-function.md] - Sync function pattern
- [Source: docs/sprint-artifacts/6-3-sharepoint-inventory-transformer-sync.md] - Latest sync pattern

### FRs Covered

- **FR34**: Technical Lead can trigger manual sync for a specific tenant (primary)
- **NFR18**: Module must include -WhatIf support for all write operations
- **NFR19**: Module must include -Verbose logging for troubleshooting
- **NFR10**: Partial failure handling continues with remaining items

## Dev Agent Record

### Context Reference

<!-- Story context analysis completed by create-story workflow -->

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

### Completion Notes List

- **2025-12-15**: Story implemented with all acceptance criteria met
- Created `Sync-CIPPTenantToConfluence` function with full orchestration of 6 data types
- Used PS 5.1 array wrapping pattern for `@(Where-Object).Count` to avoid null count issue
- Parameter mapping: internal params (Users, Teams, SharePointSites) map to function params (Users, TeamsData, SharePointData)
- Fixed pre-existing bug in New-ConfluenceClientSpace.Tests.ps1 (wrong path for mapping functions)
- Updated ConfluenceAPI.psd1 FunctionsToExport with all missing Epic 4-8 functions
- PSScriptAnalyzer: 0 warnings
- New tests: 44 passing
- Full regression: 1182 passing (0 failed)

### Senior Developer Review (AI)

**Reviewed:** 2025-12-15
**Reviewer:** Claude Opus 4.5 (Adversarial Code Review)
**Outcome:** ✅ APPROVED (with fixes applied)

**Issues Found & Fixed:**
1. **HIGH** - Dev Notes code pattern was stale (used `Param` instead of `DataParam`, `.PageId` instead of `.Id`) → Fixed
2. **HIGH** - Contradictory statement about manifest updates → Fixed
3. **MEDIUM** - Missing `PageId = $null` in Dev Notes pattern for Skipped/Failed/WhatIf results → Fixed

**Verification:**
- All 8 Acceptance Criteria validated against implementation ✓
- All tasks marked `[x]` verified as completed ✓
- Test quality: Real assertions, proper mocks, PS 5.1 compatible ✓
- No security issues found ✓
- Code quality: Proper error handling, consistent patterns ✓

### File List

**Created:**

- `Modules/ConfluenceAPI/Public/Sync-CIPPTenantToConfluence.ps1` - Main orchestration function
- `Modules/ConfluenceAPI/Tests/Public/Sync-CIPPTenantToConfluence.Tests.ps1` - Unit tests (44 tests)

**Modified:**

- `Modules/ConfluenceAPI/ConfluenceAPI.psd1` - Added all missing FunctionsToExport
- `Modules/ConfluenceAPI/Tests/Public/New-ConfluenceClientSpace.Tests.ps1` - Fixed dot-source paths for mapping functions
- `docs/sprint-artifacts/sprint-status.yaml` - Updated story status to done
- `docs/sprint-artifacts/8-1-manual-tenant-sync.md` - Code review fixes to Dev Notes pattern
