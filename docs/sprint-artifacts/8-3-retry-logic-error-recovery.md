# Story 8.3: Retry Logic & Error Recovery

Status: Done

## Story

As a **Technical Lead**,
I want **sync operations to retry on transient failures**,
so that **temporary issues don't cause sync failures and I can rely on automated processes**.

## Acceptance Criteria

### AC1: Transient Error Retry (FR37, NFR10)
**Given** a sync operation encounters a transient error
**When** the error is a 5xx response, network timeout, or connection failure
**Then** the operation retries up to the configured attempts (default 3)
**And** each retry uses exponential backoff based on RetryDelaySeconds
**And** `Write-Verbose` logs each retry attempt

### AC2: Configurable Retry Behavior
**Given** sync configuration has been set via `Set-ConfluenceSyncConfiguration`
**When** a sync operation retries
**Then** it uses `RetryAttempts` from configuration (default 3)
**And** it uses `RetryDelaySeconds` as base delay for exponential backoff
**And** actual delays are: RetryDelaySeconds * 2^(attempt-1)

### AC3: Error Classification
**Given** an error occurs during sync
**When** the error is classified
**Then** transient errors (retryable) include:
- HTTP 5xx (server errors)
- HTTP 429 (rate limit)
- Network timeouts
- Connection refused/reset
**And** permanent errors (not retryable) include:
- HTTP 4xx (client errors except 429)
- Invalid data format
- Missing required parameters

### AC4: All Retries Exhausted (FR41)
**Given** all retry attempts fail
**When** the final attempt fails
**Then** a detailed error is logged with:
- Original error message
- Number of attempts made
- Total time spent retrying
- Last error details
**And** the sync continues with remaining data types
**And** the failed item is included in the sync summary

### AC5: Retry Logging
**Given** a sync operation retries
**When** each retry attempt occurs
**Then** `Write-Verbose` logs:
- "Retry attempt X of Y for [DataType]"
- "Waiting Z seconds before retry (exponential backoff)"
- "Retry failed: [error message]"

### AC6: WhatIf Support
**Given** I run a sync operation with `-WhatIf`
**When** the operation would normally retry
**Then** no actual retries occur
**And** the operation behaves as before (shows what would happen)

## Tasks / Subtasks

- [x] Task 1: Create Invoke-WithRetry Private Helper Function (AC: 1, 2, 3, 5)
  - [x] Create `Private/Invoke-WithRetry.ps1` file
  - [x] Add `[CmdletBinding()]` attribute
  - [x] Add `-ScriptBlock` parameter for the operation to retry
  - [x] Add `-MaxRetries` parameter (default from config or 3)
  - [x] Add `-BaseDelaySeconds` parameter (default from config or 30)
  - [x] Add `-OperationName` parameter for logging context
  - [x] Implement transient error detection (5xx, 429, timeout, connection errors)
  - [x] Implement exponential backoff: delay = BaseDelay * 2^(attempt-1)
  - [x] Add `Write-Verbose` logging for each retry
  - [x] Return result on success or throw on all retries exhausted
  - [x] Include retry statistics in error (attempts, total time)

- [x] Task 2: Create Unit Tests for Invoke-WithRetry (AC: 1, 2, 3, 4, 5)
  - [x] Create `Tests/Private/Invoke-WithRetry.Tests.ps1`
  - [x] Test: Succeeds on first attempt (no retry needed)
  - [x] Test: Retries on 5xx error
  - [x] Test: Retries on 429 rate limit
  - [x] Test: Retries on network timeout
  - [x] Test: Retries on connection refused
  - [x] Test: Does NOT retry on 4xx client error (except 429)
  - [x] Test: Does NOT retry on invalid data error
  - [x] Test: Respects MaxRetries limit
  - [x] Test: Uses exponential backoff delays
  - [x] Test: Throws after all retries exhausted
  - [x] Test: Error includes attempt count and timing
  - [x] Test: Writes verbose messages during retries

- [x] Task 3: Update Sync-CIPPTenantToConfluence to Use Retry Helper (AC: 1, 2, 4, 6)
  - [x] Import retry helper function
  - [x] Get retry settings from `Get-ConfluenceSyncConfiguration`
  - [x] Wrap each sync operation call with `Invoke-WithRetry`
  - [x] Pass operation name for logging context
  - [x] Preserve WhatIf behavior (skip retry wrapper when WhatIf)
  - [x] Include retry statistics in sync results
  - [x] Update error collection to include retry information

- [x] Task 4: Create Unit Tests for Updated Sync-CIPPTenantToConfluence (AC: 1, 4, 6)
  - [x] Update existing tests to account for retry wrapper
  - [x] Test: Uses retry settings from configuration
  - [x] Test: Retries on transient failure and succeeds
  - [x] Test: Reports retry statistics in results
  - [x] Test: WhatIf does not invoke retry logic
  - [x] Test: Error includes retry attempt information

- [x] Task 5: Run Validation
  - [x] Run `Invoke-ScriptAnalyzer` on new files - 0 warnings
  - [x] Run all new Pester tests - all passing
  - [x] Run full regression tests - verify no regressions
  - [x] Test integration with Story 8.2 configuration settings

## Dev Notes

### Architecture Compliance

**Module Location:**
- `Modules/ConfluenceAPI/Private/Invoke-WithRetry.ps1` - Retry helper function
- `Modules/ConfluenceAPI/Public/Sync-CIPPTenantToConfluence.ps1` - Modified to use retry

Per architecture.md, private helper functions go in Private/:
- [Source: docs/architecture.md#Structure-Patterns] - Private/ for internal helpers
- [Source: docs/architecture.md#Error-Handling-Pattern] - Standard PowerShell ErrorRecord
- [Source: docs/epics.md#Story-8.3] - FR37, NFR10 retry requirements

**Dependencies (All Exist):**
- `Get-ConfluenceSyncConfiguration` (Story 8.2) - provides RetryAttempts, RetryDelaySeconds
- `Sync-CIPPTenantToConfluence` (Story 8.1) - orchestration function to enhance

### Existing Retry Context

**HTTP-Level Retry Already Exists:**
The `Invoke-ConfluenceRequest` function (lines 114-204) already implements HTTP-level retry:
- 3 retries with exponential backoff for 5xx and 429
- Uses `Get-RateLimitDelay` for Retry-After header parsing

**Story 8.3 Adds Sync-Level Retry:**
This story adds a HIGHER-LEVEL retry that wraps entire sync operations:
- Retries the complete data type sync (Users, Endpoints, etc.)
- Uses configuration from Story 8.2
- Handles errors that propagate up from lower levels

### Invoke-WithRetry Function Pattern

```powershell
function Invoke-WithRetry {
    <#
    .SYNOPSIS
        Executes a script block with configurable retry logic.
    .DESCRIPTION
        Wraps any operation with retry support for transient failures.
        Uses exponential backoff and integrates with sync configuration.
    .PARAMETER ScriptBlock
        The operation to execute and potentially retry.
    .PARAMETER MaxRetries
        Maximum number of retry attempts (default: from config or 3).
    .PARAMETER BaseDelaySeconds
        Base delay for exponential backoff (default: from config or 30).
    .PARAMETER OperationName
        Name for logging context (e.g., "UserInventory sync").
    .EXAMPLE
        Invoke-WithRetry -ScriptBlock { Sync-ConfluenceUserInventory -SpaceKey 'TEST' -Users $users } -OperationName 'UserInventory'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,

        [Parameter()]
        [int]$MaxRetries,

        [Parameter()]
        [int]$BaseDelaySeconds,

        [Parameter()]
        [string]$OperationName = 'Operation'
    )

    # Get defaults from configuration if not provided
    if (-not $PSBoundParameters.ContainsKey('MaxRetries') -or
        -not $PSBoundParameters.ContainsKey('BaseDelaySeconds')) {
        $config = Get-ConfluenceSyncConfiguration
        if (-not $PSBoundParameters.ContainsKey('MaxRetries')) {
            $MaxRetries = $config.RetryAttempts
        }
        if (-not $PSBoundParameters.ContainsKey('BaseDelaySeconds')) {
            $BaseDelaySeconds = $config.RetryDelaySeconds
        }
    }

    $attempt = 0
    $startTime = Get-Date
    $lastError = $null

    while ($attempt -le $MaxRetries) {
        $attempt++

        try {
            Write-Verbose "$OperationName - Attempt $attempt of $($MaxRetries + 1)"
            $result = & $ScriptBlock
            return $result
        }
        catch {
            $lastError = $_

            # Classify error
            $isRetryable = Test-TransientError -Exception $_.Exception

            if (-not $isRetryable) {
                Write-Verbose "$OperationName - Permanent error, not retrying: $($_.Exception.Message)"
                throw
            }

            if ($attempt -gt $MaxRetries) {
                Write-Verbose "$OperationName - All $MaxRetries retries exhausted"
                break
            }

            # Calculate exponential backoff delay
            $delay = $BaseDelaySeconds * [math]::Pow(2, $attempt - 1)
            Write-Verbose "$OperationName - Retry $attempt of $MaxRetries failed: $($_.Exception.Message)"
            Write-Verbose "$OperationName - Waiting $delay seconds before retry (exponential backoff)"
            Start-Sleep -Seconds $delay
        }
    }

    # All retries exhausted - throw with details
    $totalTime = (Get-Date) - $startTime
    $errorMessage = "$OperationName failed after $MaxRetries retries over $($totalTime.TotalSeconds.ToString('F1')) seconds. Last error: $($lastError.Exception.Message)"

    $errorRecord = [System.Management.Automation.ErrorRecord]::new(
        [System.Exception]::new($errorMessage, $lastError.Exception),
        'RetryExhausted',
        [System.Management.Automation.ErrorCategory]::OperationTimeout,
        $OperationName
    )
    throw $errorRecord
}
```

### Transient Error Detection Pattern

```powershell
function Test-TransientError {
    <#
    .SYNOPSIS
        Determines if an error is transient (retryable).
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter()]
        [System.Exception]$Exception
    )

    if (-not $Exception) {
        return $false
    }

    $message = $Exception.Message

    # HTTP 5xx server errors
    if ($message -match '\(5\d{2}\)' -or $message -match 'server error') {
        return $true
    }

    # HTTP 429 rate limit
    if ($message -match '\(429\)' -or $message -match 'rate limit') {
        return $true
    }

    # Network/connection errors
    if ($message -match 'timeout|timed out|connection refused|connection reset|unable to connect|network') {
        return $true
    }

    # Confluence server error messages
    if ($message -match 'Confluence server error|Service unavailable|Gateway timeout') {
        return $true
    }

    return $false
}
```

### Updated Sync-CIPPTenantToConfluence Pattern

```powershell
# In the foreach loop for sync operations:
foreach ($op in $syncOperations) {
    # ... existing parameter check ...

    Write-Verbose "Syncing $($op.Name) to space '$spaceKey'"

    if ($PSCmdlet.ShouldProcess("$($op.Name) in $spaceKey", "Sync CIPP data")) {
        try {
            # Build parameters for sync function
            $syncParams = @{
                SpaceKey = $spaceKey
            }
            $syncParams[$op.DataParam] = $op.Data

            # Wrap with retry logic
            $syncFunctionResult = Invoke-WithRetry -ScriptBlock {
                & $op.Function @syncParams
            } -OperationName $op.Name

            $syncResults += [PSCustomObject]@{
                DataType     = $op.Name
                Status       = 'Success'
                PageId       = $syncFunctionResult.Id
                Message      = "Synced successfully"
                RetryCount   = 0  # Track retries if needed
            }
            Write-Verbose "$($op.Name) sync completed successfully"
        }
        catch {
            # Error already includes retry information if retries were attempted
            Write-Warning "$($op.Name) sync failed: $($_.Exception.Message)"
            $syncResults += [PSCustomObject]@{
                DataType     = $op.Name
                Status       = 'Failed'
                PageId       = $null
                Message      = $_.Exception.Message
            }
            $errors += [PSCustomObject]@{
                DataType  = $op.Name
                Error     = $_.Exception.Message
                Timestamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss')
            }
        }
    }
    # ... rest of WhatIf handling ...
}
```

### Testing Pattern (Pester 3.4 Compatible)

```powershell
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleRoot = Split-Path -Parent (Split-Path -Parent $here)
$privateDir = Join-Path $moduleRoot 'Private'
$publicDir = Join-Path $moduleRoot 'Public'

Describe 'Invoke-WithRetry' {
    BeforeAll {
        # Stub configuration function
        function Get-ConfluenceSyncConfiguration {
            [PSCustomObject]@{
                RetryAttempts     = 3
                RetryDelaySeconds = 1  # Use 1 second for fast tests
            }
        }

        . "$privateDir\Invoke-WithRetry.ps1"
    }

    Context 'Successful Operations' {
        It 'Returns result on first attempt success' {
            $result = Invoke-WithRetry -ScriptBlock { 'success' } -OperationName 'Test'
            $result | Should Be 'success'
        }

        It 'Does not retry when operation succeeds' {
            $script:attemptCount = 0
            $result = Invoke-WithRetry -ScriptBlock {
                $script:attemptCount++
                'success'
            } -OperationName 'Test'
            $script:attemptCount | Should Be 1
        }
    }

    Context 'Transient Error Retry' {
        It 'Retries on 5xx server error' {
            $script:attemptCount = 0
            $result = Invoke-WithRetry -ScriptBlock {
                $script:attemptCount++
                if ($script:attemptCount -lt 2) {
                    throw "Server error (500)"
                }
                'success'
            } -OperationName 'Test' -BaseDelaySeconds 0

            $result | Should Be 'success'
            $script:attemptCount | Should Be 2
        }

        It 'Retries on 429 rate limit' {
            $script:attemptCount = 0
            $result = Invoke-WithRetry -ScriptBlock {
                $script:attemptCount++
                if ($script:attemptCount -lt 2) {
                    throw "Rate limit exceeded (429)"
                }
                'success'
            } -OperationName 'Test' -BaseDelaySeconds 0

            $result | Should Be 'success'
        }

        It 'Retries on network timeout' {
            $script:attemptCount = 0
            $result = Invoke-WithRetry -ScriptBlock {
                $script:attemptCount++
                if ($script:attemptCount -lt 2) {
                    throw "Connection timed out"
                }
                'success'
            } -OperationName 'Test' -BaseDelaySeconds 0

            $result | Should Be 'success'
        }
    }

    Context 'Non-Retryable Errors' {
        It 'Does NOT retry on 4xx client error' {
            $script:attemptCount = 0
            {
                Invoke-WithRetry -ScriptBlock {
                    $script:attemptCount++
                    throw "Bad request (400)"
                } -OperationName 'Test' -BaseDelaySeconds 0
            } | Should Throw

            $script:attemptCount | Should Be 1
        }

        It 'Does NOT retry on 404 not found' {
            $script:attemptCount = 0
            {
                Invoke-WithRetry -ScriptBlock {
                    $script:attemptCount++
                    throw "Not found (404)"
                } -OperationName 'Test' -BaseDelaySeconds 0
            } | Should Throw

            $script:attemptCount | Should Be 1
        }
    }

    Context 'Retry Exhaustion' {
        It 'Throws after max retries exhausted' {
            {
                Invoke-WithRetry -ScriptBlock {
                    throw "Server error (500)"
                } -OperationName 'Test' -MaxRetries 2 -BaseDelaySeconds 0
            } | Should Throw
        }

        It 'Error message includes retry count' {
            try {
                Invoke-WithRetry -ScriptBlock {
                    throw "Server error (500)"
                } -OperationName 'TestOp' -MaxRetries 2 -BaseDelaySeconds 0
            }
            catch {
                $_.Exception.Message | Should Match 'TestOp failed after 2 retries'
            }
        }
    }

    Context 'Configuration Integration' {
        It 'Uses RetryAttempts from configuration' {
            $script:attemptCount = 0
            try {
                Invoke-WithRetry -ScriptBlock {
                    $script:attemptCount++
                    throw "Server error (500)"
                } -OperationName 'Test' -BaseDelaySeconds 0
            }
            catch { }
            # Config has RetryAttempts=3, so should attempt 3+1=4 times
            $script:attemptCount | Should Be 4
        }
    }

    Context 'Verbose Logging' {
        It 'Writes verbose messages during retries' {
            $script:attemptCount = 0
            $verboseOutput = Invoke-WithRetry -ScriptBlock {
                $script:attemptCount++
                if ($script:attemptCount -lt 2) {
                    throw "Server error (500)"
                }
                'success'
            } -OperationName 'TestOp' -BaseDelaySeconds 0 -Verbose 4>&1

            $verboseMessages = $verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }
            $verboseText = $verboseMessages -join ' '
            $verboseText | Should Match 'TestOp'
        }
    }
}
```

### Previous Story Intelligence (Story 8.2 Learnings)

**Key Learnings to Apply:**

1. **Pester 3.4 Syntax (CRITICAL):**
   - Use `Should Be` (no hyphen) for Windows PS 5.1 compatibility
   - Use `Should Not Be $null` for null checks
   - Use `Should Throw` / `Should Not Throw` for exception tests
   - Define stub functions before testing

2. **Script-Scoped Variables:**
   - Use `$script:` for counter variables in tests
   - Reset counters in each test

3. **Configuration Integration:**
   - Call `Get-ConfluenceSyncConfiguration` to get retry settings
   - Provide defaults if config not set

4. **Error Handling:**
   - Use `$PSCmdlet.ThrowTerminatingError()` for module functions
   - For helper functions, standard `throw` with ErrorRecord is acceptable
   - Include context in error messages

5. **Testing with Sleep:**
   - Use `BaseDelaySeconds = 0` in tests to avoid slow tests
   - Verify delay logic separately if needed

### Project Structure Notes

**Files to Create:**
```text
Modules/ConfluenceAPI/
├── Private/
│   └── Invoke-WithRetry.ps1             # CREATE
└── Tests/
    └── Private/
        └── Invoke-WithRetry.Tests.ps1   # CREATE
```

**Files to Modify:**
```text
Modules/ConfluenceAPI/Public/Sync-CIPPTenantToConfluence.ps1  # MODIFY
Modules/ConfluenceAPI/Tests/Public/Sync-CIPPTenantToConfluence.Tests.ps1  # MODIFY
```

### Common Mistakes to Avoid

1. **DO NOT** use `Should -Invoke` - use Pester 3.4 syntax
2. **DO NOT** hardcode retry counts - read from configuration
3. **DO NOT** use long sleep delays in tests - use 0 or 1 second
4. **DO NOT** retry on 4xx errors (except 429) - these are permanent
5. **DO NOT** forget to reset `$script:` counters between tests
6. **DO NOT** swallow errors silently - always log or propagate
7. **DO NOT** modify the HTTP-level retry in `Invoke-ConfluenceRequest` - that's separate
8. **DO NOT** break WhatIf behavior - skip retry wrapper when WhatIf

### Git Commit Pattern

```
feat: implement Story 8.3 Retry Logic & Error Recovery

- Add Invoke-WithRetry private helper for configurable retry
- Support exponential backoff with configurable base delay
- Integrate retry settings from Get-ConfluenceSyncConfiguration
- Classify errors as transient (retryable) or permanent
- Update Sync-CIPPTenantToConfluence to use retry wrapper
- Create XX unit tests (all passing)
- PSScriptAnalyzer: 0 warnings

Story covers FR37 (retry logic), NFR10 (3-retry with backoff), FR41 (detailed error logging)
```

### References

- [Source: docs/architecture.md#Error-Handling-Pattern] - Standard error handling
- [Source: docs/architecture.md#Structure-Patterns] - Private/ for helpers
- [Source: docs/epics.md#Story-8.3] - FR37, NFR10 requirements
- [Source: docs/prd.md#Reliability] - NFR10 transient failure retry
- [Source: Modules/ConfluenceAPI/Public/Invoke-ConfluenceRequest.ps1] - HTTP-level retry reference
- [Source: Modules/ConfluenceAPI/Private/Get-RateLimitDelay.ps1] - Existing rate limit helper
- [Source: Modules/ConfluenceAPI/Public/Sync-CIPPTenantToConfluence.ps1] - Function to enhance
- [Source: docs/sprint-artifacts/8-2-sync-configuration.md] - Configuration integration
- [Source: docs/sprint-artifacts/8-1-manual-tenant-sync.md] - Sync function patterns

### FRs Covered

- **FR37**: System can handle sync failures with retry logic (primary)
- **FR41**: System can log detailed error information for troubleshooting
- **NFR10**: Transient failures must retry automatically (up to 3 attempts with backoff)
- **NFR19**: Module must include -Verbose logging for troubleshooting
- **NFR20**: Error messages must include actionable troubleshooting guidance

### Integration with Other Stories

**From Story 8.2 (Sync Configuration):**
- `RetryAttempts` - maximum retry attempts (1-10, default 3)
- `RetryDelaySeconds` - base delay for exponential backoff (5-300, default 30)

**For Story 8.4 (Incremental Sync):**
- Retry logic will also apply to incremental sync operations

## Dev Agent Record

### Context Reference

<!-- Story context analysis completed by create-story workflow -->

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

### Completion Notes List

- Created `Invoke-WithRetry` private helper function with configurable retry logic
- Implemented `Test-TransientError` helper to classify errors (transient vs permanent)
- Transient errors (retryable): 5xx, 429, timeout, connection errors
- Permanent errors (not retried): 4xx (except 429), validation errors
- Exponential backoff formula: `BaseDelaySeconds * 2^(attempt-1)`
- Integrates with Story 8.2's `Get-ConfluenceSyncConfiguration` for retry settings
- Updated `Sync-CIPPTenantToConfluence` to wrap sync operations with retry logic
- WhatIf behavior preserved - no retries occur when WhatIf is specified
- Created 62 unit tests for Invoke-WithRetry and Test-TransientError
- Added 14 retry integration tests to Sync-CIPPTenantToConfluence.Tests.ps1
- PSScriptAnalyzer: 0 warnings
- Full regression: 1331 tests passing

### File List

**New Files:**
- Modules/ConfluenceAPI/Private/Invoke-WithRetry.ps1
- Modules/ConfluenceAPI/Tests/Private/Invoke-WithRetry.Tests.ps1

**Modified Files:**
- Modules/ConfluenceAPI/Public/Sync-CIPPTenantToConfluence.ps1
- Modules/ConfluenceAPI/Tests/Public/Sync-CIPPTenantToConfluence.Tests.ps1
- docs/sprint-artifacts/sprint-status.yaml

### Change Log

- 2025-12-15: Code Review Fixes (AI-Review)
  - [M1] Updated verbose log format to match AC5 specification
  - [M2] Added AttemptsTaken parameter to Invoke-WithRetry
  - [M2] Added RetryCount property to SyncResults for all statuses
  - [M3] Added sprint-status.yaml to File List
  - Added 6 new tests (3 for AttemptsTaken, 3 for RetryCount)
  - Total tests: 65 (Invoke-WithRetry) + 59 (Sync) = 124 tests passing

- 2025-12-15: Implemented Story 8.3 - Retry Logic & Error Recovery
  - Added Invoke-WithRetry private helper with exponential backoff
  - Added Test-TransientError for error classification
  - Integrated retry wrapper into Sync-CIPPTenantToConfluence
  - Created 76 new tests (62 for retry, 14 for integration)
