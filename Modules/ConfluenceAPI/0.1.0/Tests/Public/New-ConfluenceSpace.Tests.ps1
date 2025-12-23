#Requires -Modules Pester

Describe 'New-ConfluenceSpace' {
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

    Context 'Create Space with Required Parameters' {
        It 'Creates space with SpaceKey and Name' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @{
                        id = '123456'
                        key = 'TEST'
                        name = 'Test Space'
                        type = 'global'
                        status = 'current'
                        homepageId = '789012'
                    }
                }

                $result = New-ConfluenceSpace -SpaceKey 'TEST' -Name 'Test Space'
                $result.Key | Should Be 'TEST'
                $result.Name | Should Be 'Test Space'
                $result.Id | Should Be '123456'
            }
        }

        It 'Sends POST request to correct endpoint' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @{
                        id = '123'
                        key = 'TEST'
                        name = 'Test'
                        type = 'global'
                        status = 'current'
                        homepageId = '456'
                    }
                }

                $result = New-ConfluenceSpace -SpaceKey 'TEST' -Name 'Test'
                Assert-MockCalled Invoke-ConfluenceRequest -ParameterFilter {
                    $Endpoint -eq '/wiki/api/v2/spaces' -and $Method -eq 'POST'
                }
            }
        }

        It 'Converts lowercase SpaceKey to uppercase' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    param($Body)
                    $bodyObj = $Body | ConvertFrom-Json
                    @{
                        id = '123'
                        key = $bodyObj.key
                        name = $bodyObj.name
                        type = 'global'
                        status = 'current'
                        homepageId = '456'
                    }
                }

                $result = New-ConfluenceSpace -SpaceKey 'test' -Name 'Test'
                Assert-MockCalled Invoke-ConfluenceRequest -ParameterFilter {
                    $Body -match '"key":\s*"TEST"'
                }
            }
        }
    }

    Context 'Create Space with Optional Description' {
        It 'Includes description in request body when provided' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @{
                        id = '123'
                        key = 'TEST'
                        name = 'Test'
                        type = 'global'
                        status = 'current'
                        homepageId = '456'
                        description = @{ plain = @{ value = 'Test description' } }
                    }
                }

                $result = New-ConfluenceSpace -SpaceKey 'TEST' -Name 'Test' -Description 'Test description'
                Assert-MockCalled Invoke-ConfluenceRequest -ParameterFilter {
                    $Body -match '"description"' -and $Body -match 'Test description'
                }
            }
        }

        It 'Creates space without description when not provided' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @{
                        id = '123'
                        key = 'TEST'
                        name = 'Test'
                        type = 'global'
                        status = 'current'
                        homepageId = '456'
                    }
                }

                $result = New-ConfluenceSpace -SpaceKey 'TEST' -Name 'Test'
                Assert-MockCalled Invoke-ConfluenceRequest -ParameterFilter {
                    $Body -notmatch '"description"'
                }
            }
        }
    }

    Context 'WhatIf Support' {
        It 'Does not call API when WhatIf is used' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest { }

                $result = New-ConfluenceSpace -SpaceKey 'TEST' -Name 'Test' -WhatIf
                Assert-MockCalled Invoke-ConfluenceRequest -Times 0
            }
        }

        It 'Returns null when WhatIf is used' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest { }

                $result = New-ConfluenceSpace -SpaceKey 'TEST' -Name 'Test' -WhatIf
                $result | Should Be $null
            }
        }
    }

    Context 'Return Type' {
        It 'Returns PSCustomObject with correct properties' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @{
                        id = '999'
                        key = 'NEWSPACE'
                        name = 'New Space'
                        type = 'global'
                        status = 'current'
                        homepageId = '888'
                        description = @{ plain = @{ value = 'Description' } }
                    }
                }

                $result = New-ConfluenceSpace -SpaceKey 'NEWSPACE' -Name 'New Space' -Description 'Description'
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

    Context 'Verbose Logging' {
        It 'Logs verbose message during space creation' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @{
                        id = '123'
                        key = 'TEST'
                        name = 'Test'
                        type = 'global'
                        status = 'current'
                        homepageId = '456'
                    }
                }
                Mock Write-Verbose { } -Verifiable

                $result = New-ConfluenceSpace -SpaceKey 'TEST' -Name 'Test' -Verbose
                Assert-MockCalled Write-Verbose
            }
        }
    }

    Context 'SpaceKey Validation' {
        It 'Throws error for SpaceKey with spaces' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest { }

                { New-ConfluenceSpace -SpaceKey 'TEST SPACE' -Name 'Test' } | Should Throw 'invalid'
            }
        }

        It 'Throws error for SpaceKey with special characters' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest { }

                { New-ConfluenceSpace -SpaceKey 'TEST-KEY' -Name 'Test' } | Should Throw 'invalid'
            }
        }

        It 'Accepts valid alphanumeric SpaceKey' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @{
                        id = '123'
                        key = 'TEST123'
                        name = 'Test'
                        type = 'global'
                        status = 'current'
                        homepageId = '456'
                    }
                }

                $result = New-ConfluenceSpace -SpaceKey 'TEST123' -Name 'Test'
                $result.Key | Should Be 'TEST123'
            }
        }
    }

    Context 'Error Handling' {
        It 'Throws error when space key already exists' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    throw [System.Exception]::new('409 Conflict')
                }

                { New-ConfluenceSpace -SpaceKey 'EXISTING' -Name 'Test' } | Should Throw 'already exists'
            }
        }

        It 'Throws terminating error on API failure' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    throw [System.Exception]::new('Connection failed')
                }

                { New-ConfluenceSpace -SpaceKey 'TEST' -Name 'Test' } | Should Throw 'Failed to create space'
            }
        }

        It 'Includes SpaceKey in error message' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    throw [System.Exception]::new('API error')
                }

                try {
                    New-ConfluenceSpace -SpaceKey 'MYSPACE' -Name 'Test'
                }
                catch {
                    $_.Exception.Message | Should Match 'MYSPACE'
                }
            }
        }
    }
}
