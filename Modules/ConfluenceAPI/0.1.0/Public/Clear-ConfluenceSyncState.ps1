function Clear-ConfluenceSyncState {
    <#
    .SYNOPSIS
        Clears stored sync state.
    .DESCRIPTION
        Removes stored sync state for a specific tenant or all tenants.
        Used to force full sync on next execution or clean up state cache.
    .PARAMETER TenantId
        Optional tenant identifier. If specified, only clears state for that tenant.
        If not specified, clears ALL stored sync state.
    .PARAMETER DataType
        Optional data type filter. Only used when TenantId is specified.
        Clears state only for the specific data type.
    .OUTPUTS
        [PSCustomObject] Summary of cleared state with count of entries removed.
    .EXAMPLE
        Clear-ConfluenceSyncState -TenantId 'abc-123'
        Clears all sync state for the specified tenant.
    .EXAMPLE
        Clear-ConfluenceSyncState -TenantId 'abc-123' -DataType 'UserInventory'
        Clears sync state for a specific tenant and data type.
    .EXAMPLE
        Clear-ConfluenceSyncState
        Clears ALL stored sync state (forces full sync for all tenants).
    .EXAMPLE
        Clear-ConfluenceSyncState -WhatIf
        Shows what state would be cleared without making changes.
    .NOTES
        Part of Story 8.4 - Incremental Sync Support.
        FR38: System can skip sync for unchanged data.
        NFR18: Module must include -WhatIf support for all write operations.

        IMPORTANT: Sync state is stored in-memory only. State is automatically
        cleared when PowerShell session ends or module is reloaded.
        Use this function to force full sync without restarting the session.
    .LINK
        Get-ConfluenceSyncState
    .LINK
        Sync-CIPPTenantToConfluence
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [string]$TenantId,

        [Parameter()]
        [ValidateSet('UserInventory', 'EndpointInventory', 'LicenseReport', 'MFAReport', 'TeamsInventory', 'SharePointInventory')]
        [string]$DataType
    )

    Write-Verbose "Clearing sync state"

    # Initialize cache if not exists
    if (-not $script:SyncStateCache) {
        $script:SyncStateCache = @{}
    }

    # Determine keys to remove
    $keysToRemove = @()

    if (-not $TenantId) {
        # Clear all state
        $keysToRemove = @($script:SyncStateCache.Keys)
        $targetDescription = "ALL sync state ($($keysToRemove.Count) entries)"
    }
    elseif ($DataType) {
        # Clear specific tenant + data type
        $targetKey = "$TenantId|$DataType"
        if ($script:SyncStateCache.ContainsKey($targetKey)) {
            $keysToRemove = @($targetKey)
        }
        $targetDescription = "sync state for tenant '$TenantId' data type '$DataType'"
    }
    else {
        # Clear all data types for specific tenant
        foreach ($key in $script:SyncStateCache.Keys) {
            if ($key.StartsWith("$TenantId|")) {
                $keysToRemove += $key
            }
        }
        $targetDescription = "sync state for tenant '$TenantId' ($($keysToRemove.Count) entries)"
    }

    $removedCount = 0

    if ($PSCmdlet.ShouldProcess($targetDescription, 'Clear')) {
        foreach ($key in $keysToRemove) {
            $script:SyncStateCache.Remove($key)
            $removedCount++
            Write-Verbose "Removed state for key: $key"
        }
        Write-Verbose "Cleared $removedCount sync state entries"
    }

    [PSCustomObject]@{
        TenantId     = $TenantId
        DataType     = $DataType
        EntriesFound = $keysToRemove.Count
        Cleared      = $removedCount
        ClearedAt    = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss UTC')
    }
}
