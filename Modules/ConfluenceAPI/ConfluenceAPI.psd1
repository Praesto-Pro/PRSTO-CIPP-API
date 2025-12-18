@{
    RootModule = 'ConfluenceAPI.psm1'
    ModuleVersion = '0.1.0'
    GUID = '47d0aa49-0c22-45bb-ac9a-32124e04debe'
    Author = 'Matthias Kittok'
    CompanyName = 'Unknown'
    Copyright = '(c) 2025 Matthias Kittok. All rights reserved.'
    Description = 'PowerShell module for Atlassian Confluence Cloud REST API v2 integration with CIPP'
    PowerShellVersion = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    RequiredModules = @()  # Zero external dependencies by design (NFR)
    FunctionsToExport = @(
        # API Key Management (Epic 1)
        'New-ConfluenceAPIKey',
        'Get-ConfluenceAPIKey',
        'Remove-ConfluenceAPIKey',
        # Base URL Management (Epic 1)
        'New-ConfluenceBaseURL',
        'Get-ConfluenceBaseURL',
        'Remove-ConfluenceBaseURL',
        # Connection (Epic 1)
        'Test-ConfluenceConnection',
        'Invoke-ConfluenceRequest',
        # Space Operations (Epic 2)
        'Get-ConfluenceSpace',
        'New-ConfluenceSpace',
        'Set-ConfluenceSpace',
        'Remove-ConfluenceSpace',
        # Page Operations (Epic 2)
        'Get-ConfluencePage',
        'New-ConfluencePage',
        'Set-ConfluencePage',
        'Remove-ConfluencePage',
        'Move-ConfluencePage',
        # Label Operations (Epic 2)
        'Get-ConfluenceLabel',
        'Add-ConfluenceLabel',
        'Remove-ConfluenceLabel',
        # Search (Epic 2)
        'Search-Confluence',
        # Data Sync Functions (Epic 4-6)
        'Sync-ConfluenceUserInventory',
        'Sync-ConfluenceEndpointInventory',
        'Sync-ConfluenceLicenseReport',
        'Sync-ConfluenceMFAReport',
        'Sync-ConfluenceTeamsInventory',
        'Sync-ConfluenceSharePointInventory',
        # Client Space Management (Epic 7)
        'New-ConfluenceClientSpace',
        'Get-ConfluenceTenantMapping',
        'Set-ConfluenceTenantMapping',
        'Remove-ConfluenceTenantMapping',
        'Update-ConfluenceClientIndex',
        # Sync Orchestration (Epic 8)
        'Sync-CIPPTenantToConfluence',
        # Sync Configuration (Epic 8)
        'Set-ConfluenceSyncConfiguration',
        'Get-ConfluenceSyncConfiguration',
        'Remove-ConfluenceSyncConfiguration',
        # Incremental Sync State Management (Epic 8)
        'Get-ConfluenceSyncState',
        'Clear-ConfluenceSyncState',
        # Sync Logging (Epic 9)
        'Get-ConfluenceSyncLog',
        'Clear-ConfluenceSyncLog'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('Confluence', 'Atlassian', 'API', 'CIPP', 'MSP', 'Documentation')
            LicenseUri = 'https://github.com/PLACEHOLDER/ConfluenceAPI/blob/main/LICENSE'
            ProjectUri = 'https://github.com/PLACEHOLDER/ConfluenceAPI'
        }
    }
}
