#Requires -Modules Pester

# Note: Tests written for Pester 3.4.0+ compatibility (Windows PowerShell default)

Describe 'Get-ConfluenceAPIKey' {
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

    Context 'Retrieving Stored Key' {
        It 'Returns masked representation when key is stored' {
            New-ConfluenceAPIKey -ApiKey 'test-token-123'
            $result = Get-ConfluenceAPIKey

            $result | Should Not BeNullOrEmpty
            $result.IsConfigured | Should Be $true
            $result.MaskedKey | Should Be '****...****'
        }

        It 'Does not expose actual token value' {
            New-ConfluenceAPIKey -ApiKey 'my-secret-token-xyz'
            $result = Get-ConfluenceAPIKey

            $result.MaskedKey | Should Not Match 'my-secret-token-xyz'
            ($result | Out-String) | Should Not Match 'my-secret-token-xyz'
        }

        It 'Returns PSCustomObject with expected properties' {
            New-ConfluenceAPIKey -ApiKey 'test-key'
            $result = Get-ConfluenceAPIKey

            # Verify IsConfigured property exists and has correct value
            $result.IsConfigured | Should Be $true
            # Verify MaskedKey property exists and has correct value
            $result.MaskedKey | Should Be '****...****'
        }
    }

    Context 'No Key Stored' {
        It 'Returns null when no key is stored' {
            $result = Get-ConfluenceAPIKey
            $result | Should BeNullOrEmpty
        }

        It 'Does not throw error when no key exists' {
            { Get-ConfluenceAPIKey } | Should Not Throw
        }
    }

    Context 'Verbose Logging' {
        It 'Outputs verbose message when -Verbose is used' {
            New-ConfluenceAPIKey -ApiKey 'test-key'
            $verboseMessages = Get-ConfluenceAPIKey -Verbose 4>&1

            $verboseMessages | Should Not BeNullOrEmpty
        }

        It 'Verbose output does not contain actual token' {
            New-ConfluenceAPIKey -ApiKey 'super-secret-key-999'
            $verboseOutput = Get-ConfluenceAPIKey -Verbose 4>&1

            $verboseOutput | ForEach-Object { $_.ToString() } | Should Not Match 'super-secret-key-999'
        }
    }
}
