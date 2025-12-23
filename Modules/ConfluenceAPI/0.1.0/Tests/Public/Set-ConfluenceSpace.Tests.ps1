#Requires -Modules Pester

Describe 'Set-ConfluenceSpace' {
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

    Context 'Update Space Name' {
        It 'Updates space name successfully' {
            InModuleScope ConfluenceAPI {
                $script:mockCallCount = 0
                Mock Invoke-ConfluenceRequest {
                    $script:mockCallCount++
                    if ($script:mockCallCount -eq 1) {
                        # Lookup call - use comma to preserve array
                        , @(@{
                            id = '123456'
                            key = 'TEST'
                            name = 'Old Name'
                            type = 'global'
                            status = 'current'
                            homepageId = '789'
                        })
                    } else {
                        # Update call
                        @{
                            id = '123456'
                            key = 'TEST'
                            name = 'New Name'
                            type = 'global'
                            status = 'current'
                            homepageId = '789'
                        }
                    }
                }

                $result = Set-ConfluenceSpace -SpaceKey 'TEST' -Name 'New Name'
                $result.Name | Should Be 'New Name'
            }
        }

        It 'Sends PUT request with name in body' {
            InModuleScope ConfluenceAPI {
                $script:mockCallCount = 0
                Mock Invoke-ConfluenceRequest {
                    $script:mockCallCount++
                    if ($script:mockCallCount -eq 1) {
                        , @(@{ id = '123'; key = 'TEST'; name = 'Old'; type = 'global'; status = 'current'; homepageId = '456' })
                    } else {
                        @{ id = '123'; key = 'TEST'; name = 'New'; type = 'global'; status = 'current'; homepageId = '456' }
                    }
                }

                $result = Set-ConfluenceSpace -SpaceKey 'TEST' -Name 'New'
                Assert-MockCalled Invoke-ConfluenceRequest -ParameterFilter {
                    $Method -eq 'PUT' -and $Body -match '"name":\s*"New"'
                }
            }
        }
    }

    Context 'Update Space Description' {
        It 'Updates space description successfully' {
            InModuleScope ConfluenceAPI {
                $script:mockCallCount = 0
                Mock Invoke-ConfluenceRequest {
                    $script:mockCallCount++
                    if ($script:mockCallCount -eq 1) {
                        , @(@{ id = '123'; key = 'TEST'; name = 'Test'; type = 'global'; status = 'current'; homepageId = '456' })
                    } else {
                        @{
                            id = '123'
                            key = 'TEST'
                            name = 'Test'
                            type = 'global'
                            status = 'current'
                            homepageId = '456'
                            description = @{ plain = @{ value = 'New description' } }
                        }
                    }
                }

                $result = Set-ConfluenceSpace -SpaceKey 'TEST' -Description 'New description'
                Assert-MockCalled Invoke-ConfluenceRequest -ParameterFilter {
                    $Method -eq 'PUT' -and $Body -match 'New description'
                }
            }
        }
    }

    Context 'WhatIf Support' {
        It 'Does not call API when WhatIf is used (except lookup)' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    , @(@{ id = '123'; key = 'TEST'; name = 'Test'; type = 'global'; status = 'current'; homepageId = '456' })
                }

                $result = Set-ConfluenceSpace -SpaceKey 'TEST' -Name 'New Name' -WhatIf
                # Should call lookup but NOT update
                Assert-MockCalled Invoke-ConfluenceRequest -ParameterFilter { $Method -eq 'GET' } -Times 1
                Assert-MockCalled Invoke-ConfluenceRequest -ParameterFilter { $Method -eq 'PUT' } -Times 0
            }
        }

        It 'Returns null when WhatIf is used' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    , @(@{ id = '123'; key = 'TEST'; name = 'Test'; type = 'global'; status = 'current'; homepageId = '456' })
                }

                $result = Set-ConfluenceSpace -SpaceKey 'TEST' -Name 'New Name' -WhatIf
                $result | Should Be $null
            }
        }
    }

    Context 'Return Type' {
        It 'Returns updated PSCustomObject' {
            InModuleScope ConfluenceAPI {
                $script:mockCallCount = 0
                Mock Invoke-ConfluenceRequest {
                    $script:mockCallCount++
                    if ($script:mockCallCount -eq 1) {
                        , @(@{ id = '123'; key = 'TEST'; name = 'Old'; type = 'global'; status = 'current'; homepageId = '456' })
                    } else {
                        @{ id = '123'; key = 'TEST'; name = 'Updated'; type = 'global'; status = 'current'; homepageId = '456' }
                    }
                }

                $result = Set-ConfluenceSpace -SpaceKey 'TEST' -Name 'Updated'
                $propNames = $result.PSObject.Properties.Name

                ($propNames -contains 'Id') | Should Be $true
                ($propNames -contains 'Key') | Should Be $true
                ($propNames -contains 'Name') | Should Be $true
                ($propNames -contains 'Type') | Should Be $true
                ($propNames -contains 'Status') | Should Be $true
                ($propNames -contains 'HomepageId') | Should Be $true
            }
        }
    }

    Context 'Parameter Validation' {
        It 'Throws error when no update parameters provided' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest { }

                { Set-ConfluenceSpace -SpaceKey 'TEST' } | Should Throw 'At least one update parameter'
            }
        }

        It 'Accepts Name parameter alone' {
            InModuleScope ConfluenceAPI {
                $script:mockCallCount = 0
                Mock Invoke-ConfluenceRequest {
                    $script:mockCallCount++
                    if ($script:mockCallCount -eq 1) {
                        , @(@{ id = '123'; key = 'TEST'; name = 'Old'; type = 'global'; status = 'current'; homepageId = '456' })
                    } else {
                        @{ id = '123'; key = 'TEST'; name = 'New'; type = 'global'; status = 'current'; homepageId = '456' }
                    }
                }

                { Set-ConfluenceSpace -SpaceKey 'TEST' -Name 'New' } | Should Not Throw
            }
        }

        It 'Accepts Description parameter alone' {
            InModuleScope ConfluenceAPI {
                $script:mockCallCount = 0
                Mock Invoke-ConfluenceRequest {
                    $script:mockCallCount++
                    if ($script:mockCallCount -eq 1) {
                        , @(@{ id = '123'; key = 'TEST'; name = 'Test'; type = 'global'; status = 'current'; homepageId = '456' })
                    } else {
                        @{ id = '123'; key = 'TEST'; name = 'Test'; type = 'global'; status = 'current'; homepageId = '456' }
                    }
                }

                { Set-ConfluenceSpace -SpaceKey 'TEST' -Description 'New desc' } | Should Not Throw
            }
        }

        It 'Accepts HomepageId parameter alone' {
            InModuleScope ConfluenceAPI {
                $script:mockCallCount = 0
                Mock Invoke-ConfluenceRequest {
                    $script:mockCallCount++
                    if ($script:mockCallCount -eq 1) {
                        , @(@{ id = '123'; key = 'TEST'; name = 'Test'; type = 'global'; status = 'current'; homepageId = '456' })
                    } else {
                        @{ id = '123'; key = 'TEST'; name = 'Test'; type = 'global'; status = 'current'; homepageId = '999' }
                    }
                }

                { Set-ConfluenceSpace -SpaceKey 'TEST' -HomepageId '999' } | Should Not Throw
            }
        }
    }

    Context 'Space ID Lookup' {
        It 'Looks up space ID from key before update' {
            InModuleScope ConfluenceAPI {
                $script:mockCallCount = 0
                Mock Invoke-ConfluenceRequest {
                    $script:mockCallCount++
                    if ($script:mockCallCount -eq 1) {
                        , @(@{ id = '123456'; key = 'TEST'; name = 'Test'; type = 'global'; status = 'current'; homepageId = '456' })
                    } else {
                        @{ id = '123456'; key = 'TEST'; name = 'New'; type = 'global'; status = 'current'; homepageId = '456' }
                    }
                }

                $result = Set-ConfluenceSpace -SpaceKey 'TEST' -Name 'New'

                # Verify lookup was called
                Assert-MockCalled Invoke-ConfluenceRequest -ParameterFilter {
                    $Endpoint -like '*keys=TEST*' -and $Method -eq 'GET'
                }
            }
        }

        It 'Throws error when space not found' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @()
                }

                { Set-ConfluenceSpace -SpaceKey 'NOTFOUND' -Name 'New' } | Should Throw 'was not found'
            }
        }
    }

    Context 'Error Handling' {
        It 'Throws terminating error on API failure' {
            InModuleScope ConfluenceAPI {
                $script:mockCallCount = 0
                Mock Invoke-ConfluenceRequest {
                    $script:mockCallCount++
                    if ($script:mockCallCount -eq 1) {
                        , @(@{ id = '123'; key = 'TEST'; name = 'Test'; type = 'global'; status = 'current'; homepageId = '456' })
                    } else {
                        throw [System.Exception]::new('API error')
                    }
                }

                { Set-ConfluenceSpace -SpaceKey 'TEST' -Name 'New' } | Should Throw 'Failed to update space'
            }
        }
    }
}
