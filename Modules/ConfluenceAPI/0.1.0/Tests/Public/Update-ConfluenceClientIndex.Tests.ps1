$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleRoot = Split-Path -Parent (Split-Path -Parent $here)
$publicDir = Join-Path $moduleRoot 'Public'
$privateDir = Join-Path $moduleRoot 'Private'

Describe 'Update-ConfluenceClientIndex' {
    BeforeAll {
        # Define stub functions for dependencies
        function Get-ConfluenceTenantMapping { }
        function Get-ConfluenceBaseURL { }
        function Search-Confluence { param($CQL) }
        function New-ConfluencePage { param($SpaceKey, $Title, $Body) }
        function Set-ConfluencePage { param($PageId, $Body) }
        function New-ADFDocument { }
        function Add-ADFContent { param($Document, $Content) }
        function ConvertTo-ADF { param($InputObject) }
        function New-ADFHeading { param($Level, $Text) }
        function New-ADFParagraph { param($Text) }

        # Dot-source required private functions
        . "$privateDir\New-ADFDocument.ps1"
        . "$privateDir\Add-ADFContent.ps1"
        . "$privateDir\ConvertTo-ADF.ps1"
        . "$privateDir\New-ADFHeading.ps1"
        . "$privateDir\New-ADFParagraph.ps1"
        . "$privateDir\ConvertTo-ConfluenceClientIndex.ps1"

        # Dot-source function under test
        . "$publicDir\Update-ConfluenceClientIndex.ps1"
    }

    Context 'Create New Index Page' {
        BeforeEach {
            Mock Get-ConfluenceBaseURL { return 'https://example.atlassian.net' }
            Mock Get-ConfluenceTenantMapping {
                @(
                    [PSCustomObject]@{ TenantId = 't1'; SpaceKey = 'SPACE1'; SpaceName = 'Client One' },
                    [PSCustomObject]@{ TenantId = 't2'; SpaceKey = 'SPACE2'; SpaceName = 'Client Two' }
                )
            }
            Mock Search-Confluence { return $null }
            Mock New-ConfluencePage {
                [PSCustomObject]@{ Id = 'new-page-123'; Title = $Title }
            }
            Mock Set-ConfluencePage { }
        }

        It 'Creates index page when not exists' {
            $result = Update-ConfluenceClientIndex
            Assert-MockCalled New-ConfluencePage -Scope It -Times 1
            $result.Status | Should Be 'Created'
        }

        It 'Returns PSCustomObject with expected properties' {
            $result = Update-ConfluenceClientIndex
            $result.PageId | Should Be 'new-page-123'
            $result.ClientCount | Should Be 2
            $result.Status | Should Be 'Created'
        }

        It 'Uses default RootSpaceKey of MSP' {
            $script:capturedCQL = $null
            Mock Search-Confluence {
                param($CQL)
                $script:capturedCQL = $CQL
                return $null
            }
            Update-ConfluenceClientIndex
            $script:capturedCQL | Should Match "space = 'MSP'"
        }

        It 'Uses default IndexPageTitle of CLIENTS-INDEX' {
            $script:capturedCQL = $null
            Mock Search-Confluence {
                param($CQL)
                $script:capturedCQL = $CQL
                return $null
            }
            Update-ConfluenceClientIndex
            $script:capturedCQL | Should Match "title = 'CLIENTS-INDEX'"
        }

        It 'Calls Get-ConfluenceTenantMapping to retrieve mappings' {
            Update-ConfluenceClientIndex
            Assert-MockCalled Get-ConfluenceTenantMapping -Scope It -Times 1
        }

        It 'Calls Get-ConfluenceBaseURL for space links' {
            Update-ConfluenceClientIndex
            Assert-MockCalled Get-ConfluenceBaseURL -Scope It -Times 1
        }
    }

    Context 'Update Existing Index Page' {
        BeforeEach {
            Mock Get-ConfluenceBaseURL { return 'https://example.atlassian.net' }
            Mock Get-ConfluenceTenantMapping {
                @([PSCustomObject]@{ TenantId = 't1'; SpaceKey = 'SPACE1'; SpaceName = 'Client One' })
            }
            Mock Search-Confluence {
                [PSCustomObject]@{ Id = 'existing-123'; Title = 'CLIENTS-INDEX' }
            }
            Mock New-ConfluencePage { }
            Mock Set-ConfluencePage { }
        }

        It 'Updates existing page instead of creating' {
            $result = Update-ConfluenceClientIndex
            Assert-MockCalled Set-ConfluencePage -Scope It -Times 1
            Assert-MockCalled New-ConfluencePage -Times 0 -Scope It
            $result.Status | Should Be 'Updated'
        }

        It 'Uses existing page ID for update' {
            $script:capturedPageId = $null
            Mock Set-ConfluencePage {
                param($PageId, $Body)
                $script:capturedPageId = $PageId
            }
            Update-ConfluenceClientIndex
            $script:capturedPageId | Should Be 'existing-123'
        }

        It 'Returns existing page ID' {
            $result = Update-ConfluenceClientIndex
            $result.PageId | Should Be 'existing-123'
        }
    }

    Context 'WhatIf Support' {
        BeforeEach {
            Mock Get-ConfluenceBaseURL { return 'https://example.atlassian.net' }
            Mock Get-ConfluenceTenantMapping { return @() }
            Mock Search-Confluence { return $null }
            Mock New-ConfluencePage { }
            Mock Set-ConfluencePage { }
        }

        It 'Does not create page with WhatIf' {
            Update-ConfluenceClientIndex -WhatIf
            Assert-MockCalled New-ConfluencePage -Times 0 -Scope It
            Assert-MockCalled Set-ConfluencePage -Times 0 -Scope It
        }

        It 'Returns nothing with WhatIf' {
            $result = Update-ConfluenceClientIndex -WhatIf
            $result | Should Be $null
        }
    }

    Context 'Empty Mappings' {
        BeforeEach {
            Mock Get-ConfluenceBaseURL { return 'https://example.atlassian.net' }
            Mock Get-ConfluenceTenantMapping { return @() }
            Mock Search-Confluence { return $null }
            Mock New-ConfluencePage {
                [PSCustomObject]@{ Id = 'empty-page-456'; Title = $Title }
            }
        }

        It 'Creates page even with no mappings' {
            $result = Update-ConfluenceClientIndex
            Assert-MockCalled New-ConfluencePage -Scope It -Times 1
            $result.ClientCount | Should Be 0
        }

        It 'Returns zero ClientCount for empty mappings' {
            $result = Update-ConfluenceClientIndex
            $result.ClientCount | Should Be 0
            $result.Status | Should Be 'Created'
        }
    }

    Context 'Custom Parameters' {
        BeforeEach {
            Mock Get-ConfluenceBaseURL { return 'https://example.atlassian.net' }
            Mock Get-ConfluenceTenantMapping { return @() }
            Mock Search-Confluence { return $null }
            Mock New-ConfluencePage {
                param($SpaceKey, $Title, $Body)
                [PSCustomObject]@{ Id = 'custom-page'; Title = $Title }
            }
        }

        It 'Accepts custom RootSpaceKey parameter' {
            $script:capturedSpaceKey = $null
            Mock New-ConfluencePage {
                param($SpaceKey, $Title, $Body)
                $script:capturedSpaceKey = $SpaceKey
                [PSCustomObject]@{ Id = 'custom-page'; Title = $Title }
            }
            Update-ConfluenceClientIndex -RootSpaceKey 'CUSTOM'
            $script:capturedSpaceKey | Should Be 'CUSTOM'
        }

        It 'Accepts custom IndexPageTitle parameter' {
            $script:capturedTitle = $null
            Mock New-ConfluencePage {
                param($SpaceKey, $Title, $Body)
                $script:capturedTitle = $Title
                [PSCustomObject]@{ Id = 'custom-page'; Title = $Title }
            }
            Update-ConfluenceClientIndex -IndexPageTitle 'My Index'
            $script:capturedTitle | Should Be 'My Index'
        }

        It 'Uses custom parameters in CQL search' {
            $script:capturedCQL = $null
            Mock Search-Confluence {
                param($CQL)
                $script:capturedCQL = $CQL
                return $null
            }
            Update-ConfluenceClientIndex -RootSpaceKey 'DOCS' -IndexPageTitle 'Client Directory'
            $script:capturedCQL | Should Match "title = 'Client Directory'"
            $script:capturedCQL | Should Match "space = 'DOCS'"
        }
    }

    Context 'Verbose Logging' {
        BeforeEach {
            Mock Get-ConfluenceBaseURL { return 'https://example.atlassian.net' }
            Mock Get-ConfluenceTenantMapping {
                @([PSCustomObject]@{ TenantId = 't1'; SpaceKey = 'TEST'; SpaceName = 'Test Client' })
            }
            Mock Search-Confluence { return $null }
            Mock New-ConfluencePage {
                [PSCustomObject]@{ Id = 'test-page'; Title = 'CLIENTS-INDEX' }
            }
        }

        It 'Writes verbose messages during execution' {
            $verboseOutput = Update-ConfluenceClientIndex -Verbose 4>&1
            $verboseMessages = $verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }
            $verboseMessages.Count | Should BeGreaterThan 0
        }
    }

    Context 'Error Handling' {
        BeforeEach {
            Mock Get-ConfluenceTenantMapping { return @() }
            Mock Search-Confluence { return $null }
        }

        It 'Throws error when base URL not configured' {
            Mock Get-ConfluenceBaseURL { return $null }
            { Update-ConfluenceClientIndex } | Should Throw
        }

        It 'Error message mentions New-ConfluenceBaseURL' {
            Mock Get-ConfluenceBaseURL { return $null }
            try {
                Update-ConfluenceClientIndex
            }
            catch {
                $_.Exception.Message | Should Match 'New-ConfluenceBaseURL'
            }
        }
    }

    Context 'Search CQL Correctness' {
        BeforeEach {
            Mock Get-ConfluenceBaseURL { return 'https://example.atlassian.net' }
            Mock Get-ConfluenceTenantMapping { return @() }
            Mock New-ConfluencePage {
                [PSCustomObject]@{ Id = 'page-id'; Title = 'CLIENTS-INDEX' }
            }
        }

        It 'Searches with correct CQL syntax' {
            $script:capturedCQL = $null
            Mock Search-Confluence {
                param($CQL)
                $script:capturedCQL = $CQL
                return $null
            }
            Update-ConfluenceClientIndex
            $script:capturedCQL | Should Be "title = 'CLIENTS-INDEX' and space = 'MSP' and type = page"
        }

        It 'Escapes single quotes in IndexPageTitle for CQL' {
            $script:capturedCQL = $null
            Mock Search-Confluence {
                param($CQL)
                $script:capturedCQL = $CQL
                return $null
            }
            Update-ConfluenceClientIndex -IndexPageTitle "Client's Index"
            $script:capturedCQL | Should Match "title = 'Client''s Index'"
        }
    }
}
