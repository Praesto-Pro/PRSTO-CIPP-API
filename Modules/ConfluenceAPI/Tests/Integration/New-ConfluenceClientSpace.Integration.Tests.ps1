$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleRoot = Split-Path -Parent (Split-Path -Parent $here)
$publicDir = Join-Path $moduleRoot 'Public'
$privateDir = Join-Path $moduleRoot 'Private'

Describe 'New-ConfluenceClientSpace Integration with CLIENTS-INDEX' {
    BeforeAll {
        # Define stub functions for all dependencies
        function Get-ConfluenceSpace { param($SpaceKey) }
        function New-ConfluenceSpace { param($SpaceKey, $Name, $Description) }
        function Set-ConfluencePage { param($PageId, $Body) }
        function Get-ConfluenceTenantMapping { param($TenantId, $SpaceKey) }
        function Set-ConfluenceTenantMapping { param($TenantId, $SpaceKey, $SpaceName) }
        function ConvertTo-ConfluenceClientHomepage { param($ClientName) }
        function Get-ConfluenceBaseURL { }
        function Search-Confluence { param($CQL) }
        function New-ConfluencePage { param($SpaceKey, $Title, $Body) }

        # Dot-source required private functions
        . "$privateDir\New-ADFDocument.ps1"
        . "$privateDir\Add-ADFContent.ps1"
        . "$privateDir\ConvertTo-ADF.ps1"
        . "$privateDir\New-ADFHeading.ps1"
        . "$privateDir\New-ADFParagraph.ps1"
        . "$privateDir\ConvertTo-ConfluenceClientIndex.ps1"

        # Dot-source public functions
        . "$publicDir\Update-ConfluenceClientIndex.ps1"
        . "$publicDir\New-ConfluenceClientSpace.ps1"
    }

    Context 'Space Creation Triggers Index Update' {
        BeforeEach {
            # Reset tracking
            $script:indexUpdateCalled = $false
            $script:indexUpdateParams = $null

            # Mock all dependencies
            Mock Get-ConfluenceSpace { return $null }
            Mock Get-ConfluenceTenantMapping {
                param($TenantId, $SpaceKey)
                if ($TenantId) { return $null }
                if ($SpaceKey) { return $null }
                # Return all mappings for Update-ConfluenceClientIndex
                return @(
                    [PSCustomObject]@{ TenantId = 'test-tenant'; SpaceKey = 'NEWCLIENT'; SpaceName = 'New Client' }
                )
            }
            Mock New-ConfluenceSpace {
                [PSCustomObject]@{
                    Id         = 'space-123'
                    Key        = 'NEWCLIENT'
                    Name       = 'New Client'
                    HomepageId = 'homepage-456'
                }
            }
            Mock Set-ConfluencePage { }
            Mock Set-ConfluenceTenantMapping { }
            Mock ConvertTo-ConfluenceClientHomepage { return '{"version":1,"type":"doc","content":[]}' }
            Mock Get-ConfluenceBaseURL { return 'https://example.atlassian.net' }
            Mock Search-Confluence { return $null }
            Mock New-ConfluencePage {
                $script:indexUpdateCalled = $true
                [PSCustomObject]@{ Id = 'index-page-789'; Title = 'CLIENTS-INDEX' }
            }
        }

        It 'Calls Update-ConfluenceClientIndex after creating space' {
            New-ConfluenceClientSpace -SpaceKey 'NEWCLIENT' -ClientName 'New Client' -TenantId 'test-tenant'
            $script:indexUpdateCalled | Should Be $true
        }

        It 'Space creation succeeds even when index update is triggered' {
            $result = New-ConfluenceClientSpace -SpaceKey 'NEWCLIENT' -ClientName 'New Client' -TenantId 'test-tenant'
            $result.SpaceKey | Should Be 'NEWCLIENT'
            $result.Name | Should Be 'New Client'
        }
    }

    Context 'Index Update Failure Does Not Fail Space Creation' {
        BeforeEach {
            Mock Get-ConfluenceSpace { return $null }
            Mock Get-ConfluenceTenantMapping {
                param($TenantId, $SpaceKey)
                if ($TenantId) { return $null }
                if ($SpaceKey) { return $null }
                return @()
            }
            Mock New-ConfluenceSpace {
                [PSCustomObject]@{
                    Id         = 'space-123'
                    Key        = 'FAILTEST'
                    Name       = 'Fail Test Client'
                    HomepageId = 'homepage-456'
                }
            }
            Mock Set-ConfluencePage { }
            Mock Set-ConfluenceTenantMapping { }
            Mock ConvertTo-ConfluenceClientHomepage { return '{"version":1,"type":"doc","content":[]}' }
            Mock Get-ConfluenceBaseURL { return 'https://example.atlassian.net' }
            Mock Search-Confluence { throw "API Error: Network timeout" }
        }

        It 'Space creation succeeds when index update fails' {
            # Should not throw despite index update failing
            $result = New-ConfluenceClientSpace -SpaceKey 'FAILTEST' -ClientName 'Fail Test Client' -TenantId 'fail-tenant'
            $result | Should Not Be $null
            $result.SpaceKey | Should Be 'FAILTEST'
        }

        It 'Returns complete space object when index update fails' {
            $result = New-ConfluenceClientSpace -SpaceKey 'FAILTEST' -ClientName 'Fail Test Client' -TenantId 'fail-tenant'
            $result.Id | Should Be 'space-123'
            $result.Name | Should Be 'Fail Test Client'
            $result.HomepageId | Should Be 'homepage-456'
            $result.TenantId | Should Be 'fail-tenant'
        }

        It 'Emits warning when index update fails' {
            $warningOutput = New-ConfluenceClientSpace -SpaceKey 'FAILTEST' -ClientName 'Fail Test Client' -TenantId 'fail-tenant' 3>&1
            $warnings = $warningOutput | Where-Object { $_ -is [System.Management.Automation.WarningRecord] }
            $warnings.Count | Should BeGreaterThan 0
        }

        It 'Warning mentions CLIENTS-INDEX' {
            $warningOutput = New-ConfluenceClientSpace -SpaceKey 'FAILTEST' -ClientName 'Fail Test Client' -TenantId 'fail-tenant' 3>&1
            $warnings = $warningOutput | Where-Object { $_ -is [System.Management.Automation.WarningRecord] }
            $warningText = ($warnings | ForEach-Object { $_.Message }) -join ' '
            $warningText | Should Match 'CLIENTS-INDEX'
        }
    }

    Context 'Index Update Is Non-Blocking' {
        BeforeEach {
            Mock Get-ConfluenceSpace { return $null }
            Mock Get-ConfluenceTenantMapping {
                param($TenantId, $SpaceKey)
                if ($TenantId) { return $null }
                if ($SpaceKey) { return $null }
                return @()
            }
            Mock New-ConfluenceSpace {
                [PSCustomObject]@{
                    Id         = 'space-123'
                    Key        = 'NONBLOCK'
                    Name       = 'Non-Block Test'
                    HomepageId = 'homepage-456'
                }
            }
            Mock Set-ConfluencePage { }
            Mock Set-ConfluenceTenantMapping { }
            Mock ConvertTo-ConfluenceClientHomepage { return '{"version":1,"type":"doc","content":[]}' }
            Mock Get-ConfluenceBaseURL { throw "Configuration error" }
        }

        It 'Space creation completes when base URL is not configured' {
            $result = New-ConfluenceClientSpace -SpaceKey 'NONBLOCK' -ClientName 'Non-Block Test' -TenantId 'nonblock-tenant'
            $result.SpaceKey | Should Be 'NONBLOCK'
        }
    }
}
