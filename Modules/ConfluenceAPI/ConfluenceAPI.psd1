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
        'New-ConfluenceAPIKey',
        'Get-ConfluenceAPIKey',
        'Remove-ConfluenceAPIKey',
        'New-ConfluenceBaseURL',
        'Get-ConfluenceBaseURL',
        'Remove-ConfluenceBaseURL',
        'Test-ConfluenceConnection',
        'Invoke-ConfluenceRequest',
        'Get-ConfluenceSpace',
        'New-ConfluenceSpace',
        'Set-ConfluenceSpace',
        'Remove-ConfluenceSpace',
        'Get-ConfluencePage',
        'New-ConfluencePage',
        'Set-ConfluencePage',
        'Remove-ConfluencePage',
        'Move-ConfluencePage',
        'Get-ConfluenceLabel',
        'Add-ConfluenceLabel',
        'Remove-ConfluenceLabel',
        'Search-Confluence',
        'Sync-ConfluenceUserInventory'
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
