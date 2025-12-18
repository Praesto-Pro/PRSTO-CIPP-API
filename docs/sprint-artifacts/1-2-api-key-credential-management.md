# Story 1.2: API Key Credential Management

Status: done

## Story

As a **Technical Lead**,
I want **to store my Confluence API key securely in memory**,
so that **subsequent API calls can authenticate without re-entering credentials**.

## Acceptance Criteria

### AC1: Store API Key
**Given** I have a valid Confluence API token
**When** I run `New-ConfluenceAPIKey -ApiKey 'my-token'`
**Then** the token is stored in `$script:ConfluenceAPIKey`
**And** a success message confirms the key was stored
**And** the token value is NEVER output to console or logs (NFR6)

### AC2: Retrieve API Key (Masked)
**Given** an API key is stored
**When** I run `Get-ConfluenceAPIKey`
**Then** a masked representation is returned (e.g., "****...****" - NOT the actual token)
**And** `Write-Verbose` logs "Retrieving stored API key" when `-Verbose` used
**And** the actual token is available internally for API calls

### AC3: Remove API Key
**Given** I want to rotate credentials
**When** I run `Remove-ConfluenceAPIKey`
**Then** `$script:ConfluenceAPIKey` is cleared
**And** `Get-ConfluenceAPIKey` returns null
**And** a confirmation message is displayed

### AC4: WhatIf Support
**Given** I want to preview credential operations
**When** I run `New-ConfluenceAPIKey -ApiKey 'my-token' -WhatIf`
**Then** the operation is described without actually storing the key
**When** I run `Remove-ConfluenceAPIKey -WhatIf`
**Then** the removal is described without clearing the key

### AC5: Error Handling
**Given** no API key is stored
**When** I run `Get-ConfluenceAPIKey`
**Then** null is returned (NOT an error - allows checking if key exists)
**Given** `Remove-ConfluenceAPIKey` is called with no key stored
**When** the function runs
**Then** it completes without error (idempotent operation)

## Tasks / Subtasks

- [x] Task 1: Create New-ConfluenceAPIKey Function (AC: 1, 4)
  - [x] Create `Public/New-ConfluenceAPIKey.ps1` file
  - [x] Implement `[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]`
  - [x] Add `-ApiKey` parameter with `[ValidateNotNullOrEmpty()]`
  - [x] Store token in `$script:ConfluenceAPIKey`
  - [x] Return confirmation message (NOT the token value)
  - [x] Add `Write-Verbose` logging for operation
  - [x] Implement `-WhatIf` support via `$PSCmdlet.ShouldProcess()`
  - [x] Add comment-based help with synopsis, description, parameters, examples

- [x] Task 2: Create Get-ConfluenceAPIKey Function (AC: 2, 5)
  - [x] Create `Public/Get-ConfluenceAPIKey.ps1` file
  - [x] Implement `[CmdletBinding()]`
  - [x] Return masked representation if key exists
  - [x] Return `$null` if no key stored
  - [x] Add `Write-Verbose` logging
  - [x] Add comment-based help

- [x] Task 3: Create Remove-ConfluenceAPIKey Function (AC: 3, 4, 5)
  - [x] Create `Public/Remove-ConfluenceAPIKey.ps1` file
  - [x] Implement `[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]`
  - [x] Clear `$script:ConfluenceAPIKey`
  - [x] Handle already-cleared state gracefully (idempotent)
  - [x] Implement `-WhatIf` support
  - [x] Add confirmation message
  - [x] Add comment-based help

- [x] Task 4: Update Module Manifest (AC: 1, 2, 3)
  - [x] Update `ConfluenceAPI.psd1` FunctionsToExport array
  - [x] Add: `'New-ConfluenceAPIKey'`, `'Get-ConfluenceAPIKey'`, `'Remove-ConfluenceAPIKey'`
  - [x] Verify module loads with new functions via `Test-ModuleManifest`

- [x] Task 5: Create Unit Tests (AC: 1-5)
  - [x] Create `Tests/Public/New-ConfluenceAPIKey.Tests.ps1`
  - [x] Create `Tests/Public/Get-ConfluenceAPIKey.Tests.ps1`
  - [x] Create `Tests/Public/Remove-ConfluenceAPIKey.Tests.ps1`
  - [x] Test: Store key, verify stored
  - [x] Test: Get key returns masked value
  - [x] Test: Remove key clears storage
  - [x] Test: Get with no key returns null
  - [x] Test: Remove with no key doesn't error
  - [x] Test: WhatIf doesn't actually store/remove
  - [x] Test: Token value never appears in output

- [x] Task 6: Validate Implementation (AC: 1-5)
  - [x] Run `Invoke-ScriptAnalyzer -Path ./Modules/ConfluenceAPI/ -Recurse`
  - [x] Run all Pester tests
  - [x] Manual verification of all acceptance criteria
  - [x] Verify token never appears in `-Verbose` output

## Dev Notes

### Architecture Compliance

**Module Location:** `Modules/ConfluenceAPI/Public/`

All three functions go in `Public/` because they are user-facing credential management operations. This matches the HuduAPI pattern where credential functions are directly accessible to users.

**Function Structure (from architecture.md):**
```powershell
function Verb-ConfluenceNoun {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Level')]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ParameterName
    )

    Write-Verbose "Verb-ing noun '$ParameterName'"

    if ($PSCmdlet.ShouldProcess($ParameterName, "Description of action")) {
        # Implementation
    }
}
```

**Credential Storage Pattern (from architecture.md):**
- Store in script-scoped variable: `$script:ConfluenceAPIKey`
- Memory-only storage (NOT persisted to disk)
- Matches HuduAPI pattern: `$script:HuduAPIKey`
- Clear on module removal (handled by PowerShell automatically)

### Technical Requirements

**API Token Format (from Atlassian documentation):**
- Tokens are 24+ character strings generated at https://id.atlassian.com/manage/api-tokens
- Used with email for Basic Auth: `email:token` → Base64 encoded
- Tokens expire after 1 year (as of March 2025 Atlassian policy)
- Scoped tokens require different URL format: `https://api.atlassian.com/ex/confluence/{cloudId}`

**Security Requirements (NFR5, NFR6):**
- NEVER log the actual token value
- NEVER return the actual token to console
- Token only used internally for API authentication
- Masked output format: `"****...****"` (first 4 + last 4 chars only, or just asterisks)

**PowerShell Compatibility:**
- Must work on Windows PowerShell 5.1 AND PowerShell 7+
- Use `[SecureString]` considerations: Not needed for memory-only storage
- Avoid PS 7+ only syntax (no ternary `?:`, no null coalescing `??`)

### Previous Story Intelligence

**Story 1.1 Learnings (Module Scaffold):**
- Module structure established at `Modules/ConfluenceAPI/`
- Module loader (psm1) dot-sources all `Public/*.ps1` files automatically
- Manifest (psd1) requires explicit FunctionsToExport list (no wildcards)
- PSScriptAnalyzer must pass with zero errors/warnings
- .gitkeep files preserve directory structure

**Files to Modify:**
- `Modules/ConfluenceAPI/ConfluenceAPI.psd1` - Update FunctionsToExport

**Files to Create:**
- `Modules/ConfluenceAPI/Public/New-ConfluenceAPIKey.ps1`
- `Modules/ConfluenceAPI/Public/Get-ConfluenceAPIKey.ps1`
- `Modules/ConfluenceAPI/Public/Remove-ConfluenceAPIKey.ps1`
- `Modules/ConfluenceAPI/Tests/Public/New-ConfluenceAPIKey.Tests.ps1`
- `Modules/ConfluenceAPI/Tests/Public/Get-ConfluenceAPIKey.Tests.ps1`
- `Modules/ConfluenceAPI/Tests/Public/Remove-ConfluenceAPIKey.Tests.ps1`

### Project Structure Notes

**Alignment with Module Structure:**
```text
Modules/ConfluenceAPI/
├── ConfluenceAPI.psd1          # Update FunctionsToExport
├── ConfluenceAPI.psm1          # No changes (auto-loads Public/*.ps1)
├── Public/
│   ├── New-ConfluenceAPIKey.ps1    # CREATE
│   ├── Get-ConfluenceAPIKey.ps1    # CREATE
│   └── Remove-ConfluenceAPIKey.ps1 # CREATE
├── Private/                    # No changes
└── Tests/
    └── Public/
        ├── New-ConfluenceAPIKey.Tests.ps1    # CREATE
        ├── Get-ConfluenceAPIKey.Tests.ps1    # CREATE
        └── Remove-ConfluenceAPIKey.Tests.ps1 # CREATE
```

### References

- [Source: docs/architecture.md#Authentication-Security] - Credential storage pattern
- [Source: docs/architecture.md#Implementation-Patterns] - WhatIf/Verbose pattern
- [Source: docs/project_context.md#Credential-Pattern] - Script-scoped storage
- [Source: docs/project_context.md#Function-Structure] - CmdletBinding requirements
- [Source: docs/prd.md#FR1-FR4] - Configuration & Credentials requirements
- [Source: docs/epics.md#Story-1.2] - Acceptance criteria
- [Atlassian: Basic Auth for REST APIs](https://developer.atlassian.com/cloud/confluence/basic-auth-for-rest-apis/)
- [Atlassian: Manage API Tokens](https://support.atlassian.com/atlassian-account/docs/manage-api-tokens-for-your-atlassian-account/)

### Code Templates

**New-ConfluenceAPIKey.ps1 Template:**
```powershell
function New-ConfluenceAPIKey {
    <#
    .SYNOPSIS
        Stores the Confluence API key for authentication.
    .DESCRIPTION
        Stores the provided API token in a script-scoped variable for use by
        other ConfluenceAPI functions. The token is stored in memory only
        and is never persisted to disk or logged.
    .PARAMETER ApiKey
        The Atlassian API token generated from https://id.atlassian.com/manage/api-tokens
    .EXAMPLE
        New-ConfluenceAPIKey -ApiKey 'your-api-token-here'

        Stores the API key for subsequent API calls.
    .EXAMPLE
        New-ConfluenceAPIKey -ApiKey $token -WhatIf

        Shows what would happen without actually storing the key.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ApiKey
    )

    Write-Verbose "Storing Confluence API key"

    if ($PSCmdlet.ShouldProcess("Confluence API Key", "Store credential")) {
        $script:ConfluenceAPIKey = $ApiKey
        Write-Output "Confluence API key has been stored successfully."
    }
}
```

**Get-ConfluenceAPIKey.ps1 Template:**
```powershell
function Get-ConfluenceAPIKey {
    <#
    .SYNOPSIS
        Retrieves the stored Confluence API key status.
    .DESCRIPTION
        Returns a masked representation of the stored API key to confirm
        a key is configured. The actual token is never returned to prevent
        accidental exposure.
    .EXAMPLE
        Get-ConfluenceAPIKey

        Returns masked key representation if stored, null otherwise.
    .EXAMPLE
        Get-ConfluenceAPIKey -Verbose

        Returns masked key with verbose logging.
    #>
    [CmdletBinding()]
    param()

    Write-Verbose "Retrieving stored API key"

    if ($script:ConfluenceAPIKey) {
        # Return masked representation - NEVER the actual token
        [PSCustomObject]@{
            IsConfigured = $true
            MaskedKey = "****...****"
        }
    }
    else {
        $null
    }
}
```

**Remove-ConfluenceAPIKey.ps1 Template:**
```powershell
function Remove-ConfluenceAPIKey {
    <#
    .SYNOPSIS
        Removes the stored Confluence API key.
    .DESCRIPTION
        Clears the stored API key from memory. This function is idempotent -
        calling it when no key is stored does not produce an error.
    .EXAMPLE
        Remove-ConfluenceAPIKey

        Removes the stored API key.
    .EXAMPLE
        Remove-ConfluenceAPIKey -WhatIf

        Shows what would happen without actually removing the key.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param()

    Write-Verbose "Removing stored Confluence API key"

    if ($PSCmdlet.ShouldProcess("Confluence API Key", "Remove credential")) {
        $script:ConfluenceAPIKey = $null
        Write-Output "Confluence API key has been removed."
    }
}
```

### Testing Pattern (Pester 5)

```powershell
Describe 'New-ConfluenceAPIKey' {
    BeforeAll {
        # Import module
        Import-Module "$PSScriptRoot/../../ConfluenceAPI.psd1" -Force
    }

    AfterEach {
        # Clean up after each test
        Remove-ConfluenceAPIKey -ErrorAction SilentlyContinue
    }

    It 'Stores API key successfully' {
        New-ConfluenceAPIKey -ApiKey 'test-token-12345'
        $result = Get-ConfluenceAPIKey
        $result.IsConfigured | Should -Be $true
    }

    It 'Does not expose actual token in output' {
        $output = New-ConfluenceAPIKey -ApiKey 'secret-token-xyz' 4>&1
        $output | Should -Not -Match 'secret-token-xyz'
    }

    It 'Supports WhatIf without storing' {
        New-ConfluenceAPIKey -ApiKey 'test-token' -WhatIf
        Get-ConfluenceAPIKey | Should -BeNullOrEmpty
    }
}
```

### Common Mistakes to Avoid

1. **DO NOT** return or log the actual API token value
2. **DO NOT** use `throw` directly - use proper error handling if needed
3. **DO NOT** forget `-WhatIf` support on write operations
4. **DO NOT** use PS 7+ only syntax (ternary, null coalescing)
5. **DO NOT** forget to update FunctionsToExport in the manifest
6. **DO NOT** create functions in Private/ - these are user-facing

### Validation Checklist

After implementation, verify:
```powershell
# 1. Module loads with new functions
Import-Module ./Modules/ConfluenceAPI/ConfluenceAPI.psd1 -Force
Get-Command -Module ConfluenceAPI | Select-Object Name
# Should show: New-ConfluenceAPIKey, Get-ConfluenceAPIKey, Remove-ConfluenceAPIKey

# 2. Store and verify key
New-ConfluenceAPIKey -ApiKey 'test-token-123'
Get-ConfluenceAPIKey  # Should show IsConfigured = $true, MaskedKey = ****...****

# 3. Verify token not exposed
$verbose = New-ConfluenceAPIKey -ApiKey 'secret' -Verbose 4>&1
$verbose | Should -Not -Match 'secret'

# 4. Remove and verify
Remove-ConfluenceAPIKey
Get-ConfluenceAPIKey  # Should be $null

# 5. WhatIf works
New-ConfluenceAPIKey -ApiKey 'test' -WhatIf
Get-ConfluenceAPIKey  # Should still be $null

# 6. PSScriptAnalyzer passes
Invoke-ScriptAnalyzer -Path ./Modules/ConfluenceAPI/ -Recurse -Severity Warning

# 7. Pester tests pass
Invoke-Pester -Path ./Modules/ConfluenceAPI/Tests/
```

## Dev Agent Record

### Context Reference

<!-- Story context analysis completed by create-story workflow -->

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

### Completion Notes List

- Implemented all three credential management functions following HuduAPI pattern
- Functions use script-scoped variable `$script:ConfluenceAPIKey` for memory-only storage
- All functions include `[CmdletBinding()]` and appropriate ShouldProcess support
- Token values are NEVER exposed in output, verbose, or logs (NFR6 compliant)
- Get-ConfluenceAPIKey returns `PSCustomObject` with `IsConfigured` and `MaskedKey` properties
- Tests written in Pester 3.4.0 syntax for Windows PowerShell 5.1 compatibility
- All 22 Pester tests pass (7 for Get, 8 for New, 7 for Remove)
- PSScriptAnalyzer passes with zero warnings
- Module manifest updated with FunctionsToExport

### File List

**Created:**
- Modules/ConfluenceAPI/Public/New-ConfluenceAPIKey.ps1
- Modules/ConfluenceAPI/Public/Get-ConfluenceAPIKey.ps1
- Modules/ConfluenceAPI/Public/Remove-ConfluenceAPIKey.ps1
- Modules/ConfluenceAPI/Tests/Public/New-ConfluenceAPIKey.Tests.ps1
- Modules/ConfluenceAPI/Tests/Public/Get-ConfluenceAPIKey.Tests.ps1
- Modules/ConfluenceAPI/Tests/Public/Remove-ConfluenceAPIKey.Tests.ps1

**Modified:**
- Modules/ConfluenceAPI/ConfluenceAPI.psd1 (FunctionsToExport updated)
- docs/sprint-artifacts/sprint-status.yaml (status: ready-for-dev -> in-progress -> review)

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2025-12-10 | Story created via create-story workflow | Claude Opus 4.5 |
| 2025-12-10 | Implementation complete - all 6 tasks done, 22 tests passing | Claude Opus 4.5 |
| 2025-12-10 | Code review: Fixed 5 issues (1 High, 4 Medium) - tests improved, docs clarified | Claude Opus 4.5 |
