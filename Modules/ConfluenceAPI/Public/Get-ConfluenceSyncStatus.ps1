function Get-ConfluenceSyncStatus {
    <#
    .SYNOPSIS
        Retrieves sync status for tenants.
    .DESCRIPTION
        Returns sync status derived from the most recent sync log entry for each tenant.
        Status can be: Success, PartialFailure, Failed, or Never (if no sync has occurred).

        When -IncludeNeverSynced is specified, also returns tenants that have a mapping
        but have never been synced (status = 'Never').

        Note: Status is derived from in-memory sync logs which are cleared on module reload.
        For persistent status tracking, export Get-ConfluenceSyncLog results.
    .PARAMETER TenantId
        Filter to a specific tenant. If not specified, returns status for all tenants.
    .PARAMETER IncludeNeverSynced
        Include tenants that have a mapping but have never been synced.
        Requires Get-ConfluenceTenantMapping to be available.
    .PARAMETER Summary
        Return summary counts instead of individual tenant statuses.
        Returns: TotalTenants, SuccessCount, PartialFailureCount, FailedCount, NeverSyncedCount
    .OUTPUTS
        [PSCustomObject[]] Array of status objects with properties:
        - TenantId: The tenant identifier
        - SpaceKey: The Confluence space key
        - LastSyncTime: Timestamp of last sync (null for Never)
        - Status: Success, PartialFailure, Failed, or Never
        - Duration: How long the sync took
        - SuccessCount: Number of successful data type syncs
        - FailedCount: Number of failed data type syncs
        - SkippedCount: Number of skipped data type syncs
        - UnchangedCount: Number of unchanged data type syncs
        - ErrorCount: Total error count
        - LastError: Most recent error message (null if successful)
    .EXAMPLE
        Get-ConfluenceSyncStatus
        Returns sync status for all tenants with sync history.
    .EXAMPLE
        Get-ConfluenceSyncStatus -TenantId 'abc-123'
        Returns detailed sync status for tenant abc-123.
    .EXAMPLE
        Get-ConfluenceSyncStatus -IncludeNeverSynced
        Returns status for all mapped tenants, including those never synced.
    .EXAMPLE
        Get-ConfluenceSyncStatus -Summary
        Returns summary counts: TotalTenants, SuccessCount, PartialFailureCount, FailedCount.
    .EXAMPLE
        Get-ConfluenceSyncStatus | Where-Object { $_.Status -ne 'Success' }
        Returns only tenants with sync issues.
    .EXAMPLE
        Get-ConfluenceSyncStatus -Verbose
        Returns status with verbose logging showing tenant issues.
    .LINK
        Get-ConfluenceSyncLog
    .LINK
        Sync-CIPPTenantToConfluence
    .NOTES
        Part of Story 9.2 - Sync Status Dashboard (FR40).
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter()]
        [string]$TenantId,

        [Parameter()]
        [switch]$IncludeNeverSynced,

        [Parameter()]
        [switch]$Summary
    )

    Write-Verbose "Retrieving sync status"

    $results = @()

    # Get most recent log per tenant using Group-Object (if logs exist)
    $latestLogs = @()
    if ($script:SyncLogCache -and $script:SyncLogCache.Count -gt 0) {
        $latestLogs = @($script:SyncLogCache.Values |
            Group-Object TenantId |
            ForEach-Object {
                $_.Group | Sort-Object Timestamp -Descending | Select-Object -First 1
            })
    }

    $tenantCount = @($latestLogs).Count
    Write-Verbose "Found sync history for $tenantCount tenants"

    # Build lookup of tenants with sync history
    $syncedTenants = @{}
    foreach ($log in $latestLogs) {
        $syncedTenants[$log.TenantId] = $log
    }

    # If IncludeNeverSynced, get all tenant mappings and find unsynced ones
    $neverSyncedTenants = @()
    if ($IncludeNeverSynced) {
        Write-Verbose "Checking for tenants that have never been synced"
        try {
            $allMappings = @(Get-ConfluenceTenantMapping)
            foreach ($mapping in $allMappings) {
                if (-not $syncedTenants.ContainsKey($mapping.TenantId)) {
                    $neverSyncedTenants += $mapping
                }
            }
            Write-Verbose "Found $(@($neverSyncedTenants).Count) tenants that have never been synced"
        }
        catch {
            Write-Verbose "Unable to retrieve tenant mappings: $($_.Exception.Message)"
        }
    }

    # Filter by TenantId if specified
    if ($TenantId) {
        Write-Verbose "Filtering for tenant '$TenantId'"

        # Check if tenant has sync history
        if ($syncedTenants.ContainsKey($TenantId)) {
            $latestLogs = @($syncedTenants[$TenantId])
            $neverSyncedTenants = @()
        }
        elseif ($IncludeNeverSynced) {
            # Check if tenant has mapping but no sync
            $neverSyncedTenants = @($neverSyncedTenants | Where-Object { $_.TenantId -eq $TenantId })
            $latestLogs = @()

            if (@($neverSyncedTenants).Count -eq 0) {
                Write-Verbose "No sync history or mapping found for tenant '$TenantId'"
                if ($Summary) {
                    return [PSCustomObject]@{
                        TotalTenants         = 0
                        SuccessCount         = 0
                        PartialFailureCount  = 0
                        FailedCount          = 0
                        NeverSyncedCount     = 0
                    }
                }
                return @()
            }
        }
        else {
            Write-Verbose "No sync history found for tenant '$TenantId'"
            if ($Summary) {
                return [PSCustomObject]@{
                    TotalTenants         = 0
                    SuccessCount         = 0
                    PartialFailureCount  = 0
                    FailedCount          = 0
                    NeverSyncedCount     = 0
                }
            }
            return @()
        }
    }

    # Convert synced tenants to status objects
    foreach ($log in $latestLogs) {
        $lastError = $null
        if ($log.Errors -and @($log.Errors).Count -gt 0) {
            $lastError = $log.Errors[0].Error
        }

        # Log tenants with issues
        if ($log.OverallStatus -ne 'Success') {
            Write-Verbose "Tenant '$($log.TenantId)' last sync: $($log.OverallStatus)"
        }

        $results += [PSCustomObject]@{
            TenantId       = $log.TenantId
            SpaceKey       = $log.SpaceKey
            LastSyncTime   = $log.Timestamp
            Status         = $log.OverallStatus
            Duration       = $log.Duration
            SuccessCount   = $log.SuccessCount
            FailedCount    = $log.FailedCount
            SkippedCount   = $log.SkippedCount
            UnchangedCount = $log.UnchangedCount
            ErrorCount     = $log.ErrorCount
            LastError      = $lastError
        }
    }

    # Add never-synced tenants (if requested)
    foreach ($mapping in $neverSyncedTenants) {
        Write-Verbose "Tenant '$($mapping.TenantId)' has never been synced"
        $results += [PSCustomObject]@{
            TenantId       = $mapping.TenantId
            SpaceKey       = $mapping.SpaceKey
            LastSyncTime   = $null
            Status         = 'Never'
            Duration       = $null
            SuccessCount   = 0
            FailedCount    = 0
            SkippedCount   = 0
            UnchangedCount = 0
            ErrorCount     = 0
            LastError      = $null
        }
    }

    # Return summary if requested
    if ($Summary) {
        $successCount = @($results | Where-Object { $_.Status -eq 'Success' }).Count
        $partialCount = @($results | Where-Object { $_.Status -eq 'PartialFailure' }).Count
        $failedCount = @($results | Where-Object { $_.Status -eq 'Failed' }).Count
        $neverCount = @($results | Where-Object { $_.Status -eq 'Never' }).Count

        Write-Verbose "Summary: Total=$(@($results).Count), Success=$successCount, Partial=$partialCount, Failed=$failedCount, Never=$neverCount"

        return [PSCustomObject]@{
            TotalTenants         = @($results).Count
            SuccessCount         = $successCount
            PartialFailureCount  = $partialCount
            FailedCount          = $failedCount
            NeverSyncedCount     = $neverCount
        }
    }

    return $results
}
