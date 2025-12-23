#Requires -Modules Pester

# Note: Tests written for Pester 3.4.0+ compatibility (Windows PowerShell default)

Describe 'Remove-ConfluenceAPIKey' {
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
        # Ensure cleanup
        Remove-ConfluenceAPIKey -ErrorAction SilentlyContinue
    }

    Context 'Removing Stored Key' {
        It 'Removes stored API key successfully' {
            New-ConfluenceAPIKey -ApiKey 'test-token-to-remove'
            Remove-ConfluenceAPIKey

            $result = Get-ConfluenceAPIKey
            $result | Should BeNullOrEmpty
        }

        It 'Returns confirmation message when key is removed' {
            New-ConfluenceAPIKey -ApiKey 'test-token'
            $result = Remove-ConfluenceAPIKey

            $result | Should Be 'Confluence API key has been removed.'
        }
    }

    Context 'Idempotent Behavior' {
        It 'Does not error when called with no key stored' {
            { Remove-ConfluenceAPIKey } | Should Not Throw
        }

        It 'Can be called multiple times without error' {
            New-ConfluenceAPIKey -ApiKey 'test-key'
            Remove-ConfluenceAPIKey
            { Remove-ConfluenceAPIKey } | Should Not Throw
            { Remove-ConfluenceAPIKey } | Should Not Throw
        }
    }

    Context 'WhatIf Support' {
        It 'Does not remove key when WhatIf is used' {
            New-ConfluenceAPIKey -ApiKey 'test-token'
            Remove-ConfluenceAPIKey -WhatIf

            $result = Get-ConfluenceAPIKey
            $result.IsConfigured | Should Be $true
        }

        It 'Supports ShouldProcess with correct target description' {
            # Verify WhatIf is properly implemented via CmdletBinding
            $cmd = Get-Command Remove-ConfluenceAPIKey
            $cmd.Parameters.ContainsKey('WhatIf') | Should Be $true
            $cmd.Parameters.ContainsKey('Confirm') | Should Be $true
        }
    }

    Context 'Verbose Logging' {
        It 'Outputs verbose message when -Verbose is used' {
            New-ConfluenceAPIKey -ApiKey 'test-key'
            $verboseMessages = Remove-ConfluenceAPIKey -Verbose 4>&1

            $verboseMessages | Should Not BeNullOrEmpty
        }
    }
}
