function Find-ConfluencePageByTitle {
    <#
    .SYNOPSIS
        Finds a Confluence page by title in a space, with fallback methods.
    .DESCRIPTION
        Attempts to find an existing page using multiple methods:
        1. CQL search (fastest, but may have indexing delays)
        2. Direct space pages listing with title filter (reliable fallback)

        This handles the known issue where Confluence search doesn't immediately
        index newly created pages, causing "page already exists" errors on create
        when the search returns no results.
    .PARAMETER SpaceKey
        The Confluence space key (e.g., 'CONTOSO').
    .PARAMETER Title
        The exact title of the page to find.
    .OUTPUTS
        [PSCustomObject] - Page object with Id, Title properties, or $null if not found.
    .EXAMPLE
        $page = Find-ConfluencePageByTitle -SpaceKey 'CONTOSO' -Title 'User Inventory'
        if ($page) { Set-ConfluencePage -PageId $page.Id -Body $content }
    .NOTES
        Part of the ConfluenceAPI module. Used internally by Sync-* functions.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$SpaceKey,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Title
    )

    Write-Verbose "Finding page '$Title' in space '$SpaceKey'"

    # Method 1: Try CQL search first (fastest when index is up to date)
    $escapedSpaceKey = $SpaceKey -replace "'", "''"
    $escapedTitle = $Title -replace "'", "''"
    $cql = "space = '$escapedSpaceKey' AND title = '$escapedTitle' AND type = page"

    try {
        Write-Verbose "Attempting CQL search: $cql"
        $searchResults = Search-Confluence -CQL $cql
        $page = $searchResults | Select-Object -First 1
        if ($page) {
            Write-Verbose "Found page via CQL search (ID: $($page.Id))"
            return $page
        }
        Write-Verbose "CQL search returned no results"
    }
    catch {
        Write-Verbose "CQL search failed: $($_.Exception.Message)"
    }

    # Method 2: Fallback to listing all pages in space and filtering by title
    # This is slower but more reliable when search index is stale
    try {
        Write-Verbose "Falling back to space pages listing..."

        # Get space to get its ID
        $space = Get-ConfluenceSpace -SpaceKey $SpaceKey -ErrorAction Stop
        if (-not $space) {
            Write-Verbose "Space '$SpaceKey' not found"
            return $null
        }

        # Get all pages in the space
        $allPages = Get-ConfluencePage -SpaceId $space.Id -ErrorAction Stop

        # Find page with matching title (case-insensitive)
        $page = $allPages | Where-Object { $_.Title -eq $Title } | Select-Object -First 1

        if ($page) {
            Write-Verbose "Found page via space listing (ID: $($page.Id))"
            return $page
        }

        Write-Verbose "Page not found via space listing"
    }
    catch {
        Write-Verbose "Space pages fallback failed: $($_.Exception.Message)"
    }

    # Page not found by any method
    Write-Verbose "Page '$Title' not found in space '$SpaceKey'"
    return $null
}
