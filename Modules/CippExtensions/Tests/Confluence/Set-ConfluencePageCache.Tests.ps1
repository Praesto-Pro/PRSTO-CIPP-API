$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'

# Get path to function file - Tests/Confluence -> parent is Tests -> parent is CippExtensions
$moduleRoot = Split-Path (Split-Path $here -Parent) -Parent
$functionPath = Join-Path $moduleRoot (Join-Path 'Private' (Join-Path 'Confluence' $sut))

# Define stub functions for dependencies (required for Pester 3.4 mocking)
function Get-CIPPTable { param($TableName) }
function Add-CIPPAzDataTableEntity { param($Entity, [switch]$Force) }

Describe 'Set-ConfluencePageCache' {
    BeforeAll {
        # Dot-source the function for testing
        if (Test-Path $functionPath) {
            . $functionPath
        }
    }

    BeforeEach {
        # Mock CIPP framework functions with default behavior
        Mock Get-CIPPTable { return @{ TableName = 'CacheConfluencePages' } }
        Mock Add-CIPPAzDataTableEntity { }
    }

    Context 'Cache Entry Creation' {
        It 'Calls Add-CIPPAzDataTableEntity with correct PageId as RowKey' {
            Set-ConfluencePageCache -PageId '12345' -SpaceKey 'TEST' -PageTitle 'Test Page' -Hash 'HASH123'

            Assert-MockCalled Add-CIPPAzDataTableEntity -Times 1 -ParameterFilter {
                $Entity.RowKey -eq '12345'
            }
        }

        It 'Calls Add-CIPPAzDataTableEntity with ConfluencePage as PartitionKey' {
            Set-ConfluencePageCache -PageId '12345' -SpaceKey 'TEST' -PageTitle 'Test Page' -Hash 'HASH123'

            Assert-MockCalled Add-CIPPAzDataTableEntity -Times 1 -ParameterFilter {
                $Entity.PartitionKey -eq 'ConfluencePage'
            }
        }

        It 'Calls Add-CIPPAzDataTableEntity with correct SpaceKey' {
            Set-ConfluencePageCache -PageId '12345' -SpaceKey 'MYSPACE' -PageTitle 'Test Page' -Hash 'HASH123'

            Assert-MockCalled Add-CIPPAzDataTableEntity -Times 1 -ParameterFilter {
                $Entity.SpaceKey -eq 'MYSPACE'
            }
        }

        It 'Calls Add-CIPPAzDataTableEntity with correct PageTitle' {
            Set-ConfluencePageCache -PageId '12345' -SpaceKey 'TEST' -PageTitle 'My Custom Title' -Hash 'HASH123'

            Assert-MockCalled Add-CIPPAzDataTableEntity -Times 1 -ParameterFilter {
                $Entity.PageTitle -eq 'My Custom Title'
            }
        }

        It 'Calls Add-CIPPAzDataTableEntity with correct Hash' {
            Set-ConfluencePageCache -PageId '12345' -SpaceKey 'TEST' -PageTitle 'Test Page' -Hash 'ABCDEF1234567890'

            Assert-MockCalled Add-CIPPAzDataTableEntity -Times 1 -ParameterFilter {
                $Entity.Hash -eq 'ABCDEF1234567890'
            }
        }

        It 'Calls Add-CIPPAzDataTableEntity with LastUpdated timestamp' {
            Set-ConfluencePageCache -PageId '12345' -SpaceKey 'TEST' -PageTitle 'Test Page' -Hash 'HASH123'

            Assert-MockCalled Add-CIPPAzDataTableEntity -Times 1 -ParameterFilter {
                $Entity.LastUpdated -ne $null -and $Entity.LastUpdated -match '\d{4}-\d{2}-\d{2}'
            }
        }

        It 'Calls Add-CIPPAzDataTableEntity with Force flag for upsert' {
            Set-ConfluencePageCache -PageId '12345' -SpaceKey 'TEST' -PageTitle 'Test Page' -Hash 'HASH123'

            Assert-MockCalled Add-CIPPAzDataTableEntity -Times 1 -ParameterFilter {
                $Force -eq $true
            }
        }
    }

    Context 'Table Access' {
        It 'Calls Get-CIPPTable with CacheConfluencePages table name' {
            Set-ConfluencePageCache -PageId '12345' -SpaceKey 'TEST' -PageTitle 'Test Page' -Hash 'HASH123'

            Assert-MockCalled Get-CIPPTable -Times 1 -ParameterFilter { $TableName -eq 'CacheConfluencePages' }
        }
    }

    Context 'Different Values' {
        It 'Handles long PageId correctly' {
            Set-ConfluencePageCache -PageId '123456789012345678901234567890' -SpaceKey 'TEST' -PageTitle 'Test Page' -Hash 'HASH123'

            Assert-MockCalled Add-CIPPAzDataTableEntity -Times 1 -ParameterFilter {
                $Entity.RowKey -eq '123456789012345678901234567890'
            }
        }

        It 'Handles SpaceKey with special characters' {
            Set-ConfluencePageCache -PageId '12345' -SpaceKey 'CONTOSO-TEST' -PageTitle 'Test Page' -Hash 'HASH123'

            Assert-MockCalled Add-CIPPAzDataTableEntity -Times 1 -ParameterFilter {
                $Entity.SpaceKey -eq 'CONTOSO-TEST'
            }
        }

        It 'Handles PageTitle with special characters' {
            Set-ConfluencePageCache -PageId '12345' -SpaceKey 'TEST' -PageTitle "User's Inventory & Licenses" -Hash 'HASH123'

            Assert-MockCalled Add-CIPPAzDataTableEntity -Times 1 -ParameterFilter {
                $Entity.PageTitle -eq "User's Inventory & Licenses"
            }
        }

        It 'Handles 40-character SHA1 hash' {
            $sha1Hash = 'ABCDEF1234567890ABCDEF1234567890ABCDEF12'

            Set-ConfluencePageCache -PageId '12345' -SpaceKey 'TEST' -PageTitle 'Test Page' -Hash $sha1Hash

            Assert-MockCalled Add-CIPPAzDataTableEntity -Times 1 -ParameterFilter {
                $Entity.Hash -eq 'ABCDEF1234567890ABCDEF1234567890ABCDEF12'
            }
        }
    }

    Context 'Entity Structure' {
        It 'Creates entity with all required properties' {
            Set-ConfluencePageCache -PageId '12345' -SpaceKey 'TEST' -PageTitle 'Test Page' -Hash 'HASH123'

            Assert-MockCalled Add-CIPPAzDataTableEntity -Times 1 -ParameterFilter {
                $Entity.PartitionKey -ne $null -and
                $Entity.RowKey -ne $null -and
                $Entity.SpaceKey -ne $null -and
                $Entity.PageTitle -ne $null -and
                $Entity.Hash -ne $null -and
                $Entity.LastUpdated -ne $null
            }
        }
    }
}
