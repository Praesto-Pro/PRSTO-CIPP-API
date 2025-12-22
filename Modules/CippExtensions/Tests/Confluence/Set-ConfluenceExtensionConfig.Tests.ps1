$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'

# Get path to function file - Tests/Confluence -> parent is Tests -> parent is CippExtensions
$moduleRoot = Split-Path (Split-Path $here -Parent) -Parent
$functionPath = Join-Path $moduleRoot (Join-Path 'Public' (Join-Path 'Confluence' $sut))

# Define stub functions for dependencies (required for Pester 3.4 mocking)
function Get-CIPPTable { param($TableName) }
function Get-CIPPAzDataTableEntity { param($Filter) }
function Add-CIPPAzDataTableEntity { param($Entity, [switch]$Force) }

Describe 'Set-ConfluenceExtensionConfig' {
    BeforeAll {
        # Dot-source the function for testing
        if (Test-Path $functionPath) {
            . $functionPath
        }
    }

    BeforeEach {
        # Mock CIPP framework functions with default behavior
        Mock Get-CIPPTable { return @{ TableName = 'Extensionsconfig' } }
        Mock Add-CIPPAzDataTableEntity { }
    }

    Context 'Validation - BaseURL Required When Enabled' {
        It 'Throws when Enabled without BaseURL' {
            Mock Get-CIPPAzDataTableEntity { return @{ config = '{}' } }

            { Set-ConfluenceExtensionConfig -Enabled $true } | Should Throw 'BaseURL is required'
        }

        It 'Throws when Enabled with empty BaseURL' {
            Mock Get-CIPPAzDataTableEntity { return @{ config = '{}' } }

            { Set-ConfluenceExtensionConfig -Enabled $true -BaseURL '' } | Should Throw 'BaseURL is required'
        }

        It 'Does not throw when disabled without BaseURL' {
            Mock Get-CIPPAzDataTableEntity { return @{ config = '{}' } }

            { Set-ConfluenceExtensionConfig -Enabled $false } | Should Not Throw
        }
    }

    Context 'Validation - BaseURL Pattern' {
        It 'Throws on invalid BaseURL pattern' {
            Mock Get-CIPPAzDataTableEntity { return @{ config = '{}' } }

            { Set-ConfluenceExtensionConfig -Enabled $true -BaseURL 'http://invalid.com' } | Should Throw 'must match pattern'
        }

        It 'Throws on HTTP URL' {
            Mock Get-CIPPAzDataTableEntity { return @{ config = '{}' } }

            { Set-ConfluenceExtensionConfig -Enabled $true -BaseURL 'http://company.atlassian.net' } | Should Throw 'must match pattern'
        }

        It 'Throws on non-atlassian domain' {
            Mock Get-CIPPAzDataTableEntity { return @{ config = '{}' } }

            { Set-ConfluenceExtensionConfig -Enabled $true -BaseURL 'https://company.confluence.com' } | Should Throw 'must match pattern'
        }

        It 'Accepts valid atlassian.net URL' {
            Mock Get-CIPPAzDataTableEntity { return @{ config = '{}' } }

            { Set-ConfluenceExtensionConfig -Enabled $true -BaseURL 'https://company.atlassian.net' } | Should Not Throw
        }

        It 'Accepts valid atlassian.net URL with trailing slash' {
            Mock Get-CIPPAzDataTableEntity { return @{ config = '{}' } }

            { Set-ConfluenceExtensionConfig -Enabled $true -BaseURL 'https://company.atlassian.net/' } | Should Not Throw
        }

        It 'Accepts valid api.atlassian.com URL' {
            Mock Get-CIPPAzDataTableEntity { return @{ config = '{}' } }

            { Set-ConfluenceExtensionConfig -Enabled $true -BaseURL 'https://api.atlassian.com/ex/confluence/abc123' } | Should Not Throw
        }

        It 'Accepts URL with hyphen in subdomain' {
            Mock Get-CIPPAzDataTableEntity { return @{ config = '{}' } }

            { Set-ConfluenceExtensionConfig -Enabled $true -BaseURL 'https://my-company.atlassian.net' } | Should Not Throw
        }
    }

    Context 'Preserves Other Extensions' {
        It 'Calls Add-CIPPAzDataTableEntity with config containing Confluence' {
            Mock Get-CIPPAzDataTableEntity {
                return @{
                    PartitionKey = 'CippExtensions'
                    RowKey       = 'Config'
                    config       = @{
                        Hudu = @{ Enabled = $true; BaseURL = 'https://hudu.test' }
                    } | ConvertTo-Json
                }
            }

            Set-ConfluenceExtensionConfig -Enabled $true -BaseURL 'https://test.atlassian.net'

            Assert-MockCalled Add-CIPPAzDataTableEntity -Times 1 -ParameterFilter {
                $Entity.config -match '"Confluence"'
            }
        }

        It 'Preserves Hudu config in saved entity' {
            Mock Get-CIPPAzDataTableEntity {
                return @{
                    PartitionKey = 'CippExtensions'
                    RowKey       = 'Config'
                    config       = @{
                        Hudu = @{ Enabled = $true; BaseURL = 'https://hudu.test' }
                    } | ConvertTo-Json
                }
            }

            Set-ConfluenceExtensionConfig -Enabled $true -BaseURL 'https://test.atlassian.net'

            Assert-MockCalled Add-CIPPAzDataTableEntity -Times 1 -ParameterFilter {
                $Entity.config -match '"Hudu"'
            }
        }
    }

    Context 'WhatIf Support' {
        It 'Does not modify table when WhatIf' {
            Mock Get-CIPPAzDataTableEntity { return @{ config = '{}' } }

            Set-ConfluenceExtensionConfig -Enabled $true -BaseURL 'https://test.atlassian.net' -WhatIf

            Assert-MockCalled Add-CIPPAzDataTableEntity -Times 0 -Exactly
        }

        It 'Still validates input when WhatIf' {
            Mock Get-CIPPAzDataTableEntity { return @{ config = '{}' } }

            { Set-ConfluenceExtensionConfig -Enabled $true -WhatIf } | Should Throw 'BaseURL is required'
        }
    }

    Context 'Configuration Values' {
        It 'Saves Enabled value in config' {
            Mock Get-CIPPAzDataTableEntity { return @{ config = '{}' } }

            Set-ConfluenceExtensionConfig -Enabled $true -BaseURL 'https://test.atlassian.net'

            Assert-MockCalled Add-CIPPAzDataTableEntity -Times 1 -ParameterFilter {
                $Entity.config -match '"Enabled":\s*true'
            }
        }

        It 'Saves BaseURL value in config' {
            Mock Get-CIPPAzDataTableEntity { return @{ config = '{}' } }

            Set-ConfluenceExtensionConfig -Enabled $true -BaseURL 'https://mycompany.atlassian.net'

            Assert-MockCalled Add-CIPPAzDataTableEntity -Times 1 -ParameterFilter {
                $Entity.config -match 'https://mycompany\.atlassian\.net'
            }
        }

        It 'Saves CloudId value when provided' {
            Mock Get-CIPPAzDataTableEntity { return @{ config = '{}' } }

            Set-ConfluenceExtensionConfig -Enabled $true -BaseURL 'https://test.atlassian.net' -CloudId 'my-cloud-123'

            Assert-MockCalled Add-CIPPAzDataTableEntity -Times 1 -ParameterFilter {
                $Entity.config -match 'my-cloud-123'
            }
        }

        It 'Saves SyncUsers as false when specified' {
            Mock Get-CIPPAzDataTableEntity { return @{ config = '{}' } }

            Set-ConfluenceExtensionConfig -Enabled $true -BaseURL 'https://test.atlassian.net' -SyncUsers $false

            Assert-MockCalled Add-CIPPAzDataTableEntity -Times 1 -ParameterFilter {
                $Entity.config -match '"SyncUsers":\s*false'
            }
        }

        It 'Saves CreateMissingSpaces as true when specified' {
            Mock Get-CIPPAzDataTableEntity { return @{ config = '{}' } }

            Set-ConfluenceExtensionConfig -Enabled $true -BaseURL 'https://test.atlassian.net' -CreateMissingSpaces $true

            Assert-MockCalled Add-CIPPAzDataTableEntity -Times 1 -ParameterFilter {
                $Entity.config -match '"CreateMissingSpaces":\s*true'
            }
        }
    }

    Context 'PartitionKey and RowKey Handling' {
        It 'Preserves existing PartitionKey' {
            Mock Get-CIPPAzDataTableEntity {
                return @{
                    PartitionKey = 'CustomPartition'
                    RowKey       = 'CustomRow'
                    config       = '{}'
                }
            }

            Set-ConfluenceExtensionConfig -Enabled $true -BaseURL 'https://test.atlassian.net'

            Assert-MockCalled Add-CIPPAzDataTableEntity -Times 1 -ParameterFilter {
                $Entity.PartitionKey -eq 'CustomPartition'
            }
        }

        It 'Preserves existing RowKey' {
            Mock Get-CIPPAzDataTableEntity {
                return @{
                    PartitionKey = 'CustomPartition'
                    RowKey       = 'CustomRow'
                    config       = '{}'
                }
            }

            Set-ConfluenceExtensionConfig -Enabled $true -BaseURL 'https://test.atlassian.net'

            Assert-MockCalled Add-CIPPAzDataTableEntity -Times 1 -ParameterFilter {
                $Entity.RowKey -eq 'CustomRow'
            }
        }

        It 'Uses default PartitionKey when none exists' {
            Mock Get-CIPPAzDataTableEntity { return @{ config = '{}' } }

            Set-ConfluenceExtensionConfig -Enabled $true -BaseURL 'https://test.atlassian.net'

            Assert-MockCalled Add-CIPPAzDataTableEntity -Times 1 -ParameterFilter {
                $Entity.PartitionKey -eq 'CippExtensions'
            }
        }

        It 'Uses default RowKey when none exists' {
            Mock Get-CIPPAzDataTableEntity { return @{ config = '{}' } }

            Set-ConfluenceExtensionConfig -Enabled $true -BaseURL 'https://test.atlassian.net'

            Assert-MockCalled Add-CIPPAzDataTableEntity -Times 1 -ParameterFilter {
                $Entity.RowKey -eq 'Config'
            }
        }
    }

    Context 'Table Operations' {
        It 'Calls Get-CIPPTable with Extensionsconfig table name' {
            Mock Get-CIPPAzDataTableEntity { return @{ config = '{}' } }

            Set-ConfluenceExtensionConfig -Enabled $true -BaseURL 'https://test.atlassian.net'

            Assert-MockCalled Get-CIPPTable -Times 1 -ParameterFilter { $TableName -eq 'Extensionsconfig' }
        }

        It 'Calls Add-CIPPAzDataTableEntity with Force flag' {
            Mock Get-CIPPAzDataTableEntity { return @{ config = '{}' } }

            Set-ConfluenceExtensionConfig -Enabled $true -BaseURL 'https://test.atlassian.net'

            Assert-MockCalled Add-CIPPAzDataTableEntity -Times 1 -ParameterFilter {
                $Force -eq $true
            }
        }
    }

    Context 'New Configuration' {
        It 'Creates config when no entity exists' {
            Mock Get-CIPPAzDataTableEntity { return $null }

            Set-ConfluenceExtensionConfig -Enabled $true -BaseURL 'https://test.atlassian.net'

            Assert-MockCalled Add-CIPPAzDataTableEntity -Times 1 -ParameterFilter {
                $Entity.config -match '"Confluence"'
            }
        }

        It 'Creates config when entity has no config property' {
            Mock Get-CIPPAzDataTableEntity { return @{ otherProp = 'value' } }

            Set-ConfluenceExtensionConfig -Enabled $true -BaseURL 'https://test.atlassian.net'

            Assert-MockCalled Add-CIPPAzDataTableEntity -Times 1 -ParameterFilter {
                $Entity.config -match '"Confluence"'
            }
        }
    }

    Context 'Update Existing Confluence Configuration' {
        It 'Updates existing Confluence settings with new BaseURL' {
            Mock Get-CIPPAzDataTableEntity {
                return @{
                    PartitionKey = 'CippExtensions'
                    RowKey       = 'Config'
                    config       = @{
                        Confluence = @{
                            Enabled = $false
                            BaseURL = 'https://old.atlassian.net'
                        }
                    } | ConvertTo-Json
                }
            }

            Set-ConfluenceExtensionConfig -Enabled $true -BaseURL 'https://new.atlassian.net'

            Assert-MockCalled Add-CIPPAzDataTableEntity -Times 1 -ParameterFilter {
                $Entity.config -match 'https://new\.atlassian\.net'
            }
        }
    }

    Context 'All Sync Types' {
        It 'Includes all sync type fields in saved config' {
            Mock Get-CIPPAzDataTableEntity { return @{ config = '{}' } }

            Set-ConfluenceExtensionConfig -Enabled $true -BaseURL 'https://test.atlassian.net' `
                -SyncUsers $false `
                -SyncDevices $false `
                -SyncLicenses $false `
                -SyncMFA $false `
                -SyncTeams $false `
                -SyncSharePoint $false

            Assert-MockCalled Add-CIPPAzDataTableEntity -Times 1 -ParameterFilter {
                $Entity.config -match '"SyncUsers"' -and
                $Entity.config -match '"SyncDevices"' -and
                $Entity.config -match '"SyncLicenses"' -and
                $Entity.config -match '"SyncMFA"' -and
                $Entity.config -match '"SyncTeams"' -and
                $Entity.config -match '"SyncSharePoint"'
            }
        }
    }

    Context 'Default Values' {
        It 'Includes Enabled field when not specified' {
            Mock Get-CIPPAzDataTableEntity { return @{ config = '{}' } }

            Set-ConfluenceExtensionConfig -BaseURL 'https://test.atlassian.net'

            Assert-MockCalled Add-CIPPAzDataTableEntity -Times 1 -ParameterFilter {
                $Entity.config -match '"Enabled"'
            }
        }

        It 'Includes all Sync fields when using defaults' {
            Mock Get-CIPPAzDataTableEntity { return @{ config = '{}' } }

            Set-ConfluenceExtensionConfig -Enabled $true -BaseURL 'https://test.atlassian.net'

            Assert-MockCalled Add-CIPPAzDataTableEntity -Times 1 -ParameterFilter {
                $Entity.config -match '"SyncUsers":\s*true' -and
                $Entity.config -match '"SyncDevices":\s*true' -and
                $Entity.config -match '"SyncLicenses":\s*true'
            }
        }
    }
}
