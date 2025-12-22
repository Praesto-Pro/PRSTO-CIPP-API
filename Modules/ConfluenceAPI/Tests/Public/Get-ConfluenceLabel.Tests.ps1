#Requires -Modules Pester

Describe 'Get-ConfluenceLabel' {
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

    Context 'Returns Labels Successfully' {
        It 'Returns labels with expected properties (Id, Name, Prefix)' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @{
                        results = @(
                            @{ id = '123'; name = 'label1'; prefix = 'global' },
                            @{ id = '456'; name = 'label2'; prefix = 'global' }
                        )
                    }
                }

                $result = Get-ConfluenceLabel -PageId '12345'
                $result.Count | Should Be 2
                $result[0].Id | Should Be '123'
                $result[0].Name | Should Be 'label1'
                $result[0].Prefix | Should Be 'global'
                $result[1].Id | Should Be '456'
                $result[1].Name | Should Be 'label2'
            }
        }

        It 'Returns empty array when page has no labels' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @{
                        results = @()
                    }
                }

                $result = @(Get-ConfluenceLabel -PageId '12345')
                $result.Count | Should Be 0
            }
        }

        It 'Returns empty array when response results is null' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @{
                        results = $null
                    }
                }

                $result = Get-ConfluenceLabel -PageId '12345'
                @($result).Count | Should Be 0
            }
        }

        It 'Uses correct v1 API endpoint' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @{ results = @() }
                }

                $null = Get-ConfluenceLabel -PageId '12345'
                Assert-MockCalled Invoke-ConfluenceRequest -ParameterFilter {
                    $Endpoint -eq '/wiki/rest/api/content/12345/label' -and $Method -eq 'GET'
                }
            }
        }

        It 'Returns PSCustomObject for each label' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @{
                        results = @(
                            @{ id = '789'; name = 'test-label'; prefix = 'global' }
                        )
                    }
                }

                $result = Get-ConfluenceLabel -PageId '12345'
                $result[0].GetType().Name | Should Be 'PSCustomObject'
                $propNames = $result[0].PSObject.Properties.Name
                ($propNames -contains 'Id') | Should Be $true
                ($propNames -contains 'Name') | Should Be $true
                ($propNames -contains 'Prefix') | Should Be $true
            }
        }
    }

    Context 'Error Handling' {
        It '404 throws with "Page not found" message' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    throw [System.Exception]::new('Resource not found (404)')
                }

                { Get-ConfluenceLabel -PageId '999' } | Should Throw 'was not found'
            }
        }

        It '404 error includes PageId in message' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    throw [System.Exception]::new('Resource not found (404)')
                }

                try {
                    Get-ConfluenceLabel -PageId 'TESTPAGE123'
                }
                catch {
                    $_.Exception.Message | Should Match 'TESTPAGE123'
                }
            }
        }

        It '403 throws with "Access denied" message' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    throw [System.Exception]::new('Forbidden (403)')
                }

                { Get-ConfluenceLabel -PageId '999' } | Should Throw 'Access denied'
            }
        }

        It '403 error includes PageId in message' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    throw [System.Exception]::new('Forbidden (403)')
                }

                try {
                    Get-ConfluenceLabel -PageId 'MYPAGE456'
                }
                catch {
                    $_.Exception.Message | Should Match 'MYPAGE456'
                }
            }
        }

        It 'Generic error includes context information' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    throw [System.Exception]::new('Connection timeout')
                }

                try {
                    Get-ConfluenceLabel -PageId '12345'
                }
                catch {
                    $_.Exception.Message | Should Match '12345'
                    $_.Exception.Message | Should Match 'Failed to retrieve labels'
                }
            }
        }
    }

    Context 'Verbose Output' {
        It 'Verbose output logs page ID' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @{ results = @() }
                }

                $verboseOutput = @()
                Get-ConfluenceLabel -PageId '12345' -Verbose 4>&1 | ForEach-Object {
                    if ($_ -is [System.Management.Automation.VerboseRecord]) {
                        $verboseOutput += $_.Message
                    }
                }

                ($verboseOutput -join ' ') | Should Match '12345'
            }
        }

        It 'Verbose output does not contain API token' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @{
                        results = @(
                            @{ id = '123'; name = 'label1'; prefix = 'global' }
                        )
                    }
                }

                $verboseOutput = @()
                Get-ConfluenceLabel -PageId '12345' -Verbose 4>&1 | ForEach-Object {
                    if ($_ -is [System.Management.Automation.VerboseRecord]) {
                        $verboseOutput += $_.Message
                    }
                }

                foreach ($msg in $verboseOutput) {
                    $msg | Should Not Match 'test-token'
                }
            }
        }

        It 'Logs count of labels found' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @{
                        results = @(
                            @{ id = '1'; name = 'a'; prefix = 'global' },
                            @{ id = '2'; name = 'b'; prefix = 'global' },
                            @{ id = '3'; name = 'c'; prefix = 'global' }
                        )
                    }
                }

                $verboseOutput = @()
                Get-ConfluenceLabel -PageId '12345' -Verbose 4>&1 | ForEach-Object {
                    if ($_ -is [System.Management.Automation.VerboseRecord]) {
                        $verboseOutput += $_.Message
                    }
                }

                ($verboseOutput -join ' ') | Should Match '3 label'
            }
        }
    }

    Context 'Parameter Validation' {
        It 'Requires PageId parameter' {
            { Get-ConfluenceLabel } | Should Throw
        }

        It 'Does not accept empty PageId' {
            { Get-ConfluenceLabel -PageId '' } | Should Throw
        }

        It 'Does not accept null PageId' {
            { Get-ConfluenceLabel -PageId $null } | Should Throw
        }
    }
}
