#Requires -Modules Pester

Describe 'Move-ConfluencePage' {
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

    Context 'Move Page to New Parent' {
        It 'Moves page with append position by default' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @{
                        id = '12345'
                        title = 'Moved Page'
                        status = 'current'
                        space = @{
                            id = 789
                            key = 'TEST'
                            name = 'Test Space'
                        }
                        ancestors = @(
                            @{ id = '67890'; type = 'page'; title = 'Parent Page' }
                        )
                        version = @{ number = 2 }
                    }
                }

                $result = Move-ConfluencePage -PageId '12345' -TargetId '67890'
                $result.Id | Should Be '12345'
                $result.ParentId | Should Be '67890'
                Assert-MockCalled Invoke-ConfluenceRequest -ParameterFilter {
                    $Endpoint -eq '/wiki/rest/api/content/12345/move/append/67890'
                }
            }
        }

        It 'Returns PSCustomObject with all expected properties' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @{
                        id = '12345'
                        title = 'Moved Page'
                        status = 'current'
                        space = @{
                            id = 789
                            key = 'TEST'
                            name = 'Test Space'
                        }
                        ancestors = @(
                            @{ id = '67890'; type = 'page'; title = 'Parent Page' }
                        )
                        version = @{ number = 2 }
                    }
                }

                $result = Move-ConfluencePage -PageId '12345' -TargetId '67890'
                $result.Id | Should Be '12345'
                $result.Title | Should Be 'Moved Page'
                $result.SpaceId | Should Be 789
                $result.SpaceKey | Should Be 'TEST'
                $result.Status | Should Be 'current'
                $result.ParentId | Should Be '67890'
                $result.ParentType | Should Be 'page'
                $result.Version | Should Be 2
            }
        }

        It 'Handles page with no ancestors (root level page)' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @{
                        id = '12345'
                        title = 'Root Page'
                        status = 'current'
                        space = @{ id = 789; key = 'TEST'; name = 'Test Space' }
                        ancestors = @()
                        version = @{ number = 1 }
                    }
                }

                $result = Move-ConfluencePage -PageId '12345' -TargetId '67890'
                $result.ParentId | Should Be $null
                $result.ParentType | Should Be $null
            }
        }
    }

    Context 'Position Options' {
        It 'Supports before position' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @{
                        id = '12345'
                        title = 'Moved Page'
                        status = 'current'
                        space = @{ id = 789; key = 'TEST'; name = 'Test' }
                        ancestors = @(@{ id = '999'; type = 'page'; title = 'Parent' })
                        version = @{ number = 2 }
                    }
                }

                $result = Move-ConfluencePage -PageId '12345' -TargetId '67890' -Position 'before'
                $result.Id | Should Be '12345'
                Assert-MockCalled Invoke-ConfluenceRequest -ParameterFilter {
                    $Endpoint -eq '/wiki/rest/api/content/12345/move/before/67890'
                }
            }
        }

        It 'Supports after position' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @{
                        id = '12345'
                        title = 'Moved Page'
                        status = 'current'
                        space = @{ id = 789; key = 'TEST'; name = 'Test' }
                        ancestors = @(@{ id = '999'; type = 'page'; title = 'Parent' })
                        version = @{ number = 2 }
                    }
                }

                $result = Move-ConfluencePage -PageId '12345' -TargetId '67890' -Position 'after'
                $result.Id | Should Be '12345'
                Assert-MockCalled Invoke-ConfluenceRequest -ParameterFilter {
                    $Endpoint -eq '/wiki/rest/api/content/12345/move/after/67890'
                }
            }
        }

        It 'Uses correct endpoint format with v1 API' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @{
                        id = '111'
                        title = 'Test'
                        status = 'current'
                        space = @{ id = 222; key = 'SP'; name = 'Space' }
                        ancestors = @()
                        version = @{ number = 1 }
                    }
                }

                $result = Move-ConfluencePage -PageId '111' -TargetId '222' -Position 'append'
                $result.Id | Should Be '111'
                Assert-MockCalled Invoke-ConfluenceRequest -ParameterFilter {
                    $Endpoint -eq '/wiki/rest/api/content/111/move/append/222' -and $Method -eq 'PUT'
                }
            }
        }
    }

    Context 'WhatIf Support' {
        It 'Does not call API when WhatIf is used' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest { }

                $null = Move-ConfluencePage -PageId '12345' -TargetId '67890' -WhatIf
                Assert-MockCalled Invoke-ConfluenceRequest -Times 0
            }
        }

        It 'Returns null when WhatIf is used' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @{
                        id = '12345'
                        title = 'Page'
                        status = 'current'
                        space = @{ id = 789; key = 'TEST'; name = 'Test' }
                        ancestors = @()
                        version = @{ number = 1 }
                    }
                }

                $result = Move-ConfluencePage -PageId '12345' -TargetId '67890' -WhatIf
                $result | Should Be $null
            }
        }

        It 'Supports ConfirmImpact Medium attribute' {
            $cmd = Get-Command Move-ConfluencePage
            $cmd.Parameters['Confirm'] | Should Not Be $null
            $cmdletBinding = $cmd.ScriptBlock.Attributes | Where-Object { $_.TypeId.Name -eq 'CmdletBindingAttribute' }
            $cmdletBinding.ConfirmImpact | Should Be 'Medium'
        }
    }

    Context 'Error Handling' {
        It 'Throws 404 error with content not found message including both IDs' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    throw [System.Exception]::new('Resource not found (404)')
                }

                { Move-ConfluencePage -PageId '999' -TargetId '888' } | Should Throw 'was not found'
            }
        }

        It 'Includes both PageId and TargetId in 404 error message' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    throw [System.Exception]::new('Resource not found (404)')
                }

                try {
                    Move-ConfluencePage -PageId 'PAGE123' -TargetId 'TARGET456'
                }
                catch {
                    $_.Exception.Message | Should Match 'PAGE123'
                    $_.Exception.Message | Should Match 'TARGET456'
                }
            }
        }

        It 'Throws 403 error with "Access denied" message' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    throw [System.Exception]::new('Forbidden (403)')
                }

                { Move-ConfluencePage -PageId '999' -TargetId '888' } | Should Throw 'Access denied'
            }
        }

        It 'Throws 400 error with "Invalid move" message' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    throw [System.Exception]::new('Bad request - circular reference (400)')
                }

                { Move-ConfluencePage -PageId '999' -TargetId '888' } | Should Throw 'invalid'
            }
        }

        It 'Includes PageId in error message' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    throw [System.Exception]::new('Resource not found (404)')
                }

                try {
                    Move-ConfluencePage -PageId 'MYPAGE123' -TargetId '888'
                }
                catch {
                    $_.Exception.Message | Should Match 'MYPAGE123'
                }
            }
        }

        It 'Includes TargetId in invalid move error message' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    throw [System.Exception]::new('Bad request (400)')
                }

                try {
                    Move-ConfluencePage -PageId '123' -TargetId 'TARGET456'
                }
                catch {
                    $_.Exception.Message | Should Match 'TARGET456'
                }
            }
        }

        It 'Throws when null response received' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    return $null
                }

                { Move-ConfluencePage -PageId '123' -TargetId '456' } | Should Throw 'Move operation failed'
            }
        }
    }

    Context 'Verbose Output' {
        It 'Logs verbose message with page and target information' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @{
                        id = '12345'
                        title = 'Page'
                        status = 'current'
                        space = @{ id = 789; key = 'TEST'; name = 'Test' }
                        ancestors = @(@{ id = '67890'; type = 'page'; title = 'Parent' })
                        version = @{ number = 1 }
                    }
                }
                Mock Write-Verbose { } -Verifiable

                $null = Move-ConfluencePage -PageId '12345' -TargetId '67890' -Verbose
                Assert-MockCalled Write-Verbose
            }
        }

        It 'Verbose output does not contain API token' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @{
                        id = '12345'
                        title = 'Page'
                        status = 'current'
                        space = @{ id = 789; key = 'TEST'; name = 'Test' }
                        ancestors = @()
                        version = @{ number = 1 }
                    }
                }

                $verboseOutput = @()
                Move-ConfluencePage -PageId '12345' -TargetId '67890' -Verbose 4>&1 | ForEach-Object {
                    if ($_ -is [System.Management.Automation.VerboseRecord]) {
                        $verboseOutput += $_.Message
                    }
                }

                foreach ($msg in $verboseOutput) {
                    $msg | Should Not Match 'test-token'
                }
            }
        }

        It 'Verbose output includes position parameter' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @{
                        id = '12345'
                        title = 'Page'
                        status = 'current'
                        space = @{ id = 789; key = 'TEST'; name = 'Test' }
                        ancestors = @()
                        version = @{ number = 1 }
                    }
                }

                $verboseOutput = @()
                Move-ConfluencePage -PageId '12345' -TargetId '67890' -Position 'before' -Verbose 4>&1 | ForEach-Object {
                    if ($_ -is [System.Management.Automation.VerboseRecord]) {
                        $verboseOutput += $_.Message
                    }
                }

                ($verboseOutput -join ' ') | Should Match 'before'
            }
        }
    }

    Context 'Move to Different Space' {
        It 'Returns updated SpaceId after moving to different space' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @{
                        id = '12345'
                        title = 'Moved Page'
                        status = 'current'
                        space = @{
                            id = 99999
                            key = 'NEWSPACE'
                            name = 'New Space'
                        }
                        ancestors = @(@{ id = '11111'; type = 'page'; title = 'New Parent' })
                        version = @{ number = 3 }
                    }
                }

                $result = Move-ConfluencePage -PageId '12345' -TargetId '11111'
                $result.SpaceId | Should Be 99999
                $result.SpaceKey | Should Be 'NEWSPACE'
            }
        }
    }

    Context 'Property Mapping from v1 API' {
        It 'Maps ancestors array correctly for parent information' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @{
                        id = '12345'
                        title = 'Deep Page'
                        status = 'current'
                        space = @{ id = 789; key = 'TEST'; name = 'Test' }
                        ancestors = @(
                            @{ id = '100'; type = 'page'; title = 'Grandparent' },
                            @{ id = '200'; type = 'page'; title = 'Parent' }
                        )
                        version = @{ number = 1 }
                    }
                }

                $result = Move-ConfluencePage -PageId '12345' -TargetId '200'
                # Should return the LAST ancestor (immediate parent)
                $result.ParentId | Should Be '200'
                $result.ParentType | Should Be 'page'
            }
        }

        It 'Maps all expected properties from v1 API response' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @{
                        id = '12345'
                        title = 'Full Properties'
                        status = 'draft'
                        space = @{ id = 789; key = 'SPACE'; name = 'Space Name' }
                        ancestors = @(@{ id = '555'; type = 'page'; title = 'P' })
                        version = @{ number = 10 }
                    }
                }

                $result = Move-ConfluencePage -PageId '12345' -TargetId '555'
                $propNames = $result.PSObject.Properties.Name

                ($propNames -contains 'Id') | Should Be $true
                ($propNames -contains 'Title') | Should Be $true
                ($propNames -contains 'SpaceId') | Should Be $true
                ($propNames -contains 'SpaceKey') | Should Be $true
                ($propNames -contains 'Status') | Should Be $true
                ($propNames -contains 'ParentId') | Should Be $true
                ($propNames -contains 'ParentType') | Should Be $true
                ($propNames -contains 'Version') | Should Be $true
            }
        }
    }
}
