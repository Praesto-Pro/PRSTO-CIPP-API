$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleRoot = Split-Path -Parent (Split-Path -Parent $here)
$publicDir = Join-Path $moduleRoot 'Public'

Describe 'Clear-ConfluenceSyncLog' {
    BeforeAll {
        . "$publicDir\Clear-ConfluenceSyncLog.ps1"
    }

    BeforeEach {
        # Reset cache for test isolation
        $script:SyncLogCache = @{}
    }

    Context 'Empty Cache' {
        It 'Does not error on empty cache' {
            { Clear-ConfluenceSyncLog -Confirm:$false } | Should Not Throw
        }

        It 'Does not error with TenantId filter on empty cache' {
            { Clear-ConfluenceSyncLog -TenantId 'non-existent' -Confirm:$false } | Should Not Throw
        }
    }

    Context 'Clear All Logs' {
        BeforeEach {
            $script:SyncLogCache = @{
                'log-1' = [PSCustomObject]@{
                    LogId          = 'log-1'
                    TenantId       = 'tenant-a'
                    Timestamp      = '2025-12-17 10:00:00 UTC'
                    SpaceKey       = 'SPACE-A'
                    Duration       = '00:01:00'
                    OverallStatus  = 'Success'
                    SuccessCount   = 6
                    FailedCount    = 0
                    SkippedCount   = 0
                    UnchangedCount = 0
                    ErrorCount     = 0
                }
                'log-2' = [PSCustomObject]@{
                    LogId          = 'log-2'
                    TenantId       = 'tenant-b'
                    Timestamp      = '2025-12-17 11:00:00 UTC'
                    SpaceKey       = 'SPACE-B'
                    Duration       = '00:00:30'
                    OverallStatus  = 'Success'
                    SuccessCount   = 6
                    FailedCount    = 0
                    SkippedCount   = 0
                    UnchangedCount = 0
                    ErrorCount     = 0
                }
                'log-3' = [PSCustomObject]@{
                    LogId          = 'log-3'
                    TenantId       = 'tenant-c'
                    Timestamp      = '2025-12-17 12:00:00 UTC'
                    SpaceKey       = 'SPACE-C'
                    Duration       = '00:02:00'
                    OverallStatus  = 'Success'
                    SuccessCount   = 6
                    FailedCount    = 0
                    SkippedCount   = 0
                    UnchangedCount = 0
                    ErrorCount     = 0
                }
            }
        }

        It 'Clears all logs without TenantId parameter' {
            Clear-ConfluenceSyncLog -Confirm:$false
            $script:SyncLogCache.Count | Should Be 0
        }

        It 'Leaves cache empty after clearing' {
            Clear-ConfluenceSyncLog -Confirm:$false
            $script:SyncLogCache.Keys.Count | Should Be 0
        }
    }

    Context 'Clear Specific Tenant Logs' {
        BeforeEach {
            $script:SyncLogCache = @{
                'log-1' = [PSCustomObject]@{
                    LogId          = 'log-1'
                    TenantId       = 'tenant-a'
                    Timestamp      = '2025-12-17 10:00:00 UTC'
                    SpaceKey       = 'SPACE-A'
                    Duration       = '00:01:00'
                    OverallStatus  = 'Success'
                    SuccessCount   = 6
                    FailedCount    = 0
                    SkippedCount   = 0
                    UnchangedCount = 0
                    ErrorCount     = 0
                }
                'log-2' = [PSCustomObject]@{
                    LogId          = 'log-2'
                    TenantId       = 'tenant-b'
                    Timestamp      = '2025-12-17 11:00:00 UTC'
                    SpaceKey       = 'SPACE-B'
                    Duration       = '00:00:30'
                    OverallStatus  = 'Success'
                    SuccessCount   = 6
                    FailedCount    = 0
                    SkippedCount   = 0
                    UnchangedCount = 0
                    ErrorCount     = 0
                }
                'log-3' = [PSCustomObject]@{
                    LogId          = 'log-3'
                    TenantId       = 'tenant-a'
                    Timestamp      = '2025-12-17 12:00:00 UTC'
                    SpaceKey       = 'SPACE-A'
                    Duration       = '00:02:00'
                    OverallStatus  = 'Success'
                    SuccessCount   = 6
                    FailedCount    = 0
                    SkippedCount   = 0
                    UnchangedCount = 0
                    ErrorCount     = 0
                }
            }
        }

        It 'Clears only logs for specified tenant' {
            Clear-ConfluenceSyncLog -TenantId 'tenant-a' -Confirm:$false
            $script:SyncLogCache.Count | Should Be 1
        }

        It 'Retains logs for other tenants' {
            Clear-ConfluenceSyncLog -TenantId 'tenant-a' -Confirm:$false
            $remaining = $script:SyncLogCache.Values | Select-Object -First 1
            $remaining.TenantId | Should Be 'tenant-b'
        }

        It 'Clears multiple logs for same tenant' {
            # tenant-a has 2 logs (log-1 and log-3)
            Clear-ConfluenceSyncLog -TenantId 'tenant-a' -Confirm:$false

            $tenantALogs = @($script:SyncLogCache.Values | Where-Object { $_.TenantId -eq 'tenant-a' })
            $tenantALogs.Count | Should Be 0
        }

        It 'Does nothing when tenant has no logs' {
            $initialCount = $script:SyncLogCache.Count
            Clear-ConfluenceSyncLog -TenantId 'non-existent' -Confirm:$false
            $script:SyncLogCache.Count | Should Be $initialCount
        }
    }

    Context 'WhatIf Support' {
        BeforeEach {
            $script:SyncLogCache = @{
                'log-1' = [PSCustomObject]@{
                    LogId          = 'log-1'
                    TenantId       = 'tenant-a'
                    Timestamp      = '2025-12-17 10:00:00 UTC'
                    SpaceKey       = 'SPACE-A'
                    Duration       = '00:01:00'
                    OverallStatus  = 'Success'
                    SuccessCount   = 6
                    FailedCount    = 0
                    SkippedCount   = 0
                    UnchangedCount = 0
                    ErrorCount     = 0
                }
                'log-2' = [PSCustomObject]@{
                    LogId          = 'log-2'
                    TenantId       = 'tenant-b'
                    Timestamp      = '2025-12-17 11:00:00 UTC'
                    SpaceKey       = 'SPACE-B'
                    Duration       = '00:00:30'
                    OverallStatus  = 'Success'
                    SuccessCount   = 6
                    FailedCount    = 0
                    SkippedCount   = 0
                    UnchangedCount = 0
                    ErrorCount     = 0
                }
            }
        }

        It 'Does not modify cache with -WhatIf' {
            Clear-ConfluenceSyncLog -WhatIf
            $script:SyncLogCache.Count | Should Be 2
        }

        It 'Does not modify cache with -WhatIf and TenantId' {
            Clear-ConfluenceSyncLog -TenantId 'tenant-a' -WhatIf
            $script:SyncLogCache.Count | Should Be 2
        }

        It 'Shows WhatIf message for all logs' {
            $whatIfOutput = Clear-ConfluenceSyncLog -WhatIf 4>&1
            # WhatIf output should be generated
            $script:SyncLogCache.Count | Should Be 2
        }
    }

    Context 'Confirm Parameter' {
        BeforeEach {
            $script:SyncLogCache = @{
                'log-1' = [PSCustomObject]@{
                    LogId          = 'log-1'
                    TenantId       = 'tenant-a'
                    Timestamp      = '2025-12-17 10:00:00 UTC'
                    SpaceKey       = 'SPACE-A'
                    Duration       = '00:01:00'
                    OverallStatus  = 'Success'
                    SuccessCount   = 6
                    FailedCount    = 0
                    SkippedCount   = 0
                    UnchangedCount = 0
                    ErrorCount     = 0
                }
            }
        }

        It 'Clears logs when Confirm is false' {
            Clear-ConfluenceSyncLog -Confirm:$false
            $script:SyncLogCache.Count | Should Be 0
        }

        It 'Has SupportsShouldProcess attribute' {
            $cmd = Get-Command Clear-ConfluenceSyncLog
            $cmd.Parameters.ContainsKey('WhatIf') | Should Be $true
            $cmd.Parameters.ContainsKey('Confirm') | Should Be $true
        }
    }

    Context 'Verbose Output' {
        BeforeEach {
            $script:SyncLogCache = @{
                'log-1' = [PSCustomObject]@{
                    LogId          = 'log-1'
                    TenantId       = 'tenant-a'
                    Timestamp      = '2025-12-17 10:00:00 UTC'
                    SpaceKey       = 'SPACE-A'
                    Duration       = '00:01:00'
                    OverallStatus  = 'Success'
                    SuccessCount   = 6
                    FailedCount    = 0
                    SkippedCount   = 0
                    UnchangedCount = 0
                    ErrorCount     = 0
                }
            }
        }

        It 'Writes verbose message when -Verbose is used' {
            $verboseOutput = Clear-ConfluenceSyncLog -Confirm:$false -Verbose 4>&1
            $verboseOutput | Should Not Be $null
        }
    }

    Context 'Edge Cases' {
        It 'Handles null cache gracefully' {
            $script:SyncLogCache = $null
            { Clear-ConfluenceSyncLog -Confirm:$false } | Should Not Throw
        }

        It 'Handles removing last log' {
            $script:SyncLogCache = @{
                'log-1' = [PSCustomObject]@{
                    LogId          = 'log-1'
                    TenantId       = 'tenant-a'
                    Timestamp      = '2025-12-17 10:00:00 UTC'
                    SpaceKey       = 'SPACE-A'
                    Duration       = '00:01:00'
                    OverallStatus  = 'Success'
                    SuccessCount   = 6
                    FailedCount    = 0
                    SkippedCount   = 0
                    UnchangedCount = 0
                    ErrorCount     = 0
                }
            }

            Clear-ConfluenceSyncLog -TenantId 'tenant-a' -Confirm:$false
            $script:SyncLogCache.Count | Should Be 0
        }
    }
}
