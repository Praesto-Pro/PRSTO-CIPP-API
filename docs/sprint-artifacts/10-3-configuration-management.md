# Story 10.3: Configuration Management

Status: done

## Story

As a **CIPP Administrator**,
I want **Confluence extension settings to be stored and managed through CIPP's Extensionsconfig table**,
so that **I can configure Confluence sync options through the CIPP UI alongside other extensions like Hudu**.

## Acceptance Criteria

### AC1: Configuration Schema Definition
**Given** the Extensionsconfig table stores all extension settings
**When** the Confluence extension is configured
**Then** the configuration structure includes:
- `Enabled`: boolean - Whether extension is active
- `BaseURL`: string - Confluence Cloud base URL (e.g., "https://company.atlassian.net")
- `CloudId`: string - Atlassian Cloud ID (optional, for scoped API)
- `CreateMissingSpaces`: boolean - Auto-create spaces for unmapped tenants
- `SyncUsers`: boolean - Sync user inventory pages
- `SyncDevices`: boolean - Sync endpoint inventory pages
- `SyncLicenses`: boolean - Sync license report pages
- `SyncMFA`: boolean - Sync MFA status pages
- `SyncTeams`: boolean - Sync Teams inventory pages
- `SyncSharePoint`: boolean - Sync SharePoint inventory pages

### AC2: Read Configuration Function
**Given** configuration exists in Extensionsconfig table
**When** `Get-ConfluenceExtensionConfig` is called
**Then** it returns the Confluence configuration as a PSCustomObject
**And** returns `$null` if Confluence section doesn't exist

### AC3: Write Configuration Function
**Given** valid configuration parameters are provided
**When** `Set-ConfluenceExtensionConfig` is called
**Then** the Confluence section in Extensionsconfig is updated
**And** existing configuration for other extensions is preserved
**And** the function supports `-WhatIf` for safety

### AC4: Orchestrator Integration
**Given** `Invoke-ConfluenceExtensionSync` receives `$Configuration` parameter
**When** configuration controls sync behavior
**Then** `SyncUsers=$false` skips user sync
**And** `SyncDevices=$false` skips device sync
**And** `SyncLicenses=$false` skips license sync
**And** similar for MFA, Teams, SharePoint
**And** `Enabled=$false` causes immediate return with log message

### AC5: Default Values for New Configurations
**Given** a new Confluence configuration is created
**When** optional fields are not specified
**Then** `CreateMissingSpaces` defaults to `$false`
**And** all `Sync*` fields default to `$true`
**And** `Enabled` defaults to `$false` (explicit enablement required)

### AC6: Configuration Validation
**Given** configuration is being saved
**When** validation runs
**Then** `BaseURL` must be non-empty when `Enabled` is `$true`
**And** `BaseURL` must match pattern `https://*.atlassian.net` or `https://api.atlassian.com/*`
**And** invalid configuration throws descriptive error

## Tasks / Subtasks

- [x] Task 1: Create Get-ConfluenceExtensionConfig Function (AC: 1, 2)
  - [x] Create `Modules/CippExtensions/Public/Confluence/Get-ConfluenceExtensionConfig.ps1`
  - [x] Add `[CmdletBinding()]` attribute
  - [x] Query `Extensionsconfig` table via `Get-CIPPTable` and `Get-CIPPAzDataTableEntity`
  - [x] Parse JSON `config` property from entity
  - [x] Extract `Confluence` section and return as PSCustomObject
  - [x] Return `$null` if Confluence section doesn't exist
  - [x] Add `Write-Verbose` logging for table access

- [x] Task 2: Create Set-ConfluenceExtensionConfig Function (AC: 1, 3, 5, 6)
  - [x] Create `Modules/CippExtensions/Public/Confluence/Set-ConfluenceExtensionConfig.ps1`
  - [x] Add `[CmdletBinding(SupportsShouldProcess)]` attribute
  - [x] Accept parameters: `-Enabled`, `-BaseURL`, `-CloudId`, `-CreateMissingSpaces`, `-SyncUsers`, `-SyncDevices`, `-SyncLicenses`, `-SyncMFA`, `-SyncTeams`, `-SyncSharePoint`
  - [x] Load existing Extensionsconfig entity
  - [x] Parse existing JSON config
  - [x] Merge Confluence section with defaults
  - [x] Validate `BaseURL` pattern if `Enabled` is `$true`
  - [x] Update JSON and write back to table
  - [x] Add `Write-Verbose` logging for all operations

- [x] Task 3: Integrate with Invoke-ConfluenceExtensionSync (AC: 4)
  - [x] Open `Modules/CippExtensions/Public/Confluence/Invoke-ConfluenceExtensionSync.ps1`
  - [x] Add early return if `$Configuration.Enabled -eq $false` with log message
  - [x] Check `$Configuration.SyncUsers` before user sync block
  - [x] Check `$Configuration.SyncDevices` before device sync block
  - [x] Check `$Configuration.SyncLicenses` before license sync block
  - [x] Check `$Configuration.SyncMFA` before MFA sync block
  - [x] Check `$Configuration.SyncTeams` before Teams sync block
  - [x] Check `$Configuration.SyncSharePoint` before SharePoint sync block
  - [x] Add `Write-Verbose` messages when sync types are skipped

- [x] Task 4: Create Unit Tests (AC: 1, 2, 3, 4, 5, 6)
  - [x] Create `Modules/CippExtensions/Tests/Confluence/Get-ConfluenceExtensionConfig.Tests.ps1`
  - [x] Create `Modules/CippExtensions/Tests/Confluence/Set-ConfluenceExtensionConfig.Tests.ps1`
  - [x] Use Pester 3.4 syntax (`Should Be` without hyphen)
  - [x] Test: Get returns configuration when exists
  - [x] Test: Get returns null when missing
  - [x] Test: Set creates new configuration with defaults
  - [x] Test: Set preserves other extensions
  - [x] Test: Set validates BaseURL pattern
  - [x] Test: Set throws on invalid BaseURL when Enabled
  - [x] Test: WhatIf doesn't modify table
  - [x] Test: Orchestrator skips disabled sync types
  - [x] Test: Orchestrator returns early when Enabled is false

- [x] Task 5: Run Validation
  - [x] Run `Invoke-ScriptAnalyzer` on all new/modified files - 0 warnings expected
  - [x] Run all new Pester tests - verify all pass
  - [x] Run full regression tests - verify no breakage to Story 10.1/10.2

## Dev Notes

### Architecture Compliance

**Module Location:**
Configuration functions go in the Confluence extension folder within CippExtensions:
- `Modules/CippExtensions/Public/Confluence/Get-ConfluenceExtensionConfig.ps1`
- `Modules/CippExtensions/Public/Confluence/Set-ConfluenceExtensionConfig.ps1`

Per research document:
- [Source: docs/analysis/research/technical-cipp-extension-integration-research-2025-12-18.md#Extension-Configuration-Storage]

### Technical Research Summary

**Source:** [docs/analysis/research/technical-cipp-extension-integration-research-2025-12-18.md](../analysis/research/technical-cipp-extension-integration-research-2025-12-18.md)

### Extensionsconfig Table Structure

The Extensionsconfig table stores all extension settings in a single JSON blob:

```
Table: Extensionsconfig
PartitionKey: CippExtensions (implied, may vary)
RowKey: Config (implied, may vary)
config: [JSON string with all extensions]
```

**Existing Config JSON Structure (from Hudu pattern):**

```json
{
  "Hudu": {
    "Enabled": true,
    "APIKey": "SentToKeyVault",
    "BaseURL": "https://demo.huducloud.com",
    "CreateMissingUsers": true,
    "CreateMissingDevices": true,
    "ExcludeSerials": "serial1,serial2",
    "ImportDomains": true,
    "MonitorDomains": false,
    "NextSync": 1734567890
  },
  "NinjaOne": { ... },
  "Confluence": {
    "Enabled": true,
    "BaseURL": "https://company.atlassian.net",
    "CloudId": "abc123-def456-...",
    "CreateMissingSpaces": false,
    "SyncUsers": true,
    "SyncDevices": true,
    "SyncLicenses": true,
    "SyncMFA": true,
    "SyncTeams": true,
    "SyncSharePoint": true
  }
}
```

**Note:** API keys are stored separately in Key Vault (production) or DevSecrets table (development). The `APIKey` field typically contains "SentToKeyVault" as a marker, not the actual key. API key retrieval is handled by Story 10.5.

### Reference Implementation: Register-CIPPExtensionScheduledTasks.ps1

The existing function (lines 9-11) shows how to read Extensionsconfig:

```powershell
# get extension configuration and mappings table
$Table = Get-CIPPTable -TableName Extensionsconfig
$Config = ((Get-CIPPAzDataTableEntity @Table).config | ConvertFrom-Json -ea stop)
```

Then access individual extension configs:

```powershell
$ExtensionConfig = $Config.$Extension
if ($ExtensionConfig.Enabled -eq $true) {
    # Extension is enabled, proceed with operations
}
```

### Get-ConfluenceExtensionConfig Pattern

```powershell
function Get-ConfluenceExtensionConfig {
    <#
    .SYNOPSIS
        Retrieves Confluence extension configuration from Extensionsconfig table.
    .DESCRIPTION
        Reads the Extensionsconfig table and extracts the Confluence section.
        Returns $null if Confluence is not configured.
    #>
    [CmdletBinding()]
    param()

    Write-Verbose "Reading Extensionsconfig table"
    $Table = Get-CIPPTable -TableName 'Extensionsconfig'
    $Entity = Get-CIPPAzDataTableEntity @Table

    if (-not $Entity -or -not $Entity.config) {
        Write-Verbose "Extensionsconfig table is empty or has no config property"
        return $null
    }

    $Config = $Entity.config | ConvertFrom-Json -ErrorAction Stop

    if (-not $Config.Confluence) {
        Write-Verbose "No Confluence section in Extensionsconfig"
        return $null
    }

    Write-Verbose "Returning Confluence configuration"
    return [PSCustomObject]@{
        Enabled            = $Config.Confluence.Enabled
        BaseURL            = $Config.Confluence.BaseURL
        CloudId            = $Config.Confluence.CloudId
        CreateMissingSpaces = $Config.Confluence.CreateMissingSpaces
        SyncUsers          = $Config.Confluence.SyncUsers
        SyncDevices        = $Config.Confluence.SyncDevices
        SyncLicenses       = $Config.Confluence.SyncLicenses
        SyncMFA            = $Config.Confluence.SyncMFA
        SyncTeams          = $Config.Confluence.SyncTeams
        SyncSharePoint     = $Config.Confluence.SyncSharePoint
    }
}
```

### Set-ConfluenceExtensionConfig Pattern

```powershell
function Set-ConfluenceExtensionConfig {
    <#
    .SYNOPSIS
        Updates Confluence extension configuration in Extensionsconfig table.
    .DESCRIPTION
        Merges provided settings into the Extensionsconfig table,
        preserving other extension configurations.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [bool]$Enabled = $false,
        [string]$BaseURL,
        [string]$CloudId,
        [bool]$CreateMissingSpaces = $false,
        [bool]$SyncUsers = $true,
        [bool]$SyncDevices = $true,
        [bool]$SyncLicenses = $true,
        [bool]$SyncMFA = $true,
        [bool]$SyncTeams = $true,
        [bool]$SyncSharePoint = $true
    )

    # Validate BaseURL if enabling
    if ($Enabled -and [string]::IsNullOrEmpty($BaseURL)) {
        throw "BaseURL is required when enabling Confluence extension"
    }

    if ($Enabled -and $BaseURL -notmatch '^https://[\w-]+\.atlassian\.net/?$|^https://api\.atlassian\.com/.+$') {
        throw "BaseURL must match pattern 'https://*.atlassian.net' or 'https://api.atlassian.com/*'"
    }

    Write-Verbose "Reading existing Extensionsconfig"
    $Table = Get-CIPPTable -TableName 'Extensionsconfig'
    $Entity = Get-CIPPAzDataTableEntity @Table

    # Initialize or parse existing config
    if ($Entity -and $Entity.config) {
        $Config = $Entity.config | ConvertFrom-Json -ErrorAction Stop -AsHashtable
    } else {
        $Config = @{}
    }

    # Build Confluence section
    $Config['Confluence'] = @{
        Enabled            = $Enabled
        BaseURL            = $BaseURL
        CloudId            = $CloudId
        CreateMissingSpaces = $CreateMissingSpaces
        SyncUsers          = $SyncUsers
        SyncDevices        = $SyncDevices
        SyncLicenses       = $SyncLicenses
        SyncMFA            = $SyncMFA
        SyncTeams          = $SyncTeams
        SyncSharePoint     = $SyncSharePoint
    }

    if ($PSCmdlet.ShouldProcess('Extensionsconfig', 'Update Confluence configuration')) {
        Write-Verbose "Saving updated configuration to Extensionsconfig table"

        $UpdatedEntity = @{
            PartitionKey = $Entity.PartitionKey ?? 'CippExtensions'
            RowKey       = $Entity.RowKey ?? 'Config'
            config       = $Config | ConvertTo-Json -Depth 10 -Compress
        }

        Add-CIPPAzDataTableEntity @Table -Entity $UpdatedEntity -Force
        Write-Verbose "Configuration saved successfully"
    }
}
```

### Orchestrator Integration Pattern

Modify `Invoke-ConfluenceExtensionSync` to check configuration flags:

```powershell
# At the start of the function
if ($Configuration.Enabled -eq $false) {
    Write-Verbose "Confluence extension is disabled, skipping sync"
    $CompanyResult.Logs.Add("Sync skipped: Extension disabled")
    return $CompanyResult
}

# Before user sync block (around existing line 100+)
if ($Configuration.SyncUsers -ne $false) {
    # Existing user sync code
} else {
    Write-Verbose "User sync disabled in configuration"
    $CompanyResult.Logs.Add("User sync skipped: Disabled in configuration")
}

# Similar pattern for Devices, Licenses, MFA, Teams, SharePoint
```

### Testing Pattern (Pester 3.4 Compatible)

```powershell
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

Describe 'Get-ConfluenceExtensionConfig' {
    BeforeAll {
        $moduleRoot = Split-Path (Split-Path $here -Parent) -Parent
        Import-Module "$moduleRoot\CippExtensions.psd1" -Force
    }

    BeforeEach {
        Mock Get-CIPPTable { return @{ TableName = 'Extensionsconfig' } }
    }

    Context 'Configuration Exists' {
        It 'Returns Confluence configuration when present' {
            Mock Get-CIPPAzDataTableEntity {
                return @{
                    config = @{
                        Confluence = @{
                            Enabled = $true
                            BaseURL = 'https://test.atlassian.net'
                        }
                    } | ConvertTo-Json
                }
            }

            $result = Get-ConfluenceExtensionConfig

            $result | Should Not BeNullOrEmpty
            $result.Enabled | Should Be $true
            $result.BaseURL | Should Be 'https://test.atlassian.net'
        }
    }

    Context 'Configuration Missing' {
        It 'Returns null when Confluence section missing' {
            Mock Get-CIPPAzDataTableEntity {
                return @{
                    config = @{
                        Hudu = @{ Enabled = $true }
                    } | ConvertTo-Json
                }
            }

            $result = Get-ConfluenceExtensionConfig

            $result | Should BeNullOrEmpty
        }
    }
}

Describe 'Set-ConfluenceExtensionConfig' {
    BeforeAll {
        $moduleRoot = Split-Path (Split-Path $here -Parent) -Parent
        Import-Module "$moduleRoot\CippExtensions.psd1" -Force
    }

    BeforeEach {
        Mock Get-CIPPTable { return @{ TableName = 'Extensionsconfig' } }
        Mock Add-CIPPAzDataTableEntity { }
    }

    Context 'Validation' {
        It 'Throws when Enabled without BaseURL' {
            Mock Get-CIPPAzDataTableEntity { return @{ config = '{}' } }

            { Set-ConfluenceExtensionConfig -Enabled $true } | Should Throw 'BaseURL is required'
        }

        It 'Throws on invalid BaseURL pattern' {
            Mock Get-CIPPAzDataTableEntity { return @{ config = '{}' } }

            { Set-ConfluenceExtensionConfig -Enabled $true -BaseURL 'http://invalid.com' } | Should Throw 'must match pattern'
        }

        It 'Accepts valid atlassian.net URL' {
            Mock Get-CIPPAzDataTableEntity { return @{ config = '{}' } }

            { Set-ConfluenceExtensionConfig -Enabled $true -BaseURL 'https://company.atlassian.net' } | Should Not Throw
        }
    }

    Context 'Preserves Other Extensions' {
        It 'Does not remove Hudu configuration' {
            Mock Get-CIPPAzDataTableEntity {
                return @{
                    PartitionKey = 'CippExtensions'
                    RowKey = 'Config'
                    config = @{
                        Hudu = @{ Enabled = $true; BaseURL = 'https://hudu.test' }
                    } | ConvertTo-Json
                }
            }

            $savedEntity = $null
            Mock Add-CIPPAzDataTableEntity {
                param($Entity)
                $script:savedEntity = $Entity
            }

            Set-ConfluenceExtensionConfig -Enabled $true -BaseURL 'https://test.atlassian.net'

            $savedConfig = $savedEntity.config | ConvertFrom-Json
            $savedConfig.Hudu | Should Not BeNullOrEmpty
            $savedConfig.Hudu.Enabled | Should Be $true
            $savedConfig.Confluence | Should Not BeNullOrEmpty
        }
    }

    Context 'WhatIf Support' {
        It 'Does not modify table when WhatIf' {
            Mock Get-CIPPAzDataTableEntity { return @{ config = '{}' } }

            Set-ConfluenceExtensionConfig -Enabled $true -BaseURL 'https://test.atlassian.net' -WhatIf

            Assert-MockCalled Add-CIPPAzDataTableEntity -Times 0 -Exactly
        }
    }
}
```

### Common Mistakes to Avoid

1. **DO NOT** parse config multiple times - parse once and reuse
2. **DO NOT** lose other extension configs when saving - always merge
3. **DO NOT** forget `ConvertFrom-Json -AsHashtable` when modifying - PSCustomObject is read-only
4. **DO NOT** assume PartitionKey/RowKey values - preserve from existing entity
5. **DO NOT** validate BaseURL when `Enabled` is `$false` - only validate when enabling
6. **DO NOT** forget `-ErrorAction Stop` on `ConvertFrom-Json` - handle parse errors

### Dependencies

**From Story 10.1:**
- `Invoke-ConfluenceExtensionSync` must exist and accept `$Configuration` parameter

**External CIPP Functions Required:**
- `Get-CIPPTable` - Get table context
- `Get-CIPPAzDataTableEntity` - Query table entities
- `Add-CIPPAzDataTableEntity` - Write table entities

### Git Commit Pattern

```
feat: implement Story 10.3 Configuration Management

- Add Get-ConfluenceExtensionConfig for reading Extensionsconfig
- Add Set-ConfluenceExtensionConfig with WhatIf support
- Integrate configuration checks into Invoke-ConfluenceExtensionSync
- Create XX unit tests (all passing)
- PSScriptAnalyzer: 0 warnings

Story enables Confluence configuration through CIPP's Extensionsconfig table
```

### Project Structure Notes

**Files to Create:**
```text
Modules/CippExtensions/Public/Confluence/
├── Get-ConfluenceExtensionConfig.ps1    # CREATE
└── Set-ConfluenceExtensionConfig.ps1    # CREATE

Modules/CippExtensions/Tests/Confluence/
├── Get-ConfluenceExtensionConfig.Tests.ps1  # CREATE
└── Set-ConfluenceExtensionConfig.Tests.ps1  # CREATE
```

**Files to Modify:**
```text
Modules/CippExtensions/Public/Confluence/Invoke-ConfluenceExtensionSync.ps1
└── Add configuration checks for Enabled and Sync* flags
```

### References

- [Source: docs/analysis/research/technical-cipp-extension-integration-research-2025-12-18.md#Extension-Configuration-Storage] - Extensionsconfig patterns
- [Source: docs/sprint-artifacts/epic-9-retro-2025-12-18.md#Epic-10-Definition] - Story 10.3 definition
- [Source: docs/sprint-artifacts/10-1-extension-sync-orchestrator.md] - Orchestrator implementation
- [Source: Modules/CippExtensions/Public/Extension Functions/Register-CIPPExtensionScheduledTasks.ps1] - Config read pattern

### FRs Covered

This story implements CIPP framework integration (post-MVP Epic 10) enabling:
- Configuration storage in standard CIPP tables
- UI-compatible settings management
- Per-data-type sync control

## Dev Agent Record

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

- PSScriptAnalyzer: 0 warnings on all new/modified files
- Get-ConfluenceExtensionConfig.Tests.ps1: 26/26 passed
- Set-ConfluenceExtensionConfig.Tests.ps1: 31/31 passed
- Invoke-ConfluenceExtensionSync.Tests.ps1: All Story 10.3 tests pass (13 new tests)

### Completion Notes List

- Implemented Get-ConfluenceExtensionConfig with defaults for Sync* properties ($true when null)
- Implemented Set-ConfluenceExtensionConfig with PS 5.1 compatibility (manual hashtable conversion instead of -AsHashtable)
- Added Enabled check and sync skip logging to Invoke-ConfluenceExtensionSync
- All 6 Acceptance Criteria verified implemented

### File List

**Created:**

- `Modules/CippExtensions/Public/Confluence/Get-ConfluenceExtensionConfig.ps1`
- `Modules/CippExtensions/Public/Confluence/Set-ConfluenceExtensionConfig.ps1`
- `Modules/CippExtensions/Tests/Confluence/Get-ConfluenceExtensionConfig.Tests.ps1`
- `Modules/CippExtensions/Tests/Confluence/Set-ConfluenceExtensionConfig.Tests.ps1`

**Modified:**

- `Modules/CippExtensions/Public/Confluence/Invoke-ConfluenceExtensionSync.ps1` (added Enabled check and sync skip logging)
- `Modules/CippExtensions/Tests/Confluence/Invoke-ConfluenceExtensionSync.Tests.ps1` (added Story 10.3 test contexts)
