function Get-ConfluencePageCache {
    <#
    .SYNOPSIS
        Retrieves cached page hash from CacheConfluencePages table.
    .DESCRIPTION
        Returns cached hash for a Confluence page to enable change detection.
        Returns $null if no cache entry exists.

        Used by Sync-Confluence* functions to avoid redundant API calls when
        page content has not changed.
    .PARAMETER PageId
        The Confluence page ID to look up in the cache.
    .OUTPUTS
        [PSCustomObject] with PageId, SpaceKey, PageTitle, Hash, LastUpdated properties
        or $null if no cache entry exists.
    .EXAMPLE
        $cached = Get-ConfluencePageCache -PageId '12345'
        if ($cached -and $cached.Hash -eq $newHash) {
            Write-Verbose "Page unchanged, skipping update"
        }
    .NOTES
        Part of Story 10.4 - Cache Integration.
        Uses CacheConfluencePages Azure Table Storage table.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('^[0-9]+$', ErrorMessage = 'PageId must be numeric (Confluence Cloud page IDs are numeric only)')]
        [string]$PageId
    )

    Write-Verbose "Checking cache for page '$PageId'"
    $Table = Get-CIPPTable -TableName 'CacheConfluencePages'

    $escapedPageId = $PageId -replace "'", "''"
    $Entity = Get-CIPPAzDataTableEntity @Table `
        -Filter "PartitionKey eq 'ConfluencePage' and RowKey eq '$escapedPageId'"

    if ($Entity) {
        Write-Verbose "Cache hit for page '$PageId': Hash = $($Entity.Hash)"
        return [PSCustomObject]@{
            PageId      = $Entity.RowKey
            SpaceKey    = $Entity.SpaceKey
            PageTitle   = $Entity.PageTitle
            Hash        = $Entity.Hash
            LastUpdated = $Entity.LastUpdated
        }
    }

    Write-Verbose "Cache miss for page '$PageId'"
    return $null
}
