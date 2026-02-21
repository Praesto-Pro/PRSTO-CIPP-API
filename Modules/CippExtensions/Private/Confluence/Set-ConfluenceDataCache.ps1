function Set-ConfluenceDataCache {
    <#
    .SYNOPSIS
        Stores data hash in CacheConfluenceDataHash table.
    .DESCRIPTION
        Creates or updates cache entry for a data type in a Confluence space.
        Used after successful sync to store the current data hash for
        future change detection.
    .PARAMETER SpaceKey
        The Confluence space key (stored as PartitionKey).
    .PARAMETER DataType
        The data type identifier (stored as RowKey).
    .PARAMETER Hash
        The SHA256 hash of the source data.
    .EXAMPLE
        Set-ConfluenceDataCache -SpaceKey 'CONTOSO' -DataType 'UserInventory' -Hash 'ABC123...'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$SpaceKey,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DataType,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Hash
    )

    Write-Verbose "Updating data cache for '$DataType' in space '$SpaceKey'"
    $Table = Get-CIPPTable -TableName 'CacheConfluenceDataHash'

    $Entity = @{
        PartitionKey = $SpaceKey
        RowKey       = $DataType
        Hash         = $Hash
        LastUpdated  = (Get-Date).ToString('o')
    }

    Add-CIPPAzDataTableEntity @Table -Entity $Entity -Force
    Write-Verbose "Data cache updated for '$DataType' in space '$SpaceKey'"
}
