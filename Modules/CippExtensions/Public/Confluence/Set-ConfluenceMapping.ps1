function Set-ConfluenceMapping {
    <#
    .SYNOPSIS
        Sets tenant-to-space mappings for Confluence in CippMapping table.
    .DESCRIPTION
        Writes or updates Confluence tenant mappings in the CippMapping Azure Table Storage.
        Each mapping associates a CIPP tenant with a Confluence space.

        Following the Hudu pattern, this function always clears all existing mappings
        before writing the new set. The frontend sends ALL current mappings - any mapping
        not included has been deleted by the user.

        Mappings are stored with:
        - PartitionKey: 'ConfluenceMapping'
        - RowKey: TenantId (tenant's defaultDomainName or customerId)
        - IntegrationId: Confluence space key
        - IntegrationName: Confluence space display name
    .PARAMETER CIPPMapping
        CippMapping table reference from Get-CIPPTable.
        If not provided, table is retrieved automatically.
    .PARAMETER APIName
        API name for logging purposes. Defaults to 'ConfluenceMapping'.
    .PARAMETER Request
        HTTP request object containing:
        - Headers: For logging context
        - Body: Array of mapping objects with TenantId, IntegrationId (SpaceKey), IntegrationName (SpaceName)
    .OUTPUTS
        [PSCustomObject] - Result object with Results property
    .EXAMPLE
        $mappings = @(
            @{ TenantId = 'contoso.onmicrosoft.com'; IntegrationId = 'CONTOSO'; IntegrationName = 'Contoso Corp' }
        )
        Set-ConfluenceMapping -Request @{ Body = $mappings; Headers = @{} }

        Replaces all existing mappings with the new tenant-to-space mappings.
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

    # Delete all existing mappings first (follows Hudu pattern exactly)
    # The frontend sends all current mappings - if one is missing, it's been deleted
    Get-CIPPAzDataTableEntity @CIPPMapping -Filter "PartitionKey eq 'ConfluenceMapping'" | ForEach-Object {
        Remove-AzDataTableEntity -Force @CIPPMapping -Entity $_
    }

    # Add all mappings from request body
    foreach ($Mapping in $Request.Body) {
        $AddObject = @{
            PartitionKey    = 'ConfluenceMapping'
            RowKey          = "$($Mapping.TenantId)"
            IntegrationId   = "$($Mapping.IntegrationId)"
            IntegrationName = "$($Mapping.IntegrationName)"
        }
        Add-CIPPAzDataTableEntity @CIPPMapping -Entity $AddObject -Force
        Write-LogMessage -API $APIName -headers $Request.Headers -message "Added mapping for $($Mapping.IntegrationName)." -Sev 'Info'
    }

    return [PSCustomObject]@{ Results = 'Successfully edited mapping table.' }
}
