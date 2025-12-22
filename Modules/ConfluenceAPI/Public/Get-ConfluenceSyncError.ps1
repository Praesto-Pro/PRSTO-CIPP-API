function Get-ConfluenceSyncError {
    <#
    .SYNOPSIS
        Retrieves sync errors with troubleshooting guidance.
    .DESCRIPTION
        Returns sync errors from log entries with categorization and
        actionable troubleshooting hints. Errors are extracted from
        the Errors arrays in sync log entries.

        Each error is classified into one of these categories:
        - ConnectionError: Network/connectivity/auth issues
        - NotFound: Resource not found (404)
        - RateLimit: API rate limiting (429)
        - ValidationError: Invalid data format
        - PermissionDenied: Access denied (403)
        - ServerError: Server-side errors (5xx)
        - Unknown: Unclassified errors

        WARNING: Errors are derived from in-memory sync logs which are
        cleared on module reload. For persistent error tracking, export
        results using: Get-ConfluenceSyncError | Export-Csv -Path 'errors.csv'

        NOTE: Error classification uses message pattern matching. HTTP status
        codes are parsed from error messages when present (e.g., "404 Not Found").
        For more accurate classification, ensure error messages include HTTP codes.
    .PARAMETER TenantId
        Filter errors to a specific tenant. If not specified, returns all errors.
    .PARAMETER Last
        Return only the N most recent errors. Valid range: 1-1000.
    .PARAMETER IncludeStackTrace
        Include full exception details and raw API response for debugging.
    .OUTPUTS
        [PSCustomObject[]] Array of error objects with troubleshooting hints.
        Each object contains: Timestamp, TenantId, SpaceKey, DataType, ErrorCode,
        Message, Category, TroubleshootingHint, LogId.
        With -IncludeStackTrace: also StackTrace and RawResponse.
    .EXAMPLE
        Get-ConfluenceSyncError
        Returns all sync errors from the log cache.
    .EXAMPLE
        Get-ConfluenceSyncError -TenantId 'abc-123'
        Returns all errors for tenant abc-123.
    .EXAMPLE
        Get-ConfluenceSyncError -Last 10
        Returns the 10 most recent errors.
    .EXAMPLE
        Get-ConfluenceSyncError -TenantId 'abc-123' -Last 5
        Returns the 5 most recent errors for tenant abc-123.
    .EXAMPLE
        Get-ConfluenceSyncError -IncludeStackTrace
        Returns errors with full exception details for debugging.
    .EXAMPLE
        Get-ConfluenceSyncError | Where-Object { $_.Category -eq 'ConnectionError' }
        Returns only connection-related errors.
    .NOTES
        Part of Story 9.3 - Error Reporting & Troubleshooting.
        FR41: System can log detailed error information for troubleshooting.
        NFR20: Error messages must include actionable troubleshooting guidance.
    .LINK
        Get-ConfluenceSyncLog
    .LINK
        Get-ConfluenceSyncStatus
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
        [switch]$IncludeStackTrace
    )

    Write-Verbose "Retrieving sync errors"

    if (-not $script:SyncLogCache -or $script:SyncLogCache.Count -eq 0) {
        Write-Verbose "No sync logs found - no errors to report"
        return @()
    }

    # Flatten errors from all logs
    $allErrors = @()
    foreach ($log in $script:SyncLogCache.Values) {
        if ($log.Errors -and @($log.Errors).Count -gt 0) {
            foreach ($errorEntry in $log.Errors) {
                # Get classification
                $classification = Get-SyncErrorCategory -ErrorMessage $errorEntry.Error

                # Parse error code from message (HTTP status codes like 401, 403, 404, 429, 500-599)
                $parsedErrorCode = $null
                if ($errorEntry.Error -match '\b(40[0-9]|4[1-9][0-9]|5[0-9]{2})\b') {
                    $parsedErrorCode = $Matches[1]
                }

                $errorObj = [PSCustomObject]@{
                    Timestamp           = $log.Timestamp
                    TenantId            = $log.TenantId
                    SpaceKey            = $log.SpaceKey
                    DataType            = $errorEntry.DataType
                    ErrorCode           = $parsedErrorCode
                    Message             = $errorEntry.Error
                    Category            = $classification.Category
                    TroubleshootingHint = $classification.TroubleshootingHint
                    LogId               = $log.LogId
                }

                # Add stack trace if requested
                if ($IncludeStackTrace) {
                    Add-Member -InputObject $errorObj -MemberType NoteProperty -Name 'StackTrace' -Value $errorEntry.StackTrace
                    Add-Member -InputObject $errorObj -MemberType NoteProperty -Name 'RawResponse' -Value $errorEntry.RawResponse
                }

                $allErrors += $errorObj
            }
        }
    }

    Write-Verbose "Found $(@($allErrors).Count) total errors"

    # Sort by timestamp (newest first)
    $allErrors = @($allErrors | Sort-Object Timestamp -Descending)

    # Filter by TenantId if specified
    if ($TenantId) {
        Write-Verbose "Filtering for tenant '$TenantId'"
        $allErrors = @($allErrors | Where-Object { $_.TenantId -eq $TenantId })
    }

    # Limit results if specified
    if ($Last -and $Last -gt 0) {
        Write-Verbose "Limiting to last $Last errors"
        $allErrors = @($allErrors | Select-Object -First $Last)
    }

    Write-Verbose "Returning $(@($allErrors).Count) errors"

    return $allErrors
}
