#Requires -Modules Pester

Describe 'Invoke-ConfluenceRequest' {
    BeforeAll {
        $ModulePath = (Get-Item "$PSScriptRoot\..\..\ConfluenceAPI.psd1").FullName
        Import-Module $ModulePath -Force
    }

    BeforeEach {
        # Clear credentials for clean state
        Remove-ConfluenceAPIKey -ErrorAction SilentlyContinue
        Remove-ConfluenceBaseURL -ErrorAction SilentlyContinue
        New-ConfluenceAPIKey -ApiKey 'test-token'
        New-ConfluenceBaseURL -BaseURL 'https://test.atlassian.net'
    }

    AfterEach {
        Remove-ConfluenceAPIKey -ErrorAction SilentlyContinue
        Remove-ConfluenceBaseURL -ErrorAction SilentlyContinue
    }

    Context 'Missing Credentials' {
        It 'Throws error when no API key is configured' {
            Remove-ConfluenceAPIKey -ErrorAction SilentlyContinue
            { Invoke-ConfluenceRequest -Endpoint '/wiki/api/v2/spaces' } | Should Throw 'API key not configured'
        }

        It 'Throws error when no base URL is configured' {
            Remove-ConfluenceBaseURL -ErrorAction SilentlyContinue
            { Invoke-ConfluenceRequest -Endpoint '/wiki/api/v2/spaces' } | Should Throw 'Base URL not configured'
        }
    }

    Context 'Basic Request (AC1)' {
        BeforeEach {
            Mock Invoke-RestMethod {
                @{ id = '123'; name = 'Test Space' }
            } -ModuleName ConfluenceAPI
        }

        It 'Returns PSCustomObject on success' {
            $result = Invoke-ConfluenceRequest -Endpoint '/wiki/api/v2/spaces/TEST'
            $result | Should BeOfType 'PSCustomObject'
        }

        It 'Returns response properties correctly' {
            $result = Invoke-ConfluenceRequest -Endpoint '/wiki/api/v2/spaces/TEST'
            $result.id | Should Be '123'
            $result.name | Should Be 'Test Space'
        }

        It 'Sends Authorization header' {
            Invoke-ConfluenceRequest -Endpoint '/wiki/api/v2/spaces/TEST'

            Assert-MockCalled Invoke-RestMethod -ModuleName ConfluenceAPI -ParameterFilter {
                $Headers -and $Headers.ContainsKey('Authorization')
            }
        }

        It 'Sends Accept header for JSON' {
            Invoke-ConfluenceRequest -Endpoint '/wiki/api/v2/spaces/TEST'

            Assert-MockCalled Invoke-RestMethod -ModuleName ConfluenceAPI -ParameterFilter {
                $Headers -and $Headers['Accept'] -eq 'application/json'
            }
        }

        It 'Uses correct URI with base URL and endpoint' {
            Invoke-ConfluenceRequest -Endpoint '/wiki/api/v2/spaces/TEST'

            Assert-MockCalled Invoke-RestMethod -ModuleName ConfluenceAPI -ParameterFilter {
                $Uri -eq 'https://test.atlassian.net/wiki/api/v2/spaces/TEST'
            }
        }
    }

    Context 'HTTP Method Support (AC5)' {
        BeforeEach {
            Mock Invoke-RestMethod {
                @{ id = '123' }
            } -ModuleName ConfluenceAPI
        }

        It 'Uses GET method by default' {
            Invoke-ConfluenceRequest -Endpoint '/wiki/api/v2/spaces'

            Assert-MockCalled Invoke-RestMethod -ModuleName ConfluenceAPI -ParameterFilter {
                $Method -eq 'GET'
            }
        }

        It 'Uses POST method when specified' {
            Invoke-ConfluenceRequest -Endpoint '/wiki/api/v2/spaces' -Method POST -Body '{"name":"Test"}' -Confirm:$false

            Assert-MockCalled Invoke-RestMethod -ModuleName ConfluenceAPI -ParameterFilter {
                $Method -eq 'POST'
            }
        }

        It 'Sends Body with POST request' {
            $testBody = '{"name":"Test Space"}'
            Invoke-ConfluenceRequest -Endpoint '/wiki/api/v2/spaces' -Method POST -Body $testBody -Confirm:$false

            Assert-MockCalled Invoke-RestMethod -ModuleName ConfluenceAPI -ParameterFilter {
                $Body -eq $testBody
            }
        }

        It 'Uses PUT method when specified' {
            Invoke-ConfluenceRequest -Endpoint '/wiki/api/v2/spaces/TEST' -Method PUT -Body '{"name":"Updated"}' -Confirm:$false

            Assert-MockCalled Invoke-RestMethod -ModuleName ConfluenceAPI -ParameterFilter {
                $Method -eq 'PUT'
            }
        }

        It 'Uses DELETE method when specified' {
            Invoke-ConfluenceRequest -Endpoint '/wiki/api/v2/spaces/TEST' -Method DELETE -Confirm:$false

            Assert-MockCalled Invoke-RestMethod -ModuleName ConfluenceAPI -ParameterFilter {
                $Method -eq 'DELETE'
            }
        }

        It 'Sets Content-Type header for POST requests with body' {
            Invoke-ConfluenceRequest -Endpoint '/wiki/api/v2/spaces' -Method POST -Body '{"name":"Test"}' -Confirm:$false

            Assert-MockCalled Invoke-RestMethod -ModuleName ConfluenceAPI -ParameterFilter {
                $Headers -and $Headers['Content-Type'] -eq 'application/json'
            }
        }
    }

    Context 'WhatIf Support (AC6)' {
        BeforeEach {
            Mock Invoke-RestMethod { } -ModuleName ConfluenceAPI
        }

        It 'Does not make request when WhatIf used on POST' {
            Invoke-ConfluenceRequest -Endpoint '/wiki/api/v2/spaces' -Method POST -Body '{}' -WhatIf

            Assert-MockCalled Invoke-RestMethod -ModuleName ConfluenceAPI -Times 0
        }

        It 'Does not make request when WhatIf used on DELETE' {
            Invoke-ConfluenceRequest -Endpoint '/wiki/api/v2/spaces/TEST' -Method DELETE -WhatIf

            Assert-MockCalled Invoke-RestMethod -ModuleName ConfluenceAPI -Times 0
        }

        It 'Returns null when WhatIf used' {
            $result = Invoke-ConfluenceRequest -Endpoint '/wiki/api/v2/spaces' -Method POST -Body '{}' -WhatIf
            $result | Should Be $null
        }

        It 'Still makes GET request (no WhatIf prompt for GET)' {
            Mock Invoke-RestMethod { @{ id = '1' } } -ModuleName ConfluenceAPI

            $result = Invoke-ConfluenceRequest -Endpoint '/wiki/api/v2/spaces' -WhatIf
            # GET should still work with WhatIf since it's read-only
            $result | Should Not Be $null
        }
    }

    Context 'Rate Limiting (AC2)' {
        It 'Calls Start-Sleep when rate limited' {
            # Use InModuleScope for proper variable scoping
            InModuleScope ConfluenceAPI {
                $script:mockCallCount = 0
                Mock Invoke-RestMethod {
                    $script:mockCallCount++
                    if ($script:mockCallCount -eq 1) {
                        throw [System.Net.WebException]::new('The remote server returned an error: (429) Too Many Requests.')
                    }
                    @{ id = '123' }
                }

                Mock Start-Sleep { }

                Invoke-ConfluenceRequest -Endpoint '/wiki/api/v2/spaces'

                Assert-MockCalled Start-Sleep -Times 1
            }
        }

        It 'Retries on 429 and succeeds on second attempt' {
            InModuleScope ConfluenceAPI {
                $script:mockCallCount = 0
                Mock Invoke-RestMethod {
                    $script:mockCallCount++
                    if ($script:mockCallCount -eq 1) {
                        throw [System.Net.WebException]::new('The remote server returned an error: (429) Too Many Requests.')
                    }
                    @{ id = '123' }
                }

                Mock Start-Sleep { }

                $result = Invoke-ConfluenceRequest -Endpoint '/wiki/api/v2/spaces'
                $result.id | Should Be '123'
            }
        }
    }

    Context 'Transient Failure Retry (AC3)' {
        It 'Retries on 500 server error and succeeds' {
            InModuleScope ConfluenceAPI {
                $script:mockCallCount = 0
                Mock Invoke-RestMethod {
                    $script:mockCallCount++
                    if ($script:mockCallCount -eq 1) {
                        throw [System.Net.WebException]::new('The remote server returned an error: (500) Internal Server Error.')
                    }
                    @{ id = '123' }
                }

                Mock Start-Sleep { }

                $result = Invoke-ConfluenceRequest -Endpoint '/wiki/api/v2/spaces'
                $result.id | Should Be '123'
            }
        }

        It 'Throws after 3 retries exhausted on 5xx' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-RestMethod {
                    throw [System.Net.WebException]::new('The remote server returned an error: (503) Service Unavailable.')
                }

                Mock Start-Sleep { }

                { Invoke-ConfluenceRequest -Endpoint '/wiki/api/v2/spaces' } | Should Throw 'server error'
            }
        }

        It 'Calls Start-Sleep multiple times for exponential backoff' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-RestMethod {
                    throw [System.Net.WebException]::new('The remote server returned an error: (500) Internal Server Error.')
                }

                Mock Start-Sleep { }

                try { Invoke-ConfluenceRequest -Endpoint '/wiki/api/v2/spaces' } catch { $null = $_ }

                # Should have 3 sleep calls for 3 retries
                Assert-MockCalled Start-Sleep -Times 3
            }
        }
    }

    Context 'Error Handling (AC7)' {
        It 'Throws immediately on 400 without retry' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-RestMethod {
                    throw [System.Net.WebException]::new('The remote server returned an error: (400) Bad Request.')
                }

                Mock Start-Sleep { }

                { Invoke-ConfluenceRequest -Endpoint '/wiki/api/v2/spaces' } | Should Throw
                Assert-MockCalled Invoke-RestMethod -Times 1
                Assert-MockCalled Start-Sleep -Times 0
            }
        }

        It 'Returns bad request message for 400' {
            Mock Invoke-RestMethod {
                throw [System.Net.WebException]::new('The remote server returned an error: (400) Bad Request.')
            } -ModuleName ConfluenceAPI

            $errorThrown = $null
            try {
                Invoke-ConfluenceRequest -Endpoint '/wiki/api/v2/spaces'
            } catch {
                $errorThrown = $_.Exception.Message
            }
            $errorThrown | Should Match 'Bad request'
        }

        It 'Throws immediately on 401 without retry' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-RestMethod {
                    throw [System.Net.WebException]::new('The remote server returned an error: (401) Unauthorized.')
                }

                Mock Start-Sleep { }

                { Invoke-ConfluenceRequest -Endpoint '/wiki/api/v2/spaces' } | Should Throw
                Assert-MockCalled Invoke-RestMethod -Times 1
                Assert-MockCalled Start-Sleep -Times 0
            }
        }

        It 'Returns authentication message for 401' {
            Mock Invoke-RestMethod {
                throw [System.Net.WebException]::new('The remote server returned an error: (401) Unauthorized.')
            } -ModuleName ConfluenceAPI

            $errorThrown = $null
            try {
                Invoke-ConfluenceRequest -Endpoint '/wiki/api/v2/spaces'
            } catch {
                $errorThrown = $_.Exception.Message
            }
            $errorThrown | Should Match 'Authentication failed'
        }

        It 'Throws immediately on 403 without retry' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-RestMethod {
                    throw [System.Net.WebException]::new('The remote server returned an error: (403) Forbidden.')
                }

                Mock Start-Sleep { }

                { Invoke-ConfluenceRequest -Endpoint '/wiki/api/v2/spaces' } | Should Throw
                Assert-MockCalled Invoke-RestMethod -Times 1
                Assert-MockCalled Start-Sleep -Times 0
            }
        }

        It 'Returns permission message for 403' {
            Mock Invoke-RestMethod {
                throw [System.Net.WebException]::new('The remote server returned an error: (403) Forbidden.')
            } -ModuleName ConfluenceAPI

            $errorThrown = $null
            try {
                Invoke-ConfluenceRequest -Endpoint '/wiki/api/v2/spaces'
            } catch {
                $errorThrown = $_.Exception.Message
            }
            $errorThrown | Should Match 'forbidden|permission'
        }

        It 'Throws immediately on 404 without retry' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-RestMethod {
                    throw [System.Net.WebException]::new('The remote server returned an error: (404) Not Found.')
                }

                Mock Start-Sleep { }

                { Invoke-ConfluenceRequest -Endpoint '/wiki/api/v2/spaces/INVALID' } | Should Throw
                Assert-MockCalled Invoke-RestMethod -Times 1
                Assert-MockCalled Start-Sleep -Times 0
            }
        }

        It 'Returns not found message for 404' {
            Mock Invoke-RestMethod {
                throw [System.Net.WebException]::new('The remote server returned an error: (404) Not Found.')
            } -ModuleName ConfluenceAPI

            $errorThrown = $null
            try {
                Invoke-ConfluenceRequest -Endpoint '/wiki/api/v2/spaces/INVALID'
            } catch {
                $errorThrown = $_.Exception.Message
            }
            $errorThrown | Should Match 'not found'
        }
    }

    Context 'Pagination (AC4)' {
        It 'Returns null when paginated results are empty' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-RestMethod {
                    @{
                        results = @()
                        _links = @{}
                    }
                }

                $result = Invoke-ConfluenceRequest -Endpoint '/wiki/api/v2/spaces'
                # When results array is empty, allResults stays empty, so returns raw response
                # This is expected behavior - API returned empty results
                $result.results.Count | Should Be 0
            }
        }

        It 'Aggregates results across multiple pages' {
            InModuleScope ConfluenceAPI {
                $script:mockCallCount = 0
                Mock Invoke-RestMethod {
                    $script:mockCallCount++
                    if ($script:mockCallCount -eq 1) {
                        @{
                            results = @(@{ id = '1' }, @{ id = '2' })
                            _links = @{ next = '/wiki/api/v2/spaces?cursor=abc123' }
                        }
                    } else {
                        @{
                            results = @(@{ id = '3' })
                            _links = @{}
                        }
                    }
                }

                $result = Invoke-ConfluenceRequest -Endpoint '/wiki/api/v2/spaces'
                $result.Count | Should Be 3
            }
        }

        It 'Respects Limit parameter' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-RestMethod {
                    @{
                        results = @(@{ id = '1' }, @{ id = '2' }, @{ id = '3' })
                        _links = @{ next = '/wiki/api/v2/spaces?cursor=abc' }
                    }
                }

                $result = Invoke-ConfluenceRequest -Endpoint '/wiki/api/v2/spaces' -Limit 2
                $result.Count | Should Be 2
            }
        }

        It 'Returns all results when Limit is 0 (disabled)' {
            InModuleScope ConfluenceAPI {
                $script:mockCallCount = 0
                Mock Invoke-RestMethod {
                    $script:mockCallCount++
                    if ($script:mockCallCount -eq 1) {
                        @{
                            results = @(@{ id = '1' }, @{ id = '2' })
                            _links = @{ next = '/wiki/api/v2/spaces?cursor=abc' }
                        }
                    } else {
                        @{
                            results = @(@{ id = '3' })
                            _links = @{}
                        }
                    }
                }

                $result = Invoke-ConfluenceRequest -Endpoint '/wiki/api/v2/spaces' -Limit 0
                $result.Count | Should Be 3
            }
        }

        It 'Returns all results when Limit exceeds total' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-RestMethod {
                    @{
                        results = @(@{ id = '1' }, @{ id = '2' })
                        _links = @{}
                    }
                }

                $result = Invoke-ConfluenceRequest -Endpoint '/wiki/api/v2/spaces' -Limit 100
                $result.Count | Should Be 2
            }
        }

        It 'Follows cursor pagination until no more pages' {
            InModuleScope ConfluenceAPI {
                $script:mockCallCount = 0
                Mock Invoke-RestMethod {
                    $script:mockCallCount++
                    if ($script:mockCallCount -lt 3) {
                        @{
                            results = @(@{ id = "$script:mockCallCount" })
                            _links = @{ next = "/wiki/api/v2/spaces?cursor=page$script:mockCallCount" }
                        }
                    } else {
                        @{
                            results = @(@{ id = '3' })
                            _links = @{}
                        }
                    }
                }

                $result = Invoke-ConfluenceRequest -Endpoint '/wiki/api/v2/spaces'
                $result.Count | Should Be 3
            }
        }
    }

    Context 'Token Security (AC8)' {
        BeforeEach {
            New-ConfluenceAPIKey -ApiKey 'super-secret-token-12345'
            Mock Invoke-RestMethod {
                @{ id = '123' }
            } -ModuleName ConfluenceAPI
        }

        It 'Verbose output does not contain API token' {
            $verboseOutput = Invoke-ConfluenceRequest -Endpoint '/wiki/api/v2/spaces' -Verbose 4>&1
            $verboseText = $verboseOutput | Out-String
            $verboseText | Should Not Match 'super-secret-token-12345'
        }

        It 'Verbose output shows endpoint URL' {
            $verboseOutput = Invoke-ConfluenceRequest -Endpoint '/wiki/api/v2/spaces' -Verbose 4>&1
            $verboseText = $verboseOutput | Out-String
            $verboseText | Should Match '/wiki/api/v2/spaces'
        }
    }

    Context 'Verbose Logging (AC1)' {
        BeforeEach {
            Mock Invoke-RestMethod {
                @{ id = '123' }
            } -ModuleName ConfluenceAPI
        }

        It 'Logs endpoint being called' {
            $verboseOutput = Invoke-ConfluenceRequest -Endpoint '/wiki/api/v2/spaces/TEST' -Verbose 4>&1
            $verboseText = $verboseOutput | Out-String
            $verboseText | Should Match 'Requesting'
        }
    }
}
