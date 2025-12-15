$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleRoot = Split-Path -Parent (Split-Path -Parent $here)
$publicDir = Join-Path $moduleRoot 'Public'

Describe 'Remove-ConfluenceSyncConfiguration' {
    BeforeAll {
        . "$publicDir\Set-ConfluenceSyncConfiguration.ps1"
        . "$publicDir\Get-ConfluenceSyncConfiguration.ps1"
        . "$publicDir\Remove-ConfluenceSyncConfiguration.ps1"
    }

    BeforeEach {
        # Clear config before each test
        $script:ConfluenceSyncConfiguration = $null
    }

    Context 'Clear Configuration' {
        It 'Clears script scope variable' {
            Set-ConfluenceSyncConfiguration -SyncFrequency 'Daily'
            Remove-ConfluenceSyncConfiguration
            $script:ConfluenceSyncConfiguration | Should Be $null
        }

        It 'Clears all stored settings' {
            Set-ConfluenceSyncConfiguration -SyncFrequency 'Weekly' -RetryAttempts 7 -RetryDelaySeconds 60 -EnableIncrementalSync $true
            Remove-ConfluenceSyncConfiguration
            $script:ConfluenceSyncConfiguration | Should Be $null
        }

        It 'Get returns defaults after Remove' {
            Set-ConfluenceSyncConfiguration -SyncFrequency 'Weekly' -RetryAttempts 7
            Remove-ConfluenceSyncConfiguration
            $result = Get-ConfluenceSyncConfiguration
            $result.SyncFrequency | Should Be 'Manual'
            $result.RetryAttempts | Should Be 3
        }

        It 'Get returns default SyncFrequency after Remove' {
            Set-ConfluenceSyncConfiguration -SyncFrequency 'Hourly'
            Remove-ConfluenceSyncConfiguration
            $result = Get-ConfluenceSyncConfiguration
            $result.SyncFrequency | Should Be 'Manual'
        }

        It 'Get returns default RetryAttempts after Remove' {
            Set-ConfluenceSyncConfiguration -RetryAttempts 10
            Remove-ConfluenceSyncConfiguration
            $result = Get-ConfluenceSyncConfiguration
            $result.RetryAttempts | Should Be 3
        }

        It 'Get returns default RetryDelaySeconds after Remove' {
            Set-ConfluenceSyncConfiguration -RetryDelaySeconds 100
            Remove-ConfluenceSyncConfiguration
            $result = Get-ConfluenceSyncConfiguration
            $result.RetryDelaySeconds | Should Be 30
        }

        It 'Get returns default EnableIncrementalSync after Remove' {
            Set-ConfluenceSyncConfiguration -EnableIncrementalSync $true
            Remove-ConfluenceSyncConfiguration
            $result = Get-ConfluenceSyncConfiguration
            $result.EnableIncrementalSync | Should Be $false
        }

        It 'Get returns null ConfiguredAt after Remove' {
            Set-ConfluenceSyncConfiguration -SyncFrequency 'Daily'
            Remove-ConfluenceSyncConfiguration
            $result = Get-ConfluenceSyncConfiguration
            $result.ConfiguredAt | Should Be $null
        }
    }

    Context 'WhatIf Support' {
        It 'Does not clear configuration with WhatIf' {
            Set-ConfluenceSyncConfiguration -SyncFrequency 'Daily'
            Remove-ConfluenceSyncConfiguration -WhatIf
            $script:ConfluenceSyncConfiguration | Should Not Be $null
        }

        It 'Preserves SyncFrequency with WhatIf' {
            Set-ConfluenceSyncConfiguration -SyncFrequency 'Daily'
            Remove-ConfluenceSyncConfiguration -WhatIf
            $script:ConfluenceSyncConfiguration.SyncFrequency | Should Be 'Daily'
        }

        It 'Preserves all settings with WhatIf' {
            Set-ConfluenceSyncConfiguration -SyncFrequency 'Weekly' -RetryAttempts 5 -RetryDelaySeconds 60 -EnableIncrementalSync $true
            Remove-ConfluenceSyncConfiguration -WhatIf
            $script:ConfluenceSyncConfiguration.SyncFrequency | Should Be 'Weekly'
            $script:ConfluenceSyncConfiguration.RetryAttempts | Should Be 5
            $script:ConfluenceSyncConfiguration.RetryDelaySeconds | Should Be 60
            $script:ConfluenceSyncConfiguration.EnableIncrementalSync | Should Be $true
        }

        It 'Get still returns stored config after WhatIf' {
            Set-ConfluenceSyncConfiguration -SyncFrequency 'Hourly'
            Remove-ConfluenceSyncConfiguration -WhatIf
            $result = Get-ConfluenceSyncConfiguration
            $result.SyncFrequency | Should Be 'Hourly'
        }
    }

    Context 'Verbose Logging' {
        It 'Writes verbose message when removing configuration' {
            $verboseOutput = Remove-ConfluenceSyncConfiguration -Verbose 4>&1
            $verboseMessages = $verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }
            $verboseMessages.Count | Should BeGreaterThan 0
        }

        It 'Writes verbose message indicating removal' {
            $verboseOutput = Remove-ConfluenceSyncConfiguration -Verbose 4>&1
            $verboseText = ($verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }) -join ' '
            $verboseText | Should Match '[Rr]emov'
        }

        It 'Writes verbose message indicating cleared' {
            Set-ConfluenceSyncConfiguration -SyncFrequency 'Daily'
            $verboseOutput = Remove-ConfluenceSyncConfiguration -Verbose 4>&1
            $verboseText = ($verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }) -join ' '
            $verboseText | Should Match 'cleared'
        }
    }

    Context 'Idempotent Behavior' {
        It 'Can be called multiple times without error' {
            { Remove-ConfluenceSyncConfiguration } | Should Not Throw
            { Remove-ConfluenceSyncConfiguration } | Should Not Throw
        }

        It 'Removes config that was set after previous Remove' {
            Set-ConfluenceSyncConfiguration -SyncFrequency 'Daily'
            Remove-ConfluenceSyncConfiguration
            Set-ConfluenceSyncConfiguration -SyncFrequency 'Weekly'
            Remove-ConfluenceSyncConfiguration
            $script:ConfluenceSyncConfiguration | Should Be $null
        }
    }

    Context 'No Configuration Set' {
        It 'Does not throw when no configuration exists' {
            { Remove-ConfluenceSyncConfiguration } | Should Not Throw
        }

        It 'Script variable is null after Remove when no config was set' {
            Remove-ConfluenceSyncConfiguration
            $script:ConfluenceSyncConfiguration | Should Be $null
        }
    }
}
