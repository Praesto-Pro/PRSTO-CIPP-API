function Test-ConfluenceConnection {
    <#
    .SYNOPSIS
        Tests the Confluence API connection using stored credentials.
    .DESCRIPTION
        Validates that the configured API key and base URL can successfully
        connect to the Confluence instance. This is useful to verify credentials
        before running sync operations.

        Requires both New-ConfluenceAPIKey and New-ConfluenceBaseURL to be run first.
    .EXAMPLE
        Test-ConfluenceConnection

        Tests the connection and returns status object.
    .EXAMPLE
        Test-ConfluenceConnection -Verbose

        Tests the connection with detailed logging output.
    .EXAMPLE
        if ((Test-ConfluenceConnection).ConnectionStatus) { "Connected!" }

        Checks connection status in a script.
    .NOTES
        The function calls /wiki/api/v2/spaces?limit=1 to validate connectivity
        without retrieving large amounts of data.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    Write-Verbose "Testing connection to Confluence"

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

    # Build request URL
    $uri = "$script:ConfluenceBaseURL/wiki/api/v2/spaces?limit=1"
    Write-Verbose "Connecting to: $uri"

    # Prepare Basic Auth header
    # Note: Atlassian uses email:token format, but we store only token
    # Using token-only auth with empty username prefix
    $base64Auth = [System.Convert]::ToBase64String(
        [System.Text.Encoding]::ASCII.GetBytes(":$($script:ConfluenceAPIKey)")
    )
    $headers = @{
        "Authorization" = "Basic $base64Auth"
        "Accept"        = "application/json"
    }

    try {
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get -TimeoutSec 30

        Write-Verbose "Connection successful"

        # Extract CloudId from response if available
        $cloudId = $null
        if ($response.results -and $response.results.Count -gt 0) {
            $baseLink = $response.results[0]._links.base
            if ($baseLink -match '/wiki/spaces/|confluence/([^/]+)/wiki') {
                $cloudId = $Matches[1]
            }
        }

        [PSCustomObject]@{
            ConnectionStatus = $true
            Message          = "Successfully connected to Confluence"
            BaseURL          = $script:ConfluenceBaseURL
            CloudId          = $cloudId
        }
    }
    catch {
        $statusCode = $null
        $errorMessage = "Connection failed: $($_.Exception.Message)"

        # Try to extract HTTP status code from exception
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
        }

        # Also check for status code in WebException message for PS 5.1 compatibility
        if (-not $statusCode -and $_.Exception.Message) {
            if ($_.Exception.Message -match '\(401\)') { $statusCode = 401 }
            elseif ($_.Exception.Message -match '\(403\)') { $statusCode = 403 }
            elseif ($_.Exception.Message -match '\(404\)') { $statusCode = 404 }
            elseif ($_.Exception.Message -match '\(5\d{2}\)') { $statusCode = 500 }
        }

        # Map status codes to user-friendly messages (per AC6 spec)
        switch ($statusCode) {
            401 { $errorMessage = "Authentication failed. Verify your API key is correct." }
            403 { $errorMessage = "Access forbidden. Check API key permissions." }
            404 { $errorMessage = "Confluence instance not found. Verify your base URL." }
            { $_ -ge 500 -and $_ -lt 600 } {
                $errorMessage = "Confluence server error. Try again later."
            }
            default {
                if ($_.Exception.Message -match 'timed out|timeout') {
                    $errorMessage = "Connection timed out. Check your network connectivity."
                }
            }
        }

        Write-Verbose "Connection failed: $errorMessage"

        [PSCustomObject]@{
            ConnectionStatus = $false
            Message          = $errorMessage
            BaseURL          = $script:ConfluenceBaseURL
            ErrorCode        = $statusCode
        }
    }
}
