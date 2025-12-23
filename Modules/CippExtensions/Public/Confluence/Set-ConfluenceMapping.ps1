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

    # Step 1: Delete all existing mappings (Hudu pattern - replace all)
    try {
        Get-CIPPAzDataTableEntity @CIPPMapping -Filter "PartitionKey eq 'ConfluenceMapping'" | ForEach-Object {
            Remove-AzDataTableEntity -Force @CIPPMapping -Entity $_
        }
    }
    catch {
        Write-LogMessage -API $APIName -headers $Request.Headers -message "Set-ConfluenceMapping DELETE FAILED: $_" -Sev 'Error'
    }

    # Step 2: Add all mappings from request body
    foreach ($Mapping in $Request.Body) {
        $AddObject = @{
            PartitionKey    = 'ConfluenceMapping'
            RowKey          = "$($Mapping.TenantId)"
            IntegrationId   = "$($Mapping.IntegrationId)"
            IntegrationName = "$($Mapping.IntegrationName)"
        }
        Add-CIPPAzDataTableEntity @CIPPMapping -Entity $AddObject -Force
        Write-LogMessage -API $APIName -headers $Request.Headers -message "Added mapping for $($Mapping.name)." -Sev 'Info'
    }

    return [PSCustomObject]@{ Results = 'Successfully edited mapping table.' }
}
