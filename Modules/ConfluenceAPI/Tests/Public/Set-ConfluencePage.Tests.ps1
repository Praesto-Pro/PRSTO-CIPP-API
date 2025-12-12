#Requires -Modules Pester

Describe 'Set-ConfluencePage' {
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

    Context 'Update Page Title' {
        It 'Fetches current version before update' {
            InModuleScope ConfluenceAPI {
                $script:mockCallCount = 0
                Mock Invoke-ConfluenceRequest {
                    $script:mockCallCount++
                    if ($script:mockCallCount -eq 1) {
                        # GET call for current page
                        @{
                            id      = '123'
                            title   = 'Old Title'
                            spaceId = '456'
                            status  = 'current'
                            version = @{ number = 5 }
                            body    = @{ storage = @{ value = '<p>Content</p>' } }
                        }
                    } else {
                        # PUT call for update
                        @{
                            id      = '123'
                            title   = 'New Title'
                            spaceId = '456'
                            status  = 'current'
                            version = @{ number = 6 }
                        }
                    }
                }

                $result = Set-ConfluencePage -PageId '123' -Title 'New Title'
                Assert-MockCalled Invoke-ConfluenceRequest -Times 2
            }
        }

        It 'Increments version number by 1' {
            InModuleScope ConfluenceAPI {
                $script:mockCallCount = 0
                Mock Invoke-ConfluenceRequest {
                    param($Endpoint, $Method, $Body)
                    $script:mockCallCount++
                    if ($script:mockCallCount -eq 1) {
                        # GET
                        @{
                            id      = '123'
                            title   = 'Old'
                            spaceId = '456'
                            status  = 'current'
                            version = @{ number = 10 }
                            body    = @{ storage = @{ value = 'content' } }
                        }
                    } else {
                        # PUT - verify version
                        $bodyObj = $Body | ConvertFrom-Json
                        if ($bodyObj.version.number -ne 11) {
                            throw "Version should be 11, got $($bodyObj.version.number)"
                        }
                        @{
                            id      = '123'
                            title   = 'New Title'
                            spaceId = '456'
                            status  = 'current'
                            version = @{ number = 11 }
                        }
                    }
                }

                $result = Set-ConfluencePage -PageId '123' -Title 'New Title'
                $result.Version | Should Be 11
            }
        }

        It 'Returns updated PSCustomObject' {
            InModuleScope ConfluenceAPI {
                $script:mockCallCount = 0
                Mock Invoke-ConfluenceRequest {
                    $script:mockCallCount++
                    if ($script:mockCallCount -eq 1) {
                        @{
                            id      = '123'
                            title   = 'Old'
                            spaceId = '456'
                            status  = 'current'
                            version = @{ number = 1 }
                            body    = @{ storage = @{ value = 'content' } }
                        }
                    } else {
                        @{
                            id         = '123'
                            title      = 'Updated Title'
                            spaceId    = '456'
                            status     = 'current'
                            parentId   = $null
                            parentType = $null
                            authorId   = 'author'
                            createdAt  = '2025-12-11T00:00:00Z'
                            version    = @{ number = 2 }
                        }
                    }
                }

                $result = Set-ConfluencePage -PageId '123' -Title 'Updated Title'
                $result.Title | Should Be 'Updated Title'
                $result.Version | Should Be 2
            }
        }
    }

    Context 'Update Page Body' {
        It 'Updates body content' {
            InModuleScope ConfluenceAPI {
                $script:mockCallCount = 0
                Mock Invoke-ConfluenceRequest {
                    param($Endpoint, $Method, $Body)
                    $script:mockCallCount++
                    if ($script:mockCallCount -eq 1) {
                        @{
                            id      = '123'
                            title   = 'Test'
                            spaceId = '456'
                            status  = 'current'
                            version = @{ number = 1 }
                            body    = @{ storage = @{ value = '<p>Old</p>' } }
                        }
                    } else {
                        $bodyObj = $Body | ConvertFrom-Json
                        if ($bodyObj.body.value -ne '<p>New Content</p>') {
                            throw "Body not updated correctly"
                        }
                        @{
                            id      = '123'
                            title   = 'Test'
                            spaceId = '456'
                            status  = 'current'
                            version = @{ number = 2 }
                        }
                    }
                }

                $result = Set-ConfluencePage -PageId '123' -Body '<p>New Content</p>'
                Assert-MockCalled Invoke-ConfluenceRequest -Times 2
            }
        }

        It 'Preserves existing body when only title updated' {
            InModuleScope ConfluenceAPI {
                $script:mockCallCount = 0
                Mock Invoke-ConfluenceRequest {
                    param($Endpoint, $Method, $Body)
                    $script:mockCallCount++
                    if ($script:mockCallCount -eq 1) {
                        @{
                            id      = '123'
                            title   = 'Old Title'
                            spaceId = '456'
                            status  = 'current'
                            version = @{ number = 1 }
                            body    = @{ storage = @{ value = '<p>Existing Content</p>' } }
                        }
                    } else {
                        $bodyObj = $Body | ConvertFrom-Json
                        if ($bodyObj.body.value -ne '<p>Existing Content</p>') {
                            throw "Body should be preserved"
                        }
                        @{
                            id      = '123'
                            title   = 'New Title'
                            spaceId = '456'
                            status  = 'current'
                            version = @{ number = 2 }
                        }
                    }
                }

                $result = Set-ConfluencePage -PageId '123' -Title 'New Title'
                Assert-MockCalled Invoke-ConfluenceRequest -Times 2
            }
        }
    }

    Context 'Validation' {
        It 'Requires at least one update parameter' {
            InModuleScope ConfluenceAPI {
                { Set-ConfluencePage -PageId '123' } | Should Throw 'At least one update parameter'
            }
        }

        It 'Accepts Title alone' {
            InModuleScope ConfluenceAPI {
                $script:mockCallCount = 0
                Mock Invoke-ConfluenceRequest {
                    $script:mockCallCount++
                    if ($script:mockCallCount -eq 1) {
                        @{ id = '123'; title = 'Old'; spaceId = '456'; status = 'current'; version = @{ number = 1 }; body = @{ storage = @{ value = '' } } }
                    } else {
                        @{ id = '123'; title = 'New'; spaceId = '456'; status = 'current'; version = @{ number = 2 } }
                    }
                }

                { Set-ConfluencePage -PageId '123' -Title 'New' } | Should Not Throw
            }
        }

        It 'Accepts Body alone' {
            InModuleScope ConfluenceAPI {
                $script:mockCallCount = 0
                Mock Invoke-ConfluenceRequest {
                    $script:mockCallCount++
                    if ($script:mockCallCount -eq 1) {
                        @{ id = '123'; title = 'Test'; spaceId = '456'; status = 'current'; version = @{ number = 1 }; body = @{ storage = @{ value = '' } } }
                    } else {
                        @{ id = '123'; title = 'Test'; spaceId = '456'; status = 'current'; version = @{ number = 2 } }
                    }
                }

                { Set-ConfluencePage -PageId '123' -Body '<p>Content</p>' } | Should Not Throw
            }
        }

        It 'Accepts Status alone' {
            InModuleScope ConfluenceAPI {
                $script:mockCallCount = 0
                Mock Invoke-ConfluenceRequest {
                    $script:mockCallCount++
                    if ($script:mockCallCount -eq 1) {
                        @{ id = '123'; title = 'Test'; spaceId = '456'; status = 'current'; version = @{ number = 1 }; body = @{ storage = @{ value = '' } } }
                    } else {
                        @{ id = '123'; title = 'Test'; spaceId = '456'; status = 'draft'; version = @{ number = 2 } }
                    }
                }

                { Set-ConfluencePage -PageId '123' -Status 'draft' } | Should Not Throw
            }
        }
    }

    Context 'WhatIf Support' {
        It 'Does not call PUT API when WhatIf is specified' {
            InModuleScope ConfluenceAPI {
                $script:mockCallCount = 0
                Mock Invoke-ConfluenceRequest {
                    $script:mockCallCount++
                    if ($script:mockCallCount -eq 1) {
                        # GET is allowed
                        @{ id = '123'; title = 'Test'; spaceId = '456'; status = 'current'; version = @{ number = 1 }; body = @{ storage = @{ value = '' } } }
                    } else {
                        throw "PUT should not be called"
                    }
                }

                $result = Set-ConfluencePage -PageId '123' -Title 'New' -WhatIf
                # Only GET should be called (for version), PUT should be skipped
                Assert-MockCalled Invoke-ConfluenceRequest -Times 1
            }
        }

        It 'Returns null when WhatIf is specified' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @{ id = '123'; title = 'Test'; spaceId = '456'; status = 'current'; version = @{ number = 1 }; body = @{ storage = @{ value = '' } } }
                }

                $result = Set-ConfluencePage -PageId '123' -Title 'New' -WhatIf
                $result | Should Be $null
            }
        }
    }

    Context 'Error Handling' {
        It 'Throws when page not found' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    throw [System.Exception]::new('Resource not found (404)')
                }

                { Set-ConfluencePage -PageId '999' -Title 'Test' } | Should Throw 'was not found'
            }
        }

        It 'Handles 409 version conflict' {
            InModuleScope ConfluenceAPI {
                $script:mockCallCount = 0
                Mock Invoke-ConfluenceRequest {
                    $script:mockCallCount++
                    if ($script:mockCallCount -eq 1) {
                        @{ id = '123'; title = 'Test'; spaceId = '456'; status = 'current'; version = @{ number = 1 }; body = @{ storage = @{ value = '' } } }
                    } else {
                        throw [System.Exception]::new('Version conflict (409)')
                    }
                }

                { Set-ConfluencePage -PageId '123' -Title 'New' } | Should Throw 'Version conflict'
            }
        }

        It 'Includes PageId in error message' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    throw [System.Exception]::new('Resource not found (404)')
                }

                try {
                    Set-ConfluencePage -PageId 'MYPAGE999' -Title 'Test'
                }
                catch {
                    $_.Exception.Message | Should Match 'MYPAGE999'
                }
            }
        }
    }

    Context 'Verbose Output' {
        It 'Logs verbose messages during update' {
            InModuleScope ConfluenceAPI {
                $script:mockCallCount = 0
                Mock Invoke-ConfluenceRequest {
                    $script:mockCallCount++
                    if ($script:mockCallCount -eq 1) {
                        @{ id = '123'; title = 'Test'; spaceId = '456'; status = 'current'; version = @{ number = 1 }; body = @{ storage = @{ value = '' } } }
                    } else {
                        @{ id = '123'; title = 'New'; spaceId = '456'; status = 'current'; version = @{ number = 2 } }
                    }
                }
                Mock Write-Verbose { } -Verifiable

                $result = Set-ConfluencePage -PageId '123' -Title 'New' -Verbose
                Assert-MockCalled Write-Verbose
            }
        }
    }
}
