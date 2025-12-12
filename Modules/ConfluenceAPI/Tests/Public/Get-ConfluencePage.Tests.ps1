#Requires -Modules Pester

Describe 'Get-ConfluencePage' {
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

    Context 'Get Single Page' {
        It 'Returns PSCustomObject with correct properties' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @{
                        id         = '123456'
                        title      = 'Test Page'
                        spaceId    = '789012'
                        status     = 'current'
                        parentId   = '111222'
                        parentType = 'page'
                        authorId   = 'user123'
                        createdAt  = '2025-12-11T10:00:00Z'
                        version    = @{ number = 5 }
                    }
                }

                $result = Get-ConfluencePage -PageId '123456'
                $result.Id | Should Be '123456'
                $result.Title | Should Be 'Test Page'
                $result.SpaceId | Should Be '789012'
                $result.Status | Should Be 'current'
                $result.ParentId | Should Be '111222'
                $result.ParentType | Should Be 'page'
                $result.AuthorId | Should Be 'user123'
                $result.Version | Should Be 5
            }
        }

        It 'Calls correct endpoint without body parameter' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @{
                        id      = '123'
                        title   = 'Test'
                        spaceId = '456'
                        status  = 'current'
                        version = @{ number = 1 }
                    }
                }

                $result = Get-ConfluencePage -PageId '123456'
                Assert-MockCalled Invoke-ConfluenceRequest -ParameterFilter {
                    $Endpoint -eq '/wiki/api/v2/pages/123456'
                }
            }
        }

        It 'Handles null parentId gracefully' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @{
                        id         = '123'
                        title      = 'Test'
                        spaceId    = '456'
                        status     = 'current'
                        parentId   = $null
                        parentType = $null
                        version    = @{ number = 1 }
                    }
                }

                $result = Get-ConfluencePage -PageId '123'
                $result.ParentId | Should Be $null
                $result.ParentType | Should Be $null
            }
        }
    }

    Context 'Get Page with Body' {
        It 'Returns Body property when IncludeBody is specified' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @{
                        id      = '123456'
                        title   = 'Test Page'
                        spaceId = '789'
                        status  = 'current'
                        version = @{ number = 1 }
                        body    = @{
                            storage = @{
                                representation = 'storage'
                                value          = '<p>Page content here</p>'
                            }
                        }
                    }
                }

                $result = Get-ConfluencePage -PageId '123456' -IncludeBody
                $result.Body | Should Be '<p>Page content here</p>'
            }
        }

        It 'Calls endpoint with body-format parameter' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @{
                        id      = '123'
                        title   = 'Test'
                        spaceId = '456'
                        status  = 'current'
                        version = @{ number = 1 }
                        body    = @{ storage = @{ value = 'content' } }
                    }
                }

                $result = Get-ConfluencePage -PageId '123456' -IncludeBody
                Assert-MockCalled Invoke-ConfluenceRequest -ParameterFilter {
                    $Endpoint -eq '/wiki/api/v2/pages/123456?body-format=storage'
                }
            }
        }

        It 'Uses specified BodyFormat parameter' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @{
                        id      = '123'
                        title   = 'Test'
                        spaceId = '456'
                        status  = 'current'
                        version = @{ number = 1 }
                        body    = @{ atlas_doc_format = @{ value = '{"type":"doc"}' } }
                    }
                }

                $result = Get-ConfluencePage -PageId '123456' -IncludeBody -BodyFormat 'atlas_doc_format'
                Assert-MockCalled Invoke-ConfluenceRequest -ParameterFilter {
                    $Endpoint -eq '/wiki/api/v2/pages/123456?body-format=atlas_doc_format'
                }
            }
        }

        It 'Uses view BodyFormat when specified' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @{
                        id      = '123'
                        title   = 'Test'
                        spaceId = '456'
                        status  = 'current'
                        version = @{ number = 1 }
                        body    = @{ view = @{ value = '<p>Rendered HTML</p>' } }
                    }
                }

                $result = Get-ConfluencePage -PageId '123456' -IncludeBody -BodyFormat 'view'
                Assert-MockCalled Invoke-ConfluenceRequest -ParameterFilter {
                    $Endpoint -eq '/wiki/api/v2/pages/123456?body-format=view'
                }
            }
        }

        It 'Returns null Body when not requested' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @{
                        id      = '123'
                        title   = 'Test'
                        spaceId = '456'
                        status  = 'current'
                        version = @{ number = 1 }
                    }
                }

                $result = Get-ConfluencePage -PageId '123456'
                $result.Body | Should Be $null
            }
        }
    }

    Context 'List Pages in Space' {
        It 'Returns array of PSCustomObjects' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @(
                        @{
                            id      = '1'
                            title   = 'Page One'
                            spaceId = '789'
                            status  = 'current'
                            version = @{ number = 1 }
                        },
                        @{
                            id      = '2'
                            title   = 'Page Two'
                            spaceId = '789'
                            status  = 'current'
                            version = @{ number = 3 }
                        }
                    )
                }

                $result = Get-ConfluencePage -SpaceId '789'
                $result.Count | Should Be 2
                $result[0].Title | Should Be 'Page One'
                $result[1].Title | Should Be 'Page Two'
            }
        }

        It 'Calls correct endpoint for space pages' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @()
                }

                $result = Get-ConfluencePage -SpaceId '789012'
                Assert-MockCalled Invoke-ConfluenceRequest -ParameterFilter {
                    $Endpoint -eq '/wiki/api/v2/spaces/789012/pages'
                }
            }
        }

        It 'Returns empty array when no pages exist' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @()
                }

                $result = Get-ConfluencePage -SpaceId '789'
                $result.Count | Should Be 0
            }
        }

        It 'Handles pagination automatically via Invoke-ConfluenceRequest' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @(
                        @{ id = '1'; title = 'A'; spaceId = '789'; status = 'current'; version = @{ number = 1 } },
                        @{ id = '2'; title = 'B'; spaceId = '789'; status = 'current'; version = @{ number = 1 } },
                        @{ id = '3'; title = 'C'; spaceId = '789'; status = 'current'; version = @{ number = 1 } }
                    )
                }

                $result = Get-ConfluencePage -SpaceId '789'
                $result.Count | Should Be 3
            }
        }
    }

    Context 'Error Handling' {
        It 'Throws 404 error when page not found' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    throw [System.Exception]::new('Resource not found. Verify endpoint or ID. Endpoint: /wiki/api/v2/pages/999 (404)')
                }

                { Get-ConfluencePage -PageId '999' } | Should Throw 'was not found'
            }
        }

        It 'Throws terminating error on API failure' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    throw [System.Exception]::new('Connection failed')
                }

                { Get-ConfluencePage -PageId '123' } | Should Throw 'Failed to get page'
            }
        }

        It 'Includes PageId in error message' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    throw [System.Exception]::new('Resource not found (404)')
                }

                try {
                    Get-ConfluencePage -PageId 'MYPAGE123'
                }
                catch {
                    $_.Exception.Message | Should Match 'MYPAGE123'
                }
            }
        }

        It 'Throws when null response received' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    return $null
                }

                { Get-ConfluencePage -PageId '123' } | Should Throw 'was not found'
            }
        }
    }

    Context 'Verbose Output' {
        It 'Logs verbose message when getting single page' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @{
                        id      = '123'
                        title   = 'Test'
                        spaceId = '456'
                        status  = 'current'
                        version = @{ number = 1 }
                    }
                }
                Mock Write-Verbose { } -Verifiable

                $result = Get-ConfluencePage -PageId '123' -Verbose
                Assert-MockCalled Write-Verbose
            }
        }

        It 'Verbose output does not contain API token' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @{
                        id      = '123'
                        title   = 'Test'
                        spaceId = '456'
                        status  = 'current'
                        version = @{ number = 1 }
                    }
                }

                $verboseOutput = @()
                $result = Get-ConfluencePage -PageId '123' -Verbose 4>&1 | ForEach-Object {
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

    Context 'Property Mapping' {
        It 'Maps all expected properties from API response' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @{
                        id         = '999'
                        title      = 'Full Properties'
                        spaceId    = '888'
                        status     = 'draft'
                        parentId   = '777'
                        parentType = 'page'
                        authorId   = 'author456'
                        createdAt  = '2025-01-01T00:00:00Z'
                        version    = @{ number = 10 }
                    }
                }

                $result = Get-ConfluencePage -PageId '999'
                $propNames = $result.PSObject.Properties.Name

                ($propNames -contains 'Id') | Should Be $true
                ($propNames -contains 'Title') | Should Be $true
                ($propNames -contains 'SpaceId') | Should Be $true
                ($propNames -contains 'Status') | Should Be $true
                ($propNames -contains 'ParentId') | Should Be $true
                ($propNames -contains 'ParentType') | Should Be $true
                ($propNames -contains 'AuthorId') | Should Be $true
                ($propNames -contains 'CreatedAt') | Should Be $true
                ($propNames -contains 'Version') | Should Be $true
                ($propNames -contains 'Body') | Should Be $true
            }
        }
    }
}
