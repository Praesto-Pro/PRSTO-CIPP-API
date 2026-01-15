function Search-Confluence {
    <#
    .SYNOPSIS
        Searches Confluence content using CQL (Confluence Query Language).
    .DESCRIPTION
        Executes a CQL query against the Confluence Cloud REST API v1 search endpoint.
        Returns an array of search results with Id, Title, Type, SpaceKey, Url, and Excerpt
        properties. Returns an empty array if no matches are found.

        CQL syntax: field operator value
        Common fields: space, type, label, title, text, creator, created, lastModified
        Operators: =, !=, ~, !~, >, <, IN, NOT IN, AND, OR

        Note: Uses the v1 REST API search endpoint because v2 does not have search functionality.
    .PARAMETER CQL
        The CQL query string to execute. Will be URL-encoded automatically.
        Example: "space = 'CONTOSO' AND type = page"
        Example: "label = 'user-inventory'"
        Example: "text ~ 'john smith'"
    .PARAMETER Limit
        Maximum number of results to return. Default is 0 (no limit, returns all results).
        The API has backend limits based on expand parameter (50-1000).
    .PARAMETER Expand
        Additional properties to include in the response.
        Example: 'content.body.view' to include page body content.
    .EXAMPLE
        Search-Confluence -CQL "space = 'CONTOSO' AND type = page"

        Searches for all pages in the CONTOSO space.
    .EXAMPLE
        Search-Confluence -CQL "label = 'user-inventory'" -Verbose

        Searches for all pages with the 'user-inventory' label with verbose logging.
    .EXAMPLE
        Search-Confluence -CQL "text ~ 'john smith'" -Limit 50

        Searches for pages containing 'john smith', limited to 50 results.
    .EXAMPLE
        Search-Confluence -CQL "type = page" -Expand 'content.body.view'

        Searches for all pages and includes body content in results.
    .NOTES
        This function uses the Confluence Cloud REST API v1 search endpoint because
        the v2 API does not support search operations.

        Result limits vary based on expand parameter:
        - With body expansion: max 50 results
        - Without body expansion: max 200 results
        - No expansions: max 1000 results

        Requires credentials to be configured via New-ConfluenceAPIKey and New-ConfluenceBaseURL.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$CQL,

        [Parameter()]
        [int]$Limit = 0,

        [Parameter()]
        [string]$Expand
    )

    Write-Verbose "Searching Confluence with CQL: $CQL"
    if ($Expand) {
        Write-Verbose "Including expanded properties: $Expand"
    }

    # URL-encode the CQL query
    $encodedCQL = [System.Uri]::EscapeDataString($CQL)

    # Build v1 API search endpoint
    $endpoint = "/wiki/rest/api/search?cql=$encodedCQL"

    # Add limit if specified
    if ($Limit -gt 0) {
        $endpoint += "&limit=$Limit"
    }

    # Add expand if specified
    if ($Expand) {
        $encodedExpand = [System.Uri]::EscapeDataString($Expand)
        $endpoint += "&expand=$encodedExpand"
    }

    try {
        Write-Verbose "Calling Confluence search API: $endpoint"
        $response = Invoke-ConfluenceRequest -Endpoint $endpoint -Method GET
        Write-Verbose "Search API response type: $($response.GetType().Name)"
    }
    catch {
        $errorMessage = $_.Exception.Message
        Write-Verbose "Search API threw exception: $errorMessage"

        # 400 - Invalid CQL syntax
        if ($errorMessage -match '400|Bad request|invalid|CQL') {
            $PSCmdlet.ThrowTerminatingError(
                [System.Management.Automation.ErrorRecord]::new(
                    [System.Exception]::new("Invalid CQL query: $errorMessage. Check CQL syntax."),
                    "InvalidCQLQuery",
                    [System.Management.Automation.ErrorCategory]::InvalidArgument,
                    $CQL
                )
            )
        }

        # 403 - Permission denied
        if ($errorMessage -match '403|forbidden|denied') {
            $PSCmdlet.ThrowTerminatingError(
                [System.Management.Automation.ErrorRecord]::new(
                    [System.Exception]::new("Access denied to search. Check your API permissions."),
                    "AccessDenied",
                    [System.Management.Automation.ErrorCategory]::PermissionDenied,
                    $CQL
                )
            )
        }

        # Re-throw other errors with CQL context
        $PSCmdlet.ThrowTerminatingError(
            [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new("Failed to search Confluence: $errorMessage. CQL: $CQL"),
                "SearchError",
                [System.Management.Automation.ErrorCategory]::ConnectionError,
                $CQL
            )
        )
    }

    # Handle response - Invoke-ConfluenceRequest returns just the results array for paginated responses
    # For non-paginated or empty responses, handle appropriately
    $searchResults = $null

    # Check if response is already an array (from Invoke-ConfluenceRequest pagination handling)
    if ($response -is [System.Array]) {
        $searchResults = $response
    }
    # Check if response is wrapped object with results property
    elseif ($null -ne $response -and $null -ne $response.results) {
        $searchResults = $response.results
    }

    # Handle null or empty results
    if ($null -eq $searchResults -or $searchResults.Count -eq 0) {
        Write-Verbose "No results found for CQL query"
        return @()
    }

    Write-Verbose "Found $($searchResults.Count) result(s) for CQL query"

    # Map v1 API response to PSCustomObject array
    $results = foreach ($result in $searchResults) {
        [PSCustomObject]@{
            Id       = $result.content.id
            Title    = $result.title
            Type     = $result.content.type
            SpaceKey = $result.content.space.key
            Url      = $result.url
            Excerpt  = $result.excerpt
        }
    }

    return $results
}
