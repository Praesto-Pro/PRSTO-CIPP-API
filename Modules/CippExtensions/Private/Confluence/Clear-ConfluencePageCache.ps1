function Clear-ConfluencePageCache {
    <#
    .SYNOPSIS
        Removes cache entries from CacheConfluencePages table.
    .DESCRIPTION
        Clears cache for specific space or all entries.
        Used when tenant mapping is removed to clean up related cache entries.
    .PARAMETER SpaceKey
        Optional space key to filter removal. If not specified, removes all entries.
    .EXAMPLE
        Clear-ConfluencePageCache -SpaceKey 'CONTOSO'

        Removes all cache entries for the CONTOSO space.
    .EXAMPLE
        Clear-ConfluencePageCache

        Removes all cache entries (use with caution).
    .NOTES
        Part of Story 10.4 - Cache Integration.
        Uses CacheConfluencePages Azure Table Storage table.
        Supports -WhatIf for preview mode.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [string]$SpaceKey
    )

    $SpaceInfo = if ($SpaceKey) { " for space '$SpaceKey'" } else { '' }
    Write-Verbose "Clearing cache$SpaceInfo"

    $Table = Get-CIPPTable -TableName 'CacheConfluencePages'

    if ($SpaceKey) {
        $Filter = "PartitionKey eq 'ConfluencePage' and SpaceKey eq '$SpaceKey'"
    } else {
        $Filter = "PartitionKey eq 'ConfluencePage'"
    }

    $Entities = Get-CIPPAzDataTableEntity @Table -Filter $Filter

    if (-not $Entities -or $Entities.Count -eq 0) {
        Write-Verbose "No cache entries found$SpaceInfo"
        return
    }

    $EntityCount = if ($Entities -is [array]) { $Entities.Count } else { 1 }
    Write-Verbose "Found $EntityCount cache entries to remove"

    if ($PSCmdlet.ShouldProcess("$EntityCount cache entries$SpaceInfo", 'Remove')) {
        foreach ($Entity in $Entities) {
            # Note: -Force used for batch operations without additional confirmations
            Remove-AzDataTableEntity @Table -Entity $Entity -Force
        }
        Write-Verbose "Removed $EntityCount cache entries$SpaceInfo"
    }
}
