# Story 7.2: Tenant-Space Mapping Management

Status: Done

## Story

As a **Technical Lead**,
I want **to view and manage tenant-to-space mappings**,
so that **I know which CIPP tenants sync to which Confluence spaces and can update or remove mappings as needed**.

## Acceptance Criteria

### AC1: View All Mappings (FR7)
**Given** tenant-to-space mappings exist in Azure Table Storage
**When** I run `Get-ConfluenceTenantMapping` (exported as Public function)
**Then** all tenant-to-space mappings are returned
**And** each mapping shows TenantId, SpaceKey, SpaceName as PSCustomObject

### AC2: View Specific Mapping (FR7)
**Given** a mapping exists for a specific TenantId
**When** I run `Get-ConfluenceTenantMapping -TenantId 'abc-123'`
**Then** that specific mapping is returned
**And** if no mapping exists, $null is returned (not an error)

### AC3: Update Existing Mapping (FR8)
**Given** a mapping exists for TenantId 'abc-123' pointing to 'OLDSPACE'
**When** I run `Set-ConfluenceTenantMapping -TenantId 'abc-123' -SpaceKey 'NEWSPACE' -SpaceName 'New Client Name'`
**Then** the mapping is updated to point to the new space
**And** the old mapping is replaced (not duplicated)
**And** `-WhatIf` shows what would change

### AC4: Remove Mapping (FR8)
**Given** a mapping exists for TenantId 'abc-123'
**When** I run `Remove-ConfluenceTenantMapping -TenantId 'abc-123'`
**Then** the mapping is removed from Azure Table Storage
**And** the Confluence space itself is NOT deleted (only the mapping)
**And** `-WhatIf` shows what would be removed
**And** `-Confirm` prompts for confirmation (ConfirmImpact = High)

### AC5: Support -Verbose Logging (NFR19)
**Given** I want detailed operation logging
**When** I run any mapping function with `-Verbose`
**Then** verbose messages describe the operation being performed
**And** each step is logged (table lookup, update, removal)

### AC6: Validate TenantId on Remove
**Given** I want to remove a mapping that doesn't exist
**When** I run `Remove-ConfluenceTenantMapping -TenantId 'nonexistent'`
**Then** a warning is written (not an error) indicating no mapping found
**And** the function completes without throwing

### AC7: Validate SpaceKey Format on Set
**Given** I want to update a mapping with an invalid SpaceKey
**When** I run `Set-ConfluenceTenantMapping -TenantId 'abc-123' -SpaceKey 'invalid key'`
**Then** a terminating error is thrown
**And** the error message explains SpaceKey requirements (uppercase letters and numbers)

### AC8: Get Mapping by SpaceKey (Optional Enhancement)
**Given** I want to find which tenant maps to a specific space
**When** I run `Get-ConfluenceTenantMapping -SpaceKey 'CONTOSO'`
**Then** the mapping for that space is returned (or $null if not found)
**And** this provides reverse lookup capability

## Tasks / Subtasks

- [x] Task 1: Promote Get-ConfluenceTenantMapping to Public (AC: 1, 2, 5, 8)
  - [x] Move `Private/Get-ConfluenceTenantMapping.ps1` to `Public/Get-ConfluenceTenantMapping.ps1`
  - [x] Add `-SpaceKey` optional parameter for reverse lookup (AC8)
  - [x] Add filter logic: "SpaceKey eq 'X'" when SpaceKey provided
  - [x] Update comment-based help with all parameters and examples
  - [x] Ensure verbose logging covers all code paths

- [x] Task 2: Promote Set-ConfluenceTenantMapping to Public (AC: 3, 5, 7)
  - [x] Move `Private/Set-ConfluenceTenantMapping.ps1` to `Public/Set-ConfluenceTenantMapping.ps1`
  - [x] Add SpaceKey validation (uppercase letters/numbers, start with letter)
  - [x] Use `-cnotmatch '^[A-Z][A-Z0-9]*$'` for case-sensitive validation
  - [x] Add `[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]`
  - [x] Update error handling to use `$PSCmdlet.ThrowTerminatingError()`
  - [x] Update comment-based help with validation rules and examples

- [x] Task 3: Create Remove-ConfluenceTenantMapping Public Function (AC: 4, 5, 6)
  - [x] Create `Public/Remove-ConfluenceTenantMapping.ps1` file
  - [x] Add `[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]` attribute
  - [x] Add `[OutputType([void])]` for return type
  - [x] Add `-TenantId` parameter (Mandatory string)
  - [x] Check if mapping exists before attempting removal
  - [x] Write warning (not error) if mapping not found
  - [x] Use `Remove-AzDataTableEntity -Force @CIPPMapping -Entity $entity` for deletion
  - [x] Implement `$PSCmdlet.ShouldProcess` for WhatIf/Confirm support
  - [x] Add `Write-Verbose` logging throughout
  - [x] Add comment-based help with examples

- [x] Task 4: Create Unit Tests for Get-ConfluenceTenantMapping (AC: 1, 2, 5, 8)
  - [x] Create `Tests/Public/Get-ConfluenceTenantMapping.Tests.ps1`
  - [x] Test: Returns all mappings when no parameters (AC1)
  - [x] Test: Returns PSCustomObject with TenantId, SpaceKey, SpaceName (AC1)
  - [x] Test: Returns specific mapping by TenantId (AC2)
  - [x] Test: Returns $null when TenantId not found (AC2)
  - [x] Test: Returns mapping by SpaceKey (AC8)
  - [x] Test: Returns $null when SpaceKey not found (AC8)
  - [x] Test: Writes verbose messages (AC5)
  - [x] Test: Handles empty table gracefully

- [x] Task 5: Create Unit Tests for Set-ConfluenceTenantMapping (AC: 3, 5, 7)
  - [x] Create `Tests/Public/Set-ConfluenceTenantMapping.Tests.ps1`
  - [x] Test: Calls Add-CIPPAzDataTableEntity with correct parameters (AC3)
  - [x] Test: Uses -Force to overwrite existing mapping (AC3)
  - [x] Test: Does not update with WhatIf (AC3)
  - [x] Test: Writes verbose messages (AC5)
  - [x] Test: Throws error for invalid SpaceKey format (AC7) - lowercase
  - [x] Test: Throws error for SpaceKey with spaces (AC7)
  - [x] Test: Throws error for SpaceKey starting with number (AC7)
  - [x] Test: Accepts valid uppercase SpaceKey (AC7)

- [x] Task 6: Create Unit Tests for Remove-ConfluenceTenantMapping (AC: 4, 5, 6)
  - [x] Create `Tests/Public/Remove-ConfluenceTenantMapping.Tests.ps1`
  - [x] Test: Calls Remove-AzDataTableEntity with correct entity (AC4)
  - [x] Test: Does not remove with WhatIf (AC4)
  - [x] Test: Prompts for confirmation (ConfirmImpact = High) (AC4)
  - [x] Test: Writes verbose messages (AC5)
  - [x] Test: Writes warning when mapping not found (AC6)
  - [x] Test: Does not throw when mapping not found (AC6)
  - [x] Test: Returns nothing (void) on success

- [x] Task 7: Run Validation (AC: 1-8)
  - [x] Run `Invoke-ScriptAnalyzer` on all 3 functions - target 0 warnings
  - [x] Run all new Pester tests - all passing
  - [x] Verify all existing tests still pass (regression check)
  - [x] Verify module loads correctly after file moves

## Dev Notes

### Architecture Compliance

**Module Locations (after promotion):**
- `Modules/ConfluenceAPI/Public/Get-ConfluenceTenantMapping.ps1` - Retrieval (MOVE from Private)
- `Modules/ConfluenceAPI/Public/Set-ConfluenceTenantMapping.ps1` - Update (MOVE from Private)
- `Modules/ConfluenceAPI/Public/Remove-ConfluenceTenantMapping.ps1` - Delete (CREATE)

Per architecture.md (lines 308-312), tenant mapping management functions belong in Public/:
- [Source: docs/architecture.md#Project-Structure-Boundaries] - CIPP integration in Public/
- [Source: docs/epics.md#Story-7.2] - FR7, FR8 requirements

**Why Promote to Public?**
- FR7 explicitly requires "Technical Lead can view all tenant-to-space mappings"
- FR8 explicitly requires "Technical Lead can update or remove tenant-to-space mappings"
- These are user-facing operations, not internal helpers
- Story 7.1 used them as private helpers during space creation, but now they need direct user access

### Dependencies

- `Get-CIPPTable` - CIPP framework function for Azure Table reference
- `Get-CIPPAzDataTableEntity` - CIPP framework function for querying entities
- `Add-CIPPAzDataTableEntity` - CIPP framework function for adding/updating entities
- `Remove-AzDataTableEntity` - Azure Table function for deleting entities

### CRITICAL: Azure Table Storage Pattern (from Story 7.1)

**Table Structure:**

| Component | Value |
|-----------|-------|
| **Table** | `CippMapping` |
| **Partition Key** | `'ConfluenceMapping'` |
| **Row Key** | Tenant ID |
| **Properties** | `SpaceKey`, `SpaceName` |

**Existing Code Pattern (Get-ConfluenceTenantMapping):**

```powershell
$CIPPMapping = Get-CIPPTable -TableName 'CippMapping'
$filter = "PartitionKey eq 'ConfluenceMapping' and RowKey eq '$TenantId'"
$mapping = Get-CIPPAzDataTableEntity @CIPPMapping -Filter $filter
```

**Removal Pattern (from CIPP codebase):**

```powershell
$CIPPMapping = Get-CIPPTable -TableName 'CippMapping'
$filter = "PartitionKey eq 'ConfluenceMapping' and RowKey eq '$TenantId'"
$entity = Get-CIPPAzDataTableEntity @CIPPMapping -Filter $filter

if ($entity) {
    Remove-AzDataTableEntity -Force @CIPPMapping -Entity $entity
}
```

### SpaceKey Validation Pattern (from Story 7.1)

```powershell
# Use -cnotmatch for case-sensitive matching (PowerShell default is case-insensitive)
if ($SpaceKey -cnotmatch '^[A-Z][A-Z0-9]*$') {
    $PSCmdlet.ThrowTerminatingError(
        [System.Management.Automation.ErrorRecord]::new(
            [System.Exception]::new("SpaceKey '$SpaceKey' is invalid. SpaceKey must start with an uppercase letter and contain only uppercase letters and numbers (A-Z, 0-9)."),
            "InvalidSpaceKey",
            [System.Management.Automation.ErrorCategory]::InvalidArgument,
            $SpaceKey
        )
    )
}
```

### Remove-ConfluenceTenantMapping Pattern

```powershell
function Remove-ConfluenceTenantMapping {
    <#
    .SYNOPSIS
        Removes a tenant-to-space mapping from Azure Table Storage.
    .DESCRIPTION
        Deletes the mapping between a CIPP tenant and a Confluence space.
        Note: This only removes the mapping - it does NOT delete the Confluence space itself.
    .PARAMETER TenantId
        The CIPP tenant ID whose mapping should be removed.
    .EXAMPLE
        Remove-ConfluenceTenantMapping -TenantId 'abc-123'
        Removes the mapping for tenant abc-123.
    .EXAMPLE
        Remove-ConfluenceTenantMapping -TenantId 'abc-123' -WhatIf
        Shows what would be removed without actually removing.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$TenantId
    )

    Write-Verbose "Removing tenant mapping for '$TenantId'"

    # Get the CIPPMapping table reference
    $CIPPMapping = Get-CIPPTable -TableName 'CippMapping'

    # Find the existing mapping
    Write-Verbose "Looking up existing mapping for tenant '$TenantId'"
    $filter = "PartitionKey eq 'ConfluenceMapping' and RowKey eq '$TenantId'"
    $entity = Get-CIPPAzDataTableEntity @CIPPMapping -Filter $filter

    if (-not $entity) {
        Write-Warning "No mapping found for tenant '$TenantId'. Nothing to remove."
        return
    }

    Write-Verbose "Found mapping: '$TenantId' -> '$($entity.SpaceKey)'"

    if ($PSCmdlet.ShouldProcess("Tenant '$TenantId' -> Space '$($entity.SpaceKey)'", "Remove Confluence tenant mapping")) {
        Remove-AzDataTableEntity -Force @CIPPMapping -Entity $entity
        Write-Verbose "Successfully removed mapping for tenant '$TenantId'"
    }
}
```

### Enhanced Get-ConfluenceTenantMapping Pattern

```powershell
function Get-ConfluenceTenantMapping {
    <#
    .SYNOPSIS
        Retrieves Confluence tenant-to-space mappings from Azure Table Storage.
    .DESCRIPTION
        Queries the CippMapping Azure Table for Confluence mappings. Can retrieve
        a specific mapping by TenantId, by SpaceKey, or all Confluence mappings.
    .PARAMETER TenantId
        Optional. The specific tenant ID to look up.
    .PARAMETER SpaceKey
        Optional. The specific space key to look up (reverse lookup).
    .OUTPUTS
        [PSCustomObject] Mapping object(s) with TenantId, SpaceKey, SpaceName properties.
    .EXAMPLE
        Get-ConfluenceTenantMapping
        Returns all Confluence tenant mappings.
    .EXAMPLE
        Get-ConfluenceTenantMapping -TenantId 'abc-123'
        Returns the mapping for the specified tenant.
    .EXAMPLE
        Get-ConfluenceTenantMapping -SpaceKey 'CONTOSO'
        Returns the mapping for the specified space (reverse lookup).
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [string]$TenantId,

        [Parameter()]
        [string]$SpaceKey
    )

    Write-Verbose "Retrieving Confluence tenant mapping(s)"

    # Get the CIPPMapping table reference
    $CIPPMapping = Get-CIPPTable -TableName 'CippMapping'

    if ($TenantId) {
        # Get specific mapping by TenantId
        Write-Verbose "Looking up mapping for tenant '$TenantId'"
        $filter = "PartitionKey eq 'ConfluenceMapping' and RowKey eq '$TenantId'"
        $mapping = Get-CIPPAzDataTableEntity @CIPPMapping -Filter $filter

        if ($mapping) {
            return [PSCustomObject]@{
                TenantId  = $mapping.RowKey
                SpaceKey  = $mapping.SpaceKey
                SpaceName = $mapping.SpaceName
            }
        }
        return $null
    }
    elseif ($SpaceKey) {
        # Get specific mapping by SpaceKey (reverse lookup)
        Write-Verbose "Looking up mapping for space '$SpaceKey'"
        $filter = "PartitionKey eq 'ConfluenceMapping' and SpaceKey eq '$SpaceKey'"
        $mapping = Get-CIPPAzDataTableEntity @CIPPMapping -Filter $filter

        if ($mapping) {
            return [PSCustomObject]@{
                TenantId  = $mapping.RowKey
                SpaceKey  = $mapping.SpaceKey
                SpaceName = $mapping.SpaceName
            }
        }
        return $null
    }
    else {
        # Get all mappings
        Write-Verbose "Retrieving all Confluence tenant mappings"
        $filter = "PartitionKey eq 'ConfluenceMapping'"
        $mappings = Get-CIPPAzDataTableEntity @CIPPMapping -Filter $filter

        foreach ($mapping in $mappings) {
            [PSCustomObject]@{
                TenantId  = $mapping.RowKey
                SpaceKey  = $mapping.SpaceKey
                SpaceName = $mapping.SpaceName
            }
        }
    }
}
```

### Enhanced Set-ConfluenceTenantMapping Pattern

```powershell
function Set-ConfluenceTenantMapping {
    <#
    .SYNOPSIS
        Creates or updates a tenant-to-space mapping in Azure Table Storage.
    .DESCRIPTION
        Stores a mapping between a CIPP tenant and a Confluence space in the CippMapping
        Azure Table. If a mapping already exists for the TenantId, it will be overwritten.
    .PARAMETER TenantId
        The CIPP tenant ID to map.
    .PARAMETER SpaceKey
        The Confluence space key to map to. Must be uppercase letters and numbers only,
        starting with a letter (e.g., 'CONTOSO', 'CLIENT123').
    .PARAMETER SpaceName
        The display name of the space/client.
    .EXAMPLE
        Set-ConfluenceTenantMapping -TenantId 'abc-123' -SpaceKey 'CONTOSO' -SpaceName 'Contoso Corp'
        Creates or updates a mapping for tenant abc-123 to space CONTOSO.
    .EXAMPLE
        Set-ConfluenceTenantMapping -TenantId 'abc-123' -SpaceKey 'NEWSPACE' -SpaceName 'New Name' -WhatIf
        Shows what would be changed without actually changing.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$TenantId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$SpaceKey,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$SpaceName
    )

    Write-Verbose "Setting tenant mapping: '$TenantId' -> '$SpaceKey'"

    # Validate SpaceKey format (uppercase letters and numbers, starts with letter)
    # Use -cnotmatch for case-sensitive matching
    if ($SpaceKey -cnotmatch '^[A-Z][A-Z0-9]*$') {
        $PSCmdlet.ThrowTerminatingError(
            [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new("SpaceKey '$SpaceKey' is invalid. SpaceKey must start with an uppercase letter and contain only uppercase letters and numbers (A-Z, 0-9)."),
                "InvalidSpaceKey",
                [System.Management.Automation.ErrorCategory]::InvalidArgument,
                $SpaceKey
            )
        )
    }

    if ($PSCmdlet.ShouldProcess($TenantId, "Create/Update Confluence tenant mapping to '$SpaceKey'")) {
        $CIPPMapping = Get-CIPPTable -TableName 'CippMapping'

        $AddObject = @{
            PartitionKey = 'ConfluenceMapping'
            RowKey       = "$TenantId"
            SpaceKey     = "$SpaceKey"
            SpaceName    = "$SpaceName"
        }

        Add-CIPPAzDataTableEntity @CIPPMapping -Entity $AddObject -Force
        Write-Verbose "Successfully stored mapping for tenant '$TenantId'"
    }
}
```

### Previous Story Intelligence (Story 7.1 Learnings)

**Key Learnings to Apply:**

1. **Pester 3.4 Syntax (CRITICAL):**
   - Use `Should Be` (no hyphen) for Windows PS 5.1 compatibility
   - Use `Should Not Be $null` for null checks
   - Use `Assert-MockCalled` (NOT `Should -Invoke`) with `-Scope It`
   - Define stub functions before mocking
   - Dot-source function under test in BeforeAll

2. **Case-Sensitive SpaceKey Validation:**
   - MUST use `-cnotmatch` not `-notmatch`
   - PowerShell's `-notmatch` is case-insensitive by default
   - Pattern: `'^[A-Z][A-Z0-9]*$'`

3. **Error Handling Pattern:**
   - Use `$PSCmdlet.ThrowTerminatingError()` - NEVER `throw` directly
   - Include actionable guidance in error messages
   - Use `Write-Warning` for non-fatal issues (like "mapping not found")

4. **Test Isolation Pattern:**
   - Mock Azure Table Storage functions (Get-CIPPTable, Get-CIPPAzDataTableEntity, Add-CIPPAzDataTableEntity, Remove-AzDataTableEntity)
   - Use `$script:capturedX` pattern to verify parameters passed

5. **Module Loader Behavior:**
   - Moving files from Private/ to Public/ automatically changes export status
   - psm1 dot-sources both directories, psd1 exports Public/ functions

### Testing Pattern

```powershell
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $here)) 'Public'

Describe 'Get-ConfluenceTenantMapping' {
    BeforeAll {
        # Define stub functions for CIPP dependencies
        function Get-CIPPTable { param($TableName) }
        function Get-CIPPAzDataTableEntity { param($Filter) }

        # Dot-source the function under test
        . "$publicDir\Get-ConfluenceTenantMapping.ps1"
    }

    Context 'Retrieve All Mappings' {
        BeforeEach {
            Mock Get-CIPPTable { return @{ TableName = 'CippMapping' } }
            Mock Get-CIPPAzDataTableEntity {
                @(
                    @{ RowKey = 'tenant-1'; SpaceKey = 'SPACE1'; SpaceName = 'Space One' },
                    @{ RowKey = 'tenant-2'; SpaceKey = 'SPACE2'; SpaceName = 'Space Two' }
                )
            }
        }

        It 'Returns all mappings when no parameters provided' {
            $result = @(Get-ConfluenceTenantMapping)
            $result.Count | Should Be 2
        }

        It 'Returns PSCustomObject with expected properties' {
            $result = @(Get-ConfluenceTenantMapping)
            $result[0].TenantId | Should Be 'tenant-1'
            $result[0].SpaceKey | Should Be 'SPACE1'
            $result[0].SpaceName | Should Be 'Space One'
        }
    }

    Context 'Retrieve by TenantId' {
        BeforeEach {
            Mock Get-CIPPTable { return @{ TableName = 'CippMapping' } }
        }

        It 'Returns specific mapping when TenantId provided' {
            Mock Get-CIPPAzDataTableEntity {
                @{ RowKey = 'tenant-1'; SpaceKey = 'SPACE1'; SpaceName = 'Space One' }
            }

            $result = Get-ConfluenceTenantMapping -TenantId 'tenant-1'
            $result.TenantId | Should Be 'tenant-1'
        }

        It 'Returns $null when TenantId not found' {
            Mock Get-CIPPAzDataTableEntity { return $null }

            $result = Get-ConfluenceTenantMapping -TenantId 'nonexistent'
            $result | Should Be $null
        }
    }

    Context 'Retrieve by SpaceKey' {
        BeforeEach {
            Mock Get-CIPPTable { return @{ TableName = 'CippMapping' } }
        }

        It 'Returns specific mapping when SpaceKey provided' {
            Mock Get-CIPPAzDataTableEntity {
                @{ RowKey = 'tenant-1'; SpaceKey = 'CONTOSO'; SpaceName = 'Contoso Corp' }
            }

            $result = Get-ConfluenceTenantMapping -SpaceKey 'CONTOSO'
            $result.SpaceKey | Should Be 'CONTOSO'
        }
    }
}
```

### Project Structure Notes

**Files to Move:**
```text
Modules/ConfluenceAPI/
├── Private/
│   ├── Get-ConfluenceTenantMapping.ps1    # MOVE to Public/
│   └── Set-ConfluenceTenantMapping.ps1    # MOVE to Public/
└── Public/
    ├── Get-ConfluenceTenantMapping.ps1    # MOVED FROM Private/
    ├── Set-ConfluenceTenantMapping.ps1    # MOVED FROM Private/
    └── Remove-ConfluenceTenantMapping.ps1 # CREATE
```

**Files to Create:**
```text
Modules/ConfluenceAPI/Tests/Public/
├── Get-ConfluenceTenantMapping.Tests.ps1    # CREATE
├── Set-ConfluenceTenantMapping.Tests.ps1    # CREATE
└── Remove-ConfluenceTenantMapping.Tests.ps1 # CREATE
```

**No manifest update needed** - Module exports are auto-handled by psm1 loader structure.

### Impact on New-ConfluenceClientSpace

After moving Get/Set-ConfluenceTenantMapping to Public/:
- `New-ConfluenceClientSpace.ps1` will continue to work because it calls by function name
- The functions are still available to all other module functions
- No code changes needed in New-ConfluenceClientSpace

### Common Mistakes to Avoid

1. **DO NOT** forget `-cnotmatch` for case-sensitive SpaceKey validation
2. **DO NOT** throw errors when mapping not found on Remove - use Write-Warning
3. **DO NOT** delete the Confluence space when removing mapping (mapping only!)
4. **DO NOT** forget `SupportsShouldProcess` on Set and Remove functions
5. **DO NOT** forget `ConfirmImpact = 'High'` on Remove function
6. **DO NOT** use `throw` directly - use `$PSCmdlet.ThrowTerminatingError()`
7. **DO NOT** forget to update existing tests after moving files
8. **DO NOT** forget the `-Force` flag on `Add-CIPPAzDataTableEntity` to allow updates
9. **DO NOT** return anything from Remove function (void return type)
10. **DO NOT** forget to mock `Remove-AzDataTableEntity` in tests

### Git Intelligence

**Recent Commit Patterns (Story 7.1):**
- Commit message format: `feat: implement Story X.Y Title`
- Include bullet list of changes
- Reference FRs covered
- Note PSScriptAnalyzer status and test counts

**Files Modified in 7.1:**
- 4 PowerShell functions (1 public, 3 private)
- 2 test files
- Story file and sprint-status.yaml

### References

- [Source: docs/architecture.md#Project-Structure-Boundaries] - Public function location
- [Source: docs/epics.md#Story-7.2] - FR7, FR8 requirements
- [Source: docs/prd.md#Space-Management] - FR7, FR8 requirements
- [Source: docs/sprint-artifacts/7-1-client-space-creation.md] - Previous story patterns
- [Source: Modules/ConfluenceAPI/Private/Get-ConfluenceTenantMapping.ps1] - Current implementation
- [Source: Modules/ConfluenceAPI/Private/Set-ConfluenceTenantMapping.ps1] - Current implementation

### FRs Covered

- **FR7**: Technical Lead can view all tenant-to-space mappings (primary)
- **FR8**: Technical Lead can update or remove tenant-to-space mappings (primary)
- **NFR18**: Module must include -WhatIf support for all write operations
- **NFR19**: Module must include -Verbose logging for troubleshooting
- **NFR20**: Error messages must include actionable troubleshooting guidance

## Dev Agent Record

### Context Reference

<!-- Story context analysis completed by create-story workflow -->

### Agent Model Used

Claude Opus 4.5

### Debug Log References

- PSScriptAnalyzer: 0 warnings on all 3 tenant mapping functions
- Pester 3.4 test run: 67 new tests (20 Get + 27 Set + 20 Remove) all passing
- Full regression suite: 632 tests passing, 0 failures

### Completion Notes List

- Promoted Get-ConfluenceTenantMapping from Private/ to Public/ with new -SpaceKey parameter for reverse lookup
- Promoted Set-ConfluenceTenantMapping from Private/ to Public/ with case-sensitive SpaceKey validation using -cnotmatch
- Created new Remove-ConfluenceTenantMapping with ConfirmImpact='High' and proper warning for non-existent mappings
- All functions include comprehensive -Verbose logging and -WhatIf support
- SpaceKey validation enforces uppercase letters/numbers pattern: '^[A-Z][A-Z0-9]*$'
- Test stub functions correctly define -Force as [switch] parameter

### Code Review Fixes (2025-12-15)

- Added parameter sets to Get-ConfluenceTenantMapping to prevent -TenantId and -SpaceKey from being used together
- Added `[OutputType([void])]` to Set-ConfluenceTenantMapping for consistency
- Added 2 new tests for parameter set validation

### File List

**Created:**
- Modules/ConfluenceAPI/Public/Get-ConfluenceTenantMapping.ps1
- Modules/ConfluenceAPI/Public/Set-ConfluenceTenantMapping.ps1
- Modules/ConfluenceAPI/Public/Remove-ConfluenceTenantMapping.ps1
- Modules/ConfluenceAPI/Tests/Public/Get-ConfluenceTenantMapping.Tests.ps1
- Modules/ConfluenceAPI/Tests/Public/Set-ConfluenceTenantMapping.Tests.ps1
- Modules/ConfluenceAPI/Tests/Public/Remove-ConfluenceTenantMapping.Tests.ps1

**Deleted:**
- Modules/ConfluenceAPI/Private/Get-ConfluenceTenantMapping.ps1
- Modules/ConfluenceAPI/Private/Set-ConfluenceTenantMapping.ps1

**Modified:**
- docs/sprint-artifacts/sprint-status.yaml
- docs/sprint-artifacts/7-2-tenant-space-mapping-management.md

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2025-12-15 | Story created via create-story workflow | Claude Opus 4.5 |
| 2025-12-15 | Implementation complete - all tasks done, 65 tests passing | Claude Opus 4.5 |
| 2025-12-15 | Code review complete - 3 fixes applied, 67 tests passing | Claude Opus 4.5 |
