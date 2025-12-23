#Requires -Modules Pester

Describe 'Test-ConfluenceConnection' {
    BeforeAll {
        $ModulePath = (Get-Item "$PSScriptRoot\..\..\ConfluenceAPI.psd1").FullName
        Import-Module $ModulePath -Force
    }

    BeforeEach {
        # Clear credentials for clean state
        Remove-ConfluenceAPIKey -ErrorAction SilentlyContinue
        Remove-ConfluenceBaseURL -ErrorAction SilentlyContinue
    }

    AfterEach {
        Remove-ConfluenceAPIKey -ErrorAction SilentlyContinue
        Remove-ConfluenceBaseURL -ErrorAction SilentlyContinue
    }

    Context 'Missing Credentials' {
        It 'Throws error when no API key is configured' {
            New-ConfluenceBaseURL -BaseURL 'https://test.atlassian.net'
            { Test-ConfluenceConnection } | Should Throw 'API key not configured'
        }

        It 'Throws error when no base URL is configured' {
            New-ConfluenceAPIKey -ApiKey 'test-token'
            { Test-ConfluenceConnection } | Should Throw 'Base URL not configured'
        }

        It 'Error message mentions New-ConfluenceAPIKey when API key missing' {
            New-ConfluenceBaseURL -BaseURL 'https://test.atlassian.net'
            $errorThrown = $null
            try {
                Test-ConfluenceConnection
            } catch {
                $errorThrown = $_.Exception.Message
            }
            $errorThrown | Should Match 'New-ConfluenceAPIKey'
        }

        It 'Error message mentions New-ConfluenceBaseURL when base URL missing' {
            New-ConfluenceAPIKey -ApiKey 'test-token'
            $errorThrown = $null
            try {
                Test-ConfluenceConnection
            } catch {
                $errorThrown = $_.Exception.Message
            }
            $errorThrown | Should Match 'New-ConfluenceBaseURL'
        }
    }

    Context 'Successful Connection' {
        BeforeEach {
            New-ConfluenceAPIKey -ApiKey 'test-token'
            New-ConfluenceBaseURL -BaseURL 'https://test.atlassian.net'

            # Mock successful API response
            Mock Invoke-RestMethod {
                @{
                    results = @(
                        @{
                            id = '123456'
                            key = 'TEST'
                            name = 'Test Space'
                            _links = @{
                                base = 'https://test.atlassian.net/wiki'
                            }
                        }
                    )
                }
            } -ModuleName ConfluenceAPI
        }

        It 'Returns PSCustomObject on success' {
            $result = Test-ConfluenceConnection
            $result | Should BeOfType 'PSCustomObject'
        }

        It 'Returns ConnectionStatus as true' {
            $result = Test-ConfluenceConnection
            $result.ConnectionStatus | Should Be $true
        }

        It 'Returns Message property' {
            $result = Test-ConfluenceConnection
            $result.Message | Should Be 'Successfully connected to Confluence'
        }

        It 'Returns BaseURL in result' {
            $result = Test-ConfluenceConnection
            $result.BaseURL | Should Be 'https://test.atlassian.net'
        }

        It 'Returns CloudId property on success (AC1, AC5)' {
            $result = Test-ConfluenceConnection
            ($result.PSObject.Properties.Name -contains 'CloudId') | Should Be $true
        }

        It 'Calls Invoke-RestMethod with correct URI' {
            Test-ConfluenceConnection
            Assert-MockCalled Invoke-RestMethod -ModuleName ConfluenceAPI -ParameterFilter {
                $Uri -eq 'https://test.atlassian.net/wiki/api/v2/spaces?limit=1'
            }
        }

        It 'Calls Invoke-RestMethod with Authorization header' {
            Test-ConfluenceConnection
            Assert-MockCalled Invoke-RestMethod -ModuleName ConfluenceAPI -ParameterFilter {
                $Headers -and $Headers.ContainsKey('Authorization')
            }
        }

        It 'Calls Invoke-RestMethod with Accept header for JSON' {
            Test-ConfluenceConnection
            Assert-MockCalled Invoke-RestMethod -ModuleName ConfluenceAPI -ParameterFilter {
                $Headers -and $Headers['Accept'] -eq 'application/json'
            }
        }

        It 'Uses GET method' {
            Test-ConfluenceConnection
            Assert-MockCalled Invoke-RestMethod -ModuleName ConfluenceAPI -ParameterFilter {
                $Method -eq 'Get'
            }
        }
    }

    Context 'HTTP Error Handling' {
        BeforeEach {
            New-ConfluenceAPIKey -ApiKey 'test-token'
            New-ConfluenceBaseURL -BaseURL 'https://test.atlassian.net'
        }

        It 'Returns failure object for 401 error with authentication message' {
            Mock Invoke-RestMethod {
                $exception = New-Object System.Net.WebException -ArgumentList 'The remote server returned an error: (401) Unauthorized.'
                throw $exception
            } -ModuleName ConfluenceAPI

            $result = Test-ConfluenceConnection
            $result.ConnectionStatus | Should Be $false
            $result.Message | Should Match 'Authentication failed|Verify your API key'
        }

        It 'Returns failure object for 403 error with forbidden message' {
            Mock Invoke-RestMethod {
                $exception = New-Object System.Net.WebException -ArgumentList 'The remote server returned an error: (403) Forbidden.'
                throw $exception
            } -ModuleName ConfluenceAPI

            $result = Test-ConfluenceConnection
            $result.ConnectionStatus | Should Be $false
            $result.Message | Should Match 'forbidden|permissions'
        }

        It 'Returns failure object for 404 error with URL verification message' {
            Mock Invoke-RestMethod {
                $exception = New-Object System.Net.WebException -ArgumentList 'The remote server returned an error: (404) Not Found.'
                throw $exception
            } -ModuleName ConfluenceAPI

            $result = Test-ConfluenceConnection
            $result.ConnectionStatus | Should Be $false
            $result.Message | Should Match 'not found|Verify your base URL'
        }

        It 'Returns failure object for 500 server error' {
            Mock Invoke-RestMethod {
                $exception = New-Object System.Net.WebException -ArgumentList 'The remote server returned an error: (500) Internal Server Error.'
                throw $exception
            } -ModuleName ConfluenceAPI

            $result = Test-ConfluenceConnection
            $result.ConnectionStatus | Should Be $false
            $result.Message | Should Match 'server error|Try again later'
        }

        It 'Returns failure object with BaseURL property on error' {
            Mock Invoke-RestMethod {
                throw [System.Net.WebException]::new('Connection error')
            } -ModuleName ConfluenceAPI

            $result = Test-ConfluenceConnection
            $result.BaseURL | Should Be 'https://test.atlassian.net'
        }
    }

    Context 'Network Timeout Handling' {
        BeforeEach {
            New-ConfluenceAPIKey -ApiKey 'test-token'
            New-ConfluenceBaseURL -BaseURL 'https://test.atlassian.net'
        }

        It 'Returns meaningful error for timeout' {
            Mock Invoke-RestMethod {
                throw [System.Net.WebException]::new('The operation has timed out')
            } -ModuleName ConfluenceAPI

            $result = Test-ConfluenceConnection
            $result.ConnectionStatus | Should Be $false
            $result.Message | Should Match 'timed out|timeout|network'
        }
    }

    Context 'Security - Token Not Exposed' {
        BeforeEach {
            New-ConfluenceAPIKey -ApiKey 'super-secret-token-12345'
            New-ConfluenceBaseURL -BaseURL 'https://test.atlassian.net'

            Mock Invoke-RestMethod {
                @{ results = @() }
            } -ModuleName ConfluenceAPI
        }

        It 'Result object does not contain API token' {
            $result = Test-ConfluenceConnection
            $result | ConvertTo-Json | Should Not Match 'super-secret-token-12345'
        }

        It 'Verbose output does not contain API token' {
            $verboseOutput = Test-ConfluenceConnection -Verbose 4>&1
            $verboseText = $verboseOutput | Out-String
            $verboseText | Should Not Match 'super-secret-token-12345'
        }
    }

    Context 'Verbose Logging' {
        BeforeEach {
            New-ConfluenceAPIKey -ApiKey 'test-token'
            New-ConfluenceBaseURL -BaseURL 'https://test.atlassian.net'

            Mock Invoke-RestMethod {
                @{ results = @() }
            } -ModuleName ConfluenceAPI
        }

        It 'Writes verbose output for connection attempt' {
            $verboseOutput = Test-ConfluenceConnection -Verbose 4>&1
            $verboseText = $verboseOutput | Out-String
            $verboseText | Should Match 'Testing connection'
        }

        It 'Verbose output shows URL being tested' {
            $verboseOutput = Test-ConfluenceConnection -Verbose 4>&1
            $verboseText = $verboseOutput | Out-String
            $verboseText | Should Match 'test.atlassian.net'
        }
    }
}
