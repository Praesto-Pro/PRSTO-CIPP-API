$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleRoot = Split-Path -Parent (Split-Path -Parent $here)
$publicDir = Join-Path $moduleRoot 'Public'

Describe 'Get-ConfluenceSyncStatus' {
    BeforeAll {
        . "$publicDir\Get-ConfluenceSyncStatus.ps1"
    }

    BeforeEach {
        # Reset cache for test isolation
        $script:SyncLogCache = @{}
    }

    Context 'Empty Cache' {
        It 'Returns empty array when no logs exist' {
            $result = Get-ConfluenceSyncStatus
            @($result).Count | Should Be 0
        }

        It 'Returns empty array for specific tenant with no logs' {
            $result = Get-ConfluenceSyncStatus -TenantId 'unknown'
            @($result).Count | Should Be 0
        }

        It 'Does not throw with empty cache' {
            { Get-ConfluenceSyncStatus } | Should Not Throw
        }

        It 'Returns empty array with TenantId filter on empty cache' {
            $result = Get-ConfluenceSyncStatus -TenantId 'non-existent'
            @($result).Count | Should Be 0
        }
    }

    Context 'Basic Status Retrieval' {
        BeforeEach {
            # Seed test data - single tenant, single log
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

        It 'Returns one status per tenant' {
            $result = Get-ConfluenceSyncStatus
            @($result).Count | Should Be 1
        }

        It 'Returns status with expected properties' {
            $result = Get-ConfluenceSyncStatus
            ($result[0].PSObject.Properties.Name -contains 'TenantId') | Should Be $true
            ($result[0].PSObject.Properties.Name -contains 'SpaceKey') | Should Be $true
            ($result[0].PSObject.Properties.Name -contains 'LastSyncTime') | Should Be $true
            ($result[0].PSObject.Properties.Name -contains 'Status') | Should Be $true
            ($result[0].PSObject.Properties.Name -contains 'Duration') | Should Be $true
            ($result[0].PSObject.Properties.Name -contains 'SuccessCount') | Should Be $true
            ($result[0].PSObject.Properties.Name -contains 'FailedCount') | Should Be $true
            ($result[0].PSObject.Properties.Name -contains 'SkippedCount') | Should Be $true
            ($result[0].PSObject.Properties.Name -contains 'UnchangedCount') | Should Be $true
            ($result[0].PSObject.Properties.Name -contains 'ErrorCount') | Should Be $true
            ($result[0].PSObject.Properties.Name -contains 'LastError') | Should Be $true
        }

        It 'Returns correct TenantId' {
            $result = Get-ConfluenceSyncStatus
            $result[0].TenantId | Should Be 'tenant-a'
        }

        It 'Returns correct SpaceKey' {
            $result = Get-ConfluenceSyncStatus
            $result[0].SpaceKey | Should Be 'SPACE-A'
        }

        It 'Returns correct LastSyncTime' {
            $result = Get-ConfluenceSyncStatus
            $result[0].LastSyncTime | Should Be '2025-12-17 10:00:00 UTC'
        }

        It 'Returns correct Status' {
            $result = Get-ConfluenceSyncStatus
            $result[0].Status | Should Be 'Success'
        }

        It 'Returns correct Duration' {
            $result = Get-ConfluenceSyncStatus
            $result[0].Duration | Should Be '00:01:00'
        }

        It 'Returns correct SuccessCount' {
            $result = Get-ConfluenceSyncStatus
            $result[0].SuccessCount | Should Be 6
        }

        It 'Returns correct FailedCount' {
            $result = Get-ConfluenceSyncStatus
            $result[0].FailedCount | Should Be 0
        }

        It 'Returns correct SkippedCount' {
            $result = Get-ConfluenceSyncStatus
            $result[0].SkippedCount | Should Be 0
        }

        It 'Returns correct UnchangedCount' {
            $result = Get-ConfluenceSyncStatus
            $result[0].UnchangedCount | Should Be 0
        }

        It 'Returns correct ErrorCount' {
            $result = Get-ConfluenceSyncStatus
            $result[0].ErrorCount | Should Be 0
        }

        It 'Has null LastError for successful sync' {
            $result = Get-ConfluenceSyncStatus
            $result[0].LastError | Should BeNullOrEmpty
        }
    }

    Context 'Multiple Tenants' {
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
                    Duration       = '00:00:45'
                    OverallStatus  = 'PartialFailure'
                    SuccessCount   = 4
                    FailedCount    = 2
                    SkippedCount   = 0
                    UnchangedCount = 0
                    ErrorCount     = 2
                    SyncResults    = @()
                    Errors         = @([PSCustomObject]@{ DataType = 'Users'; Error = 'Connection failed' })
                }
                'log-3' = [PSCustomObject]@{
                    LogId          = 'log-3'
                    Timestamp      = '2025-12-17 09:00:00 UTC'
                    TenantId       = 'tenant-c'
                    SpaceKey       = 'SPACE-C'
                    Duration       = '00:02:00'
                    OverallStatus  = 'Failed'
                    SuccessCount   = 0
                    FailedCount    = 6
                    SkippedCount   = 0
                    UnchangedCount = 0
                    ErrorCount     = 6
                    SyncResults    = @()
                    Errors         = @([PSCustomObject]@{ DataType = 'All'; Error = 'Space not found' })
                }
            }
        }

        It 'Returns status for all tenants' {
            $result = Get-ConfluenceSyncStatus
            @($result).Count | Should Be 3
        }

        It 'Returns unique tenants only' {
            $result = Get-ConfluenceSyncStatus
            $tenantIds = $result | Select-Object -ExpandProperty TenantId
            @($tenantIds | Sort-Object -Unique).Count | Should Be 3
        }

        It 'Each tenant has correct status' {
            $result = Get-ConfluenceSyncStatus
            $tenantA = $result | Where-Object { $_.TenantId -eq 'tenant-a' }
            $tenantB = $result | Where-Object { $_.TenantId -eq 'tenant-b' }
            $tenantC = $result | Where-Object { $_.TenantId -eq 'tenant-c' }

            $tenantA.Status | Should Be 'Success'
            $tenantB.Status | Should Be 'PartialFailure'
            $tenantC.Status | Should Be 'Failed'
        }
    }

    Context 'Most Recent Log Per Tenant' {
        BeforeEach {
            # Same tenant with multiple logs at different times
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
                    TenantId       = 'tenant-a'  # Same tenant, newer
                    SpaceKey       = 'SPACE-A'
                    Duration       = '00:00:45'
                    OverallStatus  = 'PartialFailure'
                    SuccessCount   = 4
                    FailedCount    = 2
                    SkippedCount   = 0
                    UnchangedCount = 0
                    ErrorCount     = 2
                    SyncResults    = @()
                    Errors         = @([PSCustomObject]@{ DataType = 'Users'; Error = 'Connection failed' })
                }
                'log-3' = [PSCustomObject]@{
                    LogId          = 'log-3'
                    Timestamp      = '2025-12-17 09:00:00 UTC'
                    TenantId       = 'tenant-a'  # Same tenant, oldest
                    SpaceKey       = 'SPACE-A'
                    Duration       = '00:02:00'
                    OverallStatus  = 'Failed'
                    SuccessCount   = 0
                    FailedCount    = 6
                    SkippedCount   = 0
                    UnchangedCount = 0
                    ErrorCount     = 6
                    SyncResults    = @()
                    Errors         = @([PSCustomObject]@{ DataType = 'All'; Error = 'Space not found' })
                }
            }
        }

        It 'Returns only one status per tenant even with multiple logs' {
            $result = Get-ConfluenceSyncStatus
            @($result).Count | Should Be 1
        }

        It 'Uses most recent log per tenant' {
            $result = Get-ConfluenceSyncStatus
            $result[0].Status | Should Be 'PartialFailure'  # 11:00 log, not 10:00 or 09:00
        }

        It 'Returns most recent LastSyncTime' {
            $result = Get-ConfluenceSyncStatus
            $result[0].LastSyncTime | Should Be '2025-12-17 11:00:00 UTC'
        }

        It 'Returns correct Duration from most recent log' {
            $result = Get-ConfluenceSyncStatus
            $result[0].Duration | Should Be '00:00:45'
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
                    Duration       = '00:00:45'
                    OverallStatus  = 'Failed'
                    SuccessCount   = 0
                    FailedCount    = 6
                    SkippedCount   = 0
                    UnchangedCount = 0
                    ErrorCount     = 6
                    SyncResults    = @()
                    Errors         = @([PSCustomObject]@{ DataType = 'All'; Error = 'Connection failed' })
                }
            }
        }

        It 'Filters by TenantId correctly' {
            $result = Get-ConfluenceSyncStatus -TenantId 'tenant-a'
            @($result).Count | Should Be 1
            $result.TenantId | Should Be 'tenant-a'
        }

        It 'Returns correct status for filtered tenant' {
            $result = Get-ConfluenceSyncStatus -TenantId 'tenant-b'
            $result.Status | Should Be 'Failed'
        }

        It 'Returns empty when tenant not found' {
            $result = Get-ConfluenceSyncStatus -TenantId 'non-existent'
            @($result).Count | Should Be 0
        }

        It 'TenantId filter is case-insensitive' {
            $result = Get-ConfluenceSyncStatus -TenantId 'TENANT-A'
            @($result).Count | Should Be 1
        }
    }

    Context 'Error Handling' {
        BeforeEach {
            $script:SyncLogCache = @{
                'log-failed' = [PSCustomObject]@{
                    LogId          = 'log-failed'
                    Timestamp      = '2025-12-17 10:00:00 UTC'
                    TenantId       = 'tenant-fail'
                    SpaceKey       = 'SPACE-F'
                    Duration       = '00:00:30'
                    OverallStatus  = 'Failed'
                    SuccessCount   = 0
                    FailedCount    = 6
                    SkippedCount   = 0
                    UnchangedCount = 0
                    ErrorCount     = 3
                    SyncResults    = @()
                    Errors         = @(
                        [PSCustomObject]@{ DataType = 'Users'; Error = 'First error message' }
                        [PSCustomObject]@{ DataType = 'Endpoints'; Error = 'Second error message' }
                        [PSCustomObject]@{ DataType = 'Licenses'; Error = 'Third error message' }
                    )
                }
            }
        }

        It 'Includes LastError from failed syncs' {
            $result = Get-ConfluenceSyncStatus
            $result[0].LastError | Should Be 'First error message'
        }

        It 'Returns first error only' {
            $result = Get-ConfluenceSyncStatus
            # Should only have the first error, not all errors
            $result[0].LastError | Should Be 'First error message'
            $result[0].LastError | Should Not Be 'Second error message'
        }

        It 'Has correct ErrorCount' {
            $result = Get-ConfluenceSyncStatus
            $result[0].ErrorCount | Should Be 3
        }
    }

    Context 'Partial Failure Status' {
        BeforeEach {
            $script:SyncLogCache = @{
                'log-partial' = [PSCustomObject]@{
                    LogId          = 'log-partial'
                    Timestamp      = '2025-12-17 10:00:00 UTC'
                    TenantId       = 'tenant-partial'
                    SpaceKey       = 'SPACE-P'
                    Duration       = '00:01:30'
                    OverallStatus  = 'PartialFailure'
                    SuccessCount   = 4
                    FailedCount    = 2
                    SkippedCount   = 0
                    UnchangedCount = 0
                    ErrorCount     = 2
                    SyncResults    = @()
                    Errors         = @([PSCustomObject]@{ DataType = 'Users'; Error = 'Partial failure error' })
                }
            }
        }

        It 'Returns PartialFailure status' {
            $result = Get-ConfluenceSyncStatus
            $result[0].Status | Should Be 'PartialFailure'
        }

        It 'Has correct SuccessCount and FailedCount' {
            $result = Get-ConfluenceSyncStatus
            $result[0].SuccessCount | Should Be 4
            $result[0].FailedCount | Should Be 2
        }

        It 'Includes LastError for partial failure' {
            $result = Get-ConfluenceSyncStatus
            $result[0].LastError | Should Be 'Partial failure error'
        }
    }

    Context 'Null LastError for Success' {
        BeforeEach {
            $script:SyncLogCache = @{
                'success-log' = [PSCustomObject]@{
                    LogId          = 'success-log'
                    Timestamp      = '2025-12-17 12:00:00 UTC'
                    TenantId       = 'good-tenant'
                    SpaceKey       = 'GOOD'
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
            }
        }

        It 'Has null LastError for successful sync' {
            $result = Get-ConfluenceSyncStatus
            $result[0].LastError | Should BeNullOrEmpty
        }

        It 'Has zero ErrorCount for successful sync' {
            $result = Get-ConfluenceSyncStatus
            $result[0].ErrorCount | Should Be 0
        }
    }

    Context 'Empty Errors Array' {
        BeforeEach {
            $script:SyncLogCache = @{
                'log-no-errors' = [PSCustomObject]@{
                    LogId          = 'log-no-errors'
                    Timestamp      = '2025-12-17 10:00:00 UTC'
                    TenantId       = 'tenant-no-errors'
                    SpaceKey       = 'SPACE-NE'
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

        It 'Handles empty Errors array gracefully' {
            $result = Get-ConfluenceSyncStatus
            $result[0].LastError | Should BeNullOrEmpty
        }
    }

    Context 'Null Errors Property' {
        BeforeEach {
            $script:SyncLogCache = @{
                'log-null-errors' = [PSCustomObject]@{
                    LogId          = 'log-null-errors'
                    Timestamp      = '2025-12-17 10:00:00 UTC'
                    TenantId       = 'tenant-null-errors'
                    SpaceKey       = 'SPACE-NUL'
                    Duration       = '00:01:00'
                    OverallStatus  = 'Success'
                    SuccessCount   = 6
                    FailedCount    = 0
                    SkippedCount   = 0
                    UnchangedCount = 0
                    ErrorCount     = 0
                    SyncResults    = @()
                    Errors         = $null
                }
            }
        }

        It 'Handles null Errors property gracefully' {
            $result = Get-ConfluenceSyncStatus
            $result[0].LastError | Should BeNullOrEmpty
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
                'log-2' = [PSCustomObject]@{
                    LogId          = 'log-2'
                    Timestamp      = '2025-12-17 11:00:00 UTC'
                    TenantId       = 'tenant-b'
                    SpaceKey       = 'SPACE-B'
                    Duration       = '00:00:45'
                    OverallStatus  = 'Failed'
                    SuccessCount   = 0
                    FailedCount    = 6
                    SkippedCount   = 0
                    UnchangedCount = 0
                    ErrorCount     = 6
                    SyncResults    = @()
                    Errors         = @([PSCustomObject]@{ DataType = 'All'; Error = 'Test error' })
                }
            }
        }

        It 'Writes verbose message when -Verbose is used' {
            $verboseOutput = Get-ConfluenceSyncStatus -Verbose 4>&1
            $verboseOutput | Should Not BeNullOrEmpty
        }

        It 'Verbose output includes tenant count' {
            $verboseOutput = Get-ConfluenceSyncStatus -Verbose 4>&1
            $verboseText = $verboseOutput -join ' '
            $verboseText | Should Match 'tenants'
        }

        It 'Verbose output logs failed tenant status' {
            $verboseOutput = Get-ConfluenceSyncStatus -Verbose 4>&1
            $verboseText = $verboseOutput -join ' '
            $verboseText | Should Match 'tenant-b'
        }
    }

    Context 'Verbose Output on Empty Cache' {
        BeforeEach {
            $script:SyncLogCache = @{}
        }

        It 'Writes verbose message for empty cache' {
            $verboseOutput = Get-ConfluenceSyncStatus -Verbose 4>&1
            $verboseText = $verboseOutput -join ' '
            $verboseText | Should Match '0 tenants'
        }
    }

    Context 'Verbose Output with TenantId Filter' {
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

        It 'Writes verbose message when filtering by TenantId' {
            $verboseOutput = Get-ConfluenceSyncStatus -TenantId 'tenant-a' -Verbose 4>&1
            $verboseText = $verboseOutput -join ' '
            $verboseText | Should Match 'Filtering'
        }

        It 'Writes verbose message when TenantId not found' {
            $verboseOutput = Get-ConfluenceSyncStatus -TenantId 'unknown' -Verbose 4>&1
            $verboseText = $verboseOutput -join ' '
            $verboseText | Should Match 'No sync history found'
        }
    }

    Context 'PSCustomObject Return Type' {
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

        It 'Returns PSCustomObject type' {
            $result = Get-ConfluenceSyncStatus
            $result[0].GetType().Name | Should Be 'PSCustomObject'
        }

        It 'Result can be piped to Where-Object' {
            $result = Get-ConfluenceSyncStatus | Where-Object { $_.Status -eq 'Success' }
            @($result).Count | Should Be 1
        }

        It 'Result can be piped to Select-Object' {
            $result = Get-ConfluenceSyncStatus | Select-Object TenantId, Status
            @($result).Count | Should Be 1
            ($result[0].PSObject.Properties.Name -contains 'TenantId') | Should Be $true
            ($result[0].PSObject.Properties.Name -contains 'Status') | Should Be $true
        }
    }

    Context 'Large Dataset Performance' {
        BeforeEach {
            # Create 100 tenants with multiple logs each
            $script:SyncLogCache = @{}
            $logId = 0
            for ($t = 1; $t -le 100; $t++) {
                for ($l = 1; $l -le 5; $l++) {
                    $logId++
                    $timestamp = "2025-12-17 $($l.ToString('00')):00:00 UTC"
                    $script:SyncLogCache["log-$logId"] = [PSCustomObject]@{
                        LogId          = "log-$logId"
                        Timestamp      = $timestamp
                        TenantId       = "tenant-$t"
                        SpaceKey       = "SPACE-$t"
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
        }

        It 'Handles 100 tenants with multiple logs' {
            $result = Get-ConfluenceSyncStatus
            @($result).Count | Should Be 100
        }

        It 'Returns only most recent log per tenant' {
            $result = Get-ConfluenceSyncStatus
            foreach ($status in $result) {
                $status.LastSyncTime | Should Be '2025-12-17 05:00:00 UTC'
            }
        }
    }

    Context 'Summary Parameter (AC3)' {
        BeforeEach {
            $script:SyncLogCache = @{
                'log-1' = [PSCustomObject]@{
                    LogId          = 'log-1'
                    Timestamp      = '2025-12-17 10:00:00 UTC'
                    TenantId       = 'tenant-success-1'
                    SpaceKey       = 'SPACE-S1'
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
                    Timestamp      = '2025-12-17 10:00:00 UTC'
                    TenantId       = 'tenant-success-2'
                    SpaceKey       = 'SPACE-S2'
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
                'log-3' = [PSCustomObject]@{
                    LogId          = 'log-3'
                    Timestamp      = '2025-12-17 10:00:00 UTC'
                    TenantId       = 'tenant-partial'
                    SpaceKey       = 'SPACE-P'
                    Duration       = '00:01:00'
                    OverallStatus  = 'PartialFailure'
                    SuccessCount   = 4
                    FailedCount    = 2
                    SkippedCount   = 0
                    UnchangedCount = 0
                    ErrorCount     = 2
                    SyncResults    = @()
                    Errors         = @([PSCustomObject]@{ DataType = 'Users'; Error = 'Error' })
                }
                'log-4' = [PSCustomObject]@{
                    LogId          = 'log-4'
                    Timestamp      = '2025-12-17 10:00:00 UTC'
                    TenantId       = 'tenant-failed'
                    SpaceKey       = 'SPACE-F'
                    Duration       = '00:01:00'
                    OverallStatus  = 'Failed'
                    SuccessCount   = 0
                    FailedCount    = 6
                    SkippedCount   = 0
                    UnchangedCount = 0
                    ErrorCount     = 6
                    SyncResults    = @()
                    Errors         = @([PSCustomObject]@{ DataType = 'All'; Error = 'Error' })
                }
            }
        }

        It 'Returns summary object when -Summary is specified' {
            $result = Get-ConfluenceSyncStatus -Summary
            $result | Should Not BeNullOrEmpty
            $result.GetType().Name | Should Be 'PSCustomObject'
        }

        It 'Summary has TotalTenants property' {
            $result = Get-ConfluenceSyncStatus -Summary
            ($result.PSObject.Properties.Name -contains 'TotalTenants') | Should Be $true
        }

        It 'Summary has SuccessCount property' {
            $result = Get-ConfluenceSyncStatus -Summary
            ($result.PSObject.Properties.Name -contains 'SuccessCount') | Should Be $true
        }

        It 'Summary has PartialFailureCount property' {
            $result = Get-ConfluenceSyncStatus -Summary
            ($result.PSObject.Properties.Name -contains 'PartialFailureCount') | Should Be $true
        }

        It 'Summary has FailedCount property' {
            $result = Get-ConfluenceSyncStatus -Summary
            ($result.PSObject.Properties.Name -contains 'FailedCount') | Should Be $true
        }

        It 'Summary TotalTenants is correct' {
            $result = Get-ConfluenceSyncStatus -Summary
            $result.TotalTenants | Should Be 4
        }

        It 'Summary SuccessCount is correct' {
            $result = Get-ConfluenceSyncStatus -Summary
            $result.SuccessCount | Should Be 2
        }

        It 'Summary PartialFailureCount is correct' {
            $result = Get-ConfluenceSyncStatus -Summary
            $result.PartialFailureCount | Should Be 1
        }

        It 'Summary FailedCount is correct' {
            $result = Get-ConfluenceSyncStatus -Summary
            $result.FailedCount | Should Be 1
        }

        It 'Summary returns zeros for empty cache' {
            $script:SyncLogCache = @{}
            $result = Get-ConfluenceSyncStatus -Summary
            $result.TotalTenants | Should Be 0
            $result.SuccessCount | Should Be 0
            $result.PartialFailureCount | Should Be 0
            $result.FailedCount | Should Be 0
        }

        It 'Summary with TenantId filter returns correct counts' {
            $result = Get-ConfluenceSyncStatus -TenantId 'tenant-success-1' -Summary
            $result.TotalTenants | Should Be 1
            $result.SuccessCount | Should Be 1
        }

        It 'Summary with unknown TenantId returns zeros' {
            $result = Get-ConfluenceSyncStatus -TenantId 'unknown' -Summary
            $result.TotalTenants | Should Be 0
        }
    }

    Context 'Never Synced Status (AC4)' {
        BeforeEach {
            # Only tenant-a has sync history
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

            # Mock Get-ConfluenceTenantMapping to return tenants (both synced and unsynced)
            function global:Get-ConfluenceTenantMapping {
                @(
                    [PSCustomObject]@{ TenantId = 'tenant-a'; SpaceKey = 'SPACE-A'; SpaceName = 'Tenant A' }
                    [PSCustomObject]@{ TenantId = 'tenant-never'; SpaceKey = 'SPACE-NEVER'; SpaceName = 'Never Synced Tenant' }
                    [PSCustomObject]@{ TenantId = 'tenant-also-never'; SpaceKey = 'SPACE-ALSO'; SpaceName = 'Also Never Synced' }
                )
            }
        }

        AfterEach {
            # Clean up mock
            Remove-Item Function:\Get-ConfluenceTenantMapping -ErrorAction SilentlyContinue
        }

        It 'Without IncludeNeverSynced returns only synced tenants' {
            $result = Get-ConfluenceSyncStatus
            @($result).Count | Should Be 1
            $result[0].TenantId | Should Be 'tenant-a'
        }

        It 'With IncludeNeverSynced includes never-synced tenants' {
            $result = Get-ConfluenceSyncStatus -IncludeNeverSynced
            @($result).Count | Should Be 3
        }

        It 'Never-synced tenants have Status of Never' {
            $result = Get-ConfluenceSyncStatus -IncludeNeverSynced
            $neverTenant = $result | Where-Object { $_.TenantId -eq 'tenant-never' }
            $neverTenant.Status | Should Be 'Never'
        }

        It 'Never-synced tenants have null LastSyncTime' {
            $result = Get-ConfluenceSyncStatus -IncludeNeverSynced
            $neverTenant = $result | Where-Object { $_.TenantId -eq 'tenant-never' }
            $neverTenant.LastSyncTime | Should BeNullOrEmpty
        }

        It 'Never-synced tenants have null Duration' {
            $result = Get-ConfluenceSyncStatus -IncludeNeverSynced
            $neverTenant = $result | Where-Object { $_.TenantId -eq 'tenant-never' }
            $neverTenant.Duration | Should BeNullOrEmpty
        }

        It 'Never-synced tenants have zero counts' {
            $result = Get-ConfluenceSyncStatus -IncludeNeverSynced
            $neverTenant = $result | Where-Object { $_.TenantId -eq 'tenant-never' }
            $neverTenant.SuccessCount | Should Be 0
            $neverTenant.FailedCount | Should Be 0
            $neverTenant.SkippedCount | Should Be 0
            $neverTenant.UnchangedCount | Should Be 0
            $neverTenant.ErrorCount | Should Be 0
        }

        It 'Never-synced tenants have null LastError' {
            $result = Get-ConfluenceSyncStatus -IncludeNeverSynced
            $neverTenant = $result | Where-Object { $_.TenantId -eq 'tenant-never' }
            $neverTenant.LastError | Should BeNullOrEmpty
        }

        It 'Never-synced tenants preserve SpaceKey from mapping' {
            $result = Get-ConfluenceSyncStatus -IncludeNeverSynced
            $neverTenant = $result | Where-Object { $_.TenantId -eq 'tenant-never' }
            $neverTenant.SpaceKey | Should Be 'SPACE-NEVER'
        }

        It 'TenantId filter works with never-synced tenants' {
            $result = Get-ConfluenceSyncStatus -TenantId 'tenant-never' -IncludeNeverSynced
            @($result).Count | Should Be 1
            $result.TenantId | Should Be 'tenant-never'
            $result.Status | Should Be 'Never'
        }

        It 'Summary includes NeverSyncedCount' {
            $result = Get-ConfluenceSyncStatus -Summary -IncludeNeverSynced
            ($result.PSObject.Properties.Name -contains 'NeverSyncedCount') | Should Be $true
        }

        It 'Summary NeverSyncedCount is correct' {
            $result = Get-ConfluenceSyncStatus -Summary -IncludeNeverSynced
            $result.NeverSyncedCount | Should Be 2
        }

        It 'Summary TotalTenants includes never-synced with IncludeNeverSynced' {
            $result = Get-ConfluenceSyncStatus -Summary -IncludeNeverSynced
            $result.TotalTenants | Should Be 3
        }
    }

    Context 'Never Synced with Empty Sync Cache' {
        BeforeEach {
            $script:SyncLogCache = @{}

            function global:Get-ConfluenceTenantMapping {
                @(
                    [PSCustomObject]@{ TenantId = 'tenant-never-1'; SpaceKey = 'SPACE-N1'; SpaceName = 'Never 1' }
                    [PSCustomObject]@{ TenantId = 'tenant-never-2'; SpaceKey = 'SPACE-N2'; SpaceName = 'Never 2' }
                )
            }
        }

        AfterEach {
            Remove-Item Function:\Get-ConfluenceTenantMapping -ErrorAction SilentlyContinue
        }

        It 'Returns never-synced tenants even with empty cache' {
            $result = Get-ConfluenceSyncStatus -IncludeNeverSynced
            @($result).Count | Should Be 2
        }

        It 'All tenants have Never status when cache is empty' {
            $result = Get-ConfluenceSyncStatus -IncludeNeverSynced
            foreach ($tenant in $result) {
                $tenant.Status | Should Be 'Never'
            }
        }

        It 'Summary shows all as never-synced' {
            $result = Get-ConfluenceSyncStatus -Summary -IncludeNeverSynced
            $result.TotalTenants | Should Be 2
            $result.NeverSyncedCount | Should Be 2
            $result.SuccessCount | Should Be 0
        }
    }

    Context 'IncludeNeverSynced Without Mapping Function' {
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

            # Remove the mapping function if it exists
            Remove-Item Function:\Get-ConfluenceTenantMapping -ErrorAction SilentlyContinue
        }

        It 'Gracefully handles missing mapping function' {
            { Get-ConfluenceSyncStatus -IncludeNeverSynced } | Should Not Throw
        }

        It 'Returns only synced tenants when mapping function unavailable' {
            $result = Get-ConfluenceSyncStatus -IncludeNeverSynced
            @($result).Count | Should Be 1
        }
    }
}
