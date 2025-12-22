function Invoke-ConfluenceExtensionSync {
    <#
    .SYNOPSIS
        Main orchestrator for Confluence extension sync operations.
    .DESCRIPTION
        Reads M365 data from CIPP cache and syncs to Confluence pages.
        Called by Push-CippExtensionData when Extension = 'Confluence'.

        This function follows the Hudu extension pattern:
        1. Initialize result tracking with Generic Lists for O(1) append
        2. Connect to Confluence API via extension framework
        3. Resolve tenant-to-space mapping from CippMapping table
        4. Load cached M365 data via Get-ExtensionCacheData
        5. Sync each data type to Confluence pages with error isolation
        6. Return standardized result object

        Each data type sync is wrapped in try-catch to ensure one failure
        doesn't stop other syncs from completing.
    .PARAMETER Configuration
        Extension configuration from Extensionsconfig table.
        Expected structure includes Confluence.BaseURL, Confluence.SyncUsers, etc.
    .PARAMETER TenantFilter
        Tenant domain name (defaultDomainName) to sync.
    .OUTPUTS
        [PSCustomObject] - Result object with Name, Users, Devices, Errors, Logs properties
    .EXAMPLE
        Invoke-ConfluenceExtensionSync -Configuration $Config -TenantFilter 'contoso.onmicrosoft.com'

        Syncs all enabled data types for the specified tenant to Confluence.
    .NOTES
        Part of Story 10.1 - Extension Sync Orchestrator.

        This function is located in CippExtensions (NOT ConfluenceAPI) because
        it integrates with CIPP's extension framework. It calls existing
        Sync-Confluence* functions from the ConfluenceAPI module.

        Dependencies:
        - Connect-ConfluenceAPI (Story 10.1)
        - Get-ConfluenceMapping (Story 10.1)
        - Get-ExtensionCacheData (CIPP framework)
        - Sync-ConfluenceUserInventory (Epic 4)
        - Sync-ConfluenceEndpointInventory (Epic 5)
        - Sync-ConfluenceLicenseReport (Epic 5)
        - Sync-ConfluenceMFAReport (Epic 6)
        - Sync-ConfluenceTeamsInventory (Epic 6)
        - Sync-ConfluenceSharePointInventory (Epic 6)
    .LINK
        Connect-ConfluenceAPI
    .LINK
        Get-ConfluenceMapping
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Configuration,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$TenantFilter
    )

    # Phase 1: Initialize result tracking with Generic Lists for O(1) append
    # Note: Name will be updated to display name once cache is loaded (matches Hudu pattern)
    Write-Verbose "Initializing Confluence extension sync for tenant '$TenantFilter'"
    $CompanyResult = [PSCustomObject]@{
        Name    = $TenantFilter
        Users   = 0
        Devices = 0
        Errors  = [System.Collections.Generic.List[string]]@()
        Logs    = [System.Collections.Generic.List[string]]@()
    }

    $CompanyResult.Logs.Add("Starting Confluence Extension Sync for $TenantFilter")

    # Get Confluence-specific configuration (handle nested structure)
    $confluenceConfig = if ($Configuration.Confluence) { $Configuration.Confluence } else { $Configuration }

    # Check if extension is enabled (AC4: Enabled=$false causes immediate return)
    if ($confluenceConfig.Enabled -eq $false) {
        Write-Verbose 'Confluence extension is disabled, skipping sync'
        $CompanyResult.Logs.Add('Sync skipped: Confluence extension is disabled')
        return $CompanyResult
    }

    try {
        # Phase 2: Connect to Confluence API
        Write-Verbose 'Connecting to Confluence API'
        $connectionResult = Connect-ConfluenceAPI -Configuration $Configuration
        if (-not $connectionResult -or -not $connectionResult.Success) {
            $errorMsg = if ($connectionResult -and $connectionResult.Error) { $connectionResult.Error } else { 'Unknown connection error' }
            $CompanyResult.Errors.Add("Confluence connection failed: $errorMsg")
            Write-Verbose "Connection failed: $errorMsg"
            return $CompanyResult
        }
        $CompanyResult.Logs.Add('Connected to Confluence API')

        # Phase 3: Resolve tenant mapping
        Write-Verbose "Resolving tenant mapping for '$TenantFilter'"
        $allMappings = Get-ConfluenceMapping
        $TenantMapping = $allMappings | Where-Object { $_.RowKey -eq $TenantFilter -or $_.TenantId -eq $TenantFilter }

        if (-not $TenantMapping) {
            $CompanyResult.Errors.Add("No Confluence mapping found for tenant '$TenantFilter'. Configure mappings in CIPP Settings > Extensions > Confluence.")
            Write-Verbose "No mapping found for tenant '$TenantFilter'"
            return $CompanyResult
        }

        $SpaceKey = $TenantMapping.SpaceKey
        if (-not $SpaceKey) {
            $CompanyResult.Errors.Add("Tenant mapping exists but SpaceKey is empty for '$TenantFilter'")
            return $CompanyResult
        }

        Write-Verbose "Resolved tenant mapping: SpaceKey = '$SpaceKey'"
        $CompanyResult.Logs.Add("Tenant mapped to Confluence space '$SpaceKey'")

        # Phase 4: Load cached M365 data
        Write-Verbose 'Loading cached M365 data from CacheExtensionSync'
        $ExtensionCache = Get-ExtensionCacheData -TenantFilter $TenantFilter

        if ($null -eq $ExtensionCache) {
            $CompanyResult.Errors.Add("No cached data found for tenant '$TenantFilter'. Run Sync-CippExtensionData first.")
            return $CompanyResult
        }

        # Update Name to display name from cache (matches Hudu pattern using $Tenant.displayName)
        if ($ExtensionCache.Tenant -and $ExtensionCache.Tenant.displayName) {
            $CompanyResult.Name = $ExtensionCache.Tenant.displayName
        }
        elseif ($ExtensionCache.Organization -and $ExtensionCache.Organization.displayName) {
            $CompanyResult.Name = $ExtensionCache.Organization.displayName
        }

        $CompanyResult.Logs.Add('Loaded cached M365 data')

        # Phase 5: Sync each enabled data type with error isolation
        # 5a: User Inventory
        if ($confluenceConfig.SyncUsers -ne $false) {
            try {
                $users = @($ExtensionCache.Users)
                $userCount = $users.Count
                Write-Verbose "Syncing user inventory ($userCount users)"

                if ($userCount -gt 0) {
                    $syncParams = @{
                        SpaceKey = $SpaceKey
                        Users    = $users
                    }

                    # Add optional parameters if available in cache
                    if ($ExtensionCache.Licenses) {
                        $syncParams['Licenses'] = @($ExtensionCache.Licenses)
                    }

                    $null = Sync-ConfluenceUserInventory @syncParams
                    $CompanyResult.Users = $userCount
                    $CompanyResult.Logs.Add("User sync complete: $userCount users")
                }
                else {
                    $CompanyResult.Logs.Add('User sync skipped: no users in cache')
                }
            }
            catch {
                $CompanyResult.Errors.Add("User sync failed: $_")
                Write-Verbose "User sync error: $_"
            }
        }
        else {
            Write-Verbose 'User sync disabled in configuration'
            $CompanyResult.Logs.Add('User sync skipped: disabled in configuration')
        }

        # 5b: Endpoint/Device Inventory
        if ($confluenceConfig.SyncDevices -ne $false) {
            try {
                $devices = @($ExtensionCache.Devices)
                $deviceCount = $devices.Count
                Write-Verbose "Syncing endpoint inventory ($deviceCount devices)"

                if ($deviceCount -gt 0) {
                    $null = Sync-ConfluenceEndpointInventory -SpaceKey $SpaceKey -Endpoints $devices
                    $CompanyResult.Devices = $deviceCount
                    $CompanyResult.Logs.Add("Device sync complete: $deviceCount devices")
                }
                else {
                    $CompanyResult.Logs.Add('Device sync skipped: no devices in cache')
                }
            }
            catch {
                $CompanyResult.Errors.Add("Device sync failed: $_")
                Write-Verbose "Device sync error: $_"
            }
        }
        else {
            Write-Verbose 'Device sync disabled in configuration'
            $CompanyResult.Logs.Add('Device sync skipped: disabled in configuration')
        }

        # 5c: License Report
        if ($confluenceConfig.SyncLicenses -ne $false) {
            try {
                $licenses = @($ExtensionCache.Licenses)
                $licenseCount = $licenses.Count
                Write-Verbose "Syncing license report ($licenseCount licenses)"

                if ($licenseCount -gt 0) {
                    $syncParams = @{
                        SpaceKey = $SpaceKey
                        Licenses = $licenses
                    }

                    # Add users for license assignment display if available
                    if ($ExtensionCache.Users) {
                        $syncParams['Users'] = @($ExtensionCache.Users)
                    }

                    $null = Sync-ConfluenceLicenseReport @syncParams
                    $CompanyResult.Logs.Add("License sync complete: $licenseCount licenses")
                }
                else {
                    $CompanyResult.Logs.Add('License sync skipped: no licenses in cache')
                }
            }
            catch {
                $CompanyResult.Errors.Add("License sync failed: $_")
                Write-Verbose "License sync error: $_"
            }
        }
        else {
            Write-Verbose 'License sync disabled in configuration'
            $CompanyResult.Logs.Add('License sync skipped: disabled in configuration')
        }

        # 5d: MFA Report
        if ($confluenceConfig.SyncMFA -ne $false) {
            try {
                # MFA data may be part of Users or separate
                $users = @($ExtensionCache.Users)
                Write-Verbose "Syncing MFA report ($($users.Count) users)"

                if ($users.Count -gt 0) {
                    $null = Sync-ConfluenceMFAReport -SpaceKey $SpaceKey -Users $users
                    $CompanyResult.Logs.Add("MFA sync complete: $($users.Count) users")
                }
                else {
                    $CompanyResult.Logs.Add('MFA sync skipped: no user data in cache')
                }
            }
            catch {
                $CompanyResult.Errors.Add("MFA sync failed: $_")
                Write-Verbose "MFA sync error: $_"
            }
        }
        else {
            Write-Verbose 'MFA sync disabled in configuration'
            $CompanyResult.Logs.Add('MFA sync skipped: disabled in configuration')
        }

        # 5e: Teams Inventory
        if ($confluenceConfig.SyncTeams -ne $false) {
            try {
                $groups = @($ExtensionCache.Groups)
                # Filter to Teams-enabled groups
                $teams = $groups | Where-Object { $_.groupTypes -contains 'Unified' -and $_.resourceProvisioningOptions -contains 'Team' }
                $teamsArray = @($teams)
                $teamsCount = $teamsArray.Count
                Write-Verbose "Syncing Teams inventory ($teamsCount teams)"

                if ($teamsCount -gt 0) {
                    $null = Sync-ConfluenceTeamsInventory -SpaceKey $SpaceKey -Teams $teamsArray
                    $CompanyResult.Logs.Add("Teams sync complete: $teamsCount teams")
                }
                else {
                    $CompanyResult.Logs.Add('Teams sync skipped: no Teams data in cache')
                }
            }
            catch {
                $CompanyResult.Errors.Add("Teams sync failed: $_")
                Write-Verbose "Teams sync error: $_"
            }
        }
        else {
            Write-Verbose 'Teams sync disabled in configuration'
            $CompanyResult.Logs.Add('Teams sync skipped: disabled in configuration')
        }

        # 5f: SharePoint Inventory
        if ($confluenceConfig.SyncSharePoint -ne $false) {
            try {
                # SharePoint data comes from OneDriveUsage and possibly SPOSites
                $oneDriveData = @($ExtensionCache.OneDriveUsage)
                Write-Verbose "Syncing SharePoint/OneDrive inventory ($($oneDriveData.Count) sites)"

                if ($oneDriveData.Count -gt 0) {
                    $null = Sync-ConfluenceSharePointInventory -SpaceKey $SpaceKey -Sites $oneDriveData
                    $CompanyResult.Logs.Add("SharePoint sync complete: $($oneDriveData.Count) sites")
                }
                else {
                    $CompanyResult.Logs.Add('SharePoint sync skipped: no OneDrive/SharePoint data in cache')
                }
            }
            catch {
                $CompanyResult.Errors.Add("SharePoint sync failed: $_")
                Write-Verbose "SharePoint sync error: $_"
            }
        }
        else {
            Write-Verbose 'SharePoint sync disabled in configuration'
            $CompanyResult.Logs.Add('SharePoint sync skipped: disabled in configuration')
        }

        $CompanyResult.Logs.Add('Confluence Extension Sync completed')
    }
    catch {
        $CompanyResult.Errors.Add("Orchestrator error: $_")
        Write-Verbose "Fatal orchestrator error: $_"
    }

    # Final summary
    $errorCount = $CompanyResult.Errors.Count
    Write-Verbose "Sync complete. Users: $($CompanyResult.Users), Devices: $($CompanyResult.Devices), Errors: $errorCount"

    return $CompanyResult
}
