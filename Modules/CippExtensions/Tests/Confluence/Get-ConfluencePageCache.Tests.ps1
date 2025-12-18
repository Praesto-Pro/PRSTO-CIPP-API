$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'

# Get path to function file - Tests/Confluence -> parent is Tests -> parent is CippExtensions
$moduleRoot = Split-Path (Split-Path $here -Parent) -Parent
$functionPath = Join-Path $moduleRoot (Join-Path 'Private' (Join-Path 'Confluence' $sut))

# Define stub functions for dependencies (required for Pester 3.4 mocking)
function Get-CIPPTable { param($TableName) }
function Get-CIPPAzDataTableEntity { param($Filter) }

Describe 'Get-ConfluencePageCache' {
    BeforeAll {
        # Dot-source the function for testing
        if (Test-Path $functionPath) {
            . $functionPath
        }
    }

    BeforeEach {
        # Mock CIPP framework functions with default behavior
        Mock Get-CIPPTable { return @{ TableName = 'CacheConfluencePages' } }
    }

    Context 'Cache Hit' {
        It 'Returns cached entry when exists' {
            Mock Get-CIPPAzDataTableEntity {
                return @{
                    PartitionKey = 'ConfluencePage'
                    RowKey       = '12345'
                    SpaceKey     = 'CONTOSO'
                    PageTitle    = 'User Inventory'
                    Hash         = 'ABC123DEF456'
                    LastUpdated  = '2025-12-18T00:00:00Z'
                }
            }

            $result = Get-ConfluencePageCache -PageId '12345'

            $result | Should Not BeNullOrEmpty
        }

        It 'Returns correct PageId' {
            Mock Get-CIPPAzDataTableEntity {
                return @{
                    PartitionKey = 'ConfluencePage'
                    RowKey       = '67890'
                    SpaceKey     = 'TEST'
                    PageTitle    = 'Test Page'
                    Hash         = 'HASH123'
                    LastUpdated  = '2025-12-18T00:00:00Z'
                }
            }

            $result = Get-ConfluencePageCache -PageId '67890'

            $result.PageId | Should Be '67890'
        }

        It 'Returns correct SpaceKey' {
            Mock Get-CIPPAzDataTableEntity {
                return @{
                    PartitionKey = 'ConfluencePage'
                    RowKey       = '12345'
                    SpaceKey     = 'MYSPACE'
                    PageTitle    = 'Test'
                    Hash         = 'HASH'
                    LastUpdated  = '2025-12-18T00:00:00Z'
                }
            }

            $result = Get-ConfluencePageCache -PageId '12345'

            $result.SpaceKey | Should Be 'MYSPACE'
        }

        It 'Returns correct Hash' {
            Mock Get-CIPPAzDataTableEntity {
                return @{
                    PartitionKey = 'ConfluencePage'
                    RowKey       = '12345'
                    SpaceKey     = 'TEST'
                    PageTitle    = 'Test'
                    Hash         = 'ABCDEF1234567890ABCDEF1234567890ABCDEF12'
                    LastUpdated  = '2025-12-18T00:00:00Z'
                }
            }

            $result = Get-ConfluencePageCache -PageId '12345'

            $result.Hash | Should Be 'ABCDEF1234567890ABCDEF1234567890ABCDEF12'
        }

        It 'Returns correct PageTitle' {
            Mock Get-CIPPAzDataTableEntity {
                return @{
                    PartitionKey = 'ConfluencePage'
                    RowKey       = '12345'
                    SpaceKey     = 'TEST'
                    PageTitle    = 'My Custom Page Title'
                    Hash         = 'HASH'
                    LastUpdated  = '2025-12-18T00:00:00Z'
                }
            }

            $result = Get-ConfluencePageCache -PageId '12345'

            $result.PageTitle | Should Be 'My Custom Page Title'
        }

        It 'Returns correct LastUpdated' {
            Mock Get-CIPPAzDataTableEntity {
                return @{
                    PartitionKey = 'ConfluencePage'
                    RowKey       = '12345'
                    SpaceKey     = 'TEST'
                    PageTitle    = 'Test'
                    Hash         = 'HASH'
                    LastUpdated  = '2025-12-18T15:30:00Z'
                }
            }

            $result = Get-ConfluencePageCache -PageId '12345'

            $result.LastUpdated | Should Be '2025-12-18T15:30:00Z'
        }
    }

    Context 'Cache Miss' {
        It 'Returns null when no cache entry exists' {
            Mock Get-CIPPAzDataTableEntity { return $null }

            $result = Get-ConfluencePageCache -PageId 'nonexistent'

            $result | Should BeNullOrEmpty
        }

        It 'Returns null for empty result from table query' {
            Mock Get-CIPPAzDataTableEntity { return @() }

            $result = Get-ConfluencePageCache -PageId 'missing'

            $result | Should BeNullOrEmpty
        }
    }

    Context 'Table Access' {
        It 'Calls Get-CIPPTable with CacheConfluencePages table name' {
            Mock Get-CIPPAzDataTableEntity { return $null }

            $result = Get-ConfluencePageCache -PageId '12345'

            Assert-MockCalled Get-CIPPTable -Times 1 -ParameterFilter { $TableName -eq 'CacheConfluencePages' }
        }

        It 'Calls Get-CIPPAzDataTableEntity with correct filter' {
            Mock Get-CIPPAzDataTableEntity { return $null }

            $result = Get-ConfluencePageCache -PageId 'page123'

            Assert-MockCalled Get-CIPPAzDataTableEntity -Times 1 -ParameterFilter {
                $Filter -like "*PartitionKey eq 'ConfluencePage'*" -and
                $Filter -like "*RowKey eq 'page123'*"
            }
        }
    }

    Context 'Output Type' {
        It 'Returns PSCustomObject when cache entry exists' {
            Mock Get-CIPPAzDataTableEntity {
                return @{
                    PartitionKey = 'ConfluencePage'
                    RowKey       = '12345'
                    SpaceKey     = 'TEST'
                    PageTitle    = 'Test'
                    Hash         = 'HASH'
                    LastUpdated  = '2025-12-18T00:00:00Z'
                }
            }

            $result = Get-ConfluencePageCache -PageId '12345'

            $result.GetType().Name | Should Be 'PSCustomObject'
        }

        It 'Returns object with all expected properties' {
            Mock Get-CIPPAzDataTableEntity {
                return @{
                    PartitionKey = 'ConfluencePage'
                    RowKey       = '12345'
                    SpaceKey     = 'TEST'
                    PageTitle    = 'Test'
                    Hash         = 'HASH'
                    LastUpdated  = '2025-12-18T00:00:00Z'
                }
            }

            $result = Get-ConfluencePageCache -PageId '12345'

            ($result.PSObject.Properties.Name -contains 'PageId') | Should Be $true
            ($result.PSObject.Properties.Name -contains 'SpaceKey') | Should Be $true
            ($result.PSObject.Properties.Name -contains 'PageTitle') | Should Be $true
            ($result.PSObject.Properties.Name -contains 'Hash') | Should Be $true
            ($result.PSObject.Properties.Name -contains 'LastUpdated') | Should Be $true
        }
    }
}
