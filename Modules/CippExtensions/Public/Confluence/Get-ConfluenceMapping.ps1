function Get-ConfluenceMapping {
    <#
    .SYNOPSIS
        Retrieves tenant-to-space mappings for Confluence from CippMapping table.
    .DESCRIPTION
        Queries the CippMapping Azure Table Storage for Confluence mappings.
        Each mapping associates a CIPP tenant with a Confluence space.

        Mappings are stored with:
        - PartitionKey: 'ConfluenceMapping'
        - RowKey: TenantId (tenant's defaultDomainName or customerId)
        - SpaceKey: Confluence space key
        - SpaceName: Confluence space display name

        This function follows the Get-HuduMapping pattern from CippExtensions,
        simplified since Confluence uses space keys rather than company IDs.
    .OUTPUTS
        [PSCustomObject[]] - Array of mapping objects with TenantId, SpaceKey, SpaceName properties
    .EXAMPLE
        $mappings = Get-ConfluenceMapping
        $mappings | Where-Object { $_.RowKey -eq 'contoso.onmicrosoft.com' }

        Retrieves all Confluence mappings and filters to a specific tenant.
    .EXAMPLE
        Get-ConfluenceMapping | Format-Table TenantId, SpaceKey, SpaceName

        Lists all configured tenant-to-space mappings.
    .NOTES
        Part of Story 10.1 - Extension Sync Orchestrator.

        This function is located in CippExtensions because it reads from
        CIPP's CippMapping table using CIPP's Azure Table functions.

        Table Schema:
        - PartitionKey: 'ConfluenceMapping'
        - RowKey: Tenant identifier (defaultDomainName recommended)
        - SpaceKey: Confluence space key (e.g., 'CONTOSO')
        - SpaceName: Human-readable space name (e.g., 'Contoso Corp')

        Dependencies:
        - Get-ExtensionMapping (CIPP framework)
        - Get-CIPPTable (CIPP framework)
        - Get-CIPPAzDataTableEntity (CIPP framework)
    .LINK
        Set-ConfluenceMapping
    .LINK
        Get-ExtensionMapping
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param()

    Write-Verbose 'Retrieving Confluence tenant mappings from CippMapping table'

    try {
        # Use the standard extension mapping pattern
        $mappings = Get-ExtensionMapping -Extension 'Confluence'

        if ($null -eq $mappings -or @($mappings).Count -eq 0) {
            Write-Verbose 'No Confluence mappings found in CippMapping table'
            return @()
        }

        # Transform to consistent output format
        $result = foreach ($mapping in $mappings) {
            [PSCustomObject]@{
                RowKey    = $mapping.RowKey
                TenantId  = $mapping.RowKey
                SpaceKey  = $mapping.IntegrationId
                SpaceName = $mapping.IntegrationName
            }
        }

        $resultArray = @($result)
        Write-Verbose "Found $($resultArray.Count) Confluence mapping(s)"
        return $resultArray
    }
    catch {
        Write-Verbose "Error retrieving Confluence mappings: $_"
        return @()
    }
}
