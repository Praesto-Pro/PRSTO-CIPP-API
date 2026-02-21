function Get-ConfluenceDataHash {
    <#
    .SYNOPSIS
        Computes a SHA256 hash of input data for change detection.
    .DESCRIPTION
        Converts input data to JSON and computes SHA256 hash.
        Used by the orchestrator to detect if source M365 data has changed
        since the last sync, avoiding unnecessary Confluence API calls.
    .PARAMETER InputData
        The data to hash (typically an array of objects from Graph API).
    .OUTPUTS
        [string] - The full SHA256 hex hash string.
    .EXAMPLE
        $hash = Get-ConfluenceDataHash -InputData $users
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [object]$InputData
    )

    if ($null -eq $InputData -or @($InputData).Count -eq 0) {
        $dataString = '[]'
    }
    else {
        $dataString = $InputData | ConvertTo-Json -Depth 10 -Compress
    }

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($dataString)
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hashBytes = $sha256.ComputeHash($bytes)
        [BitConverter]::ToString($hashBytes) -replace '-', ''
    }
    finally {
        $sha256.Dispose()
    }
}
