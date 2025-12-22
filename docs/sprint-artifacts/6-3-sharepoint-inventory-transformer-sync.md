# Story 6.3: SharePoint Inventory Transformer & Sync

Status: done

## Story

As a **Technical Lead**,
I want **to sync SharePoint inventory from CIPP to Confluence**,
so that **storage resources are documented and visible to business staff for capacity planning**.

## Acceptance Criteria

### AC1: Create SharePoint Inventory Page (FR32)
**Given** I have CIPP SharePoint site data and a target space
**When** I run `Sync-ConfluenceSharePointInventory -SpaceKey 'CONTOSO' -SharePointData $cippSites`
**Then** a "SharePoint Inventory" page is created in the space
**And** the function returns a PSCustomObject with Id, Title, SpaceKey, Version, Action

### AC2: Update Existing SharePoint Inventory Page
**Given** a SharePoint Inventory page already exists in the space
**When** I run `Sync-ConfluenceSharePointInventory`
**Then** the existing page is updated with new content
**And** the page version is incremented
**And** Action returns 'Updated'

### AC3: Display Site URLs with Storage Usage (FR33)
**Given** I have SharePoint data with storage information
**When** the page content is generated
**Then** the table shows each site's URL and storage usage
**And** additional columns show site name, type, and last modified date

### AC4: Display Storage Summary Statistics
**Given** I have SharePoint data for multiple sites
**When** the page content is generated
**Then** a summary section shows total sites count and total storage used
**And** the summary is displayed before the detailed sites table

### AC5: Support -WhatIf (NFR18)
**Given** I want to preview sync operations
**When** I run `Sync-ConfluenceSharePointInventory -WhatIf`
**Then** no changes are made to Confluence
**And** the function returns null

### AC6: Support -Verbose Logging (NFR19)
**Given** I want detailed operation logging
**When** I run with `-Verbose`
**Then** the function logs: "Syncing SharePoint inventory to space 'X'"
**And** logs search results and page creation/update operations

### AC7: Validate Space Exists (Error Handling)
**Given** I specify a space that doesn't exist
**When** I run `Sync-ConfluenceSharePointInventory -SpaceKey 'INVALID'`
**Then** a terminating error is thrown
**And** the error message includes actionable guidance mentioning Get-ConfluenceSpace

### AC8: Handle Empty SharePoint Data
**Given** I have null or empty SharePoint data
**When** I run `Sync-ConfluenceSharePointInventory -SharePointData $null`
**Then** a page is still created with "No SharePoint data available" message
**And** no errors are thrown

### AC9: Support Parent Page Hierarchy
**Given** I want the page under a specific parent
**When** I run `Sync-ConfluenceSharePointInventory -ParentPageId '12345'`
**Then** the new page is created as a child of the parent
**And** existing pages are not moved (only applies to creation)

### AC10: Display Data Freshness Timestamp (FR44)
**Given** I have SharePoint data
**When** the page content is generated
**Then** a timestamp paragraph shows "Data as of: YYYY-MM-DD HH:mm UTC"
**And** the timestamp uses current UTC time when the function is called

## Tasks / Subtasks

- [x] Task 1: Create ConvertTo-ConfluenceSharePointPage Private Function (AC: 3, 4, 8, 10)
  - [x] Create `Private/ConvertTo-ConfluenceSharePointPage.ps1` file
  - [x] Add `[CmdletBinding()]` attribute with Verbose support
  - [x] Add `-SharePointData` parameter (object array)
  - [x] Generate ADF heading "SharePoint Inventory"
  - [x] Generate timestamp paragraph with UTC time (FR44)
  - [x] Generate summary section with total sites and storage
  - [x] Generate ADF table from SharePoint data using `New-ADFTable`
  - [x] Map Site Name from `displayName` or `name` property
  - [x] Map Site URL from `webUrl` property
  - [x] Map Site Type from `template` or `siteType` property
  - [x] Map Storage Used from `storageUsedInBytes` (convert to human-readable)
  - [x] Map Last Modified from `lastModifiedDateTime`
  - [x] Handle null/empty input with "No SharePoint data available" message
  - [x] Add `Write-Verbose` logging throughout
  - [x] Return valid ADF JSON string via `ConvertTo-ADF`

- [x] Task 2: Create ConvertTo-ConfluenceSharePointPage Unit Tests (AC: 3, 4, 8, 10)
  - [x] Create `Tests/Private/ConvertTo-ConfluenceSharePointPage.Tests.ps1`
  - [x] Test: Returns valid ADF JSON string
  - [x] Test: Creates table with correct columns (Site, URL, Type, Storage, Last Modified)
  - [x] Test: Maps displayName correctly
  - [x] Test: Maps webUrl correctly
  - [x] Test: Maps siteType variations (Team/Communication)
  - [x] Test: Converts storageUsedInBytes to human-readable format
  - [x] Test: Formats lastModifiedDateTime correctly
  - [x] Test: Generates summary section with correct counts
  - [x] Test: Includes timestamp (FR44)
  - [x] Test: Handles null SharePointData gracefully
  - [x] Test: Handles empty array gracefully
  - [x] Test: Verbose logging output

- [x] Task 3: Create Sync-ConfluenceSharePointInventory Public Function (AC: 1, 2, 5, 6, 7, 8, 9)
  - [x] Create `Public/Sync-ConfluenceSharePointInventory.ps1` file
  - [x] Add `[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]`
  - [x] Add `[OutputType([PSCustomObject])]` for return type
  - [x] Add `-SpaceKey` parameter (Mandatory string)
  - [x] Add `-SharePointData` parameter (object array)
  - [x] Add `-PageTitle` parameter (default: 'SharePoint Inventory')
  - [x] Add `-ParentPageId` parameter (optional string)
  - [x] Validate space exists using `Get-ConfluenceSpace`
  - [x] Generate ADF content using `ConvertTo-ConfluenceSharePointPage`
  - [x] Search for existing page using CQL with quote escaping
  - [x] Create page with `New-ConfluencePage` if not exists
  - [x] Update page with `Set-ConfluencePage` if exists
  - [x] Implement `$PSCmdlet.ShouldProcess` for WhatIf support
  - [x] Add `Write-Verbose` logging throughout
  - [x] Return PSCustomObject with Id, Title, SpaceKey, Version, Action
  - [x] Add comment-based help with examples

- [x] Task 4: Create Sync-ConfluenceSharePointInventory Unit Tests (AC: 1-9)
  - [x] Create `Tests/Public/Sync-ConfluenceSharePointInventory.Tests.ps1`
  - [x] Test: Creates page when none exists (AC1)
  - [x] Test: Returns PSCustomObject with correct properties (AC1)
  - [x] Test: Updates page when exists (AC2)
  - [x] Test: Increments version on update (AC2)
  - [x] Test: Does not create page with WhatIf (AC5)
  - [x] Test: Returns null with WhatIf (AC5)
  - [x] Test: Writes verbose messages (AC6)
  - [x] Test: Throws error for non-existent space (AC7)
  - [x] Test: Error message includes actionable guidance (AC7)
  - [x] Test: Handles null SharePointData without error (AC8)
  - [x] Test: Handles empty array without error (AC8)
  - [x] Test: Accepts ParentPageId parameter (AC9)
  - [x] Test: Passes ParentPageId to New-ConfluencePage (AC9)
  - [x] Test: Uses correct CQL query format
  - [x] Test: Escapes single quotes in CQL for safety

- [x] Task 5: Run Validation (AC: 1-10)
  - [x] Run `Invoke-ScriptAnalyzer -Path ./Modules/ConfluenceAPI/Private/ConvertTo-ConfluenceSharePointPage.ps1`
  - [x] Run `Invoke-ScriptAnalyzer -Path ./Modules/ConfluenceAPI/Public/Sync-ConfluenceSharePointInventory.ps1`
  - [x] Run all Pester tests (target: 0 new warnings)
  - [x] Verify all existing tests still pass (regression check)

## Dev Notes

### Architecture Compliance

**Module Locations:**
- `Modules/ConfluenceAPI/Private/ConvertTo-ConfluenceSharePointPage.ps1` - Data transformer
- `Modules/ConfluenceAPI/Public/Sync-ConfluenceSharePointInventory.ps1` - Public sync function

Per architecture.md (lines 314-330), data transformation functions are Private, sync functions are Public:
- [Source: docs/architecture.md#Project-Structure-Boundaries] - `ConvertTo-*` in Private/, `Sync-*` in Public/
- [Source: docs/epics.md#Story-6.3] - Acceptance criteria define both functions

**Dependencies:**
- `New-ADFDocument` (Story 3.1) - for creating ADF root structure
- `Add-ADFContent` (Story 3.1) - for adding content nodes
- `ConvertTo-ADF` (Story 3.1) - for JSON serialization
- `New-ADFTable` (Story 3.2) - for table generation
- `New-ADFHeading` (Story 3.3) - for section headings
- `New-ADFParagraph` (Story 3.3) - for timestamp and summary display
- `Get-ConfluenceSpace` (Story 2.2) - for space validation
- `Search-Confluence` (Story 2.6) - for existing page lookup
- `New-ConfluencePage` (Story 2.3) - for page creation
- `Set-ConfluencePage` (Story 2.3) - for page updates

### CRITICAL: Follow Epic 6 Patterns Exactly

Stories 6.1 (MFA) and 6.2 (Teams) established the exact patterns. This story follows:
1. **Private Transformer Pattern** (from Story 6.1/6.2) - `ConvertTo-ConfluenceSharePointPage`
2. **Public Sync Pattern** (from Story 6.1/6.2) - `Sync-ConfluenceSharePointInventory`

### CIPP SharePoint Data Structure

Expected CIPP SharePoint data object properties (based on Microsoft Graph/CIPP):

```powershell
[PSCustomObject]@{
    # Core Site Information
    id = 'site-guid-here'
    displayName = 'Marketing Team Site'
    name = 'marketing'  # fallback for displayName
    webUrl = 'https://contoso.sharepoint.com/sites/marketing'

    # Site Type/Template
    template = 'GROUP#0'  # Group-connected team site
    # OR siteType can be:
    siteType = 'TeamSite'  # or 'CommunicationSite', 'OneDrive'

    # Storage Information
    storageUsedInBytes = 5368709120  # 5 GB in bytes
    storageQuotaInBytes = 26843545600  # 25 GB quota (optional)

    # Timestamps
    lastModifiedDateTime = '2024-12-14T10:30:00Z'
    createdDateTime = '2024-01-15T08:00:00Z'

    # Additional Properties (optional)
    isPersonalSite = $false
    description = 'Marketing team collaboration site'
}
```

### Table Column Mapping

| Column | Source Property | Fallback | Display |
|--------|-----------------|----------|---------|
| Site | displayName | name, id | As-is |
| URL | webUrl | '' | Full URL |
| Type | siteType, template | 'Unknown' | Map to friendly name |
| Storage | storageUsedInBytes | 0 | Convert to human-readable (KB/MB/GB) |
| Last Modified | lastModifiedDateTime | '' | Format as 'yyyy-MM-dd' |

### Storage Size Conversion Helper

```powershell
# Convert bytes to human-readable format
function ConvertTo-HumanReadableSize {
    param([long]$Bytes)

    if ($Bytes -ge 1TB) {
        return "{0:N2} TB" -f ($Bytes / 1TB)
    }
    elseif ($Bytes -ge 1GB) {
        return "{0:N2} GB" -f ($Bytes / 1GB)
    }
    elseif ($Bytes -ge 1MB) {
        return "{0:N2} MB" -f ($Bytes / 1MB)
    }
    elseif ($Bytes -ge 1KB) {
        return "{0:N2} KB" -f ($Bytes / 1KB)
    }
    else {
        return "$Bytes B"
    }
}
```

**IMPORTANT:** Do NOT create a separate function. Inline this logic in the transformer since it's a one-time use pattern.

### Site Type Mapping

Map SharePoint site templates to friendly display names:

```powershell
$siteTypeDisplay = switch -Regex ($site.template) {
    'GROUP#0'      { 'Team Site' }
    'STS#3'        { 'Team Site' }
    'SITEPAGEPUBLISHING#0' { 'Communication Site' }
    'SPSPERS#'     { 'OneDrive' }
    default {
        if ($site.siteType) {
            switch ($site.siteType.ToLower()) {
                'teamsite' { 'Team Site' }
                'communicationsite' { 'Communication Site' }
                'onedrive' { 'OneDrive' }
                default { $site.siteType }
            }
        } else {
            'Unknown'
        }
    }
}
```

### ConvertTo-ConfluenceSharePointPage Pattern

```powershell
function ConvertTo-ConfluenceSharePointPage {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [object[]]$SharePointData
    )

    Write-Verbose "Transforming $($SharePointData.Count) SharePoint site record(s) to ADF content"

    # Handle empty input first
    if (-not $SharePointData -or $SharePointData.Count -eq 0) {
        Write-Verbose "No SharePoint data provided - returning empty state message"
        $doc = New-ADFDocument
        $heading = New-ADFHeading -Level 2 -Text 'SharePoint Inventory'
        # Add timestamp even for empty state (FR44 compliance)
        $utcTime = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm')
        $timestamp = New-ADFParagraph -Text "Data as of: $utcTime UTC"
        $message = New-ADFParagraph -Text 'No SharePoint data available'
        $doc = Add-ADFContent -Document $doc -Content @($heading, $timestamp, $message)
        return ConvertTo-ADF -InputObject $doc
    }

    # Create ADF document
    $doc = New-ADFDocument

    # Add heading
    $heading = New-ADFHeading -Level 2 -Text 'SharePoint Inventory'

    # Add timestamp (FR44)
    $utcTime = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm')
    $timestamp = New-ADFParagraph -Text "Data as of: $utcTime UTC"

    # Calculate summary statistics
    $totalSites = $SharePointData.Count
    $totalStorageBytes = ($SharePointData | Measure-Object -Property storageUsedInBytes -Sum).Sum
    if (-not $totalStorageBytes) { $totalStorageBytes = 0 }

    # Convert total storage to human-readable
    $totalStorageDisplay = if ($totalStorageBytes -ge 1TB) {
        "{0:N2} TB" -f ($totalStorageBytes / 1TB)
    } elseif ($totalStorageBytes -ge 1GB) {
        "{0:N2} GB" -f ($totalStorageBytes / 1GB)
    } elseif ($totalStorageBytes -ge 1MB) {
        "{0:N2} MB" -f ($totalStorageBytes / 1MB)
    } elseif ($totalStorageBytes -ge 1KB) {
        "{0:N2} KB" -f ($totalStorageBytes / 1KB)
    } else {
        "$totalStorageBytes B"
    }

    Write-Verbose "SharePoint inventory: $totalSites site(s), $totalStorageDisplay total storage"

    # Generate summary paragraph
    $summaryText = "Total Sites: $totalSites | Total Storage: $totalStorageDisplay"
    $summary = New-ADFParagraph -Text $summaryText

    # Transform to table format
    $tableData = foreach ($site in $SharePointData) {
        # Determine site name
        $siteName = if ($site.displayName) {
            $site.displayName
        } elseif ($site.name) {
            $site.name
        } elseif ($site.id) {
            $site.id
        } else {
            'Unknown Site'
        }

        # Get URL
        $siteUrl = if ($site.webUrl) { $site.webUrl } else { '' }

        # Determine site type
        $siteType = if ($site.template) {
            switch -Regex ($site.template) {
                'GROUP#0' { 'Team Site' }
                'STS#3' { 'Team Site' }
                'SITEPAGEPUBLISHING#0' { 'Communication Site' }
                'SPSPERS#' { 'OneDrive' }
                default {
                    if ($site.siteType) { $site.siteType } else { 'Other' }
                }
            }
        } elseif ($site.siteType) {
            $type = $site.siteType.ToString()
            switch ($type.ToLower()) {
                'teamsite' { 'Team Site' }
                'communicationsite' { 'Communication Site' }
                'onedrive' { 'OneDrive' }
                default { $type }
            }
        } else {
            'Unknown'
        }

        # Convert storage to human-readable
        $storageBytes = if ($null -ne $site.storageUsedInBytes) {
            [long]$site.storageUsedInBytes
        } else {
            0
        }

        $storageDisplay = if ($storageBytes -ge 1TB) {
            "{0:N2} TB" -f ($storageBytes / 1TB)
        } elseif ($storageBytes -ge 1GB) {
            "{0:N2} GB" -f ($storageBytes / 1GB)
        } elseif ($storageBytes -ge 1MB) {
            "{0:N2} MB" -f ($storageBytes / 1MB)
        } elseif ($storageBytes -ge 1KB) {
            "{0:N2} KB" -f ($storageBytes / 1KB)
        } else {
            "$storageBytes B"
        }

        # Format last modified date
        $lastModified = if ($site.lastModifiedDateTime) {
            try {
                $date = [datetime]::Parse($site.lastModifiedDateTime)
                $date.ToString('yyyy-MM-dd')
            } catch {
                $site.lastModifiedDateTime.ToString().Substring(0, 10)
            }
        } else {
            ''
        }

        [PSCustomObject]@{
            'Site'          = $siteName
            'URL'           = $siteUrl
            'Type'          = $siteType
            'Storage'       = $storageDisplay
            'Last Modified' = $lastModified
        }
    }

    # Create table
    $table = New-ADFTable -InputObject $tableData -Property 'Site', 'URL', 'Type', 'Storage', 'Last Modified'

    # Assemble document
    $doc = Add-ADFContent -Document $doc -Content @($heading, $timestamp, $summary, $table)

    Write-Verbose "Created SharePoint inventory page with $totalSites site(s)"
    return ConvertTo-ADF -InputObject $doc
}
```

### Sync-ConfluenceSharePointInventory Pattern

Follow exact pattern from `Sync-ConfluenceMFAReport.ps1` and `Sync-ConfluenceTeamsInventory.ps1`:

```powershell
function Sync-ConfluenceSharePointInventory {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string]$SpaceKey,

        [Parameter()]
        [object[]]$SharePointData,

        [Parameter()]
        [string]$PageTitle = 'SharePoint Inventory',

        [Parameter()]
        [string]$ParentPageId
    )

    Write-Verbose "Syncing SharePoint inventory to space '$SpaceKey'"

    # Validate space exists (same pattern as Story 6.1/6.2)
    $space = Get-ConfluenceSpace -SpaceKey $SpaceKey -ErrorAction SilentlyContinue
    if (-not $space) {
        $PSCmdlet.ThrowTerminatingError(
            [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new("Space '$SpaceKey' not found. Use Get-ConfluenceSpace to list available spaces."),
                "SpaceNotFound",
                [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                $SpaceKey
            )
        )
    }

    # Generate ADF content
    $adfContent = ConvertTo-ConfluenceSharePointPage -SharePointData $SharePointData
    $siteCount = if ($SharePointData) { $SharePointData.Count } else { 0 }
    Write-Verbose "Generated ADF content for $siteCount site(s)"

    # Search for existing page (CQL injection protection)
    $escapedSpaceKey = $SpaceKey -replace "'", "''"
    $escapedTitle = $PageTitle -replace "'", "''"
    $cql = "space = '$escapedSpaceKey' AND title = '$escapedTitle' AND type = page"
    Write-Verbose "Searching for existing page with CQL: $cql"
    $existingPage = Search-Confluence -CQL $cql | Select-Object -First 1

    if ($existingPage) {
        Write-Verbose "Found existing page (ID: $($existingPage.Id)) - updating"
        if ($PSCmdlet.ShouldProcess($PageTitle, "Update Confluence page")) {
            $result = Set-ConfluencePage -PageId $existingPage.Id -Body $adfContent
            Write-Verbose "Successfully updated page '$PageTitle' (ID: $($result.Id), Version: $($result.Version.Number))"
            return [PSCustomObject]@{
                Id       = $result.Id
                Title    = $result.Title
                SpaceKey = $SpaceKey
                Version  = $result.Version.Number
                Action   = 'Updated'
            }
        }
    }
    else {
        Write-Verbose "No existing page found - creating new page"
        if ($PSCmdlet.ShouldProcess($PageTitle, "Create Confluence page")) {
            $createParams = @{
                SpaceKey = $SpaceKey
                Title    = $PageTitle
                Body     = $adfContent
            }
            if ($ParentPageId) {
                $createParams['ParentId'] = $ParentPageId
                Write-Verbose "Creating page under parent ID: $ParentPageId"
            }
            $result = New-ConfluencePage @createParams
            Write-Verbose "Successfully created page '$PageTitle' (ID: $($result.Id))"
            return [PSCustomObject]@{
                Id       = $result.Id
                Title    = $result.Title
                SpaceKey = $SpaceKey
                Version  = $result.Version.Number
                Action   = 'Created'
            }
        }
    }
}
```

### Previous Story Intelligence (Story 6.1 & 6.2 Learnings)

**Key Learnings to Apply:**

1. **Pester 3.4 Syntax (CRITICAL):**
   - Use `Should Be` (no hyphen) for Windows PS 5.1 compatibility
   - Use `Should Not Be $null` for null checks
   - Use `Assert-MockCalled` (NOT `Should -Invoke`) with `-Scope It`
   - Define stub functions before mocking
   - Dot-source function under test in BeforeAll

2. **UTC Timestamp (Story 5.1 Fix):**
   - Use `(Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm')` for actual UTC
   - NOT `Get-Date -Format` which uses local time

3. **CQL Escaping (Story 4.2 Fix):**
   - Escape single quotes: `$SpaceKey -replace "'", "''"`
   - Prevents CQL injection attacks

4. **Empty State Handling:**
   - Always include timestamp even in empty state (Story 5.3 fix)
   - Return "No SharePoint data available" message, not error

5. **Test Isolation Pattern:**
   - Mock all dependencies (Get-ConfluenceSpace, Search-Confluence, etc.)
   - Use `$script:capturedX` pattern to verify parameters passed

6. **JSON Special Character Handling (Story 6.2 Fix):**
   - JSON escapes special characters (`&` becomes `\u0026`)
   - Test for individual words rather than exact string matches with special chars

### PowerShell Size Constants

```powershell
# Define size constants for storage conversion
1KB = 1024
1MB = 1024 * 1KB  # 1048576
1GB = 1024 * 1MB  # 1073741824
1TB = 1024 * 1GB  # 1099511627776
```

### Testing Pattern

```powershell
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$privateDir = Join-Path (Split-Path -Parent (Split-Path -Parent $here)) 'Private'

Describe 'ConvertTo-ConfluenceSharePointPage' {
    BeforeAll {
        # Dot-source dependencies
        . "$privateDir\New-ADFDocument.ps1"
        . "$privateDir\Add-ADFContent.ps1"
        . "$privateDir\ConvertTo-ADF.ps1"
        . "$privateDir\New-ADFTable.ps1"
        . "$privateDir\New-ADFHeading.ps1"
        . "$privateDir\New-ADFParagraph.ps1"
        . "$privateDir\ConvertTo-ConfluenceSharePointPage.ps1"
    }

    Context 'Empty/Null Input Handling' {
        It 'Returns valid ADF with message when SharePointData is null' {
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData $null
            $result | Should Not Be $null
            $result | Should Match 'No SharePoint data available'
        }

        It 'Includes timestamp even when SharePointData is empty' {
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData @()
            $result | Should Match 'Data as of:'
        }
    }

    Context 'Site Data Mapping' {
        It 'Maps displayName correctly' {
            $site = [PSCustomObject]@{
                displayName = 'Marketing Site'
                webUrl = 'https://contoso.sharepoint.com/sites/marketing'
            }
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData @($site)
            $result | Should Match 'Marketing Site'
        }

        It 'Maps webUrl correctly' {
            $site = [PSCustomObject]@{
                displayName = 'Test Site'
                webUrl = 'https://contoso.sharepoint.com/sites/test'
            }
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData @($site)
            $result | Should Match 'sharepoint.com'
        }

        It 'Converts storage bytes to GB correctly' {
            $site = [PSCustomObject]@{
                displayName = 'Test Site'
                storageUsedInBytes = 5368709120  # 5 GB
            }
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData @($site)
            $result | Should Match '5.00 GB'
        }
    }

    Context 'Summary Statistics' {
        It 'Calculates correct total sites count' {
            $sites = @(
                [PSCustomObject]@{ displayName = 'Site1' }
                [PSCustomObject]@{ displayName = 'Site2' }
                [PSCustomObject]@{ displayName = 'Site3' }
            )
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData $sites
            $result | Should Match 'Total Sites: 3'
        }
    }
}
```

### Project Structure Notes

**Files to Create:**
```text
Modules/ConfluenceAPI/
├── Private/
│   └── ConvertTo-ConfluenceSharePointPage.ps1    # CREATE
├── Public/
│   └── Sync-ConfluenceSharePointInventory.ps1    # CREATE
└── Tests/
    ├── Private/
    │   └── ConvertTo-ConfluenceSharePointPage.Tests.ps1  # CREATE
    └── Public/
        └── Sync-ConfluenceSharePointInventory.Tests.ps1  # CREATE
```

**No manifest update needed** - Private functions are auto-loaded by psm1 module loader, Public functions are auto-exported.

### Common Mistakes to Avoid

1. **DO NOT** forget to handle bytes-to-human-readable conversion for storage
2. **DO NOT** use a separate helper function - inline the conversion logic
3. **DO NOT** forget UTC timestamp (use `.ToUniversalTime()`)
4. **DO NOT** forget CQL single quote escaping for security
5. **DO NOT** forget space validation with actionable error message
6. **DO NOT** forget `SupportsShouldProcess` attribute
7. **DO NOT** return anything when WhatIf is used
8. **DO NOT** use `Should -Invoke` - use `Assert-MockCalled` (Pester 3.4)
9. **DO NOT** forget `Write-Verbose` for all significant operations
10. **DO NOT** move existing pages when ParentPageId is provided
11. **DO NOT** use `throw` directly - use `$PSCmdlet.ThrowTerminatingError()`
12. **DO NOT** forget to handle missing storageUsedInBytes (default to 0)
13. **DO NOT** forget to handle date parsing errors gracefully
14. **DO NOT** test special characters with exact string match (JSON escapes them)

### References

- [Source: docs/architecture.md#Project-Structure-Boundaries] - Private/Public function locations
- [Source: docs/architecture.md#Data-Flow] - Transformation and sync pipeline
- [Source: docs/epics.md#Story-6.3] - Acceptance criteria
- [Source: docs/prd.md#Data-Sync-Collaboration] - FR32-33 requirements
- [Source: docs/sprint-artifacts/6-2-teams-inventory-transformer-sync.md] - Pattern reference
- [Source: Modules/ConfluenceAPI/Public/Sync-ConfluenceTeamsInventory.ps1] - Direct pattern to follow
- [Source: Modules/ConfluenceAPI/Private/ConvertTo-ConfluenceTeamsPage.ps1] - Transformer pattern
- [Microsoft Graph SharePoint API](https://learn.microsoft.com/en-us/graph/api/resources/site)
- [CIPP SharePoint Report Documentation](https://docs.cipp.app/user-documentation/tenant/reports/sharepoint-report)

### FRs Covered

- **FR32**: System can sync SharePoint inventory from CIPP to Confluence (primary)
- **FR33**: System can display SharePoint sites with storage usage
- **FR44**: System can display data freshness timestamp on pages
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

- Created ConvertTo-ConfluenceSharePointPage private transformer function with:
  - Site name mapping with displayName/name/id fallbacks
  - Site type mapping from template (GROUP#0, STS#3, SITEPAGEPUBLISHING#0, SPSPERS#) or siteType property
  - Storage size conversion from bytes to human-readable format (B/KB/MB/GB/TB)
  - Last modified date formatting with error handling
  - Summary statistics (total sites count, total storage)
  - UTC timestamp for data freshness (FR44)
  - Empty state handling with "No SharePoint data available" message
- Created 58 unit tests for transformer covering all acceptance criteria
- Created Sync-ConfluenceSharePointInventory public sync function with:
  - Space validation with actionable error messages
  - CQL search with single quote escaping for security
  - Create/update logic with SupportsShouldProcess
  - ParentPageId support for page hierarchy
- Created 29 unit tests for sync function covering AC1-AC9
- PSScriptAnalyzer: 0 warnings on both files
- Full regression test suite: 949 tests passed, 0 failed

### File List

- Modules/ConfluenceAPI/Private/ConvertTo-ConfluenceSharePointPage.ps1 (NEW)
- Modules/ConfluenceAPI/Public/Sync-ConfluenceSharePointInventory.ps1 (NEW)
- Modules/ConfluenceAPI/Tests/Private/ConvertTo-ConfluenceSharePointPage.Tests.ps1 (NEW)
- Modules/ConfluenceAPI/Tests/Public/Sync-ConfluenceSharePointInventory.Tests.ps1 (NEW)
- docs/sprint-artifacts/6-3-sharepoint-inventory-transformer-sync.md (MODIFIED)
- docs/sprint-artifacts/sprint-status.yaml (MODIFIED)

## Senior Developer Review (AI)

**Reviewer:** Claude Opus 4.5 (code-review workflow)
**Date:** 2025-12-14
**Outcome:** ✅ APPROVED with minor fixes applied

### Review Summary

| Category | Count |
|----------|-------|
| Critical Issues | 0 |
| High Issues | 0 |
| Medium Issues | 3 (2 informational, 1 fixed) |
| Low Issues | 4 (2 fixed) |

### Issues Found and Resolved

1. **[MEDIUM] Story file not tracked in git** - IDENTIFIED
   - Story file was never staged in git
   - Will be included in commit with implementation files

2. **[MEDIUM] Duplicate storage conversion code** - ACKNOWLEDGED
   - Storage bytes-to-human-readable logic duplicated (lines 89-99 and 153-163)
   - Per Dev Notes guidance, this is intentional to avoid separate helper function
   - No action needed

3. **[LOW] Missing test for template priority over siteType** - FIXED
   - Added test case "Template takes priority over siteType when both are present"
   - Verifies SITEPAGEPUBLISHING#0 template overrides TeamSite siteType

4. **[LOW] Missing verbose logging for transformer call** - FIXED
   - Added "Transforming N SharePoint site(s) to ADF content" before transformer call
   - Improves debugging trace flow

### Acceptance Criteria Validation

All 10 Acceptance Criteria verified as IMPLEMENTED:
- AC1-AC9: Sync function tests confirm all behaviors
- AC10 (FR44): Timestamp tests confirm UTC format

### Task Audit

All 5 tasks verified as ACTUALLY COMPLETED:
- ✅ Task 1: ConvertTo-ConfluenceSharePointPage (200 lines)
- ✅ Task 2: Transformer tests (59 tests after fix)
- ✅ Task 3: Sync-ConfluenceSharePointInventory (151 lines)
- ✅ Task 4: Sync tests (29 tests)
- ✅ Task 5: Validation passed

### Files Modified During Review

- `Modules/ConfluenceAPI/Tests/Private/ConvertTo-ConfluenceSharePointPage.Tests.ps1` - Added 1 test
- `Modules/ConfluenceAPI/Public/Sync-ConfluenceSharePointInventory.ps1` - Added verbose logging

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2025-12-14 | Story created via create-story workflow | Claude Opus 4.5 |
| 2025-12-14 | Implementation complete - all tasks done, 87 new tests passing | Claude Opus 4.5 |
| 2025-12-14 | Code review completed - 2 fixes applied, approved | Claude Opus 4.5 |
