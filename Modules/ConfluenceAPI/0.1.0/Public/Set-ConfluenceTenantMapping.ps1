function Set-ConfluenceTenantMapping {
    <#
    .SYNOPSIS
        Creates or updates a tenant-to-space mapping in Azure Table Storage.
    .DESCRIPTION
        Stores a mapping between a CIPP tenant and a Confluence space in the CippMapping
        Azure Table. If a mapping already exists for the TenantId, it will be overwritten.
    .PARAMETER TenantId
        The CIPP tenant ID to map.
    .PARAMETER SpaceKey
        The Confluence space key to map to. Must be uppercase letters and numbers only,
        starting with a letter (e.g., 'CONTOSO', 'CLIENT123').
    .PARAMETER SpaceName
        The display name of the space/client.
    .EXAMPLE
        Set-ConfluenceTenantMapping -TenantId 'abc-123' -SpaceKey 'CONTOSO' -SpaceName 'Contoso Corp'
        Creates or updates a mapping for tenant abc-123 to space CONTOSO.
    .EXAMPLE
        Set-ConfluenceTenantMapping -TenantId 'abc-123' -SpaceKey 'NEWSPACE' -SpaceName 'New Name' -WhatIf
        Shows what would be changed without actually changing.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$TenantId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$SpaceKey,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$SpaceName
    )

    Write-Verbose "Setting tenant mapping: '$TenantId' -> '$SpaceKey'"

    # Validate SpaceKey format (uppercase letters and numbers, starts with letter)
    # Use -cnotmatch for case-sensitive matching
    if ($SpaceKey -cnotmatch '^[A-Z][A-Z0-9]*$') {
        $PSCmdlet.ThrowTerminatingError(
            [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new("SpaceKey '$SpaceKey' is invalid. SpaceKey must start with an uppercase letter and contain only uppercase letters and numbers (A-Z, 0-9)."),
                "InvalidSpaceKey",
                [System.Management.Automation.ErrorCategory]::InvalidArgument,
                $SpaceKey
            )
        )
    }

    if ($PSCmdlet.ShouldProcess($TenantId, "Create/Update Confluence tenant mapping to '$SpaceKey'")) {
        $CIPPMapping = Get-CIPPTable -TableName 'CippMapping'

        $AddObject = @{
            PartitionKey = 'ConfluenceMapping'
            RowKey       = "$TenantId"
            SpaceKey     = "$SpaceKey"
            SpaceName    = "$SpaceName"
        }

        Add-CIPPAzDataTableEntity @CIPPMapping -Entity $AddObject -Force
        Write-Verbose "Successfully stored mapping for tenant '$TenantId'"
    }
}
