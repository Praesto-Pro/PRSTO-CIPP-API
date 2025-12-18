# Story 10.4: Cache Integration

Status: done

## Story

As a **CIPP Administrator**,
I want **page content hashes cached for change detection**,
so that **incremental sync avoids redundant Confluence API calls and improves sync performance**.

## Acceptance Criteria

### AC1: Cache Table Creation
**Given** the Azure Table Storage is accessible
**When** the first page sync occurs
**Then** `CacheConfluencePages` table is created if not exists
**And** entries use PartitionKey = 'ConfluencePage', RowKey = PageId

### AC2: Hash Storage
**Given** a page is synced to Confluence
**When** the sync completes successfully
**Then** the content hash is stored in `CacheConfluencePages`
**And** the hash is a SHA1 of the page content (ADF JSON)

### AC3: Change Detection
**Given** a page sync is requested
**When** the new content hash matches the cached hash
**Then** the Confluence API update is skipped
**And** a log entry indicates "Page unchanged, skipping update"

### AC4: Hash Mismatch Update
**Given** a page sync is requested
**When** the new content hash differs from the cached hash
**Then** the Confluence API update is performed
**And** the cache is updated with the new hash

### AC5: Cache Invalidation
**Given** a tenant mapping is removed
**When** cleanup runs
**Then** related cache entries are removed from `CacheConfluencePages`

## Tasks / Subtasks

- [x] Task 1: Create Cache Helper Functions (AC: 1, 2)
  - [x] Create `Modules/CippExtensions/Private/Confluence/Get-ConfluencePageCache.ps1`
  - [x] Create `Modules/CippExtensions/Private/Confluence/Set-ConfluencePageCache.ps1`
  - [x] Implement `Get-CIPPTable -TableName 'CacheConfluencePages'` table creation
  - [x] Use PartitionKey = 'ConfluencePage' and RowKey = PageId pattern
  - [x] Store Hash, SpaceKey, PageTitle, LastUpdated properties

- [x] Task 2: Implement Hash Generation (AC: 2)
  - [x] Create `Modules/CippExtensions/Private/Confluence/Get-ConfluenceContentHash.ps1`
  - [x] Accept ADF content (hashtable/string) as input
  - [x] Generate SHA1 hash using inline implementation
  - [x] Return consistent hash regardless of property ordering

- [x] Task 3: Integrate Cache Check into Sync Functions (AC: 3, 4)
  - [x] Modify `Sync-ConfluenceUserInventory` to check cache before update
  - [x] Modify `Sync-ConfluenceEndpointInventory` to check cache before update
  - [x] Modify `Sync-ConfluenceLicenseReport` to check cache before update
  - [x] Modify `Sync-ConfluenceMFAReport` to check cache before update
  - [x] Modify `Sync-ConfluenceTeamsInventory` to check cache before update
  - [x] Modify `Sync-ConfluenceSharePointInventory` to check cache before update
  - [x] Add `Write-Verbose "Page unchanged, skipping update"` when hash matches
  - [x] Update cache after successful page update
  - [x] Return `Action = 'Skipped'` when hash matches (new property)

- [x] Task 4: Implement Cache Invalidation (AC: 5)
  - [x] Create `Clear-ConfluencePageCache` function
  - [x] Accept `-SpaceKey` parameter for targeted cleanup
  - [x] Query and remove all cache entries for specified space
  - [x] Support ShouldProcess for WhatIf preview

- [x] Task 5: Create Unit Tests (AC: 1, 2, 3, 4, 5)
  - [x] Create `Modules/CippExtensions/Tests/Confluence/Get-ConfluencePageCache.Tests.ps1` (12 tests)
  - [x] Create `Modules/CippExtensions/Tests/Confluence/Set-ConfluencePageCache.Tests.ps1` (13 tests)
  - [x] Create `Modules/CippExtensions/Tests/Confluence/Get-ConfluenceContentHash.Tests.ps1` (13 tests)
  - [x] Create `Modules/CippExtensions/Tests/Confluence/Clear-ConfluencePageCache.Tests.ps1` (10 tests)
  - [x] Use Pester 3.4 syntax (`Should Be` without hyphen)
  - [x] All 48 tests passing

- [x] Task 6: Run Validation
  - [x] Run `Invoke-ScriptAnalyzer` on all new/modified files - 0 warnings
  - [x] Run all new Pester tests - 48/48 passing

## Dev Notes

### Architecture Compliance

**Module Location:**
Cache functions go in the Private folder (internal helpers):
- `Modules/CippExtensions/Private/Confluence/Get-ConfluencePageCache.ps1`
- `Modules/CippExtensions/Private/Confluence/Set-ConfluencePageCache.ps1`
- `Modules/CippExtensions/Private/Confluence/Get-ConfluenceContentHash.ps1`
- `Modules/CippExtensions/Private/Confluence/Clear-ConfluencePageCache.ps1`

Per research document:
- [Source: docs/analysis/research/technical-cipp-extension-integration-research-2025-12-18.md#Change-Detection-Pattern]

### Technical Research Summary

**Source:** [docs/analysis/research/technical-cipp-extension-integration-research-2025-12-18.md](../analysis/research/technical-cipp-extension-integration-research-2025-12-18.md)

### Cache Table Structure (CacheConfluencePages)

Following the Hudu pattern (`CacheHuduAssets`), the cache table stores content hashes:

```
Table: CacheConfluencePages
PartitionKey: 'ConfluencePage' (constant for all entries)
RowKey: PageId (Confluence page ID)
SpaceKey: Space identifier (for cleanup filtering)
PageTitle: Page title (for logging/debugging)
Hash: SHA1 hash of page content
LastUpdated: ISO 8601 timestamp
```

**Hudu Reference Pattern (CacheHuduAssets):**

```powershell
# From Invoke-HuduExtensionSync.ps1 lines 719-752
$NewHash = Get-StringHash -String $UserBody

$ExistingAsset = Get-CIPPAzDataTableEntity @HuduAssetCache `
    -Filter "PartitionKey eq 'HuduUser' and RowKey eq '$($HuduUser.id)'"

if (!$ExistingAsset -or $ExistingAsset.Hash -ne $NewHash) {
    # Only update if content changed
    $null = Set-HuduAsset -asset_id $HuduUser.id -Fields $UserAssetFields

    # Update cache with new hash
    Add-CIPPAzDataTableEntity @HuduAssetCache -Entity @{
        PartitionKey = 'HuduUser'
        RowKey       = [string]$HuduUser.id
        Hash         = [string]$NewHash
    } -Force
}
```

### Get-ConfluencePageCache Implementation Pattern

```powershell
function Get-ConfluencePageCache {
    <#
    .SYNOPSIS
        Retrieves cached page hash from CacheConfluencePages table.
    .DESCRIPTION
        Returns cached hash for a Confluence page to enable change detection.
        Returns $null if no cache entry exists.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$PageId
    )

    Write-Verbose "Checking cache for page '$PageId'"
    $Table = Get-CIPPTable -TableName 'CacheConfluencePages'

    $Entity = Get-CIPPAzDataTableEntity @Table `
        -Filter "PartitionKey eq 'ConfluencePage' and RowKey eq '$PageId'"

    if ($Entity) {
        Write-Verbose "Cache hit for page '$PageId': Hash = $($Entity.Hash)"
        return [PSCustomObject]@{
            PageId      = $Entity.RowKey
            SpaceKey    = $Entity.SpaceKey
            PageTitle   = $Entity.PageTitle
            Hash        = $Entity.Hash
            LastUpdated = $Entity.LastUpdated
        }
    }

    Write-Verbose "Cache miss for page '$PageId'"
    return $null
}
```

### Set-ConfluencePageCache Implementation Pattern

```powershell
function Set-ConfluencePageCache {
    <#
    .SYNOPSIS
        Stores page hash in CacheConfluencePages table.
    .DESCRIPTION
        Creates or updates cache entry for a Confluence page.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$PageId,

        [Parameter(Mandatory)]
        [string]$SpaceKey,

        [Parameter(Mandatory)]
        [string]$PageTitle,

        [Parameter(Mandatory)]
        [string]$Hash
    )

    Write-Verbose "Updating cache for page '$PageId' (SpaceKey: $SpaceKey)"
    $Table = Get-CIPPTable -TableName 'CacheConfluencePages'

    $Entity = @{
        PartitionKey = 'ConfluencePage'
        RowKey       = $PageId
        SpaceKey     = $SpaceKey
        PageTitle    = $PageTitle
        Hash         = $Hash
        LastUpdated  = (Get-Date).ToString('o')
    }

    Add-CIPPAzDataTableEntity @Table -Entity $Entity -Force
    Write-Verbose "Cache updated for page '$PageId'"
}
```

### Get-ConfluenceContentHash Implementation Pattern

```powershell
function Get-ConfluenceContentHash {
    <#
    .SYNOPSIS
        Generates SHA1 hash of Confluence page content.
    .DESCRIPTION
        Creates consistent hash for change detection.
        Accepts ADF content as hashtable or JSON string.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Content
    )

    # Convert to consistent JSON string if hashtable
    if ($Content -is [hashtable] -or $Content -is [System.Collections.Specialized.OrderedDictionary]) {
        $JsonContent = $Content | ConvertTo-Json -Depth 20 -Compress
    } else {
        $JsonContent = [string]$Content
    }

    # Use Get-StringHash if available (CIPP framework function)
    if (Get-Command 'Get-StringHash' -ErrorAction SilentlyContinue) {
        return Get-StringHash -String $JsonContent
    }

    # Fallback: Inline SHA1 implementation
    $Bytes = [System.Text.Encoding]::UTF8.GetBytes($JsonContent)
    $SHA1 = [System.Security.Cryptography.SHA1]::Create()
    $HashBytes = $SHA1.ComputeHash($Bytes)
    $Hash = [System.BitConverter]::ToString($HashBytes) -replace '-', ''

    Write-Verbose "Generated hash: $Hash (length: $($JsonContent.Length) chars)"
    return $Hash
}
```

### Clear-ConfluencePageCache Implementation Pattern

```powershell
function Clear-ConfluencePageCache {
    <#
    .SYNOPSIS
        Removes cache entries from CacheConfluencePages table.
    .DESCRIPTION
        Clears cache for specific space or all entries.
        Used when tenant mapping is removed.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [string]$SpaceKey
    )

    Write-Verbose "Clearing cache$(if ($SpaceKey) { " for space '$SpaceKey'" })"
    $Table = Get-CIPPTable -TableName 'CacheConfluencePages'

    if ($SpaceKey) {
        $Filter = "PartitionKey eq 'ConfluencePage' and SpaceKey eq '$SpaceKey'"
    } else {
        $Filter = "PartitionKey eq 'ConfluencePage'"
    }

    $Entities = Get-CIPPAzDataTableEntity @Table -Filter $Filter

    if ($PSCmdlet.ShouldProcess("$($Entities.Count) cache entries", 'Remove')) {
        foreach ($Entity in $Entities) {
            Remove-AzDataTableEntity @Table -Entity $Entity -Force
        }
        Write-Verbose "Removed $($Entities.Count) cache entries"
    }
}
```

### Integration with Sync Functions

Each Sync function needs to be modified to check cache before calling Confluence API:

```powershell
# Example pattern for Sync-ConfluenceUserInventory
function Sync-ConfluenceUserInventory {
    param(
        [string]$SpaceKey,
        [array]$Users,
        [array]$Licenses
    )

    # ... existing code to build ADF content ...
    $ADFContent = New-ADFDocument -Content $UserInventoryTable

    # Generate hash of new content
    $NewHash = Get-ConfluenceContentHash -Content $ADFContent

    # Check if page exists and get its ID
    $ExistingPage = Get-ConfluencePage -SpaceKey $SpaceKey -Title 'User Inventory'

    if ($ExistingPage) {
        # Check cache for change detection
        $CachedEntry = Get-ConfluencePageCache -PageId $ExistingPage.Id

        if ($CachedEntry -and $CachedEntry.Hash -eq $NewHash) {
            Write-Verbose "Page 'User Inventory' unchanged, skipping update"
            return [PSCustomObject]@{
                PageId   = $ExistingPage.Id
                Updated  = $false
                Message  = 'Page unchanged, skipping update'
            }
        }

        # Content changed - update page
        $Result = Set-ConfluencePage -PageId $ExistingPage.Id -Body $ADFContent
    } else {
        # Create new page
        $Result = New-ConfluencePage -SpaceKey $SpaceKey -Title 'User Inventory' -Body $ADFContent
    }

    # Update cache after successful update
    Set-ConfluencePageCache -PageId $Result.Id -SpaceKey $SpaceKey -PageTitle 'User Inventory' -Hash $NewHash

    return [PSCustomObject]@{
        PageId   = $Result.Id
        Updated  = $true
        Message  = 'Page updated successfully'
    }
}
```

### Performance Impact Analysis

**Expected Benefits:**
- Eliminates 80-90% of redundant Confluence API calls (matching Hudu pattern)
- Reduces sync time for stable tenants from ~10s to ~1s per page
- Minimal storage overhead: ~200 bytes per page entry (hash + metadata)

**Cache Entry Size Estimate:**
- PartitionKey: ~20 bytes
- RowKey (PageId): ~20 bytes
- SpaceKey: ~20 bytes
- PageTitle: ~50 bytes
- Hash: 40 bytes (SHA1 hex)
- LastUpdated: ~30 bytes
- **Total: ~180 bytes per page**

For a tenant with 6 page types: ~1KB total cache storage

### Testing Pattern (Pester 3.4 Compatible)

```powershell
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

# Define stub functions for dependencies
function Get-CIPPTable { param($TableName) }
function Get-CIPPAzDataTableEntity { param($Filter) }
function Add-CIPPAzDataTableEntity { param($Entity, $Force) }

Describe 'Get-ConfluenceContentHash' {
    BeforeAll {
        $moduleRoot = Split-Path (Split-Path $here -Parent) -Parent
        $functionPath = Join-Path $moduleRoot 'Private/Confluence/Get-ConfluenceContentHash.ps1'
        if (Test-Path $functionPath) { . $functionPath }
    }

    Context 'Hash Generation' {
        It 'Generates consistent hash for same content' {
            $content = @{ type = 'doc'; content = @(@{ type = 'paragraph' }) }

            $hash1 = Get-ConfluenceContentHash -Content $content
            $hash2 = Get-ConfluenceContentHash -Content $content

            $hash1 | Should Be $hash2
        }

        It 'Generates different hash for different content' {
            $content1 = @{ type = 'doc'; content = @(@{ type = 'paragraph'; text = 'A' }) }
            $content2 = @{ type = 'doc'; content = @(@{ type = 'paragraph'; text = 'B' }) }

            $hash1 = Get-ConfluenceContentHash -Content $content1
            $hash2 = Get-ConfluenceContentHash -Content $content2

            $hash1 | Should Not Be $hash2
        }

        It 'Returns 40-character SHA1 hex string' {
            $content = @{ type = 'doc' }

            $hash = Get-ConfluenceContentHash -Content $content

            $hash.Length | Should Be 40
            $hash | Should Match '^[A-F0-9]{40}$'
        }
    }
}

Describe 'Get-ConfluencePageCache' {
    BeforeAll {
        $moduleRoot = Split-Path (Split-Path $here -Parent) -Parent
        $functionPath = Join-Path $moduleRoot 'Private/Confluence/Get-ConfluencePageCache.ps1'
        if (Test-Path $functionPath) { . $functionPath }
    }

    BeforeEach {
        Mock Get-CIPPTable { return @{ TableName = 'CacheConfluencePages' } }
    }

    Context 'Cache Hit' {
        It 'Returns cached entry when exists' {
            Mock Get-CIPPAzDataTableEntity {
                return @{
                    PartitionKey = 'ConfluencePage'
                    RowKey       = '12345'
                    SpaceKey     = 'CONTOSO'
                    PageTitle    = 'User Inventory'
                    Hash         = 'ABC123'
                    LastUpdated  = '2025-12-18T00:00:00Z'
                }
            }

            $result = Get-ConfluencePageCache -PageId '12345'

            $result | Should Not BeNullOrEmpty
            $result.Hash | Should Be 'ABC123'
        }
    }

    Context 'Cache Miss' {
        It 'Returns null when no cache entry' {
            Mock Get-CIPPAzDataTableEntity { return $null }

            $result = Get-ConfluencePageCache -PageId 'nonexistent'

            $result | Should BeNullOrEmpty
        }
    }
}
```

### Common Mistakes to Avoid

1. **DO NOT** generate hash before all content is finalized - hash after complete ADF is built
2. **DO NOT** include timestamps in hashed content - they change every sync and invalidate cache
3. **DO NOT** hash the PSCustomObject directly - convert to JSON first for consistency
4. **DO NOT** forget to update cache after successful page update
5. **DO NOT** ignore cache when page doesn't exist - skip cache check only for new pages
6. **DO NOT** use `-Compress` inconsistently - always use it for hash consistency

### Dependencies

**From Story 10.1:**
- `Invoke-ConfluenceExtensionSync` calls Sync functions that need cache integration

**From Story 10.3:**
- Configuration may include future cache TTL settings (not in scope for this story)

**External CIPP Functions Required:**
- `Get-CIPPTable` - Get table context (creates table if not exists)
- `Get-CIPPAzDataTableEntity` - Query table entities
- `Add-CIPPAzDataTableEntity` - Write table entities
- `Remove-AzDataTableEntity` - Delete table entities (for cache invalidation)
- `Get-StringHash` - CIPP framework hash function (with fallback)

### Existing Sync Functions to Modify

All sync functions are in `Modules/ConfluenceAPI/Public/`:

| Function | File Location | Page Type |
|----------|---------------|-----------|
| `Sync-ConfluenceUserInventory` | `Sync-ConfluenceUserInventory.ps1` | User Inventory |
| `Sync-ConfluenceEndpointInventory` | `Sync-ConfluenceEndpointInventory.ps1` | Endpoint Inventory |
| `Sync-ConfluenceLicenseReport` | `Sync-ConfluenceLicenseReport.ps1` | License Report |
| `Sync-ConfluenceMFAReport` | `Sync-ConfluenceMFAReport.ps1` | MFA Status |
| `Sync-ConfluenceTeamsInventory` | `Sync-ConfluenceTeamsInventory.ps1` | Teams Inventory |
| `Sync-ConfluenceSharePointInventory` | `Sync-ConfluenceSharePointInventory.ps1` | SharePoint Inventory |

### Git Commit Pattern

```
feat: implement Story 10.4 Cache Integration

- Add Get-ConfluencePageCache for cache retrieval
- Add Set-ConfluencePageCache for cache storage
- Add Get-ConfluenceContentHash for SHA1 generation
- Add Clear-ConfluencePageCache for invalidation
- Integrate cache check into all Sync-Confluence* functions
- Create XX unit tests (all passing)
- PSScriptAnalyzer: 0 warnings

Reduces redundant Confluence API calls by ~80-90% via hash-based change detection
```

### Project Structure Notes

**Files to Create:**
```text
Modules/CippExtensions/Private/Confluence/
├── Get-ConfluencePageCache.ps1       # CREATE
├── Set-ConfluencePageCache.ps1       # CREATE
├── Get-ConfluenceContentHash.ps1     # CREATE
└── Clear-ConfluencePageCache.ps1     # CREATE

Modules/CippExtensions/Tests/Confluence/
├── Get-ConfluencePageCache.Tests.ps1     # CREATE
├── Set-ConfluencePageCache.Tests.ps1     # CREATE
├── Get-ConfluenceContentHash.Tests.ps1   # CREATE
└── Clear-ConfluencePageCache.Tests.ps1   # CREATE
```

**Files to Modify:**
```text
Modules/ConfluenceAPI/Public/
├── Sync-ConfluenceUserInventory.ps1      # ADD cache check
├── Sync-ConfluenceEndpointInventory.ps1  # ADD cache check
├── Sync-ConfluenceLicenseReport.ps1      # ADD cache check
├── Sync-ConfluenceMFAReport.ps1          # ADD cache check
├── Sync-ConfluenceTeamsInventory.ps1     # ADD cache check
└── Sync-ConfluenceSharePointInventory.ps1 # ADD cache check
```

### References

- [Source: docs/analysis/research/technical-cipp-extension-integration-research-2025-12-18.md#Change-Detection-Pattern] - Hash-based change detection
- [Source: docs/analysis/research/technical-cipp-extension-integration-research-2025-12-18.md#Hash-Based-Deduplication] - Hudu pattern
- [Source: docs/epics.md#Story-10.4-Cache-Integration] - Story definition
- [Source: docs/sprint-artifacts/10-3-configuration-management.md] - Previous story patterns

### Previous Story Intelligence (Story 10.3)

From Story 10.3 implementation:
- Used PS 5.1 compatibility pattern (no `-AsHashtable` on `ConvertFrom-Json`)
- Pester 3.4 syntax: `Should Be` without hyphen, `Assert-MockCalled -ParameterFilter`
- All tests passing: 26/26 Get tests, 31/31 Set tests
- Used manual hashtable conversion for JSON modification
- PSScriptAnalyzer compliance: 0 warnings

### FRs Covered

This story implements performance optimization (NFR1-4):
- Reduces redundant API calls via hash-based change detection
- Improves sync time for stable tenants
- Minimizes Confluence API usage

## Dev Agent Record

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

N/A

### Completion Notes List

1. Created 4 cache helper functions in `Modules/CippExtensions/Private/Confluence/`
2. Integrated cache check into all 6 Sync-Confluence* functions
3. Returns `Action = 'Skipped'` with `Message` property when content unchanged
4. Uses inline SHA1 implementation (not Get-StringHash) for consistency
5. All 48 unit tests passing
6. PSScriptAnalyzer: 0 warnings

### File List

**Created:**
- `Modules/CippExtensions/Private/Confluence/Get-ConfluencePageCache.ps1`
- `Modules/CippExtensions/Private/Confluence/Set-ConfluencePageCache.ps1`
- `Modules/CippExtensions/Private/Confluence/Get-ConfluenceContentHash.ps1`
- `Modules/CippExtensions/Private/Confluence/Clear-ConfluencePageCache.ps1`
- `Modules/CippExtensions/Tests/Confluence/Get-ConfluencePageCache.Tests.ps1`
- `Modules/CippExtensions/Tests/Confluence/Set-ConfluencePageCache.Tests.ps1`
- `Modules/CippExtensions/Tests/Confluence/Get-ConfluenceContentHash.Tests.ps1`
- `Modules/CippExtensions/Tests/Confluence/Clear-ConfluencePageCache.Tests.ps1`

**Modified:**
- `Modules/ConfluenceAPI/Public/Sync-ConfluenceUserInventory.ps1`
- `Modules/ConfluenceAPI/Public/Sync-ConfluenceEndpointInventory.ps1`
- `Modules/ConfluenceAPI/Public/Sync-ConfluenceLicenseReport.ps1`
- `Modules/ConfluenceAPI/Public/Sync-ConfluenceMFAReport.ps1`
- `Modules/ConfluenceAPI/Public/Sync-ConfluenceTeamsInventory.ps1`
- `Modules/ConfluenceAPI/Public/Sync-ConfluenceSharePointInventory.ps1`
