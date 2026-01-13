function ConvertTo-ConfluenceSharePointPage {
    <#
    .SYNOPSIS
        Transforms CIPP SharePoint site data into ADF content for Confluence pages.
    .DESCRIPTION
        Converts CIPP SharePoint inventory objects into Atlassian Document Format (ADF) content
        suitable for creating/updating Confluence pages. Displays storage summary with
        per-site details including URL, type, and storage usage.

        The function:
        - Creates a summary section with total sites and total storage used
        - Creates a table showing each site's name, URL, type, storage, and last modified date
        - Adds a timestamp for data freshness (FR44)
        - Converts storage bytes to human-readable format (KB/MB/GB/TB)

        Returns an ADF JSON string that can be used directly with
        New-ConfluencePage -Body parameter.
    .PARAMETER SharePointData
        Array of CIPP SharePoint/OneDrive site objects.

        Supports two data sources with different property names:
        - SharePoint Sites API: displayName, name, webUrl, template, siteType,
          storageUsedInBytes, lastModifiedDateTime
        - OneDrive Usage Report (getOneDriveUsageAccountDetail): ownerDisplayName,
          ownerPrincipalName, siteUrl, storageUsedInBytes, lastActivityDate
    .OUTPUTS
        [string] - ADF JSON string ready for Confluence API
        Table columns: Site, URL, Type, Storage, Last Modified
    .EXAMPLE
        $adf = ConvertTo-ConfluenceSharePointPage -SharePointData $cippSharePointReport

        Creates ADF content with SharePoint inventory table.
    .EXAMPLE
        $body = ConvertTo-ConfluenceSharePointPage -SharePointData $sites
        New-ConfluencePage -SpaceKey 'CLIENT' -Title 'SharePoint Inventory' -Body $body

        Creates a Confluence page with SharePoint inventory report.
    .NOTES
        This is a private function used internally by the ConfluenceAPI module.
        Part of Story 6.3 - SharePoint Inventory Transformer & Sync.

        CIPP Data Source:
        - SharePointData: CIPP SharePoint Report API
    .LINK
        New-ADFDocument
    .LINK
        New-ADFTable
    .LINK
        New-ADFHeading
    .LINK
        New-ADFParagraph
    .LINK
        ConvertTo-ADF
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [object[]]$SharePointData
    )

    # Handle empty/null input first
    if (-not $SharePointData -or $SharePointData.Count -eq 0) {
        Write-Verbose "No SharePoint data provided - returning empty state message"
        $doc = New-ADFDocument
        $heading = New-ADFHeading -Level 2 -Text 'SharePoint Inventory'
        # Add timestamp even for empty state (FR44 compliance)
        $utcTime = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm')
        $timestamp = New-ADFParagraph -Text "Data as of: $utcTime UTC"
        $message = New-ADFParagraph -Text 'No SharePoint data available'
        $doc = Add-ADFContent -Document $doc -Content @($heading, $timestamp, $message)
        return ConvertTo-ADF -InputObject $doc
    }

    Write-Verbose "Transforming $($SharePointData.Count) SharePoint site record(s) to ADF content"

    # Create ADF document
    $doc = New-ADFDocument

    # Add heading
    $heading = New-ADFHeading -Level 2 -Text 'SharePoint Inventory'

    # Add timestamp (FR44) - use actual UTC time
    $utcTime = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm')
    $timestamp = New-ADFParagraph -Text "Data as of: $utcTime UTC"

    # Calculate summary statistics
    $totalSites = $SharePointData.Count
    $totalStorageBytes = ($SharePointData | Measure-Object -Property storageUsedInBytes -Sum -ErrorAction SilentlyContinue).Sum
    if (-not $totalStorageBytes) { $totalStorageBytes = 0 }

    # Convert total storage to human-readable (inline - no separate function)
    $totalStorageDisplay = if ($totalStorageBytes -ge 1TB) {
        "{0:N2} TB" -f ($totalStorageBytes / 1TB)
    } elseif ($totalStorageBytes -ge 1GB) {
        "{0:N2} GB" -f ($totalStorageBytes / 1GB)
    } elseif ($totalStorageBytes -ge 1MB) {
        "{0:N2} MB" -f ($totalStorageBytes / 1MB)
    } elseif ($totalStorageBytes -ge 1KB) {
        "{0:N2} KB" -f ($totalStorageBytes / 1KB)
    } else {
        "$totalStorageBytes B"
    }

    Write-Verbose "SharePoint inventory: $totalSites site(s), $totalStorageDisplay total storage"

    # Generate summary paragraph
    $summaryText = "Total Sites: $totalSites | Total Storage: $totalStorageDisplay"
    $summary = New-ADFParagraph -Text $summaryText

    # Check if data appears to be pseudonymized (first record has GUID-like ownerDisplayName or siteUrl)
    # Microsoft 365 privacy settings can cause ownerDisplayName, ownerPrincipalName, and siteUrl to return GUIDs
    $privacyWarning = $null
    $firstSite = $SharePointData | Select-Object -First 1
    if ($firstSite) {
        $guidPattern = '^[0-9a-fA-F]{8}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{12}$'
        $isPseudonymized = (
            ($firstSite.ownerDisplayName -and $firstSite.ownerDisplayName -match $guidPattern) -or
            ($firstSite.ownerPrincipalName -and $firstSite.ownerPrincipalName -match $guidPattern) -or
            ($firstSite.siteUrl -and $firstSite.siteUrl -match $guidPattern)
        )
        if ($isPseudonymized) {
            Write-Verbose 'Detected pseudonymized data - M365 privacy settings may be enabled'
            $privacyWarning = New-ADFParagraph -Text 'Note: Site names and URLs are hidden due to Microsoft 365 privacy settings. To display identifiable information, a Global Admin must go to M365 Admin Center > Settings > Org Settings > Reports and uncheck "Display de-identified names".'
        }
    }

    # Helper function to check if a value looks like a GUID (pseudonymized data)
    # Microsoft 365 privacy settings can cause ownerDisplayName, ownerPrincipalName, and siteUrl to return GUIDs
    # See: https://techcommunity.microsoft.com/blog/spblog/onedrive-usage-reports-return-guids-or-pseudonymized-values-instead-of-actual-da/2718010
    $isGuidOrPseudonymized = {
        param($value)
        if (-not $value) { return $true }
        $value = $value.ToString().Trim()
        # Check for standard GUID format (with or without hyphens)
        if ($value -match '^[0-9a-fA-F]{8}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{12}$') {
            return $true
        }
        return $false
    }

    # Transform to table format
    $tableData = foreach ($site in $SharePointData) {
        # Get URL first - support both webUrl (SharePoint) and siteUrl (OneDrive/SharePoint Usage Report)
        # Skip GUID values that indicate pseudonymized data
        $siteUrl = if ($site.webUrl -and -not (& $isGuidOrPseudonymized $site.webUrl)) {
            $site.webUrl
        } elseif ($site.siteUrl -and -not (& $isGuidOrPseudonymized $site.siteUrl)) {
            $site.siteUrl
        } else {
            ''
        }

        # Determine site name with fallbacks
        # Support SharePoint site (displayName), Usage Reports (ownerDisplayName), or extract from URL
        # Skip GUID values that indicate M365 privacy settings are concealing identifiable information
        $siteName = if ($site.displayName -and -not (& $isGuidOrPseudonymized $site.displayName)) {
            $site.displayName
        } elseif ($site.ownerDisplayName -and -not (& $isGuidOrPseudonymized $site.ownerDisplayName)) {
            $site.ownerDisplayName
        } elseif ($site.name -and -not (& $isGuidOrPseudonymized $site.name)) {
            $site.name
        } elseif ($site.ownerPrincipalName -and -not (& $isGuidOrPseudonymized $site.ownerPrincipalName)) {
            $site.ownerPrincipalName
        } elseif ($site.id -and -not (& $isGuidOrPseudonymized $site.id)) {
            $site.id
        } elseif ($siteUrl) {
            # Extract site name from URL (e.g., /sites/Marketing -> Marketing, /personal/john_contoso_com -> john_contoso_com)
            if ($siteUrl -match '/sites/([^/]+)') {
                $matches[1]
            } elseif ($siteUrl -match '/personal/([^/]+)') {
                $matches[1] -replace '_', ' '
            } elseif ($siteUrl -match '/teams/([^/]+)') {
                $matches[1]
            } else {
                'Unknown Site'
            }
        } else {
            # All identifying fields are pseudonymized - use storage-based identifier if available
            if ($null -ne $site.storageUsedInBytes -and $site.storageUsedInBytes -gt 0) {
                "Site ($($site.storageUsedInBytes) bytes)"
            } else {
                'Unknown Site'
            }
        }

        # Determine site type from template or siteType property
        # For OneDrive Usage Reports (which have storageAllocatedInBytes but no template), default to OneDrive
        $siteType = if ($site.template) {
            switch -Regex ($site.template) {
                'GROUP#0' { 'Team Site' }
                'STS#3' { 'Team Site' }
                'SITEPAGEPUBLISHING#0' { 'Communication Site' }
                'SPSPERS#' { 'OneDrive' }
                default {
                    if ($site.siteType) { $site.siteType } else { 'Other' }
                }
            }
        } elseif ($site.siteType) {
            $type = $site.siteType.ToString()
            switch ($type.ToLower()) {
                'teamsite' { 'Team Site' }
                'communicationsite' { 'Communication Site' }
                'onedrive' { 'OneDrive' }
                default { $type }
            }
        } elseif ($null -ne $site.storageAllocatedInBytes) {
            # OneDrive Usage Report data has storageAllocatedInBytes but no template/siteType
            'OneDrive'
        } else {
            'Unknown'
        }

        # Convert storage to human-readable (inline)
        $storageBytes = if ($null -ne $site.storageUsedInBytes) {
            [long]$site.storageUsedInBytes
        } else {
            0
        }

        $storageDisplay = if ($storageBytes -ge 1TB) {
            "{0:N2} TB" -f ($storageBytes / 1TB)
        } elseif ($storageBytes -ge 1GB) {
            "{0:N2} GB" -f ($storageBytes / 1GB)
        } elseif ($storageBytes -ge 1MB) {
            "{0:N2} MB" -f ($storageBytes / 1MB)
        } elseif ($storageBytes -ge 1KB) {
            "{0:N2} KB" -f ($storageBytes / 1KB)
        } else {
            "$storageBytes B"
        }

        # Format last modified date with error handling
        # Support both lastModifiedDateTime (SharePoint) and lastActivityDate (OneDrive Usage Report)
        $dateValue = if ($site.lastModifiedDateTime) {
            $site.lastModifiedDateTime
        } elseif ($site.lastActivityDate) {
            $site.lastActivityDate
        } else {
            $null
        }

        $lastModified = if ($dateValue) {
            try {
                $date = [datetime]::Parse($dateValue)
                $date.ToString('yyyy-MM-dd')
            } catch {
                # Fallback: try to extract first 10 chars if ISO format
                $dateStr = $dateValue.ToString()
                if ($dateStr.Length -ge 10) {
                    $dateStr.Substring(0, 10)
                } else {
                    $dateStr
                }
            }
        } else {
            ''
        }

        [PSCustomObject]@{
            'Site'          = $siteName
            'URL'           = $siteUrl
            'Type'          = $siteType
            'Storage'       = $storageDisplay
            'Last Modified' = $lastModified
        }
    }

    # Create table
    $table = New-ADFTable -InputObject $tableData -Property 'Site', 'URL', 'Type', 'Storage', 'Last Modified'

    # Assemble document - include privacy warning if pseudonymized data detected
    $contentElements = @($heading, $timestamp, $summary)
    if ($privacyWarning) {
        $contentElements += $privacyWarning
    }
    $contentElements += $table
    $doc = Add-ADFContent -Document $doc -Content $contentElements

    Write-Verbose "Created SharePoint inventory page with $totalSites site(s)"
    return ConvertTo-ADF -InputObject $doc
}
