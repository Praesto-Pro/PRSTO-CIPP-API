function Set-ConfluenceExtensionConfig {
    <#
    .SYNOPSIS
        Updates Confluence extension configuration in Extensionsconfig table.
    .DESCRIPTION
        Merges provided settings into the Extensionsconfig table,
        preserving other extension configurations (Hudu, NinjaOne, etc.).

        Validates BaseURL format when enabling the extension.
    .PARAMETER Enabled
        Whether the Confluence extension is active. Defaults to $false.
    .PARAMETER BaseURL
        Confluence Cloud base URL. Required when Enabled is $true.
        Must match pattern 'https://*.atlassian.net' or 'https://api.atlassian.com/*'.
    .PARAMETER CloudId
        Atlassian Cloud ID for scoped API access. Optional.
    .PARAMETER CreateMissingSpaces
        Auto-create spaces for unmapped tenants. Defaults to $false.
    .PARAMETER SyncUsers
        Sync user inventory pages. Defaults to $true.
    .PARAMETER SyncDevices
        Sync endpoint inventory pages. Defaults to $true.
    .PARAMETER SyncLicenses
        Sync license report pages. Defaults to $true.
    .PARAMETER SyncMFA
        Sync MFA status pages. Defaults to $true.
    .PARAMETER SyncTeams
        Sync Teams inventory pages. Defaults to $true.
    .PARAMETER SyncSharePoint
        Sync SharePoint inventory pages. Defaults to $true.
    .EXAMPLE
        Set-ConfluenceExtensionConfig -Enabled $true -BaseURL 'https://company.atlassian.net'

        Enables Confluence extension with the specified base URL.
    .EXAMPLE
        Set-ConfluenceExtensionConfig -Enabled $true -BaseURL 'https://company.atlassian.net' -SyncMFA $false

        Enables extension but disables MFA report syncing.
    .EXAMPLE
        Set-ConfluenceExtensionConfig -Enabled $true -BaseURL 'https://company.atlassian.net' -WhatIf

        Shows what would be changed without modifying the table.
    .NOTES
        Part of Story 10.3 - Configuration Management.

        Dependencies:
        - Get-CIPPTable (CIPP framework)
        - Get-CIPPAzDataTableEntity (CIPP framework)
        - Add-CIPPAzDataTableEntity (CIPP framework)
    .LINK
        Get-ConfluenceExtensionConfig
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [bool]$Enabled = $false,

        [Parameter()]
        [string]$BaseURL,

        [Parameter()]
        [string]$CloudId,

        [Parameter()]
        [bool]$CreateMissingSpaces = $false,

        [Parameter()]
        [bool]$SyncUsers = $true,

        [Parameter()]
        [bool]$SyncDevices = $true,

        [Parameter()]
        [bool]$SyncLicenses = $true,

        [Parameter()]
        [bool]$SyncMFA = $true,

        [Parameter()]
        [bool]$SyncTeams = $true,

        [Parameter()]
        [bool]$SyncSharePoint = $true
    )

    # Validate BaseURL if enabling
    if ($Enabled -and [string]::IsNullOrEmpty($BaseURL)) {
        throw 'BaseURL is required when enabling Confluence extension'
    }

    if ($Enabled -and $BaseURL -notmatch '^https://[\w-]+\.atlassian\.net/?$|^https://api\.atlassian\.com/.+$') {
        throw "BaseURL must match pattern 'https://*.atlassian.net' or 'https://api.atlassian.com/*'"
    }

    Write-Verbose 'Reading existing Extensionsconfig'
    $Table = Get-CIPPTable -TableName 'Extensionsconfig'
    $Entity = Get-CIPPAzDataTableEntity @Table

    # Initialize or parse existing config
    if ($Entity -and $Entity.config) {
        # Parse JSON and convert to hashtable for modifiable structure (PS 5.1 compatible)
        $ParsedConfig = $Entity.config | ConvertFrom-Json -ErrorAction Stop
        $Config = @{}
        # Copy all existing extension sections to hashtable
        foreach ($Property in $ParsedConfig.PSObject.Properties) {
            $Config[$Property.Name] = $Property.Value
        }
    }
    else {
        $Config = @{}
    }

    # Build Confluence section
    $Config['Confluence'] = @{
        Enabled             = $Enabled
        BaseURL             = $BaseURL
        CloudId             = $CloudId
        CreateMissingSpaces = $CreateMissingSpaces
        SyncUsers           = $SyncUsers
        SyncDevices         = $SyncDevices
        SyncLicenses        = $SyncLicenses
        SyncMFA             = $SyncMFA
        SyncTeams           = $SyncTeams
        SyncSharePoint      = $SyncSharePoint
    }

    if ($PSCmdlet.ShouldProcess('Extensionsconfig', 'Update Confluence configuration')) {
        Write-Verbose 'Saving updated configuration to Extensionsconfig table'

        # Preserve existing PartitionKey/RowKey or use defaults
        $UpdatedEntity = @{
            PartitionKey = if ($Entity.PartitionKey) { $Entity.PartitionKey } else { 'CippExtensions' }
            RowKey       = if ($Entity.RowKey) { $Entity.RowKey } else { 'Config' }
            config       = $Config | ConvertTo-Json -Depth 10 -Compress
        }

        Add-CIPPAzDataTableEntity @Table -Entity $UpdatedEntity -Force
        Write-Verbose 'Configuration saved successfully'
    }
}
