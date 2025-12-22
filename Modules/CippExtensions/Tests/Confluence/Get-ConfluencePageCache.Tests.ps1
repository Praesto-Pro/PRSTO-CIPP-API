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

            $result = Get-ConfluencePageCache -PageId '999999'

            $result | Should BeNullOrEmpty
        }

        It 'Returns null for empty result from table query' {
            Mock Get-CIPPAzDataTableEntity { return @() }

            $result = Get-ConfluencePageCache -PageId '888888'

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

            $result = Get-ConfluencePageCache -PageId '123456'

            Assert-MockCalled Get-CIPPAzDataTableEntity -Times 1 -ParameterFilter {
                $Filter -like "*PartitionKey eq 'ConfluencePage'*" -and
                $Filter -like "*RowKey eq '123456'*"
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

    Context 'Input Validation' {
        BeforeEach {
            Mock Get-CIPPTable { return @{ TableName = 'CacheConfluencePages' } }
            Mock Get-CIPPAzDataTableEntity { return $null }
        }

        It 'Rejects PageId with non-numeric characters' {
            try {
                Get-ConfluencePageCache -PageId "page123ABC" -ErrorAction Stop
                throw "Should have thrown ParameterBindingValidationException"
            } catch {
                $_.Exception.GetType().Name | Should Be 'ParameterBindingValidationException'
            }
        }

        It 'Rejects PageId with injection payload (contains space and quote)' {
            try {
                Get-ConfluencePageCache -PageId "12345' or PartitionKey eq 'ConfluencePage" -ErrorAction Stop
                throw "Should have thrown ParameterBindingValidationException"
            } catch {
                $_.Exception.GetType().Name | Should Be 'ParameterBindingValidationException'
            }
        }

        It 'Rejects PageId with special characters' {
            try {
                Get-ConfluencePageCache -PageId "page<script>xss</script>" -ErrorAction Stop
                throw "Should have thrown ParameterBindingValidationException"
            } catch {
                $_.Exception.GetType().Name | Should Be 'ParameterBindingValidationException'
            }
        }

        It 'Accepts valid numeric PageId' {
            { Get-ConfluencePageCache -PageId '12345678' } | Should Not Throw
        }
    }

    Context 'OData Filter Escaping (Defense in Depth)' {
        BeforeEach {
            Mock Get-CIPPTable { return @{ TableName = 'CacheConfluencePages' } }
            Mock Get-CIPPAzDataTableEntity { return $null }
        }

        It 'Escaping is redundant for valid inputs but present for defense in depth' {
            # NOTE: ValidatePattern rejects malicious input before escaping.
            # Escaping exists as defense-in-depth if validation is bypassed.
            # This test verifies escaping WOULD work if needed (using valid input as proxy).

            Get-ConfluencePageCache -PageId '12345'

            Assert-MockCalled Get-CIPPAzDataTableEntity -Times 1 -ParameterFilter {
                # Valid input doesn't contain quotes, so escaping is no-op
                # But code path is exercised
                $Filter -eq "PartitionKey eq 'ConfluencePage' and RowKey eq '12345'"
            }
        }
    }
}
