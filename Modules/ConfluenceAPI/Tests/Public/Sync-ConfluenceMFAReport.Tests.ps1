$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleRoot = Split-Path -Parent (Split-Path -Parent $here)
$publicDir = Join-Path $moduleRoot 'Public'

Describe 'Sync-ConfluenceMFAReport' {
    BeforeAll {
        # Define stub functions for dependencies that will be mocked (Pester 3.4 requirement)
        # Public dependencies
        function Get-ConfluenceSpace { param($SpaceKey) }
        function Search-Confluence { param($CQL) }
        function New-ConfluencePage { param($SpaceKey, $Title, $Body, $ParentId) }
        function Set-ConfluencePage { param($PageId, $Body) }
        # Private dependency - stub for isolation
        function ConvertTo-ConfluenceMFAPage { param($MFAData) }

        # Dot-source the function under test
        . "$publicDir\Sync-ConfluenceMFAReport.ps1"
    }

    Context 'New Page Creation (AC1)' {
        BeforeAll {
            $script:capturedNewPageParams = $null
            Mock Get-ConfluenceSpace { return [PSCustomObject]@{ Id = '123'; Key = 'CONTOSO'; Name = 'Contoso Corp' } }
            Mock Search-Confluence { return $null }
            Mock ConvertTo-ConfluenceMFAPage { return '{"version":1,"type":"doc","content":[]}' }
            Mock New-ConfluencePage {
                param($SpaceKey, $Title, $Body, $ParentId)
                $script:capturedNewPageParams = @{
                    SpaceKey = $SpaceKey
                    Title = $Title
                    Body = $Body
                    ParentId = $ParentId
                }
                return [PSCustomObject]@{ Id = '456'; Title = 'MFA Status'; Version = @{ Number = 1 } }
            }
        }

        It 'Creates page when none exists' {
            $testMFAData = @(
                [PSCustomObject]@{ displayName = 'User1'; isMfaRegistered = $true }
            )

            $result = Sync-ConfluenceMFAReport -SpaceKey 'CONTOSO' -MFAData $testMFAData

            $result | Should Not Be $null
            $result.Action | Should Be 'Created'
        }

        It 'Returns PSCustomObject with correct properties' {
            $testMFAData = @(
                [PSCustomObject]@{ displayName = 'User1'; isMfaRegistered = $true }
            )

            $result = Sync-ConfluenceMFAReport -SpaceKey 'CONTOSO' -MFAData $testMFAData

            $result.Id | Should Be '456'
            $result.Title | Should Be 'MFA Status'
            $result.SpaceKey | Should Be 'CONTOSO'
            $result.Version | Should Be 1
            $result.Action | Should Be 'Created'
        }

        It 'Calls New-ConfluencePage with correct parameters' {
            $testMFAData = @(
                [PSCustomObject]@{ displayName = 'User1'; isMfaRegistered = $true }
            )

            Sync-ConfluenceMFAReport -SpaceKey 'CONTOSO' -MFAData $testMFAData

            Assert-MockCalled New-ConfluencePage -Times 1 -Scope It
        }

        It 'Uses default page title when not specified' {
            $testMFAData = @(
                [PSCustomObject]@{ displayName = 'User1'; isMfaRegistered = $true }
            )

            Sync-ConfluenceMFAReport -SpaceKey 'CONTOSO' -MFAData $testMFAData

            $script:capturedNewPageParams.Title | Should Be 'MFA Status'
        }

        It 'Uses custom page title when specified' {
            $script:capturedNewPageParams = $null
            $testMFAData = @(
                [PSCustomObject]@{ displayName = 'User1'; isMfaRegistered = $true }
            )

            Sync-ConfluenceMFAReport -SpaceKey 'CONTOSO' -MFAData $testMFAData -PageTitle 'Security - MFA Report'

            $script:capturedNewPageParams.Title | Should Be 'Security - MFA Report'
        }
    }

    Context 'Update Existing Page (AC2)' {
        BeforeAll {
            $script:capturedSetPageParams = $null
            Mock Get-ConfluenceSpace { return [PSCustomObject]@{ Id = '123'; Key = 'CONTOSO'; Name = 'Contoso Corp' } }
            Mock Search-Confluence { return [PSCustomObject]@{ Id = '789'; Title = 'MFA Status' } }
            Mock ConvertTo-ConfluenceMFAPage { return '{"version":1,"type":"doc","content":[]}' }
            Mock Set-ConfluencePage {
                param($PageId, $Body)
                $script:capturedSetPageParams = @{
                    PageId = $PageId
                    Body = $Body
                }
                return [PSCustomObject]@{ Id = '789'; Title = 'MFA Status'; Version = @{ Number = 5 } }
            }
            Mock New-ConfluencePage { throw "Should not be called when page exists" }
        }

        It 'Updates page when one already exists' {
            $testMFAData = @(
                [PSCustomObject]@{ displayName = 'User1'; isMfaRegistered = $true }
            )

            $result = Sync-ConfluenceMFAReport -SpaceKey 'CONTOSO' -MFAData $testMFAData

            $result | Should Not Be $null
            $result.Action | Should Be 'Updated'
        }

        It 'Returns incremented version on update' {
            $testMFAData = @(
                [PSCustomObject]@{ displayName = 'User1'; isMfaRegistered = $true }
            )

            $result = Sync-ConfluenceMFAReport -SpaceKey 'CONTOSO' -MFAData $testMFAData

            $result.Version | Should Be 5
        }

        It 'Calls Set-ConfluencePage with existing page ID' {
            $testMFAData = @(
                [PSCustomObject]@{ displayName = 'User1'; isMfaRegistered = $true }
            )

            Sync-ConfluenceMFAReport -SpaceKey 'CONTOSO' -MFAData $testMFAData

            Assert-MockCalled Set-ConfluencePage -Times 1 -Scope It
            $script:capturedSetPageParams.PageId | Should Be '789'
        }

        It 'Does not call New-ConfluencePage when page exists' {
            $testMFAData = @(
                [PSCustomObject]@{ displayName = 'User1'; isMfaRegistered = $true }
            )

            Sync-ConfluenceMFAReport -SpaceKey 'CONTOSO' -MFAData $testMFAData

            Assert-MockCalled New-ConfluencePage -Times 0 -Scope It
        }
    }

    Context 'MFAData Parameter Passing' {
        BeforeAll {
            $script:capturedTransformerParams = $null
            Mock Get-ConfluenceSpace { return [PSCustomObject]@{ Id = '123'; Key = 'CONTOSO'; Name = 'Contoso Corp' } }
            Mock Search-Confluence { return $null }
            Mock ConvertTo-ConfluenceMFAPage {
                param($MFAData)
                $script:capturedTransformerParams = @{
                    MFAData = $MFAData
                }
                return '{"version":1,"type":"doc","content":[]}'
            }
            Mock New-ConfluencePage { return [PSCustomObject]@{ Id = '456'; Title = 'MFA Status'; Version = @{ Number = 1 } } }
        }

        It 'Passes MFAData parameter to transformer' {
            $testMFAData = @(
                [PSCustomObject]@{ displayName = 'John Doe'; isMfaRegistered = $true; perUserMfaState = 'enforced' }
            )

            Sync-ConfluenceMFAReport -SpaceKey 'CONTOSO' -MFAData $testMFAData

            $script:capturedTransformerParams.MFAData | Should Not Be $null
            $script:capturedTransformerParams.MFAData.Count | Should Be 1
            $script:capturedTransformerParams.MFAData[0].displayName | Should Be 'John Doe'
        }

        It 'Passes multiple MFA records to transformer' {
            $testMFAData = @(
                [PSCustomObject]@{ displayName = 'User1'; isMfaRegistered = $true }
                [PSCustomObject]@{ displayName = 'User2'; isMfaRegistered = $false }
            )

            Sync-ConfluenceMFAReport -SpaceKey 'CONTOSO' -MFAData $testMFAData

            $script:capturedTransformerParams.MFAData.Count | Should Be 2
        }
    }

    Context 'WhatIf Support (AC6)' {
        BeforeAll {
            Mock Get-ConfluenceSpace { return [PSCustomObject]@{ Id = '123'; Key = 'CONTOSO'; Name = 'Contoso Corp' } }
            Mock Search-Confluence { return $null }
            Mock ConvertTo-ConfluenceMFAPage { return '{"version":1,"type":"doc","content":[]}' }
            Mock New-ConfluencePage { throw "Should not be called with WhatIf" }
            Mock Set-ConfluencePage { throw "Should not be called with WhatIf" }
        }

        It 'Does not create page when WhatIf is specified' {
            $testMFAData = @(
                [PSCustomObject]@{ displayName = 'User1'; isMfaRegistered = $true }
            )

            Sync-ConfluenceMFAReport -SpaceKey 'CONTOSO' -MFAData $testMFAData -WhatIf

            Assert-MockCalled New-ConfluencePage -Times 0 -Scope It
        }

        It 'Returns null when WhatIf is specified' {
            $testMFAData = @(
                [PSCustomObject]@{ displayName = 'User1'; isMfaRegistered = $true }
            )

            $result = Sync-ConfluenceMFAReport -SpaceKey 'CONTOSO' -MFAData $testMFAData -WhatIf

            $result | Should Be $null
        }
    }

    Context 'WhatIf with Existing Page (AC6)' {
        BeforeAll {
            Mock Get-ConfluenceSpace { return [PSCustomObject]@{ Id = '123'; Key = 'CONTOSO'; Name = 'Contoso Corp' } }
            Mock Search-Confluence { return [PSCustomObject]@{ Id = '789'; Title = 'MFA Status' } }
            Mock ConvertTo-ConfluenceMFAPage { return '{"version":1,"type":"doc","content":[]}' }
            Mock Set-ConfluencePage { throw "Should not be called with WhatIf" }
        }

        It 'Does not update page when WhatIf is specified' {
            $testMFAData = @(
                [PSCustomObject]@{ displayName = 'User1'; isMfaRegistered = $true }
            )

            Sync-ConfluenceMFAReport -SpaceKey 'CONTOSO' -MFAData $testMFAData -WhatIf

            Assert-MockCalled Set-ConfluencePage -Times 0 -Scope It
        }
    }

    Context 'Verbose Logging (AC7)' {
        BeforeAll {
            Mock Get-ConfluenceSpace { return [PSCustomObject]@{ Id = '123'; Key = 'CONTOSO'; Name = 'Contoso Corp' } }
            Mock Search-Confluence { return $null }
            Mock ConvertTo-ConfluenceMFAPage { return '{"version":1,"type":"doc","content":[]}' }
            Mock New-ConfluencePage { return [PSCustomObject]@{ Id = '456'; Title = 'MFA Status'; Version = @{ Number = 1 } } }
        }

        It 'Writes verbose message about syncing to space' {
            $testMFAData = @(
                [PSCustomObject]@{ displayName = 'User1'; isMfaRegistered = $true }
            )

            $verboseOutput = Sync-ConfluenceMFAReport -SpaceKey 'CONTOSO' -MFAData $testMFAData -Verbose 4>&1

            $verboseOutput | Where-Object { $_ -like "*Syncing MFA report to space*" } | Should Not Be $null
        }

        It 'Writes verbose message about ADF content generation' {
            $testMFAData = @(
                [PSCustomObject]@{ displayName = 'User1'; isMfaRegistered = $true }
            )

            $verboseOutput = Sync-ConfluenceMFAReport -SpaceKey 'CONTOSO' -MFAData $testMFAData -Verbose 4>&1

            $verboseOutput | Where-Object { $_ -like "*Generated ADF content*" } | Should Not Be $null
        }

        It 'Writes verbose message about CQL search' {
            $testMFAData = @(
                [PSCustomObject]@{ displayName = 'User1'; isMfaRegistered = $true }
            )

            $verboseOutput = Sync-ConfluenceMFAReport -SpaceKey 'CONTOSO' -MFAData $testMFAData -Verbose 4>&1

            $verboseOutput | Where-Object { $_ -like "*Searching for existing page with CQL*" } | Should Not Be $null
        }

        It 'Writes verbose message about page creation' {
            $testMFAData = @(
                [PSCustomObject]@{ displayName = 'User1'; isMfaRegistered = $true }
            )

            $verboseOutput = Sync-ConfluenceMFAReport -SpaceKey 'CONTOSO' -MFAData $testMFAData -Verbose 4>&1

            $verboseOutput | Where-Object { $_ -like "*Successfully created page*" } | Should Not Be $null
        }
    }

    Context 'Space Validation Error (AC8)' {
        BeforeAll {
            Mock Get-ConfluenceSpace { return $null }
            Mock Search-Confluence { throw "Should not be called when space doesn't exist" }
            Mock ConvertTo-ConfluenceMFAPage { throw "Should not be called when space doesn't exist" }
        }

        It 'Throws terminating error for non-existent space' {
            $testMFAData = @(
                [PSCustomObject]@{ displayName = 'User1'; isMfaRegistered = $true }
            )

            { Sync-ConfluenceMFAReport -SpaceKey 'INVALID' -MFAData $testMFAData } | Should Throw
        }

        It 'Error message includes space key' {
            $testMFAData = @(
                [PSCustomObject]@{ displayName = 'User1'; isMfaRegistered = $true }
            )

            try {
                Sync-ConfluenceMFAReport -SpaceKey 'INVALID' -MFAData $testMFAData
            }
            catch {
                $_.Exception.Message | Should Match 'INVALID'
            }
        }

        It 'Error message includes actionable guidance mentioning Get-ConfluenceSpace' {
            $testMFAData = @(
                [PSCustomObject]@{ displayName = 'User1'; isMfaRegistered = $true }
            )

            try {
                Sync-ConfluenceMFAReport -SpaceKey 'INVALID' -MFAData $testMFAData
            }
            catch {
                $_.Exception.Message | Should Match 'Get-ConfluenceSpace'
            }
        }
    }

    Context 'Empty MFAData Handling (AC9)' {
        BeforeAll {
            Mock Get-ConfluenceSpace { return [PSCustomObject]@{ Id = '123'; Key = 'CONTOSO'; Name = 'Contoso Corp' } }
            Mock Search-Confluence { return $null }
            Mock ConvertTo-ConfluenceMFAPage { return '{"version":1,"type":"doc","content":[]}' }
            Mock New-ConfluencePage { return [PSCustomObject]@{ Id = '456'; Title = 'MFA Status'; Version = @{ Number = 1 } } }
        }

        It 'Handles null MFAData without error' {
            { Sync-ConfluenceMFAReport -SpaceKey 'CONTOSO' -MFAData $null } | Should Not Throw
        }

        It 'Handles empty array without error' {
            { Sync-ConfluenceMFAReport -SpaceKey 'CONTOSO' -MFAData @() } | Should Not Throw
        }

        It 'Creates page with empty MFA data' {
            $result = Sync-ConfluenceMFAReport -SpaceKey 'CONTOSO' -MFAData $null

            $result | Should Not Be $null
            $result.Action | Should Be 'Created'
        }
    }

    Context 'Parent Page Hierarchy (AC10)' {
        BeforeAll {
            $script:capturedNewPageParams = $null
            Mock Get-ConfluenceSpace { return [PSCustomObject]@{ Id = '123'; Key = 'CONTOSO'; Name = 'Contoso Corp' } }
            Mock Search-Confluence { return $null }
            Mock ConvertTo-ConfluenceMFAPage { return '{"version":1,"type":"doc","content":[]}' }
            Mock New-ConfluencePage {
                param($SpaceKey, $Title, $Body, $ParentId)
                $script:capturedNewPageParams = @{
                    SpaceKey = $SpaceKey
                    Title = $Title
                    Body = $Body
                    ParentId = $ParentId
                }
                return [PSCustomObject]@{ Id = '456'; Title = 'MFA Status'; Version = @{ Number = 1 } }
            }
        }

        It 'Accepts ParentPageId parameter' {
            $testMFAData = @(
                [PSCustomObject]@{ displayName = 'User1'; isMfaRegistered = $true }
            )

            { Sync-ConfluenceMFAReport -SpaceKey 'CONTOSO' -MFAData $testMFAData -ParentPageId '12345' } | Should Not Throw
        }

        It 'Passes ParentPageId to New-ConfluencePage' {
            $script:capturedNewPageParams = $null
            $testMFAData = @(
                [PSCustomObject]@{ displayName = 'User1'; isMfaRegistered = $true }
            )

            Sync-ConfluenceMFAReport -SpaceKey 'CONTOSO' -MFAData $testMFAData -ParentPageId '12345'

            $script:capturedNewPageParams.ParentId | Should Be '12345'
        }

        It 'Does not pass ParentId when not specified' {
            $script:capturedNewPageParams = $null
            $testMFAData = @(
                [PSCustomObject]@{ displayName = 'User1'; isMfaRegistered = $true }
            )

            Sync-ConfluenceMFAReport -SpaceKey 'CONTOSO' -MFAData $testMFAData

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
            Mock ConvertTo-ConfluenceMFAPage { return '{"version":1,"type":"doc","content":[]}' }
            Mock New-ConfluencePage { return [PSCustomObject]@{ Id = '456'; Title = 'MFA Status'; Version = @{ Number = 1 } } }
        }

        It 'Uses correct CQL query format' {
            Sync-ConfluenceMFAReport -SpaceKey 'CONTOSO' -MFAData @()

            $script:capturedCQL | Should Match "space = 'CONTOSO'"
            $script:capturedCQL | Should Match "title = 'MFA Status'"
            $script:capturedCQL | Should Match "type = page"
        }

        It 'Escapes single quotes in SpaceKey for CQL safety' {
            Sync-ConfluenceMFAReport -SpaceKey "O'Brien" -MFAData @()

            $script:capturedCQL | Should Match "space = 'O''Brien'"
        }

        It 'Escapes single quotes in PageTitle for CQL safety' {
            Sync-ConfluenceMFAReport -SpaceKey 'CONTOSO' -MFAData @() -PageTitle "John's MFA Report"

            $script:capturedCQL | Should Match "title = 'John''s MFA Report'"
        }
    }

    Context 'Verbose Logging for Update Path' {
        BeforeAll {
            Mock Get-ConfluenceSpace { return [PSCustomObject]@{ Id = '123'; Key = 'CONTOSO'; Name = 'Contoso Corp' } }
            Mock Search-Confluence { return [PSCustomObject]@{ Id = '789'; Title = 'MFA Status' } }
            Mock ConvertTo-ConfluenceMFAPage { return '{"version":1,"type":"doc","content":[]}' }
            Mock Set-ConfluencePage { return [PSCustomObject]@{ Id = '789'; Title = 'MFA Status'; Version = @{ Number = 5 } } }
        }

        It 'Writes verbose message about finding existing page' {
            $testMFAData = @(
                [PSCustomObject]@{ displayName = 'User1'; isMfaRegistered = $true }
            )

            $verboseOutput = Sync-ConfluenceMFAReport -SpaceKey 'CONTOSO' -MFAData $testMFAData -Verbose 4>&1

            $verboseOutput | Where-Object { $_ -like "*Found existing page*updating*" } | Should Not Be $null
        }

        It 'Writes verbose message about successful update' {
            $testMFAData = @(
                [PSCustomObject]@{ displayName = 'User1'; isMfaRegistered = $true }
            )

            $verboseOutput = Sync-ConfluenceMFAReport -SpaceKey 'CONTOSO' -MFAData $testMFAData -Verbose 4>&1

            $verboseOutput | Where-Object { $_ -like "*Successfully updated page*" } | Should Not Be $null
        }
    }

    Context 'Verbose Logging for ParentPageId' {
        BeforeAll {
            Mock Get-ConfluenceSpace { return [PSCustomObject]@{ Id = '123'; Key = 'CONTOSO'; Name = 'Contoso Corp' } }
            Mock Search-Confluence { return $null }
            Mock ConvertTo-ConfluenceMFAPage { return '{"version":1,"type":"doc","content":[]}' }
            Mock New-ConfluencePage { return [PSCustomObject]@{ Id = '456'; Title = 'MFA Status'; Version = @{ Number = 1 } } }
        }

        It 'Writes verbose message about parent page when specified' {
            $testMFAData = @(
                [PSCustomObject]@{ displayName = 'User1'; isMfaRegistered = $true }
            )

            $verboseOutput = Sync-ConfluenceMFAReport -SpaceKey 'CONTOSO' -MFAData $testMFAData -ParentPageId '12345' -Verbose 4>&1

            $verboseOutput | Where-Object { $_ -like "*Creating page under parent ID: 12345*" } | Should Not Be $null
        }
    }
}
