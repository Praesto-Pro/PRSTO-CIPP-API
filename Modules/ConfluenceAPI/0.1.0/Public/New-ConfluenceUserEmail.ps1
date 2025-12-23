function New-ConfluenceUserEmail {
    <#
    .SYNOPSIS
        Stores the Confluence user email for authentication.
    .DESCRIPTION
        Stores the provided user email in a script-scoped variable for use by
        other ConfluenceAPI functions. Required for Basic Auth which uses
        email:api_token format.
    .PARAMETER Email
        The email address associated with the Atlassian account.
    .EXAMPLE
        New-ConfluenceUserEmail -Email 'user@example.com'

        Stores the user email for subsequent API calls.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Email
    )

    Write-Verbose "Storing Confluence user email"

    if ($PSCmdlet.ShouldProcess("Confluence User Email", "Store credential")) {
        $script:ConfluenceUserEmail = $Email
        Write-Output "Confluence user email has been stored successfully."
    }
}
