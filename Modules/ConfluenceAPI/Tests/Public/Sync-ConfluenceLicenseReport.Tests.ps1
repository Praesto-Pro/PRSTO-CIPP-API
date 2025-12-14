$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleRoot = Split-Path -Parent (Split-Path -Parent $here)
$publicDir = Join-Path $moduleRoot 'Public'

Describe 'Sync-ConfluenceLicenseReport' {
    BeforeAll {
        # Define stub functions for dependencies that will be mocked (Pester 3.4 requirement)
        # Public dependencies
        function Get-ConfluenceSpace { param($SpaceKey) }
        function Search-Confluence { param($CQL) }
        function New-ConfluencePage { param($SpaceKey, $Title, $Body, $ParentId) }
        function Set-ConfluencePage { param($PageId, $Body) }
        # Private dependency - stub for isolation
        function ConvertTo-ConfluenceLicensePage { param($Licenses, $Users) }

        # Dot-source the function under test
        . "$publicDir\Sync-ConfluenceLicenseReport.ps1"
    }

    Context 'New Page Creation (AC1)' {
        BeforeAll {
            $script:capturedNewPageParams = $null
            Mock Get-ConfluenceSpace { return [PSCustomObject]@{ Id = '123'; Key = 'CONTOSO'; Name = 'Contoso Corp' } }
            Mock Search-Confluence { return $null }
            Mock ConvertTo-ConfluenceLicensePage { return '{"version":1,"type":"doc","content":[]}' }
            Mock New-ConfluencePage {
                param($SpaceKey, $Title, $Body, $ParentId)
                $script:capturedNewPageParams = @{
                    SpaceKey = $SpaceKey
                    Title = $Title
                    Body = $Body
                    ParentId = $ParentId
                }
                return [PSCustomObject]@{ Id = '456'; Title = 'License Report'; Version = @{ Number = 1 } }
            }
        }

        It 'Creates page when none exists' {
            $testLicenses = @(
                [PSCustomObject]@{ skuId = 'sku1'; skuPartNumber = 'E3'; prepaidUnits = @{ enabled = 100 }; consumedUnits = 50 }
            )

            $result = Sync-ConfluenceLicenseReport -SpaceKey 'CONTOSO' -Licenses $testLicenses

            $result | Should Not Be $null
            $result.Action | Should Be 'Created'
        }

        It 'Returns PSCustomObject with correct properties' {
            $testLicenses = @(
                [PSCustomObject]@{ skuId = 'sku1'; skuPartNumber = 'E3'; prepaidUnits = @{ enabled = 100 }; consumedUnits = 50 }
            )

            $result = Sync-ConfluenceLicenseReport -SpaceKey 'CONTOSO' -Licenses $testLicenses

            $result.Id | Should Be '456'
            $result.Title | Should Be 'License Report'
            $result.SpaceKey | Should Be 'CONTOSO'
            $result.Version | Should Be 1
            $result.Action | Should Be 'Created'
        }

        It 'Calls New-ConfluencePage with correct parameters' {
            $testLicenses = @(
                [PSCustomObject]@{ skuId = 'sku1'; skuPartNumber = 'E3'; prepaidUnits = @{ enabled = 100 }; consumedUnits = 50 }
            )

            Sync-ConfluenceLicenseReport -SpaceKey 'CONTOSO' -Licenses $testLicenses

            Assert-MockCalled New-ConfluencePage -Times 1 -Scope It
        }

        It 'Uses default page title when not specified' {
            $testLicenses = @(
                [PSCustomObject]@{ skuId = 'sku1'; skuPartNumber = 'E3'; prepaidUnits = @{ enabled = 100 }; consumedUnits = 50 }
            )

            Sync-ConfluenceLicenseReport -SpaceKey 'CONTOSO' -Licenses $testLicenses

            $script:capturedNewPageParams.Title | Should Be 'License Report'
        }

        It 'Uses custom page title when specified' {
            $script:capturedNewPageParams = $null
            $testLicenses = @(
                [PSCustomObject]@{ skuId = 'sku1'; skuPartNumber = 'E3'; prepaidUnits = @{ enabled = 100 }; consumedUnits = 50 }
            )

            Sync-ConfluenceLicenseReport -SpaceKey 'CONTOSO' -Licenses $testLicenses -PageTitle 'My License Report'

            $script:capturedNewPageParams.Title | Should Be 'My License Report'
        }
    }

    Context 'Update Existing Page (AC2)' {
        BeforeAll {
            $script:capturedSetPageParams = $null
            Mock Get-ConfluenceSpace { return [PSCustomObject]@{ Id = '123'; Key = 'CONTOSO'; Name = 'Contoso Corp' } }
            Mock Search-Confluence { return [PSCustomObject]@{ Id = '789'; Title = 'License Report' } }
            Mock ConvertTo-ConfluenceLicensePage { return '{"version":1,"type":"doc","content":[]}' }
            Mock Set-ConfluencePage {
                param($PageId, $Body)
                $script:capturedSetPageParams = @{
                    PageId = $PageId
                    Body = $Body
                }
                return [PSCustomObject]@{ Id = '789'; Title = 'License Report'; Version = @{ Number = 5 } }
            }
            Mock New-ConfluencePage { throw "Should not be called when page exists" }
        }

        It 'Updates page when one already exists' {
            $testLicenses = @(
                [PSCustomObject]@{ skuId = 'sku1'; skuPartNumber = 'E3'; prepaidUnits = @{ enabled = 100 }; consumedUnits = 50 }
            )

            $result = Sync-ConfluenceLicenseReport -SpaceKey 'CONTOSO' -Licenses $testLicenses

            $result | Should Not Be $null
            $result.Action | Should Be 'Updated'
        }

        It 'Returns incremented version on update' {
            $testLicenses = @(
                [PSCustomObject]@{ skuId = 'sku1'; skuPartNumber = 'E3'; prepaidUnits = @{ enabled = 100 }; consumedUnits = 50 }
            )

            $result = Sync-ConfluenceLicenseReport -SpaceKey 'CONTOSO' -Licenses $testLicenses

            $result.Version | Should Be 5
        }

        It 'Calls Set-ConfluencePage with existing page ID' {
            $testLicenses = @(
                [PSCustomObject]@{ skuId = 'sku1'; skuPartNumber = 'E3'; prepaidUnits = @{ enabled = 100 }; consumedUnits = 50 }
            )

            Sync-ConfluenceLicenseReport -SpaceKey 'CONTOSO' -Licenses $testLicenses

            Assert-MockCalled Set-ConfluencePage -Times 1 -Scope It
            $script:capturedSetPageParams.PageId | Should Be '789'
        }

        It 'Does not call New-ConfluencePage when page exists' {
            $testLicenses = @(
                [PSCustomObject]@{ skuId = 'sku1'; skuPartNumber = 'E3'; prepaidUnits = @{ enabled = 100 }; consumedUnits = 50 }
            )

            Sync-ConfluenceLicenseReport -SpaceKey 'CONTOSO' -Licenses $testLicenses

            Assert-MockCalled New-ConfluencePage -Times 0 -Scope It
        }
    }

    Context 'License Assignments with Users Parameter (AC4)' {
        BeforeAll {
            $script:capturedTransformerParams = $null
            Mock Get-ConfluenceSpace { return [PSCustomObject]@{ Id = '123'; Key = 'CONTOSO'; Name = 'Contoso Corp' } }
            Mock Search-Confluence { return $null }
            Mock ConvertTo-ConfluenceLicensePage {
                param($Licenses, $Users)
                $script:capturedTransformerParams = @{
                    Licenses = $Licenses
                    Users = $Users
                }
                return '{"version":1,"type":"doc","content":[]}'
            }
            Mock New-ConfluencePage { return [PSCustomObject]@{ Id = '456'; Title = 'License Report'; Version = @{ Number = 1 } } }
        }

        It 'Passes Users parameter to transformer' {
            $testLicenses = @(
                [PSCustomObject]@{ skuId = 'sku1'; skuPartNumber = 'E3'; prepaidUnits = @{ enabled = 100 }; consumedUnits = 50 }
            )
            $testUsers = @(
                [PSCustomObject]@{ displayName = 'John Doe'; userPrincipalName = 'john@contoso.com'; assignedLicenses = @(@{ skuId = 'sku1' }) }
            )

            Sync-ConfluenceLicenseReport -SpaceKey 'CONTOSO' -Licenses $testLicenses -Users $testUsers

            $script:capturedTransformerParams.Users | Should Not Be $null
            $script:capturedTransformerParams.Users.Count | Should Be 1
            $script:capturedTransformerParams.Users[0].displayName | Should Be 'John Doe'
        }

        It 'Passes Licenses parameter to transformer' {
            $testLicenses = @(
                [PSCustomObject]@{ skuId = 'sku1'; skuPartNumber = 'E3'; prepaidUnits = @{ enabled = 100 }; consumedUnits = 50 }
            )

            Sync-ConfluenceLicenseReport -SpaceKey 'CONTOSO' -Licenses $testLicenses

            $script:capturedTransformerParams.Licenses | Should Not Be $null
            $script:capturedTransformerParams.Licenses.Count | Should Be 1
        }
    }

    Context 'WhatIf Support (AC6)' {
        BeforeAll {
            Mock Get-ConfluenceSpace { return [PSCustomObject]@{ Id = '123'; Key = 'CONTOSO'; Name = 'Contoso Corp' } }
            Mock Search-Confluence { return $null }
            Mock ConvertTo-ConfluenceLicensePage { return '{"version":1,"type":"doc","content":[]}' }
            Mock New-ConfluencePage { throw "Should not be called with WhatIf" }
            Mock Set-ConfluencePage { throw "Should not be called with WhatIf" }
        }

        It 'Does not create page when WhatIf is specified' {
            $testLicenses = @(
                [PSCustomObject]@{ skuId = 'sku1'; skuPartNumber = 'E3'; prepaidUnits = @{ enabled = 100 }; consumedUnits = 50 }
            )

            Sync-ConfluenceLicenseReport -SpaceKey 'CONTOSO' -Licenses $testLicenses -WhatIf

            Assert-MockCalled New-ConfluencePage -Times 0 -Scope It
        }

        It 'Returns null when WhatIf is specified' {
            $testLicenses = @(
                [PSCustomObject]@{ skuId = 'sku1'; skuPartNumber = 'E3'; prepaidUnits = @{ enabled = 100 }; consumedUnits = 50 }
            )

            $result = Sync-ConfluenceLicenseReport -SpaceKey 'CONTOSO' -Licenses $testLicenses -WhatIf

            $result | Should Be $null
        }
    }

    Context 'WhatIf with Existing Page (AC6)' {
        BeforeAll {
            Mock Get-ConfluenceSpace { return [PSCustomObject]@{ Id = '123'; Key = 'CONTOSO'; Name = 'Contoso Corp' } }
            Mock Search-Confluence { return [PSCustomObject]@{ Id = '789'; Title = 'License Report' } }
            Mock ConvertTo-ConfluenceLicensePage { return '{"version":1,"type":"doc","content":[]}' }
            Mock Set-ConfluencePage { throw "Should not be called with WhatIf" }
        }

        It 'Does not update page when WhatIf is specified' {
            $testLicenses = @(
                [PSCustomObject]@{ skuId = 'sku1'; skuPartNumber = 'E3'; prepaidUnits = @{ enabled = 100 }; consumedUnits = 50 }
            )

            Sync-ConfluenceLicenseReport -SpaceKey 'CONTOSO' -Licenses $testLicenses -WhatIf

            Assert-MockCalled Set-ConfluencePage -Times 0 -Scope It
        }
    }

    Context 'Verbose Logging (AC7)' {
        BeforeAll {
            Mock Get-ConfluenceSpace { return [PSCustomObject]@{ Id = '123'; Key = 'CONTOSO'; Name = 'Contoso Corp' } }
            Mock Search-Confluence { return $null }
            Mock ConvertTo-ConfluenceLicensePage { return '{"version":1,"type":"doc","content":[]}' }
            Mock New-ConfluencePage { return [PSCustomObject]@{ Id = '456'; Title = 'License Report'; Version = @{ Number = 1 } } }
        }

        It 'Writes verbose message about syncing to space' {
            $testLicenses = @(
                [PSCustomObject]@{ skuId = 'sku1'; skuPartNumber = 'E3'; prepaidUnits = @{ enabled = 100 }; consumedUnits = 50 }
            )

            $verboseOutput = Sync-ConfluenceLicenseReport -SpaceKey 'CONTOSO' -Licenses $testLicenses -Verbose 4>&1

            $verboseOutput | Where-Object { $_ -like "*Syncing license report to space*" } | Should Not Be $null
        }

        It 'Writes verbose message about ADF content generation' {
            $testLicenses = @(
                [PSCustomObject]@{ skuId = 'sku1'; skuPartNumber = 'E3'; prepaidUnits = @{ enabled = 100 }; consumedUnits = 50 }
            )

            $verboseOutput = Sync-ConfluenceLicenseReport -SpaceKey 'CONTOSO' -Licenses $testLicenses -Verbose 4>&1

            $verboseOutput | Where-Object { $_ -like "*Generated ADF content*" } | Should Not Be $null
        }

        It 'Writes verbose message about CQL search' {
            $testLicenses = @(
                [PSCustomObject]@{ skuId = 'sku1'; skuPartNumber = 'E3'; prepaidUnits = @{ enabled = 100 }; consumedUnits = 50 }
            )

            $verboseOutput = Sync-ConfluenceLicenseReport -SpaceKey 'CONTOSO' -Licenses $testLicenses -Verbose 4>&1

            $verboseOutput | Where-Object { $_ -like "*Searching for existing page with CQL*" } | Should Not Be $null
        }

        It 'Writes verbose message about page creation' {
            $testLicenses = @(
                [PSCustomObject]@{ skuId = 'sku1'; skuPartNumber = 'E3'; prepaidUnits = @{ enabled = 100 }; consumedUnits = 50 }
            )

            $verboseOutput = Sync-ConfluenceLicenseReport -SpaceKey 'CONTOSO' -Licenses $testLicenses -Verbose 4>&1

            $verboseOutput | Where-Object { $_ -like "*Successfully created page*" } | Should Not Be $null
        }
    }

    Context 'Space Validation Error (AC8)' {
        BeforeAll {
            Mock Get-ConfluenceSpace { return $null }
            Mock Search-Confluence { throw "Should not be called when space doesn't exist" }
            Mock ConvertTo-ConfluenceLicensePage { throw "Should not be called when space doesn't exist" }
        }

        It 'Throws terminating error for non-existent space' {
            $testLicenses = @(
                [PSCustomObject]@{ skuId = 'sku1'; skuPartNumber = 'E3'; prepaidUnits = @{ enabled = 100 }; consumedUnits = 50 }
            )

            { Sync-ConfluenceLicenseReport -SpaceKey 'INVALID' -Licenses $testLicenses } | Should Throw
        }

        It 'Error message includes space key' {
            $testLicenses = @(
                [PSCustomObject]@{ skuId = 'sku1'; skuPartNumber = 'E3'; prepaidUnits = @{ enabled = 100 }; consumedUnits = 50 }
            )

            try {
                Sync-ConfluenceLicenseReport -SpaceKey 'INVALID' -Licenses $testLicenses
            }
            catch {
                $_.Exception.Message | Should Match 'INVALID'
            }
        }

        It 'Error message includes actionable guidance mentioning Get-ConfluenceSpace' {
            $testLicenses = @(
                [PSCustomObject]@{ skuId = 'sku1'; skuPartNumber = 'E3'; prepaidUnits = @{ enabled = 100 }; consumedUnits = 50 }
            )

            try {
                Sync-ConfluenceLicenseReport -SpaceKey 'INVALID' -Licenses $testLicenses
            }
            catch {
                $_.Exception.Message | Should Match 'Get-ConfluenceSpace'
            }
        }
    }

    Context 'Empty License Data Handling (AC9)' {
        BeforeAll {
            Mock Get-ConfluenceSpace { return [PSCustomObject]@{ Id = '123'; Key = 'CONTOSO'; Name = 'Contoso Corp' } }
            Mock Search-Confluence { return $null }
            Mock ConvertTo-ConfluenceLicensePage { return '{"version":1,"type":"doc","content":[]}' }
            Mock New-ConfluencePage { return [PSCustomObject]@{ Id = '456'; Title = 'License Report'; Version = @{ Number = 1 } } }
        }

        It 'Handles null licenses without error' {
            { Sync-ConfluenceLicenseReport -SpaceKey 'CONTOSO' -Licenses $null } | Should Not Throw
        }

        It 'Handles empty array without error' {
            { Sync-ConfluenceLicenseReport -SpaceKey 'CONTOSO' -Licenses @() } | Should Not Throw
        }

        It 'Creates page with empty license data' {
            $result = Sync-ConfluenceLicenseReport -SpaceKey 'CONTOSO' -Licenses $null

            $result | Should Not Be $null
            $result.Action | Should Be 'Created'
        }
    }

    Context 'Parent Page Hierarchy (AC10)' {
        BeforeAll {
            $script:capturedNewPageParams = $null
            Mock Get-ConfluenceSpace { return [PSCustomObject]@{ Id = '123'; Key = 'CONTOSO'; Name = 'Contoso Corp' } }
            Mock Search-Confluence { return $null }
            Mock ConvertTo-ConfluenceLicensePage { return '{"version":1,"type":"doc","content":[]}' }
            Mock New-ConfluencePage {
                param($SpaceKey, $Title, $Body, $ParentId)
                $script:capturedNewPageParams = @{
                    SpaceKey = $SpaceKey
                    Title = $Title
                    Body = $Body
                    ParentId = $ParentId
                }
                return [PSCustomObject]@{ Id = '456'; Title = 'License Report'; Version = @{ Number = 1 } }
            }
        }

        It 'Accepts ParentPageId parameter' {
            $testLicenses = @(
                [PSCustomObject]@{ skuId = 'sku1'; skuPartNumber = 'E3'; prepaidUnits = @{ enabled = 100 }; consumedUnits = 50 }
            )

            { Sync-ConfluenceLicenseReport -SpaceKey 'CONTOSO' -Licenses $testLicenses -ParentPageId '12345' } | Should Not Throw
        }

        It 'Passes ParentPageId to New-ConfluencePage' {
            $script:capturedNewPageParams = $null
            $testLicenses = @(
                [PSCustomObject]@{ skuId = 'sku1'; skuPartNumber = 'E3'; prepaidUnits = @{ enabled = 100 }; consumedUnits = 50 }
            )

            Sync-ConfluenceLicenseReport -SpaceKey 'CONTOSO' -Licenses $testLicenses -ParentPageId '12345'

            $script:capturedNewPageParams.ParentId | Should Be '12345'
        }

        It 'Does not pass ParentId when not specified' {
            $script:capturedNewPageParams = $null
            $testLicenses = @(
                [PSCustomObject]@{ skuId = 'sku1'; skuPartNumber = 'E3'; prepaidUnits = @{ enabled = 100 }; consumedUnits = 50 }
            )

            Sync-ConfluenceLicenseReport -SpaceKey 'CONTOSO' -Licenses $testLicenses

            $script:capturedNewPageParams.ParentId | Should Be $null
        }
    }

    Context 'CQL Query Safety' {
        BeforeAll {
            $script:capturedCQL = $null
            Mock Get-ConfluenceSpace { return [PSCustomObject]@{ Id = '123'; Key = 'TEST'; Name = 'Test' } }
            Mock Search-Confluence {
                param($CQL)
                $script:capturedCQL = $CQL
                return $null
            }
            Mock ConvertTo-ConfluenceLicensePage { return '{"version":1,"type":"doc","content":[]}' }
            Mock New-ConfluencePage { return [PSCustomObject]@{ Id = '456'; Title = 'License Report'; Version = @{ Number = 1 } } }
        }

        It 'Uses correct CQL query format' {
            Sync-ConfluenceLicenseReport -SpaceKey 'CONTOSO' -Licenses @()

            $script:capturedCQL | Should Match "space = 'CONTOSO'"
            $script:capturedCQL | Should Match "title = 'License Report'"
            $script:capturedCQL | Should Match "type = page"
        }

        It 'Escapes single quotes in SpaceKey for CQL safety' {
            Sync-ConfluenceLicenseReport -SpaceKey "O'Brien" -Licenses @()

            $script:capturedCQL | Should Match "space = 'O''Brien'"
        }

        It 'Escapes single quotes in PageTitle for CQL safety' {
            Sync-ConfluenceLicenseReport -SpaceKey 'CONTOSO' -Licenses @() -PageTitle "John's Report"

            $script:capturedCQL | Should Match "title = 'John''s Report'"
        }
    }

    Context 'Verbose Logging for Update Path' {
        BeforeAll {
            Mock Get-ConfluenceSpace { return [PSCustomObject]@{ Id = '123'; Key = 'CONTOSO'; Name = 'Contoso Corp' } }
            Mock Search-Confluence { return [PSCustomObject]@{ Id = '789'; Title = 'License Report' } }
            Mock ConvertTo-ConfluenceLicensePage { return '{"version":1,"type":"doc","content":[]}' }
            Mock Set-ConfluencePage { return [PSCustomObject]@{ Id = '789'; Title = 'License Report'; Version = @{ Number = 5 } } }
        }

        It 'Writes verbose message about finding existing page' {
            $testLicenses = @(
                [PSCustomObject]@{ skuId = 'sku1'; skuPartNumber = 'E3'; prepaidUnits = @{ enabled = 100 }; consumedUnits = 50 }
            )

            $verboseOutput = Sync-ConfluenceLicenseReport -SpaceKey 'CONTOSO' -Licenses $testLicenses -Verbose 4>&1

            $verboseOutput | Where-Object { $_ -like "*Found existing page*updating*" } | Should Not Be $null
        }

        It 'Writes verbose message about successful update' {
            $testLicenses = @(
                [PSCustomObject]@{ skuId = 'sku1'; skuPartNumber = 'E3'; prepaidUnits = @{ enabled = 100 }; consumedUnits = 50 }
            )

            $verboseOutput = Sync-ConfluenceLicenseReport -SpaceKey 'CONTOSO' -Licenses $testLicenses -Verbose 4>&1

            $verboseOutput | Where-Object { $_ -like "*Successfully updated page*" } | Should Not Be $null
        }
    }

    Context 'Verbose Logging for ParentPageId' {
        BeforeAll {
            Mock Get-ConfluenceSpace { return [PSCustomObject]@{ Id = '123'; Key = 'CONTOSO'; Name = 'Contoso Corp' } }
            Mock Search-Confluence { return $null }
            Mock ConvertTo-ConfluenceLicensePage { return '{"version":1,"type":"doc","content":[]}' }
            Mock New-ConfluencePage { return [PSCustomObject]@{ Id = '456'; Title = 'License Report'; Version = @{ Number = 1 } } }
        }

        It 'Writes verbose message about parent page when specified' {
            $testLicenses = @(
                [PSCustomObject]@{ skuId = 'sku1'; skuPartNumber = 'E3'; prepaidUnits = @{ enabled = 100 }; consumedUnits = 50 }
            )

            $verboseOutput = Sync-ConfluenceLicenseReport -SpaceKey 'CONTOSO' -Licenses $testLicenses -ParentPageId '12345' -Verbose 4>&1

            $verboseOutput | Where-Object { $_ -like "*Creating page under parent ID: 12345*" } | Should Not Be $null
        }
    }
}
