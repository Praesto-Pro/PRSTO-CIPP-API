#Requires -Modules Pester

Describe 'Add-ConfluenceLabel' {
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

    Context 'Add Single Label' {
        It 'Adds single label successfully' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @(
                        @{ id = '123'; name = 'user-inventory'; prefix = 'global' }
                    )
                }

                $result = @(Add-ConfluenceLabel -PageId '12345' -Label 'user-inventory')
                $result.Count | Should Be 1
                $result[0].Name | Should Be 'user-inventory'
                $result[0].Prefix | Should Be 'global'
            }
        }

        It 'Returns PSCustomObject with label properties' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @(
                        @{ id = '789'; name = 'test-label'; prefix = 'global' }
                    )
                }

                $result = Add-ConfluenceLabel -PageId '12345' -Label 'test-label'
                $result[0].GetType().Name | Should Be 'PSCustomObject'
                $propNames = $result[0].PSObject.Properties.Name
                ($propNames -contains 'Id') | Should Be $true
                ($propNames -contains 'Name') | Should Be $true
                ($propNames -contains 'Prefix') | Should Be $true
            }
        }

        It 'Uses correct v1 API endpoint with POST method' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @(@{ id = '1'; name = 'test'; prefix = 'global' })
                }

                $null = Add-ConfluenceLabel -PageId '12345' -Label 'test'
                Assert-MockCalled Invoke-ConfluenceRequest -ParameterFilter {
                    $Endpoint -eq '/wiki/rest/api/content/12345/label' -and $Method -eq 'POST'
                }
            }
        }
    }

    Context 'Add Multiple Labels' {
        It 'Adds multiple labels in single API call' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @(
                        @{ id = '1'; name = 'label1'; prefix = 'global' },
                        @{ id = '2'; name = 'label2'; prefix = 'global' },
                        @{ id = '3'; name = 'label3'; prefix = 'global' }
                    )
                }

                $result = @(Add-ConfluenceLabel -PageId '12345' -Label 'label1', 'label2', 'label3')
                $result.Count | Should Be 3
                $result[0].Name | Should Be 'label1'
                $result[1].Name | Should Be 'label2'
                $result[2].Name | Should Be 'label3'
            }
        }

        It 'Makes only one API call for multiple labels' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @(
                        @{ id = '1'; name = 'a'; prefix = 'global' },
                        @{ id = '2'; name = 'b'; prefix = 'global' }
                    )
                }

                $null = Add-ConfluenceLabel -PageId '12345' -Label 'a', 'b'
                Assert-MockCalled Invoke-ConfluenceRequest -Times 1
            }
        }
    }

    Context 'Request Body Format' {
        It 'Request body is array of prefix/name objects for single label' {
            InModuleScope ConfluenceAPI {
                $capturedBody = $null
                Mock Invoke-ConfluenceRequest {
                    param($Endpoint, $Method, $Body)
                    $script:capturedBody = $Body
                    @(@{ id = '1'; name = 'test'; prefix = 'global' })
                }

                $null = Add-ConfluenceLabel -PageId '12345' -Label 'test'
                $parsed = $script:capturedBody | ConvertFrom-Json
                @($parsed).Count | Should Be 1
                $parsed[0].prefix | Should Be 'global'
                $parsed[0].name | Should Be 'test'
            }
        }

        It 'Request body is array of prefix/name objects for multiple labels' {
            InModuleScope ConfluenceAPI {
                $capturedBody = $null
                Mock Invoke-ConfluenceRequest {
                    param($Endpoint, $Method, $Body)
                    $script:capturedBody = $Body
                    @(
                        @{ id = '1'; name = 'first'; prefix = 'global' },
                        @{ id = '2'; name = 'second'; prefix = 'global' }
                    )
                }

                $null = Add-ConfluenceLabel -PageId '12345' -Label 'first', 'second'
                $parsed = $script:capturedBody | ConvertFrom-Json
                @($parsed).Count | Should Be 2
                $parsed[0].prefix | Should Be 'global'
                $parsed[0].name | Should Be 'first'
                $parsed[1].prefix | Should Be 'global'
                $parsed[1].name | Should Be 'second'
            }
        }

        It 'All labels use global prefix' {
            InModuleScope ConfluenceAPI {
                $capturedBody = $null
                Mock Invoke-ConfluenceRequest {
                    param($Endpoint, $Method, $Body)
                    $script:capturedBody = $Body
                    @(@{ id = '1'; name = 'x'; prefix = 'global' })
                }

                $null = Add-ConfluenceLabel -PageId '12345' -Label 'x'
                $parsed = $script:capturedBody | ConvertFrom-Json
                $parsed[0].prefix | Should Be 'global'
            }
        }
    }

    Context 'WhatIf Support' {
        It 'WhatIf does not call API' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest { }

                $null = Add-ConfluenceLabel -PageId '12345' -Label 'test' -WhatIf
                Assert-MockCalled Invoke-ConfluenceRequest -Times 0
            }
        }

        It 'WhatIf returns null' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @(@{ id = '1'; name = 'test'; prefix = 'global' })
                }

                $result = Add-ConfluenceLabel -PageId '12345' -Label 'test' -WhatIf
                $result | Should Be $null
            }
        }

        It 'Supports ConfirmImpact Low attribute' {
            $cmd = Get-Command Add-ConfluenceLabel
            $cmd.Parameters['Confirm'] | Should Not Be $null
            $cmdletBinding = $cmd.ScriptBlock.Attributes | Where-Object { $_.TypeId.Name -eq 'CmdletBindingAttribute' }
            $cmdletBinding.ConfirmImpact | Should Be 'Low'
        }
    }

    Context 'Error Handling' {
        It '404 throws with "Page not found" message' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    throw [System.Exception]::new('Resource not found (404)')
                }

                { Add-ConfluenceLabel -PageId '999' -Label 'test' } | Should Throw 'was not found'
            }
        }

        It '404 error includes PageId in message' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    throw [System.Exception]::new('Resource not found (404)')
                }

                try {
                    Add-ConfluenceLabel -PageId 'TESTPAGE123' -Label 'test'
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

                { Add-ConfluenceLabel -PageId '999' -Label 'test' } | Should Throw 'Access denied'
            }
        }

        It '400 throws with error context' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    throw [System.Exception]::new('Bad request - invalid label (400)')
                }

                { Add-ConfluenceLabel -PageId '999' -Label 'invalid!' } | Should Throw 'Failed to add'
            }
        }

        It 'Error message includes label name' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    throw [System.Exception]::new('Bad request (400)')
                }

                try {
                    Add-ConfluenceLabel -PageId '999' -Label 'my-label'
                }
                catch {
                    $_.Exception.Message | Should Match 'my-label'
                }
            }
        }
    }

    Context 'Verbose Output' {
        It 'Verbose output logs label being added' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @(@{ id = '1'; name = 'test-label'; prefix = 'global' })
                }

                $verboseOutput = @()
                Add-ConfluenceLabel -PageId '12345' -Label 'test-label' -Verbose 4>&1 | ForEach-Object {
                    if ($_ -is [System.Management.Automation.VerboseRecord]) {
                        $verboseOutput += $_.Message
                    }
                }

                ($verboseOutput -join ' ') | Should Match 'test-label'
            }
        }

        It 'Verbose output logs page ID' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @(@{ id = '1'; name = 'x'; prefix = 'global' })
                }

                $verboseOutput = @()
                Add-ConfluenceLabel -PageId '67890' -Label 'x' -Verbose 4>&1 | ForEach-Object {
                    if ($_ -is [System.Management.Automation.VerboseRecord]) {
                        $verboseOutput += $_.Message
                    }
                }

                ($verboseOutput -join ' ') | Should Match '67890'
            }
        }

        It 'Verbose output does not contain API token' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @(@{ id = '1'; name = 'test'; prefix = 'global' })
                }

                $verboseOutput = @()
                Add-ConfluenceLabel -PageId '12345' -Label 'test' -Verbose 4>&1 | ForEach-Object {
                    if ($_ -is [System.Management.Automation.VerboseRecord]) {
                        $verboseOutput += $_.Message
                    }
                }

                foreach ($msg in $verboseOutput) {
                    $msg | Should Not Match 'test-token'
                }
            }
        }

        It 'Verbose output includes all labels when adding multiple' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @(
                        @{ id = '1'; name = 'a'; prefix = 'global' },
                        @{ id = '2'; name = 'b'; prefix = 'global' }
                    )
                }

                $verboseOutput = @()
                Add-ConfluenceLabel -PageId '12345' -Label 'a', 'b' -Verbose 4>&1 | ForEach-Object {
                    if ($_ -is [System.Management.Automation.VerboseRecord]) {
                        $verboseOutput += $_.Message
                    }
                }

                $combined = $verboseOutput -join ' '
                $combined | Should Match 'a'
                $combined | Should Match 'b'
            }
        }
    }

    Context 'Parameter Validation' {
        It 'Requires PageId parameter' {
            { Add-ConfluenceLabel -Label 'test' } | Should Throw
        }

        It 'Requires Label parameter' {
            { Add-ConfluenceLabel -PageId '12345' } | Should Throw
        }

        It 'Does not accept empty PageId' {
            { Add-ConfluenceLabel -PageId '' -Label 'test' } | Should Throw
        }

        It 'Does not accept empty Label' {
            { Add-ConfluenceLabel -PageId '12345' -Label '' } | Should Throw
        }
    }
}
