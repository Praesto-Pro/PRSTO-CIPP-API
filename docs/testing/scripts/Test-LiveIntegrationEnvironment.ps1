<#
.SYNOPSIS
    Validates that the live integration test environment is properly configured.

.DESCRIPTION
    This script validates all prerequisites for live integration testing:
    - CIPP framework functions accessible
    - Confluence API authentication successful
    - Azure Table Storage tables accessible
    - Test tenant data exists
    - Tenant mapping configured

    This script must pass 100% before executing live integration tests.

.PARAMETER TestTenantId
    The tenant ID to use for testing (must exist in CacheExtensionSync)

.PARAMETER TestSpaceKey
    The Confluence space key to use for testing (default: CIPPTESTSPACE)

.EXAMPLE
    .\Test-LiveIntegrationEnvironment.ps1 -TestTenantId 'contoso.onmicrosoft.com' -TestSpaceKey 'CIPPTESTSPACE'

.NOTES
    Story: 11.2 - Live Integration Testing
    Author: Matthias Kittok
    Date: 2025-12-21
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$|^[a-zA-Z0-9][a-zA-Z0-9.-]*\.[a-zA-Z]{2,}$', ErrorMessage = 'TestTenantId must be a valid GUID or domain name')]
    [string]$TestTenantId,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^[a-zA-Z0-9]+$', ErrorMessage = 'TestSpaceKey must contain only letters and numbers')]
    [string]$TestSpaceKey = 'CIPPTESTSPACE'
)

# Initialize validation results
$validationResults = [System.Collections.Generic.List[PSCustomObject]]::new()

function Add-ValidationResult {
    param(
        [string]$Component,
        [bool]$Passed,
        [string]$Message,
        [string]$Details = ''
    )

    $validationResults.Add([PSCustomObject]@{
            Component = $Component
            Passed    = $Passed
            Message   = $Message
            Details   = $Details
        })
}

Write-Host '========================================' -ForegroundColor Cyan
Write-Host 'Live Integration Test Environment Validation' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ''
Write-Host "Test Tenant ID: $TestTenantId" -ForegroundColor Yellow
Write-Host "Test Space Key: $TestSpaceKey" -ForegroundColor Yellow
Write-Host ''

# Validation 1: CIPP Framework Functions
Write-Host '[1/7] Validating CIPP Framework Functions...' -ForegroundColor Cyan

try {
    # Check Get-ExtensionAPIKey
    $null = Get-Command -Name 'Get-ExtensionAPIKey' -ErrorAction Stop
    Add-ValidationResult -Component 'CIPP Framework' -Passed $true -Message 'Get-ExtensionAPIKey available'
    Write-Host '  ✅ Get-ExtensionAPIKey available' -ForegroundColor Green
}
catch {
    Add-ValidationResult -Component 'CIPP Framework' -Passed $false -Message 'Get-ExtensionAPIKey NOT available' -Details $_.Exception.Message
    Write-Host '  ❌ Get-ExtensionAPIKey NOT available' -ForegroundColor Red
}

try {
    # Check Get-ExtensionCacheData
    $null = Get-Command -Name 'Get-ExtensionCacheData' -ErrorAction Stop
    Add-ValidationResult -Component 'CIPP Framework' -Passed $true -Message 'Get-ExtensionCacheData available'
    Write-Host '  ✅ Get-ExtensionCacheData available' -ForegroundColor Green
}
catch {
    Add-ValidationResult -Component 'CIPP Framework' -Passed $false -Message 'Get-ExtensionCacheData NOT available' -Details $_.Exception.Message
    Write-Host '  ❌ Get-ExtensionCacheData NOT available' -ForegroundColor Red
}

try {
    # Check Get-CIPPTable
    $null = Get-Command -Name 'Get-CIPPTable' -ErrorAction Stop
    Add-ValidationResult -Component 'CIPP Framework' -Passed $true -Message 'Get-CIPPTable available'
    Write-Host '  ✅ Get-CIPPTable available' -ForegroundColor Green
}
catch {
    Add-ValidationResult -Component 'CIPP Framework' -Passed $false -Message 'Get-CIPPTable NOT available' -Details $_.Exception.Message
    Write-Host '  ❌ Get-CIPPTable NOT available' -ForegroundColor Red
}

# Validation 2: Confluence API Authentication
Write-Host ''
Write-Host '[2/7] Validating Confluence API Authentication...' -ForegroundColor Cyan

try {
    # Get API key from framework
    $apiKey = Get-ExtensionAPIKey -Extension 'Confluence'

    if ($null -ne $apiKey -and $apiKey -ne '') {
        Add-ValidationResult -Component 'Confluence Auth' -Passed $true -Message 'Confluence API key retrieved successfully'
        Write-Host '  ✅ Confluence API key retrieved successfully' -ForegroundColor Green

        # Test authentication by attempting to get space
        try {
            Import-Module "$PSScriptRoot\..\..\..\Modules\ConfluenceAPI\ConfluenceAPI.psd1" -Force
            $space = Get-ConfluenceSpace -SpaceKey $TestSpaceKey -ErrorAction Stop

            if ($null -ne $space) {
                Add-ValidationResult -Component 'Confluence Auth' -Passed $true -Message "Successfully authenticated and accessed space '$TestSpaceKey'"
                Write-Host "  ✅ Successfully accessed space '$TestSpaceKey'" -ForegroundColor Green
            }
            else {
                Add-ValidationResult -Component 'Confluence Auth' -Passed $false -Message "Space '$TestSpaceKey' not found" -Details 'Create test space or update TestSpaceKey parameter'
                Write-Host "  ❌ Space '$TestSpaceKey' not found" -ForegroundColor Red
            }
        }
        catch {
            Add-ValidationResult -Component 'Confluence Auth' -Passed $false -Message 'Confluence API authentication failed' -Details $_.Exception.Message
            Write-Host '  ❌ Confluence API authentication failed' -ForegroundColor Red
        }
    }
    else {
        Add-ValidationResult -Component 'Confluence Auth' -Passed $false -Message 'Confluence API key is null or empty'
        Write-Host '  ❌ Confluence API key is null or empty' -ForegroundColor Red
    }
}
catch {
    Add-ValidationResult -Component 'Confluence Auth' -Passed $false -Message 'Failed to retrieve Confluence API key' -Details $_.Exception.Message
    Write-Host '  ❌ Failed to retrieve Confluence API key' -ForegroundColor Red
}

# Validation 3: Azure Table Storage - CacheExtensionSync
Write-Host ''
Write-Host '[3/7] Validating Azure Table Storage - CacheExtensionSync...' -ForegroundColor Cyan

try {
    $cacheTable = Get-CIPPTable -TableName 'CacheExtensionSync'

    if ($null -ne $cacheTable) {
        Add-ValidationResult -Component 'Azure Storage' -Passed $true -Message 'CacheExtensionSync table accessible'
        Write-Host '  ✅ CacheExtensionSync table accessible' -ForegroundColor Green

        # Check for test tenant data
        try {
            $filter = "PartitionKey eq '$TestTenantId'"
            $tenantData = Get-CIPPAzDataTableEntity -Filter $filter -Table $cacheTable -ErrorAction Stop

            if ($null -ne $tenantData -and $tenantData.Count -gt 0) {
                Add-ValidationResult -Component 'Azure Storage' -Passed $true -Message "Test tenant data found ($($tenantData.Count) records)"
                Write-Host "  ✅ Test tenant data found ($($tenantData.Count) records)" -ForegroundColor Green
            }
            else {
                Add-ValidationResult -Component 'Azure Storage' -Passed $false -Message "No data found for tenant '$TestTenantId'" -Details 'Seed test data before running live tests'
                Write-Host "  ❌ No data found for tenant '$TestTenantId'" -ForegroundColor Red
            }
        }
        catch {
            Add-ValidationResult -Component 'Azure Storage' -Passed $false -Message 'Failed to query CacheExtensionSync' -Details $_.Exception.Message
            Write-Host '  ❌ Failed to query CacheExtensionSync' -ForegroundColor Red
        }
    }
    else {
        Add-ValidationResult -Component 'Azure Storage' -Passed $false -Message 'CacheExtensionSync table NOT accessible'
        Write-Host '  ❌ CacheExtensionSync table NOT accessible' -ForegroundColor Red
    }
}
catch {
    Add-ValidationResult -Component 'Azure Storage' -Passed $false -Message 'Failed to access CacheExtensionSync table' -Details $_.Exception.Message
    Write-Host '  ❌ Failed to access CacheExtensionSync table' -ForegroundColor Red
}

# Validation 4: Azure Table Storage - CippMapping
Write-Host ''
Write-Host '[4/7] Validating Azure Table Storage - CippMapping...' -ForegroundColor Cyan

try {
    $mappingTable = Get-CIPPTable -TableName 'CippMapping'

    if ($null -ne $mappingTable) {
        Add-ValidationResult -Component 'Azure Storage' -Passed $true -Message 'CippMapping table accessible'
        Write-Host '  ✅ CippMapping table accessible' -ForegroundColor Green

        # Check for test tenant mapping
        try {
            # Escape single quotes in TenantId for OData filter
            $escapedTenantId = $TestTenantId -replace "'", "''"
            $filter = "PartitionKey eq 'ConfluenceMapping' and RowKey eq '$escapedTenantId'"
            $mapping = Get-CIPPAzDataTableEntity -Filter $filter -Table $mappingTable -ErrorAction Stop

            if ($null -ne $mapping) {
                $mappedSpaceKey = $mapping.SpaceKey
                if ($mappedSpaceKey -eq $TestSpaceKey) {
                    Add-ValidationResult -Component 'Azure Storage' -Passed $true -Message "Tenant mapping found: $TestTenantId → $mappedSpaceKey"
                    Write-Host "  ✅ Tenant mapping found: $TestTenantId → $mappedSpaceKey" -ForegroundColor Green
                }
                else {
                    Add-ValidationResult -Component 'Azure Storage' -Passed $false -Message "Tenant mapped to wrong space: $mappedSpaceKey (expected: $TestSpaceKey)" -Details 'Update mapping or change TestSpaceKey parameter'
                    Write-Host "  ❌ Tenant mapped to wrong space: $mappedSpaceKey (expected: $TestSpaceKey)" -ForegroundColor Red
                }
            }
            else {
                Add-ValidationResult -Component 'Azure Storage' -Passed $false -Message "No mapping found for tenant '$TestTenantId'" -Details 'Create tenant mapping before running live tests'
                Write-Host "  ❌ No mapping found for tenant '$TestTenantId'" -ForegroundColor Red
            }
        }
        catch {
            Add-ValidationResult -Component 'Azure Storage' -Passed $false -Message 'Failed to query CippMapping' -Details $_.Exception.Message
            Write-Host '  ❌ Failed to query CippMapping' -ForegroundColor Red
        }
    }
    else {
        Add-ValidationResult -Component 'Azure Storage' -Passed $false -Message 'CippMapping table NOT accessible'
        Write-Host '  ❌ CippMapping table NOT accessible' -ForegroundColor Red
    }
}
catch {
    Add-ValidationResult -Component 'Azure Storage' -Passed $false -Message 'Failed to access CippMapping table' -Details $_.Exception.Message
    Write-Host '  ❌ Failed to access CippMapping table' -ForegroundColor Red
}

# Validation 5: Azure Table Storage - Extensionsconfig
Write-Host ''
Write-Host '[5/7] Validating Azure Table Storage - Extensionsconfig...' -ForegroundColor Cyan

try {
    $configTable = Get-CIPPTable -TableName 'Extensionsconfig'

    if ($null -ne $configTable) {
        Add-ValidationResult -Component 'Azure Storage' -Passed $true -Message 'Extensionsconfig table accessible'
        Write-Host '  ✅ Extensionsconfig table accessible' -ForegroundColor Green

        # Check for Confluence extension config
        try {
            $filter = "PartitionKey eq 'Confluence'"
            $config = Get-CIPPAzDataTableEntity -Filter $filter -Table $configTable -ErrorAction Stop

            if ($null -ne $config) {
                $hasBaseURL = $null -ne $config.BaseURL -and $config.BaseURL -ne ''

                if ($hasBaseURL) {
                    Add-ValidationResult -Component 'Azure Storage' -Passed $true -Message "Confluence config found with BaseURL: $($config.BaseURL)"
                    Write-Host "  ✅ Confluence config found with BaseURL: $($config.BaseURL)" -ForegroundColor Green
                }
                else {
                    Add-ValidationResult -Component 'Azure Storage' -Passed $false -Message 'Confluence config missing BaseURL' -Details 'Configure BaseURL in Extensionsconfig'
                    Write-Host '  ❌ Confluence config missing BaseURL' -ForegroundColor Red
                }
            }
            else {
                Add-ValidationResult -Component 'Azure Storage' -Passed $false -Message 'No Confluence config found' -Details 'Create Confluence config before running live tests'
                Write-Host '  ❌ No Confluence config found' -ForegroundColor Red
            }
        }
        catch {
            Add-ValidationResult -Component 'Azure Storage' -Passed $false -Message 'Failed to query Extensionsconfig' -Details $_.Exception.Message
            Write-Host '  ❌ Failed to query Extensionsconfig' -ForegroundColor Red
        }
    }
    else {
        Add-ValidationResult -Component 'Azure Storage' -Passed $false -Message 'Extensionsconfig table NOT accessible'
        Write-Host '  ❌ Extensionsconfig table NOT accessible' -ForegroundColor Red
    }
}
catch {
    Add-ValidationResult -Component 'Azure Storage' -Passed $false -Message 'Failed to access Extensionsconfig table' -Details $_.Exception.Message
    Write-Host '  ❌ Failed to access Extensionsconfig table' -ForegroundColor Red
}

# Validation 6: Azure Table Storage - CacheConfluencePages
Write-Host ''
Write-Host '[6/7] Validating Azure Table Storage - CacheConfluencePages...' -ForegroundColor Cyan

try {
    $pageCacheTable = Get-CIPPTable -TableName 'CacheConfluencePages'

    if ($null -ne $pageCacheTable) {
        Add-ValidationResult -Component 'Azure Storage' -Passed $true -Message 'CacheConfluencePages table accessible'
        Write-Host '  ✅ CacheConfluencePages table accessible' -ForegroundColor Green
    }
    else {
        Add-ValidationResult -Component 'Azure Storage' -Passed $false -Message 'CacheConfluencePages table NOT accessible'
        Write-Host '  ❌ CacheConfluencePages table NOT accessible' -ForegroundColor Red
    }
}
catch {
    Add-ValidationResult -Component 'Azure Storage' -Passed $false -Message 'Failed to access CacheConfluencePages table' -Details $_.Exception.Message
    Write-Host '  ❌ Failed to access CacheConfluencePages table' -ForegroundColor Red
}

# Validation 7: Confluence Sync Modules
Write-Host ''
Write-Host '[7/7] Validating Confluence Sync Modules...' -ForegroundColor Cyan

$syncFunctions = @(
    'Sync-ConfluenceUserInventory',
    'Sync-ConfluenceEndpointInventory',
    'Sync-ConfluenceLicenseReport',
    'Sync-ConfluenceMFAStatus',
    'Sync-ConfluenceTeamsInventory',
    'Sync-ConfluenceSharePointInventory'
)

foreach ($function in $syncFunctions) {
    try {
        $null = Get-Command -Name $function -ErrorAction Stop
        Add-ValidationResult -Component 'Sync Modules' -Passed $true -Message "$function available"
        Write-Host "  ✅ $function available" -ForegroundColor Green
    }
    catch {
        Add-ValidationResult -Component 'Sync Modules' -Passed $false -Message "$function NOT available" -Details $_.Exception.Message
        Write-Host "  ❌ $function NOT available" -ForegroundColor Red
    }
}

# Summary
Write-Host ''
Write-Host '========================================' -ForegroundColor Cyan
Write-Host 'Validation Summary' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ''

$passedCount = ($validationResults | Where-Object { $_.Passed -eq $true }).Count
$failedCount = ($validationResults | Where-Object { $_.Passed -eq $false }).Count
$totalCount = $validationResults.Count

Write-Host "Total Checks: $totalCount" -ForegroundColor Cyan
Write-Host "Passed: $passedCount" -ForegroundColor Green
Write-Host "Failed: $failedCount" -ForegroundColor Red
Write-Host ''

if ($failedCount -gt 0) {
    Write-Host 'FAILED CHECKS:' -ForegroundColor Red
    Write-Host ''

    $validationResults | Where-Object { $_.Passed -eq $false } | ForEach-Object {
        Write-Host "  ❌ [$($_.Component)] $($_.Message)" -ForegroundColor Red
        if ($_.Details) {
            Write-Host "     Details: $($_.Details)" -ForegroundColor Yellow
        }
    }

    Write-Host ''
    Write-Host '⚠️  ENVIRONMENT NOT READY FOR LIVE TESTING' -ForegroundColor Red
    Write-Host 'Fix all failed checks before proceeding.' -ForegroundColor Yellow
    Write-Host ''

    return $validationResults
}
else {
    Write-Host '✅ ALL VALIDATION CHECKS PASSED' -ForegroundColor Green
    Write-Host 'Environment is ready for live integration testing.' -ForegroundColor Green
    Write-Host ''

    return $validationResults
}
