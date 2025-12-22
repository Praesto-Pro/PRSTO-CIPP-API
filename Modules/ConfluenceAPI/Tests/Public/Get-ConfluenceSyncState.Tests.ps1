$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleRoot = Split-Path -Parent (Split-Path -Parent $here)
$publicDir = Join-Path $moduleRoot 'Public'
$privateDir = Join-Path $moduleRoot 'Private'

Describe 'Get-ConfluenceSyncState' {
    BeforeAll {
        . "$privateDir\Get-SyncStateKey.ps1"
        . "$publicDir\Get-ConfluenceSyncState.ps1"
    }

    BeforeEach {
        # Reset state cache before each test
        $script:SyncStateCache = @{}
    }

    Context 'Empty State' {
        It 'Returns empty array when no state stored' {
            $result = Get-ConfluenceSyncState
            @($result).Count | Should Be 0
        }

        It 'Returns empty array for specific tenant when no state' {
            $result = Get-ConfluenceSyncState -TenantId 'tenant-123'
            @($result).Count | Should Be 0
        }
    }

    Context 'State Retrieval' {
        BeforeEach {
            # Seed test state
            $script:SyncStateCache = @{
                'tenant-1|UserInventory' = @{
                    Hash         = 'ABC123DEF456GHI789JKL012MNO345PQR678STU901VWX234YZA567BCD890'
                    LastSyncTime = '2025-12-15 10:00:00 UTC'
                    PageId       = 'page-1'
                }
                'tenant-1|EndpointInventory' = @{
                    Hash         = 'DEF456GHI789JKL012MNO345PQR678STU901VWX234YZA567BCD890ABC123'
                    LastSyncTime = '2025-12-15 10:05:00 UTC'
                    PageId       = 'page-2'
                }
                'tenant-2|UserInventory' = @{
                    Hash         = 'GHI789JKL012MNO345PQR678STU901VWX234YZA567BCD890ABC123DEF456'
                    LastSyncTime = '2025-12-15 11:00:00 UTC'
                    PageId       = 'page-3'
                }
            }
        }

        It 'Returns all state when no filter' {
            $result = Get-ConfluenceSyncState
            @($result).Count | Should Be 3
        }

        It 'Returns state for specific tenant' {
            $result = Get-ConfluenceSyncState -TenantId 'tenant-1'
            @($result).Count | Should Be 2
        }

        It 'Returns state for specific tenant and data type' {
            $result = Get-ConfluenceSyncState -TenantId 'tenant-1' -DataType 'UserInventory'
            @($result).Count | Should Be 1
            $result.TenantId | Should Be 'tenant-1'
            $result.DataType | Should Be 'UserInventory'
        }

        It 'Returns empty when tenant not found' {
            $result = Get-ConfluenceSyncState -TenantId 'tenant-999'
            @($result).Count | Should Be 0
        }

        It 'Returns correct state properties' {
            $result = Get-ConfluenceSyncState -TenantId 'tenant-1' -DataType 'UserInventory'
            $result.TenantId | Should Be 'tenant-1'
            $result.DataType | Should Be 'UserInventory'
            $result.Hash | Should Be 'ABC123DEF456GHI789JKL012MNO345PQR678STU901VWX234YZA567BCD890'
            $result.ShortHash | Should Be 'ABC123DEF456GHI7'
            $result.LastSyncTime | Should Be '2025-12-15 10:00:00 UTC'
            $result.PageId | Should Be 'page-1'
        }

        It 'Returns PSCustomObject with expected properties' {
            $result = Get-ConfluenceSyncState -TenantId 'tenant-1' -DataType 'UserInventory'
            ($result.PSObject.Properties.Name -contains 'TenantId') | Should Be $true
            ($result.PSObject.Properties.Name -contains 'DataType') | Should Be $true
            ($result.PSObject.Properties.Name -contains 'Hash') | Should Be $true
            ($result.PSObject.Properties.Name -contains 'ShortHash') | Should Be $true
            ($result.PSObject.Properties.Name -contains 'LastSyncTime') | Should Be $true
            ($result.PSObject.Properties.Name -contains 'PageId') | Should Be $true
        }
    }

    Context 'Verbose Output' {
        It 'Writes verbose message with count' {
            $verboseOutput = Get-ConfluenceSyncState -Verbose 4>&1
            $verboseOutput | Should Not Be $null
        }
    }
}
