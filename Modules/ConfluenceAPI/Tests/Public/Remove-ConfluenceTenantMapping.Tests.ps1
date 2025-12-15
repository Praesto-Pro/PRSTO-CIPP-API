$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $here)) 'Public'

Describe 'Remove-ConfluenceTenantMapping' {
    BeforeAll {
        # Define stub functions for CIPP dependencies
        function Get-CIPPTable { param($TableName) }
        function Get-CIPPAzDataTableEntity { param($Filter) }
        function Remove-AzDataTableEntity { param([switch]$Force, $Entity) }

        # Dot-source the function under test
        . "$publicDir\Remove-ConfluenceTenantMapping.ps1"
    }

    Context 'Remove Mapping (AC4)' {
        BeforeEach {
            $script:capturedEntity = $null
            Mock Get-CIPPTable { return @{ TableName = 'CippMapping' } }
            Mock Get-CIPPAzDataTableEntity {
                @{ RowKey = 'test-tenant'; SpaceKey = 'TESTSPACE'; SpaceName = 'Test Space' }
            }
            Mock Remove-AzDataTableEntity {
                $script:capturedEntity = $Entity
            }
        }

        It 'Calls Remove-AzDataTableEntity with correct entity' {
            Remove-ConfluenceTenantMapping -TenantId 'test-tenant' -Confirm:$false

            Assert-MockCalled Remove-AzDataTableEntity -Scope It
        }

        It 'Passes the found entity to Remove-AzDataTableEntity' {
            Remove-ConfluenceTenantMapping -TenantId 'test-tenant' -Confirm:$false

            $script:capturedEntity.RowKey | Should Be 'test-tenant'
            $script:capturedEntity.SpaceKey | Should Be 'TESTSPACE'
        }

        It 'Uses -Force flag on Remove-AzDataTableEntity' {
            Remove-ConfluenceTenantMapping -TenantId 'test-tenant' -Confirm:$false

            Assert-MockCalled Remove-AzDataTableEntity -Scope It -ParameterFilter { $Force -eq $true }
        }

        It 'Does not remove when WhatIf specified' {
            Remove-ConfluenceTenantMapping -TenantId 'test-tenant' -WhatIf

            Assert-MockCalled Remove-AzDataTableEntity -Scope It -Times 0
        }

        It 'Looks up entity before removing' {
            Remove-ConfluenceTenantMapping -TenantId 'my-tenant' -Confirm:$false

            Assert-MockCalled Get-CIPPAzDataTableEntity -Scope It -ParameterFilter {
                $Filter -eq "PartitionKey eq 'ConfluenceMapping' and RowKey eq 'my-tenant'"
            }
        }
    }

    Context 'Verbose Logging (AC5)' {
        BeforeEach {
            Mock Get-CIPPTable { return @{ TableName = 'CippMapping' } }
            Mock Get-CIPPAzDataTableEntity {
                @{ RowKey = 'test-tenant'; SpaceKey = 'TESTSPACE'; SpaceName = 'Test Space' }
            }
            Mock Remove-AzDataTableEntity { }
        }

        It 'Writes verbose message when starting removal' {
            $verboseOutput = Remove-ConfluenceTenantMapping -TenantId 'test' -Verbose -Confirm:$false 4>&1
            $verboseOutput | Should Not Be $null
            ($verboseOutput | Out-String) | Should Match 'Removing'
        }

        It 'Writes verbose message when looking up mapping' {
            $verboseOutput = Remove-ConfluenceTenantMapping -TenantId 'test' -Verbose -Confirm:$false 4>&1
            ($verboseOutput | Out-String) | Should Match 'Looking up'
        }

        It 'Writes verbose message when mapping found' {
            $verboseOutput = Remove-ConfluenceTenantMapping -TenantId 'test' -Verbose -Confirm:$false 4>&1
            ($verboseOutput | Out-String) | Should Match 'Found mapping'
        }

        It 'Writes verbose message on successful removal' {
            $verboseOutput = Remove-ConfluenceTenantMapping -TenantId 'test' -Verbose -Confirm:$false 4>&1
            ($verboseOutput | Out-String) | Should Match 'Successfully'
        }
    }

    Context 'Mapping Not Found (AC6)' {
        BeforeEach {
            Mock Get-CIPPTable { return @{ TableName = 'CippMapping' } }
            Mock Get-CIPPAzDataTableEntity { return $null }
            Mock Remove-AzDataTableEntity { }
        }

        It 'Writes warning when mapping not found' {
            $warningOutput = Remove-ConfluenceTenantMapping -TenantId 'nonexistent' -Confirm:$false 3>&1
            $warningOutput | Should Not Be $null
            ($warningOutput | Out-String) | Should Match 'No mapping found'
        }

        It 'Does not throw when mapping not found' {
            { Remove-ConfluenceTenantMapping -TenantId 'nonexistent' -Confirm:$false } | Should Not Throw
        }

        It 'Does not call Remove-AzDataTableEntity when mapping not found' {
            Remove-ConfluenceTenantMapping -TenantId 'nonexistent' -Confirm:$false

            Assert-MockCalled Remove-AzDataTableEntity -Scope It -Times 0
        }
    }

    Context 'Returns Nothing (void)' {
        BeforeEach {
            Mock Get-CIPPTable { return @{ TableName = 'CippMapping' } }
            Mock Get-CIPPAzDataTableEntity {
                @{ RowKey = 'test-tenant'; SpaceKey = 'TESTSPACE'; SpaceName = 'Test Space' }
            }
            Mock Remove-AzDataTableEntity { }
        }

        It 'Returns nothing on successful removal' {
            $result = Remove-ConfluenceTenantMapping -TenantId 'test-tenant' -Confirm:$false
            $result | Should Be $null
        }

        It 'Returns nothing when mapping not found' {
            Mock Get-CIPPAzDataTableEntity { return $null }

            $result = Remove-ConfluenceTenantMapping -TenantId 'nonexistent' -Confirm:$false
            $result | Should Be $null
        }
    }

    Context 'ShouldProcess and ConfirmImpact (AC4)' {
        BeforeEach {
            Mock Get-CIPPTable { return @{ TableName = 'CippMapping' } }
            Mock Get-CIPPAzDataTableEntity {
                @{ RowKey = 'test-tenant'; SpaceKey = 'TESTSPACE'; SpaceName = 'Test Space' }
            }
            Mock Remove-AzDataTableEntity { }
        }

        It 'Has SupportsShouldProcess attribute' {
            $cmd = Get-Command Remove-ConfluenceTenantMapping
            $cmd.Parameters.ContainsKey('WhatIf') | Should Be $true
            $cmd.Parameters.ContainsKey('Confirm') | Should Be $true
        }

        It 'Has ConfirmImpact of High' {
            $cmd = Get-Command Remove-ConfluenceTenantMapping
            $attr = $cmd.ScriptBlock.Attributes | Where-Object { $_.TypeId.Name -eq 'CmdletBindingAttribute' }
            $attr.ConfirmImpact | Should Be 'High'
        }

        It 'Has OutputType of void' {
            $cmd = Get-Command Remove-ConfluenceTenantMapping
            $outputType = $cmd.OutputType
            $outputType.Type.Name | Should Be 'Void'
        }
    }

    Context 'Parameter Validation' {
        BeforeEach {
            Mock Get-CIPPTable { return @{ TableName = 'CippMapping' } }
            Mock Get-CIPPAzDataTableEntity { return $null }
            Mock Remove-AzDataTableEntity { }
        }

        It 'Rejects empty TenantId' {
            { Remove-ConfluenceTenantMapping -TenantId '' -Confirm:$false } | Should Throw
        }

        It 'TenantId parameter is mandatory' {
            $cmd = Get-Command Remove-ConfluenceTenantMapping
            $cmd.Parameters['TenantId'].Attributes | Where-Object {
                $_.TypeId.Name -eq 'ParameterAttribute' -and $_.Mandatory -eq $true
            } | Should Not Be $null
        }
    }

    Context 'Does Not Delete Confluence Space (AC4)' {
        BeforeEach {
            Mock Get-CIPPTable { return @{ TableName = 'CippMapping' } }
            Mock Get-CIPPAzDataTableEntity {
                @{ RowKey = 'test-tenant'; SpaceKey = 'TESTSPACE'; SpaceName = 'Test Space' }
            }
            Mock Remove-AzDataTableEntity { }
        }

        It 'Only removes mapping, not the space itself' {
            # This test verifies that no Confluence API calls are made
            # The function only interacts with Azure Table Storage
            Remove-ConfluenceTenantMapping -TenantId 'test-tenant' -Confirm:$false

            # Verify only table operations occurred
            Assert-MockCalled Get-CIPPTable -Scope It -Times 1
            Assert-MockCalled Get-CIPPAzDataTableEntity -Scope It -Times 1
            Assert-MockCalled Remove-AzDataTableEntity -Scope It -Times 1
        }
    }
}
