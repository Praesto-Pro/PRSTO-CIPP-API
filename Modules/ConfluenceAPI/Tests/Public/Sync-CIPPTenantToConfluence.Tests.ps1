$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleRoot = Split-Path -Parent (Split-Path -Parent $here)
$publicDir = Join-Path $moduleRoot 'Public'

Describe 'Sync-CIPPTenantToConfluence' {
    BeforeAll {
        # Define stub functions for all dependencies
        function Get-ConfluenceTenantMapping { param($TenantId) }
        function Sync-ConfluenceUserInventory { param($SpaceKey, $Users) }
        function Sync-ConfluenceEndpointInventory { param($SpaceKey, $Endpoints) }
        function Sync-ConfluenceLicenseReport { param($SpaceKey, $Licenses) }
        function Sync-ConfluenceMFAReport { param($SpaceKey, $MFAData) }
        function Sync-ConfluenceTeamsInventory { param($SpaceKey, $TeamsData) }
        function Sync-ConfluenceSharePointInventory { param($SpaceKey, $SharePointData) }

        # Dot-source function under test
        . "$publicDir\Sync-CIPPTenantToConfluence.ps1"
    }

    Context 'Tenant Resolution (AC2)' {
        BeforeEach {
            Mock Get-ConfluenceTenantMapping {
                [PSCustomObject]@{ TenantId = $TenantId; SpaceKey = 'CONTOSO'; SpaceName = 'Contoso Corp' }
            }
            Mock Sync-ConfluenceUserInventory { [PSCustomObject]@{ Id = 'user-page-123'; Title = 'User Inventory' } }
        }

        It 'Resolves tenant to space via Get-ConfluenceTenantMapping' {
            Sync-CIPPTenantToConfluence -TenantId 'test-tenant' -Users @()
            Assert-MockCalled Get-ConfluenceTenantMapping -Scope It -Times 1 -ParameterFilter {
                $TenantId -eq 'test-tenant'
            }
        }

        It 'Throws error when no mapping exists' {
            Mock Get-ConfluenceTenantMapping { return $null }
            { Sync-CIPPTenantToConfluence -TenantId 'unknown-tenant' -Users @() } | Should Throw
        }

        It 'Error message suggests Set-ConfluenceTenantMapping' {
            Mock Get-ConfluenceTenantMapping { return $null }
            try {
                Sync-CIPPTenantToConfluence -TenantId 'unknown-tenant' -Users @()
            }
            catch {
                $_.Exception.Message | Should Match 'Set-ConfluenceTenantMapping'
            }
        }

        It 'Returns Failed status when mapping not found' {
            Mock Get-ConfluenceTenantMapping { return $null }
            $errorThrown = $false
            try {
                Sync-CIPPTenantToConfluence -TenantId 'unknown-tenant' -Users @()
            }
            catch {
                $errorThrown = $true
                $_.FullyQualifiedErrorId | Should Match 'TenantMappingNotFound'
            }
            $errorThrown | Should Be $true
        }
    }

    Context 'Sync Operations (AC1, AC7)' {
        BeforeEach {
            Mock Get-ConfluenceTenantMapping {
                [PSCustomObject]@{ TenantId = 'test-tenant'; SpaceKey = 'TEST'; SpaceName = 'Test' }
            }
            Mock Sync-ConfluenceUserInventory { [PSCustomObject]@{ Id = 'user-123'; Title = 'User Inventory' } }
            Mock Sync-ConfluenceEndpointInventory { [PSCustomObject]@{ Id = 'endpoint-123'; Title = 'Endpoint Inventory' } }
            Mock Sync-ConfluenceLicenseReport { [PSCustomObject]@{ Id = 'license-123'; Title = 'License Report' } }
            Mock Sync-ConfluenceMFAReport { [PSCustomObject]@{ Id = 'mfa-123'; Title = 'MFA Status' } }
            Mock Sync-ConfluenceTeamsInventory { [PSCustomObject]@{ Id = 'teams-123'; Title = 'Teams Inventory' } }
            Mock Sync-ConfluenceSharePointInventory { [PSCustomObject]@{ Id = 'sp-123'; Title = 'SharePoint Inventory' } }
        }

        It 'Calls all 6 sync functions when all data provided' {
            Sync-CIPPTenantToConfluence -TenantId 'test' -Users @() -Endpoints @() -Licenses @() -MFAData @() -Teams @() -SharePointSites @()
            Assert-MockCalled Sync-ConfluenceUserInventory -Scope It -Times 1
            Assert-MockCalled Sync-ConfluenceEndpointInventory -Scope It -Times 1
            Assert-MockCalled Sync-ConfluenceLicenseReport -Scope It -Times 1
            Assert-MockCalled Sync-ConfluenceMFAReport -Scope It -Times 1
            Assert-MockCalled Sync-ConfluenceTeamsInventory -Scope It -Times 1
            Assert-MockCalled Sync-ConfluenceSharePointInventory -Scope It -Times 1
        }

        It 'Only calls sync functions for provided data types' {
            Sync-CIPPTenantToConfluence -TenantId 'test' -Users @() -Endpoints @()
            Assert-MockCalled Sync-ConfluenceUserInventory -Scope It -Times 1
            Assert-MockCalled Sync-ConfluenceEndpointInventory -Scope It -Times 1
            Assert-MockCalled Sync-ConfluenceLicenseReport -Scope It -Times 0
            Assert-MockCalled Sync-ConfluenceMFAReport -Scope It -Times 0
            Assert-MockCalled Sync-ConfluenceTeamsInventory -Scope It -Times 0
            Assert-MockCalled Sync-ConfluenceSharePointInventory -Scope It -Times 0
        }

        It 'Passes SpaceKey to sync functions' {
            $script:capturedSpaceKey = $null
            Mock Sync-ConfluenceUserInventory {
                param($SpaceKey, $Users)
                $script:capturedSpaceKey = $SpaceKey
                [PSCustomObject]@{ Id = 'user-123'; Title = 'User Inventory' }
            }
            Sync-CIPPTenantToConfluence -TenantId 'test' -Users @()
            $script:capturedSpaceKey | Should Be 'TEST'
        }

        It 'Returns SyncResults array with all data types' {
            $result = Sync-CIPPTenantToConfluence -TenantId 'test' -Users @() -Endpoints @() -Licenses @() -MFAData @() -Teams @() -SharePointSites @()
            $result.SyncResults.Count | Should Be 6
        }

        It 'Skips data types not provided' {
            $result = Sync-CIPPTenantToConfluence -TenantId 'test' -Users @()
            $skipped = $result.SyncResults | Where-Object { $_.Status -eq 'Skipped' }
            $skipped.Count | Should Be 5
        }
    }

    Context 'Partial Failure Handling (AC5)' {
        BeforeEach {
            Mock Get-ConfluenceTenantMapping {
                [PSCustomObject]@{ TenantId = 'test'; SpaceKey = 'TEST'; SpaceName = 'Test' }
            }
            Mock Sync-ConfluenceUserInventory { [PSCustomObject]@{ Id = 'user-123'; Title = 'User Inventory' } }
            Mock Sync-ConfluenceEndpointInventory { throw "API Error" }
            Mock Sync-ConfluenceLicenseReport { [PSCustomObject]@{ Id = 'license-123'; Title = 'License Report' } }
        }

        It 'Continues syncing after failure' {
            $result = Sync-CIPPTenantToConfluence -TenantId 'test' -Users @() -Endpoints @() -Licenses @()
            Assert-MockCalled Sync-ConfluenceUserInventory -Scope It -Times 1
            Assert-MockCalled Sync-ConfluenceEndpointInventory -Scope It -Times 1
            Assert-MockCalled Sync-ConfluenceLicenseReport -Scope It -Times 1
        }

        It 'Returns PartialFailure status' {
            $result = Sync-CIPPTenantToConfluence -TenantId 'test' -Users @() -Endpoints @() -Licenses @()
            $result.OverallStatus | Should Be 'PartialFailure'
        }

        It 'Includes error details in result' {
            $result = Sync-CIPPTenantToConfluence -TenantId 'test' -Users @() -Endpoints @() -Licenses @()
            $result.ErrorCount | Should Be 1
            $result.Errors[0].DataType | Should Be 'EndpointInventory'
        }

        It 'Records failed status in SyncResults' {
            $result = Sync-CIPPTenantToConfluence -TenantId 'test' -Users @() -Endpoints @() -Licenses @()
            $failed = @($result.SyncResults | Where-Object { $_.Status -eq 'Failed' })
            $failed.Count | Should Be 1
            $failed[0].DataType | Should Be 'EndpointInventory'
        }

        It 'Includes error message in failed result' {
            $result = Sync-CIPPTenantToConfluence -TenantId 'test' -Users @() -Endpoints @() -Licenses @()
            $failed = @($result.SyncResults | Where-Object { $_.Status -eq 'Failed' })
            $failed[0].Message | Should Match 'API Error'
        }
    }

    Context 'Result Object (AC6)' {
        BeforeEach {
            Mock Get-ConfluenceTenantMapping {
                [PSCustomObject]@{ TenantId = 'test'; SpaceKey = 'TEST'; SpaceName = 'Test' }
            }
            Mock Sync-ConfluenceUserInventory { [PSCustomObject]@{ Id = 'user-123'; Title = 'User Inventory' } }
        }

        It 'Returns PSCustomObject with TenantId' {
            $result = Sync-CIPPTenantToConfluence -TenantId 'test' -Users @()
            $result.TenantId | Should Be 'test'
        }

        It 'Returns PSCustomObject with SpaceKey' {
            $result = Sync-CIPPTenantToConfluence -TenantId 'test' -Users @()
            $result.SpaceKey | Should Be 'TEST'
        }

        It 'Returns PSCustomObject with OverallStatus' {
            $result = Sync-CIPPTenantToConfluence -TenantId 'test' -Users @()
            $result.OverallStatus | Should Be 'Success'
        }

        It 'Returns PSCustomObject with SyncResults' {
            $result = Sync-CIPPTenantToConfluence -TenantId 'test' -Users @()
            $result.SyncResults | Should Not Be $null
        }

        It 'Returns PSCustomObject with StartTime' {
            $result = Sync-CIPPTenantToConfluence -TenantId 'test' -Users @()
            $result.StartTime | Should Match '\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} UTC'
        }

        It 'Returns PSCustomObject with EndTime' {
            $result = Sync-CIPPTenantToConfluence -TenantId 'test' -Users @()
            $result.EndTime | Should Match '\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} UTC'
        }

        It 'Includes duration in result' {
            $result = Sync-CIPPTenantToConfluence -TenantId 'test' -Users @()
            $result.Duration | Should Match '\d{2}:\d{2}:\d{2}'
        }

        It 'Includes counts in result' {
            $result = Sync-CIPPTenantToConfluence -TenantId 'test' -Users @()
            $result.SuccessCount | Should Be 1
            $result.FailedCount | Should Be 0
            $result.SkippedCount | Should Be 5
            $result.ErrorCount | Should Be 0
        }

        It 'Returns Success status when all syncs succeed' {
            $result = Sync-CIPPTenantToConfluence -TenantId 'test' -Users @()
            $result.OverallStatus | Should Be 'Success'
        }

        It 'Includes PageId in successful SyncResults' {
            $result = Sync-CIPPTenantToConfluence -TenantId 'test' -Users @()
            $success = @($result.SyncResults | Where-Object { $_.Status -eq 'Success' })
            $success[0].PageId | Should Be 'user-123'
        }
    }

    Context 'WhatIf Support (AC4)' {
        BeforeEach {
            Mock Get-ConfluenceTenantMapping {
                [PSCustomObject]@{ TenantId = 'test'; SpaceKey = 'TEST'; SpaceName = 'Test' }
            }
            Mock Sync-ConfluenceUserInventory { [PSCustomObject]@{ Id = 'user-123'; Title = 'User Inventory' } }
            Mock Sync-ConfluenceEndpointInventory { [PSCustomObject]@{ Id = 'endpoint-123'; Title = 'Endpoint Inventory' } }
        }

        It 'Does not call sync functions with WhatIf' {
            Sync-CIPPTenantToConfluence -TenantId 'test' -Users @() -Endpoints @() -WhatIf
            Assert-MockCalled Sync-ConfluenceUserInventory -Scope It -Times 0
            Assert-MockCalled Sync-ConfluenceEndpointInventory -Scope It -Times 0
        }

        It 'Returns WhatIf status' {
            $result = Sync-CIPPTenantToConfluence -TenantId 'test' -Users @() -WhatIf
            $result.OverallStatus | Should Be 'WhatIf'
        }

        It 'Returns WhatIf status in SyncResults' {
            $result = Sync-CIPPTenantToConfluence -TenantId 'test' -Users @() -WhatIf
            $whatIfResults = @($result.SyncResults | Where-Object { $_.Status -eq 'WhatIf' })
            $whatIfResults.Count | Should Be 1
        }

        It 'Still resolves tenant mapping with WhatIf' {
            Sync-CIPPTenantToConfluence -TenantId 'test' -Users @() -WhatIf
            Assert-MockCalled Get-ConfluenceTenantMapping -Scope It -Times 1
        }
    }

    Context 'Verbose Logging (AC3)' {
        BeforeEach {
            Mock Get-ConfluenceTenantMapping {
                [PSCustomObject]@{ TenantId = 'test'; SpaceKey = 'TEST'; SpaceName = 'Test' }
            }
            Mock Sync-ConfluenceUserInventory { [PSCustomObject]@{ Id = 'user-123'; Title = 'User Inventory' } }
        }

        It 'Writes verbose messages during execution' {
            $verboseOutput = Sync-CIPPTenantToConfluence -TenantId 'test' -Users @() -Verbose 4>&1
            $verboseMessages = $verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }
            $verboseMessages.Count | Should BeGreaterThan 0
        }

        It 'Logs tenant resolution' {
            $verboseOutput = Sync-CIPPTenantToConfluence -TenantId 'test' -Users @() -Verbose 4>&1
            $verboseText = ($verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }).Message -join ' '
            $verboseText | Should Match 'Resolving tenant'
        }

        It 'Logs sync completion' {
            $verboseOutput = Sync-CIPPTenantToConfluence -TenantId 'test' -Users @() -Verbose 4>&1
            $verboseText = ($verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }).Message -join ' '
            $verboseText | Should Match 'Sync completed'
        }

        It 'Logs skipped data types' {
            $verboseOutput = Sync-CIPPTenantToConfluence -TenantId 'test' -Users @() -Verbose 4>&1
            $verboseText = ($verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }).Message -join ' '
            $verboseText | Should Match 'Skipping'
        }
    }

    Context 'Empty Data Handling (AC8)' {
        BeforeEach {
            Mock Get-ConfluenceTenantMapping {
                [PSCustomObject]@{ TenantId = 'test'; SpaceKey = 'TEST'; SpaceName = 'Test' }
            }
            Mock Sync-ConfluenceUserInventory { [PSCustomObject]@{ Id = 'user-123'; Title = 'User Inventory' } }
        }

        It 'Calls sync function when empty array is provided' {
            Sync-CIPPTenantToConfluence -TenantId 'test' -Users @()
            Assert-MockCalled Sync-ConfluenceUserInventory -Scope It -Times 1
        }

        It 'Passes empty array to sync function' {
            $script:capturedUsers = 'not-set'
            Mock Sync-ConfluenceUserInventory {
                param($SpaceKey, $Users)
                $script:capturedUsers = $Users
                [PSCustomObject]@{ Id = 'user-123'; Title = 'User Inventory' }
            }
            Sync-CIPPTenantToConfluence -TenantId 'test' -Users @()
            $script:capturedUsers.Count | Should Be 0
        }

        It 'Handles null array explicitly provided' {
            $script:capturedUsers = 'not-set'
            Mock Sync-ConfluenceUserInventory {
                param($SpaceKey, $Users)
                $script:capturedUsers = $Users
                [PSCustomObject]@{ Id = 'user-123'; Title = 'User Inventory' }
            }
            Sync-CIPPTenantToConfluence -TenantId 'test' -Users $null
            # Function should still be called because parameter was bound
            Assert-MockCalled Sync-ConfluenceUserInventory -Scope It -Times 1
        }
    }

    Context 'Overall Status Determination' {
        BeforeEach {
            Mock Get-ConfluenceTenantMapping {
                [PSCustomObject]@{ TenantId = 'test'; SpaceKey = 'TEST'; SpaceName = 'Test' }
            }
        }

        It 'Returns NoOperation when no data types provided' {
            # This would skip all sync operations
            Mock Sync-ConfluenceUserInventory { }
            $result = Sync-CIPPTenantToConfluence -TenantId 'test'
            $result.OverallStatus | Should Be 'NoOperation'
        }

        It 'Returns Failed when all sync operations fail' {
            Mock Sync-ConfluenceUserInventory { throw "Error" }
            Mock Sync-ConfluenceEndpointInventory { throw "Error" }
            $result = Sync-CIPPTenantToConfluence -TenantId 'test' -Users @() -Endpoints @()
            $result.OverallStatus | Should Be 'Failed'
        }

        It 'Returns PartialFailure when some fail and some succeed' {
            Mock Sync-ConfluenceUserInventory { [PSCustomObject]@{ Id = 'user-123'; Title = 'User Inventory' } }
            Mock Sync-ConfluenceEndpointInventory { throw "Error" }
            $result = Sync-CIPPTenantToConfluence -TenantId 'test' -Users @() -Endpoints @()
            $result.OverallStatus | Should Be 'PartialFailure'
        }
    }

    Context 'Data Type Parameter Mapping' {
        BeforeEach {
            Mock Get-ConfluenceTenantMapping {
                [PSCustomObject]@{ TenantId = 'test'; SpaceKey = 'TEST'; SpaceName = 'Test' }
            }
            Mock Sync-ConfluenceUserInventory { [PSCustomObject]@{ Id = 'user-123' } }
            Mock Sync-ConfluenceEndpointInventory { [PSCustomObject]@{ Id = 'endpoint-123' } }
            Mock Sync-ConfluenceLicenseReport { [PSCustomObject]@{ Id = 'license-123' } }
            Mock Sync-ConfluenceMFAReport { [PSCustomObject]@{ Id = 'mfa-123' } }
            Mock Sync-ConfluenceTeamsInventory { [PSCustomObject]@{ Id = 'teams-123' } }
            Mock Sync-ConfluenceSharePointInventory { [PSCustomObject]@{ Id = 'sp-123' } }
        }

        It 'Passes Users parameter to Sync-ConfluenceUserInventory' {
            $script:capturedParam = $null
            Mock Sync-ConfluenceUserInventory {
                param($SpaceKey, $Users)
                $script:capturedParam = $Users
                [PSCustomObject]@{ Id = 'user-123' }
            }
            $testUsers = @(@{ Name = 'Test User' })
            Sync-CIPPTenantToConfluence -TenantId 'test' -Users $testUsers
            $script:capturedParam.Count | Should Be 1
        }

        It 'Passes TeamsData parameter to Sync-ConfluenceTeamsInventory' {
            $script:capturedParam = $null
            Mock Sync-ConfluenceTeamsInventory {
                param($SpaceKey, $TeamsData)
                $script:capturedParam = $TeamsData
                [PSCustomObject]@{ Id = 'teams-123' }
            }
            $testTeams = @(@{ Name = 'Test Team' })
            Sync-CIPPTenantToConfluence -TenantId 'test' -Teams $testTeams
            $script:capturedParam.Count | Should Be 1
        }

        It 'Passes SharePointData parameter to Sync-ConfluenceSharePointInventory' {
            $script:capturedParam = $null
            Mock Sync-ConfluenceSharePointInventory {
                param($SpaceKey, $SharePointData)
                $script:capturedParam = $SharePointData
                [PSCustomObject]@{ Id = 'sp-123' }
            }
            $testSites = @(@{ Name = 'Test Site' })
            Sync-CIPPTenantToConfluence -TenantId 'test' -SharePointSites $testSites
            $script:capturedParam.Count | Should Be 1
        }
    }

    Context 'Error Recording' {
        BeforeEach {
            Mock Get-ConfluenceTenantMapping {
                [PSCustomObject]@{ TenantId = 'test'; SpaceKey = 'TEST'; SpaceName = 'Test' }
            }
            Mock Sync-ConfluenceUserInventory { throw "User sync error" }
            Mock Sync-ConfluenceEndpointInventory { throw "Endpoint sync error" }
        }

        It 'Records multiple errors when multiple syncs fail' {
            $result = Sync-CIPPTenantToConfluence -TenantId 'test' -Users @() -Endpoints @()
            $result.ErrorCount | Should Be 2
        }

        It 'Includes timestamp in error records' {
            $result = Sync-CIPPTenantToConfluence -TenantId 'test' -Users @()
            $result.Errors[0].Timestamp | Should Match '\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}'
        }

        It 'Includes error message in error records' {
            $result = Sync-CIPPTenantToConfluence -TenantId 'test' -Users @()
            $result.Errors[0].Error | Should Match 'User sync error'
        }
    }
}
