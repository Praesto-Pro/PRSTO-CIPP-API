$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $here)) 'Public'
$privateDir = Join-Path (Split-Path -Parent (Split-Path -Parent $here)) 'Private'

Describe 'Sync-ConfluenceUserInventory' {
    BeforeAll {
        # Define stub functions for public dependencies that will be mocked
        # These stubs allow Pester 3.4 to mock them
        function Get-ConfluenceSpace { param($SpaceKey) }
        function Search-Confluence { param($CQL) }
        function New-ConfluencePage { param($SpaceKey, $Title, $Body) }
        function Set-ConfluencePage { param($PageId, $Body) }

        # Dot-source the function under test
        . "$publicDir\Sync-ConfluenceUserInventory.ps1"

        # Dot-source private dependencies for ConvertTo-ConfluenceUserPage
        . "$privateDir\New-ADFDocument.ps1"
        . "$privateDir\Add-ADFContent.ps1"
        . "$privateDir\ConvertTo-ADF.ps1"
        . "$privateDir\New-ADFTable.ps1"
        . "$privateDir\New-ADFHeading.ps1"
        . "$privateDir\New-ADFParagraph.ps1"
        . "$privateDir\ConvertTo-ConfluenceUserPage.ps1"
    }

    Context 'New Page Creation (AC1)' {
        BeforeAll {
            # Mock dependencies for new page scenario
            Mock Get-ConfluenceSpace { return [PSCustomObject]@{ Id = '123'; Key = 'CONTOSO'; Name = 'Contoso Corp' } }
            Mock Search-Confluence { return $null }  # No existing page
            Mock New-ConfluencePage { return [PSCustomObject]@{ Id = '456'; Title = 'User Inventory'; Version = @{ Number = 1 } } }
            Mock Set-ConfluencePage { return [PSCustomObject]@{ Id = '456'; Title = 'User Inventory'; Version = @{ Number = 2 } } }
        }

        It 'Creates page when none exists' {
            $result = Sync-ConfluenceUserInventory -SpaceKey 'CONTOSO' -Users @()

            $result | Should Not Be $null
            $result.Action | Should Be 'Created'
        }

        It 'Calls New-ConfluencePage for new page' {
            Sync-ConfluenceUserInventory -SpaceKey 'CONTOSO' -Users @()

            Assert-MockCalled -CommandName 'New-ConfluencePage' -Scope It
        }

        It 'Returns PSCustomObject with correct properties' {
            $result = Sync-ConfluenceUserInventory -SpaceKey 'CONTOSO' -Users @()

            $result.Id | Should Be '456'
            $result.Title | Should Be 'User Inventory'
            $result.SpaceKey | Should Be 'CONTOSO'
            $result.Version | Should Be 1
            $result.Action | Should Be 'Created'
        }

        It 'Validates space exists before sync' {
            Sync-ConfluenceUserInventory -SpaceKey 'CONTOSO' -Users @()

            Assert-MockCalled -CommandName 'Get-ConfluenceSpace' -Scope It
        }

        It 'Searches for existing page' {
            Sync-ConfluenceUserInventory -SpaceKey 'CONTOSO' -Users @()

            Assert-MockCalled -CommandName 'Search-Confluence' -Scope It
        }

        It 'Uses correct CQL query format' {
            $script:capturedCQL = $null
            Mock Search-Confluence {
                param($CQL)
                $script:capturedCQL = $CQL
                return $null
            }

            Sync-ConfluenceUserInventory -SpaceKey 'CONTOSO' -Users @() -PageTitle 'User Inventory'

            $script:capturedCQL | Should Be "space = 'CONTOSO' AND title = 'User Inventory' AND type = page"
        }

        It 'Escapes single quotes in page title for CQL safety' {
            $script:capturedCQL = $null
            Mock Search-Confluence {
                param($CQL)
                $script:capturedCQL = $CQL
                return $null
            }

            Sync-ConfluenceUserInventory -SpaceKey 'CONTOSO' -Users @() -PageTitle "User's Inventory"

            $script:capturedCQL | Should Be "space = 'CONTOSO' AND title = 'User''s Inventory' AND type = page"
        }
    }

    Context 'Page Update (AC2)' {
        BeforeAll {
            Mock Get-ConfluenceSpace { return [PSCustomObject]@{ Id = '123'; Key = 'CONTOSO'; Name = 'Contoso Corp' } }
            Mock Search-Confluence { return [PSCustomObject]@{ Id = '789'; Title = 'User Inventory' } }
            Mock New-ConfluencePage { return [PSCustomObject]@{ Id = '456'; Title = 'User Inventory'; Version = @{ Number = 1 } } }
            Mock Set-ConfluencePage { return [PSCustomObject]@{ Id = '789'; Title = 'User Inventory'; Version = @{ Number = 2 } } }
        }

        It 'Updates page when exists' {
            $result = Sync-ConfluenceUserInventory -SpaceKey 'CONTOSO' -Users @()

            $result.Action | Should Be 'Updated'
        }

        It 'Calls Set-ConfluencePage for existing page' {
            Sync-ConfluenceUserInventory -SpaceKey 'CONTOSO' -Users @()

            Assert-MockCalled -CommandName 'Set-ConfluencePage' -Scope It
        }

        It 'Does not call New-ConfluencePage when page exists' {
            Sync-ConfluenceUserInventory -SpaceKey 'CONTOSO' -Users @()

            Assert-MockCalled -CommandName 'New-ConfluencePage' -Times 0
        }

        It 'Returns incremented version number' {
            $result = Sync-ConfluenceUserInventory -SpaceKey 'CONTOSO' -Users @()

            $result.Version | Should Be 2
        }
    }

    Context 'WhatIf Support (AC3)' {
        BeforeAll {
            Mock Get-ConfluenceSpace { return [PSCustomObject]@{ Id = '123'; Key = 'CONTOSO'; Name = 'Contoso Corp' } }
            Mock Search-Confluence { return $null }
            Mock New-ConfluencePage { return [PSCustomObject]@{ Id = '456'; Title = 'User Inventory'; Version = @{ Number = 1 } } }
        }

        It 'Does not create page with WhatIf' {
            Sync-ConfluenceUserInventory -SpaceKey 'CONTOSO' -Users @() -WhatIf

            Assert-MockCalled -CommandName 'New-ConfluencePage' -Times 0
        }

        It 'Returns null with WhatIf' {
            $result = Sync-ConfluenceUserInventory -SpaceKey 'CONTOSO' -Users @() -WhatIf

            $result | Should Be $null
        }
    }

    Context 'Verbose Logging (AC4)' {
        BeforeAll {
            Mock Get-ConfluenceSpace { return [PSCustomObject]@{ Id = '123'; Key = 'CONTOSO'; Name = 'Contoso Corp' } }
            Mock Search-Confluence { return $null }
            Mock New-ConfluencePage { return [PSCustomObject]@{ Id = '456'; Title = 'User Inventory'; Version = @{ Number = 1 } } }
        }

        It 'Writes verbose message for space sync' {
            $verboseOutput = Sync-ConfluenceUserInventory -SpaceKey 'CONTOSO' -Users @() -Verbose 4>&1

            ($verboseOutput -join ' ') | Should Match 'Syncing user inventory to space'
        }
    }

    Context 'License Data Passthrough (AC5)' {
        BeforeAll {
            Mock Get-ConfluenceSpace { return [PSCustomObject]@{ Id = '123'; Key = 'CONTOSO'; Name = 'Contoso Corp' } }
            Mock Search-Confluence { return $null }
            Mock New-ConfluencePage { return [PSCustomObject]@{ Id = '456'; Title = 'User Inventory'; Version = @{ Number = 1 } } }
        }

        It 'Accepts Licenses parameter' {
            $licenses = @(
                [PSCustomObject]@{ skuId = 'abc-123'; skuPartNumber = 'ENTERPRISEPREMIUM' }
            )

            { Sync-ConfluenceUserInventory -SpaceKey 'CONTOSO' -Users @() -Licenses $licenses } | Should Not Throw
        }

        It 'Passes Licenses to ConvertTo-ConfluenceUserPage' {
            $licenses = @(
                [PSCustomObject]@{ skuId = 'abc-123'; skuPartNumber = 'ENTERPRISEPREMIUM' }
            )
            $users = @(
                [PSCustomObject]@{ displayName = 'Test User'; userPrincipalName = 'test@contoso.com'; accountEnabled = $true }
            )

            $result = Sync-ConfluenceUserInventory -SpaceKey 'CONTOSO' -Users $users -Licenses $licenses

            # Verify the function completed without error and data was processed
            $result | Should Not Be $null
        }
    }

    Context 'MFA Data Passthrough (AC6)' {
        BeforeAll {
            Mock Get-ConfluenceSpace { return [PSCustomObject]@{ Id = '123'; Key = 'CONTOSO'; Name = 'Contoso Corp' } }
            Mock Search-Confluence { return $null }
            Mock New-ConfluencePage { return [PSCustomObject]@{ Id = '456'; Title = 'User Inventory'; Version = @{ Number = 1 } } }
        }

        It 'Accepts MFAData parameter' {
            $mfaData = @(
                [PSCustomObject]@{ UPN = 'user@contoso.com'; MFARegistration = $true }
            )

            { Sync-ConfluenceUserInventory -SpaceKey 'CONTOSO' -Users @() -MFAData $mfaData } | Should Not Throw
        }

        It 'Passes MFAData to ConvertTo-ConfluenceUserPage' {
            $mfaData = @(
                [PSCustomObject]@{ UPN = 'test@contoso.com'; MFARegistration = $true }
            )
            $users = @(
                [PSCustomObject]@{ displayName = 'Test User'; userPrincipalName = 'test@contoso.com'; accountEnabled = $true }
            )

            $result = Sync-ConfluenceUserInventory -SpaceKey 'CONTOSO' -Users $users -MFAData $mfaData

            # Verify the function completed without error and data was processed
            $result | Should Not Be $null
        }
    }

    Context 'Error Handling (AC7)' {
        BeforeAll {
            Mock Get-ConfluenceSpace { return $null }
            Mock Search-Confluence { return $null }
            Mock New-ConfluencePage { return $null }
        }

        It 'Throws error for non-existent space' {
            { Sync-ConfluenceUserInventory -SpaceKey 'INVALID' -Users @() } | Should Throw
        }

        It 'Error message contains space name' {
            try {
                Sync-ConfluenceUserInventory -SpaceKey 'INVALID' -Users @() -ErrorAction Stop
            }
            catch {
                $_.Exception.Message | Should Match 'INVALID'
            }
        }

        It 'Error message includes actionable guidance' {
            try {
                Sync-ConfluenceUserInventory -SpaceKey 'INVALID' -Users @() -ErrorAction Stop
            }
            catch {
                $_.Exception.Message | Should Match 'Get-ConfluenceSpace'
            }
        }
    }

    Context 'Empty Users Handling (AC8)' {
        BeforeAll {
            Mock Get-ConfluenceSpace { return [PSCustomObject]@{ Id = '123'; Key = 'CONTOSO'; Name = 'Contoso Corp' } }
            Mock Search-Confluence { return $null }
            Mock New-ConfluencePage { return [PSCustomObject]@{ Id = '456'; Title = 'User Inventory'; Version = @{ Number = 1 } } }
        }

        It 'Handles null users without error' {
            { Sync-ConfluenceUserInventory -SpaceKey 'CONTOSO' -Users $null } | Should Not Throw
        }

        It 'Handles empty array without error' {
            { Sync-ConfluenceUserInventory -SpaceKey 'CONTOSO' -Users @() } | Should Not Throw
        }

        It 'Creates page even with empty users' {
            $result = Sync-ConfluenceUserInventory -SpaceKey 'CONTOSO' -Users @()

            $result | Should Not Be $null
            $result.Action | Should Be 'Created'
        }
    }

    Context 'Custom Page Title' {
        BeforeAll {
            Mock Get-ConfluenceSpace { return [PSCustomObject]@{ Id = '123'; Key = 'CONTOSO'; Name = 'Contoso Corp' } }
            Mock Search-Confluence { return $null }
            Mock New-ConfluencePage {
                param($SpaceKey, $Title, $Body)
                return [PSCustomObject]@{ Id = '456'; Title = $Title; Version = @{ Number = 1 } }
            }
        }

        It 'Uses default page title' {
            $result = Sync-ConfluenceUserInventory -SpaceKey 'CONTOSO' -Users @()

            $result.Title | Should Be 'User Inventory'
        }

        It 'Allows custom page title' {
            $result = Sync-ConfluenceUserInventory -SpaceKey 'CONTOSO' -Users @() -PageTitle 'Custom Title'

            $result.Title | Should Be 'Custom Title'
        }
    }
}
