function Set-ConfluencePage {
    <#
    .SYNOPSIS
        Updates an existing Confluence page.
    .DESCRIPTION
        Updates the title, body content, or status of an existing page.
        Automatically handles version incrementing required by the Confluence API.

        At least one update parameter (Title, Body, or Status) must be provided.
        Supports -WhatIf to preview the operation without making changes.
    .PARAMETER PageId
        The unique ID of the page to update.
    .PARAMETER Title
        New title for the page. If not provided, keeps the existing title.
    .PARAMETER Body
        New body content in storage format (HTML).
    .PARAMETER Status
        New status for the page. Valid values: 'current', 'draft'.
    .EXAMPLE
        Set-ConfluencePage -PageId '12345678' -Title 'New Title'

        Updates the page title, preserving existing content.
    .EXAMPLE
        Set-ConfluencePage -PageId '12345678' -Body '<p>Updated content</p>'

        Updates the page content.
    .EXAMPLE
        Set-ConfluencePage -PageId '12345678' -Title 'New Title' -Body '<p>New content</p>'

        Updates both title and content.
    .EXAMPLE
        Set-ConfluencePage -PageId '12345678' -Title 'Test' -WhatIf

        Shows what would be updated without making changes.
    .NOTES
        Requires credentials to be configured via New-ConfluenceAPIKey and New-ConfluenceBaseURL.

        CRITICAL: The Confluence API requires the version number to be incremented
        for each update. This function automatically fetches the current version
        and increments it before updating.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$PageId,

        [Parameter()]
        [string]$Title,

        [Parameter()]
        [string]$Body,

        [Parameter()]
        [ValidateSet('current', 'draft')]
        [string]$Status
    )

    # Validate at least one update parameter is provided
    if (-not $Title -and -not $Body -and -not $Status) {
        $PSCmdlet.ThrowTerminatingError(
            [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new("At least one update parameter (Title, Body, or Status) must be provided."),
                "NoUpdateParameters",
                [System.Management.Automation.ErrorCategory]::InvalidArgument,
                $PageId
            )
        )
    }

    Write-Verbose "Updating page '$PageId'..."

    # STEP 1: Fetch current page to get version number, title, and existing values
    try {
        $currentPage = Invoke-ConfluenceRequest -Endpoint "/wiki/api/v2/pages/$PageId`?body-format=storage" -Method GET
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
        $PSCmdlet.ThrowTerminatingError(
            [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new("Failed to fetch page '$PageId' for update: $($_.Exception.Message)"),
                "PageFetchError",
                [System.Management.Automation.ErrorCategory]::ConnectionError,
                $PageId
            )
        )
    }

    if ($null -eq $currentPage) {
        $PSCmdlet.ThrowTerminatingError(
            [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new("Page with ID '$PageId' was not found. Verify the page ID exists."),
                "PageNotFound",
                [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                $PageId
            )
        )
    }

    # STEP 2: Calculate new version number
    $currentVersion = $currentPage.version.number
    $newVersion = $currentVersion + 1
    $currentTitle = $currentPage.title
    Write-Verbose "Updating page '$PageId/$currentTitle' from version $currentVersion to $newVersion..."

    # STEP 3: Build update request body
    # Use provided values or fall back to current values
    $updateTitle = if ($Title) { $Title } else { $currentPage.title }
    $updateStatus = if ($Status) { $Status } else { $currentPage.status }

    $requestBody = @{
        id      = $PageId
        status  = $updateStatus
        title   = $updateTitle
        version = @{
            number  = $newVersion
            message = ''
        }
    }

    # Add body if provided, or preserve existing
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
    elseif ($currentPage.body -and $currentPage.body.storage) {
        $requestBody.body = @{
            representation = 'storage'
            value          = $currentPage.body.storage.value
        }
    }

    # Convert to JSON
    $jsonBody = $requestBody | ConvertTo-Json -Depth 10

    # ShouldProcess check
    $changes = @()
    if ($Title) { $changes += "Title='$Title'" }
    if ($Body) { $changes += "Body updated" }
    if ($Status) { $changes += "Status='$Status'" }
    $targetDescription = "Page '$PageId' ($($changes -join ', '))"

    if (-not $PSCmdlet.ShouldProcess($targetDescription, "Update Confluence page")) {
        return $null
    }

    # STEP 4: Execute the update
    try {
        $response = Invoke-ConfluenceRequest -Endpoint "/wiki/api/v2/pages/$PageId" -Method PUT -Body $jsonBody
    }
    catch {
        # Handle version conflict specifically
        if ($_.Exception.Message -match '409|conflict|version') {
            $PSCmdlet.ThrowTerminatingError(
                [System.Management.Automation.ErrorRecord]::new(
                    [System.Exception]::new("Version conflict updating page '$PageId'. Current version is $currentVersion. The page may have been modified. Please retry."),
                    "VersionConflict",
                    [System.Management.Automation.ErrorCategory]::ResourceExists,
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
                [System.Exception]::new("Failed to update page '$PageId': $($_.Exception.Message)"),
                "PageUpdateError",
                [System.Management.Automation.ErrorCategory]::InvalidOperation,
                $PageId
            )
        )
    }

    if ($null -eq $response) {
        $PSCmdlet.ThrowTerminatingError(
            [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new("Failed to update page '$PageId'. No response received from API."),
                "PageUpdateError",
                [System.Management.Automation.ErrorCategory]::InvalidResult,
                $PageId
            )
        )
    }

    Write-Verbose "Page '$PageId' updated successfully to version $newVersion"

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
