$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleRoot = Split-Path -Parent (Split-Path -Parent $here)
$publicDir = Join-Path $moduleRoot 'Public'

Describe 'Get-ConfluenceSyncConfiguration' {
    BeforeAll {
        . "$publicDir\Set-ConfluenceSyncConfiguration.ps1"
        . "$publicDir\Get-ConfluenceSyncConfiguration.ps1"
        . "$publicDir\Remove-ConfluenceSyncConfiguration.ps1"
    }

    BeforeEach {
        # Clear config before each test
        $script:ConfluenceSyncConfiguration = $null
    }

    Context 'Returns Stored Configuration' {
        It 'Returns stored SyncFrequency when set' {
            Set-ConfluenceSyncConfiguration -SyncFrequency 'Weekly'
            $result = Get-ConfluenceSyncConfiguration
            $result.SyncFrequency | Should Be 'Weekly'
        }

        It 'Returns stored RetryAttempts when set' {
            Set-ConfluenceSyncConfiguration -RetryAttempts 5
            $result = Get-ConfluenceSyncConfiguration
            $result.RetryAttempts | Should Be 5
        }

        It 'Returns stored RetryDelaySeconds when set' {
            Set-ConfluenceSyncConfiguration -RetryDelaySeconds 60
            $result = Get-ConfluenceSyncConfiguration
            $result.RetryDelaySeconds | Should Be 60
        }

        It 'Returns stored EnableIncrementalSync when set' {
            Set-ConfluenceSyncConfiguration -EnableIncrementalSync $true
            $result = Get-ConfluenceSyncConfiguration
            $result.EnableIncrementalSync | Should Be $true
        }

        It 'Returns stored ConfiguredAt timestamp' {
            Set-ConfluenceSyncConfiguration -SyncFrequency 'Daily'
            $result = Get-ConfluenceSyncConfiguration
            $result.ConfiguredAt | Should Not Be $null
        }

        It 'Returns all stored settings together' {
            Set-ConfluenceSyncConfiguration -SyncFrequency 'Weekly' -RetryAttempts 7 -RetryDelaySeconds 45 -EnableIncrementalSync $true
            $result = Get-ConfluenceSyncConfiguration
            $result.SyncFrequency | Should Be 'Weekly'
            $result.RetryAttempts | Should Be 7
            $result.RetryDelaySeconds | Should Be 45
            $result.EnableIncrementalSync | Should Be $true
        }
    }

    Context 'Default Values When No Configuration Set' {
        It 'Returns PSCustomObject when no configuration set' {
            $result = Get-ConfluenceSyncConfiguration
            $result | Should Not Be $null
        }

        It 'Default SyncFrequency is Manual' {
            $result = Get-ConfluenceSyncConfiguration
            $result.SyncFrequency | Should Be 'Manual'
        }

        It 'Default RetryAttempts is 3' {
            $result = Get-ConfluenceSyncConfiguration
            $result.RetryAttempts | Should Be 3
        }

        It 'Default RetryDelaySeconds is 30' {
            $result = Get-ConfluenceSyncConfiguration
            $result.RetryDelaySeconds | Should Be 30
        }

        It 'Default EnableIncrementalSync is false' {
            $result = Get-ConfluenceSyncConfiguration
            $result.EnableIncrementalSync | Should Be $false
        }

        It 'Default ConfiguredAt is null' {
            $result = Get-ConfluenceSyncConfiguration
            $result.ConfiguredAt | Should Be $null
        }

        It 'Returns all default properties' {
            $result = Get-ConfluenceSyncConfiguration
            $result.PSObject.Properties.Name -contains 'SyncFrequency' | Should Be $true
            $result.PSObject.Properties.Name -contains 'RetryAttempts' | Should Be $true
            $result.PSObject.Properties.Name -contains 'RetryDelaySeconds' | Should Be $true
            $result.PSObject.Properties.Name -contains 'EnableIncrementalSync' | Should Be $true
            $result.PSObject.Properties.Name -contains 'ConfiguredAt' | Should Be $true
        }
    }

    Context 'Verbose Logging' {
        It 'Writes verbose message when retrieving configuration' {
            $verboseOutput = Get-ConfluenceSyncConfiguration -Verbose 4>&1
            $verboseMessages = $verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }
            $verboseMessages.Count | Should BeGreaterThan 0
        }

        It 'Writes verbose message indicating stored config returned' {
            Set-ConfluenceSyncConfiguration -SyncFrequency 'Daily'
            $verboseOutput = Get-ConfluenceSyncConfiguration -Verbose 4>&1
            $verboseText = ($verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }) -join ' '
            $verboseText | Should Match 'stored'
        }

        It 'Writes verbose message indicating defaults returned when no config' {
            $verboseOutput = Get-ConfluenceSyncConfiguration -Verbose 4>&1
            $verboseText = ($verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }) -join ' '
            $verboseText | Should Match 'defaults'
        }
    }

    Context 'Output Type' {
        It 'Returns PSCustomObject type' {
            $result = Get-ConfluenceSyncConfiguration
            $result.GetType().Name | Should Be 'PSCustomObject'
        }

        It 'Returns object with five properties' {
            $result = Get-ConfluenceSyncConfiguration
            @($result.PSObject.Properties).Count | Should Be 5
        }
    }

    Context 'Idempotent Behavior' {
        It 'Multiple calls return same defaults' {
            $result1 = Get-ConfluenceSyncConfiguration
            $result2 = Get-ConfluenceSyncConfiguration
            $result1.SyncFrequency | Should Be $result2.SyncFrequency
            $result1.RetryAttempts | Should Be $result2.RetryAttempts
        }

        It 'Multiple calls return same stored config' {
            Set-ConfluenceSyncConfiguration -SyncFrequency 'Weekly' -RetryAttempts 5
            $result1 = Get-ConfluenceSyncConfiguration
            $result2 = Get-ConfluenceSyncConfiguration
            $result1.SyncFrequency | Should Be $result2.SyncFrequency
            $result1.RetryAttempts | Should Be $result2.RetryAttempts
        }
    }
}
