# Story 4.1: User Data Transformer

Status: done

## Story

As a **Developer**,
I want **to transform CIPP user data into Confluence page content**,
so that **user information is displayed in a readable format with status, licenses, and MFA status**.

## Acceptance Criteria

### AC1: Transform CIPP Users to ADF Content
**Given** I have CIPP user data objects
**When** I call `ConvertTo-ConfluenceUserPage -Users $cippUsers` (Private function)
**Then** ADF content is generated with a user inventory table
**And** the output can be used with `New-ConfluencePage -Body`

### AC2: Display Required User Columns
**Given** I have CIPP user data with various properties
**When** the page is generated
**Then** the table includes: DisplayName, Email, Status, Licenses, MFAStatus
**And** columns appear in a logical order for readability

### AC3: Display User Status (FR16)
**Given** the user data includes `accountEnabled` property
**When** the page is generated
**Then** Status shows "Active" for `accountEnabled = $true`
**And** Status shows "Disabled" for `accountEnabled = $false`

### AC4: Display License Assignments (FR17)
**Given** the user has `assignedLicenses` array with SKU IDs
**When** I call `ConvertTo-ConfluenceUserPage -Users $users -Licenses $licenseInventory`
**Then** License column shows human-readable SKU names (e.g., "ENTERPRISEPACK" or "Microsoft 365 E3")
**And** Multiple licenses are comma-separated
**And** Users with no licenses show "None"

### AC5: Display MFA Status (FR19)
**Given** the user data includes MFA registration status
**When** I call `ConvertTo-ConfluenceUserPage -Users $users -MFAData $mfaReport`
**Then** MFAStatus shows "Registered" for users with MFA enabled
**And** MFAStatus shows "Not Registered" for users without MFA
**And** MFAStatus shows "Unknown" when MFA data is unavailable for a user

### AC6: Display Data Freshness Timestamp (FR44)
**Given** I generate user page content
**When** the ADF content is created
**Then** a timestamp paragraph shows data freshness (e.g., "Last updated: 2025-12-13 14:30 UTC")
**And** the timestamp uses consistent formatting

### AC7: Filter Guest Users
**Given** the user data includes both regular users and guests
**When** the page is generated
**Then** guest users (`userType -eq "Guest"`) are excluded from the table
**And** a count of filtered guests is available for logging

### AC8: Handle Empty/Null Input Gracefully
**Given** I call the function with empty or null user data
**When** the function executes
**Then** a valid ADF document is returned with "No user data available" message
**And** no errors are thrown

## Tasks / Subtasks

- [x] Task 1: Create ConvertTo-ConfluenceUserPage Function (AC: 1, 2, 6, 7, 8)
  - [x] Create `Private/ConvertTo-ConfluenceUserPage.ps1` file
  - [x] Implement `[CmdletBinding()]` with `[OutputType([string])]` (returns ADF JSON)
  - [x] Add `-Users` parameter for CIPP user objects
  - [x] Add `-Licenses` parameter for license inventory lookup (optional)
  - [x] Add `-MFAData` parameter for MFA report data (optional)
  - [x] Filter out guest users (`userType -ne "Guest"`)
  - [x] Build ADF document with heading, timestamp, and table
  - [x] Handle empty/null input gracefully
  - [x] Add `Write-Verbose` logging throughout
  - [x] Add comment-based help with `.LINK` sections
  - [x] Add PSScriptAnalyzer suppression if needed (not needed - ConvertTo-* is approved verb)

- [x] Task 2: Implement User Status Transformation (AC: 3)
  - [x] Map `accountEnabled = $true` to "Active"
  - [x] Map `accountEnabled = $false` to "Disabled"
  - [x] Handle null/missing `accountEnabled` as "Unknown"

- [x] Task 3: Implement License Name Lookup (AC: 4)
  - [x] Create license lookup hashtable from `$Licenses` parameter
  - [x] Match user's `assignedLicenses.skuId` to license inventory
  - [x] Return `skuPartNumber` as human-readable name
  - [x] Join multiple licenses with comma separator
  - [x] Return "None" for users with no licenses

- [x] Task 4: Implement MFA Status Merge (AC: 5)
  - [x] Create MFA lookup hashtable by UPN from `$MFAData`
  - [x] Match user's `userPrincipalName` to MFA report
  - [x] Map `MFARegistration = $true` to "Registered"
  - [x] Map `MFARegistration = $false` to "Not Registered"
  - [x] Return "Unknown" when user not in MFA report

- [x] Task 5: Create Unit Tests (AC: 1-8)
  - [x] Create `Tests/Private/ConvertTo-ConfluenceUserPage.Tests.ps1`
  - [x] Test: Empty users returns valid ADF with message
  - [x] Test: Single user returns table with correct columns
  - [x] Test: Multiple users creates multiple rows
  - [x] Test: Guest users are filtered out
  - [x] Test: accountEnabled maps to Active/Disabled
  - [x] Test: License lookup returns skuPartNumber
  - [x] Test: Multiple licenses are comma-separated
  - [x] Test: No licenses shows "None"
  - [x] Test: MFA lookup returns Registered/Not Registered
  - [x] Test: Missing MFA data shows "Unknown"
  - [x] Test: Timestamp is included in output
  - [x] Test: Output is valid JSON (ADF format)
  - [x] Test: Output works with ConvertTo-ADF function

- [x] Task 6: Run Validation (AC: 1-8)
  - [x] Run `Invoke-ScriptAnalyzer -Path ./Modules/ConfluenceAPI/ -Recurse`
  - [x] Run all Pester tests (target: 0 new warnings)
  - [x] Verify all existing tests still pass (regression check)
  - [x] Verify ADF output structure matches Atlassian specification

## Dev Notes

### Architecture Compliance

**Module Location:** `Modules/ConfluenceAPI/Private/`

Per architecture.md, data transformation functions are Private:
- [Source: docs/architecture.md#Project-Structure-Boundaries] - Lines 328-330: ConvertTo-ConfluenceUserPage in Private/
- [Source: docs/epics.md#Story-4.1] - Acceptance criteria define private function

**Dependencies (All from Epic 3):**
- `New-ADFDocument` (Story 3.1) - for creating document wrapper
- `Add-ADFContent` (Story 3.1) - for adding content to document
- `ConvertTo-ADF` (Story 3.1) - for final JSON output
- `New-ADFTable` (Story 3.2) - for user table generation
- `New-ADFHeading` (Story 3.3) - for page title
- `New-ADFParagraph` (Story 3.3) - for timestamp display

### CRITICAL: CIPP User Data Structure

**User Properties Available from CIPP (via ListGraphRequest):**

| Property | Type | Description |
|----------|------|-------------|
| `id` | string | User GUID |
| `displayName` | string | Full name |
| `userPrincipalName` | string | Email/UPN (used for MFA lookup key) |
| `mail` | string | Primary email |
| `accountEnabled` | boolean | Active/Disabled status |
| `userType` | string | "Member" or "Guest" |
| `assignedLicenses` | array | `[{ skuId: "guid" }, ...]` |
| `createdDateTime` | string | Account creation date |

**License Inventory Structure (from ListLicenses):**

```json
{
  "skuId": "c7df2760-2c81-4ef7-b578-5b5392b571df",
  "skuPartNumber": "ENTERPRISEPREMIUM",
  "consumedUnits": 25,
  "prepaidUnits": { "enabled": 50 }
}
```

**MFA Report Structure (from ListMFAUsers):**

```json
{
  "UPN": "john@contoso.com",
  "MFARegistration": true,
  "MethodsRegistered": ["microsoftAuthenticatorPush", "phoneAppOTP"]
}
```

### Existing Reference Pattern

From `scripts/update-client-environment-from-cipp.ps1` (lines 395-461):

```powershell
# Filter out guest users
$regularUsers = $cippData.Users | Where-Object { $_.userType -ne "Guest" }

# Create MFA lookup from MFA Report (if available)
$mfaLookup = @{}
if ($cippData.MFAReport) {
    foreach ($mfaUser in $cippData.MFAReport) {
        if ($mfaUser.UPN) {
            $mfaLookup[$mfaUser.UPN] = $mfaUser.MFARegistration
        }
    }
}

# License lookup pattern
$licenseNames = if ($_.assignedLicenses -and $_.assignedLicenses.Count -gt 0) {
    $userLicenseSKUs = $_.assignedLicenses | ForEach-Object { $_.skuId }
    $matchingLicenses = $cippData.Licenses | Where-Object { $userLicenseSKUs -contains $_.skuId }
    if ($matchingLicenses) {
        ($matchingLicenses | ForEach-Object { $_.skuPartNumber }) -join ", "
    }
}
```

**IMPORTANT:** This pattern is proven to work. Follow it exactly.

### Function Implementation Pattern

```powershell
function ConvertTo-ConfluenceUserPage {
    <#
    .SYNOPSIS
        Transforms CIPP user data into ADF content for Confluence pages.
    .DESCRIPTION
        Converts CIPP user objects into Atlassian Document Format (ADF) content
        suitable for creating/updating Confluence pages. Includes user status,
        license assignments, and MFA status.
    .PARAMETER Users
        Array of CIPP user objects from ListGraphRequest API.
    .PARAMETER Licenses
        Optional license inventory for SKU name lookup.
    .PARAMETER MFAData
        Optional MFA report data for MFA status lookup.
    .EXAMPLE
        $adf = ConvertTo-ConfluenceUserPage -Users $cippUsers
    .EXAMPLE
        $adf = ConvertTo-ConfluenceUserPage -Users $users -Licenses $licenses -MFAData $mfa
    .LINK
        New-ADFDocument
    .LINK
        New-ADFTable
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [object[]]$Users,

        [Parameter()]
        [object[]]$Licenses,

        [Parameter()]
        [object[]]$MFAData
    )

    Write-Verbose "Converting CIPP user data to Confluence page content..."

    # Create ADF document
    $doc = New-ADFDocument

    # Add heading
    $heading = New-ADFHeading -Level 1 -Text 'User Inventory'

    # Add timestamp (FR44)
    $timestamp = New-ADFParagraph -Text "Last updated: $(Get-Date -Format 'yyyy-MM-dd HH:mm') UTC"

    # Handle empty input
    if (-not $Users -or $Users.Count -eq 0) {
        Write-Verbose "No user data provided - creating placeholder content"
        $noData = New-ADFParagraph -Text 'No user data available' -Italic
        $doc = Add-ADFContent -Document $doc -Content @($heading, $timestamp, $noData)
        return ConvertTo-ADF -InputObject $doc
    }

    # Filter guest users
    $regularUsers = @($Users | Where-Object { $_.userType -ne 'Guest' })
    $guestCount = $Users.Count - $regularUsers.Count
    Write-Verbose "Filtered $guestCount guest user(s), processing $($regularUsers.Count) regular user(s)"

    # Build lookup hashtables
    $mfaLookup = @{}
    if ($MFAData) {
        foreach ($mfaUser in $MFAData) {
            if ($mfaUser.UPN) {
                $mfaLookup[$mfaUser.UPN] = $mfaUser.MFARegistration
            }
        }
        Write-Verbose "Created MFA lookup with $($mfaLookup.Count) entries"
    }

    $licenseLookup = @{}
    if ($Licenses) {
        foreach ($lic in $Licenses) {
            if ($lic.skuId) {
                $licenseLookup[$lic.skuId] = $lic.skuPartNumber
            }
        }
        Write-Verbose "Created license lookup with $($licenseLookup.Count) entries"
    }

    # Transform users to table data
    $tableData = foreach ($user in $regularUsers) {
        # Status mapping
        $status = switch ($user.accountEnabled) {
            $true { 'Active' }
            $false { 'Disabled' }
            default { 'Unknown' }
        }

        # License mapping
        $licenseNames = 'None'
        if ($user.assignedLicenses -and $user.assignedLicenses.Count -gt 0) {
            $names = @()
            foreach ($assigned in $user.assignedLicenses) {
                if ($licenseLookup.ContainsKey($assigned.skuId)) {
                    $names += $licenseLookup[$assigned.skuId]
                } else {
                    $names += $assigned.skuId.Substring(0, 8) + '...'
                }
            }
            if ($names.Count -gt 0) {
                $licenseNames = $names -join ', '
            }
        }

        # MFA mapping
        $mfaStatus = 'Unknown'
        if ($mfaLookup.ContainsKey($user.userPrincipalName)) {
            $mfaStatus = if ($mfaLookup[$user.userPrincipalName]) { 'Registered' } else { 'Not Registered' }
        }

        [PSCustomObject]@{
            DisplayName = $user.displayName
            Email       = $user.userPrincipalName
            Status      = $status
            Licenses    = $licenseNames
            MFAStatus   = $mfaStatus
        }
    }

    # Create table
    $table = New-ADFTable -InputObject $tableData -Property DisplayName, Email, Status, Licenses, MFAStatus

    # Assemble document
    $doc = Add-ADFContent -Document $doc -Content @($heading, $timestamp, $table)

    Write-Verbose "Created user page with $($regularUsers.Count) user(s)"
    return ConvertTo-ADF -InputObject $doc
}
```

### Previous Story Intelligence (Story 3.3)

**Key Learnings to Apply:**

1. **PSScriptAnalyzer Suppression:**
   - NOT needed for `ConvertTo-*` verb (approved verb)
   - Only add if analyzer complains

2. **Pester 3.4 Syntax:**
   - Use `Should Be` (no hyphen) for Windows PS 5.1
   - Use `Should Not Be $null` for null checks
   - Dot-source private function files directly in tests

3. **PS5.1 Compatibility:**
   - Do NOT use `ValidateScript` with `ErrorMessage` parameter
   - Use simple null checks, not newer PS7 features

4. **Testing Pattern:**
   ```powershell
   $here = Split-Path -Parent $MyInvocation.MyCommand.Path
   $privateDir = "$here\..\..\Private"

   Describe 'ConvertTo-ConfluenceUserPage' {
       BeforeAll {
           . "$privateDir\ConvertTo-ConfluenceUserPage.ps1"
           # Also need to dot-source dependencies
           . "$privateDir\New-ADFDocument.ps1"
           . "$privateDir\Add-ADFContent.ps1"
           . "$privateDir\ConvertTo-ADF.ps1"
           . "$privateDir\New-ADFTable.ps1"
           . "$privateDir\New-ADFHeading.ps1"
           . "$privateDir\New-ADFParagraph.ps1"
       }
       # Tests here
   }
   ```

### PRD Requirements Mapping

| Requirement | Implementation | Status |
|-------------|----------------|--------|
| FR15: Sync user inventory | ConvertTo-ConfluenceUserPage creates table | This Story |
| FR16: Display user status | `accountEnabled` mapped to Active/Disabled | This Story |
| FR17: Display license assignments | License lookup by skuId | This Story |
| FR18: Display last sign-in | **NOT in this story** - requires per-user API call | Epic 4.2 (optional) |
| FR19: Display MFA status | MFA lookup by UPN | This Story |
| FR44: Display timestamp | Paragraph with current date/time | This Story |

**Note:** FR18 (last sign-in) is deferred per Epic 3 retrospective recommendation - it requires per-user Graph API calls which would significantly impact performance. Consider making it optional in Story 4.2.

### ADF Output Structure

The function should produce this ADF structure:

```json
{
  "version": 1,
  "type": "doc",
  "content": [
    {
      "type": "heading",
      "attrs": { "level": 1 },
      "content": [{ "type": "text", "text": "User Inventory" }]
    },
    {
      "type": "paragraph",
      "content": [{ "type": "text", "text": "Last updated: 2025-12-13 14:30 UTC" }]
    },
    {
      "type": "table",
      "attrs": { "isNumberColumnEnabled": false, "layout": "default" },
      "content": [
        {
          "type": "tableRow",
          "content": [
            { "type": "tableHeader", "content": [...] },
            ...
          ]
        },
        {
          "type": "tableRow",
          "content": [
            { "type": "tableCell", "content": [...] },
            ...
          ]
        }
      ]
    }
  ]
}
```

### Project Structure Notes

**Files to Create:**
```text
Modules/ConfluenceAPI/
├── Private/
│   └── ConvertTo-ConfluenceUserPage.ps1    # CREATE
└── Tests/
    └── Private/
        └── ConvertTo-ConfluenceUserPage.Tests.ps1  # CREATE
```

### Common Mistakes to Avoid

1. **DO NOT** hardcode column order - use `-Property` parameter on New-ADFTable
2. **DO NOT** return PSCustomObject - return ADF JSON string for direct use with API
3. **DO NOT** forget to handle null `assignedLicenses` array (some users have none)
4. **DO NOT** forget case sensitivity on hashtable keys (UPN matching)
5. **DO NOT** use `throw` directly - use `$PSCmdlet.ThrowTerminatingError()` if needed
6. **DO NOT** forget Write-Verbose for all significant operations
7. **DO NOT** forget to filter guest users before processing
8. **DO NOT** assume MFA data is always available - handle gracefully
9. **DO NOT** assume license inventory is always available - handle gracefully
10. **DO NOT** forget the timestamp paragraph (FR44 requirement)

### Integration Test Considerations

For Story 4.2 (User Inventory Sync Function), this function will be called like:

```powershell
# In Sync-ConfluenceUserInventory (Story 4.2)
$adfContent = ConvertTo-ConfluenceUserPage -Users $cippUsers -Licenses $cippLicenses -MFAData $cippMFA
$page = New-ConfluencePage -SpaceKey $SpaceKey -Title 'User Inventory' -Body $adfContent
```

### References

- [Source: docs/architecture.md#Project-Structure-Boundaries] - ConvertTo-ConfluenceUserPage in Private/
- [Source: docs/architecture.md#Content-Transformation] - Data transformation pipeline
- [Source: docs/epics.md#Story-4.1] - Acceptance criteria
- [Source: docs/prd.md#Data-Sync-Users] - FR15-FR19 requirements
- [Source: docs/sprint-artifacts/epic-3-retro-2025-12-13.md] - CIPP data research findings
- [Source: scripts/update-client-environment-from-cipp.ps1#L395-461] - Proven transformation pattern
- [Source: docs/project_context.md] - PowerShell coding standards

### FRs Covered

- **FR15**: System can sync user inventory from CIPP to Confluence (data transformation component)
- **FR16**: System can display user status (active/disabled)
- **FR17**: System can display user license assignments
- **FR19**: System can display user MFA status
- **FR44**: System can display data freshness timestamp on pages

## Dev Agent Record

### Context Reference

<!-- Story context analysis completed by create-story workflow -->

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

- Pester tests: 26 passed, 0 failed
- Full test suite: All tests pass (no regressions)
- PSScriptAnalyzer: No new warnings in ConvertTo-ConfluenceUserPage.ps1

### Completion Notes List

- Implemented `ConvertTo-ConfluenceUserPage` private function per architecture.md
- Function transforms CIPP user data to ADF JSON for Confluence pages
- Reuses Epic 3 ADF functions: New-ADFDocument, Add-ADFContent, ConvertTo-ADF, New-ADFTable, New-ADFHeading, New-ADFParagraph
- Guest user filtering works correctly (userType != "Guest")
- Status mapping: accountEnabled true/false/null → Active/Disabled/Unknown
- License lookup via hashtable (skuId → skuPartNumber), multiple licenses comma-separated
- MFA lookup via hashtable (UPN → MFARegistration), handles missing data gracefully
- Timestamp (FR44) included in output
- Empty/null input returns valid ADF with "No user data available" message
- All 26 acceptance criteria tests pass
- No PSScriptAnalyzer warnings introduced

### Code Review Fixes Applied

Code review completed with 4 MEDIUM and 2 LOW issues found:

| Severity | Issue | Fix Applied |
|----------|-------|-------------|
| MEDIUM | Case-sensitivity risk in MFA lookup | Added `.ToLower()` normalization for UPN matching |
| MEDIUM | Missing test for case-sensitivity | Added test case for mixed-case UPN matching |
| LOW | Redundant code in license SKU handling | Simplified to single property access |
| LOW | Pester 3.4 syntax | Kept for PS5.1 compatibility (documented) |

### File List

| Path | Action |
|------|--------|
| Modules/ConfluenceAPI/Private/ConvertTo-ConfluenceUserPage.ps1 | Created, Updated |
| Modules/ConfluenceAPI/Tests/Private/ConvertTo-ConfluenceUserPage.Tests.ps1 | Created, Updated |

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2025-12-13 | Story created via create-story workflow | Claude Opus 4.5 |
| 2025-12-13 | Implementation complete - all AC tests pass | Claude Opus 4.5 |
| 2025-12-13 | Code review: Fixed case-sensitivity in MFA lookup, removed redundant code | Claude Opus 4.5 |
