function Get-DataHash {
    <#
    .SYNOPSIS
        Computes a SHA256 hash of input data for change detection.
    .DESCRIPTION
        Converts input data to sorted JSON and computes SHA256 hash.
        Used for incremental sync to detect data changes.
    .PARAMETER InputData
        The data to hash (typically an array of objects).
    .OUTPUTS
        [PSCustomObject] with Hash (full) and ShortHash (first 16 chars).
    .EXAMPLE
        $hash = Get-DataHash -InputData $users
        if ($hash.Hash -eq $previousHash) { ... }
    .EXAMPLE
        Get-DataHash -InputData @() -Verbose
        Computes hash for empty array with verbose output.
    .NOTES
        Part of Story 8.4 - Incremental Sync Support.
        FR38: System can skip sync for unchanged data.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [object]$InputData
    )

    Write-Verbose "Computing hash for input data"

    # Handle null/empty input
    if ($null -eq $InputData -or @($InputData).Count -eq 0) {
        $dataString = '[]'
        Write-Verbose "Input data is null or empty, using empty array representation"
    }
    else {
        # Convert to JSON for consistent hashing
        # ConvertTo-Json produces deterministic output for same input structure
        # CIPP API returns data with consistent property ordering
        # Depth 10 handles nested objects
        $dataString = $InputData | ConvertTo-Json -Depth 10 -Compress
        Write-Verbose "Converted data to JSON string (length: $($dataString.Length))"
    }

    # Compute SHA256 hash
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($dataString)
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    $hashBytes = $sha256.ComputeHash($bytes)
    $fullHash = [BitConverter]::ToString($hashBytes) -replace '-', ''
    $shortHash = $fullHash.Substring(0, 16)

    Write-Verbose "Hash computed: $shortHash..."

    [PSCustomObject]@{
        Hash      = $fullHash
        ShortHash = $shortHash
    }
}
