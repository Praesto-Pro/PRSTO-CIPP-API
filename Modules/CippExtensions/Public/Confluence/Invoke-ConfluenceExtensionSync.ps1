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
        - Sync-ConfluenceSaaSInventory (Third-Party SaaS Apps)
    .LINK
        Connect-ConfluenceAPI
    .LINK
        Get-ConfluenceMapping
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Configuration,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$TenantFilter
    )

    # Set ConfirmPreference to None to allow non-interactive sync operations
    # (Sync functions use SupportsShouldProcess which requires this in Azure Functions)
    $ConfirmPreference = 'None'

    # Phase 1: Initialize result tracking with Generic Lists for O(1) append
    # Note: Name will be updated to display name once cache is loaded (matches Hudu pattern)
    Write-Verbose "Initializing Confluence extension sync for tenant '$TenantFilter'"
    Write-LogMessage -API 'ConfluenceSync' -tenant $TenantFilter -message "Starting Confluence extension sync for $TenantFilter" -Sev 'Debug'

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
            Write-LogMessage -API 'ConfluenceSync' -tenant $TenantFilter -message "Confluence connection failed: $errorMsg" -Sev 'Error'
            Write-Verbose "Connection failed: $errorMsg"
            return $CompanyResult
        }
        $CompanyResult.Logs.Add('Connected to Confluence API')
        Write-LogMessage -API 'ConfluenceSync' -tenant $TenantFilter -message 'Connected to Confluence API' -Sev 'Debug'

        # Phase 3: Resolve tenant mapping
        Write-Verbose "Resolving tenant mapping for '$TenantFilter'"
        $allMappings = Get-ConfluenceMapping
        # Match by TenantDomain (defaultDomainName), TenantId (customerId), or Tenant (displayName)
        $TenantMapping = $allMappings | Where-Object {
            $_.TenantDomain -eq $TenantFilter -or
            $_.TenantId -eq $TenantFilter -or
            $_.Tenant -eq $TenantFilter
        }

        if (-not $TenantMapping) {
            $CompanyResult.Errors.Add("No Confluence mapping found for tenant '$TenantFilter'. Configure mappings in CIPP Settings > Extensions > Confluence.")
            Write-LogMessage -API 'ConfluenceSync' -tenant $TenantFilter -message "No Confluence mapping found for tenant '$TenantFilter'" -Sev 'Warning'
            Write-Verbose "No mapping found for tenant '$TenantFilter'"
            return $CompanyResult
        }

        # IntegrationId contains the Confluence space key
        $SpaceKey = $TenantMapping.IntegrationId
        if (-not $SpaceKey) {
            $CompanyResult.Errors.Add("Tenant mapping exists but IntegrationId (space key) is empty for '$TenantFilter'")
            Write-LogMessage -API 'ConfluenceSync' -tenant $TenantFilter -message "Tenant mapping exists but space key is empty for '$TenantFilter'" -Sev 'Error'
            return $CompanyResult
        }

        Write-Verbose "Resolved tenant mapping: SpaceKey = '$SpaceKey'"
        Write-LogMessage -API 'ConfluenceSync' -tenant $TenantFilter -message "Resolved tenant to Confluence space key '$SpaceKey'" -Sev 'Info'
        $CompanyResult.Logs.Add("Tenant mapped to Confluence space '$SpaceKey'")

        # Phase 4: Load cached M365 data
        Write-Verbose 'Loading cached M365 data from CacheExtensionSync'
        $ExtensionCache = Get-ExtensionCacheData -TenantFilter $TenantFilter

        if ($null -eq $ExtensionCache) {
            $CompanyResult.Errors.Add("No cached data found for tenant '$TenantFilter'. Run Sync-CippExtensionData first.")
            Write-LogMessage -API 'ConfluenceSync' -tenant $TenantFilter -message "No cached M365 data found for tenant '$TenantFilter'" -Sev 'Error'
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
                # Fetch users directly with signInActivity for Last Login column
                # Uses beta API to get signInActivity which isn't in the extension cache
                Write-Verbose "Fetching user data with sign-in activity for tenant $TenantFilter"
                $usersUri = "https://graph.microsoft.com/beta/users?`$top=999&`$select=id,accountEnabled,displayName,userPrincipalName,userType,assignedLicenses,signInActivity,createdDateTime,jobTitle,officeLocation,mobilePhone,manager"
                $users = @(New-GraphGetRequest -uri $usersUri -tenantid $TenantFilter)
                $userCount = $users.Count
                Write-Verbose "Syncing user inventory ($userCount users)"

                if ($userCount -gt 0) {
                    $syncParams = @{
                        SpaceKey = $SpaceKey
                        Users    = $users
                    }

                    # Add licenses if available in cache
                    if ($ExtensionCache.Licenses) {
                        $syncParams['Licenses'] = @($ExtensionCache.Licenses)
                    }

                    # Fetch and add MFA data for accurate MFA status
                    # This uses the same data source as the MFA Report for consistency
                    try {
                        $mfaData = @(Get-CIPPMFAState -TenantFilter $TenantFilter)
                        if ($mfaData.Count -gt 0) {
                            $syncParams['MFAData'] = $mfaData
                            Write-Verbose "Added MFA data for $($mfaData.Count) users"
                        }
                    }
                    catch {
                        Write-Verbose "Could not fetch MFA data: $_"
                    }

                    # Data-level change detection: hash all inputs that affect the user page
                    $userDataToHash = @{ Users = $users; Licenses = $syncParams['Licenses']; MFAData = $syncParams['MFAData'] }
                    $userDataHash = Get-ConfluenceDataHash -InputData $userDataToHash
                    $userCachedHash = Get-ConfluenceDataCache -SpaceKey $SpaceKey -DataType 'UserInventory'
                    if ($userCachedHash -and $userCachedHash.Hash -eq $userDataHash) {
                        $CompanyResult.Users = $userCount
                        $CompanyResult.Logs.Add("User sync skipped: data unchanged ($userCount users)")
                        Write-LogMessage -API 'ConfluenceSync' -tenant $TenantFilter -message "User sync skipped: data unchanged since last sync ($userCount users)" -Sev 'Info'
                    }
                    else {
                        $syncResult = Sync-ConfluenceUserInventory @syncParams
                        Set-ConfluenceDataCache -SpaceKey $SpaceKey -DataType 'UserInventory' -Hash $userDataHash
                        $CompanyResult.Users = $userCount
                        $CompanyResult.Logs.Add("User sync complete: $userCount users")
                        Write-LogMessage -API 'ConfluenceSync' -tenant $TenantFilter -message "User sync complete: $userCount users synced (Action: $($syncResult.Action))" -Sev 'Info'
                    }
                }
                else {
                    $CompanyResult.Logs.Add('User sync skipped: no users found')
                    Write-LogMessage -API 'ConfluenceSync' -tenant $TenantFilter -message 'User sync skipped: no users found' -Sev 'Debug'
                }
            }
            catch {
                $CompanyResult.Errors.Add("User sync failed: $_")
                Write-LogMessage -API 'ConfluenceSync' -tenant $TenantFilter -message "User sync failed: $_" -Sev 'Error'
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
                # Fetch devices directly from Intune managedDevices API (same as Invoke-ListDevices)
                # This provides richer data than the extension cache
                Write-Verbose "Fetching Intune managed devices for tenant $TenantFilter"
                $devices = @(New-GraphGetRequest -uri 'https://graph.microsoft.com/beta/deviceManagement/managedDevices' -tenantid $TenantFilter)
                $deviceCount = $devices.Count
                Write-Verbose "Syncing endpoint inventory ($deviceCount devices)"

                if ($deviceCount -gt 0) {
                    # Data-level change detection
                    $deviceDataHash = Get-ConfluenceDataHash -InputData $devices
                    $deviceCachedHash = Get-ConfluenceDataCache -SpaceKey $SpaceKey -DataType 'EndpointInventory'
                    if ($deviceCachedHash -and $deviceCachedHash.Hash -eq $deviceDataHash) {
                        $CompanyResult.Devices = $deviceCount
                        $CompanyResult.Logs.Add("Device sync skipped: data unchanged ($deviceCount devices)")
                        Write-LogMessage -API 'ConfluenceSync' -tenant $TenantFilter -message "Device sync skipped: data unchanged since last sync ($deviceCount devices)" -Sev 'Info'
                    }
                    else {
                        $syncResult = Sync-ConfluenceEndpointInventory -SpaceKey $SpaceKey -Endpoints $devices
                        Set-ConfluenceDataCache -SpaceKey $SpaceKey -DataType 'EndpointInventory' -Hash $deviceDataHash
                        $CompanyResult.Devices = $deviceCount
                        $CompanyResult.Logs.Add("Device sync complete: $deviceCount devices")
                        Write-LogMessage -API 'ConfluenceSync' -tenant $TenantFilter -message "Device sync complete: $deviceCount devices synced (Action: $($syncResult.Action))" -Sev 'Info'
                    }
                }
                else {
                    $CompanyResult.Logs.Add('Device sync skipped: no devices found')
                    Write-LogMessage -API 'ConfluenceSync' -tenant $TenantFilter -message 'Device sync skipped: no devices found' -Sev 'Debug'
                }
            }
            catch {
                $CompanyResult.Errors.Add("Device sync failed: $_")
                Write-LogMessage -API 'ConfluenceSync' -tenant $TenantFilter -message "Device sync failed: $_" -Sev 'Error'
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

                    # Data-level change detection: hash licenses and users (both affect the page)
                    $licenseDataToHash = @{ Licenses = $licenses; Users = $syncParams['Users'] }
                    $licenseDataHash = Get-ConfluenceDataHash -InputData $licenseDataToHash
                    $licenseCachedHash = Get-ConfluenceDataCache -SpaceKey $SpaceKey -DataType 'LicenseReport'
                    if ($licenseCachedHash -and $licenseCachedHash.Hash -eq $licenseDataHash) {
                        $CompanyResult.Logs.Add("License sync skipped: data unchanged ($licenseCount licenses)")
                        Write-LogMessage -API 'ConfluenceSync' -tenant $TenantFilter -message "License sync skipped: data unchanged since last sync ($licenseCount licenses)" -Sev 'Info'
                    }
                    else {
                        $syncResult = Sync-ConfluenceLicenseReport @syncParams
                        Set-ConfluenceDataCache -SpaceKey $SpaceKey -DataType 'LicenseReport' -Hash $licenseDataHash
                        $CompanyResult.Logs.Add("License sync complete: $licenseCount licenses")
                        Write-LogMessage -API 'ConfluenceSync' -tenant $TenantFilter -message "License sync complete: $licenseCount licenses synced (Action: $($syncResult.Action))" -Sev 'Info'
                    }
                }
                else {
                    $CompanyResult.Logs.Add('License sync skipped: no licenses in cache')
                    Write-LogMessage -API 'ConfluenceSync' -tenant $TenantFilter -message 'License sync skipped: no licenses in cache' -Sev 'Debug'
                }
            }
            catch {
                $CompanyResult.Errors.Add("License sync failed: $_")
                Write-LogMessage -API 'ConfluenceSync' -tenant $TenantFilter -message "License sync failed: $_" -Sev 'Error'
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
                # Fetch MFA data directly using Get-CIPPMFAState (same as Invoke-ListMFAUsers)
                # This returns proper MFA properties: UPN, DisplayName, MFARegistration, PerUser, MFAMethods, CoveredBySD, CoveredByCA
                Write-Verbose "Fetching MFA data for tenant $TenantFilter"
                $mfaData = @(Get-CIPPMFAState -TenantFilter $TenantFilter)
                Write-Verbose "Syncing MFA report ($($mfaData.Count) users)"

                if ($mfaData.Count -gt 0) {
                    # Data-level change detection
                    $mfaDataHash = Get-ConfluenceDataHash -InputData $mfaData
                    $mfaCachedHash = Get-ConfluenceDataCache -SpaceKey $SpaceKey -DataType 'MFAReport'
                    if ($mfaCachedHash -and $mfaCachedHash.Hash -eq $mfaDataHash) {
                        $CompanyResult.Logs.Add("MFA sync skipped: data unchanged ($($mfaData.Count) users)")
                        Write-LogMessage -API 'ConfluenceSync' -tenant $TenantFilter -message "MFA sync skipped: data unchanged since last sync ($($mfaData.Count) users)" -Sev 'Info'
                    }
                    else {
                        $syncResult = Sync-ConfluenceMFAReport -SpaceKey $SpaceKey -MFAData $mfaData
                        Set-ConfluenceDataCache -SpaceKey $SpaceKey -DataType 'MFAReport' -Hash $mfaDataHash
                        $CompanyResult.Logs.Add("MFA sync complete: $($mfaData.Count) users")
                        Write-LogMessage -API 'ConfluenceSync' -tenant $TenantFilter -message "MFA sync complete: $($mfaData.Count) users synced (Action: $($syncResult.Action))" -Sev 'Info'
                    }
                }
                else {
                    $CompanyResult.Logs.Add('MFA sync skipped: no MFA data available')
                    Write-LogMessage -API 'ConfluenceSync' -tenant $TenantFilter -message 'MFA sync skipped: no MFA data available' -Sev 'Debug'
                }
            }
            catch {
                $CompanyResult.Errors.Add("MFA sync failed: $_")
                Write-LogMessage -API 'ConfluenceSync' -tenant $TenantFilter -message "MFA sync failed: $_" -Sev 'Error'
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
                    # Enrich teams with member/owner counts from cached group members
                    # Group members are stored as Groups_{groupId} in the cache
                    $enrichedTeams = foreach ($team in $teamsArray) {
                        $groupId = $team.id
                        $memberKey = "Groups_$groupId"
                        $membersRaw = $ExtensionCache.$memberKey
                        $members = if ($membersRaw) { @($membersRaw) } else { @() }

                        # Count members from cached group members
                        $memberCount = $members.Count

                        # Create enriched team object with member count
                        [PSCustomObject]@{
                            id                          = $team.id
                            displayName                 = $team.displayName
                            description                 = $team.description
                            visibility                  = $team.visibility
                            memberCount                 = $memberCount
                            groupTypes                  = $team.groupTypes
                            resourceProvisioningOptions = $team.resourceProvisioningOptions
                            mail                        = $team.mail
                            createdDateTime             = $team.createdDateTime
                        }
                    }

                    # Data-level change detection
                    $teamsDataHash = Get-ConfluenceDataHash -InputData $enrichedTeams
                    $teamsCachedHash = Get-ConfluenceDataCache -SpaceKey $SpaceKey -DataType 'TeamsInventory'
                    if ($teamsCachedHash -and $teamsCachedHash.Hash -eq $teamsDataHash) {
                        $CompanyResult.Logs.Add("Teams sync skipped: data unchanged ($teamsCount teams)")
                        Write-LogMessage -API 'ConfluenceSync' -tenant $TenantFilter -message "Teams sync skipped: data unchanged since last sync ($teamsCount teams)" -Sev 'Info'
                    }
                    else {
                        $syncResult = Sync-ConfluenceTeamsInventory -SpaceKey $SpaceKey -TeamsData $enrichedTeams
                        Set-ConfluenceDataCache -SpaceKey $SpaceKey -DataType 'TeamsInventory' -Hash $teamsDataHash
                        $CompanyResult.Logs.Add("Teams sync complete: $teamsCount teams")
                        Write-LogMessage -API 'ConfluenceSync' -tenant $TenantFilter -message "Teams sync complete: $teamsCount teams synced (Action: $($syncResult.Action))" -Sev 'Info'
                    }
                }
                else {
                    $CompanyResult.Logs.Add('Teams sync skipped: no Teams data in cache')
                    Write-LogMessage -API 'ConfluenceSync' -tenant $TenantFilter -message 'Teams sync skipped: no Teams data in cache' -Sev 'Debug'
                }
            }
            catch {
                $CompanyResult.Errors.Add("Teams sync failed: $_")
                Write-LogMessage -API 'ConfluenceSync' -tenant $TenantFilter -message "Teams sync failed: $_" -Sev 'Error'
                Write-Verbose "Teams sync error: $_"
            }
        }
        else {
            Write-Verbose 'Teams sync disabled in configuration'
            $CompanyResult.Logs.Add('Teams sync skipped: disabled in configuration')
        }

        # 5f: SharePoint/OneDrive Inventory
        if ($confluenceConfig.SyncSharePoint -ne $false) {
            try {
                # Fetch SharePoint data directly using bulk request (same pattern as Invoke-ListSites)
                # This bypasses the cache which has issues with the sites/getAllSites API
                $BulkRequests = @(
                    @{
                        id     = 'listAllSites'
                        method = 'GET'
                        url    = "sites/getAllSites?`$filter=isPersonalSite eq false&`$select=id,createdDateTime,description,name,displayName,isPersonalSite,lastModifiedDateTime,webUrl,siteCollection,sharepointIds&`$top=999"
                    }
                    @{
                        id     = 'sharePointUsage'
                        method = 'GET'
                        url    = "reports/getSharePointSiteUsageDetail(period='D7')?`$format=application/json&`$top=999"
                    }
                    @{
                        id     = 'oneDriveUsage'
                        method = 'GET'
                        url    = "reports/getOneDriveUsageAccountDetail(period='D7')?`$format=application/json&`$top=999"
                    }
                )

                $Result = New-GraphBulkRequest -tenantid $TenantFilter -Requests @($BulkRequests) -asapp $true
                $sharePointSites = @(($Result | Where-Object { $_.id -eq 'listAllSites' }).body.value)

                # Usage reports are base64 encoded
                $spUsageBase64 = ($Result | Where-Object { $_.id -eq 'sharePointUsage' }).body
                $sharePointUsage = @()
                if ($spUsageBase64 -match '^eyJ') {
                    $spUsageJson = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($spUsageBase64))
                    $sharePointUsage = @(($spUsageJson | ConvertFrom-Json).value)
                }

                $odUsageBase64 = ($Result | Where-Object { $_.id -eq 'oneDriveUsage' }).body
                $oneDriveData = @()
                if ($odUsageBase64 -match '^eyJ') {
                    $odUsageJson = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($odUsageBase64))
                    $oneDriveData = @(($odUsageJson | ConvertFrom-Json).value)
                }

                Write-Verbose "SharePoint sites: $($sharePointSites.Count), Usage: $($sharePointUsage.Count), OneDrive: $($oneDriveData.Count)"

                # Build combined SharePoint data (sites enriched with usage data)
                $combinedSharePointData = @()
                if ($sharePointSites.Count -gt 0) {
                    $combinedSharePointData = foreach ($site in $sharePointSites) {
                        # Match usage by siteId (sharepointIds.siteId in sites, siteId in usage)
                        $siteId = if ($site.sharepointIds) { $site.sharepointIds.siteId } else { $site.id }
                        $usage = $sharePointUsage | Where-Object { $_.siteId -eq $siteId }

                        # Use lastActivityDate from usage report if available (more accurate), fallback to lastModifiedDateTime
                        $lastModified = if ($usage -and $usage.lastActivityDate) {
                            $usage.lastActivityDate
                        } elseif ($site.lastModifiedDateTime) {
                            $site.lastModifiedDateTime
                        } else {
                            $null
                        }

                        [PSCustomObject]@{
                            displayName          = $site.displayName
                            webUrl               = $site.webUrl
                            siteType             = 'SharePoint'
                            storageUsedInBytes   = if ($usage) { $usage.storageUsedInBytes } else { $null }
                            lastModifiedDateTime = $lastModified
                            ownerDisplayName     = if ($usage) { $usage.ownerDisplayName } else { $null }
                            ownerPrincipalName   = if ($usage) { $usage.ownerPrincipalName } else { $null }
                            template             = if ($usage) { $usage.rootWebTemplate } else { $null }
                        }
                    }
                }

                # Add OneDrive sites (mark as OneDrive type)
                $oneDriveEnriched = foreach ($od in $oneDriveData) {
                    [PSCustomObject]@{
                        displayName             = $od.ownerDisplayName
                        webUrl                  = $od.siteUrl
                        siteType                = 'OneDrive'
                        storageUsedInBytes      = $od.storageUsedInBytes
                        storageAllocatedInBytes = $od.storageAllocatedInBytes
                        lastModifiedDateTime    = $od.lastActivityDate
                        ownerDisplayName        = $od.ownerDisplayName
                        ownerPrincipalName      = $od.ownerPrincipalName
                    }
                }

                # Combine both into one array
                $allSitesData = @($combinedSharePointData) + @($oneDriveEnriched)
                Write-Verbose "Combined site data: $($allSitesData.Count) total sites"

                if ($allSitesData.Count -gt 0) {
                    # Data-level change detection
                    $spDataHash = Get-ConfluenceDataHash -InputData $allSitesData
                    $spCachedHash = Get-ConfluenceDataCache -SpaceKey $SpaceKey -DataType 'SharePointInventory'
                    if ($spCachedHash -and $spCachedHash.Hash -eq $spDataHash) {
                        $CompanyResult.Logs.Add("SharePoint/OneDrive sync skipped: data unchanged ($($allSitesData.Count) sites)")
                        Write-LogMessage -API 'ConfluenceSync' -tenant $TenantFilter -message "SharePoint/OneDrive sync skipped: data unchanged since last sync ($($allSitesData.Count) sites)" -Sev 'Info'
                    }
                    else {
                        $syncResult = Sync-ConfluenceSharePointInventory -SpaceKey $SpaceKey -SharePointData $allSitesData
                        Set-ConfluenceDataCache -SpaceKey $SpaceKey -DataType 'SharePointInventory' -Hash $spDataHash
                        $CompanyResult.Logs.Add("SharePoint/OneDrive sync complete: $($allSitesData.Count) sites")
                        Write-LogMessage -API 'ConfluenceSync' -tenant $TenantFilter -message "SharePoint/OneDrive sync complete: $($allSitesData.Count) sites synced (Action: $($syncResult.Action))" -Sev 'Info'
                    }
                }
                else {
                    $CompanyResult.Logs.Add('SharePoint sync skipped: no SharePoint/OneDrive data available')
                    Write-LogMessage -API 'ConfluenceSync' -tenant $TenantFilter -message 'SharePoint sync skipped: no data available' -Sev 'Info'
                }
            }
            catch {
                $CompanyResult.Errors.Add("SharePoint sync failed: $_")
                Write-LogMessage -API 'ConfluenceSync' -tenant $TenantFilter -message "SharePoint sync failed: $_" -Sev 'Error'
                Write-Verbose "SharePoint sync error: $_"
            }
        }
        else {
            Write-Verbose 'SharePoint sync disabled in configuration'
            $CompanyResult.Logs.Add('SharePoint sync skipped: disabled in configuration')
        }

        # 5g: Third-Party SaaS Applications
        if ($confluenceConfig.SyncSaaSApps -ne $false) {
            try {
                # Fetch service principals from Microsoft Graph
                # Filter out Microsoft built-in apps (done by the transformer)
                Write-Verbose "Fetching service principals for tenant $TenantFilter"
                $servicePrincipalsUri = "https://graph.microsoft.com/beta/servicePrincipals?`$select=id,appId,displayName,createdDateTime,accountEnabled,homepage,publisherName,signInAudience,replyUrls,verifiedPublisher,info,api,appOwnerOrganizationId,tags,passwordCredentials,keyCredentials&`$count=true&`$top=999"
                $servicePrincipals = @(New-GraphGetRequest -uri $servicePrincipalsUri -tenantid $TenantFilter -ComplexFilter)
                Write-Verbose "Fetched $($servicePrincipals.Count) service principals"

                if ($servicePrincipals.Count -gt 0) {
                    # Data-level change detection
                    $saasDataHash = Get-ConfluenceDataHash -InputData $servicePrincipals
                    $saasCachedHash = Get-ConfluenceDataCache -SpaceKey $SpaceKey -DataType 'SaaSInventory'
                    if ($saasCachedHash -and $saasCachedHash.Hash -eq $saasDataHash) {
                        $CompanyResult.Logs.Add("SaaS Apps sync skipped: data unchanged ($($servicePrincipals.Count) service principals)")
                        Write-LogMessage -API 'ConfluenceSync' -tenant $TenantFilter -message "SaaS Apps sync skipped: data unchanged since last sync ($($servicePrincipals.Count) service principals)" -Sev 'Info'
                    }
                    else {
                        $syncResult = Sync-ConfluenceSaaSInventory -SpaceKey $SpaceKey -ServicePrincipals $servicePrincipals
                        Set-ConfluenceDataCache -SpaceKey $SpaceKey -DataType 'SaaSInventory' -Hash $saasDataHash
                        $CompanyResult.Logs.Add("SaaS Apps sync complete: $($servicePrincipals.Count) service principals processed")
                        Write-LogMessage -API 'ConfluenceSync' -tenant $TenantFilter -message "SaaS Apps sync complete: $($servicePrincipals.Count) service principals (Action: $($syncResult.Action))" -Sev 'Info'
                    }
                }
                else {
                    $CompanyResult.Logs.Add('SaaS Apps sync skipped: no service principals found')
                    Write-LogMessage -API 'ConfluenceSync' -tenant $TenantFilter -message 'SaaS Apps sync skipped: no service principals found' -Sev 'Debug'
                }
            }
            catch {
                $CompanyResult.Errors.Add("SaaS Apps sync failed: $_")
                Write-LogMessage -API 'ConfluenceSync' -tenant $TenantFilter -message "SaaS Apps sync failed: $_" -Sev 'Error'
                Write-Verbose "SaaS Apps sync error: $_"
            }
        }
        else {
            Write-Verbose 'SaaS Apps sync disabled in configuration'
            $CompanyResult.Logs.Add('SaaS Apps sync skipped: disabled in configuration')
        }

        $CompanyResult.Logs.Add('Confluence Extension Sync completed')
        Write-LogMessage -API 'ConfluenceSync' -tenant $TenantFilter -message "Confluence sync completed. Users: $($CompanyResult.Users), Devices: $($CompanyResult.Devices)" -Sev 'Info'
    }
    catch {
        $CompanyResult.Errors.Add("Orchestrator error: $_")
        Write-LogMessage -API 'ConfluenceSync' -tenant $TenantFilter -message "Confluence sync orchestrator error: $_" -Sev 'Error'
        Write-Verbose "Fatal orchestrator error: $_"
    }

    # Final summary
    $errorCount = $CompanyResult.Errors.Count
    Write-Verbose "Sync complete. Users: $($CompanyResult.Users), Devices: $($CompanyResult.Devices), Errors: $errorCount"

    if ($errorCount -gt 0) {
        Write-LogMessage -API 'ConfluenceSync' -tenant $TenantFilter -message "Confluence sync finished with $errorCount error(s)" -Sev 'Warning'
    }

    return $CompanyResult
}
