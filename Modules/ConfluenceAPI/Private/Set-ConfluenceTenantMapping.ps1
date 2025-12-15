function Set-ConfluenceTenantMapping {
    <#
    .SYNOPSIS
        Stores a tenant-to-space mapping in Azure Table Storage.
    .DESCRIPTION
        Creates or updates a mapping between a CIPP tenant and a Confluence space
        in the CippMapping Azure Table, using the 'ConfluenceMapping' partition key.
    .PARAMETER TenantId
        The CIPP tenant ID to map.
    .PARAMETER SpaceKey
        The Confluence space key to map to.
    .PARAMETER SpaceName
        The display name of the space/client.
    .EXAMPLE
        Set-ConfluenceTenantMapping -TenantId 'abc-123' -SpaceKey 'CONTOSO' -SpaceName 'Contoso Corp'
    #>
    [CmdletBinding(SupportsShouldProcess)]
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

    if ($PSCmdlet.ShouldProcess($TenantId, "Create Confluence tenant mapping")) {
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
