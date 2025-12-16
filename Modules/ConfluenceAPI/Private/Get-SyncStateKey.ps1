function Get-SyncStateKey {
    <#
    .SYNOPSIS
        Generates a unique key for sync state storage.
    .DESCRIPTION
        Creates a composite key from TenantId and DataType for use
        as a hashtable key in the sync state cache.
    .PARAMETER TenantId
        The tenant identifier.
    .PARAMETER DataType
        The data type (e.g., 'UserInventory', 'EndpointInventory').
    .OUTPUTS
        [string] The composite key.
    .EXAMPLE
        $key = Get-SyncStateKey -TenantId 'abc-123' -DataType 'UserInventory'
        Returns 'abc-123|UserInventory'
    .NOTES
        Part of Story 8.4 - Incremental Sync Support.
        Internal helper function for state cache management.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$TenantId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DataType
    )

    return "$TenantId|$DataType"
}

# Initialize state cache at module scope if not already initialized
if (-not $script:SyncStateCache) {
    $script:SyncStateCache = @{}
}
