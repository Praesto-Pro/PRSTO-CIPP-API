function Get-ConfluenceBaseURL {
    <#
    .SYNOPSIS
        Retrieves the stored Confluence base URL.
    .DESCRIPTION
        Returns the stored Confluence base URL for API calls. Returns null if
        no URL has been configured.

        Internal module functions access $script:ConfluenceBaseURL directly
        for API calls. This function is for user verification and scripting.
    .EXAMPLE
        Get-ConfluenceBaseURL

        Returns the stored base URL, or null if not configured.
    .EXAMPLE
        Get-ConfluenceBaseURL -Verbose

        Returns the stored base URL with verbose logging.
    .EXAMPLE
        if (Get-ConfluenceBaseURL) { Write-Host "URL configured" }

        Checks if a base URL has been configured.
    .NOTES
        Internal Access: Other module functions access $script:ConfluenceBaseURL directly.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    Write-Verbose "Retrieving stored Confluence base URL"

    if ($script:ConfluenceBaseURL) {
        Write-Verbose "Base URL: $script:ConfluenceBaseURL"
        $script:ConfluenceBaseURL
    }
    else {
        Write-Verbose "No base URL configured"
        $null
    }
}
