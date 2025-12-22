function Get-ConfluenceLabel {
    <#
    .SYNOPSIS
        Gets labels from a Confluence page.
    .DESCRIPTION
        Retrieves all labels attached to a Confluence page. Returns an array of label
        objects with Id, Name, and Prefix properties. Returns an empty array if the
        page has no labels.

        Uses the Confluence Cloud REST API v1 content labels endpoint.
    .PARAMETER PageId
        The unique ID of the Confluence page to retrieve labels from.
    .EXAMPLE
        Get-ConfluenceLabel -PageId '12345678'

        Returns all labels on the page with ID '12345678'.
    .EXAMPLE
        Get-ConfluenceLabel -PageId '12345678' -Verbose

        Returns all labels with verbose logging.
    .EXAMPLE
        $labels = Get-ConfluenceLabel -PageId '12345678'
        $labels | Where-Object { $_.Name -like 'user-*' }

        Gets labels and filters for those starting with 'user-'.
    .NOTES
        This function uses the Confluence Cloud REST API v1 endpoint because
        the v2 API does not support label operations.

        Requires credentials to be configured via New-ConfluenceAPIKey and New-ConfluenceBaseURL.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$PageId
    )

    Write-Verbose "Retrieving labels for page '$PageId'..."

    # Build v1 API endpoint for page labels
    $endpoint = "/wiki/rest/api/content/$PageId/label"

    try {
        $response = Invoke-ConfluenceRequest -Endpoint $endpoint -Method GET
    }
    catch {
        $errorMessage = $_.Exception.Message

        # 404 - Page not found
        if ($errorMessage -match '404|not found') {
            $PSCmdlet.ThrowTerminatingError(
                [System.Management.Automation.ErrorRecord]::new(
                    [System.Exception]::new("Page with ID '$PageId' was not found. Verify the page ID exists."),
                    "PageNotFound",
                    [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                    $PageId
                )
            )
        }

        # 403 - Permission denied
        if ($errorMessage -match '403|forbidden|denied') {
            $PSCmdlet.ThrowTerminatingError(
                [System.Management.Automation.ErrorRecord]::new(
                    [System.Exception]::new("Access denied to view labels on page '$PageId'. Check your API permissions."),
                    "AccessDenied",
                    [System.Management.Automation.ErrorCategory]::PermissionDenied,
                    $PageId
                )
            )
        }

        # Re-throw other errors with context
        $PSCmdlet.ThrowTerminatingError(
            [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new("Failed to retrieve labels for page '$PageId': $errorMessage"),
                "GetLabelError",
                [System.Management.Automation.ErrorCategory]::ConnectionError,
                $PageId
            )
        )
    }

    # Handle null or empty response - v1 API returns { results: [...] }
    if ($null -eq $response -or $null -eq $response.results -or $response.results.Count -eq 0) {
        Write-Verbose "No labels found on page '$PageId'"
        return @()
    }

    Write-Verbose "Found $($response.results.Count) label(s) on page '$PageId'"

    # Map v1 API response to PSCustomObject array
    $labels = foreach ($label in $response.results) {
        [PSCustomObject]@{
            Id     = $label.id
            Name   = $label.name
            Prefix = $label.prefix
        }
    }

    return $labels
}
