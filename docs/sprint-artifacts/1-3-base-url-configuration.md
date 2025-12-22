# Story 1.3: Base URL Configuration

Status: done

## Story

As a **Technical Lead**,
I want **to configure the Confluence instance URL supporting both URL formats**,
so that **the module works with standard instances and service accounts**.

## Acceptance Criteria

### AC1: Standard URL Configuration
**Given** I have a standard Confluence URL
**When** I run `New-ConfluenceBaseURL -BaseURL 'https://mycompany.atlassian.net/wiki'`
**Then** the URL is stored in `$script:ConfluenceBaseURL`
**And** a success message confirms the URL was stored
**And** the URL is accessible for API calls by internal functions

### AC2: Trailing Slash Normalization
**Given** I provide a URL with a trailing slash
**When** I run `New-ConfluenceBaseURL -BaseURL 'https://mycompany.atlassian.net/wiki/'`
**Then** the trailing slash is removed before storing
**And** `Get-ConfluenceBaseURL` returns the normalized URL (no trailing slash)

### AC3: Service Account URL Support
**Given** I have a service account URL with cloud ID
**When** I run `New-ConfluenceBaseURL -BaseURL 'https://api.atlassian.com/ex/confluence/abc123'`
**Then** the URL is stored correctly for scoped API access
**And** the URL format is preserved without modification (except trailing slash normalization)

### AC4: Retrieve Base URL
**Given** a base URL is configured
**When** I run `Get-ConfluenceBaseURL`
**Then** the stored URL is returned as a string
**And** `Write-Verbose` logs "Retrieving stored Confluence base URL" when `-Verbose` used

### AC5: Remove Base URL
**Given** a base URL is configured
**When** I run `Remove-ConfluenceBaseURL`
**Then** `$script:ConfluenceBaseURL` is cleared
**And** `Get-ConfluenceBaseURL` returns null
**And** a confirmation message is displayed

### AC6: WhatIf Support
**Given** I want to preview URL configuration operations
**When** I run `New-ConfluenceBaseURL -BaseURL 'https://example.atlassian.net/wiki' -WhatIf`
**Then** the operation is described without actually storing the URL
**When** I run `Remove-ConfluenceBaseURL -WhatIf`
**Then** the removal is described without clearing the URL

### AC7: Input Validation
**Given** I provide an invalid URL format
**When** I run `New-ConfluenceBaseURL -BaseURL 'not-a-valid-url'`
**Then** a validation error is thrown
**And** the error message indicates the expected URL format
**Given** I provide an empty string
**When** I run `New-ConfluenceBaseURL -BaseURL ''`
**Then** a parameter validation error is thrown

### AC8: Idempotent Behavior
**Given** no base URL is stored
**When** I run `Get-ConfluenceBaseURL`
**Then** null is returned (NOT an error - allows checking if URL exists)
**Given** `Remove-ConfluenceBaseURL` is called with no URL stored
**When** the function runs
**Then** it completes without error (idempotent operation)

## Tasks / Subtasks

- [x] Task 1: Create New-ConfluenceBaseURL Function (AC: 1, 2, 3, 6, 7)
  - [x] Create `Public/New-ConfluenceBaseURL.ps1` file
  - [x] Implement `[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]`
  - [x] Add `-BaseURL` parameter with `[ValidateNotNullOrEmpty()]`
  - [x] Add URL format validation (must start with https://)
  - [x] Implement trailing slash normalization using `.TrimEnd('/')`
  - [x] Store URL in `$script:ConfluenceBaseURL`
  - [x] Return confirmation message (include normalized URL in verbose)
  - [x] Implement `-WhatIf` support via `$PSCmdlet.ShouldProcess()`
  - [x] Add comment-based help with synopsis, description, parameters, examples

- [x] Task 2: Create Get-ConfluenceBaseURL Function (AC: 4, 8)
  - [x] Create `Public/Get-ConfluenceBaseURL.ps1` file
  - [x] Implement `[CmdletBinding()]`
  - [x] Return stored URL as string if exists
  - [x] Return `$null` if no URL stored
  - [x] Add `Write-Verbose` logging
  - [x] Add comment-based help

- [x] Task 3: Create Remove-ConfluenceBaseURL Function (AC: 5, 6, 8)
  - [x] Create `Public/Remove-ConfluenceBaseURL.ps1` file
  - [x] Implement `[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]`
  - [x] Clear `$script:ConfluenceBaseURL`
  - [x] Handle already-cleared state gracefully (idempotent)
  - [x] Implement `-WhatIf` support
  - [x] Add confirmation message
  - [x] Add comment-based help

- [x] Task 4: Update Module Manifest (AC: 1, 4, 5)
  - [x] Update `ConfluenceAPI.psd1` FunctionsToExport array
  - [x] Add: `'New-ConfluenceBaseURL'`, `'Get-ConfluenceBaseURL'`, `'Remove-ConfluenceBaseURL'`
  - [x] Verify module loads with new functions via `Test-ModuleManifest`

- [x] Task 5: Create Unit Tests (AC: 1-8)
  - [x] Create `Tests/Public/New-ConfluenceBaseURL.Tests.ps1`
  - [x] Create `Tests/Public/Get-ConfluenceBaseURL.Tests.ps1`
  - [x] Create `Tests/Public/Remove-ConfluenceBaseURL.Tests.ps1`
  - [x] Test: Store standard URL, verify stored
  - [x] Test: Store service account URL, verify stored
  - [x] Test: Trailing slash is normalized
  - [x] Test: Get URL returns stored value
  - [x] Test: Remove URL clears storage
  - [x] Test: Get with no URL returns null
  - [x] Test: Remove with no URL doesn't error
  - [x] Test: WhatIf doesn't actually store/remove
  - [x] Test: Invalid URL format rejected
  - [x] Test: Empty string rejected

- [x] Task 6: Validate Implementation (AC: 1-8)
  - [x] Run `Invoke-ScriptAnalyzer -Path ./Modules/ConfluenceAPI/ -Recurse`
  - [x] Run all Pester tests
  - [x] Manual verification of all acceptance criteria
  - [x] Verify both URL formats work correctly

## Dev Notes

### Architecture Compliance

**Module Location:** `Modules/ConfluenceAPI/Public/`

All three functions go in `Public/` because they are user-facing configuration operations. This matches the HuduAPI pattern where configuration functions are directly accessible to users.

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

**URL Storage Pattern (from architecture.md):**
- Store in script-scoped variable: `$script:ConfluenceBaseURL`
- Memory-only storage (NOT persisted to disk)
- Matches HuduAPI pattern: `$script:HuduBaseURL`
- Clear on module removal (handled by PowerShell automatically)

### Technical Requirements

**Supported URL Formats (from architecture.md):**

1. **Standard URL Format:**
   - Pattern: `https://{domain}.atlassian.net/wiki`
   - Example: `https://mycompany.atlassian.net/wiki`
   - Used with: User API tokens, direct access

2. **Service Account URL Format (Scoped):**
   - Pattern: `https://api.atlassian.com/ex/confluence/{cloudId}`
   - Example: `https://api.atlassian.com/ex/confluence/abc123-def456`
   - Used with: Service account tokens, OAuth apps
   - Note: Cloud ID is a UUID-like identifier for the Confluence instance

**URL Validation Requirements:**
- Must start with `https://` (HTTP not allowed for security)
- Must be a valid URI format
- Trailing slashes should be normalized (removed)
- Both standard and service account formats are valid

**Security Considerations:**
- URL can be logged (unlike API tokens) - it's not sensitive
- Use verbose logging to confirm URL being used

**PowerShell Compatibility:**
- Must work on Windows PowerShell 5.1 AND PowerShell 7+
- Use `[System.Uri]` for URL validation (works on both versions)
- Avoid PS 7+ only syntax (no ternary `?:`, no null coalescing `??`)

### Previous Story Intelligence

**Story 1.2 Learnings (API Key Credential Management):**
- Script-scoped variables work well for configuration storage
- BeforeAll for module import (not BeforeEach) - reduces test time
- Path resolution: `(Get-Item "$PSScriptRoot\..\..\ConfluenceAPI.psd1").FullName`
- Pester 3.4.0 syntax required (unhyphenated `Should Be`)
- Idempotent operations (Remove doesn't error if nothing stored)
- WhatIf tests verify parameter exists, not output capture

**Return Type Design Decision:**

- `Get-ConfluenceAPIKey` returns `PSCustomObject` with `IsConfigured` and `MaskedKey` properties because API tokens are secrets that must never be exposed
- `Get-ConfluenceBaseURL` returns a raw `string` because URLs are NOT secrets and can be safely displayed, logged, and used in scripts directly
- This design difference is intentional: secrets get masked objects, configuration values get direct values

**Code Review Feedback from 1.2:**
- Document internal access patterns in help text
- Add `[OutputType()]` attribute to functions
- Use BeforeAll for module import (not BeforeEach)

**Files to Modify:**
- `Modules/ConfluenceAPI/ConfluenceAPI.psd1` - Update FunctionsToExport

**Files to Create:**
- `Modules/ConfluenceAPI/Public/New-ConfluenceBaseURL.ps1`
- `Modules/ConfluenceAPI/Public/Get-ConfluenceBaseURL.ps1`
- `Modules/ConfluenceAPI/Public/Remove-ConfluenceBaseURL.ps1`
- `Modules/ConfluenceAPI/Tests/Public/New-ConfluenceBaseURL.Tests.ps1`
- `Modules/ConfluenceAPI/Tests/Public/Get-ConfluenceBaseURL.Tests.ps1`
- `Modules/ConfluenceAPI/Tests/Public/Remove-ConfluenceBaseURL.Tests.ps1`

### Project Structure Notes

**Alignment with Module Structure:**
```text
Modules/ConfluenceAPI/
├── ConfluenceAPI.psd1          # Update FunctionsToExport
├── ConfluenceAPI.psm1          # No changes (auto-loads Public/*.ps1)
├── Public/
│   ├── New-ConfluenceAPIKey.ps1    # Existing (Story 1.2)
│   ├── Get-ConfluenceAPIKey.ps1    # Existing (Story 1.2)
│   ├── Remove-ConfluenceAPIKey.ps1 # Existing (Story 1.2)
│   ├── New-ConfluenceBaseURL.ps1    # CREATE
│   ├── Get-ConfluenceBaseURL.ps1    # CREATE
│   └── Remove-ConfluenceBaseURL.ps1 # CREATE
├── Private/                    # No changes
└── Tests/
    └── Public/
        ├── New-ConfluenceAPIKey.Tests.ps1    # Existing
        ├── Get-ConfluenceAPIKey.Tests.ps1    # Existing
        ├── Remove-ConfluenceAPIKey.Tests.ps1 # Existing
        ├── New-ConfluenceBaseURL.Tests.ps1    # CREATE
        ├── Get-ConfluenceBaseURL.Tests.ps1    # CREATE
        └── Remove-ConfluenceBaseURL.Tests.ps1 # CREATE
```

### References

- [Source: docs/architecture.md#Authentication-Security] - Dual URL format support
- [Source: docs/architecture.md#Core-Architectural-Decisions] - URL Formats decision
- [Source: docs/architecture.md#Implementation-Patterns] - WhatIf/Verbose pattern
- [Source: docs/project_context.md#Credential-Pattern] - Script-scoped storage
- [Source: docs/project_context.md#Function-Structure] - CmdletBinding requirements
- [Source: docs/prd.md#FR1-FR4] - Configuration & Credentials requirements
- [Source: docs/epics.md#Story-1.3] - Acceptance criteria
- [Source: docs/sprint-artifacts/1-2-api-key-credential-management.md] - Previous story patterns
- [Atlassian: Confluence Cloud REST API](https://developer.atlassian.com/cloud/confluence/rest/v2/intro/)
- [Atlassian: Scoped App Authorization](https://developer.atlassian.com/cloud/confluence/scoped-app-authorization/)

### Code Templates

**New-ConfluenceBaseURL.ps1 Template:**
```powershell
function New-ConfluenceBaseURL {
    <#
    .SYNOPSIS
        Sets the Confluence instance base URL for API calls.
    .DESCRIPTION
        Stores the Confluence base URL in a script-scoped variable for use by
        other ConfluenceAPI functions. Supports both standard Confluence URLs
        and service account scoped URLs.

        Supported URL formats:
        - Standard: https://{domain}.atlassian.net/wiki
        - Service Account: https://api.atlassian.com/ex/confluence/{cloudId}

        Trailing slashes are automatically normalized (removed).
    .PARAMETER BaseURL
        The Confluence instance base URL. Must be a valid HTTPS URL.
    .EXAMPLE
        New-ConfluenceBaseURL -BaseURL 'https://mycompany.atlassian.net/wiki'

        Sets the base URL for a standard Confluence Cloud instance.
    .EXAMPLE
        New-ConfluenceBaseURL -BaseURL 'https://api.atlassian.com/ex/confluence/abc123-def456'

        Sets the base URL for service account access using cloud ID.
    .EXAMPLE
        New-ConfluenceBaseURL -BaseURL 'https://example.atlassian.net/wiki/' -Verbose

        Sets the URL with trailing slash normalized, with verbose output.
    .NOTES
        Internal Access: Other module functions access $script:ConfluenceBaseURL directly.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$BaseURL
    )

    # Validate URL format
    $uri = $null
    $isValidUri = [System.Uri]::TryCreate($BaseURL, [System.UriKind]::Absolute, [ref]$uri)

    if (-not $isValidUri -or $uri.Scheme -ne 'https') {
        $errorMessage = "Invalid URL format. URL must be a valid HTTPS URL. Expected formats: " +
                        "'https://{domain}.atlassian.net/wiki' or " +
                        "'https://api.atlassian.com/ex/confluence/{cloudId}'"
        $PSCmdlet.ThrowTerminatingError(
            [System.Management.Automation.ErrorRecord]::new(
                [System.ArgumentException]::new($errorMessage),
                "InvalidURLFormat",
                [System.Management.Automation.ErrorCategory]::InvalidArgument,
                $BaseURL
            )
        )
    }

    # Normalize trailing slash
    $normalizedURL = $BaseURL.TrimEnd('/')

    Write-Verbose "Storing Confluence base URL: $normalizedURL"

    if ($PSCmdlet.ShouldProcess("Confluence Base URL", "Store configuration")) {
        $script:ConfluenceBaseURL = $normalizedURL
        Write-Output "Confluence base URL has been stored successfully."
    }
}
```

**Get-ConfluenceBaseURL.ps1 Template:**
```powershell
function Get-ConfluenceBaseURL {
    <#
    .SYNOPSIS
        Retrieves the stored Confluence base URL.
    .DESCRIPTION
        Returns the stored Confluence base URL for API calls. Returns null if
        no URL has been configured.

        Internal module functions access $script:ConfluenceBaseURL directly
        for API calls. This function is for user verification and scripting.
    .EXAMPLE
        Get-ConfluenceBaseURL

        Returns the stored base URL, or null if not configured.
    .EXAMPLE
        Get-ConfluenceBaseURL -Verbose

        Returns the stored base URL with verbose logging.
    .EXAMPLE
        if (Get-ConfluenceBaseURL) { Write-Host "URL configured" }

        Checks if a base URL has been configured.
    .NOTES
        Internal Access: Other module functions access $script:ConfluenceBaseURL directly.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    Write-Verbose "Retrieving stored Confluence base URL"

    if ($script:ConfluenceBaseURL) {
        Write-Verbose "Base URL: $script:ConfluenceBaseURL"
        $script:ConfluenceBaseURL
    }
    else {
        Write-Verbose "No base URL configured"
        $null
    }
}
```

**Remove-ConfluenceBaseURL.ps1 Template:**
```powershell
function Remove-ConfluenceBaseURL {
    <#
    .SYNOPSIS
        Removes the stored Confluence base URL.
    .DESCRIPTION
        Clears the stored Confluence base URL from memory. This function is
        idempotent - calling it when no URL is stored does not produce an error.
    .EXAMPLE
        Remove-ConfluenceBaseURL

        Removes the stored base URL.
    .EXAMPLE
        Remove-ConfluenceBaseURL -WhatIf

        Shows what would happen without actually removing the URL.
    .EXAMPLE
        Remove-ConfluenceBaseURL -Confirm:$false

        Removes the URL without confirmation prompt.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param()

    Write-Verbose "Removing stored Confluence base URL"

    if ($PSCmdlet.ShouldProcess("Confluence Base URL", "Remove configuration")) {
        $script:ConfluenceBaseURL = $null
        Write-Output "Confluence base URL has been removed."
    }
}
```

### Testing Pattern (Pester 3.4.0+ Compatible)

```powershell
#Requires -Modules Pester

# Note: Tests written for Pester 3.4.0+ compatibility (Windows PowerShell default)

Describe 'New-ConfluenceBaseURL' {
    BeforeAll {
        # Import module once before all tests
        $ModulePath = (Get-Item "$PSScriptRoot\..\..\ConfluenceAPI.psd1").FullName
        Import-Module $ModulePath -Force
    }

    BeforeEach {
        # Clean state before each test
        Remove-ConfluenceBaseURL -ErrorAction SilentlyContinue
    }

    AfterEach {
        # Clean up after each test
        Remove-ConfluenceBaseURL -ErrorAction SilentlyContinue
    }

    Context 'Standard URL Configuration' {
        It 'Stores standard Confluence URL successfully' {
            New-ConfluenceBaseURL -BaseURL 'https://mycompany.atlassian.net/wiki'
            $result = Get-ConfluenceBaseURL
            $result | Should Be 'https://mycompany.atlassian.net/wiki'
        }

        It 'Returns confirmation message' {
            $result = New-ConfluenceBaseURL -BaseURL 'https://test.atlassian.net/wiki'
            $result | Should Be 'Confluence base URL has been stored successfully.'
        }
    }

    Context 'Service Account URL Configuration' {
        It 'Stores service account URL with cloud ID' {
            New-ConfluenceBaseURL -BaseURL 'https://api.atlassian.com/ex/confluence/abc123-def456'
            $result = Get-ConfluenceBaseURL
            $result | Should Be 'https://api.atlassian.com/ex/confluence/abc123-def456'
        }
    }

    Context 'Trailing Slash Normalization' {
        It 'Removes trailing slash from URL' {
            New-ConfluenceBaseURL -BaseURL 'https://mycompany.atlassian.net/wiki/'
            $result = Get-ConfluenceBaseURL
            $result | Should Be 'https://mycompany.atlassian.net/wiki'
        }

        It 'Removes multiple trailing slashes' {
            New-ConfluenceBaseURL -BaseURL 'https://mycompany.atlassian.net/wiki///'
            $result = Get-ConfluenceBaseURL
            $result | Should Be 'https://mycompany.atlassian.net/wiki'
        }
    }

    Context 'URL Validation' {
        It 'Rejects non-HTTPS URLs' {
            { New-ConfluenceBaseURL -BaseURL 'http://mycompany.atlassian.net/wiki' } | Should Throw
        }

        It 'Rejects invalid URL format' {
            { New-ConfluenceBaseURL -BaseURL 'not-a-valid-url' } | Should Throw
        }

        It 'Rejects empty string' {
            { New-ConfluenceBaseURL -BaseURL '' } | Should Throw
        }
    }

    Context 'WhatIf Support' {
        It 'Does not store URL when WhatIf is used' {
            New-ConfluenceBaseURL -BaseURL 'https://test.atlassian.net/wiki' -WhatIf
            $result = Get-ConfluenceBaseURL
            $result | Should BeNullOrEmpty
        }

        It 'Supports ShouldProcess parameters' {
            $cmd = Get-Command New-ConfluenceBaseURL
            $cmd.Parameters.ContainsKey('WhatIf') | Should Be $true
            $cmd.Parameters.ContainsKey('Confirm') | Should Be $true
        }
    }

    Context 'Verbose Logging' {
        It 'Outputs verbose message when -Verbose is used' {
            $verboseMessages = New-ConfluenceBaseURL -BaseURL 'https://test.atlassian.net/wiki' -Verbose 4>&1
            $verboseMessages | Should Not BeNullOrEmpty
        }
    }
}
```

**Get-ConfluenceBaseURL.Tests.ps1 Template:**
```powershell
#Requires -Modules Pester

# Note: Tests written for Pester 3.4.0+ compatibility (Windows PowerShell default)

Describe 'Get-ConfluenceBaseURL' {
    BeforeAll {
        $ModulePath = (Get-Item "$PSScriptRoot\..\..\ConfluenceAPI.psd1").FullName
        Import-Module $ModulePath -Force
    }

    BeforeEach {
        Remove-ConfluenceBaseURL -ErrorAction SilentlyContinue
    }

    AfterEach {
        Remove-ConfluenceBaseURL -ErrorAction SilentlyContinue
    }

    Context 'Retrieving Stored URL' {
        It 'Returns stored URL as string' {
            New-ConfluenceBaseURL -BaseURL 'https://mycompany.atlassian.net/wiki'
            $result = Get-ConfluenceBaseURL
            $result | Should Be 'https://mycompany.atlassian.net/wiki'
        }

        It 'Returns service account URL correctly' {
            New-ConfluenceBaseURL -BaseURL 'https://api.atlassian.com/ex/confluence/abc123'
            $result = Get-ConfluenceBaseURL
            $result | Should Be 'https://api.atlassian.com/ex/confluence/abc123'
        }
    }

    Context 'No URL Stored' {
        It 'Returns null when no URL is stored' {
            $result = Get-ConfluenceBaseURL
            $result | Should BeNullOrEmpty
        }

        It 'Does not throw error when no URL exists' {
            { Get-ConfluenceBaseURL } | Should Not Throw
        }
    }

    Context 'Verbose Logging' {
        It 'Outputs verbose message when -Verbose is used' {
            New-ConfluenceBaseURL -BaseURL 'https://test.atlassian.net/wiki'
            $verboseMessages = Get-ConfluenceBaseURL -Verbose 4>&1
            $verboseMessages | Should Not BeNullOrEmpty
        }
    }
}
```

**Remove-ConfluenceBaseURL.Tests.ps1 Template:**
```powershell
#Requires -Modules Pester

# Note: Tests written for Pester 3.4.0+ compatibility (Windows PowerShell default)

Describe 'Remove-ConfluenceBaseURL' {
    BeforeAll {
        $ModulePath = (Get-Item "$PSScriptRoot\..\..\ConfluenceAPI.psd1").FullName
        Import-Module $ModulePath -Force
    }

    BeforeEach {
        Remove-ConfluenceBaseURL -ErrorAction SilentlyContinue
    }

    AfterEach {
        Remove-ConfluenceBaseURL -ErrorAction SilentlyContinue
    }

    Context 'Removing Stored URL' {
        It 'Removes stored URL successfully' {
            New-ConfluenceBaseURL -BaseURL 'https://test.atlassian.net/wiki'
            Remove-ConfluenceBaseURL
            $result = Get-ConfluenceBaseURL
            $result | Should BeNullOrEmpty
        }

        It 'Returns confirmation message when URL is removed' {
            New-ConfluenceBaseURL -BaseURL 'https://test.atlassian.net/wiki'
            $result = Remove-ConfluenceBaseURL
            $result | Should Be 'Confluence base URL has been removed.'
        }
    }

    Context 'Idempotent Behavior' {
        It 'Does not error when called with no URL stored' {
            { Remove-ConfluenceBaseURL } | Should Not Throw
        }

        It 'Can be called multiple times without error' {
            New-ConfluenceBaseURL -BaseURL 'https://test.atlassian.net/wiki'
            Remove-ConfluenceBaseURL
            { Remove-ConfluenceBaseURL } | Should Not Throw
        }
    }

    Context 'WhatIf Support' {
        It 'Does not remove URL when WhatIf is used' {
            New-ConfluenceBaseURL -BaseURL 'https://test.atlassian.net/wiki'
            Remove-ConfluenceBaseURL -WhatIf
            $result = Get-ConfluenceBaseURL
            $result | Should Be 'https://test.atlassian.net/wiki'
        }

        It 'Supports ShouldProcess parameters' {
            $cmd = Get-Command Remove-ConfluenceBaseURL
            $cmd.Parameters.ContainsKey('WhatIf') | Should Be $true
            $cmd.Parameters.ContainsKey('Confirm') | Should Be $true
        }
    }

    Context 'Verbose Logging' {
        It 'Outputs verbose message when -Verbose is used' {
            New-ConfluenceBaseURL -BaseURL 'https://test.atlassian.net/wiki'
            $verboseMessages = Remove-ConfluenceBaseURL -Verbose 4>&1
            $verboseMessages | Should Not BeNullOrEmpty
        }
    }
}
```

### Common Mistakes to Avoid

1. **DO NOT** accept HTTP URLs - enforce HTTPS only for security
2. **DO NOT** use `throw` directly - use `$PSCmdlet.ThrowTerminatingError()`
3. **DO NOT** forget `-WhatIf` support on write operations
4. **DO NOT** use PS 7+ only syntax (ternary, null coalescing)
5. **DO NOT** forget to update FunctionsToExport in the manifest
6. **DO NOT** create functions in Private/ - these are user-facing
7. **DO NOT** forget trailing slash normalization
8. **DO NOT** validate URL too strictly - allow both formats

### Validation Checklist

After implementation, verify:
```powershell
# 1. Module loads with new functions
Import-Module ./Modules/ConfluenceAPI/ConfluenceAPI.psd1 -Force
Get-Command -Module ConfluenceAPI | Select-Object Name
# Should show all 6 functions: *-ConfluenceAPIKey, *-ConfluenceBaseURL

# 2. Store and verify standard URL
New-ConfluenceBaseURL -BaseURL 'https://test.atlassian.net/wiki'
Get-ConfluenceBaseURL  # Should return: https://test.atlassian.net/wiki

# 3. Trailing slash normalized
New-ConfluenceBaseURL -BaseURL 'https://test.atlassian.net/wiki/'
Get-ConfluenceBaseURL  # Should return: https://test.atlassian.net/wiki (no slash)

# 4. Service account URL works
New-ConfluenceBaseURL -BaseURL 'https://api.atlassian.com/ex/confluence/abc123'
Get-ConfluenceBaseURL  # Should return full URL

# 5. Invalid URL rejected
New-ConfluenceBaseURL -BaseURL 'http://insecure.example.com'  # Should throw error

# 6. Remove and verify
Remove-ConfluenceBaseURL
Get-ConfluenceBaseURL  # Should be $null

# 7. WhatIf works
New-ConfluenceBaseURL -BaseURL 'https://test.atlassian.net/wiki' -WhatIf
Get-ConfluenceBaseURL  # Should still be $null

# 8. PSScriptAnalyzer passes
Invoke-ScriptAnalyzer -Path ./Modules/ConfluenceAPI/ -Recurse -Severity Warning

# 9. Pester tests pass
Invoke-Pester -Path ./Modules/ConfluenceAPI/Tests/
```

## Dev Agent Record

### Context Reference

<!-- Story context analysis completed by create-story workflow -->

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

- PSScriptAnalyzer: No warnings (all rules passed)
- Pester Tests: 49 Passed, 0 Failed, 0 Skipped (3.61s runtime) - after code review fixes
- Test-ModuleManifest: Validated successfully with 6 exported functions

### Completion Notes List

- Implemented all 3 Base URL configuration functions following the exact templates from Dev Notes
- Used `[System.Uri]::TryCreate()` for URL validation (PS 5.1 + PS 7 compatible)
- Enforced HTTPS-only URLs via scheme check against `$uri.Scheme -ne 'https'`
- Trailing slash normalization via `.TrimEnd('/')` removes single and multiple trailing slashes
- All functions include `[OutputType([string])]` per code review feedback from Story 1.2
- Get-ConfluenceBaseURL returns raw string (not PSCustomObject) since URLs are not secrets
- All tests use Pester 3.4.0 syntax (unhyphenated `Should Be`) for Windows PS compatibility
- WhatIf/ShouldProcess fully implemented and tested on New and Remove functions
- Idempotent behavior verified: Remove doesn't error when no URL stored, Get returns null gracefully

### File List

**Created:**
- Modules/ConfluenceAPI/Public/New-ConfluenceBaseURL.ps1
- Modules/ConfluenceAPI/Public/Get-ConfluenceBaseURL.ps1
- Modules/ConfluenceAPI/Public/Remove-ConfluenceBaseURL.ps1
- Modules/ConfluenceAPI/Tests/Public/New-ConfluenceBaseURL.Tests.ps1
- Modules/ConfluenceAPI/Tests/Public/Get-ConfluenceBaseURL.Tests.ps1
- Modules/ConfluenceAPI/Tests/Public/Remove-ConfluenceBaseURL.Tests.ps1

**Modified:**

- Modules/ConfluenceAPI/ConfluenceAPI.psd1 (added 3 functions to FunctionsToExport)

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2025-12-10 | Story created via create-story workflow | Claude Opus 4.5 |
| 2025-12-10 | Story implemented: 3 functions, 3 test files, manifest updated, all 45 tests pass | Claude Opus 4.5 |
| 2025-12-10 | Code review: Fixed M1 (misleading Remove message), M2 (error message validation), M3 (verbose tests). 49 tests pass | Claude Opus 4.5 |
