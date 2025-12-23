#Requires -Modules Pester

Describe 'Remove-ConfluenceSpace' {
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

    Context 'Delete Space with Force' {
        It 'Deletes space when Force is specified' {
            InModuleScope ConfluenceAPI {
                $script:mockCallCount = 0
                Mock Invoke-ConfluenceRequest {
                    $script:mockCallCount++
                    if ($script:mockCallCount -eq 1) {
                        # Lookup call - use comma to preserve array
                        , @(@{
                            id = '123456'
                            key = 'TEST'
                            name = 'Test Space'
                            type = 'global'
                            status = 'current'
                            homepageId = '789'
                        })
                    } else {
                        # Delete call returns null/empty
                        $null
                    }
                }

                { Remove-ConfluenceSpace -SpaceKey 'TEST' -Force -Confirm:$false } | Should Not Throw
                Assert-MockCalled Invoke-ConfluenceRequest -ParameterFilter {
                    $Method -eq 'DELETE'
                }
            }
        }

        It 'Sends DELETE request to correct endpoint with space ID' {
            InModuleScope ConfluenceAPI {
                $script:mockCallCount = 0
                $script:capturedEndpoint = $null
                Mock Invoke-ConfluenceRequest {
                    $script:mockCallCount++
                    if ($script:mockCallCount -eq 1) {
                        , @(@{ id = '123456'; key = 'TEST'; name = 'Test'; type = 'global'; status = 'current'; homepageId = '456' })
                    } else {
                        $script:capturedEndpoint = $Endpoint
                        $null
                    }
                }

                Remove-ConfluenceSpace -SpaceKey 'TEST' -Force -Confirm:$false
                # Verify we called with DELETE method
                Assert-MockCalled Invoke-ConfluenceRequest -ParameterFilter {
                    $Method -eq 'DELETE'
                }
                # Verify endpoint contained the space ID
                $script:capturedEndpoint | Should Match '123456'
            }
        }
    }

    Context 'WhatIf Support' {
        It 'Does not call DELETE API when WhatIf is used' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    , @(@{ id = '123'; key = 'TEST'; name = 'Test'; type = 'global'; status = 'current'; homepageId = '456' })
                }

                Remove-ConfluenceSpace -SpaceKey 'TEST' -WhatIf
                # Should only call lookup, not delete
                Assert-MockCalled Invoke-ConfluenceRequest -ParameterFilter { $Method -eq 'GET' } -Times 1
                Assert-MockCalled Invoke-ConfluenceRequest -ParameterFilter { $Method -eq 'DELETE' } -Times 0
            }
        }
    }

    Context 'Confirm Behavior' {
        It 'Has ConfirmImpact High' {
            $commandInfo = Get-Command Remove-ConfluenceSpace -Module ConfluenceAPI
            $confirmImpact = $commandInfo.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] } | ForEach-Object { $_.ConfirmImpact }
            $confirmImpact | Should Be 'High'
        }

        It 'Supports ShouldProcess' {
            $commandInfo = Get-Command Remove-ConfluenceSpace -Module ConfluenceAPI
            $supportsShouldProcess = $commandInfo.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] } | ForEach-Object { $_.SupportsShouldProcess }
            $supportsShouldProcess | Should Be $true
        }
    }

    Context 'Space ID Lookup' {
        It 'Looks up space ID from key before delete' {
            InModuleScope ConfluenceAPI {
                $script:mockCallCount = 0
                Mock Invoke-ConfluenceRequest {
                    $script:mockCallCount++
                    if ($script:mockCallCount -eq 1) {
                        , @(@{ id = '999888'; key = 'LOOKUP'; name = 'Test'; type = 'global'; status = 'current'; homepageId = '456' })
                    } else {
                        $null
                    }
                }

                Remove-ConfluenceSpace -SpaceKey 'LOOKUP' -Force -Confirm:$false

                # First call should be lookup by key
                Assert-MockCalled Invoke-ConfluenceRequest -ParameterFilter {
                    $Endpoint -like '*keys=LOOKUP*'
                }
            }
        }

        It 'Throws error when space not found' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @()
                }

                { Remove-ConfluenceSpace -SpaceKey 'NOTFOUND' -Force -Confirm:$false } | Should Throw 'was not found'
            }
        }

        It 'Handles empty results array' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @{ results = @() }
                }

                { Remove-ConfluenceSpace -SpaceKey 'EMPTY' -Force -Confirm:$false } | Should Throw 'was not found'
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
                        throw [System.Exception]::new('Delete failed')
                    }
                }

                { Remove-ConfluenceSpace -SpaceKey 'TEST' -Force -Confirm:$false } | Should Throw 'Failed to delete space'
            }
        }

        It 'Includes SpaceKey in error message' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @()
                }

                try {
                    Remove-ConfluenceSpace -SpaceKey 'MYSPACE' -Force -Confirm:$false
                }
                catch {
                    $_.Exception.Message | Should Match 'MYSPACE'
                }
            }
        }
    }

    Context 'Verbose Logging' {
        It 'Logs verbose message during delete' {
            InModuleScope ConfluenceAPI {
                $script:mockCallCount = 0
                Mock Invoke-ConfluenceRequest {
                    $script:mockCallCount++
                    if ($script:mockCallCount -eq 1) {
                        , @(@{ id = '123'; key = 'TEST'; name = 'Test'; type = 'global'; status = 'current'; homepageId = '456' })
                    } else {
                        $null
                    }
                }
                Mock Write-Verbose { } -Verifiable

                Remove-ConfluenceSpace -SpaceKey 'TEST' -Force -Confirm:$false -Verbose
                Assert-MockCalled Write-Verbose
            }
        }
    }

    Context 'SpaceKey Handling' {
        It 'Converts lowercase SpaceKey to uppercase' {
            InModuleScope ConfluenceAPI {
                $script:mockCallCount = 0
                Mock Invoke-ConfluenceRequest {
                    $script:mockCallCount++
                    if ($script:mockCallCount -eq 1) {
                        , @(@{ id = '123'; key = 'TEST'; name = 'Test'; type = 'global'; status = 'current'; homepageId = '456' })
                    } else {
                        $null
                    }
                }

                Remove-ConfluenceSpace -SpaceKey 'test' -Force -Confirm:$false
                Assert-MockCalled Invoke-ConfluenceRequest -ParameterFilter {
                    $Endpoint -like '*keys=TEST*'
                }
            }
        }
    }
}
