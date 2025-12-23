function Get-ConfluenceSyncLog {
    <#
    .SYNOPSIS
        Retrieves sync execution logs.
    .DESCRIPTION
        Returns sync log entries for troubleshooting and audit purposes.
        Supports filtering by tenant and limiting result count.

        WARNING: Logs are stored in memory and cleared when the module is reloaded.
        For persistent logging, export results to a file using:
            Get-ConfluenceSyncLog | Export-Csv -Path 'sync-logs.csv'
    .PARAMETER TenantId
        Filter logs to a specific tenant. If not specified, returns all logs.
    .PARAMETER Last
        Return only the N most recent log entries. Valid range: 1-1000.
    .PARAMETER IncludeDetails
        Include full SyncResults and Errors arrays in output.
        By default, these large arrays are excluded for cleaner output.
    .OUTPUTS
        [PSCustomObject[]] Array of log entries in reverse chronological order.
    .EXAMPLE
        Get-ConfluenceSyncLog
        Returns all sync logs (summary view).
    .EXAMPLE
        Get-ConfluenceSyncLog -TenantId 'abc-123'
        Returns all logs for tenant abc-123.
    .EXAMPLE
        Get-ConfluenceSyncLog -TenantId 'abc-123' -Last 5
        Returns the 5 most recent logs for tenant abc-123.
    .EXAMPLE
        Get-ConfluenceSyncLog -Last 10 -IncludeDetails
        Returns the 10 most recent logs with full sync result details.
    .NOTES
        Part of Story 9.1 - Sync Execution Logging.
        FR39: Technical Lead can view sync execution logs.
    .LINK
        Add-ConfluenceSyncLog
    .LINK
        Clear-ConfluenceSyncLog
    .LINK
        Sync-CIPPTenantToConfluence
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter()]
        [string]$TenantId,

        [Parameter()]
        [ValidateRange(1, 1000)]
        [int]$Last,

        [Parameter()]
        [switch]$IncludeDetails
    )

    Write-Verbose "Retrieving sync logs"

    if (-not $script:SyncLogCache -or $script:SyncLogCache.Count -eq 0) {
        Write-Verbose "No sync logs found"
        return @()
    }

    # Get all logs and sort by timestamp (newest first)
    $logs = $script:SyncLogCache.Values | Sort-Object Timestamp -Descending

    # Filter by TenantId if specified
    if ($TenantId) {
        Write-Verbose "Filtering logs for tenant '$TenantId'"
        $logs = @($logs | Where-Object { $_.TenantId -eq $TenantId })
    }

    # Limit results if specified
    if ($Last -and $Last -gt 0) {
        Write-Verbose "Limiting to last $Last entries"
        $logs = @($logs | Select-Object -First $Last)
    }

    # Return summary or details based on switch
    if ($IncludeDetails) {
        Write-Verbose "Including full sync details"
        return @($logs)
    }
    else {
        # Return summary view (exclude large arrays)
        return @($logs | ForEach-Object {
            [PSCustomObject]@{
                LogId          = $_.LogId
                Timestamp      = $_.Timestamp
                TenantId       = $_.TenantId
                SpaceKey       = $_.SpaceKey
                Duration       = $_.Duration
                OverallStatus  = $_.OverallStatus
                SuccessCount   = $_.SuccessCount
                FailedCount    = $_.FailedCount
                SkippedCount   = $_.SkippedCount
                UnchangedCount = $_.UnchangedCount
                ErrorCount     = $_.ErrorCount
            }
        })
    }
}
