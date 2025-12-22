function Get-ConfluenceSyncState {
    <#
    .SYNOPSIS
        Retrieves stored sync state for a tenant.
    .DESCRIPTION
        Returns the current sync state including data hashes and last sync times
        for all data types associated with the specified tenant. If no TenantId
        is specified, returns state for all tenants.
    .PARAMETER TenantId
        Optional tenant identifier. If not specified, returns all sync state.
    .PARAMETER DataType
        Optional data type filter (e.g., 'UserInventory', 'EndpointInventory').
        Only used when TenantId is specified.
    .OUTPUTS
        [PSCustomObject[]] Array of sync state objects with TenantId, DataType,
        Hash, LastSyncTime, and PageId properties.
    .EXAMPLE
        Get-ConfluenceSyncState -TenantId 'abc-123'
        Returns sync state for all data types for the specified tenant.
    .EXAMPLE
        Get-ConfluenceSyncState -TenantId 'abc-123' -DataType 'UserInventory'
        Returns sync state for a specific tenant and data type.
    .EXAMPLE
        Get-ConfluenceSyncState
        Returns all stored sync state.
    .NOTES
        Part of Story 8.4 - Incremental Sync Support.
        FR38: System can skip sync for unchanged data.

        IMPORTANT: Sync state is stored in-memory only. State is lost when:
        - PowerShell session ends
        - Module is removed/reloaded
        - Import-Module -Force is used
        After state loss, next sync will perform full sync for all data types.
    .LINK
        Clear-ConfluenceSyncState
    .LINK
        Sync-CIPPTenantToConfluence
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter()]
        [string]$TenantId,

        [Parameter()]
        [ValidateSet('UserInventory', 'EndpointInventory', 'LicenseReport', 'MFAReport', 'TeamsInventory', 'SharePointInventory')]
        [string]$DataType
    )

    Write-Verbose "Retrieving sync state"

    # Initialize cache if not exists
    if (-not $script:SyncStateCache) {
        $script:SyncStateCache = @{}
    }

    # If no state stored, return empty array
    if ($script:SyncStateCache.Count -eq 0) {
        Write-Verbose "No sync state stored"
        return @()
    }

    $results = @()

    foreach ($key in $script:SyncStateCache.Keys) {
        $parts = $key -split '\|'
        $storedTenantId = $parts[0]
        $storedDataType = $parts[1]
        $state = $script:SyncStateCache[$key]

        # Filter by TenantId if specified
        if ($TenantId -and $storedTenantId -ne $TenantId) {
            continue
        }

        # Filter by DataType if specified
        if ($DataType -and $storedDataType -ne $DataType) {
            continue
        }

        $results += [PSCustomObject]@{
            TenantId     = $storedTenantId
            DataType     = $storedDataType
            Hash         = $state.Hash
            ShortHash    = if ($state.Hash) { $state.Hash.Substring(0, 16) } else { $null }
            LastSyncTime = $state.LastSyncTime
            PageId       = $state.PageId
        }
    }

    if ($TenantId) {
        Write-Verbose "Found $($results.Count) state entries for tenant '$TenantId'"
    }
    else {
        Write-Verbose "Found $($results.Count) total state entries"
    }

    return $results
}
