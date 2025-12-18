$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleRoot = Split-Path -Parent (Split-Path -Parent $here)
$publicDir = Join-Path $moduleRoot 'Public'
$privateDir = Join-Path $moduleRoot 'Private'

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

        # Stub for sync configuration (used by Invoke-WithRetry and incremental sync)
        function Get-ConfluenceSyncConfiguration {
            [PSCustomObject]@{
                RetryAttempts         = 3
                RetryDelaySeconds     = 1
                EnableIncrementalSync = $false
            }
        }

        # Load private helper functions
        . "$privateDir\Invoke-WithRetry.ps1"
        . "$privateDir\Get-DataHash.ps1"
        . "$privateDir\Get-SyncStateKey.ps1"
        . "$privateDir\Test-DataChanged.ps1"
        . "$privateDir\Add-ConfluenceSyncLog.ps1"

        # Initialize sync state cache and log cache
        $script:SyncStateCache = @{}
        $script:SyncLogCache = @{}

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

    Context 'Retry Logic Integration (Story 8.3)' {
        BeforeEach {
            Mock Get-ConfluenceTenantMapping {
                [PSCustomObject]@{ TenantId = 'test'; SpaceKey = 'TEST'; SpaceName = 'Test' }
            }
        }

        It 'Uses Invoke-WithRetry wrapper for sync operations' {
            # Verify that sync operations go through retry logic by checking
            # that transient errors are retried
            $script:attemptCount = 0
            Mock Sync-ConfluenceUserInventory {
                $script:attemptCount++
                if ($script:attemptCount -lt 2) {
                    throw "Server error (500)"
                }
                [PSCustomObject]@{ Id = 'user-123'; Title = 'User Inventory' }
            }

            $result = Sync-CIPPTenantToConfluence -TenantId 'test' -Users @()
            $result.OverallStatus | Should Be 'Success'
            $script:attemptCount | Should Be 2
        }

        It 'Retries on 5xx server error and succeeds' {
            $script:attemptCount = 0
            Mock Sync-ConfluenceUserInventory {
                $script:attemptCount++
                if ($script:attemptCount -lt 2) {
                    throw "Service unavailable (503)"
                }
                [PSCustomObject]@{ Id = 'user-123'; Title = 'User Inventory' }
            }

            $result = Sync-CIPPTenantToConfluence -TenantId 'test' -Users @()
            $result.OverallStatus | Should Be 'Success'
        }

        It 'Retries on 429 rate limit and succeeds' {
            $script:attemptCount = 0
            Mock Sync-ConfluenceUserInventory {
                $script:attemptCount++
                if ($script:attemptCount -lt 2) {
                    throw "Rate limit exceeded (429)"
                }
                [PSCustomObject]@{ Id = 'user-123'; Title = 'User Inventory' }
            }

            $result = Sync-CIPPTenantToConfluence -TenantId 'test' -Users @()
            $result.OverallStatus | Should Be 'Success'
        }

        It 'Retries on network timeout and succeeds' {
            $script:attemptCount = 0
            Mock Sync-ConfluenceUserInventory {
                $script:attemptCount++
                if ($script:attemptCount -lt 2) {
                    throw "Connection timed out"
                }
                [PSCustomObject]@{ Id = 'user-123'; Title = 'User Inventory' }
            }

            $result = Sync-CIPPTenantToConfluence -TenantId 'test' -Users @()
            $result.OverallStatus | Should Be 'Success'
        }

        It 'Does NOT retry on 4xx client error' {
            $script:attemptCount = 0
            Mock Sync-ConfluenceUserInventory {
                $script:attemptCount++
                throw "Bad request (400)"
            }

            $result = Sync-CIPPTenantToConfluence -TenantId 'test' -Users @()
            $result.OverallStatus | Should Be 'Failed'
            $script:attemptCount | Should Be 1
        }

        It 'Does NOT retry on 404 not found' {
            $script:attemptCount = 0
            Mock Sync-ConfluenceUserInventory {
                $script:attemptCount++
                throw "Not found (404)"
            }

            $result = Sync-CIPPTenantToConfluence -TenantId 'test' -Users @()
            $result.OverallStatus | Should Be 'Failed'
            $script:attemptCount | Should Be 1
        }

        It 'Fails after all retries exhausted' {
            Mock Sync-ConfluenceUserInventory {
                throw "Server error (500)"
            }

            $result = Sync-CIPPTenantToConfluence -TenantId 'test' -Users @()
            $result.OverallStatus | Should Be 'Failed'
        }

        It 'Error includes retry information when retries exhausted' {
            Mock Sync-ConfluenceUserInventory {
                throw "Server error (500)"
            }

            $result = Sync-CIPPTenantToConfluence -TenantId 'test' -Users @()
            $failed = @($result.SyncResults | Where-Object { $_.Status -eq 'Failed' })
            $failed[0].Message | Should Match 'retries'
        }

        It 'Continues to next data type after retry failure' {
            Mock Sync-ConfluenceUserInventory { throw "Server error (500)" }
            Mock Sync-ConfluenceEndpointInventory { [PSCustomObject]@{ Id = 'endpoint-123' } }

            $result = Sync-CIPPTenantToConfluence -TenantId 'test' -Users @() -Endpoints @()
            Assert-MockCalled Sync-ConfluenceEndpointInventory -Scope It -Times 1
            $result.OverallStatus | Should Be 'PartialFailure'
        }

        It 'WhatIf does not invoke retry logic' {
            $script:attemptCount = 0
            Mock Sync-ConfluenceUserInventory {
                $script:attemptCount++
                [PSCustomObject]@{ Id = 'user-123' }
            }

            $result = Sync-CIPPTenantToConfluence -TenantId 'test' -Users @() -WhatIf
            $script:attemptCount | Should Be 0
            $result.OverallStatus | Should Be 'WhatIf'
        }

        It 'Reports success after transient failure recovery' {
            $script:attemptCount = 0
            Mock Sync-ConfluenceUserInventory {
                $script:attemptCount++
                if ($script:attemptCount -lt 3) {
                    throw "Confluence server error"
                }
                [PSCustomObject]@{ Id = 'user-123'; Title = 'User Inventory' }
            }

            $result = Sync-CIPPTenantToConfluence -TenantId 'test' -Users @()
            $success = @($result.SyncResults | Where-Object { $_.Status -eq 'Success' })
            $success.Count | Should Be 1
            $success[0].PageId | Should Be 'user-123'
        }

        It 'Writes verbose messages during retry' {
            $script:attemptCount = 0
            Mock Sync-ConfluenceUserInventory {
                $script:attemptCount++
                if ($script:attemptCount -lt 2) {
                    throw "Server error (500)"
                }
                [PSCustomObject]@{ Id = 'user-123'; Title = 'User Inventory' }
            }

            $verboseOutput = Sync-CIPPTenantToConfluence -TenantId 'test' -Users @() -Verbose 4>&1
            $verboseMessages = $verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }
            $verboseText = ($verboseMessages | ForEach-Object { $_.Message }) -join ' '
            # Should contain retry-related messages
            $verboseText | Should Match 'sync'
        }

        It 'Includes RetryCount of 0 when no retries needed' {
            Mock Sync-ConfluenceUserInventory {
                [PSCustomObject]@{ Id = 'user-123'; Title = 'User Inventory' }
            }

            $result = Sync-CIPPTenantToConfluence -TenantId 'test' -Users @()
            $success = @($result.SyncResults | Where-Object { $_.Status -eq 'Success' })
            $success[0].RetryCount | Should Be 0
        }

        It 'Includes RetryCount showing retries on transient failure recovery' {
            $script:attemptCount = 0
            Mock Sync-ConfluenceUserInventory {
                $script:attemptCount++
                if ($script:attemptCount -lt 3) {
                    throw "Server error (500)"
                }
                [PSCustomObject]@{ Id = 'user-123'; Title = 'User Inventory' }
            }

            $result = Sync-CIPPTenantToConfluence -TenantId 'test' -Users @()
            $success = @($result.SyncResults | Where-Object { $_.Status -eq 'Success' })
            # 3 attempts means 2 retries
            $success[0].RetryCount | Should Be 2
        }

        It 'SyncResults include RetryCount property for all statuses' {
            Mock Sync-ConfluenceUserInventory {
                [PSCustomObject]@{ Id = 'user-123' }
            }

            $result = Sync-CIPPTenantToConfluence -TenantId 'test' -Users @()
            # Skipped results should have RetryCount = null
            $skipped = @($result.SyncResults | Where-Object { $_.Status -eq 'Skipped' })
            ($skipped[0].PSObject.Properties.Name -contains 'RetryCount') | Should Be $true
        }
    }

    Context 'Incremental Sync Support (Story 8.4)' {
        BeforeEach {
            Mock Get-ConfluenceTenantMapping {
                [PSCustomObject]@{ TenantId = 'test'; SpaceKey = 'TEST'; SpaceName = 'Test' }
            }
            Mock Sync-ConfluenceUserInventory { [PSCustomObject]@{ Id = 'user-123'; Title = 'User Inventory' } }
            Mock Sync-ConfluenceEndpointInventory { [PSCustomObject]@{ Id = 'endpoint-123'; Title = 'Endpoint Inventory' } }

            # Reset state cache before each test
            $script:SyncStateCache = @{}
        }

        It 'Syncs all data when EnableIncrementalSync is false' {
            Mock Get-ConfluenceSyncConfiguration {
                [PSCustomObject]@{
                    RetryAttempts         = 3
                    RetryDelaySeconds     = 1
                    EnableIncrementalSync = $false
                }
            }

            $users = @([PSCustomObject]@{ Name = 'User1' })
            Sync-CIPPTenantToConfluence -TenantId 'test' -Users $users
            Sync-CIPPTenantToConfluence -TenantId 'test' -Users $users

            # Both calls should sync because incremental is disabled
            Assert-MockCalled Sync-ConfluenceUserInventory -Scope It -Times 2
        }

        It 'Skips unchanged data when EnableIncrementalSync is true' {
            Mock Get-ConfluenceSyncConfiguration {
                [PSCustomObject]@{
                    RetryAttempts         = 3
                    RetryDelaySeconds     = 1
                    EnableIncrementalSync = $true
                }
            }

            $users = @([PSCustomObject]@{ Name = 'User1' })

            # First sync - should sync
            $result1 = Sync-CIPPTenantToConfluence -TenantId 'test' -Users $users
            $result1.SyncResults[0].Status | Should Be 'Success'

            # Second sync with same data - should skip
            $result2 = Sync-CIPPTenantToConfluence -TenantId 'test' -Users $users
            $unchanged = @($result2.SyncResults | Where-Object { $_.Status -eq 'Unchanged' })
            $unchanged.Count | Should Be 1
        }

        It 'Syncs changed data even with incremental enabled' {
            Mock Get-ConfluenceSyncConfiguration {
                [PSCustomObject]@{
                    RetryAttempts         = 3
                    RetryDelaySeconds     = 1
                    EnableIncrementalSync = $true
                }
            }

            $users1 = @([PSCustomObject]@{ Name = 'Original' })
            $users2 = @([PSCustomObject]@{ Name = 'Changed' })

            # First sync
            Sync-CIPPTenantToConfluence -TenantId 'test' -Users $users1

            # Second sync with changed data - should sync
            $result = Sync-CIPPTenantToConfluence -TenantId 'test' -Users $users2
            $result.SyncResults[0].Status | Should Be 'Success'
        }

        It 'First sync always runs (no previous state)' {
            Mock Get-ConfluenceSyncConfiguration {
                [PSCustomObject]@{
                    RetryAttempts         = 3
                    RetryDelaySeconds     = 1
                    EnableIncrementalSync = $true
                }
            }

            $users = @([PSCustomObject]@{ Name = 'Test' })
            $result = Sync-CIPPTenantToConfluence -TenantId 'new-tenant' -Users $users
            $result.SyncResults[0].Status | Should Be 'Success'
        }

        It 'SyncResult includes Unchanged status' {
            Mock Get-ConfluenceSyncConfiguration {
                [PSCustomObject]@{
                    RetryAttempts         = 3
                    RetryDelaySeconds     = 1
                    EnableIncrementalSync = $true
                }
            }

            $users = @([PSCustomObject]@{ Name = 'Test' })

            # First sync
            Sync-CIPPTenantToConfluence -TenantId 'test' -Users $users

            # Second sync
            $result = Sync-CIPPTenantToConfluence -TenantId 'test' -Users $users
            $unchanged = @($result.SyncResults | Where-Object { $_.Status -eq 'Unchanged' })
            $unchanged[0].Message | Should Match 'unchanged'
        }

        It 'Overall status is Unchanged when all data unchanged' {
            Mock Get-ConfluenceSyncConfiguration {
                [PSCustomObject]@{
                    RetryAttempts         = 3
                    RetryDelaySeconds     = 1
                    EnableIncrementalSync = $true
                }
            }

            $users = @([PSCustomObject]@{ Name = 'Test' })

            # First sync
            Sync-CIPPTenantToConfluence -TenantId 'test' -Users $users

            # Second sync
            $result = Sync-CIPPTenantToConfluence -TenantId 'test' -Users $users
            $result.OverallStatus | Should Be 'Unchanged'
        }

        It 'Includes UnchangedCount in result' {
            Mock Get-ConfluenceSyncConfiguration {
                [PSCustomObject]@{
                    RetryAttempts         = 3
                    RetryDelaySeconds     = 1
                    EnableIncrementalSync = $true
                }
            }

            $users = @([PSCustomObject]@{ Name = 'Test' })

            # First sync
            Sync-CIPPTenantToConfluence -TenantId 'test' -Users $users

            # Second sync
            $result = Sync-CIPPTenantToConfluence -TenantId 'test' -Users $users
            $result.UnchangedCount | Should Be 1
        }

        It 'WhatIf checks change detection but does not update state' {
            Mock Get-ConfluenceSyncConfiguration {
                [PSCustomObject]@{
                    RetryAttempts         = 3
                    RetryDelaySeconds     = 1
                    EnableIncrementalSync = $true
                }
            }

            $users = @([PSCustomObject]@{ Name = 'Test' })

            # WhatIf sync - should not store state
            Sync-CIPPTenantToConfluence -TenantId 'test' -Users $users -WhatIf

            # Actual sync - should still run because state wasn't stored
            $result = Sync-CIPPTenantToConfluence -TenantId 'test' -Users $users
            $result.SyncResults[0].Status | Should Be 'Success'
        }

        It 'State updated after successful sync' {
            Mock Get-ConfluenceSyncConfiguration {
                [PSCustomObject]@{
                    RetryAttempts         = 3
                    RetryDelaySeconds     = 1
                    EnableIncrementalSync = $true
                }
            }

            $users = @([PSCustomObject]@{ Name = 'Test' })

            # First sync
            Sync-CIPPTenantToConfluence -TenantId 'test' -Users $users

            # Check state was stored
            $stateKey = 'test|UserInventory'
            $script:SyncStateCache.ContainsKey($stateKey) | Should Be $true
            $script:SyncStateCache[$stateKey].Hash | Should Not Be $null
            $script:SyncStateCache[$stateKey].PageId | Should Be 'user-123'
        }

        It 'Multiple data types tracked independently' {
            Mock Get-ConfluenceSyncConfiguration {
                [PSCustomObject]@{
                    RetryAttempts         = 3
                    RetryDelaySeconds     = 1
                    EnableIncrementalSync = $true
                }
            }

            $users = @([PSCustomObject]@{ Name = 'User1' })
            $endpoints = @([PSCustomObject]@{ Name = 'Endpoint1' })

            # First sync both
            Sync-CIPPTenantToConfluence -TenantId 'test' -Users $users -Endpoints $endpoints

            # Change users, keep endpoints same
            $users2 = @([PSCustomObject]@{ Name = 'User2' })

            $result = Sync-CIPPTenantToConfluence -TenantId 'test' -Users $users2 -Endpoints $endpoints

            # Users should be Success (changed), Endpoints should be Unchanged
            $userResult = @($result.SyncResults | Where-Object { $_.DataType -eq 'UserInventory' })
            $endpointResult = @($result.SyncResults | Where-Object { $_.DataType -eq 'EndpointInventory' })

            $userResult[0].Status | Should Be 'Success'
            $endpointResult[0].Status | Should Be 'Unchanged'
        }

        It 'Logs verbose messages for change detection' {
            Mock Get-ConfluenceSyncConfiguration {
                [PSCustomObject]@{
                    RetryAttempts         = 3
                    RetryDelaySeconds     = 1
                    EnableIncrementalSync = $true
                }
            }

            $users = @([PSCustomObject]@{ Name = 'Test' })

            # First sync
            Sync-CIPPTenantToConfluence -TenantId 'test' -Users $users

            # Second sync with verbose
            $verboseOutput = Sync-CIPPTenantToConfluence -TenantId 'test' -Users $users -Verbose 4>&1
            $verboseText = ($verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }).Message -join ' '
            $verboseText | Should Match 'unchanged'
        }

        It 'Unchanged result includes existing PageId from state' {
            Mock Get-ConfluenceSyncConfiguration {
                [PSCustomObject]@{
                    RetryAttempts         = 3
                    RetryDelaySeconds     = 1
                    EnableIncrementalSync = $true
                }
            }

            $users = @([PSCustomObject]@{ Name = 'Test' })

            # First sync
            Sync-CIPPTenantToConfluence -TenantId 'test' -Users $users

            # Second sync
            $result = Sync-CIPPTenantToConfluence -TenantId 'test' -Users $users
            $unchanged = @($result.SyncResults | Where-Object { $_.Status -eq 'Unchanged' })
            $unchanged[0].PageId | Should Be 'user-123'
        }

        It 'State not updated on sync failure' {
            Mock Get-ConfluenceSyncConfiguration {
                [PSCustomObject]@{
                    RetryAttempts         = 1
                    RetryDelaySeconds     = 1
                    EnableIncrementalSync = $true
                }
            }

            Mock Sync-ConfluenceUserInventory { throw "Sync error (400)" }

            $users = @([PSCustomObject]@{ Name = 'Test' })

            # Failed sync
            Sync-CIPPTenantToConfluence -TenantId 'test' -Users $users

            # State should not be stored
            $stateKey = 'test|UserInventory'
            $script:SyncStateCache.ContainsKey($stateKey) | Should Be $false
        }
    }

    Context 'Sync Execution Logging (Story 9.1)' {
        BeforeEach {
            Mock Get-ConfluenceTenantMapping {
                [PSCustomObject]@{ TenantId = 'test'; SpaceKey = 'TEST'; SpaceName = 'Test' }
            }
            Mock Sync-ConfluenceUserInventory { [PSCustomObject]@{ Id = 'user-123'; Title = 'User Inventory' } }
            Mock Sync-ConfluenceEndpointInventory { [PSCustomObject]@{ Id = 'endpoint-123'; Title = 'Endpoint Inventory' } }

            # Reset log cache for each test
            $script:SyncLogCache = @{}
        }

        It 'Calls Add-ConfluenceSyncLog after sync completes' {
            Sync-CIPPTenantToConfluence -TenantId 'test' -Users @()
            $script:SyncLogCache.Count | Should Be 1
        }

        It 'Logs sync result with correct TenantId' {
            Sync-CIPPTenantToConfluence -TenantId 'my-tenant' -Users @()
            $logEntry = $script:SyncLogCache.Values | Select-Object -First 1
            $logEntry.TenantId | Should Be 'my-tenant'
        }

        It 'Logs sync result with correct SpaceKey' {
            Sync-CIPPTenantToConfluence -TenantId 'test' -Users @()
            $logEntry = $script:SyncLogCache.Values | Select-Object -First 1
            $logEntry.SpaceKey | Should Be 'TEST'
        }

        It 'Logs sync result with correct OverallStatus' {
            Sync-CIPPTenantToConfluence -TenantId 'test' -Users @()
            $logEntry = $script:SyncLogCache.Values | Select-Object -First 1
            $logEntry.OverallStatus | Should Be 'Success'
        }

        It 'Logs sync result with correct SuccessCount' {
            Sync-CIPPTenantToConfluence -TenantId 'test' -Users @() -Endpoints @()
            $logEntry = $script:SyncLogCache.Values | Select-Object -First 1
            $logEntry.SuccessCount | Should Be 2
        }

        It 'Logs sync result with correct FailedCount' {
            Mock Sync-ConfluenceUserInventory { throw "Error" }
            Sync-CIPPTenantToConfluence -TenantId 'test' -Users @() -Endpoints @()
            $logEntry = $script:SyncLogCache.Values | Select-Object -First 1
            $logEntry.FailedCount | Should Be 1
        }

        It 'Logs sync result with Duration' {
            Sync-CIPPTenantToConfluence -TenantId 'test' -Users @()
            $logEntry = $script:SyncLogCache.Values | Select-Object -First 1
            $logEntry.Duration | Should Match '\d{2}:\d{2}:\d{2}'
        }

        It 'Logs sync result with SyncResults array' {
            Sync-CIPPTenantToConfluence -TenantId 'test' -Users @() -Endpoints @()
            $logEntry = $script:SyncLogCache.Values | Select-Object -First 1
            @($logEntry.SyncResults).Count | Should BeGreaterThan 0
        }

        It 'Logs sync result with Errors array on failure' {
            Mock Sync-ConfluenceUserInventory { throw "Sync error message" }
            Sync-CIPPTenantToConfluence -TenantId 'test' -Users @()
            $logEntry = $script:SyncLogCache.Values | Select-Object -First 1
            @($logEntry.Errors).Count | Should Be 1
            $logEntry.Errors[0].Error | Should Match 'Sync error message'
        }

        It 'Creates log entry even on WhatIf run' {
            Sync-CIPPTenantToConfluence -TenantId 'test' -Users @() -WhatIf
            $script:SyncLogCache.Count | Should Be 1
        }

        It 'Log entry on WhatIf has WhatIf OverallStatus' {
            Sync-CIPPTenantToConfluence -TenantId 'test' -Users @() -WhatIf
            $logEntry = $script:SyncLogCache.Values | Select-Object -First 1
            $logEntry.OverallStatus | Should Be 'WhatIf'
        }

        It 'Multiple syncs create multiple log entries' {
            Sync-CIPPTenantToConfluence -TenantId 'test' -Users @()
            Sync-CIPPTenantToConfluence -TenantId 'test' -Users @()
            $script:SyncLogCache.Count | Should Be 2
        }

        It 'Each log entry has unique LogId' {
            Sync-CIPPTenantToConfluence -TenantId 'test' -Users @()
            Sync-CIPPTenantToConfluence -TenantId 'test' -Users @()
            $logs = @($script:SyncLogCache.Values)
            $logs[0].LogId | Should Not Be $logs[1].LogId
        }

        It 'Log entry has Timestamp in UTC format' {
            Sync-CIPPTenantToConfluence -TenantId 'test' -Users @()
            $logEntry = $script:SyncLogCache.Values | Select-Object -First 1
            $logEntry.Timestamp | Should Match '\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} UTC'
        }

        It 'Log entry includes SkippedCount' {
            Sync-CIPPTenantToConfluence -TenantId 'test' -Users @()
            $logEntry = $script:SyncLogCache.Values | Select-Object -First 1
            # 5 data types should be skipped (Endpoints, Licenses, MFA, Teams, SharePoint)
            $logEntry.SkippedCount | Should Be 5
        }

        It 'Log entry includes UnchangedCount' {
            Mock Get-ConfluenceSyncConfiguration {
                [PSCustomObject]@{
                    RetryAttempts         = 3
                    RetryDelaySeconds     = 1
                    EnableIncrementalSync = $true
                }
            }

            $users = @([PSCustomObject]@{ Name = 'Test' })

            # First sync
            Sync-CIPPTenantToConfluence -TenantId 'test' -Users $users
            $script:SyncLogCache = @{}

            # Second sync (unchanged)
            Sync-CIPPTenantToConfluence -TenantId 'test' -Users $users
            $logEntry = $script:SyncLogCache.Values | Select-Object -First 1
            $logEntry.UnchangedCount | Should Be 1
        }

        It 'Log entry includes ErrorCount' {
            Mock Sync-ConfluenceUserInventory { throw "Error 1" }
            Mock Sync-ConfluenceEndpointInventory { throw "Error 2" }

            Sync-CIPPTenantToConfluence -TenantId 'test' -Users @() -Endpoints @()
            $logEntry = $script:SyncLogCache.Values | Select-Object -First 1
            $logEntry.ErrorCount | Should Be 2
        }
    }
}
