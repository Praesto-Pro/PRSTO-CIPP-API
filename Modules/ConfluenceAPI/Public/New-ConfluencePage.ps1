function New-ConfluencePage {
    <#
    .SYNOPSIS
        Creates a new Confluence page in a space.
    .DESCRIPTION
        Creates a new page in the specified Confluence space. Optionally creates
        the page as a child of an existing page.

        Supports -WhatIf to preview the operation without making changes.
    .PARAMETER SpaceId
        The unique ID of the Confluence space to create the page in.
    .PARAMETER Title
        The title of the new page.
    .PARAMETER Body
        Optional page content in storage format (HTML) or ADF JSON.
        If not provided, creates an empty page.
    .PARAMETER ParentId
        Optional parent page ID. If specified, creates the page as a child
        of the parent page.
    .EXAMPLE
        New-ConfluencePage -SpaceId '123456' -Title 'User Inventory'

        Creates a new top-level page titled 'User Inventory' in the specified space.
    .EXAMPLE
        New-ConfluencePage -SpaceId '123456' -Title 'Active Users' -ParentId '789012'

        Creates a new child page under the specified parent.
    .EXAMPLE
        New-ConfluencePage -SpaceId '123456' -Title 'Report' -Body '<p>Content</p>'

        Creates a new page with initial content.
    .EXAMPLE
        New-ConfluencePage -SpaceId '123456' -Title 'Test Page' -WhatIf

        Shows what would happen without actually creating the page.
    .NOTES
        Requires credentials to be configured via New-ConfluenceAPIKey and New-ConfluenceBaseURL.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$SpaceId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Title,

        [Parameter()]
        [string]$Body,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ParentId
    )

    Write-Verbose "Creating page '$Title' in space '$SpaceId'..."

    # Build request body
    $requestBody = @{
        spaceId = $SpaceId
        status  = 'current'
        title   = $Title
    }

    # Add body content if provided
    if ($Body) {
        $requestBody.body = @{
            representation = 'storage'
            value          = $Body
        }
    }

    # Add parent ID for child pages
    if ($ParentId) {
        $requestBody.parentId = $ParentId
        Write-Verbose "Creating as child of page '$ParentId'"
    }

    # Convert to JSON
    $jsonBody = $requestBody | ConvertTo-Json -Depth 10

    # ShouldProcess check
    $targetDescription = "Page '$Title' in space '$SpaceId'"
    if (-not $PSCmdlet.ShouldProcess($targetDescription, "Create Confluence page")) {
        return $null
    }

    try {
        $response = Invoke-ConfluenceRequest -Endpoint '/wiki/api/v2/pages' -Method POST -Body $jsonBody
    }
    catch {
        # Check for common errors
        if ($_.Exception.Message -match '404|not found') {
            $PSCmdlet.ThrowTerminatingError(
                [System.Management.Automation.ErrorRecord]::new(
                    [System.Exception]::new("Space with ID '$SpaceId' was not found. Verify the space ID exists."),
                    "SpaceNotFound",
                    [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                    $SpaceId
                )
            )
        }
        if ($_.Exception.Message -match '403|forbidden|Access denied') {
            $PSCmdlet.ThrowTerminatingError(
                [System.Management.Automation.ErrorRecord]::new(
                    [System.Exception]::new("Access denied creating page in space '$SpaceId'. Check your API permissions."),
                    "AccessDenied",
                    [System.Management.Automation.ErrorCategory]::PermissionDenied,
                    $SpaceId
                )
            )
        }
        # Re-throw with context
        $PSCmdlet.ThrowTerminatingError(
            [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new("Failed to create page '$Title': $($_.Exception.Message)"),
                "PageCreateError",
                [System.Management.Automation.ErrorCategory]::InvalidOperation,
                $Title
            )
        )
    }

    if ($null -eq $response) {
        $PSCmdlet.ThrowTerminatingError(
            [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new("Failed to create page '$Title'. No response received from API."),
                "PageCreateError",
                [System.Management.Automation.ErrorCategory]::InvalidResult,
                $Title
            )
        )
    }

    Write-Verbose "Page '$Title' created successfully with ID '$($response.id)'"

    # Map response to PSCustomObject
    return [PSCustomObject]@{
        Id         = $response.id
        Title      = $response.title
        SpaceId    = $response.spaceId
        Status     = $response.status
        ParentId   = $response.parentId
        ParentType = $response.parentType
        AuthorId   = $response.authorId
        CreatedAt  = $response.createdAt
        Version    = if ($response.version) { $response.version.number } else { $null }
    }
}
