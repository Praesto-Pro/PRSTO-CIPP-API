$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'

# Get path to function file - Tests/Confluence -> parent is Tests -> parent is CippExtensions
$moduleRoot = Split-Path (Split-Path $here -Parent) -Parent
$functionPath = Join-Path $moduleRoot (Join-Path 'Public' (Join-Path 'Confluence' $sut))

# Define stub functions for dependencies (required for Pester 3.4 mocking)
function Get-ExtensionCacheData { param($TenantFilter) }
function Connect-ConfluenceAPI { param($Configuration) }
function Get-ConfluenceMapping { }
function Sync-ConfluenceUserInventory { param($SpaceKey, $Users, $Licenses) }
function Sync-ConfluenceEndpointInventory { param($SpaceKey, $Endpoints) }
function Sync-ConfluenceLicenseReport { param($SpaceKey, $Licenses, $Users) }
function Sync-ConfluenceMFAReport { param($SpaceKey, $Users) }
function Sync-ConfluenceTeamsInventory { param($SpaceKey, $Teams) }
function Sync-ConfluenceSharePointInventory { param($SpaceKey, $Sites) }

Describe 'Invoke-ConfluenceExtensionSync' {
    BeforeAll {
        # Dot-source the function for testing
        if (Test-Path $functionPath) {
            . $functionPath
        }
    }

    BeforeEach {
        # Mock CIPP framework functions
        Mock Get-ExtensionCacheData {
            return [PSCustomObject]@{
                Users = @(
                    [PSCustomObject]@{
                        id                = 'user-1'
                        displayName       = 'Test User 1'
                        userPrincipalName = 'test1@contoso.com'
                        accountEnabled    = $true
                        assignedLicenses  = @(@{ skuId = 'sku-1' })
                    }
                    [PSCustomObject]@{
                        id                = 'user-2'
                        displayName       = 'Test User 2'
                        userPrincipalName = 'test2@contoso.com'
                        accountEnabled    = $true
                        assignedLicenses  = @(@{ skuId = 'sku-1' })
                    }
                )
                Devices = @(
                    [PSCustomObject]@{
                        id              = 'device-1'
                        deviceName      = 'DESKTOP-001'
                        complianceState = 'compliant'
                        operatingSystem = 'Windows'
                    }
                )
                Licenses = @(
                    [PSCustomObject]@{
                        skuId         = 'sku-1'
                        skuPartNumber = 'O365_BUSINESS'
                        consumedUnits = 5
                        prepaidUnits  = @{ enabled = 10 }
                    }
                )
                Groups = @()
                OneDriveUsage = @()
            }
        }

        Mock Connect-ConfluenceAPI {
            return [PSCustomObject]@{
                Success = $true
                Error   = $null
            }
        }

        Mock Get-ConfluenceMapping {
            return @(
                [PSCustomObject]@{
                    RowKey    = 'contoso.onmicrosoft.com'
                    TenantId  = 'contoso.onmicrosoft.com'
                    SpaceKey  = 'CONTOSO'
                    SpaceName = 'Contoso Corp'
                }
            )
        }

        # Mock ConfluenceAPI module functions
        Mock Sync-ConfluenceUserInventory { }
        Mock Sync-ConfluenceEndpointInventory { }
        Mock Sync-ConfluenceLicenseReport { }
        Mock Sync-ConfluenceMFAReport { }
        Mock Sync-ConfluenceTeamsInventory { }
        Mock Sync-ConfluenceSharePointInventory { }
    }

    Context 'Result Object Structure' {
        It 'Returns result object with Name property' {
            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net'; SyncUsers = $true } }
            $result = Invoke-ConfluenceExtensionSync -Configuration $config -TenantFilter 'contoso.onmicrosoft.com'

            ($result.PSObject.Properties.Name -contains 'Name') | Should Be $true
        }

        It 'Returns result object with Users property' {
            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net'; SyncUsers = $true } }
            $result = Invoke-ConfluenceExtensionSync -Configuration $config -TenantFilter 'contoso.onmicrosoft.com'

            ($result.PSObject.Properties.Name -contains 'Users') | Should Be $true
        }

        It 'Returns result object with Devices property' {
            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net'; SyncDevices = $true } }
            $result = Invoke-ConfluenceExtensionSync -Configuration $config -TenantFilter 'contoso.onmicrosoft.com'

            ($result.PSObject.Properties.Name -contains 'Devices') | Should Be $true
        }

        It 'Returns result object with Errors property' {
            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net' } }
            $result = Invoke-ConfluenceExtensionSync -Configuration $config -TenantFilter 'contoso.onmicrosoft.com'

            ($result.PSObject.Properties.Name -contains 'Errors') | Should Be $true
        }

        It 'Returns result object with Logs property' {
            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net' } }
            $result = Invoke-ConfluenceExtensionSync -Configuration $config -TenantFilter 'contoso.onmicrosoft.com'

            ($result.PSObject.Properties.Name -contains 'Logs') | Should Be $true
        }

        It 'Errors property is a Generic List' {
            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net' } }
            $result = Invoke-ConfluenceExtensionSync -Configuration $config -TenantFilter 'contoso.onmicrosoft.com'

            $result.Errors.GetType().Name | Should Be 'List`1'
        }

        It 'Logs property is a Generic List' {
            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net' } }
            $result = Invoke-ConfluenceExtensionSync -Configuration $config -TenantFilter 'contoso.onmicrosoft.com'

            $result.Logs.GetType().Name | Should Be 'List`1'
        }
    }

    Context 'Cache Data Access' {
        It 'Reads data from cache using Get-ExtensionCacheData' {
            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net' } }
            $result = Invoke-ConfluenceExtensionSync -Configuration $config -TenantFilter 'contoso.onmicrosoft.com'

            Assert-MockCalled Get-ExtensionCacheData -Times 1 -Exactly
        }

        It 'Passes correct TenantFilter to Get-ExtensionCacheData' {
            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net' } }
            $result = Invoke-ConfluenceExtensionSync -Configuration $config -TenantFilter 'contoso.onmicrosoft.com'

            Assert-MockCalled Get-ExtensionCacheData -Times 1 -ParameterFilter { $TenantFilter -eq 'contoso.onmicrosoft.com' }
        }
    }

    Context 'Tenant Mapping Resolution' {
        It 'Resolves tenant mapping using Get-ConfluenceMapping' {
            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net' } }
            $result = Invoke-ConfluenceExtensionSync -Configuration $config -TenantFilter 'contoso.onmicrosoft.com'

            Assert-MockCalled Get-ConfluenceMapping -Times 1 -Exactly
        }

        It 'Returns error when no mapping found for tenant' {
            Mock Get-ConfluenceMapping { return @() }

            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net' } }
            $result = Invoke-ConfluenceExtensionSync -Configuration $config -TenantFilter 'unknown.onmicrosoft.com'

            ($result.Errors -join '') | Should Match 'No Confluence mapping'
        }

        It 'Returns user count of 0 when no mapping found' {
            Mock Get-ConfluenceMapping { return @() }

            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net' } }
            $result = Invoke-ConfluenceExtensionSync -Configuration $config -TenantFilter 'unknown.onmicrosoft.com'

            $result.Users | Should Be 0
        }
    }

    Context 'Connection Handling' {
        It 'Calls Connect-ConfluenceAPI with Configuration' {
            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net' } }
            $result = Invoke-ConfluenceExtensionSync -Configuration $config -TenantFilter 'contoso.onmicrosoft.com'

            Assert-MockCalled Connect-ConfluenceAPI -Times 1 -Exactly
        }

        It 'Returns error when connection fails' {
            Mock Connect-ConfluenceAPI {
                return [PSCustomObject]@{
                    Success = $false
                    Error   = 'Connection refused'
                }
            }

            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net' } }
            $result = Invoke-ConfluenceExtensionSync -Configuration $config -TenantFilter 'contoso.onmicrosoft.com'

            ($result.Errors -join '') | Should Match 'connection failed'
        }

        It 'Does not call sync functions when connection fails' {
            Mock Connect-ConfluenceAPI {
                return [PSCustomObject]@{
                    Success = $false
                    Error   = 'Connection refused'
                }
            }

            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net' } }
            $result = Invoke-ConfluenceExtensionSync -Configuration $config -TenantFilter 'contoso.onmicrosoft.com'

            Assert-MockCalled Sync-ConfluenceUserInventory -Times 0
            Assert-MockCalled Sync-ConfluenceEndpointInventory -Times 0
        }
    }

    Context 'User Sync' {
        It 'Calls Sync-ConfluenceUserInventory when SyncUsers is enabled' {
            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net'; SyncUsers = $true } }
            $result = Invoke-ConfluenceExtensionSync -Configuration $config -TenantFilter 'contoso.onmicrosoft.com'

            Assert-MockCalled Sync-ConfluenceUserInventory -Times 1 -Exactly
        }

        It 'Does not call Sync-ConfluenceUserInventory when SyncUsers is false' {
            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net'; SyncUsers = $false } }
            $result = Invoke-ConfluenceExtensionSync -Configuration $config -TenantFilter 'contoso.onmicrosoft.com'

            Assert-MockCalled Sync-ConfluenceUserInventory -Times 0
        }

        It 'Returns correct user count after sync' {
            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net'; SyncUsers = $true } }
            $result = Invoke-ConfluenceExtensionSync -Configuration $config -TenantFilter 'contoso.onmicrosoft.com'

            $result.Users | Should Be 2
        }
    }

    Context 'Device Sync' {
        It 'Calls Sync-ConfluenceEndpointInventory when SyncDevices is enabled' {
            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net'; SyncDevices = $true } }
            $result = Invoke-ConfluenceExtensionSync -Configuration $config -TenantFilter 'contoso.onmicrosoft.com'

            Assert-MockCalled Sync-ConfluenceEndpointInventory -Times 1 -Exactly
        }

        It 'Does not call Sync-ConfluenceEndpointInventory when SyncDevices is false' {
            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net'; SyncDevices = $false } }
            $result = Invoke-ConfluenceExtensionSync -Configuration $config -TenantFilter 'contoso.onmicrosoft.com'

            Assert-MockCalled Sync-ConfluenceEndpointInventory -Times 0
        }

        It 'Returns correct device count after sync' {
            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net'; SyncDevices = $true } }
            $result = Invoke-ConfluenceExtensionSync -Configuration $config -TenantFilter 'contoso.onmicrosoft.com'

            $result.Devices | Should Be 1
        }
    }

    Context 'Error Isolation' {
        It 'Continues with device sync when user sync fails' {
            Mock Sync-ConfluenceUserInventory { throw 'User sync error' }

            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net'; SyncUsers = $true; SyncDevices = $true } }
            $result = Invoke-ConfluenceExtensionSync -Configuration $config -TenantFilter 'contoso.onmicrosoft.com'

            Assert-MockCalled Sync-ConfluenceEndpointInventory -Times 1 -Exactly
        }

        It 'Captures error when user sync fails' {
            Mock Sync-ConfluenceUserInventory { throw 'User sync error' }

            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net'; SyncUsers = $true } }
            $result = Invoke-ConfluenceExtensionSync -Configuration $config -TenantFilter 'contoso.onmicrosoft.com'

            $result.Errors.Count | Should BeGreaterThan 0
            ($result.Errors -join '') | Should Match 'User sync failed'
        }

        It 'Continues with user sync when device sync fails' {
            Mock Sync-ConfluenceEndpointInventory { throw 'Device sync error' }

            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net'; SyncUsers = $true; SyncDevices = $true } }
            $result = Invoke-ConfluenceExtensionSync -Configuration $config -TenantFilter 'contoso.onmicrosoft.com'

            # User sync happens before device sync
            Assert-MockCalled Sync-ConfluenceUserInventory -Times 1 -Exactly
        }

        It 'Accumulates multiple errors from different sync operations' {
            Mock Sync-ConfluenceUserInventory { throw 'User sync error' }
            Mock Sync-ConfluenceEndpointInventory { throw 'Device sync error' }

            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net'; SyncUsers = $true; SyncDevices = $true } }
            $result = Invoke-ConfluenceExtensionSync -Configuration $config -TenantFilter 'contoso.onmicrosoft.com'

            $result.Errors.Count | Should Be 2
        }
    }

    Context 'License Sync' {
        It 'Calls Sync-ConfluenceLicenseReport when SyncLicenses is enabled' {
            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net'; SyncLicenses = $true } }
            $result = Invoke-ConfluenceExtensionSync -Configuration $config -TenantFilter 'contoso.onmicrosoft.com'

            Assert-MockCalled Sync-ConfluenceLicenseReport -Times 1 -Exactly
        }

        It 'Does not call Sync-ConfluenceLicenseReport when SyncLicenses is false' {
            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net'; SyncLicenses = $false } }
            $result = Invoke-ConfluenceExtensionSync -Configuration $config -TenantFilter 'contoso.onmicrosoft.com'

            Assert-MockCalled Sync-ConfluenceLicenseReport -Times 0
        }
    }

    Context 'MFA Sync' {
        It 'Calls Sync-ConfluenceMFAReport when SyncMFA is enabled' {
            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net'; SyncMFA = $true } }
            $result = Invoke-ConfluenceExtensionSync -Configuration $config -TenantFilter 'contoso.onmicrosoft.com'

            Assert-MockCalled Sync-ConfluenceMFAReport -Times 1 -Exactly
        }

        It 'Does not call Sync-ConfluenceMFAReport when SyncMFA is false' {
            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net'; SyncMFA = $false } }
            $result = Invoke-ConfluenceExtensionSync -Configuration $config -TenantFilter 'contoso.onmicrosoft.com'

            Assert-MockCalled Sync-ConfluenceMFAReport -Times 0
        }
    }

    Context 'Verbose Logging' {
        It 'Adds log entries to Logs list' {
            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net'; SyncUsers = $true } }
            $result = Invoke-ConfluenceExtensionSync -Configuration $config -TenantFilter 'contoso.onmicrosoft.com'

            $result.Logs.Count | Should BeGreaterThan 0
        }

        It 'Logs sync completion message' {
            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net'; SyncUsers = $true } }
            $result = Invoke-ConfluenceExtensionSync -Configuration $config -TenantFilter 'contoso.onmicrosoft.com'

            ($result.Logs -join '') | Should Match 'Sync completed'
        }

        It 'Logs user sync result with count' {
            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net'; SyncUsers = $true } }
            $result = Invoke-ConfluenceExtensionSync -Configuration $config -TenantFilter 'contoso.onmicrosoft.com'

            ($result.Logs -join '') | Should Match 'User sync complete.*2 users'
        }
    }

    Context 'Configuration Handling' {
        It 'Handles nested Confluence configuration' {
            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net'; SyncUsers = $true } }
            $result = Invoke-ConfluenceExtensionSync -Configuration $config -TenantFilter 'contoso.onmicrosoft.com'

            $result.Users | Should Be 2
        }

        It 'Handles flat configuration structure' {
            $config = @{ BaseURL = 'https://test.atlassian.net'; SyncUsers = $true }

            # Re-mock Connect-ConfluenceAPI to handle flat config
            Mock Connect-ConfluenceAPI {
                return [PSCustomObject]@{
                    Success = $true
                    Error   = $null
                }
            }

            $result = Invoke-ConfluenceExtensionSync -Configuration $config -TenantFilter 'contoso.onmicrosoft.com'

            # Should still work
            $result | Should Not Be $null
        }

        It 'Defaults SyncUsers to true when not specified' {
            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net' } }
            $result = Invoke-ConfluenceExtensionSync -Configuration $config -TenantFilter 'contoso.onmicrosoft.com'

            # SyncUsers defaults to true (not explicitly false)
            Assert-MockCalled Sync-ConfluenceUserInventory -Times 1 -Exactly
        }
    }

    Context 'Empty Cache Handling' {
        It 'Handles empty users array gracefully' {
            Mock Get-ExtensionCacheData {
                return [PSCustomObject]@{
                    Users    = @()
                    Devices  = @()
                    Licenses = @()
                    Groups   = @()
                }
            }

            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net'; SyncUsers = $true } }
            $result = Invoke-ConfluenceExtensionSync -Configuration $config -TenantFilter 'contoso.onmicrosoft.com'

            $result.Users | Should Be 0
            $result.Errors.Count | Should Be 0
        }

        It 'Logs skip message when no users in cache' {
            Mock Get-ExtensionCacheData {
                return [PSCustomObject]@{
                    Users    = @()
                    Devices  = @()
                    Licenses = @()
                    Groups   = @()
                }
            }

            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net'; SyncUsers = $true } }
            $result = Invoke-ConfluenceExtensionSync -Configuration $config -TenantFilter 'contoso.onmicrosoft.com'

            ($result.Logs -join '') | Should Match 'skipped.*no users'
        }

        It 'Returns error when cache is null' {
            Mock Get-ExtensionCacheData { return $null }

            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net' } }
            $result = Invoke-ConfluenceExtensionSync -Configuration $config -TenantFilter 'contoso.onmicrosoft.com'

            ($result.Errors -join '') | Should Match 'No cached data'
        }
    }

    Context 'SpaceKey Validation' {
        It 'Returns error when mapping has empty SpaceKey' {
            Mock Get-ConfluenceMapping {
                return @(
                    [PSCustomObject]@{
                        RowKey    = 'contoso.onmicrosoft.com'
                        TenantId  = 'contoso.onmicrosoft.com'
                        SpaceKey  = ''
                        SpaceName = 'Contoso Corp'
                    }
                )
            }

            $config = @{ Confluence = @{ BaseURL = 'https://test.atlassian.net' } }
            $result = Invoke-ConfluenceExtensionSync -Configuration $config -TenantFilter 'contoso.onmicrosoft.com'

            ($result.Errors -join '') | Should Match 'SpaceKey is empty'
        }
    }
}
