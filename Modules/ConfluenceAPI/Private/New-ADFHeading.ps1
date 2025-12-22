function New-ADFHeading {
    <#
    .SYNOPSIS
        Creates an ADF heading node.
    .DESCRIPTION
        Creates an Atlassian Document Format (ADF) heading node with
        specified level (1-6) and text content. The heading follows
        ADF v1 specification with proper nesting: heading -> text node.
    .PARAMETER Level
        Heading level from 1 (largest) to 6 (smallest).
        Valid values: 1, 2, 3, 4, 5, 6
    .PARAMETER Text
        The heading text content.
    .OUTPUTS
        [hashtable] - ADF heading node structure ready to be added to an ADF document
    .EXAMPLE
        $heading = New-ADFHeading -Level 1 -Text 'User Inventory'

        Creates a level 1 heading with text "User Inventory".
    .EXAMPLE
        $heading = New-ADFHeading -Level 2 -Text 'Active Users'

        Creates a level 2 subheading.
    .EXAMPLE
        New-ADFHeading -Level 3 -Text 'Summary' | Add-ADFContent -Document $doc

        Creates heading and adds it to a document via pipeline.
    .NOTES
        This is a private function used internally by the ConfluenceAPI module.
        Use with Add-ADFContent to add headings to ADF documents.
    .LINK
        New-ADFDocument
    .LINK
        New-ADFParagraph
    .LINK
        Add-ADFContent
    .LINK
        ConvertTo-ADF
    .LINK
        https://developer.atlassian.com/cloud/jira/platform/apis/document/nodes/heading/
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Creates in-memory data structure only, no system state changes')]
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [ValidateRange(1, 6)]
        [int]$Level,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
            if ($_.Trim().Length -eq 0) {
                throw 'Text cannot be whitespace-only'
            }
            $true
        })]
        [string]$Text
    )

    Write-Verbose "Creating ADF heading level $Level with text: '$Text'"

    return @{
        type    = 'heading'
        attrs   = @{ level = $Level }
        content = @(
            @{
                type = 'text'
                text = $Text
            }
        )
    }
}
