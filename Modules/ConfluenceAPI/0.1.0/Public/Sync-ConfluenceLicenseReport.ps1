function Sync-ConfluenceLicenseReport {
    <#
    .SYNOPSIS
        Syncs CIPP license report to a Confluence page.
    .DESCRIPTION
        Creates or updates an M365 License Report page as a subpage under the
        specified parent hierarchy (defaults to 'Infrastructure Documentation > Cloud Services')
        in the Confluence space. The page displays license summary with
        quantities and optionally user assignments.

        The function:
        - Validates the target space exists
        - Finds or creates the parent page hierarchy
        - Searches for an existing M365 License Report page under that parent
        - Creates a new page or updates the existing one
        - Returns a PSCustomObject with page details

        Supports -WhatIf to preview operations without making changes.
    .PARAMETER SpaceKey
        The Confluence space key where the page will be created/updated.
        The space must already exist.
    .PARAMETER Licenses
        Array of CIPP license inventory objects from ListLicenses API.
        Expected properties: skuId, skuPartNumber, prepaidUnits, consumedUnits.
    .PARAMETER Users
        Optional array of CIPP user objects with assignedLicenses for
        generating the license assignments table.
    .PARAMETER PageTitle
        Title for the page. Defaults to 'M365 License Report'.
    .PARAMETER ParentPageTitle
        Title for the immediate parent page. Defaults to 'Cloud Services'.
        The parent page will be created if it doesn't exist.
    .PARAMETER GrandparentPageTitle
        Title for the grandparent page. Defaults to 'Infrastructure Documentation'.
        The grandparent page will be created if it doesn't exist.
    .OUTPUTS
        [PSCustomObject] - Object with Id, Title, SpaceKey, Version, Action properties
    .EXAMPLE
        Sync-ConfluenceLicenseReport -SpaceKey 'CONTOSO' -Licenses $cippLicenses

        Creates or updates the M365 License Report page under 'Infrastructure Documentation > Cloud Services' in the CONTOSO space.
    .EXAMPLE
        Sync-ConfluenceLicenseReport -SpaceKey 'CONTOSO' -Licenses $licenses -Users $users

        Creates page with both license summary and user assignments tables.
    .EXAMPLE
        Sync-ConfluenceLicenseReport -SpaceKey 'CONTOSO' -Licenses $licenses -WhatIf

        Shows what would be synced without making changes.
    .EXAMPLE
        Sync-ConfluenceLicenseReport -SpaceKey 'CONTOSO' -Licenses $licenses -ParentPageTitle 'Microsoft 365'

        Creates M365 License Report under a custom parent page.
    .NOTES
        This is a public function in the ConfluenceAPI module.
        Part of Story 5.4 - License Report Sync Function.

        Dependencies:
        - Get-ConfluenceSpace (Story 2.2)
        - Search-Confluence (Story 2.6)
        - New-ConfluencePage (Story 2.3)
        - Set-ConfluencePage (Story 2.3)
        - ConvertTo-ConfluenceLicensePage (Story 5.3)
    .LINK
        Get-ConfluenceSpace
    .LINK
        Search-Confluence
    .LINK
        New-ConfluencePage
    .LINK
        Set-ConfluencePage
    .LINK
        ConvertTo-ConfluenceLicensePage
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string]$SpaceKey,

        [Parameter()]
        [object[]]$Licenses,

        [Parameter()]
        [object[]]$Users,

        [Parameter()]
        [string]$PageTitle = 'M365 License Report',

        [Parameter()]
        [string]$ParentPageTitle = 'Cloud Services',

        [Parameter()]
        [string]$GrandparentPageTitle = 'Infrastructure Documentation'
    )

    Write-Verbose "Syncing license report to space '$SpaceKey'"

    # Validate space exists
    $space = Get-ConfluenceSpace -SpaceKey $SpaceKey -ErrorAction SilentlyContinue
    if (-not $space) {
        $PSCmdlet.ThrowTerminatingError(
            [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new("Space '$SpaceKey' not found. Use Get-ConfluenceSpace to list available spaces."),
                "SpaceNotFound",
                [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                $SpaceKey
            )
        )
    }

    # Find or create grandparent page (e.g., 'Infrastructure Documentation')
    Write-Verbose "Finding or creating grandparent page '$GrandparentPageTitle' in space '$SpaceKey'"
    $grandparentPage = Find-ConfluencePageByTitle -SpaceKey $SpaceKey -Title $GrandparentPageTitle

    if (-not $grandparentPage) {
        Write-Verbose "Grandparent page '$GrandparentPageTitle' not found - creating it"
        if ($PSCmdlet.ShouldProcess($GrandparentPageTitle, "Create grandparent Confluence page")) {
            $grandparentPage = New-ConfluencePage -SpaceKey $SpaceKey -Title $GrandparentPageTitle
            Write-Verbose "Created grandparent page '$GrandparentPageTitle' (ID: $($grandparentPage.Id))"
        }
    }
    else {
        Write-Verbose "Found existing grandparent page '$GrandparentPageTitle' (ID: $($grandparentPage.Id))"
    }

    $grandparentPageId = if ($grandparentPage) { $grandparentPage.Id } else { $null }

    # Find or create parent page (e.g., 'Cloud Services') under grandparent
    Write-Verbose "Finding or creating parent page '$ParentPageTitle' in space '$SpaceKey'"
    $parentPage = Find-ConfluencePageByTitle -SpaceKey $SpaceKey -Title $ParentPageTitle

    if (-not $parentPage) {
        Write-Verbose "Parent page '$ParentPageTitle' not found - creating it under '$GrandparentPageTitle'"
        if ($PSCmdlet.ShouldProcess($ParentPageTitle, "Create parent Confluence page")) {
            $createParentParams = @{
                SpaceKey = $SpaceKey
                Title    = $ParentPageTitle
            }
            if ($grandparentPageId) {
                $createParentParams['ParentId'] = $grandparentPageId
            }
            $parentPage = New-ConfluencePage @createParentParams
            Write-Verbose "Created parent page '$ParentPageTitle' (ID: $($parentPage.Id))"
        }
    }
    else {
        Write-Verbose "Found existing parent page '$ParentPageTitle' (ID: $($parentPage.Id))"
    }

    $parentPageId = if ($parentPage) { $parentPage.Id } else { $null }

    # Generate ADF content using Story 5.3 transformer
    $adfContent = ConvertTo-ConfluenceLicensePage -Licenses $Licenses -Users $Users
    $licenseCount = if ($Licenses) { $Licenses.Count } else { 0 }
    Write-Verbose "Generated ADF content for $licenseCount license type(s)"

    # Generate content hash for change detection (Story 10.4)
    $newHash = Get-ConfluenceContentHash -Content $adfContent

    # Find existing page using helper (handles search indexing delays)
    Write-Verbose "Searching for existing page '$PageTitle' in space '$SpaceKey'"
    $existingPage = Find-ConfluencePageByTitle -SpaceKey $SpaceKey -Title $PageTitle

    if ($existingPage) {
        # Check cache for change detection (Story 10.4)
        $cachedEntry = Get-ConfluencePageCache -PageId $existingPage.Id
        if ($cachedEntry -and $cachedEntry.Hash -eq $newHash) {
            Write-Verbose "Page '$PageTitle' unchanged, skipping update"
            return [PSCustomObject]@{
                Id       = $existingPage.Id
                Title    = $existingPage.Title
                SpaceKey = $SpaceKey
                Version  = if ($existingPage.Version.Number) { $existingPage.Version.Number } else { $null }
                Action   = 'Skipped'
                Message  = 'Page unchanged, skipping update'
            }
        }

        Write-Verbose "Found existing page (ID: $($existingPage.Id)) - updating"
        if ($PSCmdlet.ShouldProcess($PageTitle, "Update Confluence page")) {
            $result = Set-ConfluencePage -PageId $existingPage.Id -Body $adfContent

            # Update cache after successful update (Story 10.4)
            Set-ConfluencePageCache -PageId $result.Id -SpaceKey $SpaceKey -PageTitle $PageTitle -Hash $newHash

            Write-Verbose "Successfully updated page '$PageTitle' (ID: $($result.Id), Version: $($result.Version.Number))"
            return [PSCustomObject]@{
                Id       = $result.Id
                Title    = $result.Title
                SpaceKey = $SpaceKey
                Version  = $result.Version.Number
                Action   = 'Updated'
            }
        }
    }
    else {
        Write-Verbose "No existing page found - creating new page under '$GrandparentPageTitle > $ParentPageTitle'"
        if ($PSCmdlet.ShouldProcess($PageTitle, "Create Confluence page")) {
            try {
                $createParams = @{
                    SpaceKey = $SpaceKey
                    Title    = $PageTitle
                    Body     = $adfContent
                }
                if ($parentPageId) {
                    $createParams['ParentId'] = $parentPageId
                }
                $result = New-ConfluencePage @createParams

                # Update cache after successful create (Story 10.4)
                Set-ConfluencePageCache -PageId $result.Id -SpaceKey $SpaceKey -PageTitle $PageTitle -Hash $newHash

                Write-Verbose "Successfully created page '$PageTitle' (ID: $($result.Id)) under '$GrandparentPageTitle > $ParentPageTitle'"
                return [PSCustomObject]@{
                    Id       = $result.Id
                    Title    = $result.Title
                    SpaceKey = $SpaceKey
                    Version  = $result.Version.Number
                    Action   = 'Created'
                }
            }
            catch {
                # Handle "page already exists" error - search index was stale
                if ($_.Exception.Message -match 'already exists|same TITLE') {
                    Write-Verbose "Page creation failed because it already exists - retrying find and update"
                    $existingPage = Find-ConfluencePageByTitle -SpaceKey $SpaceKey -Title $PageTitle
                    if ($existingPage) {
                        $result = Set-ConfluencePage -PageId $existingPage.Id -Body $adfContent
                        Set-ConfluencePageCache -PageId $result.Id -SpaceKey $SpaceKey -PageTitle $PageTitle -Hash $newHash
                        Write-Verbose "Successfully updated existing page '$PageTitle' (ID: $($result.Id))"
                        return [PSCustomObject]@{
                            Id       = $result.Id
                            Title    = $result.Title
                            SpaceKey = $SpaceKey
                            Version  = $result.Version.Number
                            Action   = 'Updated'
                        }
                    }
                }
                # Re-throw if not handled
                throw
            }
        }
    }
}
