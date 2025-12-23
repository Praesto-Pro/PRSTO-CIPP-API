#Requires -Modules Pester

Describe 'Remove-ConfluencePage' {
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

    Context 'Delete Page' {
        It 'Calls DELETE endpoint' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    # DELETE returns nothing on success
                    return $null
                }

                Remove-ConfluencePage -PageId '123456' -Force -Confirm:$false
                Assert-MockCalled Invoke-ConfluenceRequest -ParameterFilter {
                    $Endpoint -eq '/wiki/api/v2/pages/123456' -and $Method -eq 'DELETE'
                }
            }
        }

        It 'Returns null on success' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    return $null
                }

                $result = Remove-ConfluencePage -PageId '123456' -Force -Confirm:$false
                $result | Should Be $null
            }
        }
    }

    Context 'WhatIf Support' {
        It 'Does not call API when WhatIf is specified' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    throw "Should not be called"
                }

                Remove-ConfluencePage -PageId '123456' -WhatIf
                Assert-MockCalled Invoke-ConfluenceRequest -Times 0
            }
        }

        It 'Returns nothing when WhatIf is specified' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    return $null
                }

                $result = Remove-ConfluencePage -PageId '123456' -WhatIf
                $result | Should Be $null
            }
        }
    }

    Context 'Force Parameter' {
        It 'Deletes page when Force is specified' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    return $null
                }

                Remove-ConfluencePage -PageId '123456' -Force -Confirm:$false
                Assert-MockCalled Invoke-ConfluenceRequest -Times 1
            }
        }
    }

    Context 'Error Handling' {
        It 'Throws 404 error when page not found' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    throw [System.Exception]::new('Resource not found (404)')
                }

                { Remove-ConfluencePage -PageId '999' -Force -Confirm:$false } | Should Throw 'was not found'
            }
        }

        It 'Throws when access denied' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    throw [System.Exception]::new('Access forbidden (403)')
                }

                { Remove-ConfluencePage -PageId '123' -Force -Confirm:$false } | Should Throw 'Access denied'
            }
        }

        It 'Includes PageId in error message' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    throw [System.Exception]::new('Resource not found (404)')
                }

                try {
                    Remove-ConfluencePage -PageId 'MYPAGE555' -Force -Confirm:$false
                }
                catch {
                    $_.Exception.Message | Should Match 'MYPAGE555'
                }
            }
        }
    }

    Context 'Verbose Output' {
        It 'Logs verbose message when removing page' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    return $null
                }
                Mock Write-Verbose { } -Verifiable

                Remove-ConfluencePage -PageId '123456' -Force -Confirm:$false -Verbose
                Assert-MockCalled Write-Verbose
            }
        }

        It 'Verbose output does not contain API token' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    return $null
                }

                $verboseOutput = @()
                Remove-ConfluencePage -PageId '123456' -Force -Confirm:$false -Verbose 4>&1 | ForEach-Object {
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

    Context 'Pipeline Support' {
        It 'Accepts PageId from pipeline by property name' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    return $null
                }

                $page = [PSCustomObject]@{ Id = '123456'; Title = 'Test' }
                $page | Remove-ConfluencePage -Force -Confirm:$false
                Assert-MockCalled Invoke-ConfluenceRequest -ParameterFilter {
                    $Endpoint -eq '/wiki/api/v2/pages/123456'
                }
            }
        }

        It 'Processes multiple pages from pipeline' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    return $null
                }

                $pages = @(
                    [PSCustomObject]@{ Id = '111'; Title = 'Page 1' },
                    [PSCustomObject]@{ Id = '222'; Title = 'Page 2' }
                )
                $pages | Remove-ConfluencePage -Force -Confirm:$false
                Assert-MockCalled Invoke-ConfluenceRequest -Times 2
            }
        }
    }

    Context 'ConfirmImpact' {
        It 'Has ConfirmImpact set to High' {
            $command = Get-Command Remove-ConfluencePage
            $cmdletBinding = $command.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }
            $cmdletBinding.ConfirmImpact | Should Be 'High'
        }
    }
}
