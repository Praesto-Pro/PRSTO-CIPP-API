function New-ADFParagraph {
    <#
    .SYNOPSIS
        Creates an ADF paragraph node.
    .DESCRIPTION
        Creates an Atlassian Document Format (ADF) paragraph node with
        text content and optional formatting marks (bold, italic).

        The paragraph follows ADF v1 specification with proper nesting:
        paragraph -> text node(s) with optional marks.

        Supports two modes:
        - Simple text: Use -Text with optional -Bold/-Italic switches
        - Complex content: Use -Content with pre-built text nodes
    .PARAMETER Text
        Simple text content for the paragraph.
    .PARAMETER Bold
        Apply bold formatting (strong mark) to the text.
    .PARAMETER Italic
        Apply italic formatting (em mark) to the text.
    .PARAMETER Content
        Array of pre-built text node hashtables for complex paragraphs
        with mixed formatting.
    .OUTPUTS
        [hashtable] - ADF paragraph node structure ready to be added to an ADF document
    .EXAMPLE
        $para = New-ADFParagraph -Text 'Last updated: 2025-12-12'

        Creates a simple paragraph with plain text.
    .EXAMPLE
        $para = New-ADFParagraph -Text 'Important!' -Bold

        Creates a paragraph with bold text.
    .EXAMPLE
        $para = New-ADFParagraph -Text 'Note: See documentation' -Italic

        Creates a paragraph with italic text.
    .EXAMPLE
        $para = New-ADFParagraph -Text 'Critical warning!' -Bold -Italic

        Creates a paragraph with bold and italic text.
    .EXAMPLE
        $textNodes = @(
            (New-ADFTextNode -Text 'Normal '),
            (New-ADFTextNode -Text 'bold' -Bold),
            (New-ADFTextNode -Text ' text')
        )
        $para = New-ADFParagraph -Content $textNodes

        Creates a paragraph with mixed formatting using New-ADFTextNode helper.
    .NOTES
        This is a private function used internally by the ConfluenceAPI module.
        Use with Add-ADFContent to add paragraphs to ADF documents.
    .LINK
        New-ADFDocument
    .LINK
        New-ADFHeading
    .LINK
        New-ADFTextNode
    .LINK
        Add-ADFContent
    .LINK
        ConvertTo-ADF
    .LINK
        https://developer.atlassian.com/cloud/jira/platform/apis/document/nodes/paragraph/
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Creates in-memory data structure only, no system state changes')]
    [CmdletBinding(DefaultParameterSetName = 'SimpleText')]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'SimpleText')]
        [AllowEmptyString()]
        [string]$Text,

        [Parameter(ParameterSetName = 'SimpleText')]
        [switch]$Bold,

        [Parameter(ParameterSetName = 'SimpleText')]
        [switch]$Italic,

        [Parameter(Mandatory, ParameterSetName = 'Content')]
        [hashtable[]]$Content
    )

    # Handle Content parameter set (pre-built text nodes)
    if ($PSCmdlet.ParameterSetName -eq 'Content') {
        Write-Verbose "Creating ADF paragraph with $($Content.Count) pre-built text node(s)"
        return @{
            type    = 'paragraph'
            content = $Content
        }
    }

    # Handle SimpleText parameter set
    Write-Verbose "Creating ADF paragraph with text: '$Text'"

    # Build text node
    $textNode = @{
        type = 'text'
        text = $Text
    }

    # Build marks array if formatting requested
    $marks = @()
    if ($Bold) {
        Write-Verbose "Adding bold (strong) mark"
        $marks += @{ type = 'strong' }
    }
    if ($Italic) {
        Write-Verbose "Adding italic (em) mark"
        $marks += @{ type = 'em' }
    }

    # Add marks to text node if any exist
    if ($marks.Count -gt 0) {
        $textNode.marks = $marks
    }

    return @{
        type    = 'paragraph'
        content = @($textNode)
    }
}

function New-ADFTextNode {
    <#
    .SYNOPSIS
        Creates an ADF text node with optional marks.
    .DESCRIPTION
        Helper function that creates an Atlassian Document Format (ADF) text node
        with optional formatting marks. Used for building complex paragraphs with
        mixed formatting.
    .PARAMETER Text
        The text content.
    .PARAMETER Bold
        Apply bold formatting (strong mark).
    .PARAMETER Italic
        Apply italic formatting (em mark).
    .OUTPUTS
        [hashtable] - ADF text node structure
    .EXAMPLE
        $node = New-ADFTextNode -Text 'Hello'

        Creates a plain text node.
    .EXAMPLE
        $node = New-ADFTextNode -Text 'Important' -Bold

        Creates a bold text node.
    .EXAMPLE
        $nodes = @(
            New-ADFTextNode -Text 'Normal '
            New-ADFTextNode -Text 'bold' -Bold
            New-ADFTextNode -Text ' and '
            New-ADFTextNode -Text 'italic' -Italic
        )
        $para = New-ADFParagraph -Content $nodes

        Creates mixed formatting paragraph.
    .NOTES
        This is a private helper function used internally by the ConfluenceAPI module.
    .LINK
        New-ADFParagraph
    .LINK
        https://developer.atlassian.com/cloud/jira/platform/apis/document/marks/
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Creates in-memory data structure only, no system state changes')]
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text,

        [Parameter()]
        [switch]$Bold,

        [Parameter()]
        [switch]$Italic
    )

    Write-Verbose "Creating ADF text node: '$Text'"

    $textNode = @{
        type = 'text'
        text = $Text
    }

    $marks = @()
    if ($Bold) {
        $marks += @{ type = 'strong' }
    }
    if ($Italic) {
        $marks += @{ type = 'em' }
    }

    if ($marks.Count -gt 0) {
        $textNode.marks = $marks
    }

    return $textNode
}
