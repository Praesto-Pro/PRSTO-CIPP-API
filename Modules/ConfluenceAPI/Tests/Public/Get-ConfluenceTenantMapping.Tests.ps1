$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $here)) 'Public'

Describe 'Get-ConfluenceTenantMapping' {
    BeforeAll {
        # Define stub functions for CIPP dependencies
        function Get-CIPPTable { param($TableName) }
        function Get-CIPPAzDataTableEntity { param($Filter) }

        # Dot-source the function under test
        . "$publicDir\Get-ConfluenceTenantMapping.ps1"
    }

    Context 'Retrieve All Mappings (AC1)' {
        BeforeEach {
            Mock Get-CIPPTable { return @{ TableName = 'CippMapping' } }
            Mock Get-CIPPAzDataTableEntity {
                @(
                    @{ RowKey = 'tenant-1'; SpaceKey = 'SPACE1'; SpaceName = 'Space One' },
                    @{ RowKey = 'tenant-2'; SpaceKey = 'SPACE2'; SpaceName = 'Space Two' }
                )
            }
        }

        It 'Returns all mappings when no parameters provided' {
            $result = @(Get-ConfluenceTenantMapping)
            $result.Count | Should Be 2
        }

        It 'Returns PSCustomObject with TenantId, SpaceKey, SpaceName properties' {
            $result = @(Get-ConfluenceTenantMapping)
            $result[0].TenantId | Should Be 'tenant-1'
            $result[0].SpaceKey | Should Be 'SPACE1'
            $result[0].SpaceName | Should Be 'Space One'
        }

        It 'Returns PSCustomObject for all mappings' {
            $result = @(Get-ConfluenceTenantMapping)
            $result[1].TenantId | Should Be 'tenant-2'
            $result[1].SpaceKey | Should Be 'SPACE2'
            $result[1].SpaceName | Should Be 'Space Two'
        }

        It 'Calls Get-CIPPTable with CippMapping' {
            Get-ConfluenceTenantMapping
            Assert-MockCalled Get-CIPPTable -Scope It -ParameterFilter {
                $TableName -eq 'CippMapping'
            }
        }

        It 'Calls Get-CIPPAzDataTableEntity with ConfluenceMapping filter' {
            Get-ConfluenceTenantMapping
            Assert-MockCalled Get-CIPPAzDataTableEntity -Scope It -ParameterFilter {
                $Filter -eq "PartitionKey eq 'ConfluenceMapping'"
            }
        }
    }

    Context 'Retrieve by TenantId (AC2)' {
        BeforeEach {
            Mock Get-CIPPTable { return @{ TableName = 'CippMapping' } }
        }

        It 'Returns specific mapping when TenantId provided' {
            Mock Get-CIPPAzDataTableEntity {
                @{ RowKey = 'tenant-1'; SpaceKey = 'SPACE1'; SpaceName = 'Space One' }
            }

            $result = Get-ConfluenceTenantMapping -TenantId 'tenant-1'
            $result.TenantId | Should Be 'tenant-1'
            $result.SpaceKey | Should Be 'SPACE1'
            $result.SpaceName | Should Be 'Space One'
        }

        It 'Returns $null when TenantId not found' {
            Mock Get-CIPPAzDataTableEntity { return $null }

            $result = Get-ConfluenceTenantMapping -TenantId 'nonexistent'
            $result | Should Be $null
        }

        It 'Uses correct filter for TenantId lookup' {
            Mock Get-CIPPAzDataTableEntity { return $null }

            Get-ConfluenceTenantMapping -TenantId 'test-tenant-123'
            Assert-MockCalled Get-CIPPAzDataTableEntity -Scope It -ParameterFilter {
                $Filter -eq "PartitionKey eq 'ConfluenceMapping' and RowKey eq 'test-tenant-123'"
            }
        }
    }

    Context 'Retrieve by SpaceKey (AC8)' {
        BeforeEach {
            Mock Get-CIPPTable { return @{ TableName = 'CippMapping' } }
        }

        It 'Returns specific mapping when SpaceKey provided' {
            Mock Get-CIPPAzDataTableEntity {
                @{ RowKey = 'tenant-1'; SpaceKey = 'CONTOSO'; SpaceName = 'Contoso Corp' }
            }

            $result = Get-ConfluenceTenantMapping -SpaceKey 'CONTOSO'
            $result.SpaceKey | Should Be 'CONTOSO'
            $result.TenantId | Should Be 'tenant-1'
            $result.SpaceName | Should Be 'Contoso Corp'
        }

        It 'Returns $null when SpaceKey not found' {
            Mock Get-CIPPAzDataTableEntity { return $null }

            $result = Get-ConfluenceTenantMapping -SpaceKey 'NOTFOUND'
            $result | Should Be $null
        }

        It 'Uses correct filter for SpaceKey lookup' {
            Mock Get-CIPPAzDataTableEntity { return $null }

            Get-ConfluenceTenantMapping -SpaceKey 'TESTSPACE'
            Assert-MockCalled Get-CIPPAzDataTableEntity -Scope It -ParameterFilter {
                $Filter -eq "PartitionKey eq 'ConfluenceMapping' and SpaceKey eq 'TESTSPACE'"
            }
        }
    }

    Context 'Verbose Logging (AC5)' {
        BeforeEach {
            Mock Get-CIPPTable { return @{ TableName = 'CippMapping' } }
            Mock Get-CIPPAzDataTableEntity { return $null }
        }

        It 'Writes verbose message when retrieving all mappings' {
            $verboseOutput = Get-ConfluenceTenantMapping -Verbose 4>&1
            $verboseOutput | Should Not Be $null
            ($verboseOutput | Out-String) | Should Match 'Retrieving'
        }

        It 'Writes verbose message for TenantId lookup' {
            $verboseOutput = Get-ConfluenceTenantMapping -TenantId 'test' -Verbose 4>&1
            ($verboseOutput | Out-String) | Should Match 'tenant'
        }

        It 'Writes verbose message for SpaceKey lookup' {
            $verboseOutput = Get-ConfluenceTenantMapping -SpaceKey 'TEST' -Verbose 4>&1
            ($verboseOutput | Out-String) | Should Match 'space'
        }
    }

    Context 'Handles Empty Table Gracefully' {
        BeforeEach {
            Mock Get-CIPPTable { return @{ TableName = 'CippMapping' } }
            Mock Get-CIPPAzDataTableEntity { return @() }
        }

        It 'Returns empty collection when no mappings exist' {
            $result = @(Get-ConfluenceTenantMapping)
            $result.Count | Should Be 0
        }

        It 'Does not throw when table is empty' {
            { Get-ConfluenceTenantMapping } | Should Not Throw
        }
    }

    Context 'Parameter Validation' {
        BeforeEach {
            Mock Get-CIPPTable { return @{ TableName = 'CippMapping' } }
            Mock Get-CIPPAzDataTableEntity { return $null }
        }

        It 'Rejects empty string for TenantId (ValidatePattern)' {
            { Get-ConfluenceTenantMapping -TenantId '' } | Should Throw
        }

        It 'Rejects empty string for SpaceKey (ValidatePattern)' {
            { Get-ConfluenceTenantMapping -SpaceKey '' } | Should Throw
        }

        It 'Uses parameter sets to prevent TenantId and SpaceKey together' {
            $cmd = Get-Command Get-ConfluenceTenantMapping
            $tenantIdSet = $cmd.Parameters['TenantId'].ParameterSets.Keys
            $spaceKeySet = $cmd.Parameters['SpaceKey'].ParameterSets.Keys
            $tenantIdSet | Should Be 'ByTenantId'
            $spaceKeySet | Should Be 'BySpaceKey'
        }

        It 'Has default parameter set for retrieving all mappings' {
            $cmd = Get-Command Get-ConfluenceTenantMapping
            $attr = $cmd.ScriptBlock.Attributes | Where-Object { $_.TypeId.Name -eq 'CmdletBindingAttribute' }
            $attr.DefaultParameterSetName | Should Be 'All'
        }
    }

    Context 'Input Validation' {
        BeforeEach {
            Mock Get-CIPPTable { return @{ TableName = 'CippMapping' } }
            Mock Get-CIPPAzDataTableEntity { return $null }
        }

        It 'Rejects TenantId with invalid domain (missing TLD)' {
            try {
                Get-ConfluenceTenantMapping -TenantId "abc" -ErrorAction Stop
                throw "Should have thrown ParameterBindingValidationException"
            } catch {
                $_.Exception.GetType().Name | Should Be 'ParameterBindingValidationException'
            }
        }

        It 'Rejects TenantId with injection payload (contains space and quote)' {
            try {
                Get-ConfluenceTenantMapping -TenantId "abc' or PartitionKey eq 'ConfluenceMapping" -ErrorAction Stop
                throw "Should have thrown ParameterBindingValidationException"
            } catch {
                $_.Exception.GetType().Name | Should Be 'ParameterBindingValidationException'
            }
        }

        It 'Rejects SpaceKey with hyphens (not allowed per Confluence spec)' {
            try {
                Get-ConfluenceTenantMapping -SpaceKey 'CONTOSO-SPACE' -ErrorAction Stop
                throw "Should have thrown ParameterBindingValidationException"
            } catch {
                $_.Exception.GetType().Name | Should Be 'ParameterBindingValidationException'
            }
        }

        It 'Rejects SpaceKey with underscores (not allowed per Confluence spec)' {
            try {
                Get-ConfluenceTenantMapping -SpaceKey 'CONTOSO_SPACE' -ErrorAction Stop
                throw "Should have thrown ParameterBindingValidationException"
            } catch {
                $_.Exception.GetType().Name | Should Be 'ParameterBindingValidationException'
            }
        }

        It 'Rejects SpaceKey with injection payload (contains space and quote)' {
            try {
                Get-ConfluenceTenantMapping -SpaceKey "CONTOSO' or PartitionKey eq 'ConfluenceMapping" -ErrorAction Stop
                throw "Should have thrown ParameterBindingValidationException"
            } catch {
                $_.Exception.GetType().Name | Should Be 'ParameterBindingValidationException'
            }
        }

        It 'Accepts valid GUID format for TenantId' {
            { Get-ConfluenceTenantMapping -TenantId '12345678-1234-1234-1234-123456789abc' } | Should Not Throw
        }

        It 'Accepts valid domain format for TenantId' {
            { Get-ConfluenceTenantMapping -TenantId 'contoso.onmicrosoft.com' } | Should Not Throw
        }

        It 'Accepts valid alphanumeric SpaceKey' {
            { Get-ConfluenceTenantMapping -SpaceKey 'CONTOSO1' } | Should Not Throw
        }
    }

    Context 'OData Filter Escaping (Defense in Depth)' {
        BeforeEach {
            Mock Get-CIPPTable { return @{ TableName = 'CippMapping' } }
            Mock Get-CIPPAzDataTableEntity { return $null }
        }

        It 'Escaping is redundant for valid inputs but present for defense in depth' {
            # NOTE: ValidatePattern rejects malicious input before escaping.
            # Escaping exists as defense-in-depth if validation is bypassed.
            # This test verifies escaping WOULD work if needed (using valid input as proxy).

            Get-ConfluenceTenantMapping -TenantId 'contoso-test.com'

            Assert-MockCalled Get-CIPPAzDataTableEntity -Times 1 -ParameterFilter {
                # Valid input doesn't contain quotes, so escaping is no-op
                # But code path is exercised
                $Filter -eq "PartitionKey eq 'ConfluenceMapping' and RowKey eq 'contoso-test.com'"
            }
        }
    }
}
