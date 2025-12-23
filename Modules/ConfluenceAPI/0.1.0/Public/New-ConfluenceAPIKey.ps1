function New-ConfluenceAPIKey {
    <#
    .SYNOPSIS
        Stores the Confluence API key for authentication.
    .DESCRIPTION
        Stores the provided API token in a script-scoped variable for use by
        other ConfluenceAPI functions. The token is stored in memory only
        and is never persisted to disk or logged.
    .PARAMETER ApiKey
        The Atlassian API token generated from https://id.atlassian.com/manage/api-tokens
    .EXAMPLE
        New-ConfluenceAPIKey -ApiKey 'your-api-token-here'

        Stores the API key for subsequent API calls.
    .EXAMPLE
        New-ConfluenceAPIKey -ApiKey $token -WhatIf

        Shows what would happen without actually storing the key.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ApiKey
    )

    Write-Verbose "Storing Confluence API key"

    if ($PSCmdlet.ShouldProcess("Confluence API Key", "Store credential")) {
        $script:ConfluenceAPIKey = $ApiKey
        Write-Output "Confluence API key has been stored successfully."
    }
}
