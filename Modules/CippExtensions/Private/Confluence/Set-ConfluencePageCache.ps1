function Set-ConfluencePageCache {
    <#
    .SYNOPSIS
        Stores page hash in CacheConfluencePages table.
    .DESCRIPTION
        Creates or updates cache entry for a Confluence page.
        Used after successful page updates to store the new content hash.

        Cache entries include SpaceKey for cleanup operations and
        PageTitle for logging/debugging purposes.
    .PARAMETER PageId
        The Confluence page ID (stored as RowKey).
    .PARAMETER SpaceKey
        The Confluence space key (stored for cleanup filtering).
    .PARAMETER PageTitle
        The page title (stored for logging/debugging).
    .PARAMETER Hash
        The SHA1 hash of the page content.
    .EXAMPLE
        Set-ConfluencePageCache -PageId '12345' -SpaceKey 'CONTOSO' -PageTitle 'User Inventory' -Hash 'ABC123...'

        Stores the cache entry after a successful page update.
    .NOTES
        Part of Story 10.4 - Cache Integration.
        Uses CacheConfluencePages Azure Table Storage table.
        Uses -Force to upsert (create or update).
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$PageId,

        [Parameter(Mandatory)]
        [string]$SpaceKey,

        [Parameter(Mandatory)]
        [string]$PageTitle,

        [Parameter(Mandatory)]
        [string]$Hash
    )

    Write-Verbose "Updating cache for page '$PageId' (SpaceKey: $SpaceKey)"

    # Get table reference outside ShouldProcess (read operation)
    $Table = Get-CIPPTable -TableName 'CacheConfluencePages'

    if ($PSCmdlet.ShouldProcess("Page '$PageId'", 'Update cache entry')) {
        $Entity = @{
            PartitionKey = 'ConfluencePage'
            RowKey       = $PageId
            SpaceKey     = $SpaceKey
            PageTitle    = $PageTitle
            Hash         = $Hash
            LastUpdated  = (Get-Date).ToString('o')
        }

        Add-CIPPAzDataTableEntity @Table -Entity $Entity -Force
        Write-Verbose "Cache updated for page '$PageId'"
    }
}
