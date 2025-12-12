function Remove-ConfluenceBaseURL {
    <#
    .SYNOPSIS
        Removes the stored Confluence base URL.
    .DESCRIPTION
        Clears the stored Confluence base URL from memory. This function is
        idempotent - calling it when no URL is stored does not produce an error.
    .EXAMPLE
        Remove-ConfluenceBaseURL

        Removes the stored base URL.
    .EXAMPLE
        Remove-ConfluenceBaseURL -WhatIf

        Shows what would happen without actually removing the URL.
    .EXAMPLE
        Remove-ConfluenceBaseURL -Confirm:$false

        Removes the URL without confirmation prompt.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([string])]
    param()

    Write-Verbose "Removing stored Confluence base URL"

    if ($PSCmdlet.ShouldProcess("Confluence Base URL", "Remove configuration")) {
        if ($script:ConfluenceBaseURL) {
            $script:ConfluenceBaseURL = $null
            Write-Output "Confluence base URL has been removed."
        }
        else {
            $script:ConfluenceBaseURL = $null
            Write-Verbose "No base URL was configured to remove."
        }
    }
}
