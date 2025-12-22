# Story 6.1: MFA Status Transformer & Sync

Status: done

## Story

As a **Technical Lead**,
I want **to sync MFA status reports from CIPP to Confluence**,
so that **security posture is visible in client documentation**.

## Acceptance Criteria

### AC1: Create MFA Status Page (FR27)
**Given** I have CIPP MFA status data and a target space
**When** I run `Sync-ConfluenceMFAReport -SpaceKey 'CONTOSO' -MFAData $cippMFA`
**Then** an "MFA Status" page is created in the space
**And** the function returns a PSCustomObject with Id, Title, SpaceKey, Version, Action

### AC2: Update Existing MFA Status Page
**Given** an MFA Status page already exists in the space
**When** I run `Sync-ConfluenceMFAReport`
**Then** the existing page is updated with new content
**And** the page version is incremented
**And** Action returns 'Updated'

### AC3: Display MFA Enabled/Disabled Per User (FR28)
**Given** I have MFA data with user status
**When** the page content is generated
**Then** the table shows each user's MFA status (Enabled/Disabled/Enforced)
**And** users without MFA are clearly identified

### AC4: Display MFA Methods Configured (FR29)
**Given** I have MFA data with authentication methods
**When** the page content is generated
**Then** the table includes a column showing configured MFA methods
**And** methods are displayed as comma-separated list (e.g., "Authenticator App, Phone")

### AC5: Display MFA Coverage Summary
**Given** I have MFA data for multiple users
**When** the page content is generated
**Then** a summary section shows total users, MFA-enabled count, and percentage
**And** the summary is displayed before the detailed user table

### AC6: Support -WhatIf (NFR18)
**Given** I want to preview sync operations
**When** I run `Sync-ConfluenceMFAReport -WhatIf`
**Then** no changes are made to Confluence
**And** the function returns null

### AC7: Support -Verbose Logging (NFR19)
**Given** I want detailed operation logging
**When** I run with `-Verbose`
**Then** the function logs: "Syncing MFA report to space 'X'"
**And** logs search results and page creation/update operations

### AC8: Validate Space Exists (Error Handling)
**Given** I specify a space that doesn't exist
**When** I run `Sync-ConfluenceMFAReport -SpaceKey 'INVALID'`
**Then** a terminating error is thrown
**And** the error message includes actionable guidance mentioning Get-ConfluenceSpace

### AC9: Handle Empty MFA Data
**Given** I have null or empty MFA data
**When** I run `Sync-ConfluenceMFAReport -MFAData $null`
**Then** a page is still created with "No MFA data available" message
**And** no errors are thrown

### AC10: Support Parent Page Hierarchy
**Given** I want the page under a specific parent
**When** I run `Sync-ConfluenceMFAReport -ParentPageId '12345'`
**Then** the new page is created as a child of the parent
**And** existing pages are not moved (only applies to creation)

### AC11: Display Data Freshness Timestamp (FR44)
**Given** I have MFA data
**When** the page content is generated
**Then** a timestamp paragraph shows "Data as of: YYYY-MM-DD HH:mm UTC"
**And** the timestamp uses current UTC time when the function is called

## Tasks / Subtasks

- [x] Task 1: Create ConvertTo-ConfluenceMFAPage Private Function (AC: 3, 4, 5, 9, 11)
  - [x] Create `Private/ConvertTo-ConfluenceMFAPage.ps1` file
  - [x] Add `[CmdletBinding()]` attribute with Verbose support
  - [x] Add `-MFAData` parameter (object array)
  - [x] Generate ADF heading "MFA Status Report"
  - [x] Generate timestamp paragraph with UTC time (FR44)
  - [x] Generate summary section with total users, MFA-enabled count, percentage
  - [x] Generate ADF table from MFA data using `New-ADFTable`
  - [x] Map DisplayName from `displayName` or `userPrincipalName` property
  - [x] Map MFA Status with Enabled/Disabled/Enforced logic
  - [x] Map MFA Methods as comma-separated list
  - [x] Map Per-User MFA status
  - [x] Map Security Defaults coverage
  - [x] Map Conditional Access coverage
  - [x] Handle null/empty input with "No MFA data available" message
  - [x] Add `Write-Verbose` logging throughout
  - [x] Return valid ADF JSON string via `ConvertTo-ADF`

- [x] Task 2: Create ConvertTo-ConfluenceMFAPage Unit Tests (AC: 3, 4, 5, 9, 11)
  - [x] Create `Tests/Private/ConvertTo-ConfluenceMFAPage.Tests.ps1`
  - [x] Test: Returns valid ADF JSON string
  - [x] Test: Creates table with correct columns
  - [x] Test: Maps DisplayName correctly
  - [x] Test: Maps MFA Status variations (Enabled/Disabled/Enforced)
  - [x] Test: Maps MFA Methods as comma-separated list
  - [x] Test: Generates summary section with correct counts
  - [x] Test: Calculates percentage correctly
  - [x] Test: Includes timestamp (FR44)
  - [x] Test: Handles null MFAData gracefully
  - [x] Test: Handles empty array gracefully
  - [x] Test: Verbose logging output

- [x] Task 3: Create Sync-ConfluenceMFAReport Public Function (AC: 1, 2, 6, 7, 8, 9, 10)
  - [x] Create `Public/Sync-ConfluenceMFAReport.ps1` file
  - [x] Add `[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]`
  - [x] Add `[OutputType([PSCustomObject])]` for return type
  - [x] Add `-SpaceKey` parameter (Mandatory string)
  - [x] Add `-MFAData` parameter (object array)
  - [x] Add `-PageTitle` parameter (default: 'MFA Status')
  - [x] Add `-ParentPageId` parameter (optional string)
  - [x] Validate space exists using `Get-ConfluenceSpace`
  - [x] Generate ADF content using `ConvertTo-ConfluenceMFAPage`
  - [x] Search for existing page using CQL with quote escaping
  - [x] Create page with `New-ConfluencePage` if not exists
  - [x] Update page with `Set-ConfluencePage` if exists
  - [x] Implement `$PSCmdlet.ShouldProcess` for WhatIf support
  - [x] Add `Write-Verbose` logging throughout
  - [x] Return PSCustomObject with Id, Title, SpaceKey, Version, Action
  - [x] Add comment-based help with examples

- [x] Task 4: Create Sync-ConfluenceMFAReport Unit Tests (AC: 1-10)
  - [x] Create `Tests/Public/Sync-ConfluenceMFAReport.Tests.ps1`
  - [x] Test: Creates page when none exists (AC1)
  - [x] Test: Returns PSCustomObject with correct properties (AC1)
  - [x] Test: Updates page when exists (AC2)
  - [x] Test: Increments version on update (AC2)
  - [x] Test: Does not create page with WhatIf (AC6)
  - [x] Test: Returns null with WhatIf (AC6)
  - [x] Test: Writes verbose messages (AC7)
  - [x] Test: Throws error for non-existent space (AC8)
  - [x] Test: Error message includes actionable guidance (AC8)
  - [x] Test: Handles null MFAData without error (AC9)
  - [x] Test: Handles empty array without error (AC9)
  - [x] Test: Accepts ParentPageId parameter (AC10)
  - [x] Test: Passes ParentPageId to New-ConfluencePage (AC10)
  - [x] Test: Uses correct CQL query format
  - [x] Test: Escapes single quotes in CQL for safety

- [x] Task 5: Run Validation (AC: 1-11)
  - [x] Run `Invoke-ScriptAnalyzer -Path ./Modules/ConfluenceAPI/Private/ConvertTo-ConfluenceMFAPage.ps1`
  - [x] Run `Invoke-ScriptAnalyzer -Path ./Modules/ConfluenceAPI/Public/Sync-ConfluenceMFAReport.ps1`
  - [x] Run all Pester tests (target: 0 new warnings)
  - [x] Verify all existing tests still pass (regression check)

## Dev Notes

### Architecture Compliance

**Module Locations:**
- `Modules/ConfluenceAPI/Private/ConvertTo-ConfluenceMFAPage.ps1` - Data transformer
- `Modules/ConfluenceAPI/Public/Sync-ConfluenceMFAReport.ps1` - Public sync function

Per architecture.md (lines 314-330), data transformation functions are Private, sync functions are Public:
- [Source: docs/architecture.md#Project-Structure-Boundaries] - `ConvertTo-*` in Private/, `Sync-*` in Public/
- [Source: docs/epics.md#Story-6.1] - Acceptance criteria define both functions

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

### CRITICAL: Follow Epic 4-5 Patterns Exactly

Stories 4.1, 4.2, 5.1-5.4 established the exact patterns to follow. This story combines:
1. **Private Transformer Pattern** (from Story 5.1, 5.3) - `ConvertTo-ConfluenceMFAPage`
2. **Public Sync Pattern** (from Story 5.2, 5.4) - `Sync-ConfluenceMFAReport`

### CIPP MFA Data Structure

Expected CIPP MFA report object properties (based on CIPP documentation):

```powershell
[PSCustomObject]@{
    userPrincipalName = 'user@contoso.com'
    displayName = 'John Smith'
    # MFA Status - indicates overall protection
    isMfaRegistered = $true  # or $false
    # Per-User MFA State
    perUserMfaState = 'enabled'  # disabled, enabled, enforced
    # Coverage indicators
    isSecurityDefaultsCovered = $true  # Protected by Security Defaults
    isConditionalAccessCovered = $true  # Protected by CA policies
    isMfaCapable = $true  # User can use MFA
    # Authentication Methods configured
    authenticationMethods = @('microsoftAuthenticator', 'phone', 'fido2')
    # Alternative property names from Graph API
    methodsRegistered = @('mobilePhone', 'microsoftAuthenticatorPush')
    defaultMfaMethod = 'microsoftAuthenticator'
}
```

### MFA Status Mapping Logic

```powershell
# Determine overall MFA status for display
$mfaStatus = if ($_.perUserMfaState -eq 'enforced') {
    'Enforced'
} elseif ($_.perUserMfaState -eq 'enabled' -or $_.isMfaRegistered) {
    'Enabled'
} elseif ($_.isSecurityDefaultsCovered -or $_.isConditionalAccessCovered) {
    'Protected (Policy)'
} else {
    'Disabled'
}
```

### MFA Methods Display Logic

```powershell
# Convert authentication methods array to readable display
$methods = $_.authenticationMethods ?? $_.methodsRegistered ?? @()
$methodsDisplay = if ($methods.Count -gt 0) {
    $friendlyNames = $methods | ForEach-Object {
        switch ($_.ToLower()) {
            'microsoftauthenticator' { 'Authenticator App' }
            'microsoftauthenticatorpush' { 'Authenticator App' }
            'phone' { 'Phone' }
            'mobilephone' { 'Phone' }
            'sms' { 'SMS' }
            'fido2' { 'Security Key' }
            'windowshelloforbusiness' { 'Windows Hello' }
            'softwareoath' { 'TOTP App' }
            'email' { 'Email' }
            default { $_ }
        }
    } | Select-Object -Unique
    $friendlyNames -join ', '
} else {
    'None'
}
```

### Summary Section Generation

```powershell
# Calculate MFA coverage summary
$totalUsers = $MFAData.Count
$mfaEnabledCount = ($MFAData | Where-Object {
    $_.isMfaRegistered -or
    $_.perUserMfaState -in @('enabled', 'enforced') -or
    $_.isSecurityDefaultsCovered -or
    $_.isConditionalAccessCovered
}).Count
$percentage = if ($totalUsers -gt 0) {
    [math]::Round(($mfaEnabledCount / $totalUsers) * 100, 1)
} else {
    0
}

# Generate summary paragraph
$summaryText = "MFA Coverage: $mfaEnabledCount of $totalUsers users ($percentage%) protected by MFA"
```

### ConvertTo-ConfluenceMFAPage Pattern

```powershell
function ConvertTo-ConfluenceMFAPage {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [object[]]$MFAData
    )

    Write-Verbose "Transforming $($MFAData.Count) user MFA record(s) to ADF content"

    # Handle empty input
    if (-not $MFAData -or $MFAData.Count -eq 0) {
        Write-Verbose "No MFA data provided - returning empty state message"
        $doc = New-ADFDocument
        $heading = New-ADFHeading -Level 2 -Text 'MFA Status Report'
        $timestamp = New-ADFParagraph -Text "Data as of: $((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm')) UTC"
        $message = New-ADFParagraph -Text 'No MFA data available'
        $doc = Add-ADFContent -Document $doc -Content @($heading, $timestamp, $message)
        return ConvertTo-ADF -InputObject $doc
    }

    # Calculate summary statistics
    $totalUsers = $MFAData.Count
    $mfaEnabledCount = # ... calculation logic
    $percentage = # ... calculation logic

    # Transform to table format
    $tableData = $MFAData | ForEach-Object {
        [PSCustomObject]@{
            'User' = if ($_.displayName) { $_.displayName } else { $_.userPrincipalName }
            'MFA Status' = # ... status mapping logic
            'MFA Methods' = # ... methods mapping logic
            'Per-User MFA' = if ($_.perUserMfaState) { $_.perUserMfaState } else { 'N/A' }
            'Security Defaults' = if ($_.isSecurityDefaultsCovered) { 'Yes' } else { 'No' }
            'Conditional Access' = if ($_.isConditionalAccessCovered) { 'Yes' } else { 'No' }
        }
    }

    # Build ADF document
    $doc = New-ADFDocument
    $heading = New-ADFHeading -Level 2 -Text 'MFA Status Report'
    $timestamp = New-ADFParagraph -Text "Data as of: $((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm')) UTC"
    $summary = New-ADFParagraph -Text "MFA Coverage: $mfaEnabledCount of $totalUsers users ($percentage%) protected by MFA"
    $table = New-ADFTable -InputObject $tableData
    $doc = Add-ADFContent -Document $doc -Content @($heading, $timestamp, $summary, $table)

    return ConvertTo-ADF -InputObject $doc
}
```

### Sync-ConfluenceMFAReport Pattern

Follow exact pattern from `Sync-ConfluenceLicenseReport.ps1`:

```powershell
function Sync-ConfluenceMFAReport {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string]$SpaceKey,

        [Parameter()]
        [object[]]$MFAData,

        [Parameter()]
        [string]$PageTitle = 'MFA Status',

        [Parameter()]
        [string]$ParentPageId
    )

    Write-Verbose "Syncing MFA report to space '$SpaceKey'"

    # Validate space exists (same pattern as Story 5.4)
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
    $adfContent = ConvertTo-ConfluenceMFAPage -MFAData $MFAData
    $userCount = if ($MFAData) { $MFAData.Count } else { 0 }
    Write-Verbose "Generated ADF content for $userCount user(s)"

    # Search for existing page (CQL injection protection)
    $escapedSpaceKey = $SpaceKey -replace "'", "''"
    $escapedTitle = $PageTitle -replace "'", "''"
    $cql = "space = '$escapedSpaceKey' AND title = '$escapedTitle' AND type = page"
    Write-Verbose "Searching for existing page with CQL: $cql"
    $existingPage = Search-Confluence -CQL $cql | Select-Object -First 1

    # Create or update page (same pattern as Story 5.4)
    # ... rest follows Sync-ConfluenceLicenseReport exactly
}
```

### Previous Story Intelligence (Epic 4-5 Learnings)

**Key Learnings to Apply:**

1. **Case-Insensitive Matching:**
   - Use `.ToLower()` for any string comparisons in switch statements
   - Apply this to perUserMfaState and authenticationMethods matching

2. **Pester 3.4 Syntax (CRITICAL):**
   - Use `Should Be` (no hyphen) for Windows PS 5.1 compatibility
   - Use `Should Not Be $null` for null checks
   - Use `Assert-MockCalled` (NOT `Should -Invoke`) with `-Scope It`
   - Define stub functions before mocking
   - Dot-source function under test in BeforeAll

3. **UTC Timestamp (Story 5.1 Fix):**
   - Use `(Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm')` for actual UTC
   - NOT `Get-Date -Format` which uses local time

4. **CQL Escaping (Story 4.2 Fix):**
   - Escape single quotes: `$SpaceKey -replace "'", "''"`
   - Prevents CQL injection attacks

5. **Empty State Handling:**
   - Always include timestamp even in empty state (Story 5.3 fix)
   - Return "No MFA data available" message, not error

6. **Test Isolation Pattern:**
   - Mock all dependencies (Get-ConfluenceSpace, Search-Confluence, etc.)
   - Use `$script:capturedX` pattern to verify parameters passed

### Testing Pattern

```powershell
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$privateDir = Join-Path (Split-Path -Parent (Split-Path -Parent $here)) 'Private'

Describe 'ConvertTo-ConfluenceMFAPage' {
    BeforeAll {
        # Dot-source dependencies
        . "$privateDir\New-ADFDocument.ps1"
        . "$privateDir\Add-ADFContent.ps1"
        . "$privateDir\ConvertTo-ADF.ps1"
        . "$privateDir\New-ADFTable.ps1"
        . "$privateDir\New-ADFHeading.ps1"
        . "$privateDir\New-ADFParagraph.ps1"
        . "$privateDir\ConvertTo-ConfluenceMFAPage.ps1"
    }

    Context 'Empty/Null Input Handling' {
        It 'Returns valid ADF with message when MFAData is null' {
            $result = ConvertTo-ConfluenceMFAPage -MFAData $null
            $result | Should Not Be $null
            $result | Should Match 'No MFA data available'
        }

        It 'Includes timestamp even when MFAData is empty' {
            $result = ConvertTo-ConfluenceMFAPage -MFAData @()
            $result | Should Match 'Data as of:'
        }
    }

    Context 'MFA Status Mapping' {
        It 'Maps perUserMfaState enforced to Enforced' {
            $mfaUser = [PSCustomObject]@{
                displayName = 'Test User'
                perUserMfaState = 'enforced'
            }
            $result = ConvertTo-ConfluenceMFAPage -MFAData @($mfaUser)
            $result | Should Match 'Enforced'
        }

        It 'Maps isMfaRegistered true to Enabled' {
            $mfaUser = [PSCustomObject]@{
                displayName = 'Test User'
                isMfaRegistered = $true
            }
            $result = ConvertTo-ConfluenceMFAPage -MFAData @($mfaUser)
            $result | Should Match 'Enabled'
        }
    }

    Context 'Summary Statistics' {
        It 'Calculates correct MFA coverage percentage' {
            $mfaUsers = @(
                [PSCustomObject]@{ displayName = 'User1'; isMfaRegistered = $true }
                [PSCustomObject]@{ displayName = 'User2'; isMfaRegistered = $true }
                [PSCustomObject]@{ displayName = 'User3'; isMfaRegistered = $false }
                [PSCustomObject]@{ displayName = 'User4'; isMfaRegistered = $false }
            )
            $result = ConvertTo-ConfluenceMFAPage -MFAData $mfaUsers
            $result | Should Match '50'  # 50% coverage
        }
    }
}
```

### Project Structure Notes

**Files to Create:**
```text
Modules/ConfluenceAPI/
├── Private/
│   └── ConvertTo-ConfluenceMFAPage.ps1    # CREATE
├── Public/
│   └── Sync-ConfluenceMFAReport.ps1       # CREATE
└── Tests/
    ├── Private/
    │   └── ConvertTo-ConfluenceMFAPage.Tests.ps1  # CREATE
    └── Public/
        └── Sync-ConfluenceMFAReport.Tests.ps1     # CREATE
```

**No manifest update needed** - Private functions are auto-loaded by psm1 module loader, Public functions are auto-exported.

### Common Mistakes to Avoid

1. **DO NOT** forget to handle multiple MFA coverage sources (Per-User, SD, CA)
2. **DO NOT** forget to calculate and display summary statistics
3. **DO NOT** forget UTC timestamp (use `.ToUniversalTime()`)
4. **DO NOT** forget CQL single quote escaping for security
5. **DO NOT** forget space validation with actionable error message
6. **DO NOT** forget `SupportsShouldProcess` attribute
7. **DO NOT** return anything when WhatIf is used
8. **DO NOT** use `Should -Invoke` - use `Assert-MockCalled` (Pester 3.4)
9. **DO NOT** forget `Write-Verbose` for all significant operations
10. **DO NOT** move existing pages when ParentPageId is provided
11. **DO NOT** use `throw` directly - use `$PSCmdlet.ThrowTerminatingError()`
12. **DO NOT** forget to handle null authenticationMethods gracefully

### References

- [Source: docs/architecture.md#Project-Structure-Boundaries] - Private/Public function locations
- [Source: docs/architecture.md#Data-Flow] - Transformation and sync pipeline
- [Source: docs/epics.md#Story-6.1] - Acceptance criteria
- [Source: docs/prd.md#Data-Sync-Security] - FR27-29 requirements
- [Source: docs/sprint-artifacts/5-1-endpoint-data-transformer.md] - Transformer pattern
- [Source: docs/sprint-artifacts/5-4-license-report-sync-function.md] - Sync function pattern
- [Source: Modules/ConfluenceAPI/Public/Sync-ConfluenceLicenseReport.ps1] - Direct pattern to follow
- [CIPP MFA Report Documentation](https://docs.cipp.app/user-documentation/identity/reports/mfa-report)
- [Microsoft Graph Authentication Methods API](https://learn.microsoft.com/en-us/graph/api/resources/authenticationmethods-overview)

### FRs Covered

- **FR27**: System can sync MFA status report from CIPP to Confluence (primary)
- **FR28**: System can display MFA enabled/disabled per user
- **FR29**: System can display MFA methods configured
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

### File List

| Path | Action |
|------|--------|
| Modules/ConfluenceAPI/Private/ConvertTo-ConfluenceMFAPage.ps1 | To Create |
| Modules/ConfluenceAPI/Public/Sync-ConfluenceMFAReport.ps1 | To Create |
| Modules/ConfluenceAPI/Tests/Private/ConvertTo-ConfluenceMFAPage.Tests.ps1 | To Create |
| Modules/ConfluenceAPI/Tests/Public/Sync-ConfluenceMFAReport.Tests.ps1 | To Create |

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2025-12-13 | Story created via create-story workflow | Claude Opus 4.5 |
