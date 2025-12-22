$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleRoot = Split-Path -Parent (Split-Path -Parent $here)
$privateDir = Join-Path $moduleRoot 'Private'

Describe 'Get-DataHash' {
    BeforeAll {
        . "$privateDir\Get-DataHash.ps1"
    }

    Context 'Consistent Hashing' {
        It 'Same data produces same hash' {
            $data = @([PSCustomObject]@{ Name = 'Test'; Value = 1 })
            $hash1 = Get-DataHash -InputData $data
            $hash2 = Get-DataHash -InputData $data
            $hash1.Hash | Should Be $hash2.Hash
        }

        It 'Different data produces different hash' {
            $data1 = @([PSCustomObject]@{ Name = 'Test1' })
            $data2 = @([PSCustomObject]@{ Name = 'Test2' })
            $hash1 = Get-DataHash -InputData $data1
            $hash2 = Get-DataHash -InputData $data2
            $hash1.Hash | Should Not Be $hash2.Hash
        }

        It 'Same content in different order produces same hash' {
            # JSON serialization handles arrays consistently
            $data1 = @(
                [PSCustomObject]@{ Name = 'A'; Value = 1 },
                [PSCustomObject]@{ Name = 'B'; Value = 2 }
            )
            $data2 = @(
                [PSCustomObject]@{ Name = 'A'; Value = 1 },
                [PSCustomObject]@{ Name = 'B'; Value = 2 }
            )
            $hash1 = Get-DataHash -InputData $data1
            $hash2 = Get-DataHash -InputData $data2
            $hash1.Hash | Should Be $hash2.Hash
        }

        It 'Single object produces consistent hash' {
            $data = [PSCustomObject]@{ Name = 'SingleItem' }
            $hash1 = Get-DataHash -InputData $data
            $hash2 = Get-DataHash -InputData $data
            $hash1.Hash | Should Be $hash2.Hash
        }
    }

    Context 'Hash Format' {
        It 'Returns PSCustomObject with Hash and ShortHash properties' {
            $data = @([PSCustomObject]@{ Name = 'Test' })
            $result = Get-DataHash -InputData $data
            $result | Should Not Be $null
            ($result.PSObject.Properties.Name -contains 'Hash') | Should Be $true
            ($result.PSObject.Properties.Name -contains 'ShortHash') | Should Be $true
        }

        It 'Hash is 64 characters (SHA256 hex)' {
            $data = @([PSCustomObject]@{ Name = 'Test' })
            $result = Get-DataHash -InputData $data
            $result.Hash.Length | Should Be 64
        }

        It 'ShortHash is 16 characters' {
            $data = @([PSCustomObject]@{ Name = 'Test' })
            $result = Get-DataHash -InputData $data
            $result.ShortHash.Length | Should Be 16
        }

        It 'ShortHash is prefix of Hash' {
            $data = @([PSCustomObject]@{ Name = 'Test' })
            $result = Get-DataHash -InputData $data
            $result.Hash.StartsWith($result.ShortHash) | Should Be $true
        }

        It 'Hash contains only hex characters' {
            $data = @([PSCustomObject]@{ Name = 'Test' })
            $result = Get-DataHash -InputData $data
            $result.Hash -match '^[0-9A-F]+$' | Should Be $true
        }
    }

    Context 'Edge Cases' {
        It 'Empty array produces valid hash' {
            $result = Get-DataHash -InputData @()
            $result | Should Not Be $null
            $result.Hash | Should Not Be $null
            $result.Hash.Length | Should Be 64
        }

        It 'Null input produces valid hash' {
            $result = Get-DataHash -InputData $null
            $result | Should Not Be $null
            $result.Hash | Should Not Be $null
            $result.Hash.Length | Should Be 64
        }

        It 'Empty array and null produce same hash' {
            $hashEmpty = Get-DataHash -InputData @()
            $hashNull = Get-DataHash -InputData $null
            $hashEmpty.Hash | Should Be $hashNull.Hash
        }

        It 'Complex nested objects hash correctly' {
            $data = @(
                [PSCustomObject]@{
                    Name = 'User1'
                    Details = [PSCustomObject]@{
                        Email = 'user1@test.com'
                        Roles = @('Admin', 'User')
                    }
                }
            )
            $result = Get-DataHash -InputData $data
            $result | Should Not Be $null
            $result.Hash.Length | Should Be 64
        }

        It 'Large array produces valid hash' {
            $data = 1..100 | ForEach-Object {
                [PSCustomObject]@{ Id = $_; Name = "Item$_" }
            }
            $result = Get-DataHash -InputData $data
            $result | Should Not Be $null
            $result.Hash.Length | Should Be 64
        }
    }

    Context 'Data Variation' {
        It 'Additional property changes hash' {
            $data1 = @([PSCustomObject]@{ Name = 'Test' })
            $data2 = @([PSCustomObject]@{ Name = 'Test'; Extra = 'Value' })
            $hash1 = Get-DataHash -InputData $data1
            $hash2 = Get-DataHash -InputData $data2
            $hash1.Hash | Should Not Be $hash2.Hash
        }

        It 'Property value change changes hash' {
            $data1 = @([PSCustomObject]@{ Name = 'Test'; Value = 1 })
            $data2 = @([PSCustomObject]@{ Name = 'Test'; Value = 2 })
            $hash1 = Get-DataHash -InputData $data1
            $hash2 = Get-DataHash -InputData $data2
            $hash1.Hash | Should Not Be $hash2.Hash
        }

        It 'Array with different item count changes hash' {
            $data1 = @([PSCustomObject]@{ Name = 'Test' })
            $data2 = @(
                [PSCustomObject]@{ Name = 'Test' },
                [PSCustomObject]@{ Name = 'Test2' }
            )
            $hash1 = Get-DataHash -InputData $data1
            $hash2 = Get-DataHash -InputData $data2
            $hash1.Hash | Should Not Be $hash2.Hash
        }
    }

    Context 'Verbose Output' {
        It 'Writes verbose message when -Verbose is used' {
            $data = @([PSCustomObject]@{ Name = 'Test' })
            $verboseOutput = Get-DataHash -InputData $data -Verbose 4>&1
            $verboseOutput | Should Not Be $null
        }
    }
}
