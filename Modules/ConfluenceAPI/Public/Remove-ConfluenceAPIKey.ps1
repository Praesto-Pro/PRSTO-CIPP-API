function Remove-ConfluenceAPIKey {
    <#
    .SYNOPSIS
        Removes the stored Confluence API key.
    .DESCRIPTION
        Clears the stored API key from memory. This function is idempotent -
        calling it when no key is stored does not produce an error.
    .EXAMPLE
        Remove-ConfluenceAPIKey

        Removes the stored API key.
    .EXAMPLE
        Remove-ConfluenceAPIKey -WhatIf

        Shows what would happen without actually removing the key.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param()

    Write-Verbose "Removing stored Confluence API key"

    if ($PSCmdlet.ShouldProcess("Confluence API Key", "Remove credential")) {
        $script:ConfluenceAPIKey = $null
        Write-Output "Confluence API key has been removed."
    }
}
