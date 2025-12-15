function Get-ConfluenceTenantMapping {
    <#
    .SYNOPSIS
        Retrieves Confluence tenant-to-space mappings from Azure Table Storage.
    .DESCRIPTION
        Queries the CippMapping Azure Table for Confluence mappings. Can retrieve
        a specific mapping by TenantId or all Confluence mappings.
    .PARAMETER TenantId
        Optional. The specific tenant ID to look up. If not provided, returns all mappings.
    .OUTPUTS
        [PSCustomObject] Mapping object(s) with TenantId, SpaceKey, SpaceName properties.
    .EXAMPLE
        Get-ConfluenceTenantMapping
        Returns all Confluence tenant mappings.
    .EXAMPLE
        Get-ConfluenceTenantMapping -TenantId 'abc-123'
        Returns the mapping for the specified tenant, or $null if not found.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [string]$TenantId
    )

    Write-Verbose "Retrieving Confluence tenant mapping(s)"

    # Get the CIPPMapping table reference
    $CIPPMapping = Get-CIPPTable -TableName 'CippMapping'

    if ($TenantId) {
        # Get specific mapping by TenantId
        Write-Verbose "Looking up mapping for tenant '$TenantId'"
        $filter = "PartitionKey eq 'ConfluenceMapping' and RowKey eq '$TenantId'"
        $mapping = Get-CIPPAzDataTableEntity @CIPPMapping -Filter $filter

        if ($mapping) {
            return [PSCustomObject]@{
                TenantId  = $mapping.RowKey
                SpaceKey  = $mapping.SpaceKey
                SpaceName = $mapping.SpaceName
            }
        }
        return $null
    }
    else {
        # Get all mappings
        Write-Verbose "Retrieving all Confluence tenant mappings"
        $filter = "PartitionKey eq 'ConfluenceMapping'"
        $mappings = Get-CIPPAzDataTableEntity @CIPPMapping -Filter $filter

        foreach ($mapping in $mappings) {
            [PSCustomObject]@{
                TenantId  = $mapping.RowKey
                SpaceKey  = $mapping.SpaceKey
                SpaceName = $mapping.SpaceName
            }
        }
    }
}
