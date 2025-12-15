# Story 8.2: Sync Configuration

Status: done

## Story

As a **Technical Lead**,
I want **to configure sync behavior and frequency settings**,
so that **I can customize sync operations for my environment and prepare for scheduled automation**.

## Acceptance Criteria

### AC1: Set Sync Configuration (FR35)
**Given** I want to configure sync settings
**When** I run `Set-ConfluenceSyncConfiguration -SyncFrequency 'Daily' -RetryAttempts 3`
**Then** the settings are stored in `$script:ConfluenceSyncConfiguration`
**And** the function returns a PSCustomObject confirming the stored settings
**And** `Write-Verbose` logs "Setting sync configuration"

### AC2: Get Sync Configuration
**Given** I want to view current settings
**When** I run `Get-ConfluenceSyncConfiguration`
**Then** the current sync configuration is returned as a PSCustomObject
**And** if no configuration exists, default values are returned
**And** `Write-Verbose` logs "Retrieving sync configuration"

### AC3: Valid Sync Frequency Values
**Given** I want to set the sync frequency
**When** I provide a value to `-SyncFrequency`
**Then** only valid values are accepted: 'Hourly', 'Daily', 'Weekly', 'Manual'
**And** invalid values throw a validation error with clear guidance

### AC4: Retry Configuration
**Given** I want to configure retry behavior
**When** I run `Set-ConfluenceSyncConfiguration -RetryAttempts 5 -RetryDelaySeconds 30`
**Then** the retry settings are stored
**And** RetryAttempts is validated (1-10 range)
**And** RetryDelaySeconds is validated (5-300 range)

### AC5: Incremental Sync Toggle
**Given** I want to enable or disable incremental sync
**When** I run `Set-ConfluenceSyncConfiguration -EnableIncrementalSync $true`
**Then** the incremental sync setting is stored
**And** this affects sync behavior in Story 8.4

### AC6: WhatIf Support (NFR18)
**Given** I want to preview configuration changes
**When** I run `Set-ConfluenceSyncConfiguration -SyncFrequency 'Weekly' -WhatIf`
**Then** the changes that would be made are shown
**And** no actual configuration is changed

### AC7: Remove Sync Configuration
**Given** I want to clear/reset sync configuration
**When** I run `Remove-ConfluenceSyncConfiguration`
**Then** `$script:ConfluenceSyncConfiguration` is cleared
**And** `Get-ConfluenceSyncConfiguration` returns defaults afterward

### AC8: Default Values
**Given** no configuration has been set
**When** I run `Get-ConfluenceSyncConfiguration`
**Then** defaults are returned:
- SyncFrequency: 'Manual'
- RetryAttempts: 3
- RetryDelaySeconds: 30
- EnableIncrementalSync: $false
- ConfiguredAt: $null

## Tasks / Subtasks

- [x] Task 1: Create Set-ConfluenceSyncConfiguration Public Function (AC: 1, 3, 4, 5, 6)
  - [x] Create `Public/Set-ConfluenceSyncConfiguration.ps1` file
  - [x] Add `[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]`
  - [x] Add `[OutputType([PSCustomObject])]`
  - [x] Add `-SyncFrequency` parameter with `[ValidateSet('Hourly', 'Daily', 'Weekly', 'Manual')]`
  - [x] Add `-RetryAttempts` parameter with `[ValidateRange(1, 10)]`
  - [x] Add `-RetryDelaySeconds` parameter with `[ValidateRange(5, 300)]`
  - [x] Add `-EnableIncrementalSync` bool parameter (allows setting to `$false` after `$true`)
  - [x] Store configuration in `$script:ConfluenceSyncConfiguration` hashtable
  - [x] Implement `$PSCmdlet.ShouldProcess` for WhatIf support
  - [x] Add `Write-Verbose` logging throughout
  - [x] Return PSCustomObject with all settings and ConfiguredAt timestamp
  - [x] Add comment-based help with examples

- [x] Task 2: Create Get-ConfluenceSyncConfiguration Public Function (AC: 2, 8)
  - [x] Create `Public/Get-ConfluenceSyncConfiguration.ps1` file
  - [x] Add `[CmdletBinding()]`
  - [x] Add `[OutputType([PSCustomObject])]`
  - [x] Return `$script:ConfluenceSyncConfiguration` if set
  - [x] Return defaults if not set (SyncFrequency='Manual', RetryAttempts=3, etc.)
  - [x] Add `Write-Verbose` logging
  - [x] Add comment-based help

- [x] Task 3: Create Remove-ConfluenceSyncConfiguration Public Function (AC: 7)
  - [x] Create `Public/Remove-ConfluenceSyncConfiguration.ps1` file
  - [x] Add `[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]`
  - [x] Clear `$script:ConfluenceSyncConfiguration` to `$null`
  - [x] Add `Write-Verbose` logging
  - [x] Add comment-based help

- [x] Task 4: Create Unit Tests for Set-ConfluenceSyncConfiguration (AC: 1, 3, 4, 5, 6)
  - [x] Create `Tests/Public/Set-ConfluenceSyncConfiguration.Tests.ps1`
  - [x] Test: Stores configuration in script scope variable
  - [x] Test: Returns PSCustomObject with expected properties
  - [x] Test: Validates SyncFrequency accepts only valid values
  - [x] Test: Validates RetryAttempts range (1-10)
  - [x] Test: Validates RetryDelaySeconds range (5-300)
  - [x] Test: Stores EnableIncrementalSync setting
  - [x] Test: WhatIf does not change configuration
  - [x] Test: Writes verbose messages
  - [x] Test: Includes ConfiguredAt timestamp in result
  - [x] Test: Merges new settings with existing (partial update)

- [x] Task 5: Create Unit Tests for Get-ConfluenceSyncConfiguration (AC: 2, 8)
  - [x] Create `Tests/Public/Get-ConfluenceSyncConfiguration.Tests.ps1`
  - [x] Test: Returns stored configuration when set
  - [x] Test: Returns defaults when no configuration set
  - [x] Test: Default SyncFrequency is 'Manual'
  - [x] Test: Default RetryAttempts is 3
  - [x] Test: Default RetryDelaySeconds is 30
  - [x] Test: Default EnableIncrementalSync is $false
  - [x] Test: Writes verbose messages

- [x] Task 6: Create Unit Tests for Remove-ConfluenceSyncConfiguration (AC: 7)
  - [x] Create `Tests/Public/Remove-ConfluenceSyncConfiguration.Tests.ps1`
  - [x] Test: Clears script scope variable
  - [x] Test: Get returns defaults after Remove
  - [x] Test: WhatIf does not clear configuration
  - [x] Test: Writes verbose messages

- [x] Task 7: Update Module Manifest and Run Validation
  - [x] Add all three functions to `ConfluenceAPI.psd1` FunctionsToExport
  - [x] Run `Invoke-ScriptAnalyzer` - 0 warnings
  - [x] Run all new Pester tests - all passing
  - [x] Run full regression tests - all passing (1 pre-existing failure unrelated to Story 8.2)
  - [x] Verify module loads correctly

## Dev Notes

### Architecture Compliance

**Module Location:**
- `Modules/ConfluenceAPI/Public/Set-ConfluenceSyncConfiguration.ps1`
- `Modules/ConfluenceAPI/Public/Get-ConfluenceSyncConfiguration.ps1`
- `Modules/ConfluenceAPI/Public/Remove-ConfluenceSyncConfiguration.ps1`

Per architecture.md, configuration functions follow the credential management pattern:
- [Source: docs/architecture.md#Credential-Storage] - Script-scoped variable pattern
- [Source: docs/epics.md#Story-8.2] - FR35 sync frequency configuration

**Existing Pattern to Follow:**
These functions mirror the API key management pattern established in Epic 1:
- `New-ConfluenceAPIKey` / `Get-ConfluenceAPIKey` / `Remove-ConfluenceAPIKey`
- `New-ConfluenceBaseURL` / `Get-ConfluenceBaseURL` / `Remove-ConfluenceBaseURL`

### Script-Scoped Storage Pattern

```powershell
# Storage variable (module-level)
$script:ConfluenceSyncConfiguration = $null

# Default configuration
$script:DefaultSyncConfiguration = @{
    SyncFrequency        = 'Manual'
    RetryAttempts        = 3
    RetryDelaySeconds    = 30
    EnableIncrementalSync = $false
    ConfiguredAt         = $null
}
```

### Set-ConfluenceSyncConfiguration Function Pattern

```powershell
function Set-ConfluenceSyncConfiguration {
    <#
    .SYNOPSIS
        Configures sync behavior and frequency settings.
    .DESCRIPTION
        Stores sync configuration including frequency, retry behavior, and
        incremental sync settings. Configuration is stored in memory and
        used by sync orchestration functions.
    .PARAMETER SyncFrequency
        How often sync should run: Hourly, Daily, Weekly, or Manual.
    .PARAMETER RetryAttempts
        Number of retry attempts for failed operations (1-10).
    .PARAMETER RetryDelaySeconds
        Base delay between retry attempts in seconds (5-300).
    .PARAMETER EnableIncrementalSync
        When true, sync skips unchanged data for efficiency.
    .OUTPUTS
        [PSCustomObject] The stored sync configuration.
    .EXAMPLE
        Set-ConfluenceSyncConfiguration -SyncFrequency 'Daily' -RetryAttempts 3
        Configures daily sync with 3 retry attempts.
    .EXAMPLE
        Set-ConfluenceSyncConfiguration -EnableIncrementalSync $true
        Enables incremental sync while preserving other settings.
    .EXAMPLE
        Set-ConfluenceSyncConfiguration -SyncFrequency 'Weekly' -WhatIf
        Shows what configuration would be set without making changes.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [ValidateSet('Hourly', 'Daily', 'Weekly', 'Manual')]
        [string]$SyncFrequency,

        [Parameter()]
        [ValidateRange(1, 10)]
        [int]$RetryAttempts,

        [Parameter()]
        [ValidateRange(5, 300)]
        [int]$RetryDelaySeconds,

        [Parameter()]
        [bool]$EnableIncrementalSync
    )

    Write-Verbose "Setting sync configuration"

    # Get current config or defaults
    $currentConfig = if ($script:ConfluenceSyncConfiguration) {
        $script:ConfluenceSyncConfiguration.Clone()
    }
    else {
        @{
            SyncFrequency         = 'Manual'
            RetryAttempts         = 3
            RetryDelaySeconds     = 30
            EnableIncrementalSync = $false
            ConfiguredAt          = $null
        }
    }

    # Apply provided parameters (merge pattern - only update what's specified)
    if ($PSBoundParameters.ContainsKey('SyncFrequency')) {
        Write-Verbose "Setting SyncFrequency to '$SyncFrequency'"
        $currentConfig.SyncFrequency = $SyncFrequency
    }
    if ($PSBoundParameters.ContainsKey('RetryAttempts')) {
        Write-Verbose "Setting RetryAttempts to $RetryAttempts"
        $currentConfig.RetryAttempts = $RetryAttempts
    }
    if ($PSBoundParameters.ContainsKey('RetryDelaySeconds')) {
        Write-Verbose "Setting RetryDelaySeconds to $RetryDelaySeconds"
        $currentConfig.RetryDelaySeconds = $RetryDelaySeconds
    }
    if ($PSBoundParameters.ContainsKey('EnableIncrementalSync')) {
        Write-Verbose "Setting EnableIncrementalSync to $EnableIncrementalSync"
        $currentConfig.EnableIncrementalSync = $EnableIncrementalSync
    }

    # Update timestamp
    $currentConfig.ConfiguredAt = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss UTC')

    if ($PSCmdlet.ShouldProcess('Sync Configuration', 'Set')) {
        $script:ConfluenceSyncConfiguration = $currentConfig
        Write-Verbose "Sync configuration stored successfully"
    }

    # Return configuration object
    [PSCustomObject]@{
        SyncFrequency         = $currentConfig.SyncFrequency
        RetryAttempts         = $currentConfig.RetryAttempts
        RetryDelaySeconds     = $currentConfig.RetryDelaySeconds
        EnableIncrementalSync = $currentConfig.EnableIncrementalSync
        ConfiguredAt          = $currentConfig.ConfiguredAt
    }
}
```

### Get-ConfluenceSyncConfiguration Function Pattern

```powershell
function Get-ConfluenceSyncConfiguration {
    <#
    .SYNOPSIS
        Retrieves current sync configuration settings.
    .DESCRIPTION
        Returns the stored sync configuration or default values if no
        configuration has been set.
    .OUTPUTS
        [PSCustomObject] Current sync configuration with all settings.
    .EXAMPLE
        Get-ConfluenceSyncConfiguration
        Returns the current sync configuration.
    .EXAMPLE
        $config = Get-ConfluenceSyncConfiguration
        if ($config.SyncFrequency -eq 'Daily') { ... }
        Gets configuration and checks frequency setting.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    Write-Verbose "Retrieving sync configuration"

    if ($script:ConfluenceSyncConfiguration) {
        Write-Verbose "Returning stored configuration"
        [PSCustomObject]@{
            SyncFrequency         = $script:ConfluenceSyncConfiguration.SyncFrequency
            RetryAttempts         = $script:ConfluenceSyncConfiguration.RetryAttempts
            RetryDelaySeconds     = $script:ConfluenceSyncConfiguration.RetryDelaySeconds
            EnableIncrementalSync = $script:ConfluenceSyncConfiguration.EnableIncrementalSync
            ConfiguredAt          = $script:ConfluenceSyncConfiguration.ConfiguredAt
        }
    }
    else {
        Write-Verbose "No configuration set, returning defaults"
        [PSCustomObject]@{
            SyncFrequency         = 'Manual'
            RetryAttempts         = 3
            RetryDelaySeconds     = 30
            EnableIncrementalSync = $false
            ConfiguredAt          = $null
        }
    }
}
```

### Remove-ConfluenceSyncConfiguration Function Pattern

```powershell
function Remove-ConfluenceSyncConfiguration {
    <#
    .SYNOPSIS
        Clears the stored sync configuration.
    .DESCRIPTION
        Removes the stored sync configuration, reverting to default values
        for subsequent Get-ConfluenceSyncConfiguration calls.
    .EXAMPLE
        Remove-ConfluenceSyncConfiguration
        Clears the sync configuration.
    .EXAMPLE
        Remove-ConfluenceSyncConfiguration -WhatIf
        Shows what would happen without clearing configuration.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param()

    Write-Verbose "Removing sync configuration"

    if ($PSCmdlet.ShouldProcess('Sync Configuration', 'Remove')) {
        $script:ConfluenceSyncConfiguration = $null
        Write-Verbose "Sync configuration cleared"
    }
}
```

### Testing Pattern (Pester 3.4 Compatible)

```powershell
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleRoot = Split-Path -Parent (Split-Path -Parent $here)
$publicDir = Join-Path $moduleRoot 'Public'

Describe 'Set-ConfluenceSyncConfiguration' {
    BeforeAll {
        . "$publicDir\Set-ConfluenceSyncConfiguration.ps1"
        . "$publicDir\Get-ConfluenceSyncConfiguration.ps1"
        . "$publicDir\Remove-ConfluenceSyncConfiguration.ps1"
    }

    BeforeEach {
        # Clear config before each test
        $script:ConfluenceSyncConfiguration = $null
    }

    Context 'Basic Configuration' {
        It 'Stores SyncFrequency in script scope variable' {
            Set-ConfluenceSyncConfiguration -SyncFrequency 'Daily'
            $script:ConfluenceSyncConfiguration.SyncFrequency | Should Be 'Daily'
        }

        It 'Returns PSCustomObject with expected properties' {
            $result = Set-ConfluenceSyncConfiguration -SyncFrequency 'Weekly'
            $result | Should Not Be $null
            $result.SyncFrequency | Should Be 'Weekly'
            $result.RetryAttempts | Should Be 3
            $result.RetryDelaySeconds | Should Be 30
            $result.EnableIncrementalSync | Should Be $false
            $result.ConfiguredAt | Should Not Be $null
        }

        It 'Includes ConfiguredAt timestamp' {
            $result = Set-ConfluenceSyncConfiguration -RetryAttempts 5
            $result.ConfiguredAt | Should Match '\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} UTC'
        }
    }

    Context 'Validation' {
        It 'Validates SyncFrequency accepts only valid values' {
            { Set-ConfluenceSyncConfiguration -SyncFrequency 'Daily' } | Should Not Throw
            { Set-ConfluenceSyncConfiguration -SyncFrequency 'Invalid' } | Should Throw
        }

        It 'Validates RetryAttempts range 1-10' {
            { Set-ConfluenceSyncConfiguration -RetryAttempts 1 } | Should Not Throw
            { Set-ConfluenceSyncConfiguration -RetryAttempts 10 } | Should Not Throw
            { Set-ConfluenceSyncConfiguration -RetryAttempts 0 } | Should Throw
            { Set-ConfluenceSyncConfiguration -RetryAttempts 11 } | Should Throw
        }

        It 'Validates RetryDelaySeconds range 5-300' {
            { Set-ConfluenceSyncConfiguration -RetryDelaySeconds 5 } | Should Not Throw
            { Set-ConfluenceSyncConfiguration -RetryDelaySeconds 300 } | Should Not Throw
            { Set-ConfluenceSyncConfiguration -RetryDelaySeconds 4 } | Should Throw
            { Set-ConfluenceSyncConfiguration -RetryDelaySeconds 301 } | Should Throw
        }
    }

    Context 'Partial Updates (Merge Behavior)' {
        It 'Merges new settings with existing' {
            Set-ConfluenceSyncConfiguration -SyncFrequency 'Daily'
            Set-ConfluenceSyncConfiguration -RetryAttempts 5
            $result = Get-ConfluenceSyncConfiguration
            $result.SyncFrequency | Should Be 'Daily'
            $result.RetryAttempts | Should Be 5
        }

        It 'Preserves unspecified settings' {
            Set-ConfluenceSyncConfiguration -SyncFrequency 'Weekly' -RetryAttempts 7
            Set-ConfluenceSyncConfiguration -EnableIncrementalSync $true
            $result = Get-ConfluenceSyncConfiguration
            $result.SyncFrequency | Should Be 'Weekly'
            $result.RetryAttempts | Should Be 7
            $result.EnableIncrementalSync | Should Be $true
        }
    }

    Context 'WhatIf Support' {
        It 'Does not change configuration with WhatIf' {
            Set-ConfluenceSyncConfiguration -SyncFrequency 'Daily' -WhatIf
            $script:ConfluenceSyncConfiguration | Should Be $null
        }

        It 'Still returns what would be set with WhatIf' {
            $result = Set-ConfluenceSyncConfiguration -SyncFrequency 'Hourly' -WhatIf
            $result.SyncFrequency | Should Be 'Hourly'
        }
    }

    Context 'Verbose Logging' {
        It 'Writes verbose messages' {
            $verboseOutput = Set-ConfluenceSyncConfiguration -SyncFrequency 'Daily' -Verbose 4>&1
            $verboseMessages = $verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }
            $verboseMessages.Count | Should BeGreaterThan 0
        }
    }
}

Describe 'Get-ConfluenceSyncConfiguration' {
    BeforeAll {
        . "$publicDir\Set-ConfluenceSyncConfiguration.ps1"
        . "$publicDir\Get-ConfluenceSyncConfiguration.ps1"
    }

    BeforeEach {
        $script:ConfluenceSyncConfiguration = $null
    }

    Context 'Returns Stored Configuration' {
        It 'Returns stored configuration when set' {
            Set-ConfluenceSyncConfiguration -SyncFrequency 'Weekly' -RetryAttempts 5
            $result = Get-ConfluenceSyncConfiguration
            $result.SyncFrequency | Should Be 'Weekly'
            $result.RetryAttempts | Should Be 5
        }
    }

    Context 'Default Values' {
        It 'Returns defaults when no configuration set' {
            $result = Get-ConfluenceSyncConfiguration
            $result | Should Not Be $null
        }

        It 'Default SyncFrequency is Manual' {
            $result = Get-ConfluenceSyncConfiguration
            $result.SyncFrequency | Should Be 'Manual'
        }

        It 'Default RetryAttempts is 3' {
            $result = Get-ConfluenceSyncConfiguration
            $result.RetryAttempts | Should Be 3
        }

        It 'Default RetryDelaySeconds is 30' {
            $result = Get-ConfluenceSyncConfiguration
            $result.RetryDelaySeconds | Should Be 30
        }

        It 'Default EnableIncrementalSync is false' {
            $result = Get-ConfluenceSyncConfiguration
            $result.EnableIncrementalSync | Should Be $false
        }

        It 'Default ConfiguredAt is null' {
            $result = Get-ConfluenceSyncConfiguration
            $result.ConfiguredAt | Should Be $null
        }
    }

    Context 'Verbose Logging' {
        It 'Writes verbose messages' {
            $verboseOutput = Get-ConfluenceSyncConfiguration -Verbose 4>&1
            $verboseMessages = $verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }
            $verboseMessages.Count | Should BeGreaterThan 0
        }
    }
}

Describe 'Remove-ConfluenceSyncConfiguration' {
    BeforeAll {
        . "$publicDir\Set-ConfluenceSyncConfiguration.ps1"
        . "$publicDir\Get-ConfluenceSyncConfiguration.ps1"
        . "$publicDir\Remove-ConfluenceSyncConfiguration.ps1"
    }

    BeforeEach {
        $script:ConfluenceSyncConfiguration = $null
    }

    Context 'Clear Configuration' {
        It 'Clears script scope variable' {
            Set-ConfluenceSyncConfiguration -SyncFrequency 'Daily'
            Remove-ConfluenceSyncConfiguration
            $script:ConfluenceSyncConfiguration | Should Be $null
        }

        It 'Get returns defaults after Remove' {
            Set-ConfluenceSyncConfiguration -SyncFrequency 'Weekly' -RetryAttempts 7
            Remove-ConfluenceSyncConfiguration
            $result = Get-ConfluenceSyncConfiguration
            $result.SyncFrequency | Should Be 'Manual'
            $result.RetryAttempts | Should Be 3
        }
    }

    Context 'WhatIf Support' {
        It 'Does not clear configuration with WhatIf' {
            Set-ConfluenceSyncConfiguration -SyncFrequency 'Daily'
            Remove-ConfluenceSyncConfiguration -WhatIf
            $script:ConfluenceSyncConfiguration | Should Not Be $null
            $script:ConfluenceSyncConfiguration.SyncFrequency | Should Be 'Daily'
        }
    }

    Context 'Verbose Logging' {
        It 'Writes verbose messages' {
            $verboseOutput = Remove-ConfluenceSyncConfiguration -Verbose 4>&1
            $verboseMessages = $verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }
            $verboseMessages.Count | Should BeGreaterThan 0
        }
    }
}
```

### Previous Story Intelligence (Story 8.1 Learnings)

**Key Learnings to Apply:**

1. **Pester 3.4 Syntax (CRITICAL):**
   - Use `Should Be` (no hyphen) for Windows PS 5.1 compatibility
   - Use `Should Not Be $null` for null checks
   - Use `Should Throw` / `Should Not Throw` for exception tests
   - Dot-source all related functions in BeforeAll for cross-function tests

2. **Script-Scoped Variables:**
   - Initialize as `$null` at module scope
   - Clone hashtables before modifying to avoid reference issues
   - Use `$PSBoundParameters.ContainsKey()` to detect provided parameters

3. **UTC Timestamps:**
   - Use `(Get-Date).ToUniversalTime()` for all timestamps
   - Format as `'yyyy-MM-dd HH:mm:ss UTC'`

4. **WhatIf Pattern:**
   - Return the "would be" result even when WhatIf is true
   - Only skip the actual storage operation

5. **Validation:**
   - Use `[ValidateSet()]` for enum-like parameters
   - Use `[ValidateRange()]` for numeric bounds

### Project Structure Notes

**Files to Create:**
```text
Modules/ConfluenceAPI/
├── Public/
│   ├── Set-ConfluenceSyncConfiguration.ps1    # CREATE
│   ├── Get-ConfluenceSyncConfiguration.ps1    # CREATE
│   └── Remove-ConfluenceSyncConfiguration.ps1 # CREATE
└── Tests/
    └── Public/
        ├── Set-ConfluenceSyncConfiguration.Tests.ps1    # CREATE
        ├── Get-ConfluenceSyncConfiguration.Tests.ps1    # CREATE
        └── Remove-ConfluenceSyncConfiguration.Tests.ps1 # CREATE
```

**Files to Modify:**
```text
Modules/ConfluenceAPI/ConfluenceAPI.psd1  # Add to FunctionsToExport
```

### Common Mistakes to Avoid

1. **DO NOT** use `$script:` directly in tests - clear it in BeforeEach
2. **DO NOT** forget to handle the "no config set yet" case in Get
3. **DO NOT** overwrite entire config when only updating one property (merge pattern)
4. **DO NOT** use `Should -Invoke` - use `Assert-MockCalled` (Pester 3.4)
5. **DO NOT** forget to clone hashtables before modifying
6. **DO NOT** forget WhatIf returns the "would be" configuration
7. **DO NOT** use `throw` directly - though for simple validation PS handles via attributes
8. **DO NOT** forget UTC timestamps with proper format string

### Git Commit Pattern

```
feat: implement Story 8.2 Sync Configuration

- Add Set-ConfluenceSyncConfiguration for configuring sync behavior
- Add Get-ConfluenceSyncConfiguration to retrieve current settings
- Add Remove-ConfluenceSyncConfiguration to reset to defaults
- Support SyncFrequency: Hourly, Daily, Weekly, Manual
- Support retry configuration and incremental sync toggle
- Create XX unit tests (all passing)
- PSScriptAnalyzer: 0 warnings

Story covers FR35 (configure scheduled sync frequency)
```

### References

- [Source: docs/architecture.md#Credential-Storage] - Script-scoped variable pattern
- [Source: docs/architecture.md#WhatIf-Verbose-Pattern] - WhatIf implementation
- [Source: docs/epics.md#Story-8.2] - FR35 requirements
- [Source: docs/prd.md#Sync-Operations] - FR35 sync configuration
- [Source: Modules/ConfluenceAPI/Public/New-ConfluenceAPIKey.ps1] - Set pattern reference
- [Source: Modules/ConfluenceAPI/Public/Get-ConfluenceAPIKey.ps1] - Get pattern reference
- [Source: Modules/ConfluenceAPI/Public/Remove-ConfluenceAPIKey.ps1] - Remove pattern reference
- [Source: docs/sprint-artifacts/8-1-manual-tenant-sync.md] - Previous story learnings

### FRs Covered

- **FR35**: Technical Lead can configure scheduled sync frequency (primary)
- **NFR18**: Module must include -WhatIf support for all write operations
- **NFR19**: Module must include -Verbose logging for troubleshooting

### Future Integration Notes

**Story 8.3 (Retry Logic)** will consume:
- `RetryAttempts` - number of retry attempts
- `RetryDelaySeconds` - base delay for exponential backoff

**Story 8.4 (Incremental Sync)** will consume:
- `EnableIncrementalSync` - whether to skip unchanged data

**Scheduled Sync (Future)** will consume:
- `SyncFrequency` - when to run automatic syncs

## Dev Agent Record

### Context Reference

<!-- Story context analysis completed by create-story workflow -->

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

N/A

### Completion Notes List

1. All 7 tasks completed successfully
2. Created 3 public functions: Set-, Get-, Remove-ConfluenceSyncConfiguration
3. Created 75 unit tests across 3 test files (36 + 20 + 19)
4. All Story 8.2 tests passing
5. PSScriptAnalyzer: 0 warnings on all new files
6. Module exports all 3 new functions correctly
7. Full regression suite has 1 pre-existing failure unrelated to Story 8.2
8. Fixed 2 Pester 3.4 assertion issues in Get tests (Should Contain -> -contains)

### File List

**Created:**
- `Modules/ConfluenceAPI/Public/Set-ConfluenceSyncConfiguration.ps1`
- `Modules/ConfluenceAPI/Public/Get-ConfluenceSyncConfiguration.ps1`
- `Modules/ConfluenceAPI/Public/Remove-ConfluenceSyncConfiguration.ps1`
- `Modules/ConfluenceAPI/Tests/Public/Set-ConfluenceSyncConfiguration.Tests.ps1`
- `Modules/ConfluenceAPI/Tests/Public/Get-ConfluenceSyncConfiguration.Tests.ps1`
- `Modules/ConfluenceAPI/Tests/Public/Remove-ConfluenceSyncConfiguration.Tests.ps1`

**Modified:**
- `Modules/ConfluenceAPI/ConfluenceAPI.psd1` - Added 3 functions to FunctionsToExport
- `docs/sprint-artifacts/sprint-status.yaml` - Status: ready-for-dev → in-progress → review → done
- `docs/sprint-artifacts/8-2-sync-configuration.md` - Updated status and tasks
- `Modules/ConfluenceAPI/Tests/Public/Set-ConfluenceSyncConfiguration.Tests.ps1` - Fixed weak timestamp test

## Senior Developer Review (AI)

**Reviewer:** Claude Opus 4.5 (code-review workflow)
**Date:** 2025-12-15
**Outcome:** APPROVED with fixes applied

### Issues Found & Resolved

| Severity | Issue | Resolution |
|----------|-------|------------|
| HIGH | Test "Updates ConfiguredAt timestamp on each change" only checked `Should Not Be $null`, didn't verify timestamp actually changed | Fixed: Added `$result2.ConfiguredAt | Should Not Be $result1.ConfiguredAt` assertion, increased sleep to 1 second |
| MEDIUM | Story subtask described `-EnableIncrementalSync` as "switch" but implementation uses `[bool]` | Fixed: Updated subtask documentation to clarify bool parameter |
| MEDIUM | Default values duplicated in Set and Get functions | Deferred: Follows existing module pattern (credential management), acceptable for consistency |

### Verification

- All 75 unit tests passing (36 + 20 + 19)
- PSScriptAnalyzer: 0 warnings
- Module exports all 3 functions correctly
- All 8 Acceptance Criteria verified implemented

### Recommendation

Story approved for completion. Implementation follows established module patterns and all ACs are satisfied.
