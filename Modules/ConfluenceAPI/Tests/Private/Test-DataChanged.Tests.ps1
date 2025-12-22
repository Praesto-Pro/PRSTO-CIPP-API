$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleRoot = Split-Path -Parent (Split-Path -Parent $here)
$privateDir = Join-Path $moduleRoot 'Private'

Describe 'Test-DataChanged' {
    BeforeAll {
        . "$privateDir\Get-DataHash.ps1"
        . "$privateDir\Get-SyncStateKey.ps1"
        . "$privateDir\Test-DataChanged.ps1"
    }

    BeforeEach {
        # Reset state cache before each test
        $script:SyncStateCache = @{}
    }

    Context 'First Sync Detection' {
        It 'Returns HasChanged=true for first sync (no previous state)' {
            $data = @([PSCustomObject]@{ Name = 'Test' })
            $result = Test-DataChanged -TenantId 'tenant-1' -DataType 'UserInventory' -InputData $data
            $result.HasChanged | Should Be $true
        }

        It 'Returns IsFirstSync=true for first sync' {
            $data = @([PSCustomObject]@{ Name = 'Test' })
            $result = Test-DataChanged -TenantId 'tenant-1' -DataType 'UserInventory' -InputData $data
            $result.IsFirstSync | Should Be $true
        }

        It 'Returns null PreviousHash for first sync' {
            $data = @([PSCustomObject]@{ Name = 'Test' })
            $result = Test-DataChanged -TenantId 'tenant-1' -DataType 'UserInventory' -InputData $data
            $result.PreviousHash | Should Be $null
        }

        It 'Returns CurrentHash for first sync' {
            $data = @([PSCustomObject]@{ Name = 'Test' })
            $result = Test-DataChanged -TenantId 'tenant-1' -DataType 'UserInventory' -InputData $data
            $result.CurrentHash | Should Not Be $null
            $result.CurrentHash.Length | Should Be 64
        }
    }

    Context 'Change Detection with Existing State' {
        BeforeEach {
            # Seed state with known hash for [PSCustomObject]@{ Name = 'Original' }
            $originalData = @([PSCustomObject]@{ Name = 'Original' })
            $originalHash = (Get-DataHash -InputData $originalData).Hash

            $script:SyncStateCache = @{
                'tenant-1|UserInventory' = @{
                    Hash         = $originalHash
                    LastSyncTime = '2025-12-15 10:00:00 UTC'
                    PageId       = 'page-1'
                }
            }
        }

        It 'Returns HasChanged=true when data changed' {
            $newData = @([PSCustomObject]@{ Name = 'Changed' })
            $result = Test-DataChanged -TenantId 'tenant-1' -DataType 'UserInventory' -InputData $newData
            $result.HasChanged | Should Be $true
        }

        It 'Returns HasChanged=false when data unchanged' {
            $sameData = @([PSCustomObject]@{ Name = 'Original' })
            $result = Test-DataChanged -TenantId 'tenant-1' -DataType 'UserInventory' -InputData $sameData
            $result.HasChanged | Should Be $false
        }

        It 'Returns IsFirstSync=false when state exists' {
            $sameData = @([PSCustomObject]@{ Name = 'Original' })
            $result = Test-DataChanged -TenantId 'tenant-1' -DataType 'UserInventory' -InputData $sameData
            $result.IsFirstSync | Should Be $false
        }

        It 'Returns correct PreviousHash when state exists' {
            $newData = @([PSCustomObject]@{ Name = 'Changed' })
            $result = Test-DataChanged -TenantId 'tenant-1' -DataType 'UserInventory' -InputData $newData

            $originalData = @([PSCustomObject]@{ Name = 'Original' })
            $expectedHash = (Get-DataHash -InputData $originalData).Hash

            $result.PreviousHash | Should Be $expectedHash
        }

        It 'Returns different CurrentHash when data changed' {
            $newData = @([PSCustomObject]@{ Name = 'Changed' })
            $result = Test-DataChanged -TenantId 'tenant-1' -DataType 'UserInventory' -InputData $newData
            $result.CurrentHash | Should Not Be $result.PreviousHash
        }
    }

    Context 'Multi-Tenant Isolation' {
        BeforeEach {
            # Seed state for tenant-1 only
            $originalData = @([PSCustomObject]@{ Name = 'Original' })
            $originalHash = (Get-DataHash -InputData $originalData).Hash

            $script:SyncStateCache = @{
                'tenant-1|UserInventory' = @{
                    Hash         = $originalHash
                    LastSyncTime = '2025-12-15 10:00:00 UTC'
                    PageId       = 'page-1'
                }
            }
        }

        It 'Different tenant has no state (first sync)' {
            $data = @([PSCustomObject]@{ Name = 'Original' })
            $result = Test-DataChanged -TenantId 'tenant-2' -DataType 'UserInventory' -InputData $data
            $result.IsFirstSync | Should Be $true
        }

        It 'Same tenant different data type has no state' {
            $data = @([PSCustomObject]@{ Name = 'Original' })
            $result = Test-DataChanged -TenantId 'tenant-1' -DataType 'EndpointInventory' -InputData $data
            $result.IsFirstSync | Should Be $true
        }
    }

    Context 'Return Object Properties' {
        It 'Returns PSCustomObject with expected properties' {
            $data = @([PSCustomObject]@{ Name = 'Test' })
            $result = Test-DataChanged -TenantId 'tenant-1' -DataType 'UserInventory' -InputData $data
            ($result.PSObject.Properties.Name -contains 'HasChanged') | Should Be $true
            ($result.PSObject.Properties.Name -contains 'CurrentHash') | Should Be $true
            ($result.PSObject.Properties.Name -contains 'PreviousHash') | Should Be $true
            ($result.PSObject.Properties.Name -contains 'IsFirstSync') | Should Be $true
        }
    }

    Context 'Edge Cases' {
        It 'Handles empty array input' {
            $result = Test-DataChanged -TenantId 'tenant-1' -DataType 'UserInventory' -InputData @()
            $result | Should Not Be $null
            $result.CurrentHash | Should Not Be $null
        }

        It 'Handles null input' {
            $result = Test-DataChanged -TenantId 'tenant-1' -DataType 'UserInventory' -InputData $null
            $result | Should Not Be $null
            $result.CurrentHash | Should Not Be $null
        }

        It 'Consistent result for empty vs null' {
            $emptyResult = Test-DataChanged -TenantId 'tenant-1' -DataType 'UserInventory' -InputData @()

            # Reset state to test null
            $script:SyncStateCache = @{}
            $nullResult = Test-DataChanged -TenantId 'tenant-2' -DataType 'UserInventory' -InputData $null

            $emptyResult.CurrentHash | Should Be $nullResult.CurrentHash
        }
    }

    Context 'Verbose Output' {
        It 'Writes verbose messages' {
            $data = @([PSCustomObject]@{ Name = 'Test' })
            $verboseOutput = Test-DataChanged -TenantId 'tenant-1' -DataType 'UserInventory' -InputData $data -Verbose 4>&1
            $verboseOutput | Should Not Be $null
        }

        It 'Logs hash comparison for existing state' {
            # Seed state
            $originalData = @([PSCustomObject]@{ Name = 'Original' })
            $originalHash = (Get-DataHash -InputData $originalData).Hash
            $script:SyncStateCache = @{
                'tenant-1|UserInventory' = @{
                    Hash         = $originalHash
                    LastSyncTime = '2025-12-15 10:00:00 UTC'
                    PageId       = 'page-1'
                }
            }

            $data = @([PSCustomObject]@{ Name = 'Original' })
            $verboseOutput = Test-DataChanged -TenantId 'tenant-1' -DataType 'UserInventory' -InputData $data -Verbose 4>&1
            ($verboseOutput -join ' ') -match 'previous' | Should Be $true
        }
    }
}
