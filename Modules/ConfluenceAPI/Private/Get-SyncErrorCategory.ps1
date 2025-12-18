function Get-SyncErrorCategory {
    <#
    .SYNOPSIS
        Classifies sync errors into categories with troubleshooting hints.
    .DESCRIPTION
        Analyzes error messages and HTTP status codes to determine the error
        category and provide actionable troubleshooting guidance.

        Categories:
        - ConnectionError: Network/connectivity/auth issues
        - NotFound: Resource not found (404)
        - RateLimit: API rate limiting (429)
        - ValidationError: Invalid data format
        - PermissionDenied: Access denied (403)
        - ServerError: Server-side errors (5xx)
        - Unknown: Unclassified errors
    .PARAMETER ErrorMessage
        The error message to classify.
    .PARAMETER HttpStatusCode
        Optional HTTP status code for more accurate classification.
    .OUTPUTS
        [PSCustomObject] Object with Category and TroubleshootingHint properties.
    .EXAMPLE
        Get-SyncErrorCategory -ErrorMessage 'Connection timeout after 30 seconds'
        Returns: @{ Category = 'ConnectionError'; TroubleshootingHint = '...' }
    .EXAMPLE
        Get-SyncErrorCategory -ErrorMessage 'Not found' -HttpStatusCode 404
        Returns: @{ Category = 'NotFound'; TroubleshootingHint = '...' }
    .NOTES
        Part of Story 9.3 - Error Reporting & Troubleshooting.
        Private helper function for Get-ConfluenceSyncError.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string]$ErrorMessage,

        [Parameter()]
        [int]$HttpStatusCode
    )

    Write-Verbose "Classifying error message: $ErrorMessage"

    # Default values
    $category = 'Unknown'
    $hint = 'Check the sync logs for more details. If the issue persists, enable verbose logging with -Verbose.'

    # HTTP Status Code based classification (takes priority)
    if ($HttpStatusCode -gt 0) {
        Write-Verbose "HTTP status code provided: $HttpStatusCode"
        switch ($HttpStatusCode) {
            401 {
                $category = 'ConnectionError'
                $hint = 'Invalid API credentials. Verify API key using Get-ConfluenceAPIKey and test with Test-ConfluenceConnection.'
            }
            403 {
                $category = 'PermissionDenied'
                $hint = 'API token lacks required permissions. Check token scopes in Atlassian admin console.'
            }
            404 {
                $category = 'NotFound'
                $hint = 'Resource not found. Verify space key and page IDs exist in Confluence.'
            }
            429 {
                $category = 'RateLimit'
                $hint = 'API rate limit exceeded. Wait before retrying or increase sync interval in Set-ConfluenceSyncConfiguration.'
            }
            default {
                if ($HttpStatusCode -ge 500) {
                    $category = 'ServerError'
                    $hint = 'Confluence server error. Check Atlassian status page (status.atlassian.com) or retry later.'
                }
            }
        }
        if ($category -ne 'Unknown') {
            Write-Verbose "Classified by HTTP status code as: $category"
            return [PSCustomObject]@{
                Category            = $category
                TroubleshootingHint = $hint
            }
        }
    }

    # Message pattern matching
    $lowerMessage = $ErrorMessage.ToLower()

    # Connection errors
    if ($lowerMessage -match 'timeout|connection refused|network|unreachable|dns|socket|ssl|tls|certificate') {
        $category = 'ConnectionError'
        $hint = 'Verify network connectivity and API credentials using Test-ConfluenceConnection. Check firewall rules and proxy settings.'
    }
    # Rate limiting
    elseif ($lowerMessage -match 'rate limit|too many requests|throttl|429') {
        $category = 'RateLimit'
        $hint = 'API rate limit exceeded. Wait before retrying or reduce sync frequency in Set-ConfluenceSyncConfiguration.'
    }
    # Validation errors (check before NotFound - "required field missing" should be ValidationError)
    elseif ($lowerMessage -match 'invalid|validation|required|missing field|bad request|400|malformed|format') {
        $category = 'ValidationError'
        $hint = 'Data validation failed. Check input data format and required fields. Review CIPP data source for issues.'
    }
    # Not found (use specific pattern to avoid matching "missing field" which is ValidationError)
    elseif ($lowerMessage -match 'not found|404|does not exist|no such|resource missing') {
        $category = 'NotFound'
        $hint = 'Resource not found. Verify the space key and page exist. Use Get-ConfluenceSpace or Get-ConfluencePage to check.'
    }
    # Permission errors
    elseif ($lowerMessage -match 'permission|denied|forbidden|unauthorized|403|401|auth|access') {
        $category = 'PermissionDenied'
        $hint = 'Check API token permissions in Atlassian admin console. Ensure the token has read/write access to the target space.'
    }
    # Server errors
    elseif ($lowerMessage -match '5\d{2}|server error|internal error|service unavailable|bad gateway') {
        $category = 'ServerError'
        $hint = 'Confluence server error. Check Atlassian status page (status.atlassian.com). Retry the sync operation later.'
    }

    Write-Verbose "Classified by message pattern as: $category"

    return [PSCustomObject]@{
        Category            = $category
        TroubleshootingHint = $hint
    }
}
