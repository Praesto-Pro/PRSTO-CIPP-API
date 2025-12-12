#Requires -Modules Pester

Describe 'Remove-ConfluenceLabel' {
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

    Context 'Remove Standard Label' {
        It 'Removes label using path parameter for normal label' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest { }

                Remove-ConfluenceLabel -PageId '12345' -Label 'old-label' -Confirm:$false
                Assert-MockCalled Invoke-ConfluenceRequest -ParameterFilter {
                    $Endpoint -eq '/wiki/rest/api/content/12345/label/old-label' -and $Method -eq 'DELETE'
                }
            }
        }

        It 'Returns nothing on successful delete (204 No Content)' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest { }

                $result = Remove-ConfluenceLabel -PageId '12345' -Label 'test' -Confirm:$false
                $result | Should Be $null
            }
        }
    }

    Context 'Remove Label with Special Characters' {
        It 'Removes label using query parameter when label contains "/"' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest { }

                Remove-ConfluenceLabel -PageId '12345' -Label 'category/subcategory' -Confirm:$false
                Assert-MockCalled Invoke-ConfluenceRequest -ParameterFilter {
                    $Endpoint -match '/wiki/rest/api/content/12345/label\?name=' -and $Method -eq 'DELETE'
                }
            }
        }

        It 'URL-encodes label name for query parameter' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest { }

                Remove-ConfluenceLabel -PageId '12345' -Label 'cat/sub' -Confirm:$false
                # "/" becomes %2F when URL encoded
                Assert-MockCalled Invoke-ConfluenceRequest -ParameterFilter {
                    $Endpoint -eq '/wiki/rest/api/content/12345/label?name=cat%2Fsub' -and $Method -eq 'DELETE'
                }
            }
        }

        It 'Handles multiple "/" characters in label' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest { }

                Remove-ConfluenceLabel -PageId '12345' -Label 'a/b/c' -Confirm:$false
                Assert-MockCalled Invoke-ConfluenceRequest -ParameterFilter {
                    $Endpoint -eq '/wiki/rest/api/content/12345/label?name=a%2Fb%2Fc' -and $Method -eq 'DELETE'
                }
            }
        }

        It 'Uses path parameter when label has no "/"' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest { }

                Remove-ConfluenceLabel -PageId '12345' -Label 'simple-label' -Confirm:$false
                Assert-MockCalled Invoke-ConfluenceRequest -ParameterFilter {
                    $Endpoint -eq '/wiki/rest/api/content/12345/label/simple-label' -and $Method -eq 'DELETE'
                }
            }
        }
    }

    Context 'WhatIf Support' {
        It 'WhatIf does not call API' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest { }

                Remove-ConfluenceLabel -PageId '12345' -Label 'test' -WhatIf
                Assert-MockCalled Invoke-ConfluenceRequest -Times 0
            }
        }

        It 'Returns nothing when WhatIf is used' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest { }

                $result = Remove-ConfluenceLabel -PageId '12345' -Label 'test' -WhatIf
                $result | Should Be $null
            }
        }
    }

    Context 'Confirm Support' {
        It 'Supports ConfirmImpact Medium attribute' {
            $cmd = Get-Command Remove-ConfluenceLabel
            $cmd.Parameters['Confirm'] | Should Not Be $null
            $cmdletBinding = $cmd.ScriptBlock.Attributes | Where-Object { $_.TypeId.Name -eq 'CmdletBindingAttribute' }
            $cmdletBinding.ConfirmImpact | Should Be 'Medium'
        }

        It 'Does not call API when Confirm is not approved' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest { }

                # Using -WhatIf as a proxy since we can't mock the confirmation dialog
                Remove-ConfluenceLabel -PageId '12345' -Label 'test' -WhatIf
                Assert-MockCalled Invoke-ConfluenceRequest -Times 0
            }
        }

        It 'Calls API when Confirm is bypassed' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest { }

                Remove-ConfluenceLabel -PageId '12345' -Label 'test' -Confirm:$false
                Assert-MockCalled Invoke-ConfluenceRequest -Times 1
            }
        }
    }

    Context 'Error Handling' {
        It '404 throws with appropriate error message' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    throw [System.Exception]::new('Resource not found (404)')
                }

                { Remove-ConfluenceLabel -PageId '999' -Label 'missing' -Confirm:$false } | Should Throw 'not found'
            }
        }

        It '404 with label context throws "Label not found" message' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    throw [System.Exception]::new('No label found (404)')
                }

                try {
                    Remove-ConfluenceLabel -PageId '12345' -Label 'missing-label' -Confirm:$false
                }
                catch {
                    $_.Exception.Message | Should Match 'missing-label'
                    $_.Exception.Message | Should Match 'not found'
                }
            }
        }

        It '404 without label context throws "Page not found" message' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    throw [System.Exception]::new('Resource not found (404)')
                }

                try {
                    Remove-ConfluenceLabel -PageId 'BADPAGE' -Label 'test' -Confirm:$false
                }
                catch {
                    $_.Exception.Message | Should Match 'BADPAGE'
                }
            }
        }

        It '403 throws with "Access denied" message' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    throw [System.Exception]::new('Forbidden (403)')
                }

                { Remove-ConfluenceLabel -PageId '999' -Label 'test' -Confirm:$false } | Should Throw 'Access denied'
            }
        }

        It '403 error includes PageId in message' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    throw [System.Exception]::new('Forbidden (403)')
                }

                try {
                    Remove-ConfluenceLabel -PageId 'MYPAGE789' -Label 'test' -Confirm:$false
                }
                catch {
                    $_.Exception.Message | Should Match 'MYPAGE789'
                }
            }
        }

        It 'Generic error includes context information' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    throw [System.Exception]::new('Connection timeout')
                }

                try {
                    Remove-ConfluenceLabel -PageId '12345' -Label 'test' -Confirm:$false
                }
                catch {
                    $_.Exception.Message | Should Match '12345'
                    $_.Exception.Message | Should Match 'test'
                    $_.Exception.Message | Should Match 'Failed to remove'
                }
            }
        }
    }

    Context 'Verbose Output' {
        It 'Verbose output logs label being removed' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest { }

                $verboseOutput = @()
                Remove-ConfluenceLabel -PageId '12345' -Label 'old-label' -Confirm:$false -Verbose 4>&1 | ForEach-Object {
                    if ($_ -is [System.Management.Automation.VerboseRecord]) {
                        $verboseOutput += $_.Message
                    }
                }

                ($verboseOutput -join ' ') | Should Match 'old-label'
            }
        }

        It 'Verbose output logs page ID' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest { }

                $verboseOutput = @()
                Remove-ConfluenceLabel -PageId '67890' -Label 'test' -Confirm:$false -Verbose 4>&1 | ForEach-Object {
                    if ($_ -is [System.Management.Automation.VerboseRecord]) {
                        $verboseOutput += $_.Message
                    }
                }

                ($verboseOutput -join ' ') | Should Match '67890'
            }
        }

        It 'Verbose output does not contain API token' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest { }

                $verboseOutput = @()
                Remove-ConfluenceLabel -PageId '12345' -Label 'test' -Confirm:$false -Verbose 4>&1 | ForEach-Object {
                    if ($_ -is [System.Management.Automation.VerboseRecord]) {
                        $verboseOutput += $_.Message
                    }
                }

                foreach ($msg in $verboseOutput) {
                    $msg | Should Not Match 'test-token'
                }
            }
        }

        It 'Logs success message after removal' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest { }

                $verboseOutput = @()
                Remove-ConfluenceLabel -PageId '12345' -Label 'removed-label' -Confirm:$false -Verbose 4>&1 | ForEach-Object {
                    if ($_ -is [System.Management.Automation.VerboseRecord]) {
                        $verboseOutput += $_.Message
                    }
                }

                ($verboseOutput -join ' ') | Should Match 'Successfully removed'
            }
        }

        It 'Logs when using query parameter method for "/" labels' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest { }

                $verboseOutput = @()
                Remove-ConfluenceLabel -PageId '12345' -Label 'cat/sub' -Confirm:$false -Verbose 4>&1 | ForEach-Object {
                    if ($_ -is [System.Management.Automation.VerboseRecord]) {
                        $verboseOutput += $_.Message
                    }
                }

                ($verboseOutput -join ' ') | Should Match 'query parameter'
            }
        }
    }

    Context 'Parameter Validation' {
        It 'Requires PageId parameter' {
            { Remove-ConfluenceLabel -Label 'test' -Confirm:$false } | Should Throw
        }

        It 'Requires Label parameter' {
            { Remove-ConfluenceLabel -PageId '12345' -Confirm:$false } | Should Throw
        }

        It 'Does not accept empty PageId' {
            { Remove-ConfluenceLabel -PageId '' -Label 'test' -Confirm:$false } | Should Throw
        }

        It 'Does not accept empty Label' {
            { Remove-ConfluenceLabel -PageId '12345' -Label '' -Confirm:$false } | Should Throw
        }
    }

    Context 'Pipeline Support' {
        It 'Accepts Label from pipeline by property name (Name alias)' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest { }

                $labelObject = [PSCustomObject]@{ Name = 'piped-label' }
                $labelObject | Remove-ConfluenceLabel -PageId '12345' -Confirm:$false
                Assert-MockCalled Invoke-ConfluenceRequest -ParameterFilter {
                    $Endpoint -eq '/wiki/rest/api/content/12345/label/piped-label' -and $Method -eq 'DELETE'
                }
            }
        }

        It 'Processes multiple labels from pipeline' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest { }

                $labels = @(
                    [PSCustomObject]@{ Name = 'label1' },
                    [PSCustomObject]@{ Name = 'label2' }
                )
                $labels | Remove-ConfluenceLabel -PageId '12345' -Confirm:$false
                Assert-MockCalled Invoke-ConfluenceRequest -Times 2
            }
        }

        It 'Has OutputType of void' {
            $cmd = Get-Command Remove-ConfluenceLabel
            $outputType = $cmd.OutputType
            $outputType.Type.Name | Should Be 'Void'
        }
    }
}
