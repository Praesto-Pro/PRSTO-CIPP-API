function Get-ConfluenceExtensionConfig {
    <#
    .SYNOPSIS
        Retrieves Confluence extension configuration from Extensionsconfig table.
    .DESCRIPTION
        Reads the Extensionsconfig table and extracts the Confluence section.
        Returns $null if Confluence is not configured.

        The Extensionsconfig table stores all extension settings in a single JSON blob.
        This function extracts just the Confluence portion.
    .OUTPUTS
        [PSCustomObject] - Confluence configuration with properties:
        - Enabled: [bool] Whether extension is active
        - BaseURL: [string] Confluence Cloud base URL
        - CloudId: [string] Atlassian Cloud ID (optional)
        - CreateMissingSpaces: [bool] Auto-create spaces for unmapped tenants
        - SyncUsers: [bool] Sync user inventory pages
        - SyncDevices: [bool] Sync endpoint inventory pages
        - SyncLicenses: [bool] Sync license report pages
        - SyncMFA: [bool] Sync MFA status pages
        - SyncTeams: [bool] Sync Teams inventory pages
        - SyncSharePoint: [bool] Sync SharePoint inventory pages

        Returns $null if Confluence section doesn't exist.
    .EXAMPLE
        $config = Get-ConfluenceExtensionConfig
        if ($config.Enabled) {
            # Proceed with sync operations
        }
    .NOTES
        Part of Story 10.3 - Configuration Management.

        Dependencies:
        - Get-CIPPTable (CIPP framework)
        - Get-CIPPAzDataTableEntity (CIPP framework)
    .LINK
        Set-ConfluenceExtensionConfig
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    Write-Verbose 'Reading Extensionsconfig table'
    $Table = Get-CIPPTable -TableName 'Extensionsconfig'
    $Entity = Get-CIPPAzDataTableEntity @Table

    if (-not $Entity -or -not $Entity.config) {
        Write-Verbose 'Extensionsconfig table is empty or has no config property'
        return $null
    }

    $Config = $Entity.config | ConvertFrom-Json -ErrorAction Stop

    if (-not $Config.Confluence) {
        Write-Verbose 'No Confluence section in Extensionsconfig'
        return $null
    }

    Write-Verbose 'Returning Confluence configuration'
    return [PSCustomObject]@{
        Enabled             = [bool]$Config.Confluence.Enabled
        BaseURL             = $Config.Confluence.BaseURL
        CloudId             = $Config.Confluence.CloudId
        CreateMissingSpaces = [bool]$Config.Confluence.CreateMissingSpaces
        SyncUsers           = if ($null -eq $Config.Confluence.SyncUsers) { $true } else { [bool]$Config.Confluence.SyncUsers }
        SyncDevices         = if ($null -eq $Config.Confluence.SyncDevices) { $true } else { [bool]$Config.Confluence.SyncDevices }
        SyncLicenses        = if ($null -eq $Config.Confluence.SyncLicenses) { $true } else { [bool]$Config.Confluence.SyncLicenses }
        SyncMFA             = if ($null -eq $Config.Confluence.SyncMFA) { $true } else { [bool]$Config.Confluence.SyncMFA }
        SyncTeams           = if ($null -eq $Config.Confluence.SyncTeams) { $true } else { [bool]$Config.Confluence.SyncTeams }
        SyncSharePoint      = if ($null -eq $Config.Confluence.SyncSharePoint) { $true } else { [bool]$Config.Confluence.SyncSharePoint }
    }
}
