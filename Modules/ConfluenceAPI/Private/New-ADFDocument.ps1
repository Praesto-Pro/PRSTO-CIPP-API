function New-ADFDocument {
    <#
    .SYNOPSIS
        Creates a new ADF document root structure.
    .DESCRIPTION
        Creates a valid Atlassian Document Format (ADF) v1 document root structure.
        The returned hashtable can be modified and then converted to JSON for use
        with the Confluence API.

        ADF documents have three required properties:
        - version: Integer 1 (not string)
        - type: String "doc"
        - content: Array of block nodes (initially empty)
    .OUTPUTS
        [hashtable] - ADF document structure with version, type, and content properties
    .EXAMPLE
        $doc = New-ADFDocument
        # Returns: @{ version = 1; type = "doc"; content = @() }

        Add content nodes and convert to JSON:
        $doc.content += @{ type = "paragraph"; content = @(@{ type = "text"; text = "Hello" }) }
        $json = $doc | ConvertTo-Json -Depth 20
    .NOTES
        This is a private function used internally by the ConfluenceAPI module.
        Use ConvertTo-ADF for the public-facing ADF generation.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    Write-Verbose "Creating new ADF document structure"

    return @{
        version = [int]1
        type    = "doc"
        content = @()
    }
}
