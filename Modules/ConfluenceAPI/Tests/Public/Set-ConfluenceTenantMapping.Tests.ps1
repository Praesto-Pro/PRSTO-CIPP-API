$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $here)) 'Public'

Describe 'Set-ConfluenceTenantMapping' {
    BeforeAll {
        # Define stub functions for CIPP dependencies
        function Get-CIPPTable { param($TableName) }
        function Add-CIPPAzDataTableEntity { param($Entity, [switch]$Force) }

        # Dot-source the function under test
        . "$publicDir\Set-ConfluenceTenantMapping.ps1"
    }

    Context 'Create/Update Mapping (AC3)' {
        BeforeEach {
            $script:capturedEntity = $null
            Mock Get-CIPPTable { return @{ TableName = 'CippMapping' } }
            Mock Add-CIPPAzDataTableEntity {
                $script:capturedEntity = $Entity
            }
        }

        It 'Calls Add-CIPPAzDataTableEntity with correct parameters' {
            Set-ConfluenceTenantMapping -TenantId 'test-tenant' -SpaceKey 'TESTSPACE' -SpaceName 'Test Space'

            Assert-MockCalled Add-CIPPAzDataTableEntity -Scope It
        }

        It 'Sets correct PartitionKey for ConfluenceMapping' {
            Set-ConfluenceTenantMapping -TenantId 'test-tenant' -SpaceKey 'TESTSPACE' -SpaceName 'Test Space'

            $script:capturedEntity.PartitionKey | Should Be 'ConfluenceMapping'
        }

        It 'Sets RowKey to TenantId' {
            Set-ConfluenceTenantMapping -TenantId 'abc-123' -SpaceKey 'TESTSPACE' -SpaceName 'Test Space'

            $script:capturedEntity.RowKey | Should Be 'abc-123'
        }

        It 'Sets SpaceKey property' {
            Set-ConfluenceTenantMapping -TenantId 'test-tenant' -SpaceKey 'MYSPACE' -SpaceName 'Test Space'

            $script:capturedEntity.SpaceKey | Should Be 'MYSPACE'
        }

        It 'Sets SpaceName property' {
            Set-ConfluenceTenantMapping -TenantId 'test-tenant' -SpaceKey 'TESTSPACE' -SpaceName 'My Space Name'

            $script:capturedEntity.SpaceName | Should Be 'My Space Name'
        }

        It 'Uses -Force to overwrite existing mapping' {
            $forceCalled = $false
            Mock Add-CIPPAzDataTableEntity {
                param($Entity, $Force)
                if ($Force) { $forceCalled = $true }
            }

            Set-ConfluenceTenantMapping -TenantId 'test-tenant' -SpaceKey 'TESTSPACE' -SpaceName 'Test Space'

            Assert-MockCalled Add-CIPPAzDataTableEntity -Scope It -ParameterFilter { $Force -eq $true }
        }

        It 'Does not update when WhatIf specified' {
            Set-ConfluenceTenantMapping -TenantId 'test-tenant' -SpaceKey 'TESTSPACE' -SpaceName 'Test Space' -WhatIf

            Assert-MockCalled Add-CIPPAzDataTableEntity -Scope It -Times 0
        }
    }

    Context 'Verbose Logging (AC5)' {
        BeforeEach {
            Mock Get-CIPPTable { return @{ TableName = 'CippMapping' } }
            Mock Add-CIPPAzDataTableEntity { }
        }

        It 'Writes verbose messages during operation' {
            $verboseOutput = Set-ConfluenceTenantMapping -TenantId 'test' -SpaceKey 'TEST' -SpaceName 'Test' -Verbose 4>&1
            $verboseOutput | Should Not Be $null
            ($verboseOutput | Out-String) | Should Match 'tenant'
        }

        It 'Writes verbose message on successful completion' {
            $verboseOutput = Set-ConfluenceTenantMapping -TenantId 'test' -SpaceKey 'TEST' -SpaceName 'Test' -Verbose 4>&1
            ($verboseOutput | Out-String) | Should Match 'Successfully'
        }
    }

    Context 'SpaceKey Validation (AC7)' {
        BeforeEach {
            Mock Get-CIPPTable { return @{ TableName = 'CippMapping' } }
            Mock Add-CIPPAzDataTableEntity { }
        }

        It 'Throws error for lowercase SpaceKey' {
            { Set-ConfluenceTenantMapping -TenantId 'test' -SpaceKey 'lowercase' -SpaceName 'Test' } | Should Throw
        }

        It 'Throws error for mixed case SpaceKey' {
            { Set-ConfluenceTenantMapping -TenantId 'test' -SpaceKey 'MixedCase' -SpaceName 'Test' } | Should Throw
        }

        It 'Throws error for SpaceKey with spaces' {
            { Set-ConfluenceTenantMapping -TenantId 'test' -SpaceKey 'SPACE KEY' -SpaceName 'Test' } | Should Throw
        }

        It 'Throws error for SpaceKey starting with number' {
            { Set-ConfluenceTenantMapping -TenantId 'test' -SpaceKey '123SPACE' -SpaceName 'Test' } | Should Throw
        }

        It 'Throws error for SpaceKey with special characters' {
            { Set-ConfluenceTenantMapping -TenantId 'test' -SpaceKey 'SPACE-KEY' -SpaceName 'Test' } | Should Throw
        }

        It 'Throws error for SpaceKey with underscore' {
            { Set-ConfluenceTenantMapping -TenantId 'test' -SpaceKey 'SPACE_KEY' -SpaceName 'Test' } | Should Throw
        }

        It 'Accepts valid uppercase SpaceKey' {
            { Set-ConfluenceTenantMapping -TenantId 'test' -SpaceKey 'VALIDSPACE' -SpaceName 'Test' } | Should Not Throw
            Assert-MockCalled Add-CIPPAzDataTableEntity -Scope It
        }

        It 'Accepts SpaceKey with numbers after first letter' {
            { Set-ConfluenceTenantMapping -TenantId 'test' -SpaceKey 'CLIENT123' -SpaceName 'Test' } | Should Not Throw
            Assert-MockCalled Add-CIPPAzDataTableEntity -Scope It
        }

        It 'Accepts single letter SpaceKey' {
            { Set-ConfluenceTenantMapping -TenantId 'test' -SpaceKey 'A' -SpaceName 'Test' } | Should Not Throw
            Assert-MockCalled Add-CIPPAzDataTableEntity -Scope It
        }

        It 'Error message explains SpaceKey requirements' {
            $errorMessage = ''
            try {
                Set-ConfluenceTenantMapping -TenantId 'test' -SpaceKey 'invalid' -SpaceName 'Test'
            } catch {
                $errorMessage = $_.Exception.Message
            }
            $errorMessage | Should Match 'uppercase'
        }
    }

    Context 'Parameter Validation' {
        BeforeEach {
            Mock Get-CIPPTable { return @{ TableName = 'CippMapping' } }
            Mock Add-CIPPAzDataTableEntity { }
        }

        It 'TenantId parameter is mandatory' {
            $cmd = Get-Command Set-ConfluenceTenantMapping
            $param = $cmd.Parameters['TenantId']
            $mandatory = $param.Attributes | Where-Object { $_.TypeId.Name -eq 'ParameterAttribute' -and $_.Mandatory -eq $true }
            $mandatory | Should Not Be $null
        }

        It 'Requires SpaceKey parameter' {
            { Set-ConfluenceTenantMapping -TenantId 'test' -SpaceName 'Test' } | Should Throw
        }

        It 'Requires SpaceName parameter' {
            { Set-ConfluenceTenantMapping -TenantId 'test' -SpaceKey 'TEST' } | Should Throw
        }

        It 'Rejects empty TenantId' {
            { Set-ConfluenceTenantMapping -TenantId '' -SpaceKey 'TEST' -SpaceName 'Test' } | Should Throw
        }

        It 'Rejects empty SpaceKey' {
            { Set-ConfluenceTenantMapping -TenantId 'test' -SpaceKey '' -SpaceName 'Test' } | Should Throw
        }

        It 'Rejects empty SpaceName' {
            { Set-ConfluenceTenantMapping -TenantId 'test' -SpaceKey 'TEST' -SpaceName '' } | Should Throw
        }
    }

    Context 'ShouldProcess Support' {
        BeforeEach {
            Mock Get-CIPPTable { return @{ TableName = 'CippMapping' } }
            Mock Add-CIPPAzDataTableEntity { }
        }

        It 'Has SupportsShouldProcess attribute' {
            $cmd = Get-Command Set-ConfluenceTenantMapping
            $cmd.Parameters.ContainsKey('WhatIf') | Should Be $true
            $cmd.Parameters.ContainsKey('Confirm') | Should Be $true
        }

        It 'Has ConfirmImpact of Low' {
            $cmd = Get-Command Set-ConfluenceTenantMapping
            $attr = $cmd.ScriptBlock.Attributes | Where-Object { $_.TypeId.Name -eq 'CmdletBindingAttribute' }
            $attr.ConfirmImpact | Should Be 'Low'
        }
    }
}
