$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleRoot = Split-Path -Parent (Split-Path -Parent $here)
$publicDir = Join-Path $moduleRoot 'Public'
$privateDir = Join-Path $moduleRoot 'Private'

Describe 'Clear-ConfluenceSyncState' {
    BeforeAll {
        . "$privateDir\Get-SyncStateKey.ps1"
        . "$publicDir\Clear-ConfluenceSyncState.ps1"
    }

    BeforeEach {
        # Seed test state before each test
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

    Context 'Clear All State' {
        It 'Clears all state when no parameters' {
            $result = Clear-ConfluenceSyncState -Confirm:$false
            $result.Cleared | Should Be 3
            $script:SyncStateCache.Count | Should Be 0
        }

        It 'Returns result with correct properties' {
            $result = Clear-ConfluenceSyncState -Confirm:$false
            ($result.PSObject.Properties.Name -contains 'TenantId') | Should Be $true
            ($result.PSObject.Properties.Name -contains 'DataType') | Should Be $true
            ($result.PSObject.Properties.Name -contains 'EntriesFound') | Should Be $true
            ($result.PSObject.Properties.Name -contains 'Cleared') | Should Be $true
            ($result.PSObject.Properties.Name -contains 'ClearedAt') | Should Be $true
        }
    }

    Context 'Clear Specific Tenant' {
        It 'Clears all state for specific tenant' {
            $result = Clear-ConfluenceSyncState -TenantId 'tenant-1' -Confirm:$false
            $result.Cleared | Should Be 2
            $script:SyncStateCache.Count | Should Be 1
            $script:SyncStateCache.ContainsKey('tenant-2|UserInventory') | Should Be $true
        }

        It 'Returns 0 when tenant not found' {
            $result = Clear-ConfluenceSyncState -TenantId 'tenant-999' -Confirm:$false
            $result.EntriesFound | Should Be 0
            $result.Cleared | Should Be 0
            $script:SyncStateCache.Count | Should Be 3
        }
    }

    Context 'Clear Specific Tenant and DataType' {
        It 'Clears only specific tenant+datatype' {
            $result = Clear-ConfluenceSyncState -TenantId 'tenant-1' -DataType 'UserInventory' -Confirm:$false
            $result.Cleared | Should Be 1
            $script:SyncStateCache.Count | Should Be 2
            $script:SyncStateCache.ContainsKey('tenant-1|UserInventory') | Should Be $false
            $script:SyncStateCache.ContainsKey('tenant-1|EndpointInventory') | Should Be $true
        }

        It 'Returns 0 when specific entry not found' {
            $result = Clear-ConfluenceSyncState -TenantId 'tenant-1' -DataType 'MFAReport' -Confirm:$false
            $result.EntriesFound | Should Be 0
            $result.Cleared | Should Be 0
        }
    }

    Context 'WhatIf Support' {
        It 'Does not modify state when WhatIf used' {
            $originalCount = $script:SyncStateCache.Count
            Clear-ConfluenceSyncState -WhatIf
            $script:SyncStateCache.Count | Should Be $originalCount
        }

        It 'Does not modify state for specific tenant with WhatIf' {
            $originalCount = $script:SyncStateCache.Count
            Clear-ConfluenceSyncState -TenantId 'tenant-1' -WhatIf
            $script:SyncStateCache.Count | Should Be $originalCount
        }

        It 'Returns result showing what would be cleared' {
            $result = Clear-ConfluenceSyncState -TenantId 'tenant-1' -WhatIf
            $result.EntriesFound | Should Be 2
            $result.Cleared | Should Be 0
        }
    }

    Context 'Result Properties' {
        It 'Returns TenantId when specified' {
            $result = Clear-ConfluenceSyncState -TenantId 'tenant-1' -Confirm:$false
            $result.TenantId | Should Be 'tenant-1'
        }

        It 'Returns DataType when specified' {
            $result = Clear-ConfluenceSyncState -TenantId 'tenant-1' -DataType 'UserInventory' -Confirm:$false
            $result.DataType | Should Be 'UserInventory'
        }

        It 'Returns ClearedAt timestamp' {
            $result = Clear-ConfluenceSyncState -Confirm:$false
            $result.ClearedAt | Should Not Be $null
            $result.ClearedAt | Should Match '\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} UTC'
        }
    }

    Context 'Empty State' {
        BeforeEach {
            $script:SyncStateCache = @{}
        }

        It 'Handles clearing empty state gracefully' {
            $result = Clear-ConfluenceSyncState -Confirm:$false
            $result.EntriesFound | Should Be 0
            $result.Cleared | Should Be 0
        }
    }

    Context 'Verbose Output' {
        It 'Writes verbose messages' {
            $verboseOutput = Clear-ConfluenceSyncState -TenantId 'tenant-1' -Confirm:$false -Verbose 4>&1
            $verboseOutput | Should Not Be $null
        }
    }
}
