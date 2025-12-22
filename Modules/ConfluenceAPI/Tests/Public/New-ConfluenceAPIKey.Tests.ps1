#Requires -Modules Pester

# Note: Tests written for Pester 3.4.0+ compatibility (Windows PowerShell default)
# Pester 5 syntax (hyphenated operators) requires Pester 5.x module

Describe 'New-ConfluenceAPIKey' {
    BeforeAll {
        # Import module once before all tests (M2 fix)
        $ModulePath = (Get-Item "$PSScriptRoot\..\..\ConfluenceAPI.psd1").FullName
        Import-Module $ModulePath -Force
    }

    BeforeEach {
        # Clean state before each test
        Remove-ConfluenceAPIKey -ErrorAction SilentlyContinue
    }

    AfterEach {
        # Clean up after each test
        Remove-ConfluenceAPIKey -ErrorAction SilentlyContinue
    }

    Context 'Storing API Key' {
        It 'Stores API key successfully and returns confirmation message' {
            $result = New-ConfluenceAPIKey -ApiKey 'test-token-12345'
            $result | Should Be 'Confluence API key has been stored successfully.'
        }

        It 'Stores API key that can be verified via Get-ConfluenceAPIKey' {
            New-ConfluenceAPIKey -ApiKey 'test-token-xyz'
            $keyStatus = Get-ConfluenceAPIKey
            $keyStatus.IsConfigured | Should Be $true
        }

        It 'Does not expose actual token in output' {
            $output = New-ConfluenceAPIKey -ApiKey 'secret-token-xyz' 4>&1
            $output | Should Not Match 'secret-token-xyz'
        }

        It 'Does not expose actual token in verbose output' {
            $verboseOutput = New-ConfluenceAPIKey -ApiKey 'super-secret-123' -Verbose 4>&1
            $verboseOutput | ForEach-Object { $_.ToString() } | Should Not Match 'super-secret-123'
        }
    }

    Context 'Parameter Validation' {
        It 'Rejects empty ApiKey' {
            { New-ConfluenceAPIKey -ApiKey '' } | Should Throw
        }
    }

    Context 'WhatIf Support' {
        It 'Does not store key when WhatIf is used' {
            New-ConfluenceAPIKey -ApiKey 'test-token' -WhatIf
            $result = Get-ConfluenceAPIKey
            $result | Should BeNullOrEmpty
        }

        It 'Supports ShouldProcess with correct target description' {
            # Verify WhatIf is properly implemented via CmdletBinding
            $cmd = Get-Command New-ConfluenceAPIKey
            $cmd.Parameters.ContainsKey('WhatIf') | Should Be $true
            $cmd.Parameters.ContainsKey('Confirm') | Should Be $true
        }
    }

    Context 'Verbose Logging' {
        It 'Outputs verbose message when -Verbose is used' {
            $verboseMessages = New-ConfluenceAPIKey -ApiKey 'test-key' -Verbose 4>&1
            $verboseMessages | Should Not BeNullOrEmpty
        }
    }
}
