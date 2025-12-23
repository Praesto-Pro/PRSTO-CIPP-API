function Invoke-ConfluenceRequest {
    <#
    .SYNOPSIS
        Makes authenticated requests to the Confluence REST API v2.
    .DESCRIPTION
        Central API wrapper for all Confluence operations. Handles authentication,
        rate limiting, retry logic, and pagination automatically.

        All other Confluence functions use this internally for API communication.
        Supports both standard Confluence URLs and service account scoped URLs.
    .PARAMETER Endpoint
        The API endpoint path (e.g., '/wiki/api/v2/spaces')
    .PARAMETER Method
        HTTP method: GET, POST, PUT, DELETE (default: GET)
    .PARAMETER Body
        JSON body for POST/PUT requests
    .PARAMETER Limit
        Maximum number of results to return (for paginated endpoints)
    .EXAMPLE
        Invoke-ConfluenceRequest -Endpoint '/wiki/api/v2/spaces'

        Gets all spaces (with automatic pagination).
    .EXAMPLE
        Invoke-ConfluenceRequest -Endpoint '/wiki/api/v2/spaces' -Method POST -Body $jsonBody

        Creates a new space.
    .EXAMPLE
        Invoke-ConfluenceRequest -Endpoint '/wiki/api/v2/pages/12345' -Method DELETE -WhatIf

        Shows what would happen without actually deleting.
    .NOTES
        Implements NFR3 (graceful rate limiting), NFR10 (3-retry with backoff),
        NFR15 (cursor-based pagination), NFR6 (token security).
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([PSCustomObject], [PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Endpoint,

        [Parameter()]
        [ValidateSet('GET', 'POST', 'PUT', 'DELETE')]
        [string]$Method = 'GET',

        [Parameter()]
        [string]$Body,

        [Parameter()]
        [int]$Limit = 0
    )

    # Validate credentials are configured
    if (-not $script:ConfluenceAPIKey) {
        $PSCmdlet.ThrowTerminatingError(
            [System.Management.Automation.ErrorRecord]::new(
                [System.InvalidOperationException]::new(
                    "API key not configured. Run New-ConfluenceAPIKey first."
                ),
                "CredentialsNotConfigured",
                [System.Management.Automation.ErrorCategory]::AuthenticationError,
                $null
            )
        )
    }

    if (-not $script:ConfluenceUserEmail) {
        $PSCmdlet.ThrowTerminatingError(
            [System.Management.Automation.ErrorRecord]::new(
                [System.InvalidOperationException]::new(
                    "User email not configured. Run New-ConfluenceUserEmail first."
                ),
                "CredentialsNotConfigured",
                [System.Management.Automation.ErrorCategory]::AuthenticationError,
                $null
            )
        )
    }

    if (-not $script:ConfluenceBaseURL) {
        $PSCmdlet.ThrowTerminatingError(
            [System.Management.Automation.ErrorRecord]::new(
                [System.InvalidOperationException]::new(
                    "Base URL not configured. Run New-ConfluenceBaseURL first."
                ),
                "CredentialsNotConfigured",
                [System.Management.Automation.ErrorCategory]::InvalidOperation,
                $null
            )
        )
    }

    # Prepare Basic Auth header (email:api_token format for Confluence Cloud)
    $base64Auth = [System.Convert]::ToBase64String(
        [System.Text.Encoding]::ASCII.GetBytes("$($script:ConfluenceUserEmail):$($script:ConfluenceAPIKey)")
    )
    $headers = @{
        "Authorization" = "Basic $base64Auth"
        "Accept"        = "application/json"
    }

    # Add Content-Type for POST/PUT
    if ($Method -in @('POST', 'PUT') -and $Body) {
        $headers["Content-Type"] = "application/json"
    }

    # WhatIf support for write operations
    if ($Method -in @('POST', 'PUT', 'DELETE')) {
        $targetDescription = "$Method $Endpoint"
        if (-not $PSCmdlet.ShouldProcess($targetDescription, "Invoke Confluence API request")) {
            return $null
        }
    }

    # Pagination support - collect all results
    $allResults = @()
    $currentEndpoint = $Endpoint
    $hasMorePages = $true
    $pageCount = 0

    while ($hasMorePages) {
        # Build full URL
        $uri = "$script:ConfluenceBaseURL$currentEndpoint"
        Write-Verbose "Requesting: $Method $uri"

        # Retry logic with exponential backoff
        $maxRetries = 3
        $retryCount = 0
        $response = $null

        while ($retryCount -le $maxRetries) {
            try {
                $invokeParams = @{
                    Uri     = $uri
                    Headers = $headers
                    Method  = $Method
                }

                if ($Body -and $Method -in @('POST', 'PUT')) {
                    $invokeParams['Body'] = $Body
                }

                $response = Invoke-RestMethod @invokeParams
                break
            }
            catch {
                $statusCode = $null

                # Extract status code - handle both PS 5.1 and PS 7
                if ($_.Exception.Response) {
                    try {
                        $statusCode = [int]$_.Exception.Response.StatusCode
                    }
                    catch {
                        # StatusCode might be enum, try value__
                        try {
                            $statusCode = [int]$_.Exception.Response.StatusCode.value__
                        }
                        catch {
                            # Silently continue - will fall back to message parsing
                            $statusCode = $null
                        }
                    }
                }

                # Fallback: Parse from exception message (PS 5.1 compatibility)
                if (-not $statusCode -and $_.Exception.Message) {
                    if ($_.Exception.Message -match '\((\d{3})\)') {
                        $statusCode = [int]$Matches[1]
                    }
                }

                # Determine if error is retryable
                $isRetryable = $false
                $delay = 0

                if ($statusCode -eq 429) {
                    # Rate limited - use Retry-After header
                    $isRetryable = $true
                    $delay = Get-RateLimitDelay -Response $_.Exception.Response -DefaultDelay 5
                    Write-Verbose "Rate limited. Waiting $delay seconds before retry"
                }
                elseif ($statusCode -ge 500 -and $statusCode -lt 600) {
                    # Server error - exponential backoff
                    $isRetryable = $true
                    $delay = [math]::Pow(2, $retryCount)  # 1, 2, 4 seconds
                    Write-Verbose "Server error ($statusCode). Waiting $delay seconds before retry"
                }

                if ($isRetryable -and $retryCount -lt $maxRetries) {
                    $retryCount++
                    Write-Verbose "Retry $retryCount of $maxRetries after ${delay}s delay"
                    Start-Sleep -Seconds $delay
                    continue
                }

                # Non-retryable error or retries exhausted - throw with actionable message
                $errorMessage = switch ($statusCode) {
                    400 { "Bad request. Check your request parameters. Endpoint: $Endpoint" }
                    401 { "Authentication failed. Verify API key." }
                    403 { "Access forbidden. Check permissions." }
                    404 { "Resource not found. Verify endpoint or ID. Endpoint: $Endpoint" }
                    429 { "Rate limit exceeded after $maxRetries retries. Try again later." }
                    { $_ -ge 500 -and $_ -lt 600 } { "Confluence server error after $maxRetries retries. Try again later." }
                    default { "API request failed: $($_.Exception.Message)" }
                }

                $PSCmdlet.ThrowTerminatingError(
                    [System.Management.Automation.ErrorRecord]::new(
                        [System.Exception]::new($errorMessage),
                        "ConfluenceAPIError",
                        [System.Management.Automation.ErrorCategory]::ConnectionError,
                        $Endpoint
                    )
                )
            }
        }

        # Process successful response
        if ($null -eq $response) {
            # Should not happen, but handle gracefully
            break
        }

        # Handle paginated responses
        if ($null -ne $response.results) {
            $allResults += $response.results
            $pageCount++
            Write-Verbose "Page $pageCount retrieved. Total results so far: $($allResults.Count)"

            # Check if we've hit the limit
            if ($Limit -gt 0 -and $allResults.Count -ge $Limit) {
                $allResults = $allResults[0..($Limit - 1)]
                Write-Verbose "Limit of $Limit results reached"
                $hasMorePages = $false
            }
            # Check for next page cursor
            elseif ($response._links -and $response._links.next) {
                # Extract cursor from next link
                $nextLink = $response._links.next
                # The next link is typically a relative path with cursor parameter
                if ($nextLink -match 'cursor=([^&]+)') {
                    $cursor = $Matches[1]
                    # Build new endpoint with cursor - always use original endpoint as base
                    if ($Endpoint -match '\?') {
                        $currentEndpoint = "$Endpoint&cursor=$cursor"
                    }
                    else {
                        $currentEndpoint = "$Endpoint`?cursor=$cursor"
                    }
                    Write-Verbose "Following pagination cursor"
                }
                else {
                    # Use full next link if it's a complete path
                    $currentEndpoint = $nextLink
                }
            }
            else {
                $hasMorePages = $false
            }
        }
        else {
            # Non-paginated response - return as-is
            return $response
        }
    }

    # Return aggregated results for paginated responses
    if ($allResults.Count -gt 0) {
        return $allResults
    }

    return $response
}
