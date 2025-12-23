function Invoke-WithRetry {
    <#
    .SYNOPSIS
        Executes a script block with configurable retry logic.
    .DESCRIPTION
        Wraps any operation with retry support for transient failures.
        Uses exponential backoff and integrates with sync configuration.
        Transient errors (5xx, 429, timeout, connection issues) are retried.
        Permanent errors (4xx except 429) are thrown immediately.
    .PARAMETER ScriptBlock
        The operation to execute and potentially retry.
    .PARAMETER MaxRetries
        Maximum number of retry attempts (default: from config or 3).
    .PARAMETER BaseDelaySeconds
        Base delay for exponential backoff (default: from config or 30).
    .PARAMETER OperationName
        Name for logging context (e.g., "UserInventory sync").
    .OUTPUTS
        The result of the script block execution.
    .EXAMPLE
        Invoke-WithRetry -ScriptBlock { Sync-ConfluenceUserInventory -SpaceKey 'TEST' -Users $users } -OperationName 'UserInventory'
    .EXAMPLE
        Invoke-WithRetry -ScriptBlock { Get-Something } -MaxRetries 5 -BaseDelaySeconds 10 -OperationName 'CustomOp'
    .NOTES
        Part of Story 8.3 - Retry Logic & Error Recovery.
        FR37: System can handle sync failures with retry logic.
        NFR10: Transient failures must retry automatically (up to 3 attempts with backoff).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,

        [Parameter()]
        [int]$MaxRetries,

        [Parameter()]
        [int]$BaseDelaySeconds,

        [Parameter()]
        [string]$OperationName = 'Operation',

        [Parameter()]
        [ref]$AttemptsTaken
    )

    # Get defaults from configuration if not provided
    if (-not $PSBoundParameters.ContainsKey('MaxRetries') -or
        -not $PSBoundParameters.ContainsKey('BaseDelaySeconds')) {
        $config = Get-ConfluenceSyncConfiguration
        if (-not $PSBoundParameters.ContainsKey('MaxRetries')) {
            $MaxRetries = $config.RetryAttempts
        }
        if (-not $PSBoundParameters.ContainsKey('BaseDelaySeconds')) {
            $BaseDelaySeconds = $config.RetryDelaySeconds
        }
    }

    $attempt = 0
    $startTime = Get-Date
    $lastError = $null

    while ($attempt -le $MaxRetries) {
        $attempt++

        try {
            Write-Verbose "Attempt $attempt of $($MaxRetries + 1) for $OperationName"
            $result = & $ScriptBlock
            # Set attempt count for caller if requested
            if ($PSBoundParameters.ContainsKey('AttemptsTaken')) {
                $AttemptsTaken.Value = $attempt
            }
            return $result
        }
        catch {
            $lastError = $_

            # Classify error
            $isRetryable = Test-TransientError -Exception $_.Exception

            if (-not $isRetryable) {
                Write-Verbose "Permanent error for $OperationName, not retrying: $($_.Exception.Message)"
                throw
            }

            if ($attempt -gt $MaxRetries) {
                Write-Verbose "All $MaxRetries retries exhausted for $OperationName"
                break
            }

            # Calculate exponential backoff delay
            $delay = $BaseDelaySeconds * [math]::Pow(2, $attempt - 1)
            Write-Verbose "Retry attempt $attempt of $MaxRetries for $OperationName failed: $($_.Exception.Message)"
            Write-Verbose "Waiting $delay seconds before retry (exponential backoff)"
            Start-Sleep -Seconds $delay
        }
    }

    # All retries exhausted - throw with details
    $totalTime = (Get-Date) - $startTime
    $errorMessage = "$OperationName failed after $MaxRetries retries over $($totalTime.TotalSeconds.ToString('F1')) seconds. Last error: $($lastError.Exception.Message)"

    $errorRecord = [System.Management.Automation.ErrorRecord]::new(
        [System.Exception]::new($errorMessage, $lastError.Exception),
        'RetryExhausted',
        [System.Management.Automation.ErrorCategory]::OperationTimeout,
        $OperationName
    )
    throw $errorRecord
}

function Test-TransientError {
    <#
    .SYNOPSIS
        Determines if an error is transient (retryable).
    .DESCRIPTION
        Classifies errors as transient (should retry) or permanent (fail immediately).
        Transient: 5xx, 429, timeout, connection errors.
        Permanent: 4xx (except 429), invalid data, missing parameters.
    .PARAMETER Exception
        The exception to classify.
    .OUTPUTS
        [bool] True if the error is transient and should be retried.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter()]
        [System.Exception]$Exception
    )

    if (-not $Exception) {
        return $false
    }

    $message = $Exception.Message

    # HTTP 5xx server errors
    if ($message -match '\(5\d{2}\)' -or $message -match 'server error') {
        return $true
    }

    # HTTP 429 rate limit
    if ($message -match '\(429\)' -or $message -match 'rate limit') {
        return $true
    }

    # Network/connection errors
    if ($message -match 'timeout|timed out|connection refused|connection reset|unable to connect|network') {
        return $true
    }

    # Confluence server error messages
    if ($message -match 'Confluence server error|Service unavailable|Gateway timeout') {
        return $true
    }

    return $false
}
