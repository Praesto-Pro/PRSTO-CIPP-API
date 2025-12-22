---
project_name: 'CIPP-Confluence'
user_name: 'Matthias Kittok'
date: '2025-12-09'
sections_completed: ['technology_stack', 'language_rules', 'framework_rules', 'testing_rules', 'code_quality', 'workflow_rules', 'critical_rules']
status: 'complete'
rule_count: 47
optimized_for_llm: true
---

# Project Context for AI Agents

_This file contains critical rules and patterns that AI agents must follow when implementing code in this project. Focus on unobvious details that agents might otherwise miss._

---

## Technology Stack & Versions

| Technology | Version | Notes |
|------------|---------|-------|
| PowerShell | 5.1+ / 7+ | Must work on Windows PowerShell AND PowerShell Core |
| Confluence Cloud REST API | v2 | Cursor-based pagination, NOT v1 endpoints |
| Atlassian Document Format | v1 | JSON content format, NOT Storage Format (XHTML) |
| Pester | 3.4.0+ | Testing framework - use v3.4 syntax for PS 5.1 compatibility |
| PSScriptAnalyzer | Latest | Must pass all rules before commit |

**Runtime Constraints:**

- Zero external module dependencies
- Script-scoped credential storage only (`$script:ConfluenceAPIKey`)

## Language-Specific Rules (PowerShell)

### Function Structure

- **ALL functions** must use `[CmdletBinding()]` attribute
- **Write operations** must include `SupportsShouldProcess` and `ConfirmImpact`
- Parameters use `[Parameter()]` attribute with `Mandatory` where required

### Naming Conventions

| Element | Convention | Example |
|---------|------------|---------|
| Functions | `Verb-ConfluenceNoun` | `Get-ConfluenceSpace`, `New-ConfluencePage` |
| Parameters | PascalCase | `-SpaceKey`, `-PageTitle` |
| Local variables | camelCase | `$response`, `$pageContent` |
| Script variables | `$script:PascalCase` | `$script:ConfluenceAPIKey` |
| Files | Match function name | `Get-ConfluenceSpace.ps1` |

### Return Types

- **ALWAYS** return `[PSCustomObject]` - NEVER raw JSON strings
- Use explicit property mapping from API response
- Example:

  ```powershell
  [PSCustomObject]@{
      Id = $response.id
      Title = $response.title
      SpaceKey = $response.spaceKey
  }
  ```

### Error Handling

- Use `$PSCmdlet.ThrowTerminatingError()` with proper `ErrorRecord`
- Include error category (`ConnectionError`, `InvalidOperation`, etc.)
- Include target object for debugging
- NEVER use `throw` directly in advanced functions

### Verbose Logging

- ALL API operations must include `Write-Verbose` before the call
- Format: `Write-Verbose "Verb-ing noun '$Identifier' in context '$Context'"`

## Framework-Specific Rules (HuduAPI Pattern Parity)

### Module Structure

```text
Modules/ConfluenceAPI/
├── Public/     # Exported functions ONLY
├── Private/    # Internal helpers ONLY
├── Tests/      # Mirrors source structure
└── Docs/       # Help documentation
```

### Public vs Private Boundaries

- `Public/` - User-facing functions that get exported
- `Private/` - Internal helpers, NEVER export these
- `Invoke-ConfluenceRequest` is PUBLIC (matches HuduAPI's `Invoke-HuduRequest`)
- ADF builders (`ConvertTo-ADF`, `New-ADFTable`) are PRIVATE

### API Request Pattern

- ALL API calls go through `Invoke-ConfluenceRequest`
- Centralized rate limiting and retry logic
- Supports BOTH URL formats:
  - Standard: `https://{domain}.atlassian.net/wiki/api/v2/...`
  - Service Account: `https://api.atlassian.com/ex/confluence/{cloudId}/wiki/api/v2/...`

### Credential Pattern

- `New-ConfluenceAPIKey` stores token in `$script:ConfluenceAPIKey`
- `New-ConfluenceBaseURL` stores URL in `$script:ConfluenceBaseURL`
- Functions check for credentials and throw if not set
- NEVER log or output credential values

## Testing Rules (Pester 3.4.0+ Compatible)

### Test File Organization

- Tests mirror source structure: `Tests/Public/`, `Tests/Private/`
- Naming: `{FunctionName}.Tests.ps1`
- Integration tests in `Tests/Integration/`

### Pester Syntax (Windows PS 5.1 Compatible)

Tests use Pester 3.4.0+ syntax for Windows PowerShell 5.1 compatibility:

```powershell
Describe 'Get-ConfluenceSpace' {
    BeforeAll {
        # Module import once before all tests
        $ModulePath = (Get-Item "$PSScriptRoot\..\..\ConfluenceAPI.psd1").FullName
        Import-Module $ModulePath -Force
    }

    BeforeEach {
        # State cleanup before each test
    }

    It 'Returns space object with expected properties' {
        $result = Get-ConfluenceSpace -SpaceKey 'TEST'
        $result.SpaceKey | Should Be 'TEST'  # Pester 3.4 syntax (no hyphen)
    }
}
```

**Note:** Unhyphenated `Should Be` syntax is required for Windows PS 5.1 default Pester.

### Mock Patterns

- Mock `Invoke-ConfluenceRequest` for unit tests
- Use `Assert-MockCalled` for mock verification (Pester 3.4 compatible)
- Integration tests use real API (separate test credentials)

### WhatIf Testing

- ALL write functions must be testable with `-WhatIf`
- Verify no API calls made when `-WhatIf` is used

## Code Quality & Style Rules

### PSScriptAnalyzer

- Must pass ALL rules before commit
- Use approved PowerShell verbs only (`Get-Verb` to list)
- No aliases in scripts (use full cmdlet names)

### Code Organization

- One function per file
- File name matches function name exactly
- Maximum function length: keep functions focused and testable

### Documentation

- Comment-based help for ALL public functions:

  ```powershell
  <#
  .SYNOPSIS
      Brief description
  .DESCRIPTION
      Detailed description
  .PARAMETER SpaceKey
      The unique key of the Confluence space
  .EXAMPLE
      Get-ConfluenceSpace -SpaceKey 'PROJ'
  #>
  ```

- No inline comments unless explaining non-obvious logic
- README.md for module overview only

### Parameter Validation

- Use `[ValidateNotNullOrEmpty()]` for required strings
- Use `[ValidateRange()]` for numeric bounds
- Use `[ValidateSet()]` for known value lists

## Development Workflow Rules

### Git Workflow

- Feature branches from `main`
- Branch naming: `feature/descriptive-name` or `fix/issue-description`
- Squash merge to main

### Commit Messages

- Format: `type: brief description`
- Types: `feat`, `fix`, `docs`, `test`, `refactor`
- Example: `feat: add Get-ConfluenceSpace function`

### Pre-Commit Checklist

1. PSScriptAnalyzer passes with no errors
2. All Pester tests pass
3. New functions have comment-based help
4. Write operations support `-WhatIf`

### Module Development

- Test changes by importing module: `Import-Module ./ConfluenceAPI.psd1 -Force`
- Use `-Verbose` flag when testing API calls
- Never commit API tokens or credentials

## Critical Don't-Miss Rules

### API Gotchas

- **Confluence API v2 uses cursor pagination** - NOT offset/limit
  - Use `cursor` parameter from `_links.next`
  - Do NOT use `start` or `limit` from v1
- **ADF is JSON, NOT HTML** - Never use Storage Format (XHTML)
- **Rate limit 429** - Check `Retry-After` header first, then exponential backoff
- **CQL Injection Prevention** - Escape single quotes in user input for CQL queries:

  ```powershell
  # CORRECT: Double single quotes to escape
  $escapedTitle = $Title -replace "'", "''"
  $cql = "title = '$escapedTitle' and space = '$SpaceKey' and type = page"

  # WRONG: Unescaped user input allows injection
  $cql = "title = '$Title' and space = '$SpaceKey'"
  ```

- **OData Filter Security (Azure Table Storage)** - Escape single quotes in ALL user input for OData filter queries:

  ```powershell
  # CORRECT: Escape before filter construction
  $escapedTenantId = $TenantId -replace "'", "''"
  $filter = "PartitionKey eq 'ConfluenceMapping' and RowKey eq '$escapedTenantId'"

  # WRONG: Direct interpolation allows NoSQL injection
  $filter = "PartitionKey eq 'ConfluenceMapping' and RowKey eq '$TenantId'"

  # Attack Example:
  # Input: $TenantId = "abc' or PartitionKey eq 'ConfluenceMapping"
  # Result: Bypasses tenant isolation, returns ALL mappings
  ```

  **Defense in Depth:** Combine escaping with `[ValidatePattern()]` validation (MANDATORY for all OData parameters):

  ### OData Filter Security Checklist

  For **ANY** parameter used in OData filter construction:

  **1. Input Validation (Primary Defense)**

  - ✅ Add `[ValidatePattern()]` with strict regex matching expected format
  - ✅ Verify pattern against ACTUAL API specification (not assumptions)
  - ✅ Include ErrorMessage for better UX

  **Pattern Reference (API-verified):**

  ```powershell
  # Confluence Page ID - Numeric only (Cloud spec)
  [ValidatePattern('^[0-9]+$', ErrorMessage = 'PageId must be numeric (Confluence Cloud page IDs are numeric only)')]

  # Confluence Space Key - Letters and numbers only (no hyphens, underscores)
  [ValidatePattern('^[a-zA-Z0-9]+$', ErrorMessage = 'SpaceKey must contain only letters and numbers (no hyphens, underscores, or special characters per Confluence specification)')]

  # Azure AD Tenant ID - GUID or domain with TLD
  [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$|^[a-zA-Z0-9][a-zA-Z0-9.-]*\.[a-zA-Z]{2,}$', ErrorMessage = 'TenantId must be a valid GUID or domain name (e.g., contoso.onmicrosoft.com)')]
  ```

  **2. Escaping (Defense in Depth)**

  - ✅ ALWAYS escape before filter construction: `$escaped = $input -replace "'", "''"`
  - ✅ Use escaped variable in filter string
  - ✅ Required even with validation (defense if validation bypassed)

  **3. Code Review Checklist**

  - ✅ Validation pattern matches ACTUAL API spec (not assumptions)
  - ✅ Escaping occurs BEFORE filter construction
  - ✅ NO raw variables in filter strings
  - ✅ Test coverage includes validation rejection tests
  - ✅ Test coverage includes escaping unit tests (see `ODataEscaping.Tests.ps1`)

  **Affected Functions:** `Get-ConfluenceTenantMapping`, `Remove-ConfluenceTenantMapping`, `Get-ConfluencePageCache`, `Clear-ConfluencePageCache`

  **References:**
  - [Confluence Space Keys Spec](https://confluence.atlassian.com/display/DOC/Space+Keys)
  - [Confluence Cloud REST API](https://developer.atlassian.com/cloud/confluence/rest/v2/api-group-page/)
  - [Azure AD Tenant ID Spec](https://learn.microsoft.com/en-us/partner-center/account-settings/find-ids-and-domain-names)

### PowerShell Gotchas

- **PS 5.1 vs 7 differences:**
  - Use `Invoke-RestMethod` (works on both), NOT `Invoke-WebRequest` with JSON parsing
  - `$null -eq $var` (correct), NOT `$var -eq $null`
  - Arrays: `@()` for empty, NOT `$null`

### Security Rules

- NEVER log API tokens (even in `-Verbose` output)
- NEVER include tokens in error messages
- Credentials stored in `$script:` scope ONLY (not global)
- Clear credentials on module removal

### Common Mistakes to Avoid

- Using `throw` instead of `$PSCmdlet.ThrowTerminatingError()`
- Returning raw JSON instead of `[PSCustomObject]`
- Missing `-WhatIf` on write operations
- Using Pester 4 syntax (`Should Be` without hyphen)
- Putting helper functions in `Public/` instead of `Private/`
- Hardcoding URLs instead of using `$script:ConfluenceBaseURL`

---

## Usage Guidelines

**For AI Agents:**

- Read this file before implementing any code
- Follow ALL rules exactly as documented
- When in doubt, prefer the more restrictive option
- Update this file if new patterns emerge

**For Humans:**

- Keep this file lean and focused on agent needs
- Update when technology stack changes
- Review quarterly for outdated rules
- Remove rules that become obvious over time

---

Last Updated: 2025-12-21
