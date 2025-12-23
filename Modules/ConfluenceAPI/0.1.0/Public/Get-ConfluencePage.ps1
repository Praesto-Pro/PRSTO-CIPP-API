function Get-ConfluencePage {
    <#
    .SYNOPSIS
        Gets Confluence page(s) by ID or lists all pages in a space.
    .DESCRIPTION
        Retrieves Confluence page information. When called with a PageId parameter,
        returns a single page. When called with SpaceId, returns all pages in that space
        with automatic pagination handling.

        Optionally includes page body content in various formats.
    .PARAMETER PageId
        The unique ID of the Confluence page to retrieve. If not specified,
        SpaceId must be provided to list pages.
    .PARAMETER SpaceId
        The unique ID of the Confluence space to list pages from.
        Cannot be used with PageId.
    .PARAMETER IncludeBody
        Switch to include page body content in the response.
    .PARAMETER BodyFormat
        The format for the body content. Valid values: 'storage', 'atlas_doc_format', 'view'.
        Default: 'storage'. Only used when IncludeBody is specified.
    .EXAMPLE
        Get-ConfluencePage -PageId '12345678'

        Returns the page with ID '12345678'.
    .EXAMPLE
        Get-ConfluencePage -PageId '12345678' -IncludeBody

        Returns the page with its body content in storage format.
    .EXAMPLE
        Get-ConfluencePage -PageId '12345678' -IncludeBody -BodyFormat 'atlas_doc_format'

        Returns the page with body content in ADF format.
    .EXAMPLE
        Get-ConfluencePage -SpaceId '789012'

        Returns all pages in the space with automatic pagination.
    .EXAMPLE
        Get-ConfluencePage -PageId '12345' -Verbose

        Returns the page with verbose logging.
    .NOTES
        Requires credentials to be configured via New-ConfluenceAPIKey and New-ConfluenceBaseURL.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByPageId')]
    [OutputType([PSCustomObject], [PSCustomObject[]])]
    param(
        [Parameter(ParameterSetName = 'ByPageId', Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$PageId,

        [Parameter(ParameterSetName = 'BySpaceId', Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$SpaceId,

        [Parameter()]
        [switch]$IncludeBody,

        [Parameter()]
        [ValidateSet('storage', 'atlas_doc_format', 'view')]
        [string]$BodyFormat = 'storage'
    )

    if ($PSCmdlet.ParameterSetName -eq 'ByPageId') {
        Write-Verbose "Getting page '$PageId'..."

        # Build endpoint with optional body format
        $endpoint = "/wiki/api/v2/pages/$PageId"
        if ($IncludeBody) {
            $endpoint = "$endpoint`?body-format=$BodyFormat"
        }

        try {
            $response = Invoke-ConfluenceRequest -Endpoint $endpoint -Method GET
        }
        catch {
            # Check if it's a 404 error
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
            # Re-throw other errors with more context
            $PSCmdlet.ThrowTerminatingError(
                [System.Management.Automation.ErrorRecord]::new(
                    [System.Exception]::new("Failed to get page '$PageId': $($_.Exception.Message)"),
                    "PageGetError",
                    [System.Management.Automation.ErrorCategory]::ConnectionError,
                    $PageId
                )
            )
        }

        if ($null -eq $response) {
            $PSCmdlet.ThrowTerminatingError(
                [System.Management.Automation.ErrorRecord]::new(
                    [System.Exception]::new("Page with ID '$PageId' was not found. Verify the page ID exists."),
                    "PageNotFound",
                    [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                    $PageId
                )
            )
        }

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
            Body       = if ($IncludeBody -and $response.body -and $response.body.$BodyFormat) {
                $response.body.$BodyFormat.value
            } else {
                $null
            }
        }
    }
    else {
        # BySpaceId parameter set
        Write-Verbose "Getting all pages in space '$SpaceId'..."

        # Get all pages in space - pagination handled by Invoke-ConfluenceRequest
        $endpoint = "/wiki/api/v2/spaces/$SpaceId/pages"

        try {
            $response = Invoke-ConfluenceRequest -Endpoint $endpoint -Method GET
        }
        catch {
            # Check if it's a 404 error
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
            $PSCmdlet.ThrowTerminatingError(
                [System.Management.Automation.ErrorRecord]::new(
                    [System.Exception]::new("Failed to get pages in space '$SpaceId': $($_.Exception.Message)"),
                    "PageListError",
                    [System.Management.Automation.ErrorCategory]::ConnectionError,
                    $SpaceId
                )
            )
        }

        # Handle response - use @() to ensure we always get an array (prevents pipeline unwrapping)
        $pages = @($response)

        if ($null -eq $pages -or $pages.Count -eq 0) {
            Write-Verbose "No pages found in space '$SpaceId'"
            return @()
        }

        Write-Verbose "Found $($pages.Count) page(s) in space '$SpaceId'"

        # Map all pages to PSCustomObjects
        $result = foreach ($page in $pages) {
            [PSCustomObject]@{
                Id         = $page.id
                Title      = $page.title
                SpaceId    = $page.spaceId
                Status     = $page.status
                ParentId   = $page.parentId
                ParentType = $page.parentType
                AuthorId   = $page.authorId
                CreatedAt  = $page.createdAt
                Version    = if ($page.version) { $page.version.number } else { $null }
                Body       = $null  # Body not included in list operations
            }
        }

        return $result
    }
}
