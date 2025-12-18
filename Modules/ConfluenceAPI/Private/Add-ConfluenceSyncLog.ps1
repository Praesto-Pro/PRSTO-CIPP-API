function Add-ConfluenceSyncLog {
    <#
    .SYNOPSIS
        Adds a sync execution log entry (internal function).
    .DESCRIPTION
        Called by Sync-CIPPTenantToConfluence to record sync results.
        Stores log in in-memory cache for retrieval via Get-ConfluenceSyncLog.

        WARNING: Log storage is volatile and cleared on module reload.
        For persistent logging, export results using Get-ConfluenceSyncLog and
        save to a file.
    .PARAMETER SyncResult
        The sync result object from Sync-CIPPTenantToConfluence containing
        TenantId, SpaceKey, Duration, status counts, and error information.
    .OUTPUTS
        None. Log entry is stored in module-scoped cache.
    .EXAMPLE
        Add-ConfluenceSyncLog -SyncResult $syncResult
        Adds a log entry for the sync result.
    .NOTES
        Part of Story 9.1 - Sync Execution Logging (FR39, FR42).
        This is an internal function called by Sync-CIPPTenantToConfluence.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [PSCustomObject]$SyncResult
    )

    # Initialize cache if needed (centralized pattern from Story 8.4)
    if (-not $script:SyncLogCache) {
        $script:SyncLogCache = @{}
    }

    $logId = [guid]::NewGuid().ToString()
    $timestamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss UTC')

    Write-Verbose "Adding sync log entry for tenant '$($SyncResult.TenantId)'"

    $logEntry = [PSCustomObject]@{
        LogId          = $logId
        Timestamp      = $timestamp
        TenantId       = $SyncResult.TenantId
        SpaceKey       = $SyncResult.SpaceKey
        Duration       = $SyncResult.Duration
        OverallStatus  = $SyncResult.OverallStatus
        SuccessCount   = $SyncResult.SuccessCount
        FailedCount    = $SyncResult.FailedCount
        SkippedCount   = $SyncResult.SkippedCount
        UnchangedCount = $SyncResult.UnchangedCount
        ErrorCount     = $SyncResult.ErrorCount
        SyncResults    = $SyncResult.SyncResults
        Errors         = $SyncResult.Errors
    }

    $script:SyncLogCache[$logId] = $logEntry

    Write-Verbose "Logged sync for tenant '$($SyncResult.TenantId)' with ID '$logId'"
}
