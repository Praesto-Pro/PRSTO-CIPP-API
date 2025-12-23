function Move-ConfluencePage {
    <#
    .SYNOPSIS
        Moves a Confluence page to a new location in the hierarchy.
    .DESCRIPTION
        Moves a Confluence page to a new parent or positions it relative to a sibling page.
        Uses the Confluence Cloud REST API v1 move endpoint.

        Position options:
        - 'append' (default): Makes the page a child of the target (re-parenting)
        - 'before': Places the page before the target sibling
        - 'after': Places the page after the target sibling

        To move a page to a different space, use the target space's home page ID
        with position 'append'.
    .PARAMETER PageId
        The unique ID of the Confluence page to move.
    .PARAMETER TargetId
        The unique ID of the target content. When Position is 'append', this is the
        new parent page. When Position is 'before' or 'after', this is the sibling page.
    .PARAMETER Position
        Where to place the page relative to the target. Valid values:
        - 'append': Make target the parent (default)
        - 'before': Place before target sibling
        - 'after': Place after target sibling
    .EXAMPLE
        Move-ConfluencePage -PageId '12345' -TargetId '67890'

        Moves page 12345 to become a child of page 67890.
    .EXAMPLE
        Move-ConfluencePage -PageId '12345' -TargetId '67890' -Position 'before'

        Moves page 12345 to be positioned before sibling page 67890.
    .EXAMPLE
        Move-ConfluencePage -PageId '12345' -TargetId '99999' -WhatIf

        Shows what move operation would be performed without executing it.
    .EXAMPLE
        Move-ConfluencePage -PageId '12345' -TargetId '67890' -Verbose

        Moves the page with verbose logging output.
    .NOTES
        This function uses the Confluence Cloud REST API v1 move endpoint because
        the v2 API does not support page movement operations.

        Requires credentials to be configured via New-ConfluenceAPIKey and New-ConfluenceBaseURL.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$PageId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$TargetId,

        [Parameter()]
        [ValidateSet('append', 'before', 'after')]
        [string]$Position = 'append'
    )

    Write-Verbose "Moving page '$PageId' to target '$TargetId' with position '$Position'..."

    # Build the v1 API endpoint for page movement
    $endpoint = "/wiki/rest/api/content/$PageId/move/$Position/$TargetId"

    # ShouldProcess check - supports -WhatIf and -Confirm
    if (-not $PSCmdlet.ShouldProcess("Page '$PageId'", "Move to target '$TargetId' with position '$Position'")) {
        return $null
    }

    try {
        $response = Invoke-ConfluenceRequest -Endpoint $endpoint -Method PUT
    }
    catch {
        # Check for specific error conditions
        $errorMessage = $_.Exception.Message

        # 404 - Page or target not found
        # The API doesn't distinguish which ID is invalid, so provide both for context
        if ($errorMessage -match '404|not found') {
            $PSCmdlet.ThrowTerminatingError(
                [System.Management.Automation.ErrorRecord]::new(
                    [System.Exception]::new("Page '$PageId' or target '$TargetId' was not found. Verify both IDs exist."),
                    "ContentNotFound",
                    [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                    $PageId
                )
            )
        }

        # 403 - Permission denied
        if ($errorMessage -match '403|forbidden|denied') {
            $PSCmdlet.ThrowTerminatingError(
                [System.Management.Automation.ErrorRecord]::new(
                    [System.Exception]::new("Access denied to move page '$PageId'. Check your API permissions."),
                    "AccessDenied",
                    [System.Management.Automation.ErrorCategory]::PermissionDenied,
                    $PageId
                )
            )
        }

        # 400 - Invalid move operation (circular reference, invalid target, etc.)
        if ($errorMessage -match '400|bad request|invalid') {
            $PSCmdlet.ThrowTerminatingError(
                [System.Management.Automation.ErrorRecord]::new(
                    [System.Exception]::new("Cannot move page '$PageId' to target '$TargetId'. The move operation is invalid (check for circular references or invalid target type)."),
                    "InvalidMove",
                    [System.Management.Automation.ErrorCategory]::InvalidOperation,
                    $PageId
                )
            )
        }

        # Re-throw other errors with context
        $PSCmdlet.ThrowTerminatingError(
            [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new("Failed to move page '$PageId' to target '$TargetId': $errorMessage"),
                "MovePageError",
                [System.Management.Automation.ErrorCategory]::ConnectionError,
                $PageId
            )
        )
    }

    # Handle null response
    if ($null -eq $response) {
        $PSCmdlet.ThrowTerminatingError(
            [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new("Move operation failed for page '$PageId'. No response received from API."),
                "MovePageFailed",
                [System.Management.Automation.ErrorCategory]::InvalidResult,
                $PageId
            )
        )
    }

    # Map v1 API response to PSCustomObject
    # Note: v1 API uses 'ancestors' array where ancestors[-1] (last element) is the immediate parent
    # and 'space' object for space information (includes id and key)
    # This function returns SpaceKey (unique to Move-ConfluencePage due to v1 API response)
    [PSCustomObject]@{
        Id         = $response.id
        Title      = $response.title
        SpaceId    = $response.space.id
        SpaceKey   = $response.space.key
        Status     = $response.status
        ParentId   = if ($response.ancestors -and $response.ancestors.Count -gt 0) { $response.ancestors[-1].id } else { $null }
        ParentType = if ($response.ancestors -and $response.ancestors.Count -gt 0) { $response.ancestors[-1].type } else { $null }
        Version    = if ($response.version) { $response.version.number } else { $null }
    }
}
