function Get-ConfluenceDataCache {
    <#
    .SYNOPSIS
        Retrieves cached data hash from CacheConfluenceDataHash table.
    .DESCRIPTION
        Returns cached hash for a data type in a Confluence space to enable
        data-level change detection. Returns $null if no cache entry exists.

        Used by the orchestrator to skip Sync-Confluence* calls entirely
        when source M365 data has not changed.
    .PARAMETER SpaceKey
        The Confluence space key (used as PartitionKey).
    .PARAMETER DataType
        The data type identifier (e.g., 'UserInventory', 'EndpointInventory').
    .OUTPUTS
        [PSCustomObject] with SpaceKey, DataType, Hash, LastUpdated properties
        or $null if no cache entry exists.
    .EXAMPLE
        $cached = Get-ConfluenceDataCache -SpaceKey 'CONTOSO' -DataType 'UserInventory'
        if ($cached -and $cached.Hash -eq $newHash) {
            Write-Verbose "Data unchanged, skipping sync"
        }
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$SpaceKey,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DataType
    )

    Write-Verbose "Checking data cache for '$DataType' in space '$SpaceKey'"
    $Table = Get-CIPPTable -TableName 'CacheConfluenceDataHash'

    $escapedSpaceKey = $SpaceKey -replace "'", "''"
    $escapedDataType = $DataType -replace "'", "''"
    $Entity = Get-CIPPAzDataTableEntity @Table `
        -Filter "PartitionKey eq '$escapedSpaceKey' and RowKey eq '$escapedDataType'"

    if ($Entity) {
        Write-Verbose "Data cache hit for '$DataType' in space '$SpaceKey'"
        return [PSCustomObject]@{
            SpaceKey    = $Entity.PartitionKey
            DataType    = $Entity.RowKey
            Hash        = $Entity.Hash
            LastUpdated = $Entity.LastUpdated
        }
    }

    Write-Verbose "Data cache miss for '$DataType' in space '$SpaceKey'"
    return $null
}
