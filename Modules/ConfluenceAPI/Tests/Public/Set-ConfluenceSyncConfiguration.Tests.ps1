$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleRoot = Split-Path -Parent (Split-Path -Parent $here)
$publicDir = Join-Path $moduleRoot 'Public'

Describe 'Set-ConfluenceSyncConfiguration' {
    BeforeAll {
        . "$publicDir\Set-ConfluenceSyncConfiguration.ps1"
        . "$publicDir\Get-ConfluenceSyncConfiguration.ps1"
        . "$publicDir\Remove-ConfluenceSyncConfiguration.ps1"
    }

    BeforeEach {
        # Clear config before each test
        $script:ConfluenceSyncConfiguration = $null
    }

    Context 'Basic Configuration' {
        It 'Stores SyncFrequency in script scope variable' {
            Set-ConfluenceSyncConfiguration -SyncFrequency 'Daily'
            $script:ConfluenceSyncConfiguration.SyncFrequency | Should Be 'Daily'
        }

        It 'Stores RetryAttempts in script scope variable' {
            Set-ConfluenceSyncConfiguration -RetryAttempts 5
            $script:ConfluenceSyncConfiguration.RetryAttempts | Should Be 5
        }

        It 'Stores RetryDelaySeconds in script scope variable' {
            Set-ConfluenceSyncConfiguration -RetryDelaySeconds 60
            $script:ConfluenceSyncConfiguration.RetryDelaySeconds | Should Be 60
        }

        It 'Stores EnableIncrementalSync in script scope variable' {
            Set-ConfluenceSyncConfiguration -EnableIncrementalSync $true
            $script:ConfluenceSyncConfiguration.EnableIncrementalSync | Should Be $true
        }

        It 'Returns PSCustomObject with expected properties' {
            $result = Set-ConfluenceSyncConfiguration -SyncFrequency 'Weekly'
            $result | Should Not Be $null
            $result.SyncFrequency | Should Be 'Weekly'
            $result.RetryAttempts | Should Be 3
            $result.RetryDelaySeconds | Should Be 30
            $result.EnableIncrementalSync | Should Be $false
            $result.ConfiguredAt | Should Not Be $null
        }

        It 'Includes ConfiguredAt timestamp in result' {
            $result = Set-ConfluenceSyncConfiguration -RetryAttempts 5
            $result.ConfiguredAt | Should Match '\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} UTC'
        }

        It 'ConfiguredAt timestamp is in UTC format' {
            $result = Set-ConfluenceSyncConfiguration -SyncFrequency 'Hourly'
            $result.ConfiguredAt | Should Match 'UTC$'
        }
    }

    Context 'Validation' {
        It 'Validates SyncFrequency accepts Hourly' {
            { Set-ConfluenceSyncConfiguration -SyncFrequency 'Hourly' } | Should Not Throw
        }

        It 'Validates SyncFrequency accepts Daily' {
            { Set-ConfluenceSyncConfiguration -SyncFrequency 'Daily' } | Should Not Throw
        }

        It 'Validates SyncFrequency accepts Weekly' {
            { Set-ConfluenceSyncConfiguration -SyncFrequency 'Weekly' } | Should Not Throw
        }

        It 'Validates SyncFrequency accepts Manual' {
            { Set-ConfluenceSyncConfiguration -SyncFrequency 'Manual' } | Should Not Throw
        }

        It 'Validates SyncFrequency rejects invalid values' {
            { Set-ConfluenceSyncConfiguration -SyncFrequency 'Invalid' } | Should Throw
        }

        It 'Validates RetryAttempts accepts minimum value 1' {
            { Set-ConfluenceSyncConfiguration -RetryAttempts 1 } | Should Not Throw
        }

        It 'Validates RetryAttempts accepts maximum value 10' {
            { Set-ConfluenceSyncConfiguration -RetryAttempts 10 } | Should Not Throw
        }

        It 'Validates RetryAttempts rejects value below range' {
            { Set-ConfluenceSyncConfiguration -RetryAttempts 0 } | Should Throw
        }

        It 'Validates RetryAttempts rejects value above range' {
            { Set-ConfluenceSyncConfiguration -RetryAttempts 11 } | Should Throw
        }

        It 'Validates RetryDelaySeconds accepts minimum value 5' {
            { Set-ConfluenceSyncConfiguration -RetryDelaySeconds 5 } | Should Not Throw
        }

        It 'Validates RetryDelaySeconds accepts maximum value 300' {
            { Set-ConfluenceSyncConfiguration -RetryDelaySeconds 300 } | Should Not Throw
        }

        It 'Validates RetryDelaySeconds rejects value below range' {
            { Set-ConfluenceSyncConfiguration -RetryDelaySeconds 4 } | Should Throw
        }

        It 'Validates RetryDelaySeconds rejects value above range' {
            { Set-ConfluenceSyncConfiguration -RetryDelaySeconds 301 } | Should Throw
        }
    }

    Context 'Partial Updates (Merge Behavior)' {
        It 'Merges new SyncFrequency with existing config' {
            Set-ConfluenceSyncConfiguration -SyncFrequency 'Daily'
            Set-ConfluenceSyncConfiguration -RetryAttempts 5
            $result = Get-ConfluenceSyncConfiguration
            $result.SyncFrequency | Should Be 'Daily'
            $result.RetryAttempts | Should Be 5
        }

        It 'Preserves SyncFrequency when updating RetryAttempts' {
            Set-ConfluenceSyncConfiguration -SyncFrequency 'Weekly' -RetryAttempts 7
            Set-ConfluenceSyncConfiguration -EnableIncrementalSync $true
            $result = Get-ConfluenceSyncConfiguration
            $result.SyncFrequency | Should Be 'Weekly'
            $result.RetryAttempts | Should Be 7
            $result.EnableIncrementalSync | Should Be $true
        }

        It 'Preserves RetryDelaySeconds when updating other settings' {
            Set-ConfluenceSyncConfiguration -RetryDelaySeconds 100
            Set-ConfluenceSyncConfiguration -SyncFrequency 'Hourly'
            $result = Get-ConfluenceSyncConfiguration
            $result.RetryDelaySeconds | Should Be 100
            $result.SyncFrequency | Should Be 'Hourly'
        }

        It 'Updates ConfiguredAt timestamp on each change' {
            $result1 = Set-ConfluenceSyncConfiguration -SyncFrequency 'Daily'
            Start-Sleep -Seconds 1
            $result2 = Set-ConfluenceSyncConfiguration -RetryAttempts 5
            $result2.ConfiguredAt | Should Not Be $null
            $result2.ConfiguredAt | Should Not Be $result1.ConfiguredAt
        }
    }

    Context 'WhatIf Support' {
        It 'Does not change configuration with WhatIf' {
            Set-ConfluenceSyncConfiguration -SyncFrequency 'Daily' -WhatIf
            $script:ConfluenceSyncConfiguration | Should Be $null
        }

        It 'Does not modify existing configuration with WhatIf' {
            Set-ConfluenceSyncConfiguration -SyncFrequency 'Daily'
            Set-ConfluenceSyncConfiguration -SyncFrequency 'Weekly' -WhatIf
            $script:ConfluenceSyncConfiguration.SyncFrequency | Should Be 'Daily'
        }

        It 'Returns what would be set with WhatIf' {
            $result = Set-ConfluenceSyncConfiguration -SyncFrequency 'Hourly' -WhatIf
            $result.SyncFrequency | Should Be 'Hourly'
        }

        It 'WhatIf result includes all default values' {
            $result = Set-ConfluenceSyncConfiguration -SyncFrequency 'Weekly' -WhatIf
            $result.RetryAttempts | Should Be 3
            $result.RetryDelaySeconds | Should Be 30
            $result.EnableIncrementalSync | Should Be $false
        }
    }

    Context 'Verbose Logging' {
        It 'Writes verbose message for setting configuration' {
            $verboseOutput = Set-ConfluenceSyncConfiguration -SyncFrequency 'Daily' -Verbose 4>&1
            $verboseMessages = $verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }
            $verboseMessages.Count | Should BeGreaterThan 0
        }

        It 'Writes verbose message for SyncFrequency' {
            $verboseOutput = Set-ConfluenceSyncConfiguration -SyncFrequency 'Daily' -Verbose 4>&1
            $verboseText = ($verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }) -join ' '
            $verboseText | Should Match 'SyncFrequency'
        }

        It 'Writes verbose message for RetryAttempts' {
            $verboseOutput = Set-ConfluenceSyncConfiguration -RetryAttempts 5 -Verbose 4>&1
            $verboseText = ($verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }) -join ' '
            $verboseText | Should Match 'RetryAttempts'
        }

        It 'Writes verbose message for successful storage' {
            $verboseOutput = Set-ConfluenceSyncConfiguration -SyncFrequency 'Daily' -Verbose 4>&1
            $verboseText = ($verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }) -join ' '
            $verboseText | Should Match 'stored successfully'
        }
    }

    Context 'Multiple Parameters' {
        It 'Accepts all parameters at once' {
            $result = Set-ConfluenceSyncConfiguration -SyncFrequency 'Weekly' -RetryAttempts 5 -RetryDelaySeconds 60 -EnableIncrementalSync $true
            $result.SyncFrequency | Should Be 'Weekly'
            $result.RetryAttempts | Should Be 5
            $result.RetryDelaySeconds | Should Be 60
            $result.EnableIncrementalSync | Should Be $true
        }

        It 'Stores all parameters in script scope' {
            Set-ConfluenceSyncConfiguration -SyncFrequency 'Hourly' -RetryAttempts 2 -RetryDelaySeconds 10 -EnableIncrementalSync $true
            $script:ConfluenceSyncConfiguration.SyncFrequency | Should Be 'Hourly'
            $script:ConfluenceSyncConfiguration.RetryAttempts | Should Be 2
            $script:ConfluenceSyncConfiguration.RetryDelaySeconds | Should Be 10
            $script:ConfluenceSyncConfiguration.EnableIncrementalSync | Should Be $true
        }
    }

    Context 'EnableIncrementalSync Boolean Handling' {
        It 'Accepts EnableIncrementalSync $true' {
            $result = Set-ConfluenceSyncConfiguration -EnableIncrementalSync $true
            $result.EnableIncrementalSync | Should Be $true
        }

        It 'Accepts EnableIncrementalSync $false' {
            Set-ConfluenceSyncConfiguration -EnableIncrementalSync $true
            $result = Set-ConfluenceSyncConfiguration -EnableIncrementalSync $false
            $result.EnableIncrementalSync | Should Be $false
        }
    }
}
