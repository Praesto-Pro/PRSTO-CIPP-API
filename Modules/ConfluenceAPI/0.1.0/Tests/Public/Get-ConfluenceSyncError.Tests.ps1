$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleRoot = Split-Path -Parent (Split-Path -Parent $here)
$publicDir = Join-Path $moduleRoot 'Public'
$privateDir = Join-Path $moduleRoot 'Private'

Describe 'Get-ConfluenceSyncError' {
    BeforeAll {
        . "$publicDir\Get-ConfluenceSyncError.ps1"
        . "$privateDir\Get-SyncErrorCategory.ps1"
    }

    BeforeEach {
        # Reset cache for test isolation
        $script:SyncLogCache = @{}
    }

    Context 'Empty Cache' {
        It 'Returns empty array when no logs exist' {
            $result = Get-ConfluenceSyncError
            @($result).Count | Should Be 0
        }

        It 'Returns empty array when cache is null' {
            $script:SyncLogCache = $null
            $result = Get-ConfluenceSyncError
            @($result).Count | Should Be 0
        }
    }

    Context 'With Errors' {
        BeforeEach {
            # Seed test data with errors
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
                    SyncResults    = @()
                    Errors         = @(
                        [PSCustomObject]@{ DataType = 'UserInventory'; Error = 'Connection timeout after 30 seconds' }
                        [PSCustomObject]@{ DataType = 'EndpointInventory'; Error = '404 Not Found: Space does not exist' }
                    )
                }
                'log-2' = [PSCustomObject]@{
                    LogId          = 'log-2'
                    Timestamp      = '2025-12-17 11:00:00 UTC'
                    TenantId       = 'tenant-b'
                    SpaceKey       = 'SPACE-B'
                    Duration       = '00:00:30'
                    OverallStatus  = 'Failed'
                    SuccessCount   = 0
                    FailedCount    = 6
                    SkippedCount   = 0
                    UnchangedCount = 0
                    ErrorCount     = 1
                    SyncResults    = @()
                    Errors         = @(
                        [PSCustomObject]@{ DataType = 'All'; Error = '403 Forbidden: Permission denied' }
                    )
                }
            }
        }

        It 'Returns all errors when no filter' {
            $result = Get-ConfluenceSyncError
            @($result).Count | Should Be 3
        }

        It 'Filters by TenantId' {
            $result = Get-ConfluenceSyncError -TenantId 'tenant-a'
            @($result).Count | Should Be 2
            foreach ($err in $result) {
                $err.TenantId | Should Be 'tenant-a'
            }
        }

        It 'Filters by TenantId with no matches' {
            $result = Get-ConfluenceSyncError -TenantId 'tenant-nonexistent'
            @($result).Count | Should Be 0
        }

        It 'Limits with -Last parameter' {
            $result = Get-ConfluenceSyncError -Last 2
            @($result).Count | Should Be 2
        }

        It 'Combines TenantId and Last filters' {
            $result = Get-ConfluenceSyncError -TenantId 'tenant-a' -Last 1
            @($result).Count | Should Be 1
            $result[0].TenantId | Should Be 'tenant-a'
        }

        It 'Returns in reverse chronological order' {
            $result = Get-ConfluenceSyncError
            # Newer log (11:00) errors should come first
            $result[0].Timestamp | Should Be '2025-12-17 11:00:00 UTC'
        }

        It 'Assigns ConnectionError category for timeout' {
            $result = Get-ConfluenceSyncError -TenantId 'tenant-a'
            $timeoutError = $result | Where-Object { $_.Message -match 'timeout' }
            $timeoutError.Category | Should Be 'ConnectionError'
        }

        It 'Assigns NotFound category for 404' {
            $result = Get-ConfluenceSyncError -TenantId 'tenant-a'
            $notFoundError = $result | Where-Object { $_.Message -match '404' }
            $notFoundError.Category | Should Be 'NotFound'
        }

        It 'Assigns PermissionDenied category for 403' {
            $result = Get-ConfluenceSyncError -TenantId 'tenant-b'
            $result[0].Category | Should Be 'PermissionDenied'
        }

        It 'Includes TroubleshootingHint for all errors' {
            $result = Get-ConfluenceSyncError
            foreach ($err in $result) {
                $err.TroubleshootingHint | Should Not BeNullOrEmpty
            }
        }

        It 'Returns expected properties' {
            $result = Get-ConfluenceSyncError | Select-Object -First 1
            ($result.PSObject.Properties.Name -contains 'Timestamp') | Should Be $true
            ($result.PSObject.Properties.Name -contains 'TenantId') | Should Be $true
            ($result.PSObject.Properties.Name -contains 'SpaceKey') | Should Be $true
            ($result.PSObject.Properties.Name -contains 'DataType') | Should Be $true
            ($result.PSObject.Properties.Name -contains 'ErrorCode') | Should Be $true
            ($result.PSObject.Properties.Name -contains 'Message') | Should Be $true
            ($result.PSObject.Properties.Name -contains 'Category') | Should Be $true
            ($result.PSObject.Properties.Name -contains 'TroubleshootingHint') | Should Be $true
            ($result.PSObject.Properties.Name -contains 'LogId') | Should Be $true
        }

        It 'Preserves SpaceKey from log entry' {
            $result = Get-ConfluenceSyncError -TenantId 'tenant-a'
            foreach ($err in $result) {
                $err.SpaceKey | Should Be 'SPACE-A'
            }
        }

        It 'Preserves DataType from error entry' {
            $result = Get-ConfluenceSyncError -TenantId 'tenant-a'
            $dataTypes = $result | ForEach-Object { $_.DataType }
            ($dataTypes -contains 'UserInventory') | Should Be $true
            ($dataTypes -contains 'EndpointInventory') | Should Be $true
        }

        It 'Preserves LogId reference' {
            $result = Get-ConfluenceSyncError -TenantId 'tenant-a'
            foreach ($err in $result) {
                $err.LogId | Should Be 'log-1'
            }
        }

        It 'Parses ErrorCode from message with HTTP status' {
            $result = Get-ConfluenceSyncError -TenantId 'tenant-a'
            $notFoundError = $result | Where-Object { $_.Message -match '404' }
            $notFoundError.ErrorCode | Should Be '404'
        }

        It 'Returns null ErrorCode when no HTTP status in message' {
            $result = Get-ConfluenceSyncError -TenantId 'tenant-a'
            $timeoutError = $result | Where-Object { $_.Message -match 'timeout' }
            $timeoutError.ErrorCode | Should BeNullOrEmpty
        }
    }

    Context 'IncludeStackTrace Parameter' {
        BeforeEach {
            $script:SyncLogCache = @{
                'log-1' = [PSCustomObject]@{
                    LogId          = 'log-1'
                    Timestamp      = '2025-12-17 10:00:00 UTC'
                    TenantId       = 'tenant-a'
                    SpaceKey       = 'SPACE-A'
                    Duration       = '00:01:00'
                    OverallStatus  = 'Failed'
                    SuccessCount   = 0
                    FailedCount    = 1
                    SkippedCount   = 0
                    UnchangedCount = 0
                    ErrorCount     = 1
                    SyncResults    = @()
                    Errors         = @(
                        [PSCustomObject]@{
                            DataType    = 'UserInventory'
                            Error       = 'Connection failed'
                            StackTrace  = 'at Invoke-RestMethod, line 123'
                            RawResponse = '{"error": "timeout"}'
                        }
                    )
                }
            }
        }

        It 'Excludes StackTrace by default' {
            $result = Get-ConfluenceSyncError | Select-Object -First 1
            ($result.PSObject.Properties.Name -contains 'StackTrace') | Should Be $false
        }

        It 'Excludes RawResponse by default' {
            $result = Get-ConfluenceSyncError | Select-Object -First 1
            ($result.PSObject.Properties.Name -contains 'RawResponse') | Should Be $false
        }

        It 'Includes StackTrace when switch is set' {
            $result = Get-ConfluenceSyncError -IncludeStackTrace | Select-Object -First 1
            ($result.PSObject.Properties.Name -contains 'StackTrace') | Should Be $true
            $result.StackTrace | Should Be 'at Invoke-RestMethod, line 123'
        }

        It 'Includes RawResponse when switch is set' {
            $result = Get-ConfluenceSyncError -IncludeStackTrace | Select-Object -First 1
            ($result.PSObject.Properties.Name -contains 'RawResponse') | Should Be $true
            $result.RawResponse | Should Be '{"error": "timeout"}'
        }
    }

    Context 'No Errors in Logs' {
        BeforeEach {
            # Logs exist but no errors
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

        It 'Returns empty array when logs have no errors' {
            $result = Get-ConfluenceSyncError
            @($result).Count | Should Be 0
        }
    }

    Context 'Mixed Logs With and Without Errors' {
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
                    OverallStatus  = 'Failed'
                    SuccessCount   = 0
                    FailedCount    = 1
                    SkippedCount   = 0
                    UnchangedCount = 0
                    ErrorCount     = 1
                    SyncResults    = @()
                    Errors         = @(
                        [PSCustomObject]@{ DataType = 'All'; Error = 'Server error 500' }
                    )
                }
            }
        }

        It 'Returns only errors from logs that have them' {
            $result = Get-ConfluenceSyncError
            @($result).Count | Should Be 1
            $result[0].TenantId | Should Be 'tenant-b'
        }
    }

    Context 'Null Errors Array' {
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
                    Errors         = $null
                }
            }
        }

        It 'Handles null Errors array gracefully' {
            $result = Get-ConfluenceSyncError
            @($result).Count | Should Be 0
        }
    }

    Context 'Error Category Distribution' {
        BeforeEach {
            $script:SyncLogCache = @{
                'log-1' = [PSCustomObject]@{
                    LogId          = 'log-1'
                    Timestamp      = '2025-12-17 10:00:00 UTC'
                    TenantId       = 'tenant-a'
                    SpaceKey       = 'SPACE-A'
                    Duration       = '00:01:00'
                    OverallStatus  = 'Failed'
                    SuccessCount   = 0
                    FailedCount    = 6
                    SkippedCount   = 0
                    UnchangedCount = 0
                    ErrorCount     = 6
                    SyncResults    = @()
                    Errors         = @(
                        [PSCustomObject]@{ DataType = 'Type1'; Error = 'Connection timeout' }
                        [PSCustomObject]@{ DataType = 'Type2'; Error = '404 Not found' }
                        [PSCustomObject]@{ DataType = 'Type3'; Error = 'Rate limit exceeded' }
                        [PSCustomObject]@{ DataType = 'Type4'; Error = 'Permission denied' }
                        [PSCustomObject]@{ DataType = 'Type5'; Error = 'Invalid format' }
                        [PSCustomObject]@{ DataType = 'Type6'; Error = 'Server error 500' }
                    )
                }
            }
        }

        It 'Correctly classifies ConnectionError' {
            $result = Get-ConfluenceSyncError
            $errItem = $result | Where-Object { $_.Message -match 'timeout' }
            $errItem.Category | Should Be 'ConnectionError'
        }

        It 'Correctly classifies NotFound' {
            $result = Get-ConfluenceSyncError
            $errItem = $result | Where-Object { $_.Message -match '404' }
            $errItem.Category | Should Be 'NotFound'
        }

        It 'Correctly classifies RateLimit' {
            $result = Get-ConfluenceSyncError
            $errItem = $result | Where-Object { $_.Message -match 'Rate limit' }
            $errItem.Category | Should Be 'RateLimit'
        }

        It 'Correctly classifies PermissionDenied' {
            $result = Get-ConfluenceSyncError
            $errItem = $result | Where-Object { $_.Message -match 'Permission denied' }
            $errItem.Category | Should Be 'PermissionDenied'
        }

        It 'Correctly classifies ValidationError' {
            $result = Get-ConfluenceSyncError
            $errItem = $result | Where-Object { $_.Message -match 'Invalid' }
            $errItem.Category | Should Be 'ValidationError'
        }

        It 'Correctly classifies ServerError' {
            $result = Get-ConfluenceSyncError
            $errItem = $result | Where-Object { $_.Message -match 'Server error' }
            $errItem.Category | Should Be 'ServerError'
        }
    }

    Context 'Last Parameter Validation' {
        BeforeEach {
            $script:SyncLogCache = @{
                'log-1' = [PSCustomObject]@{
                    LogId          = 'log-1'
                    Timestamp      = '2025-12-17 10:00:00 UTC'
                    TenantId       = 'tenant-a'
                    SpaceKey       = 'SPACE-A'
                    Duration       = '00:01:00'
                    OverallStatus  = 'Failed'
                    SuccessCount   = 0
                    FailedCount    = 3
                    SkippedCount   = 0
                    UnchangedCount = 0
                    ErrorCount     = 3
                    SyncResults    = @()
                    Errors         = @(
                        [PSCustomObject]@{ DataType = 'Type1'; Error = 'Error 1' }
                        [PSCustomObject]@{ DataType = 'Type2'; Error = 'Error 2' }
                        [PSCustomObject]@{ DataType = 'Type3'; Error = 'Error 3' }
                    )
                }
            }
        }

        It 'Returns requested count when less than available' {
            $result = Get-ConfluenceSyncError -Last 2
            @($result).Count | Should Be 2
        }

        It 'Returns all when Last exceeds available' {
            $result = Get-ConfluenceSyncError -Last 100
            @($result).Count | Should Be 3
        }

        It 'Returns 1 when Last is 1' {
            $result = Get-ConfluenceSyncError -Last 1
            @($result).Count | Should Be 1
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
                    OverallStatus  = 'Failed'
                    SuccessCount   = 0
                    FailedCount    = 1
                    SkippedCount   = 0
                    UnchangedCount = 0
                    ErrorCount     = 1
                    SyncResults    = @()
                    Errors         = @(
                        [PSCustomObject]@{ DataType = 'Type1'; Error = 'Error 1' }
                    )
                }
            }
        }

        It 'Outputs verbose messages when -Verbose is used' {
            $verboseOutput = Get-ConfluenceSyncError -TenantId 'tenant-a' -Verbose 4>&1
            $verboseMessages = @($verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] })
            @($verboseMessages).Count | Should BeGreaterThan 0
        }
    }
}
