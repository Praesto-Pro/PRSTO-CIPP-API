# ConfluenceAPI Module

PowerShell module for integrating CIPP with Atlassian Confluence Cloud.

## Prerequisites

- PowerShell 5.1+ (Windows) or PowerShell 7+ (Cross-platform)
- Pester 3.4.0+ for running tests

## Running Tests

### Full Test Suite

Run all 1,139 tests from the repository root:

```powershell
Invoke-Pester -Path ".\Modules\ConfluenceAPI\Tests\" -Output Detailed
```

Or from the module directory:

```powershell
cd Modules\ConfluenceAPI
Invoke-Pester -Path ".\Tests\" -Output Detailed
```

### Run Specific Test File

```powershell
Invoke-Pester -Path ".\Modules\ConfluenceAPI\Tests\Public\Get-ConfluenceSpace.Tests.ps1" -Output Detailed
```

### Run Tests for a Specific Function

```powershell
# Public function tests
Invoke-Pester -Path ".\Modules\ConfluenceAPI\Tests\Public\New-ConfluenceClientSpace.Tests.ps1"

# Private function tests
Invoke-Pester -Path ".\Modules\ConfluenceAPI\Tests\Private\ConvertTo-ConfluenceUserPage.Tests.ps1"
```

### Run Tests by Context Name

Filter tests to run only specific contexts:

```powershell
Invoke-Pester -Path ".\Modules\ConfluenceAPI\Tests\" -TestName "*Error Handling*"
```

### Quick Pass/Fail Check

```powershell
Invoke-Pester -Path ".\Modules\ConfluenceAPI\Tests\" -PassThru | Select-Object TotalCount, PassedCount, FailedCount
```

### Integration Tests (Requires Credentials)

Integration tests require live Confluence API credentials:

```powershell
# Set up credentials first
New-ConfluenceAPIKey -APIKey "your-api-key"
New-ConfluenceBaseURL -BaseURL "https://your-domain.atlassian.net"

# Run integration tests
Invoke-Pester -Path ".\Modules\ConfluenceAPI\Tests\Integration\" -Output Detailed
```

## PSScriptAnalyzer

Run linting before commits:

```powershell
Invoke-ScriptAnalyzer -Path ".\Modules\ConfluenceAPI\" -Recurse -Severity Warning
```

## Module Structure

```
Modules/ConfluenceAPI/
├── Public/           # Exported user-facing functions
├── Private/          # Internal helper functions (not exported)
├── Tests/
│   ├── Public/       # Tests for public functions
│   ├── Private/      # Tests for private functions
│   └── Integration/  # Tests requiring live API
├── ConfluenceAPI.psd1  # Module manifest
└── ConfluenceAPI.psm1  # Module loader
```

## Test File Structure

Each test file uses this pattern:

```powershell
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleRoot = Split-Path -Parent (Split-Path -Parent $here)
$publicDir = Join-Path $moduleRoot 'Public'
$privateDir = Join-Path $moduleRoot 'Private'

Describe 'FunctionName' {
    BeforeAll {
        # Dot-source dependencies
        . "$privateDir\HelperFunction.ps1"
        # Dot-source function under test
        . "$publicDir\FunctionName.ps1"
    }

    Context 'Scenario' {
        BeforeEach {
            Mock DependentFunction { return $mockData }
        }

        It 'Does expected behavior' {
            $result = FunctionName -Param 'value'
            $result | Should Be 'expected'  # Pester 3.4 syntax
        }
    }
}
```

## Troubleshooting

### "Should Be" vs "Should -Be"

This module uses **Pester 3.4 syntax** for Windows PowerShell 5.1 compatibility:

```powershell
# CORRECT (Pester 3.4)
$result | Should Be 'expected'
$result | Should BeNullOrEmpty
$result | Should Not Throw

# WRONG (Pester 5.x)
$result | Should -Be 'expected'
```

### Mock Not Being Called

Ensure mocks are defined in `BeforeEach` within the same `Context`:

```powershell
Context 'Test scenario' {
    BeforeEach {
        Mock Invoke-ConfluenceRequest { return @{ id = '123' } }
    }

    It 'Calls the API' {
        Get-ConfluenceSpace -SpaceKey 'TEST'
        Assert-MockCalled Invoke-ConfluenceRequest -Times 1 -Scope It
    }
}
```

### Test File Not Finding Functions

Test files dot-source functions directly. Verify paths:

```powershell
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleRoot = Split-Path -Parent (Split-Path -Parent $here)
# $moduleRoot should resolve to Modules/ConfluenceAPI/
```

### Running from Wrong Directory

Always run from repository root or module root:

```powershell
# From repo root
Invoke-Pester -Path ".\Modules\ConfluenceAPI\Tests\"

# OR from module directory
cd Modules\ConfluenceAPI
Invoke-Pester -Path ".\Tests\"
```

## Function Categories

### Credential Management
- `New-ConfluenceAPIKey`, `Get-ConfluenceAPIKey`, `Remove-ConfluenceAPIKey`
- `New-ConfluenceBaseURL`, `Get-ConfluenceBaseURL`, `Remove-ConfluenceBaseURL`
- `Test-ConfluenceConnection`

### Space Operations
- `New-ConfluenceSpace`, `Get-ConfluenceSpace`, `Set-ConfluenceSpace`, `Remove-ConfluenceSpace`

### Page Operations
- `New-ConfluencePage`, `Get-ConfluencePage`, `Set-ConfluencePage`, `Remove-ConfluencePage`
- `Move-ConfluencePage`

### Label Operations
- `Add-ConfluenceLabel`, `Get-ConfluenceLabel`, `Remove-ConfluenceLabel`

### Search
- `Search-Confluence` (CQL queries)

### Client Space Management
- `New-ConfluenceClientSpace`
- `Get-ConfluenceTenantMapping`, `Set-ConfluenceTenantMapping`, `Remove-ConfluenceTenantMapping`
- `Update-ConfluenceClientIndex`

### Data Sync Functions
- `Sync-ConfluenceUserInventory`
- `Sync-ConfluenceEndpointInventory`
- `Sync-ConfluenceLicenseReport`
- `Sync-ConfluenceMFAReport`
- `Sync-ConfluenceTeamsInventory`
- `Sync-ConfluenceSharePointInventory`
