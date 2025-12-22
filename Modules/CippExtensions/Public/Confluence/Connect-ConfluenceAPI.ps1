function Connect-ConfluenceAPI {
    <#
    .SYNOPSIS
        Connects to Confluence API using CIPP extension framework credentials.
    .DESCRIPTION
        Initializes the ConfluenceAPI module connection using credentials stored
        in CIPP's extension framework (Key Vault for production, DevSecrets for development).

        This function:
        1. Retrieves API key via Get-ExtensionAPIKey
        2. Extracts BaseURL from Configuration
        3. Initializes ConfluenceAPI module (New-ConfluenceAPIKey, New-ConfluenceBaseURL)
        4. Validates connection via Test-ConfluenceConnection
        5. Returns connection status object

        Follows the Connect-HuduAPI pattern from CippExtensions.

        Credential Storage (Story 10.5):

        Production:
        - API key retrieved from Azure Key Vault using managed identity
        - Secret name: 'Confluence'
        - Cached in $env:Ext_Confluence for performance
        - Set up: az keyvault secret set --vault-name <vault> --name Confluence --value <token>

        Development:
        - API key retrieved from DevSecrets table
        - PartitionKey/RowKey: 'Confluence'
        - Triggered by $env:AzureWebJobsStorage = 'UseDevelopmentStorage=true'

        Token Rotation:
        - Update Key Vault secret (az keyvault secret set ...)
        - Environment cache clears automatically on Azure Function worker recycling
        - No manual intervention needed for gradual rollout
        - Clear cache manually if needed: Remove-Item "env:Ext_Confluence"
    .PARAMETER Configuration
        Extension configuration from Extensionsconfig table.
        Expected structure:
        - Configuration.Confluence.BaseURL: Confluence base URL
        - OR Configuration.BaseURL for flat structure
    .OUTPUTS
        [PSCustomObject] - Object with Success (bool) and optional Error (string) properties
    .EXAMPLE
        $result = Connect-ConfluenceAPI -Configuration $Config
        if ($result.Success) {
            # Connection successful, ConfluenceAPI module is ready
        }
    .EXAMPLE
        # Production setup - Set Key Vault secret
        az keyvault secret set --vault-name mykeyvault --name Confluence --value <your-api-token>

        # Grant Function App access
        az keyvault set-policy --name mykeyvault --object-id <function-identity-id> --secret-permissions get

        # Test connection
        $config = @{ Confluence = @{ BaseURL = 'https://yoursite.atlassian.net' } }
        $result = Connect-ConfluenceAPI -Configuration $config
    .EXAMPLE
        # Development setup - Add to DevSecrets table
        $Table = Get-CIPPTable -tablename 'DevSecrets'
        $Entity = @{
            PartitionKey = 'Confluence'
            RowKey       = 'Confluence'
            APIKey       = 'your-dev-api-token'
        }
        Add-CIPPAzDataTableEntity @Table -Entity $Entity -Force

        # Set development environment
        $env:AzureWebJobsStorage = 'UseDevelopmentStorage=true'

        # Test connection
        $config = @{ BaseURL = 'https://dev.atlassian.net' }
        $result = Connect-ConfluenceAPI -Configuration $config
    .EXAMPLE
        # Token rotation procedure
        # 1. Generate new token at https://id.atlassian.com/manage/api-tokens
        # 2. Update Key Vault
        az keyvault secret set --vault-name mykeyvault --name Confluence --value <new-token>
        # 3. Optional: Clear cache for immediate effect
        Remove-Item "env:Ext_Confluence" -ErrorAction SilentlyContinue
        # 4. Verify
        $result = Connect-ConfluenceAPI -Configuration $Config
    .NOTES
        Part of Story 10.1 - Extension Sync Orchestrator.
        Enhanced in Story 10.5 - API Key Framework Integration.

        This function is located in CippExtensions because it integrates with
        CIPP's credential management (Get-ExtensionAPIKey).

        Dependencies:
        - Get-ExtensionAPIKey (CIPP framework)
        - New-ConfluenceAPIKey (ConfluenceAPI module)
        - New-ConfluenceBaseURL (ConfluenceAPI module)
        - Test-ConfluenceConnection (ConfluenceAPI module)

        Security:
        - API tokens never logged or displayed in verbose output
        - Managed identity for production Key Vault access (no credentials)
        - Environment caching reduces Key Vault calls for performance
        - Token rotation supported without downtime
    .LINK
        Get-ExtensionAPIKey
    .LINK
        Test-ConfluenceConnection
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Configuration
    )

    Write-Verbose 'Connecting to Confluence API via extension framework'

    try {
        # Retrieve API key from CIPP extension framework
        # Get-ExtensionAPIKey handles both production (Key Vault) and development (DevSecrets)
        $APIKey = Get-ExtensionAPIKey -Extension 'Confluence'

        if (-not $APIKey) {
            Write-Verbose 'No API key returned from Get-ExtensionAPIKey'
            return [PSCustomObject]@{
                Success = $false
                Error   = 'Confluence API key not configured. Set via CIPP Settings > Extensions > Confluence.'
            }
        }

        # Extract BaseURL from configuration (handle nested and flat structures)
        $BaseURL = if ($Configuration.Confluence.BaseURL) {
            $Configuration.Confluence.BaseURL
        }
        elseif ($Configuration.BaseURL) {
            $Configuration.BaseURL
        }
        else {
            $null
        }

        if (-not $BaseURL) {
            Write-Verbose 'No BaseURL found in configuration'
            return [PSCustomObject]@{
                Success = $false
                Error   = 'Confluence BaseURL not configured. Set via CIPP Settings > Extensions > Confluence.'
            }
        }

        Write-Verbose "Initializing ConfluenceAPI module with BaseURL: $BaseURL"

        # Initialize ConfluenceAPI module credentials
        # These functions store credentials in script-scope variables
        New-ConfluenceAPIKey -ApiKey $APIKey
        New-ConfluenceBaseURL -BaseURL $BaseURL

        # Validate connection
        Write-Verbose 'Validating Confluence connection'
        $Connection = Test-ConfluenceConnection

        if ($Connection -and $Connection.Success) {
            Write-Verbose 'Confluence connection validated successfully'
            return [PSCustomObject]@{
                Success = $true
                Error   = $null
            }
        }
        else {
            $errorMsg = if ($Connection -and $Connection.Error) { $Connection.Error } else { 'Connection test failed' }
            Write-Verbose "Connection validation failed: $errorMsg"
            return [PSCustomObject]@{
                Success = $false
                Error   = "Confluence connection test failed: $errorMsg"
            }
        }
    }
    catch {
        Write-Verbose "Connect-ConfluenceAPI error: $_"
        return [PSCustomObject]@{
            Success = $false
            Error   = "Failed to connect to Confluence: $_"
        }
    }
}
