function Add-ADFContent {
    <#
    .SYNOPSIS
        Adds content nodes to an ADF document.
    .DESCRIPTION
        Appends one or more content nodes to an ADF document's content array.
        Supports adding both single nodes and arrays of nodes.

        The function modifies the document's content array IN PLACE and returns
        the modified document for method chaining. Since PowerShell hashtables
        are reference types, the original document variable will also reflect
        the changes after calling this function.
    .PARAMETER Document
        The ADF document hashtable to add content to.
        Must have a 'content' property that is an array.
    .PARAMETER Content
        The content node(s) to add. Can be a single hashtable or an array of hashtables.
        Each node should follow ADF block node structure (e.g., paragraph, heading, table).
    .OUTPUTS
        [hashtable] - The modified ADF document with content appended
    .EXAMPLE
        $doc = New-ADFDocument
        $paragraph = @{ type = 'paragraph'; content = @(@{ type = 'text'; text = 'Hello' }) }
        $doc = Add-ADFContent -Document $doc -Content $paragraph

        Adds a single paragraph node to the document.
    .EXAMPLE
        $doc = New-ADFDocument
        $nodes = @(
            @{ type = 'heading'; attrs = @{ level = 1 }; content = @(@{ type = 'text'; text = 'Title' }) },
            @{ type = 'paragraph'; content = @(@{ type = 'text'; text = 'Body' }) }
        )
        $doc = Add-ADFContent -Document $doc -Content $nodes

        Adds multiple nodes to the document.
    .NOTES
        This is a private function used internally by the ConfluenceAPI module.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Document,

        [Parameter(Mandatory)]
        $Content
    )

    Write-Verbose "Adding content to ADF document"

    # Handle both single node and array of nodes
    if ($Content -is [array]) {
        Write-Verbose "Adding $($Content.Count) content node(s)"
        foreach ($node in $Content) {
            $Document.content += $node
        }
    }
    else {
        Write-Verbose "Adding single content node"
        $Document.content += $Content
    }

    return $Document
}
