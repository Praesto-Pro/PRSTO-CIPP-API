$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $here)) 'Public'
$privateDir = Join-Path (Split-Path -Parent (Split-Path -Parent $here)) 'Private'

Describe 'Sync-ConfluenceSharePointInventory' {
    BeforeAll {
        # Define stub functions for mocking (Pester 3.4 compatible)
        function Get-ConfluenceSpace { param($SpaceKey) }
        function Search-Confluence { param($CQL) }
        function New-ConfluencePage { param($SpaceKey, $Title, $Body, $ParentId) }
        function Set-ConfluencePage { param($PageId, $Body) }
        function ConvertTo-ConfluenceSharePointPage { param($SharePointData) }

        # Dot-source function under test
        . "$publicDir\Sync-ConfluenceSharePointInventory.ps1"
    }

    Context 'AC1: Create SharePoint Inventory Page' {
        It 'Creates page when none exists' {
            Mock Get-ConfluenceSpace { [PSCustomObject]@{ Key = 'TEST'; Name = 'Test Space' } }
            Mock Search-Confluence { $null }
            Mock ConvertTo-ConfluenceSharePointPage { '{"type":"doc","version":1,"content":[]}' }
            Mock New-ConfluencePage {
                [PSCustomObject]@{
                    Id = '12345'
                    Title = 'SharePoint Inventory'
                    Version = @{ Number = 1 }
                }
            }

            $result = Sync-ConfluenceSharePointInventory -SpaceKey 'TEST' -SharePointData @()

            $result | Should Not Be $null
            Assert-MockCalled New-ConfluencePage -Scope It
        }

        It 'Returns PSCustomObject with Id property' {
            Mock Get-ConfluenceSpace { [PSCustomObject]@{ Key = 'TEST' } }
            Mock Search-Confluence { $null }
            Mock ConvertTo-ConfluenceSharePointPage { '{"type":"doc"}' }
            Mock New-ConfluencePage {
                [PSCustomObject]@{ Id = '54321'; Title = 'SharePoint Inventory'; Version = @{ Number = 1 } }
            }

            $result = Sync-ConfluenceSharePointInventory -SpaceKey 'TEST'

            $result.Id | Should Be '54321'
        }

        It 'Returns PSCustomObject with Title property' {
            Mock Get-ConfluenceSpace { [PSCustomObject]@{ Key = 'TEST' } }
            Mock Search-Confluence { $null }
            Mock ConvertTo-ConfluenceSharePointPage { '{"type":"doc"}' }
            Mock New-ConfluencePage {
                [PSCustomObject]@{ Id = '123'; Title = 'SharePoint Inventory'; Version = @{ Number = 1 } }
            }

            $result = Sync-ConfluenceSharePointInventory -SpaceKey 'TEST'

            $result.Title | Should Be 'SharePoint Inventory'
        }

        It 'Returns PSCustomObject with SpaceKey property' {
            Mock Get-ConfluenceSpace { [PSCustomObject]@{ Key = 'CONTOSO' } }
            Mock Search-Confluence { $null }
            Mock ConvertTo-ConfluenceSharePointPage { '{"type":"doc"}' }
            Mock New-ConfluencePage {
                [PSCustomObject]@{ Id = '123'; Title = 'SharePoint Inventory'; Version = @{ Number = 1 } }
            }

            $result = Sync-ConfluenceSharePointInventory -SpaceKey 'CONTOSO'

            $result.SpaceKey | Should Be 'CONTOSO'
        }

        It 'Returns PSCustomObject with Version property' {
            Mock Get-ConfluenceSpace { [PSCustomObject]@{ Key = 'TEST' } }
            Mock Search-Confluence { $null }
            Mock ConvertTo-ConfluenceSharePointPage { '{"type":"doc"}' }
            Mock New-ConfluencePage {
                [PSCustomObject]@{ Id = '123'; Title = 'Test'; Version = @{ Number = 1 } }
            }

            $result = Sync-ConfluenceSharePointInventory -SpaceKey 'TEST'

            $result.Version | Should Be 1
        }

        It 'Returns Action as Created for new pages' {
            Mock Get-ConfluenceSpace { [PSCustomObject]@{ Key = 'TEST' } }
            Mock Search-Confluence { $null }
            Mock ConvertTo-ConfluenceSharePointPage { '{"type":"doc"}' }
            Mock New-ConfluencePage {
                [PSCustomObject]@{ Id = '123'; Title = 'Test'; Version = @{ Number = 1 } }
            }

            $result = Sync-ConfluenceSharePointInventory -SpaceKey 'TEST'

            $result.Action | Should Be 'Created'
        }
    }

    Context 'AC2: Update Existing SharePoint Inventory Page' {
        It 'Updates page when exists' {
            Mock Get-ConfluenceSpace { [PSCustomObject]@{ Key = 'TEST' } }
            Mock Search-Confluence { [PSCustomObject]@{ Id = '999' } }
            Mock ConvertTo-ConfluenceSharePointPage { '{"type":"doc"}' }
            Mock Set-ConfluencePage {
                [PSCustomObject]@{ Id = '999'; Title = 'SharePoint Inventory'; Version = @{ Number = 2 } }
            }

            $result = Sync-ConfluenceSharePointInventory -SpaceKey 'TEST'

            Assert-MockCalled Set-ConfluencePage -Scope It
        }

        It 'Returns Action as Updated for existing pages' {
            Mock Get-ConfluenceSpace { [PSCustomObject]@{ Key = 'TEST' } }
            Mock Search-Confluence { [PSCustomObject]@{ Id = '999' } }
            Mock ConvertTo-ConfluenceSharePointPage { '{"type":"doc"}' }
            Mock Set-ConfluencePage {
                [PSCustomObject]@{ Id = '999'; Title = 'SharePoint Inventory'; Version = @{ Number = 2 } }
            }

            $result = Sync-ConfluenceSharePointInventory -SpaceKey 'TEST'

            $result.Action | Should Be 'Updated'
        }

        It 'Returns incremented version for updated pages' {
            Mock Get-ConfluenceSpace { [PSCustomObject]@{ Key = 'TEST' } }
            Mock Search-Confluence { [PSCustomObject]@{ Id = '999' } }
            Mock ConvertTo-ConfluenceSharePointPage { '{"type":"doc"}' }
            Mock Set-ConfluencePage {
                [PSCustomObject]@{ Id = '999'; Title = 'SharePoint Inventory'; Version = @{ Number = 5 } }
            }

            $result = Sync-ConfluenceSharePointInventory -SpaceKey 'TEST'

            $result.Version | Should Be 5
        }
    }

    Context 'AC5: Support -WhatIf' {
        It 'Does not create page with WhatIf' {
            Mock Get-ConfluenceSpace { [PSCustomObject]@{ Key = 'TEST' } }
            Mock Search-Confluence { $null }
            Mock ConvertTo-ConfluenceSharePointPage { '{"type":"doc"}' }
            Mock New-ConfluencePage { throw "Should not be called" }

            $result = Sync-ConfluenceSharePointInventory -SpaceKey 'TEST' -WhatIf

            Assert-MockCalled New-ConfluencePage -Exactly 0 -Scope It
        }

        It 'Does not update page with WhatIf' {
            Mock Get-ConfluenceSpace { [PSCustomObject]@{ Key = 'TEST' } }
            Mock Search-Confluence { [PSCustomObject]@{ Id = '999' } }
            Mock ConvertTo-ConfluenceSharePointPage { '{"type":"doc"}' }
            Mock Set-ConfluencePage { throw "Should not be called" }

            $result = Sync-ConfluenceSharePointInventory -SpaceKey 'TEST' -WhatIf

            Assert-MockCalled Set-ConfluencePage -Exactly 0 -Scope It
        }

        It 'Returns null with WhatIf' {
            Mock Get-ConfluenceSpace { [PSCustomObject]@{ Key = 'TEST' } }
            Mock Search-Confluence { $null }
            Mock ConvertTo-ConfluenceSharePointPage { '{"type":"doc"}' }

            $result = Sync-ConfluenceSharePointInventory -SpaceKey 'TEST' -WhatIf

            $result | Should Be $null
        }
    }

    Context 'AC6: Support -Verbose Logging' {
        It 'Writes verbose message for syncing' {
            Mock Get-ConfluenceSpace { [PSCustomObject]@{ Key = 'CONTOSO' } }
            Mock Search-Confluence { $null }
            Mock ConvertTo-ConfluenceSharePointPage { '{"type":"doc"}' }
            Mock New-ConfluencePage {
                [PSCustomObject]@{ Id = '123'; Title = 'Test'; Version = @{ Number = 1 } }
            }

            $verboseOutput = Sync-ConfluenceSharePointInventory -SpaceKey 'CONTOSO' -Verbose 4>&1
            $verboseMessages = $verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }

            $verboseMessages | Should Not Be $null
        }

        It 'Verbose message includes space key' {
            Mock Get-ConfluenceSpace { [PSCustomObject]@{ Key = 'MYSPACE' } }
            Mock Search-Confluence { $null }
            Mock ConvertTo-ConfluenceSharePointPage { '{"type":"doc"}' }
            Mock New-ConfluencePage {
                [PSCustomObject]@{ Id = '123'; Title = 'Test'; Version = @{ Number = 1 } }
            }

            $verboseOutput = Sync-ConfluenceSharePointInventory -SpaceKey 'MYSPACE' -Verbose 4>&1
            $verboseText = ($verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] } | ForEach-Object { $_.Message }) -join ' '

            $verboseText | Should Match 'MYSPACE'
        }
    }

    Context 'AC7: Validate Space Exists (Error Handling)' {
        It 'Throws error for non-existent space' {
            Mock Get-ConfluenceSpace { $null }

            { Sync-ConfluenceSharePointInventory -SpaceKey 'INVALID' } | Should Throw
        }

        It 'Error message includes actionable guidance' {
            Mock Get-ConfluenceSpace { $null }

            try {
                Sync-ConfluenceSharePointInventory -SpaceKey 'BADSPACE'
            } catch {
                $_.Exception.Message | Should Match 'Get-ConfluenceSpace'
            }
        }

        It 'Error message includes the space key' {
            Mock Get-ConfluenceSpace { $null }

            try {
                Sync-ConfluenceSharePointInventory -SpaceKey 'NOTFOUND'
            } catch {
                $_.Exception.Message | Should Match 'NOTFOUND'
            }
        }
    }

    Context 'AC8: Handle Empty SharePoint Data' {
        It 'Handles null SharePointData without error' {
            Mock Get-ConfluenceSpace { [PSCustomObject]@{ Key = 'TEST' } }
            Mock Search-Confluence { $null }
            Mock ConvertTo-ConfluenceSharePointPage { '{"type":"doc"}' }
            Mock New-ConfluencePage {
                [PSCustomObject]@{ Id = '123'; Title = 'Test'; Version = @{ Number = 1 } }
            }

            { Sync-ConfluenceSharePointInventory -SpaceKey 'TEST' -SharePointData $null } | Should Not Throw
        }

        It 'Handles empty array without error' {
            Mock Get-ConfluenceSpace { [PSCustomObject]@{ Key = 'TEST' } }
            Mock Search-Confluence { $null }
            Mock ConvertTo-ConfluenceSharePointPage { '{"type":"doc"}' }
            Mock New-ConfluencePage {
                [PSCustomObject]@{ Id = '123'; Title = 'Test'; Version = @{ Number = 1 } }
            }

            { Sync-ConfluenceSharePointInventory -SpaceKey 'TEST' -SharePointData @() } | Should Not Throw
        }

        It 'Creates page even with empty data' {
            Mock Get-ConfluenceSpace { [PSCustomObject]@{ Key = 'TEST' } }
            Mock Search-Confluence { $null }
            Mock ConvertTo-ConfluenceSharePointPage { '{"type":"doc"}' }
            Mock New-ConfluencePage {
                [PSCustomObject]@{ Id = '123'; Title = 'SharePoint Inventory'; Version = @{ Number = 1 } }
            }

            $result = Sync-ConfluenceSharePointInventory -SpaceKey 'TEST' -SharePointData $null

            $result | Should Not Be $null
            Assert-MockCalled New-ConfluencePage -Scope It
        }
    }

    Context 'AC9: Support Parent Page Hierarchy' {
        It 'Accepts ParentPageId parameter' {
            Mock Get-ConfluenceSpace { [PSCustomObject]@{ Key = 'TEST' } }
            Mock Search-Confluence { $null }
            Mock ConvertTo-ConfluenceSharePointPage { '{"type":"doc"}' }
            Mock New-ConfluencePage {
                [PSCustomObject]@{ Id = '123'; Title = 'Test'; Version = @{ Number = 1 } }
            }

            { Sync-ConfluenceSharePointInventory -SpaceKey 'TEST' -ParentPageId '456' } | Should Not Throw
        }

        It 'Passes ParentPageId to New-ConfluencePage' {
            $script:capturedParentId = $null
            Mock Get-ConfluenceSpace { [PSCustomObject]@{ Key = 'TEST' } }
            Mock Search-Confluence { $null }
            Mock ConvertTo-ConfluenceSharePointPage { '{"type":"doc"}' }
            Mock New-ConfluencePage {
                param($SpaceKey, $Title, $Body, $ParentId)
                $script:capturedParentId = $ParentId
                [PSCustomObject]@{ Id = '123'; Title = 'Test'; Version = @{ Number = 1 } }
            }

            Sync-ConfluenceSharePointInventory -SpaceKey 'TEST' -ParentPageId '789'

            $script:capturedParentId | Should Be '789'
        }

        It 'Does not pass ParentId when updating existing page' {
            Mock Get-ConfluenceSpace { [PSCustomObject]@{ Key = 'TEST' } }
            Mock Search-Confluence { [PSCustomObject]@{ Id = '999' } }
            Mock ConvertTo-ConfluenceSharePointPage { '{"type":"doc"}' }
            Mock Set-ConfluencePage {
                [PSCustomObject]@{ Id = '999'; Title = 'Test'; Version = @{ Number = 2 } }
            }

            Sync-ConfluenceSharePointInventory -SpaceKey 'TEST' -ParentPageId '456'

            # Existing pages should be updated, not moved
            Assert-MockCalled Set-ConfluencePage -Scope It
            Assert-MockCalled New-ConfluencePage -Exactly 0 -Scope It
        }
    }

    Context 'CQL Query' {
        It 'Uses correct CQL query format' {
            $script:capturedCQL = $null
            Mock Get-ConfluenceSpace { [PSCustomObject]@{ Key = 'TEST' } }
            Mock Search-Confluence {
                param($CQL)
                $script:capturedCQL = $CQL
                $null
            }
            Mock ConvertTo-ConfluenceSharePointPage { '{"type":"doc"}' }
            Mock New-ConfluencePage {
                [PSCustomObject]@{ Id = '123'; Title = 'Test'; Version = @{ Number = 1 } }
            }

            Sync-ConfluenceSharePointInventory -SpaceKey 'MYSPACE' -PageTitle 'Custom Title'

            $script:capturedCQL | Should Match "space = 'MYSPACE'"
            $script:capturedCQL | Should Match "title = 'Custom Title'"
            $script:capturedCQL | Should Match "type = page"
        }

        It 'Escapes single quotes in SpaceKey for CQL safety' {
            $script:capturedCQL = $null
            Mock Get-ConfluenceSpace { [PSCustomObject]@{ Key = "Test's" } }
            Mock Search-Confluence {
                param($CQL)
                $script:capturedCQL = $CQL
                $null
            }
            Mock ConvertTo-ConfluenceSharePointPage { '{"type":"doc"}' }
            Mock New-ConfluencePage {
                [PSCustomObject]@{ Id = '123'; Title = 'Test'; Version = @{ Number = 1 } }
            }

            Sync-ConfluenceSharePointInventory -SpaceKey "Test's"

            $script:capturedCQL | Should Match "'Test''s'"
        }

        It 'Escapes single quotes in PageTitle for CQL safety' {
            $script:capturedCQL = $null
            Mock Get-ConfluenceSpace { [PSCustomObject]@{ Key = 'TEST' } }
            Mock Search-Confluence {
                param($CQL)
                $script:capturedCQL = $CQL
                $null
            }
            Mock ConvertTo-ConfluenceSharePointPage { '{"type":"doc"}' }
            Mock New-ConfluencePage {
                [PSCustomObject]@{ Id = '123'; Title = 'Test'; Version = @{ Number = 1 } }
            }

            Sync-ConfluenceSharePointInventory -SpaceKey 'TEST' -PageTitle "It's SharePoint"

            $script:capturedCQL | Should Match "'It''s SharePoint'"
        }
    }

    Context 'Custom PageTitle' {
        It 'Uses default title SharePoint Inventory' {
            $script:capturedTitle = $null
            Mock Get-ConfluenceSpace { [PSCustomObject]@{ Key = 'TEST' } }
            Mock Search-Confluence { $null }
            Mock ConvertTo-ConfluenceSharePointPage { '{"type":"doc"}' }
            Mock New-ConfluencePage {
                param($SpaceKey, $Title, $Body, $ParentId)
                $script:capturedTitle = $Title
                [PSCustomObject]@{ Id = '123'; Title = $Title; Version = @{ Number = 1 } }
            }

            Sync-ConfluenceSharePointInventory -SpaceKey 'TEST'

            $script:capturedTitle | Should Be 'SharePoint Inventory'
        }

        It 'Accepts custom PageTitle' {
            $script:capturedTitle = $null
            Mock Get-ConfluenceSpace { [PSCustomObject]@{ Key = 'TEST' } }
            Mock Search-Confluence { $null }
            Mock ConvertTo-ConfluenceSharePointPage { '{"type":"doc"}' }
            Mock New-ConfluencePage {
                param($SpaceKey, $Title, $Body, $ParentId)
                $script:capturedTitle = $Title
                [PSCustomObject]@{ Id = '123'; Title = $Title; Version = @{ Number = 1 } }
            }

            Sync-ConfluenceSharePointInventory -SpaceKey 'TEST' -PageTitle 'Storage Report'

            $script:capturedTitle | Should Be 'Storage Report'
        }
    }

    Context 'Transformer Integration' {
        It 'Passes SharePointData to transformer' {
            $script:capturedData = $null
            Mock Get-ConfluenceSpace { [PSCustomObject]@{ Key = 'TEST' } }
            Mock Search-Confluence { $null }
            Mock ConvertTo-ConfluenceSharePointPage {
                param($SharePointData)
                $script:capturedData = $SharePointData
                '{"type":"doc"}'
            }
            Mock New-ConfluencePage {
                [PSCustomObject]@{ Id = '123'; Title = 'Test'; Version = @{ Number = 1 } }
            }

            $testData = @(
                [PSCustomObject]@{ displayName = 'Site1' }
                [PSCustomObject]@{ displayName = 'Site2' }
            )
            Sync-ConfluenceSharePointInventory -SpaceKey 'TEST' -SharePointData $testData

            $script:capturedData.Count | Should Be 2
        }
    }
}
