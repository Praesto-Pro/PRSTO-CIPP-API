$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'

# Get path to function file - Tests/Confluence -> parent is Tests -> parent is CippExtensions
$moduleRoot = Split-Path (Split-Path $here -Parent) -Parent
$functionPath = Join-Path $moduleRoot (Join-Path 'Private' (Join-Path 'Confluence' $sut))

# No stub functions needed - uses inline SHA1 implementation

Describe 'Get-ConfluenceContentHash' {
    BeforeAll {
        # Dot-source the function for testing
        if (Test-Path $functionPath) {
            . $functionPath
        }
    }

    Context 'Hash Generation - Hashtable Input' {
        It 'Generates consistent hash for same hashtable content' {
            $content = @{ type = 'doc'; content = @(@{ type = 'paragraph' }) }

            $hash1 = Get-ConfluenceContentHash -Content $content
            $hash2 = Get-ConfluenceContentHash -Content $content

            $hash1 | Should Be $hash2
        }

        It 'Generates different hash for different content' {
            $content1 = @{ type = 'doc'; value = 'A' }
            $content2 = @{ type = 'doc'; value = 'B' }

            $hash1 = Get-ConfluenceContentHash -Content $content1
            $hash2 = Get-ConfluenceContentHash -Content $content2

            $hash1 | Should Not Be $hash2
        }

        It 'Returns 40-character SHA1 hex string for hashtable' {
            $content = @{ type = 'doc' }

            $hash = Get-ConfluenceContentHash -Content $content

            $hash.Length | Should Be 40
            $hash | Should Match '^[A-F0-9]{40}$'
        }
    }

    Context 'Hash Generation - String Input' {
        It 'Generates consistent hash for same string content' {
            $content = '{"type":"doc","content":[]}'

            $hash1 = Get-ConfluenceContentHash -Content $content
            $hash2 = Get-ConfluenceContentHash -Content $content

            $hash1 | Should Be $hash2
        }

        It 'Returns 40-character SHA1 hex string for string' {
            $content = '{"type":"doc"}'

            $hash = Get-ConfluenceContentHash -Content $content

            $hash.Length | Should Be 40
            $hash | Should Match '^[A-F0-9]{40}$'
        }

        It 'Generates different hash for different strings' {
            $hash1 = Get-ConfluenceContentHash -Content 'content A'
            $hash2 = Get-ConfluenceContentHash -Content 'content B'

            $hash1 | Should Not Be $hash2
        }
    }

    Context 'Hash Generation - Ordered Dictionary Input' {
        It 'Returns 40-character hash for ordered dictionary' {
            $content = [ordered]@{ type = 'doc'; version = 1 }

            $hash = Get-ConfluenceContentHash -Content $content

            $hash.Length | Should Be 40
            $hash | Should Match '^[A-F0-9]{40}$'
        }
    }

    Context 'Hash Format' {
        It 'Returns valid hex characters with 40 character length' {
            $content = @{ test = 'value' }

            $hash = Get-ConfluenceContentHash -Content $content

            $hash.Length | Should Be 40
            $hash | Should Match '^[A-F0-9]{40}$'
        }

        It 'Returns string type' {
            $content = @{ test = 'value' }

            $hash = Get-ConfluenceContentHash -Content $content

            $hash.GetType().Name | Should Be 'String'
        }
    }

    Context 'Empty Content' {
        It 'Generates hash for empty hashtable' {
            $content = @{}

            $hash = Get-ConfluenceContentHash -Content $content

            $hash.Length | Should Be 40
        }

        It 'Generates hash for empty string' {
            $content = ''

            $hash = Get-ConfluenceContentHash -Content $content

            $hash.Length | Should Be 40
        }
    }

    Context 'Complex Content' {
        It 'Handles nested hashtables correctly' {
            $content = @{
                type    = 'doc'
                version = 1
                content = @(
                    @{
                        type    = 'paragraph'
                        content = @(
                            @{ type = 'text'; text = 'Hello World' }
                        )
                    }
                )
            }

            $hash = Get-ConfluenceContentHash -Content $content

            $hash.Length | Should Be 40
        }

        It 'Handles arrays within content' {
            $content = @{
                items = @('one', 'two', 'three')
            }

            $hash = Get-ConfluenceContentHash -Content $content

            $hash.Length | Should Be 40
        }
    }
}
