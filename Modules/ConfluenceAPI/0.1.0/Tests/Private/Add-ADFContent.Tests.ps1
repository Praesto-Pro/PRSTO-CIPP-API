# Tests for Add-ADFContent private function
# Pester 3.4.0+ syntax for Windows PowerShell 5.1 compatibility

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$privateDir = "$here\..\..\Private"

Describe 'Add-ADFContent' {
    BeforeAll {
        # Import both functions needed for testing
        . "$privateDir\New-ADFDocument.ps1"
        . "$privateDir\Add-ADFContent.ps1"
    }

    Context 'When adding a single content node' {
        It 'Appends single node to document content array' {
            $doc = New-ADFDocument
            $node = @{ type = 'paragraph'; content = @(@{ type = 'text'; text = 'Hello' }) }

            $result = Add-ADFContent -Document $doc -Content $node

            $result.content.Count | Should Be 1
            $result.content[0].type | Should Be 'paragraph'
        }

        It 'Returns the modified document' {
            $doc = New-ADFDocument
            $node = @{ type = 'heading'; attrs = @{ level = 1 }; content = @(@{ type = 'text'; text = 'Title' }) }

            $result = Add-ADFContent -Document $doc -Content $node

            $result | Should Not Be $null
            $result.version | Should Be 1
            $result.type | Should Be 'doc'
        }
    }

    Context 'When adding an array of content nodes' {
        It 'Appends all nodes to document content array' {
            $doc = New-ADFDocument
            $nodes = @(
                @{ type = 'heading'; attrs = @{ level = 1 }; content = @(@{ type = 'text'; text = 'Title' }) },
                @{ type = 'paragraph'; content = @(@{ type = 'text'; text = 'Body text' }) }
            )

            $result = Add-ADFContent -Document $doc -Content $nodes

            $result.content.Count | Should Be 2
            $result.content[0].type | Should Be 'heading'
            $result.content[1].type | Should Be 'paragraph'
        }

        It 'Preserves existing content when adding more' {
            $doc = New-ADFDocument
            $firstNode = @{ type = 'paragraph'; content = @(@{ type = 'text'; text = 'First' }) }
            $doc = Add-ADFContent -Document $doc -Content $firstNode

            $secondNode = @{ type = 'paragraph'; content = @(@{ type = 'text'; text = 'Second' }) }
            $result = Add-ADFContent -Document $doc -Content $secondNode

            $result.content.Count | Should Be 2
            $result.content[0].content[0].text | Should Be 'First'
            $result.content[1].content[0].text | Should Be 'Second'
        }
    }

    Context 'When serializing result to JSON' {
        It 'Produces valid ADF JSON after adding content' {
            $doc = New-ADFDocument
            $node = @{ type = 'paragraph'; content = @(@{ type = 'text'; text = 'Test' }) }
            $result = Add-ADFContent -Document $doc -Content $node

            $json = $result | ConvertTo-Json -Depth 20
            $parsed = $json | ConvertFrom-Json

            $parsed.version | Should Be 1
            $parsed.type | Should Be 'doc'
            $parsed.content.Count | Should Be 1
            $parsed.content[0].type | Should Be 'paragraph'
        }
    }
}
