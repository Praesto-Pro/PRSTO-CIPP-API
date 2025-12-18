$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'

# Get path to function file - Tests/Confluence -> parent is Tests -> parent is CippExtensions
$moduleRoot = Split-Path (Split-Path $here -Parent) -Parent
$functionPath = Join-Path $moduleRoot (Join-Path 'Public' (Join-Path 'Confluence' $sut))

# Define stub functions for dependencies (required for Pester 3.4 mocking)
function Get-ExtensionAPIKey { param($Extension) }
function New-ConfluenceAPIKey { param($ApiKey) }
function New-ConfluenceBaseURL { param($BaseURL) }
function Test-ConfluenceConnection { }

Describe 'Connect-ConfluenceAPI' {
    BeforeAll {
        # Dot-source the function for testing
        if (Test-Path $functionPath) {
            . $functionPath
        }
    }

    BeforeEach {
        # Mock CIPP framework functions
        Mock Get-ExtensionAPIKey {
            return 'mock-api-key-12345'
        }

        # Mock ConfluenceAPI module functions
        Mock New-ConfluenceAPIKey { }
        Mock New-ConfluenceBaseURL { }
        Mock Test-ConfluenceConnection {
            return [PSCustomObject]@{
                Success = $true
                Error   = $null
            }
        }
    }

    Context 'Successful Connection' {
        It 'Returns Success true on successful connection' {
            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net' } }
            $result = Connect-ConfluenceAPI -Configuration $config

            $result.Success | Should Be $true
        }

        It 'Returns null Error on successful connection' {
            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net' } }
            $result = Connect-ConfluenceAPI -Configuration $config

            $result.Error | Should Be $null
        }

        It 'Calls Get-ExtensionAPIKey with Confluence extension' {
            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net' } }
            $result = Connect-ConfluenceAPI -Configuration $config

            Assert-MockCalled Get-ExtensionAPIKey -Times 1 -ParameterFilter { $Extension -eq 'Confluence' }
        }

        It 'Calls New-ConfluenceAPIKey with retrieved API key' {
            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net' } }
            $result = Connect-ConfluenceAPI -Configuration $config

            Assert-MockCalled New-ConfluenceAPIKey -Times 1 -ParameterFilter { $ApiKey -eq 'mock-api-key-12345' }
        }

        It 'Calls New-ConfluenceBaseURL with BaseURL from config' {
            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net' } }
            $result = Connect-ConfluenceAPI -Configuration $config

            Assert-MockCalled New-ConfluenceBaseURL -Times 1 -ParameterFilter { $BaseURL -eq 'https://test.atlassian.net' }
        }

        It 'Calls Test-ConfluenceConnection to validate' {
            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net' } }
            $result = Connect-ConfluenceAPI -Configuration $config

            Assert-MockCalled Test-ConfluenceConnection -Times 1 -Exactly
        }
    }

    Context 'Missing API Key' {
        It 'Returns Success false when API key is null' {
            Mock Get-ExtensionAPIKey { return $null }

            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net' } }
            $result = Connect-ConfluenceAPI -Configuration $config

            $result.Success | Should Be $false
        }

        It 'Returns descriptive error when API key is missing' {
            Mock Get-ExtensionAPIKey { return $null }

            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net' } }
            $result = Connect-ConfluenceAPI -Configuration $config

            $result.Error | Should Match 'API key not configured'
        }

        It 'Does not call New-ConfluenceAPIKey when API key is missing' {
            Mock Get-ExtensionAPIKey { return $null }

            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net' } }
            $result = Connect-ConfluenceAPI -Configuration $config

            Assert-MockCalled New-ConfluenceAPIKey -Times 0
        }

        It 'Returns Success false when API key is empty string' {
            Mock Get-ExtensionAPIKey { return '' }

            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net' } }
            $result = Connect-ConfluenceAPI -Configuration $config

            $result.Success | Should Be $false
        }
    }

    Context 'Missing BaseURL' {
        It 'Returns Success false when BaseURL is missing from nested config' {
            $config = @{ Confluence = @{ SomeOtherSetting = $true } }
            $result = Connect-ConfluenceAPI -Configuration $config

            $result.Success | Should Be $false
        }

        It 'Returns descriptive error when BaseURL is missing' {
            $config = @{ Confluence = @{ SomeOtherSetting = $true } }
            $result = Connect-ConfluenceAPI -Configuration $config

            $result.Error | Should Match 'BaseURL not configured'
        }

        It 'Does not call New-ConfluenceBaseURL when BaseURL is missing' {
            $config = @{ Confluence = @{ SomeOtherSetting = $true } }
            $result = Connect-ConfluenceAPI -Configuration $config

            Assert-MockCalled New-ConfluenceBaseURL -Times 0
        }
    }

    Context 'Configuration Structure' {
        It 'Handles nested Confluence configuration' {
            $config = @{ Confluence = @{ BaseURL = 'https://nested.atlassian.net' } }
            $result = Connect-ConfluenceAPI -Configuration $config

            Assert-MockCalled New-ConfluenceBaseURL -Times 1 -ParameterFilter { $BaseURL -eq 'https://nested.atlassian.net' }
        }

        It 'Handles flat configuration structure' {
            $config = @{ BaseURL = 'https://flat.atlassian.net' }
            $result = Connect-ConfluenceAPI -Configuration $config

            Assert-MockCalled New-ConfluenceBaseURL -Times 1 -ParameterFilter { $BaseURL -eq 'https://flat.atlassian.net' }
        }

        It 'Prefers nested Confluence.BaseURL over flat BaseURL' {
            $config = @{
                BaseURL    = 'https://flat.atlassian.net'
                Confluence = @{ BaseURL = 'https://nested.atlassian.net' }
            }
            $result = Connect-ConfluenceAPI -Configuration $config

            Assert-MockCalled New-ConfluenceBaseURL -Times 1 -ParameterFilter { $BaseURL -eq 'https://nested.atlassian.net' }
        }
    }

    Context 'Connection Validation Failure' {
        It 'Returns Success false when Test-ConfluenceConnection fails' {
            Mock Test-ConfluenceConnection {
                return [PSCustomObject]@{
                    Success = $false
                    Error   = 'Authentication failed'
                }
            }

            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net' } }
            $result = Connect-ConfluenceAPI -Configuration $config

            $result.Success | Should Be $false
        }

        It 'Includes connection test error in result' {
            Mock Test-ConfluenceConnection {
                return [PSCustomObject]@{
                    Success = $false
                    Error   = 'Authentication failed'
                }
            }

            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net' } }
            $result = Connect-ConfluenceAPI -Configuration $config

            $result.Error | Should Match 'Authentication failed'
        }

        It 'Handles null return from Test-ConfluenceConnection' {
            Mock Test-ConfluenceConnection { return $null }

            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net' } }
            $result = Connect-ConfluenceAPI -Configuration $config

            $result.Success | Should Be $false
        }
    }

    Context 'Exception Handling' {
        It 'Returns Success false when Get-ExtensionAPIKey throws' {
            Mock Get-ExtensionAPIKey { throw 'Key Vault error' }

            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net' } }
            $result = Connect-ConfluenceAPI -Configuration $config

            $result.Success | Should Be $false
        }

        It 'Captures exception message in Error' {
            Mock Get-ExtensionAPIKey { throw 'Key Vault error' }

            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net' } }
            $result = Connect-ConfluenceAPI -Configuration $config

            $result.Error | Should Match 'Key Vault error'
        }

        It 'Returns Success false when New-ConfluenceAPIKey throws' {
            Mock New-ConfluenceAPIKey { throw 'Invalid API key format' }

            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net' } }
            $result = Connect-ConfluenceAPI -Configuration $config

            $result.Success | Should Be $false
        }

        It 'Returns Success false when New-ConfluenceBaseURL throws' {
            Mock New-ConfluenceBaseURL { throw 'Invalid URL format' }

            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net' } }
            $result = Connect-ConfluenceAPI -Configuration $config

            $result.Success | Should Be $false
        }

        It 'Returns Success false when Test-ConfluenceConnection throws' {
            Mock Test-ConfluenceConnection { throw 'Network unreachable' }

            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net' } }
            $result = Connect-ConfluenceAPI -Configuration $config

            $result.Success | Should Be $false
        }
    }

    Context 'Output Object Structure' {
        It 'Returns object with Success property' {
            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net' } }
            $result = Connect-ConfluenceAPI -Configuration $config

            ($result.PSObject.Properties.Name -contains 'Success') | Should Be $true
        }

        It 'Returns object with Error property' {
            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net' } }
            $result = Connect-ConfluenceAPI -Configuration $config

            ($result.PSObject.Properties.Name -contains 'Error') | Should Be $true
        }

        It 'Success property is boolean true on success' {
            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net' } }
            $result = Connect-ConfluenceAPI -Configuration $config

            $result.Success | Should BeOfType [bool]
            $result.Success | Should Be $true
        }

        It 'Success property is boolean false on failure' {
            Mock Get-ExtensionAPIKey { return $null }

            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net' } }
            $result = Connect-ConfluenceAPI -Configuration $config

            $result.Success | Should BeOfType [bool]
            $result.Success | Should Be $false
        }
    }
}
