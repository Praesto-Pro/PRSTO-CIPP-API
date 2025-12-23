# Tests for New-ADFDocument private function
# Pester 3.4.0+ syntax for Windows PowerShell 5.1 compatibility

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
$functionPath = "$here\..\..\Private\$sut"

Describe 'New-ADFDocument' {
    BeforeAll {
        # Import the function directly for testing private function
        . $functionPath
    }

    Context 'Module Integration' {
        It 'Function file exists at expected path' {
            Test-Path $functionPath | Should Be $true
        }

        It 'Function is callable after dot-sourcing' {
            { New-ADFDocument } | Should Not Throw
        }
    }

    Context 'When creating a new ADF document' {
        It 'Returns a hashtable' {
            $result = New-ADFDocument
            $result.GetType().Name | Should Be 'Hashtable'
        }

        It 'Has version property set to integer 1' {
            $result = New-ADFDocument
            $result.version | Should Be 1
            $result.version.GetType().Name | Should Be 'Int32'
        }

        It 'Has type property set to "doc"' {
            $result = New-ADFDocument
            $result.type | Should Be 'doc'
        }

        It 'Has content property as empty array' {
            $result = New-ADFDocument
            # Content key should exist
            $result.ContainsKey('content') | Should Be $true
            # Content should be an array with count 0
            $result.content.Count | Should Be 0
            # Content should be an array type
            ($result.content -is [array]) | Should Be $true
        }

        It 'Has exactly three properties' {
            $result = New-ADFDocument
            $result.Keys.Count | Should Be 3
        }
    }

    Context 'When serializing to JSON' {
        It 'Produces valid JSON with correct structure' {
            $result = New-ADFDocument
            $json = $result | ConvertTo-Json -Depth 10
            $parsed = $json | ConvertFrom-Json
            $parsed.version | Should Be 1
            $parsed.type | Should Be 'doc'
        }

        It 'Version is integer 1 not string "1" in JSON' {
            $result = New-ADFDocument
            $json = $result | ConvertTo-Json -Depth 10
            # Check raw JSON contains version: 1 not version: "1"
            $json | Should Match '"version":\s*1[,\s}]'
            $json | Should Not Match '"version":\s*"1"'
        }
    }
}
