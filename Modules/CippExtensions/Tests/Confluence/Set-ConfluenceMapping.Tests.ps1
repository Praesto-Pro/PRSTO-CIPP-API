$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'

# Get path to function file - Tests/Confluence -> parent is Tests -> parent is CippExtensions
$moduleRoot = Split-Path (Split-Path $here -Parent) -Parent
$functionPath = Join-Path $moduleRoot (Join-Path 'Public' (Join-Path 'Confluence' $sut))

# Define stub functions for dependencies (required for Pester 3.4 mocking)
function Get-CIPPTable { param($TableName) }
function Get-CIPPAzDataTableEntity { param($Filter) }
function Remove-AzDataTableEntity { param($Force, $Entity) }
function Add-CIPPAzDataTableEntity { param($Entity, $Force) }
function Write-LogMessage { param($API, $headers, $message, $Sev) }

Describe 'Set-ConfluenceMapping' {
    BeforeAll {
        # Dot-source the function for testing
        if (Test-Path $functionPath) {
            . $functionPath
        }
    }

    BeforeEach {
        # Mock CIPP framework functions
        Mock Get-CIPPTable {
            return @{ TableName = 'CippMapping' }
        }

        Mock Get-CIPPAzDataTableEntity {
            return @()
        }

        Mock Remove-AzDataTableEntity { }

        Mock Add-CIPPAzDataTableEntity { }

        Mock Write-LogMessage { }
    }

    Context 'Successful Mapping' {
        It 'Returns success result' {
            $request = @{
                Headers = @{}
                Body    = @(
                    @{ TenantId = 'contoso.onmicrosoft.com'; IntegrationId = 'CONTOSO'; IntegrationName = 'Contoso Corp' }
                )
            }

            $result = Set-ConfluenceMapping -Request $request -Confirm:$false

            $result.Results | Should Match 'Successfully'
        }

        It 'Calls Add-CIPPAzDataTableEntity for each mapping' {
            $request = @{
                Headers = @{}
                Body    = @(
                    @{ TenantId = 'contoso.onmicrosoft.com'; IntegrationId = 'CONTOSO'; IntegrationName = 'Contoso Corp' }
                    @{ TenantId = 'fabrikam.onmicrosoft.com'; IntegrationId = 'FABRIKAM'; IntegrationName = 'Fabrikam Inc' }
                )
            }

            $result = Set-ConfluenceMapping -Request $request -Confirm:$false

            Assert-MockCalled Add-CIPPAzDataTableEntity -Times 2 -Exactly
        }

        It 'Logs each mapping operation' {
            $request = @{
                Headers = @{}
                Body    = @(
                    @{ TenantId = 'contoso.onmicrosoft.com'; IntegrationId = 'CONTOSO'; IntegrationName = 'Contoso Corp' }
                )
            }

            $result = Set-ConfluenceMapping -Request $request -Confirm:$false

            Assert-MockCalled Write-LogMessage -Times 1 -Exactly
        }

        It 'Uses ConfluenceMapping as PartitionKey' {
            $request = @{
                Headers = @{}
                Body    = @(
                    @{ TenantId = 'test.onmicrosoft.com'; IntegrationId = 'TEST'; IntegrationName = 'Test' }
                )
            }

            $result = Set-ConfluenceMapping -Request $request -Confirm:$false

            Assert-MockCalled Add-CIPPAzDataTableEntity -Times 1 -ParameterFilter {
                $Entity.PartitionKey -eq 'ConfluenceMapping'
            }
        }

        It 'Uses TenantId as RowKey' {
            $request = @{
                Headers = @{}
                Body    = @(
                    @{ TenantId = 'mycompany.onmicrosoft.com'; IntegrationId = 'MYCO'; IntegrationName = 'My Company' }
                )
            }

            $result = Set-ConfluenceMapping -Request $request -Confirm:$false

            Assert-MockCalled Add-CIPPAzDataTableEntity -Times 1 -ParameterFilter {
                $Entity.RowKey -eq 'mycompany.onmicrosoft.com'
            }
        }

        It 'Stores SpaceKey as IntegrationId' {
            $request = @{
                Headers = @{}
                Body    = @(
                    @{ TenantId = 'test.com'; IntegrationId = 'TESTSPACE'; IntegrationName = 'Test Space' }
                )
            }

            $result = Set-ConfluenceMapping -Request $request -Confirm:$false

            Assert-MockCalled Add-CIPPAzDataTableEntity -Times 1 -ParameterFilter {
                $Entity.IntegrationId -eq 'TESTSPACE'
            }
        }

        It 'Stores SpaceName as IntegrationName' {
            $request = @{
                Headers = @{}
                Body    = @(
                    @{ TenantId = 'test.com'; IntegrationId = 'TEST'; IntegrationName = 'Test Display Name' }
                )
            }

            $result = Set-ConfluenceMapping -Request $request -Confirm:$false

            Assert-MockCalled Add-CIPPAzDataTableEntity -Times 1 -ParameterFilter {
                $Entity.IntegrationName -eq 'Test Display Name'
            }
        }
    }

    Context 'Clear Existing Mappings' {
        It 'Clears existing mappings when ClearExisting is specified' {
            Mock Get-CIPPAzDataTableEntity {
                return @(
                    [PSCustomObject]@{ PartitionKey = 'ConfluenceMapping'; RowKey = 'old.com' }
                )
            }

            $request = @{
                Headers = @{}
                Body    = @(
                    @{ TenantId = 'new.com'; IntegrationId = 'NEW'; IntegrationName = 'New' }
                )
            }

            $result = Set-ConfluenceMapping -Request $request -ClearExisting -Confirm:$false

            Assert-MockCalled Remove-AzDataTableEntity -Times 1 -Exactly
        }

        It 'Does not clear mappings when ClearExisting is not specified' {
            Mock Get-CIPPAzDataTableEntity {
                return @(
                    [PSCustomObject]@{ PartitionKey = 'ConfluenceMapping'; RowKey = 'old.com' }
                )
            }

            $request = @{
                Headers = @{}
                Body    = @(
                    @{ TenantId = 'new.com'; IntegrationId = 'NEW'; IntegrationName = 'New' }
                )
            }

            $result = Set-ConfluenceMapping -Request $request -Confirm:$false

            Assert-MockCalled Remove-AzDataTableEntity -Times 0
        }

        It 'Clears all existing ConfluenceMapping entries' {
            Mock Get-CIPPAzDataTableEntity {
                return @(
                    [PSCustomObject]@{ PartitionKey = 'ConfluenceMapping'; RowKey = 'old1.com' }
                    [PSCustomObject]@{ PartitionKey = 'ConfluenceMapping'; RowKey = 'old2.com' }
                    [PSCustomObject]@{ PartitionKey = 'ConfluenceMapping'; RowKey = 'old3.com' }
                )
            }

            $request = @{
                Headers = @{}
                Body    = @(
                    @{ TenantId = 'new.com'; IntegrationId = 'NEW'; IntegrationName = 'New' }
                )
            }

            $result = Set-ConfluenceMapping -Request $request -ClearExisting -Confirm:$false

            Assert-MockCalled Remove-AzDataTableEntity -Times 3 -Exactly
        }
    }

    Context 'Invalid Mappings' {
        It 'Skips mapping with missing TenantId' {
            $request = @{
                Headers = @{}
                Body    = @(
                    @{ IntegrationId = 'TEST'; IntegrationName = 'Test' }
                )
            }

            $result = Set-ConfluenceMapping -Request $request -Confirm:$false

            Assert-MockCalled Add-CIPPAzDataTableEntity -Times 0
        }

        It 'Skips mapping with missing IntegrationId (SpaceKey)' {
            $request = @{
                Headers = @{}
                Body    = @(
                    @{ TenantId = 'test.com'; IntegrationName = 'Test' }
                )
            }

            $result = Set-ConfluenceMapping -Request $request -Confirm:$false

            Assert-MockCalled Add-CIPPAzDataTableEntity -Times 0
        }

        It 'Skips mapping with empty TenantId' {
            $request = @{
                Headers = @{}
                Body    = @(
                    @{ TenantId = ''; IntegrationId = 'TEST'; IntegrationName = 'Test' }
                )
            }

            $result = Set-ConfluenceMapping -Request $request -Confirm:$false

            Assert-MockCalled Add-CIPPAzDataTableEntity -Times 0
        }

        It 'Processes valid mappings even when some are invalid' {
            $request = @{
                Headers = @{}
                Body    = @(
                    @{ TenantId = ''; IntegrationId = 'INVALID'; IntegrationName = 'Invalid' }
                    @{ TenantId = 'valid.com'; IntegrationId = 'VALID'; IntegrationName = 'Valid' }
                )
            }

            $result = Set-ConfluenceMapping -Request $request -Confirm:$false

            Assert-MockCalled Add-CIPPAzDataTableEntity -Times 1 -Exactly
        }
    }

    Context 'Multiple Mappings' {
        It 'Processes all mappings in request body' {
            $request = @{
                Headers = @{}
                Body    = @(
                    @{ TenantId = 'tenant1.com'; IntegrationId = 'SPACE1'; IntegrationName = 'Space 1' }
                    @{ TenantId = 'tenant2.com'; IntegrationId = 'SPACE2'; IntegrationName = 'Space 2' }
                    @{ TenantId = 'tenant3.com'; IntegrationId = 'SPACE3'; IntegrationName = 'Space 3' }
                )
            }

            $result = Set-ConfluenceMapping -Request $request -Confirm:$false

            Assert-MockCalled Add-CIPPAzDataTableEntity -Times 3 -Exactly
        }

        It 'Reports correct count in result' {
            $request = @{
                Headers = @{}
                Body    = @(
                    @{ TenantId = 'tenant1.com'; IntegrationId = 'SPACE1'; IntegrationName = 'Space 1' }
                    @{ TenantId = 'tenant2.com'; IntegrationId = 'SPACE2'; IntegrationName = 'Space 2' }
                )
            }

            $result = Set-ConfluenceMapping -Request $request -Confirm:$false

            $result.Results | Should Match '2 mapping'
        }
    }

    Context 'Table Reference' {
        It 'Gets CippMapping table when not provided' {
            $request = @{
                Headers = @{}
                Body    = @(
                    @{ TenantId = 'test.com'; IntegrationId = 'TEST'; IntegrationName = 'Test' }
                )
            }

            $result = Set-ConfluenceMapping -Request $request -Confirm:$false

            Assert-MockCalled Get-CIPPTable -Times 1 -ParameterFilter { $TableName -eq 'CippMapping' }
        }

        It 'Uses provided CIPPMapping table reference' {
            $customTable = @{ TableName = 'CustomTable' }

            $request = @{
                Headers = @{}
                Body    = @(
                    @{ TenantId = 'test.com'; IntegrationId = 'TEST'; IntegrationName = 'Test' }
                )
            }

            $result = Set-ConfluenceMapping -CIPPMapping $customTable -Request $request -Confirm:$false

            Assert-MockCalled Get-CIPPTable -Times 0
        }
    }

    Context 'Error Handling' {
        It 'Returns error message when Add-CIPPAzDataTableEntity fails' {
            Mock Add-CIPPAzDataTableEntity { throw 'Table storage error' }

            $request = @{
                Headers = @{}
                Body    = @(
                    @{ TenantId = 'test.com'; IntegrationId = 'TEST'; IntegrationName = 'Test' }
                )
            }

            $result = Set-ConfluenceMapping -Request $request -Confirm:$false

            $result.Results | Should Match 'Failed'
        }

        It 'Does not throw when operation fails' {
            Mock Add-CIPPAzDataTableEntity { throw 'Error' }

            $request = @{
                Headers = @{}
                Body    = @(
                    @{ TenantId = 'test.com'; IntegrationId = 'TEST'; IntegrationName = 'Test' }
                )
            }

            { Set-ConfluenceMapping -Request $request -Confirm:$false } | Should Not Throw
        }
    }

    Context 'Output Structure' {
        It 'Returns object with Results property' {
            $request = @{
                Headers = @{}
                Body    = @(
                    @{ TenantId = 'test.com'; IntegrationId = 'TEST'; IntegrationName = 'Test' }
                )
            }

            $result = Set-ConfluenceMapping -Request $request -Confirm:$false

            ($result.PSObject.Properties.Name -contains 'Results') | Should Be $true
        }

        It 'Results is a string' {
            $request = @{
                Headers = @{}
                Body    = @(
                    @{ TenantId = 'test.com'; IntegrationId = 'TEST'; IntegrationName = 'Test' }
                )
            }

            $result = Set-ConfluenceMapping -Request $request -Confirm:$false

            $result.Results | Should BeOfType [string]
        }
    }

    Context 'Empty Request Body' {
        It 'Returns success with 0 mappings when body is empty' {
            $request = @{
                Headers = @{}
                Body    = @()
            }

            $result = Set-ConfluenceMapping -Request $request -Confirm:$false

            $result.Results | Should Match '0 mapping'
        }

        It 'Does not call Add-CIPPAzDataTableEntity when body is empty' {
            $request = @{
                Headers = @{}
                Body    = @()
            }

            $result = Set-ConfluenceMapping -Request $request -Confirm:$false

            Assert-MockCalled Add-CIPPAzDataTableEntity -Times 0
        }
    }
}
