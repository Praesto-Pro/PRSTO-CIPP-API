function New-ConfluencePage {
    <#
    .SYNOPSIS
        Creates a new Confluence page in a space.
    .DESCRIPTION
        Creates a new page in the specified Confluence space. Optionally creates
        the page as a child of an existing page.

        Supports -WhatIf to preview the operation without making changes.
    .PARAMETER SpaceKey
        The human-readable key of the Confluence space (e.g., 'CONTOSO').
        The function looks up the space ID automatically.
    .PARAMETER Title
        The title of the new page.
    .PARAMETER Body
        Optional page content in storage format (HTML) or ADF JSON.
        If not provided, creates an empty page.
    .PARAMETER ParentId
        Optional parent page ID. If specified, creates the page as a child
        of the parent page.
    .EXAMPLE
        New-ConfluencePage -SpaceKey 'CONTOSO' -Title 'User Inventory'

        Creates a new top-level page titled 'User Inventory' in the CONTOSO space.
    .EXAMPLE
        New-ConfluencePage -SpaceKey 'CONTOSO' -Title 'Active Users' -ParentId '789012'

        Creates a new child page under the specified parent.
    .EXAMPLE
        New-ConfluencePage -SpaceKey 'CONTOSO' -Title 'Report' -Body '<p>Content</p>'

        Creates a new page with initial content.
    .EXAMPLE
        New-ConfluencePage -SpaceKey 'CONTOSO' -Title 'Test Page' -WhatIf

        Shows what would happen without actually creating the page.
    .EXAMPLE
        $adfJson = '{"version":1,"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"Hello World"}]}]}'
        New-ConfluencePage -SpaceKey 'CONTOSO' -Title 'ADF Page' -Body $adfJson

        Creates a new page with ADF (Atlassian Document Format) content.
        The function automatically detects ADF JSON and sets the correct representation.
    .NOTES
        Requires credentials to be configured via New-ConfluenceAPIKey and New-ConfluenceBaseURL.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$SpaceKey,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Title,

        [Parameter()]
        [string]$Body,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ParentId
    )

    Write-Verbose "Creating page '$Title' in space '$SpaceKey'..."

    # Look up Space ID from SpaceKey
    $space = Get-ConfluenceSpace -SpaceKey $SpaceKey -ErrorAction Stop
    if (-not $space) {
        $PSCmdlet.ThrowTerminatingError(
            [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new("Space '$SpaceKey' not found."),
                "SpaceNotFound",
                [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                $SpaceKey
            )
        )
    }
    $SpaceId = $space.Id
    Write-Verbose "Resolved SpaceKey '$SpaceKey' to SpaceId '$SpaceId'"

    # Build request body
    $requestBody = @{
        spaceId = $SpaceId
        status  = 'current'
        title   = $Title
    }

    # Add body content if provided
    if ($Body) {
        # Detect if body is ADF JSON by parsing and validating structure
        # ADF format: {"version":1,"type":"doc","content":[...]}
        $isADF = $false
        if ($Body -match '^\s*\{') {
            try {
                $parsed = $Body | ConvertFrom-Json -ErrorAction Stop
                # Valid ADF must have version=1, type="doc", and content property
                $isADF = ($parsed.version -eq 1) -and
                         ($parsed.type -eq 'doc') -and
                         ($null -ne $parsed.content)
            }
            catch {
                # Not valid JSON, treat as storage format
                $isADF = $false
            }
        }

        $representation = if ($isADF) { 'atlas_doc_format' } else { 'storage' }
        Write-Verbose "Body format detected: $representation"

        $requestBody.body = @{
            representation = $representation
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
    $targetDescription = "Page '$Title' in space '$SpaceKey'"
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
                    [System.Exception]::new("Space '$SpaceKey' (ID: $SpaceId) was not found. Verify the space exists."),
                    "SpaceNotFound",
                    [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                    $SpaceKey
                )
            )
        }
        if ($_.Exception.Message -match '403|forbidden|Access denied') {
            $PSCmdlet.ThrowTerminatingError(
                [System.Management.Automation.ErrorRecord]::new(
                    [System.Exception]::new("Access denied creating page in space '$SpaceKey'. Check your API permissions."),
                    "AccessDenied",
                    [System.Management.Automation.ErrorCategory]::PermissionDenied,
                    $SpaceKey
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
