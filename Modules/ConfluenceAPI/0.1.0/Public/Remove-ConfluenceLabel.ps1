function Remove-ConfluenceLabel {
    <#
    .SYNOPSIS
        Removes a label from a Confluence page.
    .DESCRIPTION
        Removes a label from a Confluence page. For labels containing "/" characters,
        the function automatically uses the query parameter method with URL encoding
        to properly handle the special character.

        Uses the Confluence Cloud REST API v1 content labels endpoint.
    .PARAMETER PageId
        The unique ID of the Confluence page to remove the label from.
    .PARAMETER Label
        The name of the label to remove from the page.
    .EXAMPLE
        Remove-ConfluenceLabel -PageId '12345678' -Label 'old-label'

        Removes the label 'old-label' from the page.
    .EXAMPLE
        Remove-ConfluenceLabel -PageId '12345678' -Label 'category/subcategory'

        Removes a label containing "/" character using query parameter method.
    .EXAMPLE
        Remove-ConfluenceLabel -PageId '12345678' -Label 'test' -WhatIf

        Shows what would be removed without making changes.
    .EXAMPLE
        Remove-ConfluenceLabel -PageId '12345678' -Label 'old' -Confirm:$false

        Removes the label without confirmation prompt.
    .EXAMPLE
        Remove-ConfluenceLabel -PageId '12345678' -Label 'cleanup' -Verbose

        Removes the label with verbose logging output.
    .EXAMPLE
        Get-ConfluenceLabel -PageId '12345678' | Remove-ConfluenceLabel -PageId '12345678'

        Removes all labels from a page by piping Get-ConfluenceLabel output.
    .NOTES
        This function uses the Confluence Cloud REST API v1 endpoint because
        the v2 API does not support removing labels.

        For labels with "/" characters, the query parameter method is used:
        DELETE /wiki/rest/api/content/{id}/label?name={encodedLabel}

        For standard labels, the path parameter method is used:
        DELETE /wiki/rest/api/content/{id}/label/{label}

        Requires credentials to be configured via New-ConfluenceAPIKey and New-ConfluenceBaseURL.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$PageId,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('Name')]
        [string]$Label
    )

    process {
        Write-Verbose "Removing label '$Label' from page '$PageId'..."

        # Determine endpoint based on whether label contains "/" character
        if ($Label -match '/') {
            # Use query parameter method for labels with "/" - URL encode the label name
            $encodedLabel = [System.Uri]::EscapeDataString($Label)
            $endpoint = "/wiki/rest/api/content/$PageId/label?name=$encodedLabel"
            Write-Verbose "Using query parameter method for label with '/' character"
        }
        else {
            # Use path parameter method for standard labels
            $endpoint = "/wiki/rest/api/content/$PageId/label/$Label"
        }

        # ShouldProcess check - supports -WhatIf and -Confirm
        if (-not $PSCmdlet.ShouldProcess("Page '$PageId'", "Remove label '$Label'")) {
            return
        }

        try {
            $null = Invoke-ConfluenceRequest -Endpoint $endpoint -Method DELETE
        }
        catch {
            $errorMessage = $_.Exception.Message

            # 404 - Page or label not found
            # Determine context based on error message content
            if ($errorMessage -match '404|not found') {
                # Check if it's specifically about the label or the page
                if ($errorMessage -match 'label|No label') {
                    $PSCmdlet.ThrowTerminatingError(
                        [System.Management.Automation.ErrorRecord]::new(
                            [System.Exception]::new("Label '$Label' was not found on page '$PageId'."),
                            "LabelNotFound",
                            [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                            $Label
                        )
                    )
                }
                else {
                    $PSCmdlet.ThrowTerminatingError(
                        [System.Management.Automation.ErrorRecord]::new(
                            [System.Exception]::new("Page with ID '$PageId' was not found. Verify the page ID exists."),
                            "PageNotFound",
                            [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                            $PageId
                        )
                    )
                }
            }

            # 403 - Permission denied
            if ($errorMessage -match '403|forbidden|denied') {
                $PSCmdlet.ThrowTerminatingError(
                    [System.Management.Automation.ErrorRecord]::new(
                        [System.Exception]::new("Access denied to modify labels on page '$PageId'. Check your API permissions."),
                        "AccessDenied",
                        [System.Management.Automation.ErrorCategory]::PermissionDenied,
                        $PageId
                    )
                )
            }

            # Re-throw other errors with context
            $PSCmdlet.ThrowTerminatingError(
                [System.Management.Automation.ErrorRecord]::new(
                    [System.Exception]::new("Failed to remove label '$Label' from page '$PageId': $errorMessage"),
                    "RemoveLabelError",
                    [System.Management.Automation.ErrorCategory]::ConnectionError,
                    $PageId
                )
            )
        }

        Write-Verbose "Successfully removed label '$Label' from page '$PageId'"
        # DELETE returns 204 No Content - no return value
    }
}
