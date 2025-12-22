function Get-ConfluenceContentHash {
    <#
    .SYNOPSIS
        Generates SHA1 hash of Confluence page content.
    .DESCRIPTION
        Creates consistent hash for change detection.
        Accepts ADF content as hashtable or JSON string.

        Uses Get-StringHash if available (CIPP framework function),
        otherwise falls back to inline SHA1 implementation.
    .PARAMETER Content
        The ADF content to hash. Can be a hashtable, ordered dictionary,
        or JSON string.
    .OUTPUTS
        [string] - 40-character SHA1 hex string (uppercase)
    .EXAMPLE
        $hash = Get-ConfluenceContentHash -Content $adfDocument

        Generates hash for an ADF document hashtable.
    .EXAMPLE
        $hash = Get-ConfluenceContentHash -Content '{"type":"doc","content":[]}'

        Generates hash for a JSON string.
    .NOTES
        Part of Story 10.4 - Cache Integration.

        Important: Always use -Compress when converting to JSON to ensure
        consistent hashing regardless of whitespace formatting.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        $Content
    )

    # Convert to consistent JSON string if hashtable
    if ($Content -is [hashtable] -or $Content -is [System.Collections.Specialized.OrderedDictionary]) {
        $JsonContent = $Content | ConvertTo-Json -Depth 20 -Compress
    } else {
        $JsonContent = [string]$Content
    }

    # Inline SHA1 implementation (always used for consistency)
    $Bytes = [System.Text.Encoding]::UTF8.GetBytes($JsonContent)
    $SHA1 = [System.Security.Cryptography.SHA1]::Create()
    $HashBytes = $SHA1.ComputeHash($Bytes)
    $Hash = [System.BitConverter]::ToString($HashBytes) -replace '-', ''

    Write-Verbose "Generated hash: $Hash (length: $($JsonContent.Length) chars)"
    return $Hash
}
