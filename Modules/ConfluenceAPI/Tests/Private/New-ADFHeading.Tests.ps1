# Tests for New-ADFHeading private function
# Pester 3.4.0+ syntax for Windows PowerShell 5.1 compatibility

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$privateDir = "$here\..\..\Private"

Describe 'New-ADFHeading' {
    BeforeAll {
        # Import the function
        . "$privateDir\New-ADFHeading.ps1"
    }

    Context 'Basic heading creation' {
        It 'Returns a hashtable' {
            $result = New-ADFHeading -Level 1 -Text 'Test'
            $result | Should Not Be $null
            $result.GetType().Name | Should Be 'Hashtable'
        }

        It 'Has type property set to heading' {
            $result = New-ADFHeading -Level 1 -Text 'Test'
            $result.type | Should Be 'heading'
        }

        It 'Has attrs property with level' {
            $result = New-ADFHeading -Level 2 -Text 'Test'
            $result.attrs | Should Not Be $null
            $result.attrs.level | Should Be 2
        }

        It 'Has content array with text node' {
            $result = New-ADFHeading -Level 1 -Text 'Test'
            $result.content | Should Not Be $null
            $result.content.Count | Should Be 1
            $result.content[0].type | Should Be 'text'
        }

        It 'Text node contains the specified text' {
            $result = New-ADFHeading -Level 1 -Text 'My Heading'
            $result.content[0].text | Should Be 'My Heading'
        }
    }

    Context 'Heading levels 1-6' {
        It 'Creates level 1 heading' {
            $result = New-ADFHeading -Level 1 -Text 'Level 1'
            $result.attrs.level | Should Be 1
        }

        It 'Creates level 2 heading' {
            $result = New-ADFHeading -Level 2 -Text 'Level 2'
            $result.attrs.level | Should Be 2
        }

        It 'Creates level 3 heading' {
            $result = New-ADFHeading -Level 3 -Text 'Level 3'
            $result.attrs.level | Should Be 3
        }

        It 'Creates level 4 heading' {
            $result = New-ADFHeading -Level 4 -Text 'Level 4'
            $result.attrs.level | Should Be 4
        }

        It 'Creates level 5 heading' {
            $result = New-ADFHeading -Level 5 -Text 'Level 5'
            $result.attrs.level | Should Be 5
        }

        It 'Creates level 6 heading' {
            $result = New-ADFHeading -Level 6 -Text 'Level 6'
            $result.attrs.level | Should Be 6
        }
    }

    Context 'Invalid heading levels' {
        It 'Rejects level 0' {
            { New-ADFHeading -Level 0 -Text 'Invalid' } | Should Throw
        }

        It 'Rejects level 7' {
            { New-ADFHeading -Level 7 -Text 'Invalid' } | Should Throw
        }

        It 'Rejects negative levels' {
            { New-ADFHeading -Level -1 -Text 'Invalid' } | Should Throw
        }
    }

    Context 'Text content handling' {
        It 'Rejects empty string text' {
            { New-ADFHeading -Level 1 -Text '' } | Should Throw
        }

        It 'Rejects whitespace-only text' {
            { New-ADFHeading -Level 1 -Text '   ' } | Should Throw
        }

        It 'Handles text with special characters' {
            $result = New-ADFHeading -Level 1 -Text 'Test & <special> "chars"'
            $result.content[0].text | Should Be 'Test & <special> "chars"'
        }

        It 'Handles text with newlines' {
            $text = "Line 1`nLine 2"
            $result = New-ADFHeading -Level 1 -Text $text
            $result.content[0].text | Should Be $text
        }

        It 'Handles long text' {
            $longText = 'A' * 500
            $result = New-ADFHeading -Level 1 -Text $longText
            $result.content[0].text | Should Be $longText
        }

        It 'Handles unicode characters' {
            $result = New-ADFHeading -Level 1 -Text 'Test 日本語 emoji 🎉'
            $result.content[0].text | Should Be 'Test 日本語 emoji 🎉'
        }
    }

    Context 'ADF structure compliance' {
        It 'Content array contains exactly one text node' {
            $result = New-ADFHeading -Level 1 -Text 'Test'
            $result.content.Count | Should Be 1
        }

        It 'Text node has only type and text properties' {
            $result = New-ADFHeading -Level 1 -Text 'Test'
            $textNode = $result.content[0]
            $textNode.Keys.Count | Should Be 2
            $textNode.ContainsKey('type') | Should Be $true
            $textNode.ContainsKey('text') | Should Be $true
        }

        It 'Attrs contains only level property' {
            $result = New-ADFHeading -Level 1 -Text 'Test'
            $result.attrs.Keys.Count | Should Be 1
            $result.attrs.ContainsKey('level') | Should Be $true
        }

        It 'Root structure has type, attrs, and content properties' {
            $result = New-ADFHeading -Level 1 -Text 'Test'
            $result.ContainsKey('type') | Should Be $true
            $result.ContainsKey('attrs') | Should Be $true
            $result.ContainsKey('content') | Should Be $true
            $result.Keys.Count | Should Be 3
        }
    }

    Context 'Verbose logging' {
        It 'Outputs verbose message when -Verbose is used' {
            $verboseOutput = New-ADFHeading -Level 1 -Text 'Test' -Verbose 4>&1
            $verboseOutput | Should Not Be $null
        }
    }

    Context 'Integration with ADF Document' {
        BeforeAll {
            . "$privateDir\New-ADFDocument.ps1"
            . "$privateDir\Add-ADFContent.ps1"
            . "$privateDir\ConvertTo-ADF.ps1"
        }

        It 'Can be added to ADF document' {
            $doc = New-ADFDocument
            $heading = New-ADFHeading -Level 1 -Text 'Test Heading'
            $result = Add-ADFContent -Document $doc -Content $heading
            $result.content.Count | Should Be 1
            $result.content[0].type | Should Be 'heading'
        }

        It 'Produces valid JSON when converted' {
            $doc = New-ADFDocument
            $heading = New-ADFHeading -Level 2 -Text 'Section Title'
            $doc = Add-ADFContent -Document $doc -Content $heading
            $json = ConvertTo-ADF -InputObject $doc

            $json | Should Not Be $null
            $json | Should BeOfType [string]
            $parsed = $json | ConvertFrom-Json
            $parsed.content[0].type | Should Be 'heading'
            $parsed.content[0].attrs.level | Should Be 2
        }

        It 'Can combine multiple headings in document' {
            $doc = New-ADFDocument
            $h1 = New-ADFHeading -Level 1 -Text 'Main Title'
            $h2 = New-ADFHeading -Level 2 -Text 'Section 1'
            $h3 = New-ADFHeading -Level 2 -Text 'Section 2'
            $doc = Add-ADFContent -Document $doc -Content @($h1, $h2, $h3)

            $doc.content.Count | Should Be 3
            $doc.content[0].attrs.level | Should Be 1
            $doc.content[1].attrs.level | Should Be 2
            $doc.content[2].attrs.level | Should Be 2
        }
    }
}
