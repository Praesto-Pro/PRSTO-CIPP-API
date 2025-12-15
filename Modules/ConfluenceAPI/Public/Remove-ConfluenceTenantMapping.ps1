function Remove-ConfluenceTenantMapping {
    <#
    .SYNOPSIS
        Removes a tenant-to-space mapping from Azure Table Storage.
    .DESCRIPTION
        Deletes the mapping between a CIPP tenant and a Confluence space.
        Note: This only removes the mapping - it does NOT delete the Confluence space itself.
    .PARAMETER TenantId
        The CIPP tenant ID whose mapping should be removed.
    .EXAMPLE
        Remove-ConfluenceTenantMapping -TenantId 'abc-123'
        Removes the mapping for tenant abc-123.
    .EXAMPLE
        Remove-ConfluenceTenantMapping -TenantId 'abc-123' -WhatIf
        Shows what would be removed without actually removing.
    .EXAMPLE
        Remove-ConfluenceTenantMapping -TenantId 'abc-123' -Confirm:$false
        Removes the mapping without prompting for confirmation.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$TenantId
    )

    Write-Verbose "Removing tenant mapping for '$TenantId'"

    # Get the CIPPMapping table reference
    $CIPPMapping = Get-CIPPTable -TableName 'CippMapping'

    # Find the existing mapping
    Write-Verbose "Looking up existing mapping for tenant '$TenantId'"
    $filter = "PartitionKey eq 'ConfluenceMapping' and RowKey eq '$TenantId'"
    $entity = Get-CIPPAzDataTableEntity @CIPPMapping -Filter $filter

    if (-not $entity) {
        Write-Warning "No mapping found for tenant '$TenantId'. Nothing to remove."
        return
    }

    Write-Verbose "Found mapping: '$TenantId' -> '$($entity.SpaceKey)'"

    if ($PSCmdlet.ShouldProcess("Tenant '$TenantId' -> Space '$($entity.SpaceKey)'", "Remove Confluence tenant mapping")) {
        Remove-AzDataTableEntity -Force @CIPPMapping -Entity $entity
        Write-Verbose "Successfully removed mapping for tenant '$TenantId'"
    }
}
