function Add-ConfluenceLabel {
    <#
    .SYNOPSIS
        Adds one or more labels to a Confluence page.
    .DESCRIPTION
        Adds labels to a Confluence page. Multiple labels can be added in a single
        API call by passing an array of label names. All labels are created with
        the 'global' prefix for user-created labels.

        Uses the Confluence Cloud REST API v1 content labels endpoint.
    .PARAMETER PageId
        The unique ID of the Confluence page to add labels to.
    .PARAMETER Label
        One or more label names to add to the page. Accepts an array for batch operations.
    .EXAMPLE
        Add-ConfluenceLabel -PageId '12345678' -Label 'user-inventory'

        Adds a single label 'user-inventory' to the page.
    .EXAMPLE
        Add-ConfluenceLabel -PageId '12345678' -Label 'label1', 'label2', 'label3'

        Adds multiple labels in a single API call.
    .EXAMPLE
        Add-ConfluenceLabel -PageId '12345678' -Label 'important' -WhatIf

        Shows what would be added without making changes.
    .EXAMPLE
        Add-ConfluenceLabel -PageId '12345678' -Label 'new-label' -Verbose

        Adds a label with verbose logging output.
    .NOTES
        This function uses the Confluence Cloud REST API v1 endpoint because
        the v2 API does not support adding labels.

        Requires credentials to be configured via New-ConfluenceAPIKey and New-ConfluenceBaseURL.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$PageId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Label
    )

    $labelList = $Label -join ', '
    Write-Verbose "Adding label(s) '$labelList' to page '$PageId'..."

    # Build request body - array of label objects with prefix and name
    $requestBody = @(
        foreach ($labelName in $Label) {
            @{
                prefix = 'global'
                name   = $labelName
            }
        }
    )

    # Convert to JSON for the API call
    $jsonBody = $requestBody | ConvertTo-Json -Compress
    # Handle single item array serialization (PowerShell converts single item to object, not array)
    if ($Label.Count -eq 1) {
        $jsonBody = "[$jsonBody]"
    }

    # Build v1 API endpoint for page labels
    $endpoint = "/wiki/rest/api/content/$PageId/label"

    # ShouldProcess check - supports -WhatIf and -Confirm
    if (-not $PSCmdlet.ShouldProcess("Page '$PageId'", "Add label(s) '$labelList'")) {
        return $null
    }

    try {
        $response = Invoke-ConfluenceRequest -Endpoint $endpoint -Method POST -Body $jsonBody
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
                    [System.Exception]::new("Access denied to modify labels on page '$PageId'. Check your API permissions."),
                    "AccessDenied",
                    [System.Management.Automation.ErrorCategory]::PermissionDenied,
                    $PageId
                )
            )
        }

        # 400 - Bad request (invalid label name, etc.)
        if ($errorMessage -match '400|bad request|invalid') {
            $PSCmdlet.ThrowTerminatingError(
                [System.Management.Automation.ErrorRecord]::new(
                    [System.Exception]::new("Failed to add label(s) '$labelList' to page '$PageId': $errorMessage"),
                    "InvalidLabel",
                    [System.Management.Automation.ErrorCategory]::InvalidArgument,
                    $PageId
                )
            )
        }

        # Re-throw other errors with context
        $PSCmdlet.ThrowTerminatingError(
            [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new("Failed to add label(s) '$labelList' to page '$PageId': $errorMessage"),
                "AddLabelError",
                [System.Management.Automation.ErrorCategory]::ConnectionError,
                $PageId
            )
        )
    }

    # Handle response - v1 API returns array of added labels directly (not wrapped in results)
    if ($null -eq $response) {
        Write-Verbose "No response received from API for add label operation"
        return @()
    }

    # Response is an array of label objects directly from the v1 API
    # When the API returns a single label, it may come unwrapped
    if ($response -is [array]) {
        $responseArray = $response
    }
    else {
        $responseArray = @(,$response)
    }

    Write-Verbose "Successfully added $($responseArray.Count) label(s) to page '$PageId'"

    # Map v1 API response to PSCustomObject array
    $labels = foreach ($item in $responseArray) {
        [PSCustomObject]@{
            Id     = $item.id
            Name   = $item.name
            Prefix = $item.prefix
        }
    }

    return $labels
}
