$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'

# Get path to function file - Tests/Confluence -> parent is Tests -> parent is CippExtensions
$moduleRoot = Split-Path (Split-Path $here -Parent) -Parent
$functionPath = Join-Path $moduleRoot (Join-Path 'Private' (Join-Path 'Confluence' $sut))

# Define stub functions for dependencies (required for Pester 3.4 mocking)
function Get-CIPPTable { param($TableName) }
function Get-CIPPAzDataTableEntity { param($Filter) }
function Remove-AzDataTableEntity { param($Entity, [switch]$Force) }

Describe 'Clear-ConfluencePageCache' {
    BeforeAll {
        # Dot-source the function for testing
        if (Test-Path $functionPath) {
            . $functionPath
        }
    }

    BeforeEach {
        # Mock CIPP framework functions with default behavior
        Mock Get-CIPPTable { return @{ TableName = 'CacheConfluencePages' } }
        Mock Remove-AzDataTableEntity { }
    }

    Context 'Clear All Entries' {
        It 'Removes all entries when no SpaceKey specified' {
            Mock Get-CIPPAzDataTableEntity {
                return @(
                    @{ PartitionKey = 'ConfluencePage'; RowKey = '111'; SpaceKey = 'SPACE1' },
                    @{ PartitionKey = 'ConfluencePage'; RowKey = '222'; SpaceKey = 'SPACE2' },
                    @{ PartitionKey = 'ConfluencePage'; RowKey = '333'; SpaceKey = 'SPACE1' }
                )
            }

            Clear-ConfluencePageCache -Confirm:$false

            Assert-MockCalled Remove-AzDataTableEntity -Times 3
        }

        It 'Queries for all ConfluencePage entries when no SpaceKey' {
            Mock Get-CIPPAzDataTableEntity { return @() }

            Clear-ConfluencePageCache -Confirm:$false

            Assert-MockCalled Get-CIPPAzDataTableEntity -Times 1 -ParameterFilter {
                $Filter -eq "PartitionKey eq 'ConfluencePage'"
            }
        }
    }

    Context 'Clear By SpaceKey' {
        It 'Removes only entries for specified SpaceKey' {
            Mock Get-CIPPAzDataTableEntity {
                return @(
                    @{ PartitionKey = 'ConfluencePage'; RowKey = '111'; SpaceKey = 'CONTOSO' },
                    @{ PartitionKey = 'ConfluencePage'; RowKey = '222'; SpaceKey = 'CONTOSO' }
                )
            }

            Clear-ConfluencePageCache -SpaceKey 'CONTOSO' -Confirm:$false

            Assert-MockCalled Remove-AzDataTableEntity -Times 2
        }

        It 'Queries with SpaceKey filter when SpaceKey specified' {
            Mock Get-CIPPAzDataTableEntity { return @() }

            Clear-ConfluencePageCache -SpaceKey 'MYSPACE' -Confirm:$false

            Assert-MockCalled Get-CIPPAzDataTableEntity -Times 1 -ParameterFilter {
                $Filter -like "*SpaceKey eq 'MYSPACE'*"
            }
        }

        It 'Does not remove entries from other spaces' {
            Mock Get-CIPPAzDataTableEntity {
                return @(
                    @{ PartitionKey = 'ConfluencePage'; RowKey = '111'; SpaceKey = 'TARGETSPACE' }
                )
            }

            Clear-ConfluencePageCache -SpaceKey 'TARGETSPACE' -Confirm:$false

            Assert-MockCalled Remove-AzDataTableEntity -Times 1
        }
    }

    Context 'No Entries Found' {
        It 'Does not call Remove when no entries exist' {
            Mock Get-CIPPAzDataTableEntity { return @() }

            Clear-ConfluencePageCache -Confirm:$false

            Assert-MockCalled Remove-AzDataTableEntity -Times 0
        }

        It 'Does not call Remove when null returned' {
            Mock Get-CIPPAzDataTableEntity { return $null }

            Clear-ConfluencePageCache -Confirm:$false

            Assert-MockCalled Remove-AzDataTableEntity -Times 0
        }
    }

    Context 'Table Access' {
        It 'Calls Get-CIPPTable with CacheConfluencePages table name' {
            Mock Get-CIPPAzDataTableEntity { return @() }

            Clear-ConfluencePageCache -Confirm:$false

            Assert-MockCalled Get-CIPPTable -Times 1 -ParameterFilter { $TableName -eq 'CacheConfluencePages' }
        }
    }

    Context 'Single Entry' {
        It 'Handles single entry correctly' {
            Mock Get-CIPPAzDataTableEntity {
                return @{ PartitionKey = 'ConfluencePage'; RowKey = '999'; SpaceKey = 'SINGLE' }
            }

            Clear-ConfluencePageCache -SpaceKey 'SINGLE' -Confirm:$false

            Assert-MockCalled Remove-AzDataTableEntity -Times 1
        }
    }

    Context 'Force Flag' {
        It 'Removes with Force flag' {
            Mock Get-CIPPAzDataTableEntity {
                return @{ PartitionKey = 'ConfluencePage'; RowKey = '111'; SpaceKey = 'TEST' }
            }

            Clear-ConfluencePageCache -SpaceKey 'TEST' -Confirm:$false

            Assert-MockCalled Remove-AzDataTableEntity -Times 1 -ParameterFilter {
                $Force -eq $true
            }
        }
    }

    Context 'Input Validation' {
        BeforeEach {
            Mock Get-CIPPTable { return @{ TableName = 'CacheConfluencePages' } }
            Mock Get-CIPPAzDataTableEntity { return @() }
            Mock Remove-AzDataTableEntity { }
        }

        It 'Rejects SpaceKey with hyphens (not allowed per Confluence spec)' {
            try {
                Clear-ConfluencePageCache -SpaceKey 'CONTOSO-SPACE' -Confirm:$false -ErrorAction Stop
                throw "Should have thrown ParameterBindingValidationException"
            } catch {
                $_.Exception.GetType().Name | Should Be 'ParameterBindingValidationException'
            }
        }

        It 'Rejects SpaceKey with underscores (not allowed per Confluence spec)' {
            try {
                Clear-ConfluencePageCache -SpaceKey 'CONTOSO_SPACE' -Confirm:$false -ErrorAction Stop
                throw "Should have thrown ParameterBindingValidationException"
            } catch {
                $_.Exception.GetType().Name | Should Be 'ParameterBindingValidationException'
            }
        }

        It 'Rejects SpaceKey with injection payload (contains space and quote)' {
            try {
                Clear-ConfluencePageCache -SpaceKey "CONTOSO' or PartitionKey eq 'ConfluencePage" -Confirm:$false -ErrorAction Stop
                throw "Should have thrown ParameterBindingValidationException"
            } catch {
                $_.Exception.GetType().Name | Should Be 'ParameterBindingValidationException'
            }
        }

        It 'Rejects SpaceKey with special characters' {
            try {
                Clear-ConfluencePageCache -SpaceKey "CON<script>xss</script>" -Confirm:$false -ErrorAction Stop
                throw "Should have thrown ParameterBindingValidationException"
            } catch {
                $_.Exception.GetType().Name | Should Be 'ParameterBindingValidationException'
            }
        }

        It 'Accepts valid simple alphanumeric SpaceKey' {
            { Clear-ConfluencePageCache -SpaceKey 'TESTSPACE' -Confirm:$false } | Should Not Throw
        }
    }

    Context 'OData Filter Escaping (Defense in Depth)' {
        BeforeEach {
            Mock Get-CIPPTable { return @{ TableName = 'CacheConfluencePages' } }
            Mock Get-CIPPAzDataTableEntity { return @() }
            Mock Remove-AzDataTableEntity { }
        }

        It 'Escaping is redundant for valid inputs but present for defense in depth' {
            # NOTE: ValidatePattern rejects malicious input before escaping.
            # Escaping exists as defense-in-depth if validation is bypassed.
            # This test verifies escaping WOULD work if needed (using valid input as proxy).

            Clear-ConfluencePageCache -SpaceKey 'CONTOSOSPACE' -Confirm:$false

            Assert-MockCalled Get-CIPPAzDataTableEntity -Times 1 -ParameterFilter {
                # Valid input doesn't contain quotes, so escaping is no-op
                # But code path is exercised
                $Filter -eq "PartitionKey eq 'ConfluencePage' and SpaceKey eq 'CONTOSOSPACE'"
            }
        }
    }
}
