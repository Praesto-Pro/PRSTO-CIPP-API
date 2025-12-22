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
        - IntegrationId: Confluence space key
        - IntegrationName: Confluence space display name

        This function follows the Get-HuduMapping pattern from CippExtensions,
        joining mapping data with tenant information for display.
    .OUTPUTS
        [PSCustomObject[]] - Array of mapping objects matching Hudu pattern
    .EXAMPLE
        $mappings = Get-ConfluenceMapping
        $mappings | Where-Object { $_.TenantDomain -eq 'contoso.onmicrosoft.com' }

        Retrieves all Confluence mappings and filters to a specific tenant.
    .EXAMPLE
        Get-ConfluenceMapping | Format-Table Tenant, IntegrationName

        Lists all configured tenant-to-space mappings.
    .NOTES
        Part of Story 10.1 - Extension Sync Orchestrator.

        This function is located in CippExtensions because it reads from
        CIPP's CippMapping table using CIPP's Azure Table functions.

        Table Schema:
        - PartitionKey: 'ConfluenceMapping'
        - RowKey: Tenant identifier (defaultDomainName recommended)
        - IntegrationId: Confluence space key (e.g., 'CONTOSO')
        - IntegrationName: Human-readable space name (e.g., 'Contoso Corp')

        Dependencies:
        - Get-ExtensionMapping (CIPP framework)
        - Get-Tenants (CIPP framework)
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
        # Use the standard extension mapping pattern (follows Hudu)
        $ExtensionMappings = Get-ExtensionMapping -Extension 'Confluence'

        if ($null -eq $ExtensionMappings -or @($ExtensionMappings).Count -eq 0) {
            Write-Verbose 'No Confluence mappings found in CippMapping table'
            return @()
        }

        # Get tenants to join with mapping data (follows Hudu pattern)
        $Tenants = Get-Tenants -IncludeErrors

        # Transform to consistent output format matching Hudu
        $Mappings = foreach ($Mapping in $ExtensionMappings) {
            $Tenant = $Tenants | Where-Object { $_.RowKey -eq $Mapping.RowKey }
            if ($Tenant) {
                [PSCustomObject]@{
                    TenantId        = $Tenant.customerId
                    Tenant          = $Tenant.displayName
                    TenantDomain    = $Tenant.defaultDomainName
                    IntegrationId   = $Mapping.IntegrationId
                    IntegrationName = $Mapping.IntegrationName
                }
            }
        }

        $resultArray = @($Mappings)
        Write-Verbose "Found $($resultArray.Count) Confluence mapping(s)"
        return $resultArray
    }
    catch {
        Write-Verbose "Error retrieving Confluence mappings: $_"
        return @()
    }
}
