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
    .PARAMETER ClearExisting
        When specified, clears all existing ConfluenceMapping entries before writing new ones.
        Default behavior is to upsert (update or insert).
    .OUTPUTS
        [PSCustomObject] - Result object with Results property
    .EXAMPLE
        $mappings = @(
            @{ TenantId = 'contoso.onmicrosoft.com'; IntegrationId = 'CONTOSO'; IntegrationName = 'Contoso Corp' }
        )
        Set-ConfluenceMapping -Request @{ Body = $mappings; Headers = @{} } -ClearExisting

        Clears existing mappings and sets new tenant-to-space mappings.
    .EXAMPLE
        Set-ConfluenceMapping -Request $Request -WhatIf

        Shows what mappings would be set without making changes.
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
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        $CIPPMapping,

        [Parameter()]
        [string]$APIName = 'ConfluenceMapping',

        [Parameter(Mandatory)]
        $Request,

        [Parameter()]
        [switch]$ClearExisting
    )

    Write-Verbose 'Setting Confluence tenant mappings'

    # Get table reference if not provided
    if (-not $CIPPMapping) {
        $CIPPMapping = Get-CIPPTable -TableName 'CippMapping'
    }

    try {
        # Optionally clear existing mappings (follows Hudu pattern)
        if ($ClearExisting) {
            if ($PSCmdlet.ShouldProcess('ConfluenceMapping entries', 'Clear existing')) {
                Write-Verbose 'Clearing existing Confluence mappings'
                $existingMappings = Get-CIPPAzDataTableEntity @CIPPMapping -Filter "PartitionKey eq 'ConfluenceMapping'"
                foreach ($existing in $existingMappings) {
                    Remove-AzDataTableEntity -Force @CIPPMapping -Entity $existing
                }
                Write-Verbose "Cleared $(@($existingMappings).Count) existing mapping(s)"
            }
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

            if ($PSCmdlet.ShouldProcess("$tenantId -> $spaceKey", 'Set mapping')) {
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
