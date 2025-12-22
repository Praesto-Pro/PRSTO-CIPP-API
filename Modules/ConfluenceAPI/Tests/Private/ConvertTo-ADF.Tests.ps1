# Tests for ConvertTo-ADF private function
# Pester 3.4.0+ syntax for Windows PowerShell 5.1 compatibility

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$privateDir = "$here\..\..\Private"

Describe 'ConvertTo-ADF' {
    BeforeAll {
        # Import all required functions
        . "$privateDir\New-ADFDocument.ps1"
        . "$privateDir\Add-ADFContent.ps1"
        . "$privateDir\ConvertTo-ADF.ps1"
    }

    Context 'When input is null' {
        It 'Returns valid empty ADF document JSON' {
            $result = ConvertTo-ADF -InputObject $null

            $result | Should Not Be $null
            $result | Should BeOfType [string]

            $parsed = $result | ConvertFrom-Json
            $parsed.version | Should Be 1
            $parsed.type | Should Be 'doc'
            $parsed.content.Count | Should Be 0
        }
    }

    Context 'When input is empty' {
        It 'Returns valid empty ADF document JSON for empty hashtable' {
            $result = ConvertTo-ADF -InputObject @{}

            $parsed = $result | ConvertFrom-Json
            $parsed.version | Should Be 1
            $parsed.type | Should Be 'doc'
        }

        It 'Returns valid empty ADF document JSON for empty array' {
            $result = ConvertTo-ADF -InputObject @()

            $parsed = $result | ConvertFrom-Json
            $parsed.version | Should Be 1
            $parsed.type | Should Be 'doc'
            $parsed.content.Count | Should Be 0
        }
    }

    Context 'When input is already an ADF document' {
        It 'Converts existing ADF document to JSON' {
            $doc = New-ADFDocument
            $doc.content += @{ type = 'paragraph'; content = @(@{ type = 'text'; text = 'Test' }) }

            $result = ConvertTo-ADF -InputObject $doc

            $result | Should BeOfType [string]
            $parsed = $result | ConvertFrom-Json
            $parsed.version | Should Be 1
            $parsed.type | Should Be 'doc'
            $parsed.content.Count | Should Be 1
        }
    }

    Context 'When input is array of content nodes' {
        It 'Wraps content nodes in document structure' {
            $nodes = @(
                @{ type = 'heading'; attrs = @{ level = 1 }; content = @(@{ type = 'text'; text = 'Title' }) },
                @{ type = 'paragraph'; content = @(@{ type = 'text'; text = 'Body' }) }
            )

            $result = ConvertTo-ADF -InputObject $nodes

            $parsed = $result | ConvertFrom-Json
            $parsed.version | Should Be 1
            $parsed.type | Should Be 'doc'
            $parsed.content.Count | Should Be 2
            $parsed.content[0].type | Should Be 'heading'
            $parsed.content[1].type | Should Be 'paragraph'
        }
    }

    Context 'When input is single content node' {
        It 'Wraps single node in document structure' {
            $node = @{ type = 'paragraph'; content = @(@{ type = 'text'; text = 'Single' }) }

            $result = ConvertTo-ADF -InputObject $node

            $parsed = $result | ConvertFrom-Json
            $parsed.version | Should Be 1
            $parsed.type | Should Be 'doc'
            $parsed.content.Count | Should Be 1
            $parsed.content[0].type | Should Be 'paragraph'
        }
    }

    Context 'Content node validation' {
        It 'Warns when content node missing type property' {
            $invalidNode = @{ foo = 'bar' }

            # Capture warning output
            $warnings = @()
            $result = ConvertTo-ADF -InputObject $invalidNode -WarningVariable warnings 3>&1

            # Should still produce output (graceful degradation)
            $result | Should Not Be $null

            # Should have emitted a warning
            ($warnings | Where-Object { $_ -match 'missing required' }).Count | Should BeGreaterThan 0
        }

        It 'Does not warn when content node has type property' {
            $validNode = @{ type = 'paragraph'; content = @() }

            $warnings = @()
            $result = ConvertTo-ADF -InputObject $validNode -WarningVariable warnings 3>&1

            $result | Should Not Be $null
            ($warnings | Where-Object { $_ -match 'missing required' }).Count | Should Be 0
        }
    }

    Context 'JSON output validation' {
        It 'Version is integer 1 not string "1"' {
            $result = ConvertTo-ADF -InputObject $null

            $result | Should Match '"version":\s*1[,\s}]'
            $result | Should Not Match '"version":\s*"1"'
        }

        It 'Type is exactly "doc"' {
            $result = ConvertTo-ADF -InputObject $null

            $result | Should Match '"type":\s*"doc"'
        }

        It 'Content is always an array in JSON' {
            $result = ConvertTo-ADF -InputObject $null

            $result | Should Match '"content":\s*\['
        }

        It 'Handles deeply nested structures with -Depth 20' {
            # Create deeply nested content to test depth handling
            $deepNode = @{
                type = 'table'
                attrs = @{ isNumberColumnEnabled = $false; layout = 'default' }
                content = @(
                    @{
                        type = 'tableRow'
                        content = @(
                            @{
                                type = 'tableCell'
                                attrs = @{}
                                content = @(
                                    @{
                                        type = 'paragraph'
                                        content = @(
                                            @{ type = 'text'; text = 'Deep content' }
                                        )
                                    }
                                )
                            }
                        )
                    }
                )
            }

            $result = ConvertTo-ADF -InputObject $deepNode

            # Should not contain truncation indicators
            $result | Should Not Match 'System\.Object\[\]'
            $result | Should Not Match 'System\.Collections'

            # Should contain the deep content
            $result | Should Match 'Deep content'
        }
    }
}
