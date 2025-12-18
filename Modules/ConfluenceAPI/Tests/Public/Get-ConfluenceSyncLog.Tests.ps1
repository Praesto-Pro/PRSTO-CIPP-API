$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleRoot = Split-Path -Parent (Split-Path -Parent $here)
$publicDir = Join-Path $moduleRoot 'Public'

Describe 'Get-ConfluenceSyncLog' {
    BeforeAll {
        . "$publicDir\Get-ConfluenceSyncLog.ps1"
    }

    BeforeEach {
        # Reset cache for test isolation
        $script:SyncLogCache = @{}
    }

    Context 'Empty Cache' {
        It 'Returns empty array when no logs exist' {
            $result = Get-ConfluenceSyncLog
            $result | Should BeNullOrEmpty
        }

        It 'Returns empty array with TenantId filter on empty cache' {
            $result = Get-ConfluenceSyncLog -TenantId 'non-existent'
            $result | Should BeNullOrEmpty
        }

        It 'Returns empty array with Last filter on empty cache' {
            $result = Get-ConfluenceSyncLog -Last 10
            $result | Should BeNullOrEmpty
        }
    }

    Context 'With Logs - Basic Retrieval' {
        BeforeEach {
            # Seed test data with distinct timestamps for ordering tests
            $script:SyncLogCache = @{
                'log-1' = [PSCustomObject]@{
                    LogId          = 'log-1'
                    Timestamp      = '2025-12-17 10:00:00 UTC'
                    TenantId       = 'tenant-a'
                    SpaceKey       = 'SPACE-A'
                    Duration       = '00:01:00'
                    OverallStatus  = 'Success'
                    SuccessCount   = 6
                    FailedCount    = 0
                    SkippedCount   = 0
                    UnchangedCount = 0
                    ErrorCount     = 0
                    SyncResults    = @([PSCustomObject]@{ DataType = 'Users'; Status = 'Success' })
                    Errors         = @()
                }
                'log-2' = [PSCustomObject]@{
                    LogId          = 'log-2'
                    Timestamp      = '2025-12-17 11:00:00 UTC'
                    TenantId       = 'tenant-b'
                    SpaceKey       = 'SPACE-B'
                    Duration       = '00:00:30'
                    OverallStatus  = 'PartialFailure'
                    SuccessCount   = 4
                    FailedCount    = 2
                    SkippedCount   = 0
                    UnchangedCount = 0
                    ErrorCount     = 2
                    SyncResults    = @([PSCustomObject]@{ DataType = 'Users'; Status = 'Success' })
                    Errors         = @([PSCustomObject]@{ DataType = 'Endpoints'; Error = 'Test error' })
                }
                'log-3' = [PSCustomObject]@{
                    LogId          = 'log-3'
                    Timestamp      = '2025-12-17 12:00:00 UTC'
                    TenantId       = 'tenant-a'
                    SpaceKey       = 'SPACE-A'
                    Duration       = '00:02:00'
                    OverallStatus  = 'Success'
                    SuccessCount   = 6
                    FailedCount    = 0
                    SkippedCount   = 0
                    UnchangedCount = 0
                    ErrorCount     = 0
                    SyncResults    = @([PSCustomObject]@{ DataType = 'Users'; Status = 'Success' })
                    Errors         = @()
                }
            }
        }

        It 'Returns all logs when no filter specified' {
            $result = Get-ConfluenceSyncLog
            @($result).Count | Should Be 3
        }

        It 'Returns logs in reverse chronological order (newest first)' {
            $result = Get-ConfluenceSyncLog
            $result[0].Timestamp | Should Be '2025-12-17 12:00:00 UTC'
            $result[1].Timestamp | Should Be '2025-12-17 11:00:00 UTC'
            $result[2].Timestamp | Should Be '2025-12-17 10:00:00 UTC'
        }

        It 'Returns logs with expected properties' {
            $result = Get-ConfluenceSyncLog
            ($result[0].PSObject.Properties.Name -contains 'LogId') | Should Be $true
            ($result[0].PSObject.Properties.Name -contains 'Timestamp') | Should Be $true
            ($result[0].PSObject.Properties.Name -contains 'TenantId') | Should Be $true
            ($result[0].PSObject.Properties.Name -contains 'SpaceKey') | Should Be $true
            ($result[0].PSObject.Properties.Name -contains 'Duration') | Should Be $true
            ($result[0].PSObject.Properties.Name -contains 'OverallStatus') | Should Be $true
            ($result[0].PSObject.Properties.Name -contains 'SuccessCount') | Should Be $true
            ($result[0].PSObject.Properties.Name -contains 'FailedCount') | Should Be $true
            ($result[0].PSObject.Properties.Name -contains 'ErrorCount') | Should Be $true
        }
    }

    Context 'TenantId Filter' {
        BeforeEach {
            $script:SyncLogCache = @{
                'log-1' = [PSCustomObject]@{
                    LogId          = 'log-1'
                    Timestamp      = '2025-12-17 10:00:00 UTC'
                    TenantId       = 'tenant-a'
                    SpaceKey       = 'SPACE-A'
                    Duration       = '00:01:00'
                    OverallStatus  = 'Success'
                    SuccessCount   = 6
                    FailedCount    = 0
                    SkippedCount   = 0
                    UnchangedCount = 0
                    ErrorCount     = 0
                    SyncResults    = @()
                    Errors         = @()
                }
                'log-2' = [PSCustomObject]@{
                    LogId          = 'log-2'
                    Timestamp      = '2025-12-17 11:00:00 UTC'
                    TenantId       = 'tenant-b'
                    SpaceKey       = 'SPACE-B'
                    Duration       = '00:00:30'
                    OverallStatus  = 'Success'
                    SuccessCount   = 6
                    FailedCount    = 0
                    SkippedCount   = 0
                    UnchangedCount = 0
                    ErrorCount     = 0
                    SyncResults    = @()
                    Errors         = @()
                }
                'log-3' = [PSCustomObject]@{
                    LogId          = 'log-3'
                    Timestamp      = '2025-12-17 12:00:00 UTC'
                    TenantId       = 'tenant-a'
                    SpaceKey       = 'SPACE-A'
                    Duration       = '00:02:00'
                    OverallStatus  = 'Success'
                    SuccessCount   = 6
                    FailedCount    = 0
                    SkippedCount   = 0
                    UnchangedCount = 0
                    ErrorCount     = 0
                    SyncResults    = @()
                    Errors         = @()
                }
            }
        }

        It 'Filters by TenantId correctly' {
            $result = Get-ConfluenceSyncLog -TenantId 'tenant-a'
            @($result).Count | Should Be 2
        }

        It 'Returns only logs for specified tenant' {
            $result = Get-ConfluenceSyncLog -TenantId 'tenant-a'
            foreach ($log in $result) {
                $log.TenantId | Should Be 'tenant-a'
            }
        }

        It 'Returns empty when tenant has no logs' {
            $result = Get-ConfluenceSyncLog -TenantId 'non-existent-tenant'
            $result | Should BeNullOrEmpty
        }

        It 'TenantId filter is case-insensitive (PowerShell default)' {
            $result = Get-ConfluenceSyncLog -TenantId 'TENANT-A'
            # PowerShell -eq operator is case-insensitive by default
            @($result).Count | Should Be 2
        }
    }

    Context 'Last N Filter' {
        BeforeEach {
            $script:SyncLogCache = @{
                'log-1' = [PSCustomObject]@{
                    LogId          = 'log-1'
                    Timestamp      = '2025-12-17 10:00:00 UTC'
                    TenantId       = 'tenant-a'
                    SpaceKey       = 'SPACE-A'
                    Duration       = '00:01:00'
                    OverallStatus  = 'Success'
                    SuccessCount   = 6
                    FailedCount    = 0
                    SkippedCount   = 0
                    UnchangedCount = 0
                    ErrorCount     = 0
                    SyncResults    = @()
                    Errors         = @()
                }
                'log-2' = [PSCustomObject]@{
                    LogId          = 'log-2'
                    Timestamp      = '2025-12-17 11:00:00 UTC'
                    TenantId       = 'tenant-b'
                    SpaceKey       = 'SPACE-B'
                    Duration       = '00:00:30'
                    OverallStatus  = 'Success'
                    SuccessCount   = 6
                    FailedCount    = 0
                    SkippedCount   = 0
                    UnchangedCount = 0
                    ErrorCount     = 0
                    SyncResults    = @()
                    Errors         = @()
                }
                'log-3' = [PSCustomObject]@{
                    LogId          = 'log-3'
                    Timestamp      = '2025-12-17 12:00:00 UTC'
                    TenantId       = 'tenant-c'
                    SpaceKey       = 'SPACE-C'
                    Duration       = '00:02:00'
                    OverallStatus  = 'Success'
                    SuccessCount   = 6
                    FailedCount    = 0
                    SkippedCount   = 0
                    UnchangedCount = 0
                    ErrorCount     = 0
                    SyncResults    = @()
                    Errors         = @()
                }
            }
        }

        It 'Returns only N most recent entries with -Last' {
            $result = Get-ConfluenceSyncLog -Last 1
            @($result).Count | Should Be 1
        }

        It 'Most recent entry is returned first' {
            $result = Get-ConfluenceSyncLog -Last 1
            $result[0].Timestamp | Should Be '2025-12-17 12:00:00 UTC'
        }

        It '-Last 2 returns 2 most recent' {
            $result = Get-ConfluenceSyncLog -Last 2
            @($result).Count | Should Be 2
            $result[0].Timestamp | Should Be '2025-12-17 12:00:00 UTC'
            $result[1].Timestamp | Should Be '2025-12-17 11:00:00 UTC'
        }

        It '-Last larger than count returns all logs' {
            $result = Get-ConfluenceSyncLog -Last 100
            @($result).Count | Should Be 3
        }
    }

    Context 'Combined Filters' {
        BeforeEach {
            $script:SyncLogCache = @{
                'log-1' = [PSCustomObject]@{
                    LogId          = 'log-1'
                    Timestamp      = '2025-12-17 10:00:00 UTC'
                    TenantId       = 'tenant-a'
                    SpaceKey       = 'SPACE-A'
                    Duration       = '00:01:00'
                    OverallStatus  = 'Success'
                    SuccessCount   = 6
                    FailedCount    = 0
                    SkippedCount   = 0
                    UnchangedCount = 0
                    ErrorCount     = 0
                    SyncResults    = @()
                    Errors         = @()
                }
                'log-2' = [PSCustomObject]@{
                    LogId          = 'log-2'
                    Timestamp      = '2025-12-17 11:00:00 UTC'
                    TenantId       = 'tenant-a'
                    SpaceKey       = 'SPACE-A'
                    Duration       = '00:00:30'
                    OverallStatus  = 'Success'
                    SuccessCount   = 6
                    FailedCount    = 0
                    SkippedCount   = 0
                    UnchangedCount = 0
                    ErrorCount     = 0
                    SyncResults    = @()
                    Errors         = @()
                }
                'log-3' = [PSCustomObject]@{
                    LogId          = 'log-3'
                    Timestamp      = '2025-12-17 12:00:00 UTC'
                    TenantId       = 'tenant-a'
                    SpaceKey       = 'SPACE-A'
                    Duration       = '00:02:00'
                    OverallStatus  = 'Success'
                    SuccessCount   = 6
                    FailedCount    = 0
                    SkippedCount   = 0
                    UnchangedCount = 0
                    ErrorCount     = 0
                    SyncResults    = @()
                    Errors         = @()
                }
                'log-4' = [PSCustomObject]@{
                    LogId          = 'log-4'
                    Timestamp      = '2025-12-17 13:00:00 UTC'
                    TenantId       = 'tenant-b'
                    SpaceKey       = 'SPACE-B'
                    Duration       = '00:00:45'
                    OverallStatus  = 'Success'
                    SuccessCount   = 6
                    FailedCount    = 0
                    SkippedCount   = 0
                    UnchangedCount = 0
                    ErrorCount     = 0
                    SyncResults    = @()
                    Errors         = @()
                }
            }
        }

        It 'Combines TenantId and Last filters' {
            $result = Get-ConfluenceSyncLog -TenantId 'tenant-a' -Last 2
            @($result).Count | Should Be 2
            foreach ($log in $result) {
                $log.TenantId | Should Be 'tenant-a'
            }
        }

        It 'TenantId filter applied before Last' {
            $result = Get-ConfluenceSyncLog -TenantId 'tenant-a' -Last 1
            @($result).Count | Should Be 1
            $result[0].TenantId | Should Be 'tenant-a'
            $result[0].Timestamp | Should Be '2025-12-17 12:00:00 UTC'
        }
    }

    Context 'IncludeDetails Switch' {
        BeforeEach {
            $script:SyncLogCache = @{
                'log-1' = [PSCustomObject]@{
                    LogId          = 'log-1'
                    Timestamp      = '2025-12-17 10:00:00 UTC'
                    TenantId       = 'tenant-a'
                    SpaceKey       = 'SPACE-A'
                    Duration       = '00:01:00'
                    OverallStatus  = 'PartialFailure'
                    SuccessCount   = 4
                    FailedCount    = 2
                    SkippedCount   = 0
                    UnchangedCount = 0
                    ErrorCount     = 2
                    SyncResults    = @(
                        [PSCustomObject]@{ DataType = 'Users'; Status = 'Success' }
                        [PSCustomObject]@{ DataType = 'Endpoints'; Status = 'Failed' }
                    )
                    Errors         = @(
                        [PSCustomObject]@{ DataType = 'Endpoints'; Error = 'Connection timeout' }
                    )
                }
            }
        }

        It 'Excludes SyncResults by default' {
            $result = Get-ConfluenceSyncLog
            ($result[0].PSObject.Properties.Name -contains 'SyncResults') | Should Be $false
        }

        It 'Excludes Errors by default' {
            $result = Get-ConfluenceSyncLog
            ($result[0].PSObject.Properties.Name -contains 'Errors') | Should Be $false
        }

        It 'Includes SyncResults with -IncludeDetails' {
            $result = Get-ConfluenceSyncLog -IncludeDetails
            ($result[0].PSObject.Properties.Name -contains 'SyncResults') | Should Be $true
            @($result[0].SyncResults).Count | Should Be 2
        }

        It 'Includes Errors with -IncludeDetails' {
            $result = Get-ConfluenceSyncLog -IncludeDetails
            ($result[0].PSObject.Properties.Name -contains 'Errors') | Should Be $true
            @($result[0].Errors).Count | Should Be 1
        }

        It 'Can combine -IncludeDetails with TenantId filter' {
            $result = Get-ConfluenceSyncLog -TenantId 'tenant-a' -IncludeDetails
            @($result).Count | Should Be 1
            ($result[0].PSObject.Properties.Name -contains 'SyncResults') | Should Be $true
        }

        It 'Can combine -IncludeDetails with Last filter' {
            $result = Get-ConfluenceSyncLog -Last 1 -IncludeDetails
            @($result).Count | Should Be 1
            ($result[0].PSObject.Properties.Name -contains 'Errors') | Should Be $true
        }
    }

    Context 'Summary View Properties' {
        BeforeEach {
            $script:SyncLogCache = @{
                'log-1' = [PSCustomObject]@{
                    LogId          = 'log-1'
                    Timestamp      = '2025-12-17 10:00:00 UTC'
                    TenantId       = 'tenant-a'
                    SpaceKey       = 'SPACE-A'
                    Duration       = '00:01:00'
                    OverallStatus  = 'Success'
                    SuccessCount   = 6
                    FailedCount    = 0
                    SkippedCount   = 0
                    UnchangedCount = 0
                    ErrorCount     = 0
                    SyncResults    = @()
                    Errors         = @()
                }
            }
        }

        It 'Summary view includes LogId' {
            $result = Get-ConfluenceSyncLog
            $result[0].LogId | Should Be 'log-1'
        }

        It 'Summary view includes Timestamp' {
            $result = Get-ConfluenceSyncLog
            $result[0].Timestamp | Should Be '2025-12-17 10:00:00 UTC'
        }

        It 'Summary view includes TenantId' {
            $result = Get-ConfluenceSyncLog
            $result[0].TenantId | Should Be 'tenant-a'
        }

        It 'Summary view includes SpaceKey' {
            $result = Get-ConfluenceSyncLog
            $result[0].SpaceKey | Should Be 'SPACE-A'
        }

        It 'Summary view includes Duration' {
            $result = Get-ConfluenceSyncLog
            $result[0].Duration | Should Be '00:01:00'
        }

        It 'Summary view includes OverallStatus' {
            $result = Get-ConfluenceSyncLog
            $result[0].OverallStatus | Should Be 'Success'
        }

        It 'Summary view includes SuccessCount' {
            $result = Get-ConfluenceSyncLog
            $result[0].SuccessCount | Should Be 6
        }

        It 'Summary view includes FailedCount' {
            $result = Get-ConfluenceSyncLog
            $result[0].FailedCount | Should Be 0
        }

        It 'Summary view includes SkippedCount' {
            $result = Get-ConfluenceSyncLog
            $result[0].SkippedCount | Should Be 0
        }

        It 'Summary view includes UnchangedCount' {
            $result = Get-ConfluenceSyncLog
            $result[0].UnchangedCount | Should Be 0
        }

        It 'Summary view includes ErrorCount' {
            $result = Get-ConfluenceSyncLog
            $result[0].ErrorCount | Should Be 0
        }
    }

    Context 'Verbose Output' {
        BeforeEach {
            $script:SyncLogCache = @{
                'log-1' = [PSCustomObject]@{
                    LogId          = 'log-1'
                    Timestamp      = '2025-12-17 10:00:00 UTC'
                    TenantId       = 'tenant-a'
                    SpaceKey       = 'SPACE-A'
                    Duration       = '00:01:00'
                    OverallStatus  = 'Success'
                    SuccessCount   = 6
                    FailedCount    = 0
                    SkippedCount   = 0
                    UnchangedCount = 0
                    ErrorCount     = 0
                    SyncResults    = @()
                    Errors         = @()
                }
            }
        }

        It 'Writes verbose message when -Verbose is used' {
            $verboseOutput = Get-ConfluenceSyncLog -Verbose 4>&1
            $verboseOutput | Should Not Be $null
        }
    }
}
