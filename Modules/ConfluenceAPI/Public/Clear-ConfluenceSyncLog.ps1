function Clear-ConfluenceSyncLog {
    <#
    .SYNOPSIS
        Clears sync execution logs.
    .DESCRIPTION
        Removes sync log entries from memory. Can clear all logs or
        logs for a specific tenant.

        Supports -WhatIf to preview what would be cleared without
        making changes.
    .PARAMETER TenantId
        Clear only logs for a specific tenant. If not specified, clears all logs.
    .OUTPUTS
        None.
    .EXAMPLE
        Clear-ConfluenceSyncLog
        Clears all sync logs (prompts for confirmation).
    .EXAMPLE
        Clear-ConfluenceSyncLog -TenantId 'abc-123'
        Clears logs for tenant abc-123 only (prompts for confirmation).
    .EXAMPLE
        Clear-ConfluenceSyncLog -TenantId 'abc-123' -Confirm:$false
        Clears logs for tenant abc-123 without confirmation.
    .EXAMPLE
        Clear-ConfluenceSyncLog -WhatIf
        Shows what would be cleared without making changes.
    .NOTES
        Part of Story 9.1 - Sync Execution Logging.
        Uses ConfirmImpact = 'High' to require confirmation by default.
    .LINK
        Get-ConfluenceSyncLog
    .LINK
        Add-ConfluenceSyncLog
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter()]
        [string]$TenantId
    )

    if (-not $script:SyncLogCache -or $script:SyncLogCache.Count -eq 0) {
        Write-Verbose "No sync logs to clear"
        return
    }

    if ($TenantId) {
        $target = "sync logs for tenant '$TenantId'"
        $logsToRemove = @($script:SyncLogCache.Keys | Where-Object {
            $script:SyncLogCache[$_].TenantId -eq $TenantId
        })
        $count = $logsToRemove.Count
    }
    else {
        $target = "all sync logs ($($script:SyncLogCache.Count) entries)"
        $logsToRemove = @($script:SyncLogCache.Keys)
        $count = $script:SyncLogCache.Count
    }

    if ($count -eq 0) {
        Write-Verbose "No logs found matching criteria"
        return
    }

    Write-Verbose "Preparing to clear $count log entries"

    if ($PSCmdlet.ShouldProcess($target, "Clear")) {
        foreach ($key in $logsToRemove) {
            $script:SyncLogCache.Remove($key)
        }
        Write-Verbose "Cleared $count sync log entries"
    }
}
