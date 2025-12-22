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
        Array of CIPP SharePoint site objects from the SharePoint Report API.
        Expected properties: displayName, name, webUrl, template, siteType,
        storageUsedInBytes, lastModifiedDateTime.
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

    # Transform to table format
    $tableData = foreach ($site in $SharePointData) {
        # Determine site name with fallbacks
        $siteName = if ($site.displayName) {
            $site.displayName
        } elseif ($site.name) {
            $site.name
        } elseif ($site.id) {
            $site.id
        } else {
            'Unknown Site'
        }

        # Get URL
        $siteUrl = if ($site.webUrl) { $site.webUrl } else { '' }

        # Determine site type from template or siteType property
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
        $lastModified = if ($site.lastModifiedDateTime) {
            try {
                $date = [datetime]::Parse($site.lastModifiedDateTime)
                $date.ToString('yyyy-MM-dd')
            } catch {
                # Fallback: try to extract first 10 chars if ISO format
                $dateStr = $site.lastModifiedDateTime.ToString()
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

    # Assemble document
    $doc = Add-ADFContent -Document $doc -Content @($heading, $timestamp, $summary, $table)

    Write-Verbose "Created SharePoint inventory page with $totalSites site(s)"
    return ConvertTo-ADF -InputObject $doc
}
