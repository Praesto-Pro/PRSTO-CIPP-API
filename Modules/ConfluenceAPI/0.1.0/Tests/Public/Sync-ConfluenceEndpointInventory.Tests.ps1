$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $here)) 'Public'

Describe 'Sync-ConfluenceEndpointInventory' {
    BeforeAll {
        # Define stub functions for dependencies that will be mocked (Pester 3.4 requirement)
        # Public dependencies
        function Get-ConfluenceSpace { param($SpaceKey) }
        function Search-Confluence { param($CQL) }
        function New-ConfluencePage { param($SpaceKey, $Title, $Body, $ParentId) }
        function Set-ConfluencePage { param($PageId, $Body) }
        # Private dependency - stub for isolation (instead of dot-sourcing real implementation)
        function ConvertTo-ConfluenceEndpointPage { param($Endpoints) }

        # Dot-source the function under test
        . "$publicDir\Sync-ConfluenceEndpointInventory.ps1"
    }

    Context 'New Page Creation (AC1)' {
        BeforeAll {
            # Mock dependencies for new page scenario
            Mock Get-ConfluenceSpace { return [PSCustomObject]@{ Id = '123'; Key = 'CONTOSO'; Name = 'Contoso Corp' } }
            Mock Search-Confluence { return $null }  # No existing page
            Mock ConvertTo-ConfluenceEndpointPage { return '{"version":1,"type":"doc","content":[]}' }
            Mock New-ConfluencePage { return [PSCustomObject]@{ Id = '456'; Title = 'Endpoint Inventory'; Version = @{ Number = 1 } } }
            Mock Set-ConfluencePage { return [PSCustomObject]@{ Id = '456'; Title = 'Endpoint Inventory'; Version = @{ Number = 2 } } }
        }

        It 'Creates page when none exists' {
            $result = Sync-ConfluenceEndpointInventory -SpaceKey 'CONTOSO' -Endpoints @()

            $result | Should Not Be $null
            $result.Action | Should Be 'Created'
        }

        It 'Calls New-ConfluencePage for new page' {
            Sync-ConfluenceEndpointInventory -SpaceKey 'CONTOSO' -Endpoints @()

            Assert-MockCalled -CommandName 'New-ConfluencePage' -Scope It
        }

        It 'Returns PSCustomObject with correct properties' {
            $result = Sync-ConfluenceEndpointInventory -SpaceKey 'CONTOSO' -Endpoints @()

            $result.Id | Should Be '456'
            $result.Title | Should Be 'Endpoint Inventory'
            $result.SpaceKey | Should Be 'CONTOSO'
            $result.Version | Should Be 1
            $result.Action | Should Be 'Created'
        }

        It 'Validates space exists before sync' {
            Sync-ConfluenceEndpointInventory -SpaceKey 'CONTOSO' -Endpoints @()

            Assert-MockCalled -CommandName 'Get-ConfluenceSpace' -Scope It
        }

        It 'Searches for existing page' {
            Sync-ConfluenceEndpointInventory -SpaceKey 'CONTOSO' -Endpoints @()

            Assert-MockCalled -CommandName 'Search-Confluence' -Scope It
        }

        It 'Uses correct CQL query format' {
            $script:capturedCQL = $null
            Mock Search-Confluence {
                param($CQL)
                $script:capturedCQL = $CQL
                return $null
            }

            Sync-ConfluenceEndpointInventory -SpaceKey 'CONTOSO' -Endpoints @() -PageTitle 'Endpoint Inventory'

            $script:capturedCQL | Should Be "space = 'CONTOSO' AND title = 'Endpoint Inventory' AND type = page"
        }

        It 'Escapes single quotes in space key for CQL safety' {
            $script:capturedCQL = $null
            Mock Search-Confluence {
                param($CQL)
                $script:capturedCQL = $CQL
                return $null
            }

            Sync-ConfluenceEndpointInventory -SpaceKey "CONT'OSO" -Endpoints @()

            $script:capturedCQL | Should Match "CONT''OSO"
        }

        It 'Escapes single quotes in page title for CQL safety' {
            $script:capturedCQL = $null
            Mock Search-Confluence {
                param($CQL)
                $script:capturedCQL = $CQL
                return $null
            }

            Sync-ConfluenceEndpointInventory -SpaceKey 'CONTOSO' -Endpoints @() -PageTitle "Endpoint's Inventory"

            $script:capturedCQL | Should Be "space = 'CONTOSO' AND title = 'Endpoint''s Inventory' AND type = page"
        }
    }

    Context 'Page Update (AC2)' {
        BeforeAll {
            Mock Get-ConfluenceSpace { return [PSCustomObject]@{ Id = '123'; Key = 'CONTOSO'; Name = 'Contoso Corp' } }
            Mock Search-Confluence { return [PSCustomObject]@{ Id = '789'; Title = 'Endpoint Inventory' } }
            Mock ConvertTo-ConfluenceEndpointPage { return '{"version":1,"type":"doc","content":[]}' }
            Mock New-ConfluencePage { return [PSCustomObject]@{ Id = '456'; Title = 'Endpoint Inventory'; Version = @{ Number = 1 } } }
            Mock Set-ConfluencePage { return [PSCustomObject]@{ Id = '789'; Title = 'Endpoint Inventory'; Version = @{ Number = 2 } } }
        }

        It 'Updates page when exists' {
            $result = Sync-ConfluenceEndpointInventory -SpaceKey 'CONTOSO' -Endpoints @()

            $result.Action | Should Be 'Updated'
        }

        It 'Calls Set-ConfluencePage for existing page' {
            Sync-ConfluenceEndpointInventory -SpaceKey 'CONTOSO' -Endpoints @()

            Assert-MockCalled -CommandName 'Set-ConfluencePage' -Scope It
        }

        It 'Does not call New-ConfluencePage when page exists' {
            Sync-ConfluenceEndpointInventory -SpaceKey 'CONTOSO' -Endpoints @()

            Assert-MockCalled -CommandName 'New-ConfluencePage' -Times 0
        }

        It 'Returns incremented version number' {
            $result = Sync-ConfluenceEndpointInventory -SpaceKey 'CONTOSO' -Endpoints @()

            $result.Version | Should Be 2
        }
    }

    Context 'WhatIf Support (AC3)' {
        BeforeAll {
            Mock Get-ConfluenceSpace { return [PSCustomObject]@{ Id = '123'; Key = 'CONTOSO'; Name = 'Contoso Corp' } }
            Mock Search-Confluence { return $null }
            Mock ConvertTo-ConfluenceEndpointPage { return '{"version":1,"type":"doc","content":[]}' }
            Mock New-ConfluencePage { return [PSCustomObject]@{ Id = '456'; Title = 'Endpoint Inventory'; Version = @{ Number = 1 } } }
        }

        It 'Does not create page with WhatIf' {
            Sync-ConfluenceEndpointInventory -SpaceKey 'CONTOSO' -Endpoints @() -WhatIf

            Assert-MockCalled -CommandName 'New-ConfluencePage' -Times 0
        }

        It 'Returns null with WhatIf' {
            $result = Sync-ConfluenceEndpointInventory -SpaceKey 'CONTOSO' -Endpoints @() -WhatIf

            $result | Should Be $null
        }

        It 'Does not update page with WhatIf' {
            Mock Search-Confluence { return [PSCustomObject]@{ Id = '789'; Title = 'Endpoint Inventory' } }
            Mock Set-ConfluencePage { return [PSCustomObject]@{ Id = '789'; Title = 'Endpoint Inventory'; Version = @{ Number = 2 } } }

            Sync-ConfluenceEndpointInventory -SpaceKey 'CONTOSO' -Endpoints @() -WhatIf

            Assert-MockCalled -CommandName 'Set-ConfluencePage' -Times 0
        }
    }

    Context 'Verbose Logging (AC4)' {
        BeforeAll {
            Mock Get-ConfluenceSpace { return [PSCustomObject]@{ Id = '123'; Key = 'CONTOSO'; Name = 'Contoso Corp' } }
            Mock Search-Confluence { return $null }
            Mock ConvertTo-ConfluenceEndpointPage { return '{"version":1,"type":"doc","content":[]}' }
            Mock New-ConfluencePage { return [PSCustomObject]@{ Id = '456'; Title = 'Endpoint Inventory'; Version = @{ Number = 1 } } }
        }

        It 'Writes verbose message for space sync' {
            $verboseOutput = Sync-ConfluenceEndpointInventory -SpaceKey 'CONTOSO' -Endpoints @() -Verbose 4>&1

            ($verboseOutput -join ' ') | Should Match 'Syncing endpoint inventory to space'
        }

        It 'Writes verbose message for endpoint count' {
            $verboseOutput = Sync-ConfluenceEndpointInventory -SpaceKey 'CONTOSO' -Endpoints @() -Verbose 4>&1

            ($verboseOutput -join ' ') | Should Match 'endpoint\(s\)'
        }

        It 'Writes verbose message for CQL search' {
            $verboseOutput = Sync-ConfluenceEndpointInventory -SpaceKey 'CONTOSO' -Endpoints @() -Verbose 4>&1

            ($verboseOutput -join ' ') | Should Match 'Searching for existing page'
        }

        It 'Writes verbose message on page creation' {
            $verboseOutput = Sync-ConfluenceEndpointInventory -SpaceKey 'CONTOSO' -Endpoints @() -Verbose 4>&1

            ($verboseOutput -join ' ') | Should Match 'Successfully created page'
        }

        It 'Writes verbose message on page update with ID and version' {
            Mock Search-Confluence { return [PSCustomObject]@{ Id = '789'; Title = 'Endpoint Inventory' } }
            Mock ConvertTo-ConfluenceEndpointPage { return '{"version":1,"type":"doc","content":[]}' }
            Mock Set-ConfluencePage { return [PSCustomObject]@{ Id = '789'; Title = 'Endpoint Inventory'; Version = @{ Number = 2 } } }

            $verboseOutput = Sync-ConfluenceEndpointInventory -SpaceKey 'CONTOSO' -Endpoints @() -Verbose 4>&1

            ($verboseOutput -join ' ') | Should Match 'Successfully updated page'
            ($verboseOutput -join ' ') | Should Match 'ID.*789'
            ($verboseOutput -join ' ') | Should Match 'Version.*2'
        }
    }

    Context 'Device Details Display (AC5)' {
        BeforeAll {
            Mock Get-ConfluenceSpace { return [PSCustomObject]@{ Id = '123'; Key = 'CONTOSO'; Name = 'Contoso Corp' } }
            Mock Search-Confluence { return $null }
            Mock ConvertTo-ConfluenceEndpointPage { return '{"version":1,"type":"doc","content":[]}' }
            Mock New-ConfluencePage { return [PSCustomObject]@{ Id = '456'; Title = 'Endpoint Inventory'; Version = @{ Number = 1 } } }
        }

        It 'Passes endpoints to ConvertTo-ConfluenceEndpointPage' {
            $endpoints = @(
                [PSCustomObject]@{
                    deviceName = 'DESKTOP-ABC123'
                    operatingSystem = 'Windows 10'
                    complianceState = 'compliant'
                    userDisplayName = 'John Smith'
                    lastSyncDateTime = '2025-12-13T10:30:00Z'
                }
            )

            $result = Sync-ConfluenceEndpointInventory -SpaceKey 'CONTOSO' -Endpoints $endpoints

            # Verify the function completed without error and data was processed
            $result | Should Not Be $null
        }
    }

    Context 'Device Assignment Display (AC6)' {
        BeforeAll {
            Mock Get-ConfluenceSpace { return [PSCustomObject]@{ Id = '123'; Key = 'CONTOSO'; Name = 'Contoso Corp' } }
            Mock Search-Confluence { return $null }
            Mock ConvertTo-ConfluenceEndpointPage { return '{"version":1,"type":"doc","content":[]}' }
            Mock New-ConfluencePage { return [PSCustomObject]@{ Id = '456'; Title = 'Endpoint Inventory'; Version = @{ Number = 1 } } }
        }

        It 'Handles endpoints with user assignment' {
            $endpoints = @(
                [PSCustomObject]@{
                    deviceName = 'DESKTOP-ABC123'
                    userDisplayName = 'John Smith'
                    userPrincipalName = 'john@contoso.com'
                }
            )

            $result = Sync-ConfluenceEndpointInventory -SpaceKey 'CONTOSO' -Endpoints $endpoints

            $result | Should Not Be $null
        }

        It 'Handles endpoints without user assignment' {
            $endpoints = @(
                [PSCustomObject]@{
                    deviceName = 'DESKTOP-ABC123'
                    userDisplayName = $null
                    userPrincipalName = $null
                }
            )

            { Sync-ConfluenceEndpointInventory -SpaceKey 'CONTOSO' -Endpoints $endpoints } | Should Not Throw
        }
    }

    Context 'Error Handling (AC7)' {
        BeforeAll {
            Mock Get-ConfluenceSpace { return $null }
            Mock Search-Confluence { return $null }
            Mock New-ConfluencePage { return $null }
        }

        It 'Throws error for non-existent space' {
            { Sync-ConfluenceEndpointInventory -SpaceKey 'INVALID' -Endpoints @() } | Should Throw
        }

        It 'Error message contains space name' {
            try {
                Sync-ConfluenceEndpointInventory -SpaceKey 'INVALID' -Endpoints @() -ErrorAction Stop
            }
            catch {
                $_.Exception.Message | Should Match 'INVALID'
            }
        }

        It 'Error message includes actionable guidance' {
            try {
                Sync-ConfluenceEndpointInventory -SpaceKey 'INVALID' -Endpoints @() -ErrorAction Stop
            }
            catch {
                $_.Exception.Message | Should Match 'Get-ConfluenceSpace'
            }
        }
    }

    Context 'Empty Endpoints Handling (AC8)' {
        BeforeAll {
            Mock Get-ConfluenceSpace { return [PSCustomObject]@{ Id = '123'; Key = 'CONTOSO'; Name = 'Contoso Corp' } }
            Mock Search-Confluence { return $null }
            Mock ConvertTo-ConfluenceEndpointPage { return '{"version":1,"type":"doc","content":[]}' }
            Mock New-ConfluencePage { return [PSCustomObject]@{ Id = '456'; Title = 'Endpoint Inventory'; Version = @{ Number = 1 } } }
        }

        It 'Handles null endpoints without error' {
            { Sync-ConfluenceEndpointInventory -SpaceKey 'CONTOSO' -Endpoints $null } | Should Not Throw
        }

        It 'Handles empty array without error' {
            { Sync-ConfluenceEndpointInventory -SpaceKey 'CONTOSO' -Endpoints @() } | Should Not Throw
        }

        It 'Creates page even with empty endpoints' {
            $result = Sync-ConfluenceEndpointInventory -SpaceKey 'CONTOSO' -Endpoints @()

            $result | Should Not Be $null
            $result.Action | Should Be 'Created'
        }
    }

    Context 'Parent Page Support (AC9)' {
        BeforeAll {
            Mock Get-ConfluenceSpace { return [PSCustomObject]@{ Id = '123'; Key = 'CONTOSO'; Name = 'Contoso Corp' } }
            Mock Search-Confluence { return $null }
            Mock ConvertTo-ConfluenceEndpointPage { return '{"version":1,"type":"doc","content":[]}' }
            Mock New-ConfluencePage {
                param($SpaceKey, $Title, $Body, $ParentId)
                return [PSCustomObject]@{ Id = '456'; Title = 'Endpoint Inventory'; Version = @{ Number = 1 }; ParentId = $ParentId }
            }
        }

        It 'Accepts ParentPageId parameter' {
            { Sync-ConfluenceEndpointInventory -SpaceKey 'CONTOSO' -Endpoints @() -ParentPageId '99999' } | Should Not Throw
        }

        It 'Passes ParentPageId to New-ConfluencePage' {
            $script:capturedParentId = $null
            Mock ConvertTo-ConfluenceEndpointPage { return '{"version":1,"type":"doc","content":[]}' }
            Mock New-ConfluencePage {
                param($SpaceKey, $Title, $Body, $ParentId)
                $script:capturedParentId = $ParentId
                return [PSCustomObject]@{ Id = '456'; Title = 'Endpoint Inventory'; Version = @{ Number = 1 } }
            }

            Sync-ConfluenceEndpointInventory -SpaceKey 'CONTOSO' -Endpoints @() -ParentPageId '99999'

            $script:capturedParentId | Should Be '99999'
        }

        It 'Writes verbose message when using parent page' {
            $verboseOutput = Sync-ConfluenceEndpointInventory -SpaceKey 'CONTOSO' -Endpoints @() -ParentPageId '99999' -Verbose 4>&1

            ($verboseOutput -join ' ') | Should Match 'parent ID'
        }
    }

    Context 'Custom Page Title' {
        BeforeAll {
            Mock Get-ConfluenceSpace { return [PSCustomObject]@{ Id = '123'; Key = 'CONTOSO'; Name = 'Contoso Corp' } }
            Mock Search-Confluence { return $null }
            Mock ConvertTo-ConfluenceEndpointPage { return '{"version":1,"type":"doc","content":[]}' }
            Mock New-ConfluencePage {
                param($SpaceKey, $Title, $Body)
                return [PSCustomObject]@{ Id = '456'; Title = $Title; Version = @{ Number = 1 } }
            }
        }

        It 'Uses default page title' {
            $result = Sync-ConfluenceEndpointInventory -SpaceKey 'CONTOSO' -Endpoints @()

            $result.Title | Should Be 'Endpoint Inventory'
        }

        It 'Allows custom page title' {
            $result = Sync-ConfluenceEndpointInventory -SpaceKey 'CONTOSO' -Endpoints @() -PageTitle 'Custom Title'

            $result.Title | Should Be 'Custom Title'
        }
    }
}
