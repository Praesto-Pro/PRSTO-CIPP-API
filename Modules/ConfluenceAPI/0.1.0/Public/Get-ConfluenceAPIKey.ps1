function Get-ConfluenceAPIKey {
    <#
    .SYNOPSIS
        Retrieves the stored Confluence API key status.
    .DESCRIPTION
        Returns a masked representation of the stored API key to confirm
        a key is configured. The actual token is never returned to the user
        to prevent accidental exposure in console output or logs.

        Internal module functions (e.g., Invoke-ConfluenceRequest) should access
        the token directly via $script:ConfluenceAPIKey variable, following the
        HuduAPI pattern for credential management.
    .EXAMPLE
        Get-ConfluenceAPIKey

        Returns masked key representation if stored, null otherwise.
    .EXAMPLE
        Get-ConfluenceAPIKey -Verbose

        Returns masked key with verbose logging.
    .NOTES
        Internal Access: Other module functions access $script:ConfluenceAPIKey directly.
        This function is for user verification only.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    Write-Verbose "Retrieving stored API key"

    if ($script:ConfluenceAPIKey) {
        # Return masked representation to user - actual token accessed via $script:ConfluenceAPIKey by internal functions
        [PSCustomObject]@{
            IsConfigured = $true
            MaskedKey    = "****...****"
        }
    }
    else {
        $null
    }
}
