$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleRoot = Split-Path -Parent (Split-Path -Parent $here)
$privateDir = Join-Path $moduleRoot 'Private'

Describe 'Add-ConfluenceSyncLog' {
    BeforeAll {
        . "$privateDir\Add-ConfluenceSyncLog.ps1"
    }

    BeforeEach {
        # Reset cache for test isolation
        $script:SyncLogCache = @{}
    }

    Context 'Log Entry Creation' {
        It 'Creates a log entry from sync result' {
            $syncResult = [PSCustomObject]@{
                TenantId       = 'tenant-123'
                SpaceKey       = 'SPACE-A'
                Duration       = '00:01:30'
                OverallStatus  = 'Success'
                SuccessCount   = 6
                FailedCount    = 0
                SkippedCount   = 0
                UnchangedCount = 0
                ErrorCount     = 0
                SyncResults    = @()
                Errors         = @()
            }

            Add-ConfluenceSyncLog -SyncResult $syncResult

            $script:SyncLogCache.Count | Should Be 1
        }

        It 'Log entry contains TenantId' {
            $syncResult = [PSCustomObject]@{
                TenantId       = 'tenant-xyz'
                SpaceKey       = 'SPACE-B'
                Duration       = '00:00:45'
                OverallStatus  = 'Success'
                SuccessCount   = 3
                FailedCount    = 0
                SkippedCount   = 3
                UnchangedCount = 0
                ErrorCount     = 0
                SyncResults    = @()
                Errors         = @()
            }

            Add-ConfluenceSyncLog -SyncResult $syncResult

            $logEntry = $script:SyncLogCache.Values | Select-Object -First 1
            $logEntry.TenantId | Should Be 'tenant-xyz'
        }

        It 'Log entry contains SpaceKey' {
            $syncResult = [PSCustomObject]@{
                TenantId       = 'tenant-123'
                SpaceKey       = 'MY-SPACE'
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

            Add-ConfluenceSyncLog -SyncResult $syncResult

            $logEntry = $script:SyncLogCache.Values | Select-Object -First 1
            $logEntry.SpaceKey | Should Be 'MY-SPACE'
        }

        It 'Log entry contains Duration' {
            $syncResult = [PSCustomObject]@{
                TenantId       = 'tenant-123'
                SpaceKey       = 'SPACE-A'
                Duration       = '00:02:15'
                OverallStatus  = 'Success'
                SuccessCount   = 6
                FailedCount    = 0
                SkippedCount   = 0
                UnchangedCount = 0
                ErrorCount     = 0
                SyncResults    = @()
                Errors         = @()
            }

            Add-ConfluenceSyncLog -SyncResult $syncResult

            $logEntry = $script:SyncLogCache.Values | Select-Object -First 1
            $logEntry.Duration | Should Be '00:02:15'
        }

        It 'Log entry contains OverallStatus' {
            $syncResult = [PSCustomObject]@{
                TenantId       = 'tenant-123'
                SpaceKey       = 'SPACE-A'
                Duration       = '00:01:00'
                OverallStatus  = 'PartialFailure'
                SuccessCount   = 4
                FailedCount    = 2
                SkippedCount   = 0
                UnchangedCount = 0
                ErrorCount     = 2
                SyncResults    = @()
                Errors         = @()
            }

            Add-ConfluenceSyncLog -SyncResult $syncResult

            $logEntry = $script:SyncLogCache.Values | Select-Object -First 1
            $logEntry.OverallStatus | Should Be 'PartialFailure'
        }

        It 'Log entry contains status counts' {
            $syncResult = [PSCustomObject]@{
                TenantId       = 'tenant-123'
                SpaceKey       = 'SPACE-A'
                Duration       = '00:01:00'
                OverallStatus  = 'PartialFailure'
                SuccessCount   = 3
                FailedCount    = 1
                SkippedCount   = 1
                UnchangedCount = 1
                ErrorCount     = 1
                SyncResults    = @()
                Errors         = @()
            }

            Add-ConfluenceSyncLog -SyncResult $syncResult

            $logEntry = $script:SyncLogCache.Values | Select-Object -First 1
            $logEntry.SuccessCount | Should Be 3
            $logEntry.FailedCount | Should Be 1
            $logEntry.SkippedCount | Should Be 1
            $logEntry.UnchangedCount | Should Be 1
            $logEntry.ErrorCount | Should Be 1
        }

        It 'Log entry contains unique LogId (GUID format)' {
            $syncResult = [PSCustomObject]@{
                TenantId       = 'tenant-123'
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

            Add-ConfluenceSyncLog -SyncResult $syncResult

            $logEntry = $script:SyncLogCache.Values | Select-Object -First 1
            $logEntry.LogId | Should Not Be $null
            # GUID format: 8-4-4-4-12 hex characters
            $logEntry.LogId -match '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' | Should Be $true
        }

        It 'Log entry contains Timestamp in UTC format' {
            $syncResult = [PSCustomObject]@{
                TenantId       = 'tenant-123'
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

            Add-ConfluenceSyncLog -SyncResult $syncResult

            $logEntry = $script:SyncLogCache.Values | Select-Object -First 1
            $logEntry.Timestamp | Should Not Be $null
            $logEntry.Timestamp -match '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} UTC$' | Should Be $true
        }

        It 'Log entry stores SyncResults array' {
            $syncResults = @(
                [PSCustomObject]@{ DataType = 'Users'; Status = 'Success' }
                [PSCustomObject]@{ DataType = 'Endpoints'; Status = 'Failed' }
            )
            $syncResult = [PSCustomObject]@{
                TenantId       = 'tenant-123'
                SpaceKey       = 'SPACE-A'
                Duration       = '00:01:00'
                OverallStatus  = 'PartialFailure'
                SuccessCount   = 1
                FailedCount    = 1
                SkippedCount   = 0
                UnchangedCount = 0
                ErrorCount     = 1
                SyncResults    = $syncResults
                Errors         = @()
            }

            Add-ConfluenceSyncLog -SyncResult $syncResult

            $logEntry = $script:SyncLogCache.Values | Select-Object -First 1
            @($logEntry.SyncResults).Count | Should Be 2
        }

        It 'Log entry stores Errors array' {
            $errors = @(
                [PSCustomObject]@{ DataType = 'Users'; Error = 'Connection timeout' }
            )
            $syncResult = [PSCustomObject]@{
                TenantId       = 'tenant-123'
                SpaceKey       = 'SPACE-A'
                Duration       = '00:01:00'
                OverallStatus  = 'Failed'
                SuccessCount   = 0
                FailedCount    = 1
                SkippedCount   = 0
                UnchangedCount = 0
                ErrorCount     = 1
                SyncResults    = @()
                Errors         = $errors
            }

            Add-ConfluenceSyncLog -SyncResult $syncResult

            $logEntry = $script:SyncLogCache.Values | Select-Object -First 1
            @($logEntry.Errors).Count | Should Be 1
            $logEntry.Errors[0].Error | Should Be 'Connection timeout'
        }
    }

    Context 'Cache Storage' {
        It 'Log is stored in cache keyed by LogId' {
            $syncResult = [PSCustomObject]@{
                TenantId       = 'tenant-123'
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

            Add-ConfluenceSyncLog -SyncResult $syncResult

            $logEntry = $script:SyncLogCache.Values | Select-Object -First 1
            $script:SyncLogCache[$logEntry.LogId] | Should Not Be $null
        }

        It 'Initializes cache if not exists' {
            $script:SyncLogCache = $null

            $syncResult = [PSCustomObject]@{
                TenantId       = 'tenant-123'
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

            Add-ConfluenceSyncLog -SyncResult $syncResult

            $script:SyncLogCache | Should Not Be $null
            $script:SyncLogCache.Count | Should Be 1
        }
    }

    Context 'Multiple Logs' {
        It 'Multiple logs accumulate in cache' {
            $syncResult1 = [PSCustomObject]@{
                TenantId       = 'tenant-1'
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

            $syncResult2 = [PSCustomObject]@{
                TenantId       = 'tenant-2'
                SpaceKey       = 'SPACE-B'
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

            $syncResult3 = [PSCustomObject]@{
                TenantId       = 'tenant-3'
                SpaceKey       = 'SPACE-C'
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

            Add-ConfluenceSyncLog -SyncResult $syncResult1
            Add-ConfluenceSyncLog -SyncResult $syncResult2
            Add-ConfluenceSyncLog -SyncResult $syncResult3

            $script:SyncLogCache.Count | Should Be 3
        }

        It 'Each log has unique LogId' {
            $syncResult1 = [PSCustomObject]@{
                TenantId       = 'tenant-1'
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

            $syncResult2 = [PSCustomObject]@{
                TenantId       = 'tenant-1'
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

            Add-ConfluenceSyncLog -SyncResult $syncResult1
            Add-ConfluenceSyncLog -SyncResult $syncResult2

            $logs = @($script:SyncLogCache.Values)
            $logs[0].LogId | Should Not Be $logs[1].LogId
        }

        It 'Same tenant can have multiple log entries' {
            $syncResult1 = [PSCustomObject]@{
                TenantId       = 'same-tenant'
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

            $syncResult2 = [PSCustomObject]@{
                TenantId       = 'same-tenant'
                SpaceKey       = 'SPACE-A'
                Duration       = '00:01:00'
                OverallStatus  = 'PartialFailure'
                SuccessCount   = 5
                FailedCount    = 1
                SkippedCount   = 0
                UnchangedCount = 0
                ErrorCount     = 1
                SyncResults    = @()
                Errors         = @()
            }

            Add-ConfluenceSyncLog -SyncResult $syncResult1
            Add-ConfluenceSyncLog -SyncResult $syncResult2

            $tenantLogs = @($script:SyncLogCache.Values | Where-Object { $_.TenantId -eq 'same-tenant' })
            $tenantLogs.Count | Should Be 2
        }
    }

    Context 'Verbose Output' {
        It 'Writes verbose message when -Verbose is used' {
            $syncResult = [PSCustomObject]@{
                TenantId       = 'tenant-123'
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

            $verboseOutput = Add-ConfluenceSyncLog -SyncResult $syncResult -Verbose 4>&1
            $verboseOutput | Should Not Be $null
        }
    }
}
