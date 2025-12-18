$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'

# Get path to function file - Tests/Confluence -> parent is Tests -> parent is CippExtensions
$moduleRoot = Split-Path (Split-Path $here -Parent) -Parent
$functionPath = Join-Path $moduleRoot (Join-Path 'Public' (Join-Path 'Confluence' $sut))

# Define stub functions for dependencies (required for Pester 3.4 mocking)
function Get-CIPPTable { param($TableName) }
function Get-CIPPAzDataTableEntity { param($Filter) }

Describe 'Get-ConfluenceExtensionConfig' {
    BeforeAll {
        # Dot-source the function for testing
        if (Test-Path $functionPath) {
            . $functionPath
        }
    }

    BeforeEach {
        # Mock CIPP framework functions with default behavior
        Mock Get-CIPPTable { return @{ TableName = 'Extensionsconfig' } }
    }

    Context 'Configuration Exists with Full Confluence Section' {
        It 'Returns Confluence configuration when present' {
            Mock Get-CIPPAzDataTableEntity {
                return @{
                    config = @{
                        Confluence = @{
                            Enabled             = $true
                            BaseURL             = 'https://test.atlassian.net'
                            CloudId             = 'abc123'
                            CreateMissingSpaces = $true
                            SyncUsers           = $true
                            SyncDevices         = $true
                            SyncLicenses        = $true
                            SyncMFA             = $true
                            SyncTeams           = $true
                            SyncSharePoint      = $true
                        }
                    } | ConvertTo-Json -Depth 10
                }
            }

            $result = Get-ConfluenceExtensionConfig

            $result | Should Not BeNullOrEmpty
        }

        It 'Returns Enabled property correctly' {
            Mock Get-CIPPAzDataTableEntity {
                return @{
                    config = @{
                        Confluence = @{
                            Enabled = $true
                            BaseURL = 'https://test.atlassian.net'
                        }
                    } | ConvertTo-Json -Depth 10
                }
            }

            $result = Get-ConfluenceExtensionConfig

            $result.Enabled | Should Be $true
        }

        It 'Returns BaseURL property correctly' {
            Mock Get-CIPPAzDataTableEntity {
                return @{
                    config = @{
                        Confluence = @{
                            Enabled = $true
                            BaseURL = 'https://mycompany.atlassian.net'
                        }
                    } | ConvertTo-Json -Depth 10
                }
            }

            $result = Get-ConfluenceExtensionConfig

            $result.BaseURL | Should Be 'https://mycompany.atlassian.net'
        }

        It 'Returns CloudId property correctly' {
            Mock Get-CIPPAzDataTableEntity {
                return @{
                    config = @{
                        Confluence = @{
                            Enabled = $true
                            BaseURL = 'https://test.atlassian.net'
                            CloudId = 'my-cloud-id-123'
                        }
                    } | ConvertTo-Json -Depth 10
                }
            }

            $result = Get-ConfluenceExtensionConfig

            $result.CloudId | Should Be 'my-cloud-id-123'
        }

        It 'Returns CreateMissingSpaces property correctly' {
            Mock Get-CIPPAzDataTableEntity {
                return @{
                    config = @{
                        Confluence = @{
                            Enabled             = $true
                            BaseURL             = 'https://test.atlassian.net'
                            CreateMissingSpaces = $true
                        }
                    } | ConvertTo-Json -Depth 10
                }
            }

            $result = Get-ConfluenceExtensionConfig

            $result.CreateMissingSpaces | Should Be $true
        }

        It 'Returns all Sync* properties correctly' {
            Mock Get-CIPPAzDataTableEntity {
                return @{
                    config = @{
                        Confluence = @{
                            Enabled        = $true
                            BaseURL        = 'https://test.atlassian.net'
                            SyncUsers      = $true
                            SyncDevices    = $false
                            SyncLicenses   = $true
                            SyncMFA        = $false
                            SyncTeams      = $true
                            SyncSharePoint = $false
                        }
                    } | ConvertTo-Json -Depth 10
                }
            }

            $result = Get-ConfluenceExtensionConfig

            $result.SyncUsers | Should Be $true
            $result.SyncDevices | Should Be $false
            $result.SyncLicenses | Should Be $true
            $result.SyncMFA | Should Be $false
            $result.SyncTeams | Should Be $true
            $result.SyncSharePoint | Should Be $false
        }
    }

    Context 'Configuration Missing' {
        It 'Returns null when Extensionsconfig table is empty' {
            Mock Get-CIPPAzDataTableEntity { return $null }

            $result = Get-ConfluenceExtensionConfig

            $result | Should BeNullOrEmpty
        }

        It 'Returns null when config property is missing' {
            Mock Get-CIPPAzDataTableEntity { return @{ otherProperty = 'value' } }

            $result = Get-ConfluenceExtensionConfig

            $result | Should BeNullOrEmpty
        }

        It 'Returns null when Confluence section is missing' {
            Mock Get-CIPPAzDataTableEntity {
                return @{
                    config = @{
                        Hudu = @{ Enabled = $true; BaseURL = 'https://hudu.test' }
                    } | ConvertTo-Json -Depth 10
                }
            }

            $result = Get-ConfluenceExtensionConfig

            $result | Should BeNullOrEmpty
        }

        It 'Returns null when config is empty JSON object' {
            Mock Get-CIPPAzDataTableEntity {
                return @{ config = '{}' }
            }

            $result = Get-ConfluenceExtensionConfig

            $result | Should BeNullOrEmpty
        }
    }

    Context 'Default Values for Missing Sync Properties' {
        It 'Defaults SyncUsers to true when not specified' {
            Mock Get-CIPPAzDataTableEntity {
                return @{
                    config = @{
                        Confluence = @{
                            Enabled = $true
                            BaseURL = 'https://test.atlassian.net'
                        }
                    } | ConvertTo-Json -Depth 10
                }
            }

            $result = Get-ConfluenceExtensionConfig

            $result.SyncUsers | Should Be $true
        }

        It 'Defaults SyncDevices to true when not specified' {
            Mock Get-CIPPAzDataTableEntity {
                return @{
                    config = @{
                        Confluence = @{
                            Enabled = $true
                            BaseURL = 'https://test.atlassian.net'
                        }
                    } | ConvertTo-Json -Depth 10
                }
            }

            $result = Get-ConfluenceExtensionConfig

            $result.SyncDevices | Should Be $true
        }

        It 'Defaults SyncLicenses to true when not specified' {
            Mock Get-CIPPAzDataTableEntity {
                return @{
                    config = @{
                        Confluence = @{
                            Enabled = $true
                            BaseURL = 'https://test.atlassian.net'
                        }
                    } | ConvertTo-Json -Depth 10
                }
            }

            $result = Get-ConfluenceExtensionConfig

            $result.SyncLicenses | Should Be $true
        }

        It 'Defaults SyncMFA to true when not specified' {
            Mock Get-CIPPAzDataTableEntity {
                return @{
                    config = @{
                        Confluence = @{
                            Enabled = $true
                            BaseURL = 'https://test.atlassian.net'
                        }
                    } | ConvertTo-Json -Depth 10
                }
            }

            $result = Get-ConfluenceExtensionConfig

            $result.SyncMFA | Should Be $true
        }

        It 'Defaults SyncTeams to true when not specified' {
            Mock Get-CIPPAzDataTableEntity {
                return @{
                    config = @{
                        Confluence = @{
                            Enabled = $true
                            BaseURL = 'https://test.atlassian.net'
                        }
                    } | ConvertTo-Json -Depth 10
                }
            }

            $result = Get-ConfluenceExtensionConfig

            $result.SyncTeams | Should Be $true
        }

        It 'Defaults SyncSharePoint to true when not specified' {
            Mock Get-CIPPAzDataTableEntity {
                return @{
                    config = @{
                        Confluence = @{
                            Enabled = $true
                            BaseURL = 'https://test.atlassian.net'
                        }
                    } | ConvertTo-Json -Depth 10
                }
            }

            $result = Get-ConfluenceExtensionConfig

            $result.SyncSharePoint | Should Be $true
        }
    }

    Context 'Table Access' {
        It 'Calls Get-CIPPTable with Extensionsconfig table name' {
            Mock Get-CIPPAzDataTableEntity { return @{ config = '{}' } }

            $result = Get-ConfluenceExtensionConfig

            Assert-MockCalled Get-CIPPTable -Times 1 -ParameterFilter { $TableName -eq 'Extensionsconfig' }
        }

        It 'Calls Get-CIPPAzDataTableEntity to retrieve entity' {
            Mock Get-CIPPAzDataTableEntity { return @{ config = '{}' } }

            $result = Get-ConfluenceExtensionConfig

            Assert-MockCalled Get-CIPPAzDataTableEntity -Times 1
        }
    }

    Context 'Output Type' {
        It 'Returns PSCustomObject when configuration exists' {
            Mock Get-CIPPAzDataTableEntity {
                return @{
                    config = @{
                        Confluence = @{
                            Enabled = $true
                            BaseURL = 'https://test.atlassian.net'
                        }
                    } | ConvertTo-Json -Depth 10
                }
            }

            $result = Get-ConfluenceExtensionConfig

            $result.GetType().Name | Should Be 'PSCustomObject'
        }

        It 'Returns object with all expected properties' {
            Mock Get-CIPPAzDataTableEntity {
                return @{
                    config = @{
                        Confluence = @{
                            Enabled = $true
                            BaseURL = 'https://test.atlassian.net'
                        }
                    } | ConvertTo-Json -Depth 10
                }
            }

            $result = Get-ConfluenceExtensionConfig

            ($result.PSObject.Properties.Name -contains 'Enabled') | Should Be $true
            ($result.PSObject.Properties.Name -contains 'BaseURL') | Should Be $true
            ($result.PSObject.Properties.Name -contains 'CloudId') | Should Be $true
            ($result.PSObject.Properties.Name -contains 'CreateMissingSpaces') | Should Be $true
            ($result.PSObject.Properties.Name -contains 'SyncUsers') | Should Be $true
            ($result.PSObject.Properties.Name -contains 'SyncDevices') | Should Be $true
            ($result.PSObject.Properties.Name -contains 'SyncLicenses') | Should Be $true
            ($result.PSObject.Properties.Name -contains 'SyncMFA') | Should Be $true
            ($result.PSObject.Properties.Name -contains 'SyncTeams') | Should Be $true
            ($result.PSObject.Properties.Name -contains 'SyncSharePoint') | Should Be $true
        }
    }

    Context 'Other Extensions Coexistence' {
        It 'Returns Confluence config when Hudu is also configured' {
            Mock Get-CIPPAzDataTableEntity {
                return @{
                    config = @{
                        Hudu = @{
                            Enabled = $true
                            BaseURL = 'https://hudu.test'
                        }
                        Confluence = @{
                            Enabled = $true
                            BaseURL = 'https://confluence.atlassian.net'
                        }
                    } | ConvertTo-Json -Depth 10
                }
            }

            $result = Get-ConfluenceExtensionConfig

            $result | Should Not BeNullOrEmpty
            $result.BaseURL | Should Be 'https://confluence.atlassian.net'
        }

        It 'Returns Confluence config when multiple extensions configured' {
            Mock Get-CIPPAzDataTableEntity {
                return @{
                    config = @{
                        Hudu = @{ Enabled = $true }
                        NinjaOne = @{ Enabled = $true }
                        Confluence = @{ Enabled = $true; BaseURL = 'https://multi.atlassian.net' }
                        CustomData = @{ }
                    } | ConvertTo-Json -Depth 10
                }
            }

            $result = Get-ConfluenceExtensionConfig

            $result.BaseURL | Should Be 'https://multi.atlassian.net'
        }
    }

    Context 'Disabled Extension' {
        It 'Returns config with Enabled=false when extension is disabled' {
            Mock Get-CIPPAzDataTableEntity {
                return @{
                    config = @{
                        Confluence = @{
                            Enabled = $false
                            BaseURL = 'https://test.atlassian.net'
                        }
                    } | ConvertTo-Json -Depth 10
                }
            }

            $result = Get-ConfluenceExtensionConfig

            $result.Enabled | Should Be $false
        }
    }

    Context 'Boolean Type Coercion' {
        It 'Returns boolean true for Enabled=true' {
            Mock Get-CIPPAzDataTableEntity {
                return @{
                    config = @{
                        Confluence = @{ Enabled = $true; BaseURL = 'https://test.atlassian.net' }
                    } | ConvertTo-Json -Depth 10
                }
            }

            $result = Get-ConfluenceExtensionConfig

            $result.Enabled.GetType().Name | Should Be 'Boolean'
            $result.Enabled | Should Be $true
        }

        It 'Returns boolean false for Enabled=false' {
            Mock Get-CIPPAzDataTableEntity {
                return @{
                    config = @{
                        Confluence = @{ Enabled = $false; BaseURL = 'https://test.atlassian.net' }
                    } | ConvertTo-Json -Depth 10
                }
            }

            $result = Get-ConfluenceExtensionConfig

            $result.Enabled | Should Be $false
        }

        It 'Returns boolean for CreateMissingSpaces' {
            Mock Get-CIPPAzDataTableEntity {
                return @{
                    config = @{
                        Confluence = @{
                            Enabled             = $true
                            BaseURL             = 'https://test.atlassian.net'
                            CreateMissingSpaces = $true
                        }
                    } | ConvertTo-Json -Depth 10
                }
            }

            $result = Get-ConfluenceExtensionConfig

            $result.CreateMissingSpaces.GetType().Name | Should Be 'Boolean'
        }
    }
}
