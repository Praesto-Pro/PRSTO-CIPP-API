# Story 7.1: Client Space Creation

Status: done

## Story

As a **Technical Lead**,
I want **to create a new client space with standard structure**,
so that **each client has organized documentation with consistent layout for data syncs**.

## Acceptance Criteria

### AC1: Create Client Space (FR5)
**Given** I want to create a client space
**When** I run `New-ConfluenceClientSpace -SpaceKey 'CONTOSO' -ClientName 'Contoso Corp' -TenantId 'abc-123'`
**Then** a new Confluence space is created with the client name
**And** the function returns a PSCustomObject with Id, SpaceKey, Name, HomepageId, TenantId

### AC2: Create Standard Homepage Structure
**Given** I create a new client space
**When** the space is created
**Then** a homepage is created with standard section headings:
  - "Overview" section
  - "User Inventory" placeholder
  - "Endpoint Inventory" placeholder
  - "License Report" placeholder
  - "Security Reports" (MFA Status) placeholder
  - "Collaboration" (Teams, SharePoint) placeholder
**And** the homepage uses ADF format

### AC3: Store Tenant-to-Space Mapping (FR6)
**Given** I create a client space with TenantId
**When** the space creation completes
**Then** the tenant-to-space mapping is stored in Azure Table Storage
**And** the mapping includes TenantId, SpaceKey, SpaceName (ClientName)
**And** the mapping uses PartitionKey 'ConfluenceMapping'

### AC4: Support -WhatIf (NFR18)
**Given** I want to preview space creation
**When** I run `New-ConfluenceClientSpace -SpaceKey 'CONTOSO' -ClientName 'Contoso Corp' -TenantId 'abc-123' -WhatIf`
**Then** no changes are made to Confluence
**And** no mapping is stored
**And** the function returns null

### AC5: Support -Verbose Logging (NFR19)
**Given** I want detailed operation logging
**When** I run with `-Verbose`
**Then** the function logs: "Creating client space 'X' for tenant 'Y'"
**And** logs space creation and mapping storage operations

### AC6: Validate SpaceKey Format
**Given** I provide an invalid SpaceKey format
**When** I run `New-ConfluenceClientSpace -SpaceKey 'invalid key with spaces'`
**Then** a validation error is thrown
**And** the error message explains SpaceKey requirements (letters, numbers, no spaces)

### AC7: Handle Duplicate SpaceKey
**Given** a space with the SpaceKey already exists
**When** I run `New-ConfluenceClientSpace -SpaceKey 'EXISTING'`
**Then** a terminating error is thrown
**And** the error message indicates the space already exists
**And** suggests using Get-ConfluenceSpace to verify

### AC8: Handle Duplicate TenantId Mapping
**Given** a mapping for the TenantId already exists
**When** I run `New-ConfluenceClientSpace -TenantId 'existing-tenant-id'`
**Then** a terminating error is thrown
**And** the error message indicates the tenant is already mapped
**And** suggests using Get-ConfluenceTenantMapping to verify

### AC9: Optional Description Parameter
**Given** I want to add a description to the space
**When** I run `New-ConfluenceClientSpace -SpaceKey 'CONTOSO' -ClientName 'Contoso Corp' -TenantId 'abc-123' -Description 'Documentation for Contoso'`
**Then** the space is created with the provided description

## Tasks / Subtasks

- [x] Task 1: Create New-ConfluenceClientSpace Public Function (AC: 1, 2, 3, 4, 5, 6, 7, 8, 9)
  - [x] Create `Public/New-ConfluenceClientSpace.ps1` file
  - [x] Add `[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]`
  - [x] Add `[OutputType([PSCustomObject])]` for return type
  - [x] Add `-SpaceKey` parameter (Mandatory string, validate format)
  - [x] Add `-ClientName` parameter (Mandatory string)
  - [x] Add `-TenantId` parameter (Mandatory string)
  - [x] Add `-Description` parameter (optional string)
  - [x] Validate SpaceKey format (alphanumeric, uppercase) - uses `-cnotmatch` for case-sensitive
  - [x] Check if space already exists using `Get-ConfluenceSpace`
  - [x] Check if TenantId already has a mapping using Azure Table lookup
  - [x] Create space using `New-ConfluenceSpace`
  - [x] Generate homepage ADF content with standard structure
  - [x] Update homepage with `Set-ConfluencePage`
  - [x] Store mapping in Azure Table Storage using CIPP pattern
  - [x] Implement `$PSCmdlet.ShouldProcess` for WhatIf support
  - [x] Add `Write-Verbose` logging throughout
  - [x] Return PSCustomObject with Id, SpaceKey, Name, HomepageId, TenantId
  - [x] Add comment-based help with examples

- [x] Task 2: Create ConvertTo-ConfluenceClientHomepage Private Function (AC: 2)
  - [x] Create `Private/ConvertTo-ConfluenceClientHomepage.ps1` file
  - [x] Add `[CmdletBinding()]` attribute with Verbose support
  - [x] Add `-ClientName` parameter (string)
  - [x] Generate ADF heading "Welcome to {ClientName} Documentation"
  - [x] Generate "Overview" section heading and placeholder paragraph
  - [x] Generate "User Inventory" section heading and placeholder
  - [x] Generate "Endpoint Inventory" section heading and placeholder
  - [x] Generate "License Report" section heading and placeholder
  - [x] Generate "Security Reports" section heading and placeholder
  - [x] Generate "Collaboration" section heading and placeholder
  - [x] Add `Write-Verbose` logging
  - [x] Return valid ADF JSON string via `ConvertTo-ADF`

- [x] Task 3: Create Get-ConfluenceTenantMapping Helper Function (AC: 3, 8)
  - [x] Create `Private/Get-ConfluenceTenantMapping.ps1` file
  - [x] Add `[CmdletBinding()]` attribute
  - [x] Add `-TenantId` parameter (optional string)
  - [x] Query Azure Table Storage for ConfluenceMapping partition
  - [x] Return mappings as PSCustomObject array
  - [x] Support filtering by TenantId if provided

- [x] Task 4: Create Set-ConfluenceTenantMapping Helper Function (AC: 3)
  - [x] Create `Private/Set-ConfluenceTenantMapping.ps1` file
  - [x] Add `[CmdletBinding(SupportsShouldProcess)]` attribute
  - [x] Add `-TenantId`, `-SpaceKey`, `-SpaceName` parameters
  - [x] Add entity to Azure Table Storage with PartitionKey 'ConfluenceMapping'
  - [x] Use Add-CIPPAzDataTableEntity pattern from Hudu module
  - [x] Support WhatIf through ShouldProcess

- [x] Task 5: Create Unit Tests for New-ConfluenceClientSpace (AC: 1-9)
  - [x] Create `Tests/Public/New-ConfluenceClientSpace.Tests.ps1`
  - [x] Test: Creates space with correct parameters (AC1) - 7 tests
  - [x] Test: Returns PSCustomObject with expected properties (AC1)
  - [x] Test: Calls Set-ConfluencePage with homepage content (AC2) - 4 tests
  - [x] Test: Stores mapping in Azure Table (AC3) - 5 tests
  - [x] Test: Does not create space with WhatIf (AC4) - 4 tests
  - [x] Test: Returns null with WhatIf (AC4)
  - [x] Test: Writes verbose messages (AC5) - 3 tests
  - [x] Test: Throws error for invalid SpaceKey format (AC6) - 7 tests
  - [x] Test: Throws error for existing SpaceKey (AC7) - 3 tests
  - [x] Test: Throws error for existing TenantId mapping (AC8) - 4 tests
  - [x] Test: Accepts optional Description (AC9) - 3 tests
  - [x] Test: Transactional flow (bonus) - 2 tests

- [x] Task 6: Create Unit Tests for ConvertTo-ConfluenceClientHomepage (AC: 2)
  - [x] Create `Tests/Private/ConvertTo-ConfluenceClientHomepage.Tests.ps1`
  - [x] Test: Returns valid ADF JSON string
  - [x] Test: Includes client name in welcome heading
  - [x] Test: Includes all section headings (6 tests)
  - [x] Test: Includes placeholder text for each section (6 tests)
  - [x] Test: Verbose output (2 tests)
  - [x] Test: Special characters handling (3 tests)

- [x] Task 7: Run Validation (AC: 1-9)
  - [x] Run `Invoke-ScriptAnalyzer` on all 4 functions - 0 warnings
  - [x] Run all Pester tests - 63 tests passing (42 + 21)
  - [x] Verify all existing tests still pass (regression check)

## Dev Notes

### Architecture Compliance

**Module Locations:**
- `Modules/ConfluenceAPI/Public/New-ConfluenceClientSpace.ps1` - Main public function
- `Modules/ConfluenceAPI/Private/ConvertTo-ConfluenceClientHomepage.ps1` - Homepage ADF generator
- `Modules/ConfluenceAPI/Private/Get-ConfluenceTenantMapping.ps1` - Mapping retrieval
- `Modules/ConfluenceAPI/Private/Set-ConfluenceTenantMapping.ps1` - Mapping storage

Per architecture.md (lines 308-312), CIPP integration functions are in Public/:
- [Source: docs/architecture.md#Project-Structure-Boundaries] - `New-ConfluenceClientSpace` in Public/
- [Source: docs/epics.md#Story-7.1] - Acceptance criteria define space creation and mapping

**Dependencies:**
- `New-ConfluenceSpace` (Story 2.2) - for creating the Confluence space
- `Get-ConfluenceSpace` (Story 2.2) - for checking if space exists
- `Set-ConfluencePage` (Story 2.3) - for updating homepage content
- `New-ADFDocument` (Story 3.1) - for creating ADF root structure
- `Add-ADFContent` (Story 3.1) - for adding content nodes
- `ConvertTo-ADF` (Story 3.1) - for JSON serialization
- `New-ADFHeading` (Story 3.3) - for section headings
- `New-ADFParagraph` (Story 3.3) - for placeholder text
- Azure Table Storage functions from CIPP framework

### CRITICAL: Azure Table Storage Pattern (from Epic 6 Retrospective)

This story uses **Azure Data Table Storage** for tenant-to-space mappings, following CIPP's established Hudu module pattern.

**Reference Implementation:**
- `Modules/CippExtensions/Public/Hudu/Get-HuduMapping.ps1`
- `Modules/CippExtensions/Public/Hudu/Set-HuduMapping.ps1`
- `Modules/CippExtensions/Public/Extension Functions/Get-ExtensionMapping.ps1`

**Mapping Storage Pattern:**

| Component | Hudu Pattern | Confluence Equivalent |
|-----------|--------------|----------------------|
| **Table** | `CippMapping` | `CippMapping` (same table) |
| **Partition Key** | `'HuduMapping'` | `'ConfluenceMapping'` |
| **Row Key** | Tenant ID | Tenant ID |
| **Properties** | `IntegrationId`, `IntegrationName` | `SpaceKey`, `SpaceName` |

**Key Code Pattern from Hudu:**

```powershell
# Get mapping (from Get-HuduMapping.ps1)
$ExtensionMappings = Get-ExtensionMapping -Extension 'Hudu'

# Set mapping (from Set-HuduMapping.ps1)
$AddObject = @{
    PartitionKey    = 'HuduMapping'
    RowKey          = "$($mapping.TenantId)"
    IntegrationId   = "$($mapping.IntegrationId)"
    IntegrationName = "$($mapping.IntegrationName)"
}
Add-CIPPAzDataTableEntity @CIPPMapping -Entity $AddObject -Force
```

**Confluence Equivalent:**

```powershell
# Get Confluence mapping
$AddObject = @{
    PartitionKey = 'ConfluenceMapping'
    RowKey       = "$TenantId"
    SpaceKey     = "$SpaceKey"
    SpaceName    = "$ClientName"
}
Add-CIPPAzDataTableEntity @CIPPMapping -Entity $AddObject -Force
```

### SpaceKey Validation Pattern

SpaceKey must meet Confluence requirements:
- 1-255 characters
- Only uppercase letters (A-Z) and numbers (0-9)
- Must start with a letter
- No spaces or special characters

```powershell
# Validation pattern - MUST use -cnotmatch for case-sensitive matching
# PowerShell's -notmatch is case-insensitive by default!
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

### Homepage ADF Structure

Standard homepage structure for client spaces:

```powershell
function ConvertTo-ConfluenceClientHomepage {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$ClientName
    )

    Write-Verbose "Generating homepage content for '$ClientName'"

    $doc = New-ADFDocument

    # Welcome heading
    $welcome = New-ADFHeading -Level 1 -Text "Welcome to $ClientName Documentation"

    # Overview section
    $overviewHeading = New-ADFHeading -Level 2 -Text 'Overview'
    $overviewText = New-ADFParagraph -Text 'This space contains automated documentation for your Microsoft 365 environment.'

    # User Inventory placeholder
    $userHeading = New-ADFHeading -Level 2 -Text 'User Inventory'
    $userText = New-ADFParagraph -Text 'User inventory data will appear here after sync.'

    # Endpoint Inventory placeholder
    $endpointHeading = New-ADFHeading -Level 2 -Text 'Endpoint Inventory'
    $endpointText = New-ADFParagraph -Text 'Endpoint inventory data will appear here after sync.'

    # License Report placeholder
    $licenseHeading = New-ADFHeading -Level 2 -Text 'License Report'
    $licenseText = New-ADFParagraph -Text 'License report data will appear here after sync.'

    # Security Reports placeholder
    $securityHeading = New-ADFHeading -Level 2 -Text 'Security Reports'
    $securityText = New-ADFParagraph -Text 'MFA status and security reports will appear here after sync.'

    # Collaboration placeholder
    $collabHeading = New-ADFHeading -Level 2 -Text 'Collaboration'
    $collabText = New-ADFParagraph -Text 'Teams and SharePoint inventory will appear here after sync.'

    # Assemble document
    $doc = Add-ADFContent -Document $doc -Content @(
        $welcome,
        $overviewHeading, $overviewText,
        $userHeading, $userText,
        $endpointHeading, $endpointText,
        $licenseHeading, $licenseText,
        $securityHeading, $securityText,
        $collabHeading, $collabText
    )

    Write-Verbose "Generated homepage with 6 sections"
    return ConvertTo-ADF -InputObject $doc
}
```

### New-ConfluenceClientSpace Pattern

```powershell
function New-ConfluenceClientSpace {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$SpaceKey,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ClientName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$TenantId,

        [Parameter()]
        [string]$Description
    )

    Write-Verbose "Creating client space '$SpaceKey' for tenant '$TenantId'"

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

    # Check if space already exists
    Write-Verbose "Checking if space '$SpaceKey' already exists"
    $existingSpace = Get-ConfluenceSpace -SpaceKey $SpaceKey -ErrorAction SilentlyContinue
    if ($existingSpace) {
        $PSCmdlet.ThrowTerminatingError(
            [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new("Space '$SpaceKey' already exists. Use Get-ConfluenceSpace to verify."),
                "SpaceAlreadyExists",
                [System.Management.Automation.ErrorCategory]::ResourceExists,
                $SpaceKey
            )
        )
    }

    # Check if TenantId already has a mapping
    Write-Verbose "Checking if tenant '$TenantId' already has a mapping"
    $existingMapping = Get-ConfluenceTenantMapping -TenantId $TenantId
    if ($existingMapping) {
        $PSCmdlet.ThrowTerminatingError(
            [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new("Tenant '$TenantId' is already mapped to space '$($existingMapping.SpaceKey)'. Use Get-ConfluenceTenantMapping to verify."),
                "TenantAlreadyMapped",
                [System.Management.Automation.ErrorCategory]::ResourceExists,
                $TenantId
            )
        )
    }

    if ($PSCmdlet.ShouldProcess("$ClientName ($SpaceKey)", "Create Confluence client space")) {
        # Create the space
        Write-Verbose "Creating Confluence space '$SpaceKey' with name '$ClientName'"
        $createParams = @{
            SpaceKey = $SpaceKey
            Name     = $ClientName
        }
        if ($Description) {
            $createParams['Description'] = $Description
        }
        $space = New-ConfluenceSpace @createParams

        # Generate and update homepage content
        Write-Verbose "Generating homepage content for '$ClientName'"
        $homepageContent = ConvertTo-ConfluenceClientHomepage -ClientName $ClientName

        Write-Verbose "Updating homepage (ID: $($space.HomepageId)) with standard structure"
        Set-ConfluencePage -PageId $space.HomepageId -Body $homepageContent | Out-Null

        # Store the tenant-to-space mapping
        Write-Verbose "Storing tenant-to-space mapping for '$TenantId' -> '$SpaceKey'"
        Set-ConfluenceTenantMapping -TenantId $TenantId -SpaceKey $SpaceKey -SpaceName $ClientName

        Write-Verbose "Successfully created client space '$SpaceKey' for tenant '$TenantId'"
        return [PSCustomObject]@{
            Id         = $space.Id
            SpaceKey   = $space.Key
            Name       = $space.Name
            HomepageId = $space.HomepageId
            TenantId   = $TenantId
        }
    }
}
```

### Get-ConfluenceTenantMapping Pattern

```powershell
function Get-ConfluenceTenantMapping {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [string]$TenantId
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

### Set-ConfluenceTenantMapping Pattern

```powershell
function Set-ConfluenceTenantMapping {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$TenantId,

        [Parameter(Mandatory)]
        [string]$SpaceKey,

        [Parameter(Mandatory)]
        [string]$SpaceName
    )

    Write-Verbose "Setting tenant mapping: '$TenantId' -> '$SpaceKey'"

    if ($PSCmdlet.ShouldProcess($TenantId, "Create Confluence tenant mapping")) {
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

### Previous Story Intelligence (Epic 6 Learnings)

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
   - Reference related functions (e.g., "Use Get-ConfluenceSpace to verify")

3. **Test Isolation Pattern:**
   - Mock all dependencies (Get-ConfluenceSpace, New-ConfluenceSpace, etc.)
   - Mock Azure Table Storage functions (Get-CIPPTable, Get-CIPPAzDataTableEntity, Add-CIPPAzDataTableEntity)
   - Use `$script:capturedX` pattern to verify parameters passed

4. **WhatIf Support:**
   - Return nothing when WhatIf is used
   - Ensure no API calls or storage operations occur with WhatIf

### CIPP Azure Table Storage Functions

These CIPP framework functions are used for tenant mapping storage:

- `Get-CIPPTable -TableName 'CippMapping'` - Returns table reference
- `Get-CIPPAzDataTableEntity @Table -Filter "..."` - Query entities
- `Add-CIPPAzDataTableEntity @Table -Entity $obj -Force` - Add/update entity
- `Remove-AzDataTableEntity -Force @Table -Entity $entity` - Delete entity (for Story 7.2)

### Testing Pattern

```powershell
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $here)) 'Public'
$privateDir = Join-Path (Split-Path -Parent (Split-Path -Parent $here)) 'Private'

Describe 'New-ConfluenceClientSpace' {
    BeforeAll {
        # Define stub functions for dependencies
        function Get-ConfluenceSpace { param($SpaceKey) }
        function New-ConfluenceSpace { param($SpaceKey, $Name, $Description) }
        function Set-ConfluencePage { param($PageId, $Body) }
        function Get-CIPPTable { param($TableName) }
        function Get-CIPPAzDataTableEntity { param($Filter) }
        function Add-CIPPAzDataTableEntity { param($Entity, $Force) }

        # Dot-source dependencies
        . "$privateDir\ConvertTo-ConfluenceClientHomepage.ps1"
        . "$privateDir\Get-ConfluenceTenantMapping.ps1"
        . "$privateDir\Set-ConfluenceTenantMapping.ps1"
        . "$publicDir\New-ConfluenceClientSpace.ps1"
    }

    Context 'Space Creation' {
        BeforeEach {
            Mock Get-ConfluenceSpace { return $null }
            Mock Get-CIPPTable { return @{ TableName = 'CippMapping' } }
            Mock Get-CIPPAzDataTableEntity { return $null }
            Mock New-ConfluenceSpace {
                [PSCustomObject]@{
                    Id = 'space-123'
                    Key = $SpaceKey
                    Name = $Name
                    HomepageId = 'page-456'
                }
            }
            Mock Set-ConfluencePage { }
            Mock Add-CIPPAzDataTableEntity { }
        }

        It 'Creates space with correct parameters' {
            $result = New-ConfluenceClientSpace -SpaceKey 'CONTOSO' -ClientName 'Contoso Corp' -TenantId 'abc-123'
            Assert-MockCalled New-ConfluenceSpace -Scope It -ParameterFilter {
                $SpaceKey -eq 'CONTOSO' -and $Name -eq 'Contoso Corp'
            }
        }

        It 'Returns PSCustomObject with expected properties' {
            $result = New-ConfluenceClientSpace -SpaceKey 'CONTOSO' -ClientName 'Contoso Corp' -TenantId 'abc-123'
            $result.SpaceKey | Should Be 'CONTOSO'
            $result.TenantId | Should Be 'abc-123'
        }
    }

    Context 'WhatIf Support' {
        It 'Does not create space with WhatIf' {
            Mock Get-ConfluenceSpace { return $null }
            Mock Get-CIPPTable { return @{ TableName = 'CippMapping' } }
            Mock Get-CIPPAzDataTableEntity { return $null }
            Mock New-ConfluenceSpace { }

            New-ConfluenceClientSpace -SpaceKey 'TEST' -ClientName 'Test' -TenantId 'test-id' -WhatIf
            Assert-MockCalled New-ConfluenceSpace -Times 0 -Scope It
        }
    }

    Context 'Validation' {
        It 'Throws error for invalid SpaceKey format' {
            { New-ConfluenceClientSpace -SpaceKey 'invalid key' -ClientName 'Test' -TenantId 'test' } |
                Should Throw "SpaceKey"
        }
    }
}
```

### Project Structure Notes

**Files to Create:**
```text
Modules/ConfluenceAPI/
├── Private/
│   ├── ConvertTo-ConfluenceClientHomepage.ps1    # CREATE
│   ├── Get-ConfluenceTenantMapping.ps1           # CREATE
│   └── Set-ConfluenceTenantMapping.ps1           # CREATE
├── Public/
│   └── New-ConfluenceClientSpace.ps1             # CREATE
└── Tests/
    ├── Private/
    │   └── ConvertTo-ConfluenceClientHomepage.Tests.ps1  # CREATE
    └── Public/
        └── New-ConfluenceClientSpace.Tests.ps1           # CREATE
```

**No manifest update needed** - Private functions are auto-loaded by psm1 module loader, Public functions are auto-exported.

### Common Mistakes to Avoid

1. **DO NOT** use lowercase letters in SpaceKey - Confluence requires uppercase
2. **DO NOT** forget to validate SpaceKey format before API calls
3. **DO NOT** forget to check for existing space before creation
4. **DO NOT** forget to check for existing tenant mapping before creation
5. **DO NOT** return anything when WhatIf is used
6. **DO NOT** forget `SupportsShouldProcess` attribute
7. **DO NOT** use `throw` directly - use `$PSCmdlet.ThrowTerminatingError()`
8. **DO NOT** forget `Write-Verbose` for all significant operations
9. **DO NOT** use `Should -Invoke` - use `Assert-MockCalled` (Pester 3.4)
10. **DO NOT** forget to mock Azure Table Storage functions in tests
11. **DO NOT** create tenant mapping if space creation fails (transactional flow)
12. **DO NOT** hardcode table names - use `Get-CIPPTable -TableName 'CippMapping'`

### References

- [Source: docs/architecture.md#Project-Structure-Boundaries] - Public function location
- [Source: docs/architecture.md#CIPP-Integration] - Integration patterns
- [Source: docs/epics.md#Story-7.1] - Acceptance criteria
- [Source: docs/prd.md#Space-Management] - FR5, FR6 requirements
- [Source: docs/sprint-artifacts/epic-6-retro-2025-12-14.md#Key-Discovery] - Azure Table Storage pattern
- [Source: Modules/CippExtensions/Public/Hudu/Get-HuduMapping.ps1] - Hudu mapping pattern
- [Source: Modules/CippExtensions/Public/Hudu/Set-HuduMapping.ps1] - Hudu mapping storage pattern
- [Confluence REST API - Create Space](https://developer.atlassian.com/cloud/confluence/rest/v2/api-group-space/#api-spaces-post)

### FRs Covered

- **FR5**: Technical Lead can create a new Confluence space for a client (primary)
- **FR6**: Technical Lead can map a CIPP tenant to a Confluence space
- **NFR8**: No tenant data from one client must be visible to another client's Confluence space (tenant isolation)
- **NFR18**: Module must include -WhatIf support for all write operations
- **NFR19**: Module must include -Verbose logging for troubleshooting
- **NFR20**: Error messages must include actionable troubleshooting guidance

## Dev Agent Record

### Context Reference

<!-- Story context analysis completed by create-story workflow -->

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

### Completion Notes List

- Implementation follows CIPP Azure Table Storage pattern from Hudu module
- Uses `-cnotmatch` for case-sensitive SpaceKey validation (PowerShell default is case-insensitive)
- All 9 Acceptance Criteria fully implemented and tested
- Pester 3.4 syntax used for Windows PS 5.1 compatibility
- Helper functions (Get/Set-ConfluenceTenantMapping) tested indirectly through main function

### File List

| File | Action | Description |
|------|--------|-------------|
| `Modules/ConfluenceAPI/Public/New-ConfluenceClientSpace.ps1` | Created | Main public function for client space creation |
| `Modules/ConfluenceAPI/Private/ConvertTo-ConfluenceClientHomepage.ps1` | Created | ADF homepage generator with 6 sections |
| `Modules/ConfluenceAPI/Private/Get-ConfluenceTenantMapping.ps1` | Created | Azure Table tenant mapping retrieval |
| `Modules/ConfluenceAPI/Private/Set-ConfluenceTenantMapping.ps1` | Created | Azure Table tenant mapping storage |
| `Modules/ConfluenceAPI/Tests/Public/New-ConfluenceClientSpace.Tests.ps1` | Created | 42 unit tests for main function |
| `Modules/ConfluenceAPI/Tests/Private/ConvertTo-ConfluenceClientHomepage.Tests.ps1` | Created | 21 unit tests for homepage generator |
| `docs/sprint-artifacts/sprint-status.yaml` | Modified | Updated story status to done |

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2025-12-14 | Story created via create-story workflow | Claude Opus 4.5 |
| 2025-12-15 | Implementation complete: 4 functions, 63 tests, 0 PSScriptAnalyzer warnings | Claude Opus 4.5 |
| 2025-12-15 | Code review fixes: tasks marked complete, Dev Agent Record populated | Claude Opus 4.5 |
