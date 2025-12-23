#Requires -Modules Pester

Describe 'Get-ConfluenceSpace' {
    BeforeAll {
        $ModulePath = (Get-Item "$PSScriptRoot\..\..\ConfluenceAPI.psd1").FullName
        Import-Module $ModulePath -Force
    }

    BeforeEach {
        InModuleScope ConfluenceAPI {
            $script:ConfluenceAPIKey = 'test-token'
            $script:ConfluenceBaseURL = 'https://test.atlassian.net'
        }
    }

    AfterEach {
        InModuleScope ConfluenceAPI {
            $script:ConfluenceAPIKey = $null
            $script:ConfluenceBaseURL = $null
        }
    }

    Context 'Get Single Space' {
        It 'Returns PSCustomObject with correct properties' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    # Use comma operator to preserve single-element array through Pester mock
                    , @(@{
                        id = '123456'
                        key = 'TEST'
                        name = 'Test Space'
                        type = 'global'
                        status = 'current'
                        homepageId = '789012'
                        description = @{ plain = @{ value = 'Test description' } }
                    })
                }

                $result = Get-ConfluenceSpace -SpaceKey 'TEST'
                $result.Key | Should Be 'TEST'
                $result.Id | Should Be '123456'
                $result.Name | Should Be 'Test Space'
                $result.Type | Should Be 'global'
                $result.Status | Should Be 'current'
                $result.HomepageId | Should Be '789012'
                $result.Description | Should Be 'Test description'
            }
        }

        It 'Converts lowercase SpaceKey to uppercase' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    , @(@{
                        id = '123'
                        key = 'TEST'
                        name = 'Test'
                        type = 'global'
                        status = 'current'
                        homepageId = '456'
                    })
                }

                $result = Get-ConfluenceSpace -SpaceKey 'test'
                Assert-MockCalled Invoke-ConfluenceRequest -ParameterFilter {
                    $Endpoint -like '*keys=TEST*'
                }
            }
        }

        It 'Throws 404 error when space not found' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @()
                }

                { Get-ConfluenceSpace -SpaceKey 'NOTFOUND' } | Should Throw 'was not found'
            }
        }

        It 'Handles empty results array' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @{ results = @() }
                }

                { Get-ConfluenceSpace -SpaceKey 'EMPTY' } | Should Throw 'was not found'
            }
        }

        It 'Handles null description gracefully' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    , @(@{
                        id = '123'
                        key = 'TEST'
                        name = 'Test'
                        type = 'global'
                        status = 'current'
                        homepageId = '456'
                        description = $null
                    })
                }

                $result = Get-ConfluenceSpace -SpaceKey 'TEST'
                $result.Description | Should Be $null
            }
        }
    }

    Context 'List All Spaces' {
        It 'Returns array of PSCustomObjects' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @(
                        @{
                            id = '1'
                            key = 'SPACE1'
                            name = 'Space One'
                            type = 'global'
                            status = 'current'
                            homepageId = '101'
                        },
                        @{
                            id = '2'
                            key = 'SPACE2'
                            name = 'Space Two'
                            type = 'global'
                            status = 'current'
                            homepageId = '102'
                        }
                    )
                }

                $result = Get-ConfluenceSpace
                $result.Count | Should Be 2
                $result[0].Key | Should Be 'SPACE1'
                $result[1].Key | Should Be 'SPACE2'
            }
        }

        It 'Returns empty array when no spaces exist' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @()
                }

                $result = Get-ConfluenceSpace
                $result.Count | Should Be 0
            }
        }

        It 'Calls correct endpoint without SpaceKey' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @()
                }

                $result = Get-ConfluenceSpace
                Assert-MockCalled Invoke-ConfluenceRequest -ParameterFilter {
                    $Endpoint -eq '/wiki/api/v2/spaces'
                }
            }
        }

        It 'Handles pagination automatically via Invoke-ConfluenceRequest' {
            InModuleScope ConfluenceAPI {
                # Invoke-ConfluenceRequest handles pagination internally
                # This test verifies we pass through without additional handling
                Mock Invoke-ConfluenceRequest {
                    @(
                        @{ id = '1'; key = 'A'; name = 'A'; type = 'global'; status = 'current'; homepageId = '1' },
                        @{ id = '2'; key = 'B'; name = 'B'; type = 'global'; status = 'current'; homepageId = '2' },
                        @{ id = '3'; key = 'C'; name = 'C'; type = 'global'; status = 'current'; homepageId = '3' }
                    )
                }

                $result = Get-ConfluenceSpace
                $result.Count | Should Be 3
            }
        }
    }

    Context 'Verbose Output' {
        It 'Logs verbose message when getting single space' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    , @(@{
                        id = '123'
                        key = 'TEST'
                        name = 'Test'
                        type = 'global'
                        status = 'current'
                        homepageId = '456'
                    })
                }
                Mock Write-Verbose { } -Verifiable

                $result = Get-ConfluenceSpace -SpaceKey 'TEST' -Verbose
                Assert-MockCalled Write-Verbose
            }
        }

        It 'Verbose output does not contain API token' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    , @(@{
                        id = '123'
                        key = 'TEST'
                        name = 'Test'
                        type = 'global'
                        status = 'current'
                        homepageId = '456'
                    })
                }

                $verboseOutput = @()
                $result = Get-ConfluenceSpace -SpaceKey 'TEST' -Verbose 4>&1 | ForEach-Object {
                    if ($_ -is [System.Management.Automation.VerboseRecord]) {
                        $verboseOutput += $_.Message
                    }
                }

                foreach ($msg in $verboseOutput) {
                    $msg | Should Not Match 'test-token'
                }
            }
        }
    }

    Context 'Error Handling' {
        It 'Throws terminating error on API failure' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    throw [System.Exception]::new('Connection failed')
                }

                { Get-ConfluenceSpace -SpaceKey 'TEST' } | Should Throw 'Failed to get space'
            }
        }

        It 'Includes SpaceKey in error message' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @()
                }

                try {
                    Get-ConfluenceSpace -SpaceKey 'MYSPACE'
                }
                catch {
                    $_.Exception.Message | Should Match 'MYSPACE'
                }
            }
        }
    }

    Context 'Property Mapping' {
        It 'Maps all expected properties from API response' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    , @(@{
                        id = '999'
                        key = 'PROPS'
                        name = 'Properties Test'
                        type = 'personal'
                        status = 'archived'
                        homepageId = '888'
                        description = @{ plain = @{ value = 'Description here' } }
                    })
                }

                $result = Get-ConfluenceSpace -SpaceKey 'PROPS'
                $propNames = $result.PSObject.Properties.Name

                ($propNames -contains 'Id') | Should Be $true
                ($propNames -contains 'Key') | Should Be $true
                ($propNames -contains 'Name') | Should Be $true
                ($propNames -contains 'Type') | Should Be $true
                ($propNames -contains 'Status') | Should Be $true
                ($propNames -contains 'HomepageId') | Should Be $true
                ($propNames -contains 'Description') | Should Be $true
            }
        }
    }
}
