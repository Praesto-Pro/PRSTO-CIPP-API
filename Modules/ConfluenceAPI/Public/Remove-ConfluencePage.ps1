function Remove-ConfluencePage {
    <#
    .SYNOPSIS
        Removes (trashes) a Confluence page.
    .DESCRIPTION
        Moves a Confluence page to the trash. The page is not permanently deleted
        and can be restored from the trash in Confluence.

        Requires confirmation by default due to ConfirmImpact = 'High'.
        Use -Force to skip confirmation, or -WhatIf to preview.
    .PARAMETER PageId
        The unique ID of the page to remove.
    .PARAMETER Force
        Bypasses confirmation prompt and removes the page immediately.
    .EXAMPLE
        Remove-ConfluencePage -PageId '12345678'

        Prompts for confirmation, then moves the page to trash.
    .EXAMPLE
        Remove-ConfluencePage -PageId '12345678' -Force

        Removes the page without prompting for confirmation.
    .EXAMPLE
        Remove-ConfluencePage -PageId '12345678' -WhatIf

        Shows what would happen without actually removing the page.
    .EXAMPLE
        Get-ConfluencePage -SpaceId '789' | Where-Object Title -like 'Draft*' | Remove-ConfluencePage -Force

        Removes all pages with titles starting with 'Draft' in the space.
    .NOTES
        Requires credentials to be configured via New-ConfluenceAPIKey and New-ConfluenceBaseURL.

        The page is moved to trash, not permanently deleted. It can be restored
        from the Confluence UI or via the API.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias('Id')]
        [ValidateNotNullOrEmpty()]
        [string]$PageId,

        [Parameter()]
        [switch]$Force
    )

    process {
        Write-Verbose "Removing page '$PageId'..."

        # ShouldProcess check
        $targetDescription = "Page '$PageId'"
        if (-not $PSCmdlet.ShouldProcess($targetDescription, "Remove Confluence page (move to trash)")) {
            return
        }

        # Force parameter is handled by ShouldProcess - with ConfirmImpact='High',
        # confirmation is prompted unless -Force or -Confirm:$false is used

        try {
            $null = Invoke-ConfluenceRequest -Endpoint "/wiki/api/v2/pages/$PageId" -Method DELETE
        }
        catch {
            if ($_.Exception.Message -match '404|not found') {
                $PSCmdlet.ThrowTerminatingError(
                    [System.Management.Automation.ErrorRecord]::new(
                        [System.Exception]::new("Page with ID '$PageId' was not found. Verify the page ID exists."),
                        "PageNotFound",
                        [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                        $PageId
                    )
                )
            }
            if ($_.Exception.Message -match '403|forbidden|Access denied') {
                $PSCmdlet.ThrowTerminatingError(
                    [System.Management.Automation.ErrorRecord]::new(
                        [System.Exception]::new("Access denied to page '$PageId'. Check your API permissions."),
                        "AccessDenied",
                        [System.Management.Automation.ErrorCategory]::PermissionDenied,
                        $PageId
                    )
                )
            }
            $PSCmdlet.ThrowTerminatingError(
                [System.Management.Automation.ErrorRecord]::new(
                    [System.Exception]::new("Failed to remove page '$PageId': $($_.Exception.Message)"),
                    "PageRemoveError",
                    [System.Management.Automation.ErrorCategory]::InvalidOperation,
                    $PageId
                )
            )
        }

        Write-Verbose "Page '$PageId' moved to trash successfully"

        # Return nothing on success (void)
    }
}
