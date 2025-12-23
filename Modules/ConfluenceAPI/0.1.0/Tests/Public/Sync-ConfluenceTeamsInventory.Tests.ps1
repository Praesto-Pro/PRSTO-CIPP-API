$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $here)) 'Public'

Describe 'Sync-ConfluenceTeamsInventory' {
    BeforeAll {
        # Define stub functions for mocking
        function Get-ConfluenceSpace { param($SpaceKey) }
        function Search-Confluence { param($CQL) }
        function New-ConfluencePage { param($SpaceKey, $Title, $Body, $ParentId) }
        function Set-ConfluencePage { param($PageId, $Body) }
        function ConvertTo-ConfluenceTeamsPage { param($TeamsData) }

        # Dot-source the function under test
        . "$publicDir\Sync-ConfluenceTeamsInventory.ps1"
    }

    Context 'Page Creation (AC1)' {
        It 'Creates page when none exists' {
            Mock Get-ConfluenceSpace { [PSCustomObject]@{ Key = 'TEST' } }
            Mock Search-Confluence { $null }
            Mock ConvertTo-ConfluenceTeamsPage { '{"type":"doc"}' }
            Mock New-ConfluencePage {
                [PSCustomObject]@{
                    Id = '12345'
                    Title = 'Teams Inventory'
                    Version = @{ Number = 1 }
                }
            }

            $result = Sync-ConfluenceTeamsInventory -SpaceKey 'TEST' -TeamsData @()
            $result | Should Not Be $null
            Assert-MockCalled New-ConfluencePage -Times 1 -Scope It
        }

        It 'Returns PSCustomObject with correct properties' {
            Mock Get-ConfluenceSpace { [PSCustomObject]@{ Key = 'TEST' } }
            Mock Search-Confluence { $null }
            Mock ConvertTo-ConfluenceTeamsPage { '{"type":"doc"}' }
            Mock New-ConfluencePage {
                [PSCustomObject]@{
                    Id = '12345'
                    Title = 'Teams Inventory'
                    Version = @{ Number = 1 }
                }
            }

            $result = Sync-ConfluenceTeamsInventory -SpaceKey 'TEST' -TeamsData @()
            $result.Id | Should Be '12345'
            $result.Title | Should Be 'Teams Inventory'
            $result.SpaceKey | Should Be 'TEST'
            $result.Version | Should Be 1
            $result.Action | Should Be 'Created'
        }

        It 'Passes SpaceKey to New-ConfluencePage' {
            Mock Get-ConfluenceSpace { [PSCustomObject]@{ Key = 'MYSPACE' } }
            Mock Search-Confluence { $null }
            Mock ConvertTo-ConfluenceTeamsPage { '{"type":"doc"}' }
            $script:capturedSpaceKey = $null
            Mock New-ConfluencePage {
                param($SpaceKey, $Title, $Body, $ParentId)
                $script:capturedSpaceKey = $SpaceKey
                [PSCustomObject]@{
                    Id = '12345'
                    Title = $Title
                    Version = @{ Number = 1 }
                }
            }

            Sync-ConfluenceTeamsInventory -SpaceKey 'MYSPACE' -TeamsData @()
            $script:capturedSpaceKey | Should Be 'MYSPACE'
        }

        It 'Passes PageTitle to New-ConfluencePage' {
            Mock Get-ConfluenceSpace { [PSCustomObject]@{ Key = 'TEST' } }
            Mock Search-Confluence { $null }
            Mock ConvertTo-ConfluenceTeamsPage { '{"type":"doc"}' }
            $script:capturedTitle = $null
            Mock New-ConfluencePage {
                param($SpaceKey, $Title, $Body, $ParentId)
                $script:capturedTitle = $Title
                [PSCustomObject]@{
                    Id = '12345'
                    Title = $Title
                    Version = @{ Number = 1 }
                }
            }

            Sync-ConfluenceTeamsInventory -SpaceKey 'TEST' -TeamsData @() -PageTitle 'Custom Title'
            $script:capturedTitle | Should Be 'Custom Title'
        }
    }

    Context 'Page Update (AC2)' {
        It 'Updates page when one exists' {
            Mock Get-ConfluenceSpace { [PSCustomObject]@{ Key = 'TEST' } }
            Mock Search-Confluence {
                [PSCustomObject]@{ Id = '99999' }
            }
            Mock ConvertTo-ConfluenceTeamsPage { '{"type":"doc"}' }
            Mock Set-ConfluencePage {
                [PSCustomObject]@{
                    Id = '99999'
                    Title = 'Teams Inventory'
                    Version = @{ Number = 2 }
                }
            }

            $result = Sync-ConfluenceTeamsInventory -SpaceKey 'TEST' -TeamsData @()
            Assert-MockCalled Set-ConfluencePage -Times 1 -Scope It
            Assert-MockCalled New-ConfluencePage -Times 0 -Scope It
        }

        It 'Returns Updated action when page is updated' {
            Mock Get-ConfluenceSpace { [PSCustomObject]@{ Key = 'TEST' } }
            Mock Search-Confluence {
                [PSCustomObject]@{ Id = '99999' }
            }
            Mock ConvertTo-ConfluenceTeamsPage { '{"type":"doc"}' }
            Mock Set-ConfluencePage {
                [PSCustomObject]@{
                    Id = '99999'
                    Title = 'Teams Inventory'
                    Version = @{ Number = 3 }
                }
            }

            $result = Sync-ConfluenceTeamsInventory -SpaceKey 'TEST' -TeamsData @()
            $result.Action | Should Be 'Updated'
            $result.Version | Should Be 3
        }

        It 'Passes existing page ID to Set-ConfluencePage' {
            Mock Get-ConfluenceSpace { [PSCustomObject]@{ Key = 'TEST' } }
            Mock Search-Confluence {
                [PSCustomObject]@{ Id = '77777' }
            }
            Mock ConvertTo-ConfluenceTeamsPage { '{"type":"doc"}' }
            $script:capturedPageId = $null
            Mock Set-ConfluencePage {
                param($PageId, $Body)
                $script:capturedPageId = $PageId
                [PSCustomObject]@{
                    Id = $PageId
                    Title = 'Teams Inventory'
                    Version = @{ Number = 2 }
                }
            }

            Sync-ConfluenceTeamsInventory -SpaceKey 'TEST' -TeamsData @()
            $script:capturedPageId | Should Be '77777'
        }
    }

    Context 'WhatIf Support (AC5)' {
        It 'Does not create page when WhatIf is used' {
            Mock Get-ConfluenceSpace { [PSCustomObject]@{ Key = 'TEST' } }
            Mock Search-Confluence { $null }
            Mock ConvertTo-ConfluenceTeamsPage { '{"type":"doc"}' }
            Mock New-ConfluencePage { throw "Should not be called" }

            { Sync-ConfluenceTeamsInventory -SpaceKey 'TEST' -TeamsData @() -WhatIf } | Should Not Throw
            Assert-MockCalled New-ConfluencePage -Times 0 -Scope It
        }

        It 'Does not update page when WhatIf is used' {
            Mock Get-ConfluenceSpace { [PSCustomObject]@{ Key = 'TEST' } }
            Mock Search-Confluence {
                [PSCustomObject]@{ Id = '12345' }
            }
            Mock ConvertTo-ConfluenceTeamsPage { '{"type":"doc"}' }
            Mock Set-ConfluencePage { throw "Should not be called" }

            { Sync-ConfluenceTeamsInventory -SpaceKey 'TEST' -TeamsData @() -WhatIf } | Should Not Throw
            Assert-MockCalled Set-ConfluencePage -Times 0 -Scope It
        }

        It 'Returns null when WhatIf is used for creation' {
            Mock Get-ConfluenceSpace { [PSCustomObject]@{ Key = 'TEST' } }
            Mock Search-Confluence { $null }
            Mock ConvertTo-ConfluenceTeamsPage { '{"type":"doc"}' }
            Mock New-ConfluencePage { }

            $result = Sync-ConfluenceTeamsInventory -SpaceKey 'TEST' -TeamsData @() -WhatIf
            $result | Should Be $null
        }

        It 'Returns null when WhatIf is used for update' {
            Mock Get-ConfluenceSpace { [PSCustomObject]@{ Key = 'TEST' } }
            Mock Search-Confluence {
                [PSCustomObject]@{ Id = '12345' }
            }
            Mock ConvertTo-ConfluenceTeamsPage { '{"type":"doc"}' }
            Mock Set-ConfluencePage { }

            $result = Sync-ConfluenceTeamsInventory -SpaceKey 'TEST' -TeamsData @() -WhatIf
            $result | Should Be $null
        }
    }

    Context 'Verbose Logging (AC6)' {
        It 'Writes verbose message when syncing' {
            Mock Get-ConfluenceSpace { [PSCustomObject]@{ Key = 'TEST' } }
            Mock Search-Confluence { $null }
            Mock ConvertTo-ConfluenceTeamsPage { '{"type":"doc"}' }
            Mock New-ConfluencePage {
                [PSCustomObject]@{
                    Id = '12345'
                    Title = 'Teams Inventory'
                    Version = @{ Number = 1 }
                }
            }

            $verboseOutput = Sync-ConfluenceTeamsInventory -SpaceKey 'TEST' -TeamsData @() -Verbose 4>&1
            $verboseMessages = $verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }
            $verboseMessages | Should Not Be $null
        }

        It 'Verbose message includes space key' {
            Mock Get-ConfluenceSpace { [PSCustomObject]@{ Key = 'MYSPACE' } }
            Mock Search-Confluence { $null }
            Mock ConvertTo-ConfluenceTeamsPage { '{"type":"doc"}' }
            Mock New-ConfluencePage {
                [PSCustomObject]@{
                    Id = '12345'
                    Title = 'Teams Inventory'
                    Version = @{ Number = 1 }
                }
            }

            $verboseOutput = Sync-ConfluenceTeamsInventory -SpaceKey 'MYSPACE' -TeamsData @() -Verbose 4>&1
            $verboseText = ($verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }) -join ' '
            $verboseText | Should Match 'MYSPACE'
        }
    }

    Context 'Space Validation (AC7)' {
        It 'Throws error when space does not exist' {
            Mock Get-ConfluenceSpace { $null }
            Mock Search-Confluence { $null }

            { Sync-ConfluenceTeamsInventory -SpaceKey 'INVALID' -TeamsData @() } | Should Throw
        }

        It 'Error message includes actionable guidance' {
            Mock Get-ConfluenceSpace { $null }
            Mock Search-Confluence { $null }

            try {
                Sync-ConfluenceTeamsInventory -SpaceKey 'INVALID' -TeamsData @()
            }
            catch {
                $_.Exception.Message | Should Match 'Get-ConfluenceSpace'
            }
        }

        It 'Error message includes the invalid space key' {
            Mock Get-ConfluenceSpace { $null }
            Mock Search-Confluence { $null }

            try {
                Sync-ConfluenceTeamsInventory -SpaceKey 'BADKEY' -TeamsData @()
            }
            catch {
                $_.Exception.Message | Should Match 'BADKEY'
            }
        }

        It 'Does not proceed if space validation fails' {
            Mock Get-ConfluenceSpace { $null }
            Mock Search-Confluence { throw "Should not be called" }
            Mock ConvertTo-ConfluenceTeamsPage { throw "Should not be called" }

            { Sync-ConfluenceTeamsInventory -SpaceKey 'INVALID' -TeamsData @() } | Should Throw
            Assert-MockCalled Search-Confluence -Times 0 -Scope It
        }
    }

    Context 'Empty Teams Data Handling (AC8)' {
        It 'Handles null TeamsData without error' {
            Mock Get-ConfluenceSpace { [PSCustomObject]@{ Key = 'TEST' } }
            Mock Search-Confluence { $null }
            Mock ConvertTo-ConfluenceTeamsPage { '{"type":"doc"}' }
            Mock New-ConfluencePage {
                [PSCustomObject]@{
                    Id = '12345'
                    Title = 'Teams Inventory'
                    Version = @{ Number = 1 }
                }
            }

            { Sync-ConfluenceTeamsInventory -SpaceKey 'TEST' -TeamsData $null } | Should Not Throw
        }

        It 'Handles empty array TeamsData without error' {
            Mock Get-ConfluenceSpace { [PSCustomObject]@{ Key = 'TEST' } }
            Mock Search-Confluence { $null }
            Mock ConvertTo-ConfluenceTeamsPage { '{"type":"doc"}' }
            Mock New-ConfluencePage {
                [PSCustomObject]@{
                    Id = '12345'
                    Title = 'Teams Inventory'
                    Version = @{ Number = 1 }
                }
            }

            { Sync-ConfluenceTeamsInventory -SpaceKey 'TEST' -TeamsData @() } | Should Not Throw
        }

        It 'Passes TeamsData to transformer' {
            Mock Get-ConfluenceSpace { [PSCustomObject]@{ Key = 'TEST' } }
            Mock Search-Confluence { $null }
            $script:capturedTeamsData = 'not-captured'
            Mock ConvertTo-ConfluenceTeamsPage {
                param($TeamsData)
                $script:capturedTeamsData = $TeamsData
                '{"type":"doc"}'
            }
            Mock New-ConfluencePage {
                [PSCustomObject]@{
                    Id = '12345'
                    Title = 'Teams Inventory'
                    Version = @{ Number = 1 }
                }
            }

            $testData = @([PSCustomObject]@{ displayName = 'Test Team' })
            Sync-ConfluenceTeamsInventory -SpaceKey 'TEST' -TeamsData $testData
            $script:capturedTeamsData | Should Not Be $null
        }
    }

    Context 'Parent Page Support (AC9)' {
        It 'Accepts ParentPageId parameter' {
            Mock Get-ConfluenceSpace { [PSCustomObject]@{ Key = 'TEST' } }
            Mock Search-Confluence { $null }
            Mock ConvertTo-ConfluenceTeamsPage { '{"type":"doc"}' }
            Mock New-ConfluencePage {
                [PSCustomObject]@{
                    Id = '12345'
                    Title = 'Teams Inventory'
                    Version = @{ Number = 1 }
                }
            }

            { Sync-ConfluenceTeamsInventory -SpaceKey 'TEST' -TeamsData @() -ParentPageId '99999' } | Should Not Throw
        }

        It 'Passes ParentPageId to New-ConfluencePage' {
            Mock Get-ConfluenceSpace { [PSCustomObject]@{ Key = 'TEST' } }
            Mock Search-Confluence { $null }
            Mock ConvertTo-ConfluenceTeamsPage { '{"type":"doc"}' }
            $script:capturedParentId = $null
            Mock New-ConfluencePage {
                param($SpaceKey, $Title, $Body, $ParentId)
                $script:capturedParentId = $ParentId
                [PSCustomObject]@{
                    Id = '12345'
                    Title = $Title
                    Version = @{ Number = 1 }
                }
            }

            Sync-ConfluenceTeamsInventory -SpaceKey 'TEST' -TeamsData @() -ParentPageId '88888'
            $script:capturedParentId | Should Be '88888'
        }

        It 'Does not pass ParentId when ParentPageId is not specified' {
            Mock Get-ConfluenceSpace { [PSCustomObject]@{ Key = 'TEST' } }
            Mock Search-Confluence { $null }
            Mock ConvertTo-ConfluenceTeamsPage { '{"type":"doc"}' }
            $script:capturedParentId = 'should-be-null'
            Mock New-ConfluencePage {
                param($SpaceKey, $Title, $Body, $ParentId)
                $script:capturedParentId = $ParentId
                [PSCustomObject]@{
                    Id = '12345'
                    Title = $Title
                    Version = @{ Number = 1 }
                }
            }

            Sync-ConfluenceTeamsInventory -SpaceKey 'TEST' -TeamsData @()
            $script:capturedParentId | Should Be $null
        }
    }

    Context 'CQL Query Format' {
        It 'Uses correct CQL query format' {
            Mock Get-ConfluenceSpace { [PSCustomObject]@{ Key = 'TEST' } }
            $script:capturedCQL = $null
            Mock Search-Confluence {
                param($CQL)
                $script:capturedCQL = $CQL
                $null
            }
            Mock ConvertTo-ConfluenceTeamsPage { '{"type":"doc"}' }
            Mock New-ConfluencePage {
                [PSCustomObject]@{
                    Id = '12345'
                    Title = 'Teams Inventory'
                    Version = @{ Number = 1 }
                }
            }

            Sync-ConfluenceTeamsInventory -SpaceKey 'TEST' -TeamsData @()
            $script:capturedCQL | Should Match "space = 'TEST'"
            $script:capturedCQL | Should Match "title = 'Teams Inventory'"
            $script:capturedCQL | Should Match "type = page"
        }

        It 'Uses custom page title in CQL query' {
            Mock Get-ConfluenceSpace { [PSCustomObject]@{ Key = 'TEST' } }
            $script:capturedCQL = $null
            Mock Search-Confluence {
                param($CQL)
                $script:capturedCQL = $CQL
                $null
            }
            Mock ConvertTo-ConfluenceTeamsPage { '{"type":"doc"}' }
            Mock New-ConfluencePage {
                [PSCustomObject]@{
                    Id = '12345'
                    Title = 'Custom Title'
                    Version = @{ Number = 1 }
                }
            }

            Sync-ConfluenceTeamsInventory -SpaceKey 'TEST' -TeamsData @() -PageTitle 'Custom Title'
            $script:capturedCQL | Should Match "title = 'Custom Title'"
        }

        It 'Escapes single quotes in SpaceKey for CQL safety' {
            Mock Get-ConfluenceSpace { [PSCustomObject]@{ Key = "TEST'KEY" } }
            $script:capturedCQL = $null
            Mock Search-Confluence {
                param($CQL)
                $script:capturedCQL = $CQL
                $null
            }
            Mock ConvertTo-ConfluenceTeamsPage { '{"type":"doc"}' }
            Mock New-ConfluencePage {
                [PSCustomObject]@{
                    Id = '12345'
                    Title = 'Teams Inventory'
                    Version = @{ Number = 1 }
                }
            }

            Sync-ConfluenceTeamsInventory -SpaceKey "TEST'KEY" -TeamsData @()
            $script:capturedCQL | Should Match "TEST''KEY"
        }

        It 'Escapes single quotes in PageTitle for CQL safety' {
            Mock Get-ConfluenceSpace { [PSCustomObject]@{ Key = 'TEST' } }
            $script:capturedCQL = $null
            Mock Search-Confluence {
                param($CQL)
                $script:capturedCQL = $CQL
                $null
            }
            Mock ConvertTo-ConfluenceTeamsPage { '{"type":"doc"}' }
            Mock New-ConfluencePage {
                [PSCustomObject]@{
                    Id = '12345'
                    Title = "Team's Inventory"
                    Version = @{ Number = 1 }
                }
            }

            Sync-ConfluenceTeamsInventory -SpaceKey 'TEST' -TeamsData @() -PageTitle "Team's Inventory"
            $script:capturedCQL | Should Match "Team''s Inventory"
        }
    }

    Context 'Default Parameter Values' {
        It 'Uses default page title when not specified' {
            Mock Get-ConfluenceSpace { [PSCustomObject]@{ Key = 'TEST' } }
            $script:capturedCQL = $null
            Mock Search-Confluence {
                param($CQL)
                $script:capturedCQL = $CQL
                $null
            }
            Mock ConvertTo-ConfluenceTeamsPage { '{"type":"doc"}' }
            Mock New-ConfluencePage {
                [PSCustomObject]@{
                    Id = '12345'
                    Title = 'Teams Inventory'
                    Version = @{ Number = 1 }
                }
            }

            Sync-ConfluenceTeamsInventory -SpaceKey 'TEST' -TeamsData @()
            $script:capturedCQL | Should Match "title = 'Teams Inventory'"
        }
    }
}
