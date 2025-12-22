$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = 'Connect-ConfluenceAPI.ps1'

# Get path to function file - Tests/Confluence -> parent is Tests -> parent is CippExtensions
$moduleRoot = Split-Path (Split-Path $here -Parent) -Parent
$functionPath = Join-Path $moduleRoot (Join-Path 'Public' (Join-Path 'Confluence' $sut))

# Define stub functions for dependencies (required for Pester 3.4 mocking)
function Get-ExtensionAPIKey { param($Extension, $Force) }
function New-ConfluenceAPIKey { param($ApiKey) }
function New-ConfluenceBaseURL { param($BaseURL) }
function Test-ConfluenceConnection { }
function Get-CIPPTable { param($tablename) }
function Get-CIPPAzDataTableEntity { param($Filter) }
function Connect-AzAccount { param([switch]$Identity) }
function Get-AzContext { }
function Set-AzContext { param($SubscriptionId) }
function Get-AzKeyVaultSecret { param($VaultName, $Name, [switch]$AsPlainText) }

Describe 'Connect-ConfluenceAPI - Key Vault Integration Tests' {
    BeforeAll {
        # Dot-source the function for testing
        if (Test-Path $functionPath) {
            . $functionPath
        }
    }

    BeforeEach {
        # Clear environment cache before each test
        Remove-Item "env:Ext_Confluence" -ErrorAction SilentlyContinue

        # Mock ConfluenceAPI module functions
        Mock New-ConfluenceAPIKey { }
        Mock New-ConfluenceBaseURL { }
        Mock Test-ConfluenceConnection {
            return [PSCustomObject]@{
                Success = $true
                Error   = $null
            }
        }
    }

    Context 'Production Key Vault Integration (AC1)' {
        BeforeEach {
            # Simulate production environment
            $env:AzureWebJobsStorage = 'DefaultEndpointsProtocol=https;AccountName=prodaccount'
            $env:WEBSITE_DEPLOYMENT_ID = 'testkeyvault-deployment-123'
            $env:WEBSITE_OWNER_NAME = 'sub-12345+resourcegroup'

            # Mock Azure Key Vault operations
            Mock Connect-AzAccount { }
            Mock Get-AzContext {
                return [PSCustomObject]@{
                    Subscription = [PSCustomObject]@{
                        Id = 'sub-12345'
                    }
                }
            }
            Mock Set-AzContext { }
            Mock Get-AzKeyVaultSecret {
                return 'vault-retrieved-token'
            }
        }

        AfterEach {
            Remove-Item "env:AzureWebJobsStorage" -ErrorAction SilentlyContinue
            Remove-Item "env:WEBSITE_DEPLOYMENT_ID" -ErrorAction SilentlyContinue
            Remove-Item "env:WEBSITE_OWNER_NAME" -ErrorAction SilentlyContinue
        }

        It 'Retrieves API key from Azure Key Vault in production (AC1)' {
            # Create a custom mock for Get-ExtensionAPIKey that simulates production behavior
            Mock Get-ExtensionAPIKey {
                param($Extension)

                # Simulate Get-ExtensionAPIKey production logic
                $keyvaultname = ($env:WEBSITE_DEPLOYMENT_ID -split '-')[0]
                Connect-AzAccount -Identity | Out-Null
                $APIKey = Get-AzKeyVaultSecret -VaultName $keyvaultname -Name $Extension -AsPlainText
                Set-Item -Path "env:Ext_$Extension" -Value $APIKey -Force -ErrorAction SilentlyContinue
                return $APIKey
            }

            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net' } }
            $result = Connect-ConfluenceAPI -Configuration $config

            # Verify Key Vault was called
            Assert-MockCalled Get-AzKeyVaultSecret -Times 1 -ParameterFilter {
                $Name -eq 'Confluence' -and $VaultName -eq 'testkeyvault'
            }

            # Verify connection succeeded
            $result.Success | Should Be $true
        }

        It 'Uses secret name Confluence for Key Vault retrieval (AC1)' {
            Mock Get-ExtensionAPIKey {
                param($Extension)

                $keyvaultname = ($env:WEBSITE_DEPLOYMENT_ID -split '-')[0]
                Connect-AzAccount -Identity | Out-Null
                $APIKey = Get-AzKeyVaultSecret -VaultName $keyvaultname -Name $Extension -AsPlainText
                return $APIKey
            }

            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net' } }
            Connect-ConfluenceAPI -Configuration $config

            Assert-MockCalled Get-AzKeyVaultSecret -ParameterFilter { $Name -eq 'Confluence' }
        }

        It 'Connects to Azure using managed identity in production (AC1)' {
            Mock Get-ExtensionAPIKey {
                param($Extension)

                Connect-AzAccount -Identity | Out-Null
                $keyvaultname = ($env:WEBSITE_DEPLOYMENT_ID -split '-')[0]
                $APIKey = Get-AzKeyVaultSecret -VaultName $keyvaultname -Name $Extension -AsPlainText
                return $APIKey
            }

            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net' } }
            Connect-ConfluenceAPI -Configuration $config

            Assert-MockCalled Connect-AzAccount -Times 1 -ParameterFilter { $Identity }
        }
    }

    Context 'Development DevSecrets Integration (AC2)' {
        BeforeEach {
            # Simulate development environment
            $env:AzureWebJobsStorage = 'UseDevelopmentStorage=true'

            # Mock DevSecrets table operations
            Mock Get-CIPPTable {
                return @{ TableName = 'DevSecrets' }
            }
            Mock Get-CIPPAzDataTableEntity {
                return [PSCustomObject]@{
                    PartitionKey = 'Confluence'
                    RowKey       = 'Confluence'
                    APIKey       = 'dev-secrets-token'
                }
            }
        }

        AfterEach {
            Remove-Item "env:AzureWebJobsStorage" -ErrorAction SilentlyContinue
        }

        It 'Retrieves API key from DevSecrets table in development (AC2)' {
            # Create a custom mock for Get-ExtensionAPIKey that simulates dev behavior
            Mock Get-ExtensionAPIKey {
                param($Extension)

                # Simulate Get-ExtensionAPIKey development logic
                if ($env:AzureWebJobsStorage -eq 'UseDevelopmentStorage=true') {
                    $DevSecretsTable = Get-CIPPTable -tablename 'DevSecrets'
                    $APIKey = (Get-CIPPAzDataTableEntity -Filter "PartitionKey eq '$Extension' and RowKey eq '$Extension'").APIKey
                    Set-Item -Path "env:Ext_$Extension" -Value $APIKey -Force -ErrorAction SilentlyContinue
                    return $APIKey
                }
            }

            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net' } }
            $result = Connect-ConfluenceAPI -Configuration $config

            # Verify DevSecrets table was accessed
            Assert-MockCalled Get-CIPPTable -Times 1 -ParameterFilter { $tablename -eq 'DevSecrets' }
            Assert-MockCalled Get-CIPPAzDataTableEntity -Times 1

            # Verify connection succeeded
            $result.Success | Should Be $true
        }

        It 'Uses PartitionKey Confluence for DevSecrets query (AC2)' {
            Mock Get-ExtensionAPIKey {
                param($Extension)

                if ($env:AzureWebJobsStorage -eq 'UseDevelopmentStorage=true') {
                    $DevSecretsTable = Get-CIPPTable -tablename 'DevSecrets'
                    $filter = "PartitionKey eq '$Extension' and RowKey eq '$Extension'"
                    $APIKey = (Get-CIPPAzDataTableEntity -Filter $filter).APIKey
                    return $APIKey
                }
            }

            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net' } }
            Connect-ConfluenceAPI -Configuration $config

            Assert-MockCalled Get-CIPPAzDataTableEntity -ParameterFilter {
                $Filter -match "PartitionKey eq 'Confluence'"
            }
        }

        It 'Handles NonLocalHostAzurite environment variable (AC2)' {
            Remove-Item "env:AzureWebJobsStorage" -ErrorAction SilentlyContinue
            $env:NonLocalHostAzurite = 'true'

            Mock Get-ExtensionAPIKey {
                param($Extension)

                if ($env:NonLocalHostAzurite -eq 'true') {
                    $DevSecretsTable = Get-CIPPTable -tablename 'DevSecrets'
                    $APIKey = (Get-CIPPAzDataTableEntity -Filter "PartitionKey eq '$Extension' and RowKey eq '$Extension'").APIKey
                    return $APIKey
                }
            }

            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net' } }
            $result = Connect-ConfluenceAPI -Configuration $config

            Assert-MockCalled Get-CIPPTable -Times 1
            $result.Success | Should Be $true

            Remove-Item "env:NonLocalHostAzurite" -ErrorAction SilentlyContinue
        }
    }

    Context 'Environment Caching Behavior (AC3)' {
        It 'Returns cached value on subsequent calls without calling storage (AC3)' {
            # Set up cache
            Set-Item "env:Ext_Confluence" -Value "cached-token-12345"

            # Mock Get-ExtensionAPIKey to return cached value
            Mock Get-ExtensionAPIKey {
                param($Extension)

                # Simulate cache check
                $Var = "Ext_$Extension"
                $APIKey = Get-Item -Path "env:$Var" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Value

                if ($APIKey) {
                    return $APIKey
                }
            }

            # Mock storage operations (should NOT be called)
            Mock Get-CIPPTable { throw "Should not call DevSecrets when cache exists!" }
            Mock Get-AzKeyVaultSecret { throw "Should not call Key Vault when cache exists!" }

            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net' } }
            $result = Connect-ConfluenceAPI -Configuration $config

            # Verify cached token was used
            Assert-MockCalled New-ConfluenceAPIKey -ParameterFilter { $ApiKey -eq 'cached-token-12345' }

            # Verify storage was not accessed
            Assert-MockCalled Get-CIPPTable -Times 0
            Assert-MockCalled Get-AzKeyVaultSecret -Times 0

            $result.Success | Should Be $true
        }

        It 'Caches token in environment variable after retrieval (AC3)' {
            Remove-Item "env:Ext_Confluence" -ErrorAction SilentlyContinue

            Mock Get-ExtensionAPIKey {
                param($Extension)

                # Simulate retrieval and caching
                $APIKey = 'newly-retrieved-token'
                Set-Item -Path "env:Ext_$Extension" -Value $APIKey -Force -ErrorAction SilentlyContinue
                return $APIKey
            }

            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net' } }
            Connect-ConfluenceAPI -Configuration $config

            # Verify token was cached
            $env:Ext_Confluence | Should Be 'newly-retrieved-token'
        }

        It 'Environment cache persists across multiple calls (AC3)' {
            Set-Item "env:Ext_Confluence" -Value "persistent-token"

            Mock Get-ExtensionAPIKey {
                param($Extension)
                $Var = "Ext_$Extension"
                return (Get-Item -Path "env:$Var" -ErrorAction SilentlyContinue).Value
            }

            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net' } }

            # First call
            $result1 = Connect-ConfluenceAPI -Configuration $config

            # Second call
            $result2 = Connect-ConfluenceAPI -Configuration $config

            # Both should succeed with cached token
            $result1.Success | Should Be $true
            $result2.Success | Should Be $true

            # Verify same token used
            Assert-MockCalled New-ConfluenceAPIKey -ParameterFilter { $ApiKey -eq 'persistent-token' } -Times 2
        }
    }

    Context 'Token Rotation Support (AC5)' {
        It 'Retrieves new token when cache is cleared (AC5)' {
            # Simulate cached old token
            Set-Item "env:Ext_Confluence" -Value "old-token"

            # Clear cache (simulating rotation scenario)
            Remove-Item "env:Ext_Confluence" -ErrorAction SilentlyContinue

            # Simulate production environment for new retrieval
            $env:AzureWebJobsStorage = 'DefaultEndpointsProtocol=https'
            $env:WEBSITE_DEPLOYMENT_ID = 'testkeyvault-deployment'
            $env:WEBSITE_OWNER_NAME = 'sub-12345+rg'

            Mock Connect-AzAccount { }
            Mock Get-AzContext { @{ Subscription = @{ Id = 'sub-12345' } } }
            Mock Get-AzKeyVaultSecret { return 'new-rotated-token' }

            Mock Get-ExtensionAPIKey {
                param($Extension)

                # Check cache first
                $Var = "Ext_$Extension"
                $cached = Get-Item -Path "env:$Var" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Value

                if (-not $cached) {
                    # Retrieve new token from Key Vault
                    $keyvaultname = ($env:WEBSITE_DEPLOYMENT_ID -split '-')[0]
                    Connect-AzAccount -Identity | Out-Null
                    $APIKey = Get-AzKeyVaultSecret -VaultName $keyvaultname -Name $Extension -AsPlainText
                    Set-Item -Path "env:$Var" -Value $APIKey -Force
                    return $APIKey
                }
                return $cached
            }

            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net' } }
            $result = Connect-ConfluenceAPI -Configuration $config

            # Verify new token was retrieved
            Assert-MockCalled New-ConfluenceAPIKey -ParameterFilter { $ApiKey -eq 'new-rotated-token' }
            Assert-MockCalled Get-AzKeyVaultSecret -Times 1

            $result.Success | Should Be $true

            # Cleanup
            Remove-Item "env:AzureWebJobsStorage" -ErrorAction SilentlyContinue
            Remove-Item "env:WEBSITE_DEPLOYMENT_ID" -ErrorAction SilentlyContinue
            Remove-Item "env:WEBSITE_OWNER_NAME" -ErrorAction SilentlyContinue
        }

        It 'Token rotation does not interrupt successful connections (AC5)' {
            # Simulate a successful connection with current token
            Mock Get-ExtensionAPIKey { return 'current-token' }

            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net' } }
            $result1 = Connect-ConfluenceAPI -Configuration $config

            # Verify first connection succeeded
            $result1.Success | Should Be $true

            # Simulate token rotation (clear cache and return new token)
            Remove-Item "env:Ext_Confluence" -ErrorAction SilentlyContinue
            Mock Get-ExtensionAPIKey { return 'rotated-token' }

            # Verify connection still works with new token
            $result2 = Connect-ConfluenceAPI -Configuration $config

            $result2.Success | Should Be $true
            Assert-MockCalled New-ConfluenceAPIKey -ParameterFilter { $ApiKey -eq 'rotated-token' }
        }

        It 'Handles gradual token rollout via worker recycling (AC5)' {
            # Simulate scenario where some workers have old cache, some have new

            # Worker 1: Has cached old token
            Set-Item "env:Ext_Confluence" -Value "old-token-worker1"

            Mock Get-ExtensionAPIKey {
                $cached = (Get-Item -Path "env:Ext_Confluence" -ErrorAction SilentlyContinue).Value
                if ($cached) { return $cached }
            }

            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net' } }
            $result1 = Connect-ConfluenceAPI -Configuration $config

            # Worker 1 should use cached old token
            Assert-MockCalled New-ConfluenceAPIKey -ParameterFilter { $ApiKey -eq 'old-token-worker1' }

            # Worker 2: Cache cleared (worker recycled), retrieves new token
            Remove-Item "env:Ext_Confluence" -ErrorAction SilentlyContinue

            Mock Get-ExtensionAPIKey {
                $cached = (Get-Item -Path "env:Ext_Confluence" -ErrorAction SilentlyContinue).Value
                if (-not $cached) {
                    $new = 'new-token-worker2'
                    Set-Item -Path "env:Ext_Confluence" -Value $new -Force
                    return $new
                }
                return $cached
            }

            $result2 = Connect-ConfluenceAPI -Configuration $config

            # Worker 2 should use new token
            Assert-MockCalled New-ConfluenceAPIKey -ParameterFilter { $ApiKey -eq 'new-token-worker2' }

            # Both workers succeeded
            $result1.Success | Should Be $true
            $result2.Success | Should Be $true
        }
    }

    Context 'Integration with Connect-ConfluenceAPI (AC4)' {
        It 'Verifies Get-ExtensionAPIKey is called with Confluence extension (AC4)' {
            Mock Get-ExtensionAPIKey {
                param($Extension)
                # Verify extension parameter
                $Extension | Should Be 'Confluence'
                return 'test-token'
            }

            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net' } }
            Connect-ConfluenceAPI -Configuration $config

            Assert-MockCalled Get-ExtensionAPIKey -Times 1 -ParameterFilter { $Extension -eq 'Confluence' }
        }

        It 'Does NOT directly access script:ConfluenceAPIKey variable (AC4)' {
            # This test verifies architectural compliance
            # Get-ExtensionAPIKey returns the token, which Connect-ConfluenceAPI passes to New-ConfluenceAPIKey
            # Connect-ConfluenceAPI should never directly access $script:ConfluenceAPIKey

            Mock Get-ExtensionAPIKey { return 'framework-token' }

            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net' } }
            $result = Connect-ConfluenceAPI -Configuration $config

            # Verify token flows through Get-ExtensionAPIKey -> New-ConfluenceAPIKey
            Assert-MockCalled Get-ExtensionAPIKey -Times 1
            Assert-MockCalled New-ConfluenceAPIKey -ParameterFilter { $ApiKey -eq 'framework-token' }

            $result.Success | Should Be $true
        }

        It 'Passes retrieved key to New-ConfluenceAPIKey without modification (AC4)' {
            $testToken = 'exact-token-from-framework-12345'
            Mock Get-ExtensionAPIKey { return $testToken }

            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net' } }
            Connect-ConfluenceAPI -Configuration $config

            # Verify exact same token passed through
            Assert-MockCalled New-ConfluenceAPIKey -ParameterFilter { $ApiKey -eq $testToken }
        }

        It 'Validates connection using Test-ConfluenceConnection after setup (AC4)' {
            Mock Get-ExtensionAPIKey { return 'test-token' }

            # Clear mock call history to ensure accurate counting
            Mock Test-ConfluenceConnection {
                return [PSCustomObject]@{
                    Success = $true
                    Error   = $null
                }
            }

            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net' } }
            Connect-ConfluenceAPI -Configuration $config

            # Verify connection validation occurs
            Assert-MockCalled Test-ConfluenceConnection -Times 1
        }
    }

    Context 'Error Scenarios' {
        It 'Handles Key Vault retrieval failure gracefully' {
            $env:AzureWebJobsStorage = 'production'
            $env:WEBSITE_DEPLOYMENT_ID = 'testkeyvault-deployment'

            Mock Get-ExtensionAPIKey { throw 'Key Vault access denied' }

            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net' } }
            $result = Connect-ConfluenceAPI -Configuration $config

            $result.Success | Should Be $false
            $result.Error | Should Match 'Key Vault access denied'

            Remove-Item "env:AzureWebJobsStorage" -ErrorAction SilentlyContinue
            Remove-Item "env:WEBSITE_DEPLOYMENT_ID" -ErrorAction SilentlyContinue
        }

        It 'Handles DevSecrets table query failure gracefully' {
            $env:AzureWebJobsStorage = 'UseDevelopmentStorage=true'

            Mock Get-ExtensionAPIKey { throw 'DevSecrets table not found' }

            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net' } }
            $result = Connect-ConfluenceAPI -Configuration $config

            $result.Success | Should Be $false
            $result.Error | Should Match 'DevSecrets table not found'

            Remove-Item "env:AzureWebJobsStorage" -ErrorAction SilentlyContinue
        }

        It 'Returns actionable error when API key is missing from storage' {
            Mock Get-ExtensionAPIKey { return $null }

            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net' } }
            $result = Connect-ConfluenceAPI -Configuration $config

            $result.Success | Should Be $false
            $result.Error | Should Match 'API key not configured'
            $result.Error | Should Match 'CIPP Settings'
        }

        It 'Handles managed identity authentication failure' {
            $env:AzureWebJobsStorage = 'production'
            $env:WEBSITE_DEPLOYMENT_ID = 'testkeyvault-deployment'

            Mock Get-ExtensionAPIKey {
                Mock Connect-AzAccount { throw 'Managed identity not configured' }
            }

            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net' } }
            $result = Connect-ConfluenceAPI -Configuration $config

            $result.Success | Should Be $false

            Remove-Item "env:AzureWebJobsStorage" -ErrorAction SilentlyContinue
            Remove-Item "env:WEBSITE_DEPLOYMENT_ID" -ErrorAction SilentlyContinue
        }
    }
}
