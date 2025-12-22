function New-ConfluenceBaseURL {
    <#
    .SYNOPSIS
        Sets the Confluence instance base URL for API calls.
    .DESCRIPTION
        Stores the Confluence base URL in a script-scoped variable for use by
        other ConfluenceAPI functions. Supports both standard Confluence URLs
        and service account scoped URLs.

        Supported URL formats:
        - Standard: https://{domain}.atlassian.net/wiki
        - Service Account: https://api.atlassian.com/ex/confluence/{cloudId}

        Trailing slashes are automatically normalized (removed).
    .PARAMETER BaseURL
        The Confluence instance base URL. Must be a valid HTTPS URL.
    .EXAMPLE
        New-ConfluenceBaseURL -BaseURL 'https://mycompany.atlassian.net/wiki'

        Sets the base URL for a standard Confluence Cloud instance.
    .EXAMPLE
        New-ConfluenceBaseURL -BaseURL 'https://api.atlassian.com/ex/confluence/abc123-def456'

        Sets the base URL for service account access using cloud ID.
    .EXAMPLE
        New-ConfluenceBaseURL -BaseURL 'https://example.atlassian.net/wiki/' -Verbose

        Sets the URL with trailing slash normalized, with verbose output.
    .NOTES
        Internal Access: Other module functions access $script:ConfluenceBaseURL directly.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$BaseURL
    )

    # Validate URL format
    $uri = $null
    $isValidUri = [System.Uri]::TryCreate($BaseURL, [System.UriKind]::Absolute, [ref]$uri)

    if (-not $isValidUri -or $uri.Scheme -ne 'https') {
        $errorMessage = "Invalid URL format. URL must be a valid HTTPS URL. Expected formats: " +
                        "'https://{domain}.atlassian.net/wiki' or " +
                        "'https://api.atlassian.com/ex/confluence/{cloudId}'"
        $PSCmdlet.ThrowTerminatingError(
            [System.Management.Automation.ErrorRecord]::new(
                [System.ArgumentException]::new($errorMessage),
                "InvalidURLFormat",
                [System.Management.Automation.ErrorCategory]::InvalidArgument,
                $BaseURL
            )
        )
    }

    # Normalize trailing slash
    $normalizedURL = $BaseURL.TrimEnd('/')

    Write-Verbose "Storing Confluence base URL: $normalizedURL"

    if ($PSCmdlet.ShouldProcess("Confluence Base URL", "Store configuration")) {
        $script:ConfluenceBaseURL = $normalizedURL
        Write-Output "Confluence base URL has been stored successfully."
    }
}
