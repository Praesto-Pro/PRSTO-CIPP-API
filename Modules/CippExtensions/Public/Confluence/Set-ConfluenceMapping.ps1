function Set-ConfluenceMapping {
    <#
    .SYNOPSIS
        Sets tenant-to-space mappings for Confluence in CippMapping table.
    .DESCRIPTION
        Writes or updates Confluence tenant mappings in the CippMapping Azure Table Storage.
        Each mapping associates a CIPP tenant with a Confluence space.

        This function:
        1. Optionally clears existing ConfluenceMapping entries
        2. Writes new mappings to the CippMapping table
        3. Logs each mapping operation
        4. Supports -WhatIf for safe preview

        Mappings are stored with:
        - PartitionKey: 'ConfluenceMapping'
        - RowKey: TenantId (tenant's defaultDomainName or customerId)
        - IntegrationId: Confluence space key
        - IntegrationName: Confluence space display name

        This function follows the Set-HuduMapping pattern from CippExtensions.
    .PARAMETER CIPPMapping
        CippMapping table reference from Get-CIPPTable.
        If not provided, table is retrieved automatically.
    .PARAMETER APIName
        API name for logging purposes. Defaults to 'ConfluenceMapping'.
    .PARAMETER Request
        HTTP request object containing:
        - Headers: For logging context
        - Body: Array of mapping objects with TenantId, IntegrationId (SpaceKey), IntegrationName (SpaceName)
    .NOTES
        Following the Hudu pattern, this function always clears all existing mappings
        before writing the new set. The frontend sends ALL current mappings - any mapping
        not included has been deleted by the user.
    .OUTPUTS
        [PSCustomObject] - Result object with Results property
    .EXAMPLE
        $mappings = @(
            @{ TenantId = 'contoso.onmicrosoft.com'; IntegrationId = 'CONTOSO'; IntegrationName = 'Contoso Corp' }
        )
        Set-ConfluenceMapping -Request @{ Body = $mappings; Headers = @{} }

        Replaces all existing mappings with the new tenant-to-space mappings.
    .NOTES
        Part of Story 10.1 - Extension Sync Orchestrator.

        This function is located in CippExtensions because it writes to
        CIPP's CippMapping table using CIPP's Azure Table functions.

        Dependencies:
        - Get-CIPPTable (CIPP framework)
        - Get-CIPPAzDataTableEntity (CIPP framework)
        - Add-CIPPAzDataTableEntity (CIPP framework)
        - Remove-AzDataTableEntity (CIPP framework)
        - Write-LogMessage (CIPP framework)
    .LINK
        Get-ConfluenceMapping
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        $CIPPMapping,

        [Parameter()]
        [string]$APIName = 'ConfluenceMapping',

        [Parameter(Mandatory)]
        $Request
    )

    Write-Verbose 'Setting Confluence tenant mappings'

    # Get table reference if not provided
    if (-not $CIPPMapping) {
        $CIPPMapping = Get-CIPPTable -TableName 'CippMapping'
    }

    try {
        # Log what we received for debugging
        $bodyCount = @($Request.Body).Count
        Write-LogMessage -API $APIName -headers $Request.Headers -message "Set-ConfluenceMapping called with $bodyCount mapping(s) in request body" -Sev 'Debug'

        # Delete all existing mappings first (follows Hudu pattern exactly)
        # The frontend sends all current mappings - if one is missing, it's been deleted
        $existingMappings = @(Get-CIPPAzDataTableEntity @CIPPMapping -Filter "PartitionKey eq 'ConfluenceMapping'")
        Write-LogMessage -API $APIName -headers $Request.Headers -message "Found $($existingMappings.Count) existing mapping(s) to delete" -Sev 'Debug'

        foreach ($existing in $existingMappings) {
            Remove-AzDataTableEntity -Force @CIPPMapping -Entity $existing
            Write-LogMessage -API $APIName -headers $Request.Headers -message "Deleted mapping for $($existing.RowKey)" -Sev 'Debug'
        }

        # Process each mapping in the request body
        $mappingCount = 0
        foreach ($Mapping in $Request.Body) {
            $tenantId = $Mapping.TenantId
            $spaceKey = $Mapping.IntegrationId
            $spaceName = $Mapping.IntegrationName

            if (-not $tenantId -or -not $spaceKey) {
                Write-Verbose "Skipping invalid mapping: TenantId='$tenantId', SpaceKey='$spaceKey'"
                continue
            }

            $AddObject = @{
                PartitionKey    = 'ConfluenceMapping'
                RowKey          = "$tenantId"
                IntegrationId   = "$spaceKey"
                IntegrationName = "$spaceName"
            }

            Add-CIPPAzDataTableEntity @CIPPMapping -Entity $AddObject -Force
            Write-LogMessage -API $APIName -headers $Request.Headers -message "Added Confluence mapping for $tenantId -> $spaceKey" -Sev 'Info'
            $mappingCount++
        }

        Write-Verbose "Set $mappingCount Confluence mapping(s)"

        return [PSCustomObject]@{
            Results = "Successfully edited Confluence mapping table. $mappingCount mapping(s) configured."
        }
    }
    catch {
        Write-Verbose "Error setting Confluence mappings: $_"
        return [PSCustomObject]@{
            Results = "Failed to set Confluence mappings: $_"
        }
    }
}
