$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'

# Get path to function file - Tests/Confluence -> parent is Tests -> parent is CippExtensions
$moduleRoot = Split-Path (Split-Path $here -Parent) -Parent
$functionPath = Join-Path $moduleRoot (Join-Path 'Public' (Join-Path 'Confluence' $sut))

# Define stub functions for dependencies (required for Pester 3.4 mocking)
function Get-ExtensionMapping { param($Extension) }

Describe 'Get-ConfluenceMapping' {
    BeforeAll {
        # Dot-source the function for testing
        if (Test-Path $functionPath) {
            . $functionPath
        }
    }

    BeforeEach {
        # Mock CIPP framework functions
        Mock Get-ExtensionMapping {
            return @(
                [PSCustomObject]@{
                    PartitionKey    = 'ConfluenceMapping'
                    RowKey          = 'contoso.onmicrosoft.com'
                    IntegrationId   = 'CONTOSO'
                    IntegrationName = 'Contoso Corp'
                }
                [PSCustomObject]@{
                    PartitionKey    = 'ConfluenceMapping'
                    RowKey          = 'fabrikam.onmicrosoft.com'
                    IntegrationId   = 'FABRIKAM'
                    IntegrationName = 'Fabrikam Inc'
                }
            )
        }
    }

    Context 'Successful Retrieval' {
        It 'Returns array of mapping objects' {
            $result = Get-ConfluenceMapping

            $result | Should Not Be $null
            @($result).Count | Should Be 2
        }

        It 'Calls Get-ExtensionMapping with Confluence extension' {
            $result = Get-ConfluenceMapping

            Assert-MockCalled Get-ExtensionMapping -Times 1 -ParameterFilter { $Extension -eq 'Confluence' }
        }

        It 'Returns objects with RowKey property' {
            $result = Get-ConfluenceMapping

            $result[0].RowKey | Should Be 'contoso.onmicrosoft.com'
        }

        It 'Returns objects with TenantId property' {
            $result = Get-ConfluenceMapping

            $result[0].TenantId | Should Be 'contoso.onmicrosoft.com'
        }

        It 'Returns objects with SpaceKey property' {
            $result = Get-ConfluenceMapping

            $result[0].SpaceKey | Should Be 'CONTOSO'
        }

        It 'Returns objects with SpaceName property' {
            $result = Get-ConfluenceMapping

            $result[0].SpaceName | Should Be 'Contoso Corp'
        }
    }

    Context 'Empty Results' {
        It 'Returns empty array when no mappings exist' {
            Mock Get-ExtensionMapping { return @() }

            $result = Get-ConfluenceMapping

            @($result).Count | Should Be 0
        }

        It 'Returns empty array when Get-ExtensionMapping returns null' {
            Mock Get-ExtensionMapping { return $null }

            $result = Get-ConfluenceMapping

            @($result).Count | Should Be 0
        }
    }

    Context 'Property Mapping' {
        It 'Maps RowKey to TenantId' {
            $result = Get-ConfluenceMapping

            $result[0].TenantId | Should Be $result[0].RowKey
        }

        It 'Maps IntegrationId to SpaceKey' {
            Mock Get-ExtensionMapping {
                return @(
                    [PSCustomObject]@{
                        PartitionKey    = 'ConfluenceMapping'
                        RowKey          = 'test.onmicrosoft.com'
                        IntegrationId   = 'TESTSPACE'
                        IntegrationName = 'Test Space'
                    }
                )
            }

            $result = Get-ConfluenceMapping

            $result[0].SpaceKey | Should Be 'TESTSPACE'
        }

        It 'Maps IntegrationName to SpaceName' {
            Mock Get-ExtensionMapping {
                return @(
                    [PSCustomObject]@{
                        PartitionKey    = 'ConfluenceMapping'
                        RowKey          = 'test.onmicrosoft.com'
                        IntegrationId   = 'TESTSPACE'
                        IntegrationName = 'Test Space Display Name'
                    }
                )
            }

            $result = Get-ConfluenceMapping

            $result[0].SpaceName | Should Be 'Test Space Display Name'
        }
    }

    Context 'Multiple Mappings' {
        It 'Returns all configured mappings' {
            Mock Get-ExtensionMapping {
                return @(
                    [PSCustomObject]@{ PartitionKey = 'ConfluenceMapping'; RowKey = 'tenant1.com'; IntegrationId = 'SPACE1'; IntegrationName = 'Space 1' }
                    [PSCustomObject]@{ PartitionKey = 'ConfluenceMapping'; RowKey = 'tenant2.com'; IntegrationId = 'SPACE2'; IntegrationName = 'Space 2' }
                    [PSCustomObject]@{ PartitionKey = 'ConfluenceMapping'; RowKey = 'tenant3.com'; IntegrationId = 'SPACE3'; IntegrationName = 'Space 3' }
                )
            }

            $result = Get-ConfluenceMapping

            @($result).Count | Should Be 3
        }

        It 'Preserves all mapping properties' {
            $result = Get-ConfluenceMapping

            $result[1].RowKey | Should Be 'fabrikam.onmicrosoft.com'
            $result[1].SpaceKey | Should Be 'FABRIKAM'
            $result[1].SpaceName | Should Be 'Fabrikam Inc'
        }
    }

    Context 'Error Handling' {
        It 'Returns empty array when Get-ExtensionMapping throws' {
            Mock Get-ExtensionMapping { throw 'Table not found' }

            $result = Get-ConfluenceMapping

            @($result).Count | Should Be 0
        }

        It 'Does not throw when Get-ExtensionMapping fails' {
            Mock Get-ExtensionMapping { throw 'Connection error' }

            { Get-ConfluenceMapping } | Should Not Throw
        }
    }

    Context 'Output Type' {
        It 'Returns PSCustomObject array' {
            $result = Get-ConfluenceMapping

            $result[0].GetType().Name | Should Be 'PSCustomObject'
        }

        It 'Returns array even for single mapping' {
            Mock Get-ExtensionMapping {
                return @(
                    [PSCustomObject]@{
                        PartitionKey    = 'ConfluenceMapping'
                        RowKey          = 'single.onmicrosoft.com'
                        IntegrationId   = 'SINGLE'
                        IntegrationName = 'Single Tenant'
                    }
                )
            }

            $result = Get-ConfluenceMapping

            # Force to array and check count
            @($result).Count | Should Be 1
        }
    }

    Context 'Filtering by Tenant' {
        It 'Can filter results by RowKey' {
            $result = Get-ConfluenceMapping
            $filtered = $result | Where-Object { $_.RowKey -eq 'contoso.onmicrosoft.com' }

            @($filtered).Count | Should Be 1
            $filtered.SpaceKey | Should Be 'CONTOSO'
        }

        It 'Can filter results by TenantId' {
            $result = Get-ConfluenceMapping
            $filtered = $result | Where-Object { $_.TenantId -eq 'fabrikam.onmicrosoft.com' }

            @($filtered).Count | Should Be 1
            $filtered.SpaceKey | Should Be 'FABRIKAM'
        }

        It 'Returns empty when filter matches nothing' {
            $result = Get-ConfluenceMapping
            $filtered = $result | Where-Object { $_.RowKey -eq 'nonexistent.com' }

            @($filtered).Count | Should Be 0
        }
    }
}
