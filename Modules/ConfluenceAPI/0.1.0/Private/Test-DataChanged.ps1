function Test-DataChanged {
    <#
    .SYNOPSIS
        Determines if data has changed since last sync.
    .DESCRIPTION
        Computes hash of current data and compares to stored state.
        Returns change status for incremental sync decision.
    .PARAMETER TenantId
        The tenant identifier for state lookup.
    .PARAMETER DataType
        The data type (e.g., 'UserInventory', 'EndpointInventory').
    .PARAMETER InputData
        The data to check for changes.
    .OUTPUTS
        [PSCustomObject] with HasChanged, CurrentHash, PreviousHash, IsFirstSync properties.
    .EXAMPLE
        $result = Test-DataChanged -TenantId 'abc-123' -DataType 'UserInventory' -InputData $users
        if ($result.HasChanged) { # perform sync }
    .NOTES
        Part of Story 8.4 - Incremental Sync Support.
        FR38: System can skip sync for unchanged data.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$TenantId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DataType,

        [Parameter()]
        [object]$InputData
    )

    # Compute current hash
    Write-Verbose "Computing hash for $DataType"
    $currentHashResult = Get-DataHash -InputData $InputData
    $currentHash = $currentHashResult.Hash
    $shortCurrent = $currentHashResult.ShortHash

    # Get previous state
    $stateKey = Get-SyncStateKey -TenantId $TenantId -DataType $DataType

    # Initialize cache if not exists
    if (-not $script:SyncStateCache) {
        $script:SyncStateCache = @{}
    }

    $previousState = $script:SyncStateCache[$stateKey]

    if (-not $previousState) {
        Write-Verbose "No previous state for $DataType, performing full sync"
        return [PSCustomObject]@{
            HasChanged   = $true
            CurrentHash  = $currentHash
            PreviousHash = $null
            IsFirstSync  = $true
        }
    }

    $previousHash = $previousState.Hash
    $shortPrevious = if ($previousHash -and $previousHash.Length -ge 16) {
        $previousHash.Substring(0, 16)
    }
    else {
        $previousHash
    }
    $hasChanged = $currentHash -ne $previousHash

    Write-Verbose "Hash: $shortCurrent (previous: $shortPrevious)"

    if ($hasChanged) {
        Write-Verbose "Data has changed for $DataType"
    }
    else {
        Write-Verbose "Data unchanged for $DataType"
    }

    [PSCustomObject]@{
        HasChanged   = $hasChanged
        CurrentHash  = $currentHash
        PreviousHash = $previousHash
        IsFirstSync  = $false
    }
}
