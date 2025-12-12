function ConvertTo-ADF {
    <#
    .SYNOPSIS
        Converts PowerShell data to valid ADF JSON.
    .DESCRIPTION
        Converts PowerShell data structures into valid Atlassian Document Format (ADF)
        JSON that can be used directly with the Confluence API.

        Handles multiple input types:
        - null/empty: Returns empty ADF document JSON
        - ADF document hashtable: Converts directly to JSON
        - Array of content nodes: Wraps in ADF document structure
        - Single content node: Wraps in array, then in ADF document

        Uses -Depth 20 for ConvertTo-Json to handle deeply nested ADF structures.
    .PARAMETER InputObject
        The data to convert to ADF JSON. Can be:
        - $null or empty: Creates empty ADF document
        - Hashtable with version/type/content: Converts existing ADF document
        - Array of block nodes: Wraps nodes in ADF document
        - Single block node hashtable: Wraps in document with single content
    .OUTPUTS
        [string] - Valid ADF JSON string ready for Confluence API
    .EXAMPLE
        $json = ConvertTo-ADF -InputObject $null
        # Returns: {"version":1,"type":"doc","content":[]}
    .EXAMPLE
        $doc = New-ADFDocument
        $doc = Add-ADFContent -Document $doc -Content @{ type = 'paragraph'; content = @(@{ type = 'text'; text = 'Hello' }) }
        $json = ConvertTo-ADF -InputObject $doc
        # Returns valid ADF JSON string
    .EXAMPLE
        $nodes = @(
            @{ type = 'heading'; attrs = @{ level = 1 }; content = @(@{ type = 'text'; text = 'Title' }) },
            @{ type = 'paragraph'; content = @(@{ type = 'text'; text = 'Body' }) }
        )
        $json = ConvertTo-ADF -InputObject $nodes
        # Wraps nodes in ADF document structure and returns JSON
    .NOTES
        This is a private function used internally by the ConfluenceAPI module.
        The output can be used directly with New-ConfluencePage -Body parameter.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        $InputObject
    )

    Write-Verbose "Converting input to ADF JSON"

    # Handle null or empty input - return empty ADF document
    if ($null -eq $InputObject) {
        Write-Verbose "Input is null, creating empty ADF document"
        $doc = New-ADFDocument
        return $doc | ConvertTo-Json -Depth 20 -Compress
    }

    # Handle empty hashtable
    if ($InputObject -is [hashtable] -and $InputObject.Count -eq 0) {
        Write-Verbose "Input is empty hashtable, creating empty ADF document"
        $doc = New-ADFDocument
        return $doc | ConvertTo-Json -Depth 20 -Compress
    }

    # Handle empty array
    if ($InputObject -is [array] -and $InputObject.Count -eq 0) {
        Write-Verbose "Input is empty array, creating empty ADF document"
        $doc = New-ADFDocument
        return $doc | ConvertTo-Json -Depth 20 -Compress
    }

    # Check if input is already a complete ADF document (has version, type, content)
    if ($InputObject -is [hashtable] -and
        $InputObject.ContainsKey('version') -and
        $InputObject.ContainsKey('type') -and
        $InputObject.ContainsKey('content') -and
        $InputObject.type -eq 'doc') {
        Write-Verbose "Input is existing ADF document, converting to JSON"
        return $InputObject | ConvertTo-Json -Depth 20 -Compress
    }

    # Check if input is an array of content nodes
    if ($InputObject -is [array]) {
        Write-Verbose "Input is array of $($InputObject.Count) content node(s), wrapping in document"
        # Validate that array items have 'type' property (required by ADF spec)
        foreach ($node in $InputObject) {
            if ($node -is [hashtable] -and -not $node.ContainsKey('type')) {
                Write-Warning "Content node missing required 'type' property - ADF may be invalid"
            }
        }
        $doc = New-ADFDocument
        $doc = Add-ADFContent -Document $doc -Content $InputObject
        return $doc | ConvertTo-Json -Depth 20 -Compress
    }

    # Input is a single content node - wrap it in document
    if ($InputObject -is [hashtable]) {
        Write-Verbose "Input is single content node, wrapping in document"
        # Validate that node has 'type' property (required by ADF spec)
        if (-not $InputObject.ContainsKey('type')) {
            Write-Warning "Content node missing required 'type' property - ADF may be invalid"
        }
        $doc = New-ADFDocument
        $doc = Add-ADFContent -Document $doc -Content $InputObject
        return $doc | ConvertTo-Json -Depth 20 -Compress
    }

    # Fallback for unexpected input types - create empty document
    Write-Verbose "Unexpected input type '$($InputObject.GetType().Name)', creating empty ADF document"
    $doc = New-ADFDocument
    return $doc | ConvertTo-Json -Depth 20 -Compress
}
