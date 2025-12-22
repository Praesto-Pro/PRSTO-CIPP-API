# Tests for New-ADFParagraph and New-ADFTextNode private functions
# Pester 3.4.0+ syntax for Windows PowerShell 5.1 compatibility

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$privateDir = "$here\..\..\Private"

Describe 'New-ADFParagraph' {
    BeforeAll {
        # Import the function
        . "$privateDir\New-ADFParagraph.ps1"
    }

    Context 'Basic paragraph creation' {
        It 'Returns a hashtable' {
            $result = New-ADFParagraph -Text 'Test'
            $result | Should Not Be $null
            $result.GetType().Name | Should Be 'Hashtable'
        }

        It 'Has type property set to paragraph' {
            $result = New-ADFParagraph -Text 'Test'
            $result.type | Should Be 'paragraph'
        }

        It 'Has content array with text node' {
            $result = New-ADFParagraph -Text 'Test'
            $result.content | Should Not Be $null
            $result.content.Count | Should Be 1
            $result.content[0].type | Should Be 'text'
        }

        It 'Text node contains the specified text' {
            $result = New-ADFParagraph -Text 'My paragraph'
            $result.content[0].text | Should Be 'My paragraph'
        }
    }

    Context 'Plain text without marks' {
        It 'Text node has no marks property when no formatting' {
            $result = New-ADFParagraph -Text 'Plain text'
            $result.content[0].ContainsKey('marks') | Should Be $false
        }

        It 'Handles empty string text' {
            $result = New-ADFParagraph -Text ''
            $result.content[0].text | Should Be ''
        }

        It 'Handles text with special characters' {
            $result = New-ADFParagraph -Text 'Test & <special> "chars"'
            $result.content[0].text | Should Be 'Test & <special> "chars"'
        }

        It 'Handles text with newlines' {
            $text = "Line 1`nLine 2"
            $result = New-ADFParagraph -Text $text
            $result.content[0].text | Should Be $text
        }

        It 'Handles unicode characters' {
            $result = New-ADFParagraph -Text 'Test 日本語 emoji 🎉'
            $result.content[0].text | Should Be 'Test 日本語 emoji 🎉'
        }
    }

    Context 'Bold formatting' {
        It 'Adds marks array when -Bold is used' {
            $result = New-ADFParagraph -Text 'Bold text' -Bold
            $result.content[0].marks | Should Not Be $null
        }

        It 'Marks array contains strong type' {
            $result = New-ADFParagraph -Text 'Bold text' -Bold
            $result.content[0].marks.Count | Should Be 1
            $result.content[0].marks[0].type | Should Be 'strong'
        }

        It 'Text content is preserved with bold' {
            $result = New-ADFParagraph -Text 'Important!' -Bold
            $result.content[0].text | Should Be 'Important!'
        }
    }

    Context 'Italic formatting' {
        It 'Adds marks array when -Italic is used' {
            $result = New-ADFParagraph -Text 'Italic text' -Italic
            $result.content[0].marks | Should Not Be $null
        }

        It 'Marks array contains em type' {
            $result = New-ADFParagraph -Text 'Italic text' -Italic
            $result.content[0].marks.Count | Should Be 1
            $result.content[0].marks[0].type | Should Be 'em'
        }

        It 'Text content is preserved with italic' {
            $result = New-ADFParagraph -Text 'Emphasized' -Italic
            $result.content[0].text | Should Be 'Emphasized'
        }
    }

    Context 'Combined bold and italic' {
        It 'Marks array contains both strong and em' {
            $result = New-ADFParagraph -Text 'Both' -Bold -Italic
            $result.content[0].marks.Count | Should Be 2
        }

        It 'Strong mark is present' {
            $result = New-ADFParagraph -Text 'Both' -Bold -Italic
            $strongMark = $result.content[0].marks | Where-Object { $_.type -eq 'strong' }
            $strongMark | Should Not Be $null
        }

        It 'Em mark is present' {
            $result = New-ADFParagraph -Text 'Both' -Bold -Italic
            $emMark = $result.content[0].marks | Where-Object { $_.type -eq 'em' }
            $emMark | Should Not Be $null
        }
    }

    Context 'Content parameter for multiple text nodes' {
        It 'Accepts array of text nodes' {
            $nodes = @(
                @{ type = 'text'; text = 'First' },
                @{ type = 'text'; text = 'Second' }
            )
            $result = New-ADFParagraph -Content $nodes
            $result.content.Count | Should Be 2
        }

        It 'Preserves text node content' {
            $nodes = @(
                @{ type = 'text'; text = 'Hello ' },
                @{ type = 'text'; text = 'World' }
            )
            $result = New-ADFParagraph -Content $nodes
            $result.content[0].text | Should Be 'Hello '
            $result.content[1].text | Should Be 'World'
        }

        It 'Preserves marks on text nodes' {
            $nodes = @(
                @{ type = 'text'; text = 'Normal ' },
                @{ type = 'text'; text = 'bold'; marks = @(@{ type = 'strong' }) }
            )
            $result = New-ADFParagraph -Content $nodes
            $result.content[1].marks[0].type | Should Be 'strong'
        }

        It 'Handles single node in Content array' {
            $nodes = @(
                @{ type = 'text'; text = 'Single' }
            )
            $result = New-ADFParagraph -Content $nodes
            $result.content.Count | Should Be 1
            $result.content[0].text | Should Be 'Single'
        }
    }

    Context 'ADF structure compliance' {
        It 'Root structure has type and content properties' {
            $result = New-ADFParagraph -Text 'Test'
            $result.ContainsKey('type') | Should Be $true
            $result.ContainsKey('content') | Should Be $true
        }

        It 'Paragraph has no attrs property' {
            $result = New-ADFParagraph -Text 'Test'
            $result.ContainsKey('attrs') | Should Be $false
        }

        It 'Content is always an array' {
            $result = New-ADFParagraph -Text 'Test'
            $result.content.GetType().BaseType.Name | Should Be 'Array'
        }
    }

    Context 'Timestamp formatting (FR44)' {
        It 'Handles date formatted strings' {
            $timestamp = "Data as of: $(Get-Date -Format 'yyyy-MM-dd HH:mm') UTC"
            $result = New-ADFParagraph -Text $timestamp
            $result.content[0].text | Should Match 'Data as of:'
            $result.content[0].text | Should Match '\d{4}-\d{2}-\d{2}'
        }
    }

    Context 'Verbose logging' {
        It 'Outputs verbose message when -Verbose is used' {
            $verboseOutput = New-ADFParagraph -Text 'Test' -Verbose 4>&1
            $verboseOutput | Should Not Be $null
        }
    }
}

Describe 'New-ADFTextNode' {
    BeforeAll {
        . "$privateDir\New-ADFParagraph.ps1"
    }

    Context 'Basic text node creation' {
        It 'Returns a hashtable' {
            $result = New-ADFTextNode -Text 'Test'
            $result.GetType().Name | Should Be 'Hashtable'
        }

        It 'Has type property set to text' {
            $result = New-ADFTextNode -Text 'Test'
            $result.type | Should Be 'text'
        }

        It 'Contains the specified text' {
            $result = New-ADFTextNode -Text 'Hello World'
            $result.text | Should Be 'Hello World'
        }

        It 'Has no marks when no formatting specified' {
            $result = New-ADFTextNode -Text 'Plain'
            $result.ContainsKey('marks') | Should Be $false
        }
    }

    Context 'Bold formatting' {
        It 'Adds strong mark when -Bold used' {
            $result = New-ADFTextNode -Text 'Bold' -Bold
            $result.marks[0].type | Should Be 'strong'
        }
    }

    Context 'Italic formatting' {
        It 'Adds em mark when -Italic used' {
            $result = New-ADFTextNode -Text 'Italic' -Italic
            $result.marks[0].type | Should Be 'em'
        }
    }

    Context 'Combined formatting' {
        It 'Adds both marks when -Bold and -Italic used' {
            $result = New-ADFTextNode -Text 'Both' -Bold -Italic
            $result.marks.Count | Should Be 2
        }
    }

    Context 'Edge cases' {
        It 'Creates valid node with empty text and marks' {
            $result = New-ADFTextNode -Text '' -Bold
            $result.type | Should Be 'text'
            $result.text | Should Be ''
            $result.marks[0].type | Should Be 'strong'
        }
    }

    Context 'Integration with New-ADFParagraph' {
        It 'Can be used with -Content parameter' {
            $nodes = @(
                (New-ADFTextNode -Text 'Normal '),
                (New-ADFTextNode -Text 'bold' -Bold),
                (New-ADFTextNode -Text ' text')
            )
            $result = New-ADFParagraph -Content $nodes
            $result.content.Count | Should Be 3
            $result.content[1].marks[0].type | Should Be 'strong'
        }
    }
}

Describe 'New-ADFParagraph Integration with ADF Document' {
    BeforeAll {
        . "$privateDir\New-ADFParagraph.ps1"
        . "$privateDir\New-ADFHeading.ps1"
        . "$privateDir\New-ADFDocument.ps1"
        . "$privateDir\Add-ADFContent.ps1"
        . "$privateDir\ConvertTo-ADF.ps1"
    }

    Context 'Document integration' {
        It 'Can be added to ADF document' {
            $doc = New-ADFDocument
            $para = New-ADFParagraph -Text 'Test paragraph'
            $result = Add-ADFContent -Document $doc -Content $para
            $result.content.Count | Should Be 1
            $result.content[0].type | Should Be 'paragraph'
        }

        It 'Produces valid JSON when converted' {
            $doc = New-ADFDocument
            $para = New-ADFParagraph -Text 'Hello World' -Bold
            $doc = Add-ADFContent -Document $doc -Content $para
            $json = ConvertTo-ADF -InputObject $doc

            $json | Should Not Be $null
            $json | Should BeOfType [string]
            $parsed = $json | ConvertFrom-Json
            $parsed.content[0].type | Should Be 'paragraph'
            $parsed.content[0].content[0].text | Should Be 'Hello World'
            $parsed.content[0].content[0].marks[0].type | Should Be 'strong'
        }

        It 'Can combine headings and paragraphs' {
            $doc = New-ADFDocument
            $heading = New-ADFHeading -Level 1 -Text 'Title'
            $para = New-ADFParagraph -Text 'Description text'
            $doc = Add-ADFContent -Document $doc -Content @($heading, $para)

            $doc.content.Count | Should Be 2
            $doc.content[0].type | Should Be 'heading'
            $doc.content[1].type | Should Be 'paragraph'
        }

        It 'Handles complex document with mixed formatting' {
            $doc = New-ADFDocument
            $h1 = New-ADFHeading -Level 1 -Text 'Report'
            $timestamp = New-ADFParagraph -Text "Generated: $(Get-Date -Format 'yyyy-MM-dd')"
            $h2 = New-ADFHeading -Level 2 -Text 'Summary'
            $note = New-ADFParagraph -Text 'Important notice' -Bold -Italic

            $doc = Add-ADFContent -Document $doc -Content @($h1, $timestamp, $h2, $note)
            $json = ConvertTo-ADF -InputObject $doc

            $parsed = $json | ConvertFrom-Json
            $parsed.content.Count | Should Be 4
            $parsed.content[3].content[0].marks.Count | Should Be 2
        }
    }

    Context 'Mixed text node integration' {
        It 'Complex paragraph with mixed formatting produces valid JSON' {
            $nodes = @(
                (New-ADFTextNode -Text 'Normal '),
                (New-ADFTextNode -Text 'bold' -Bold),
                (New-ADFTextNode -Text ' and '),
                (New-ADFTextNode -Text 'italic' -Italic),
                (New-ADFTextNode -Text ' text')
            )
            $para = New-ADFParagraph -Content $nodes

            $doc = New-ADFDocument
            $doc = Add-ADFContent -Document $doc -Content $para
            $json = ConvertTo-ADF -InputObject $doc

            $parsed = $json | ConvertFrom-Json
            $parsed.content[0].content.Count | Should Be 5
            $parsed.content[0].content[1].marks[0].type | Should Be 'strong'
            $parsed.content[0].content[3].marks[0].type | Should Be 'em'
        }
    }
}
