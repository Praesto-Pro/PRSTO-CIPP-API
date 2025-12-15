function Get-ConfluenceTenantMapping {
    <#
    .SYNOPSIS
        Retrieves Confluence tenant-to-space mappings from Azure Table Storage.
    .DESCRIPTION
        Queries the CippMapping Azure Table for Confluence mappings. Can retrieve
        a specific mapping by TenantId, by SpaceKey, or all Confluence mappings.
    .PARAMETER TenantId
        Optional. The specific tenant ID to look up.
    .PARAMETER SpaceKey
        Optional. The specific space key to look up (reverse lookup).
    .OUTPUTS
        [PSCustomObject] Mapping object(s) with TenantId, SpaceKey, SpaceName properties.
    .EXAMPLE
        Get-ConfluenceTenantMapping
        Returns all Confluence tenant mappings.
    .EXAMPLE
        Get-ConfluenceTenantMapping -TenantId 'abc-123'
        Returns the mapping for the specified tenant, or $null if not found.
    .EXAMPLE
        Get-ConfluenceTenantMapping -SpaceKey 'CONTOSO'
        Returns the mapping for the specified space (reverse lookup).
    #>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(ParameterSetName = 'ByTenantId')]
        [string]$TenantId,

        [Parameter(ParameterSetName = 'BySpaceKey')]
        [string]$SpaceKey
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
    elseif ($SpaceKey) {
        # Get specific mapping by SpaceKey (reverse lookup)
        Write-Verbose "Looking up mapping for space '$SpaceKey'"
        $filter = "PartitionKey eq 'ConfluenceMapping' and SpaceKey eq '$SpaceKey'"
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
