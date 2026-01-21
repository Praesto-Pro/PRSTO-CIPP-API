function Sync-ConfluenceUserInventory {
    <#
    .SYNOPSIS
        Syncs CIPP user inventory to a Confluence page.
    .DESCRIPTION
        Creates or updates a User Directory page as a subpage under the specified
        parent page (defaults to 'Overview & Contacts') in the Confluence space.
        The page displays user information in table format including status,
        licenses, and MFA status.

        The function:
        - Validates the target space exists
        - Finds or creates the parent page (e.g., 'Overview & Contacts')
        - Searches for an existing User Directory page under that parent
        - Creates a new page or updates the existing one
        - Returns a PSCustomObject with page details

        Supports -WhatIf to preview operations without making changes.
    .PARAMETER SpaceKey
        The Confluence space key where the page will be created/updated.
        The space must already exist.
    .PARAMETER Users
        Array of CIPP user objects from ListGraphRequest API.
        Guest users are automatically filtered out.
    .PARAMETER Licenses
        Optional license inventory array for SKU name lookup.
        When provided, displays license names instead of SKU IDs.
    .PARAMETER MFAData
        Optional MFA report data array for MFA status lookup.
        When provided, displays MFA registration status per user.
    .PARAMETER PageTitle
        Title for the page. Defaults to 'User Directory'.
    .PARAMETER ParentPageTitle
        Title for the parent page. Defaults to 'Overview & Contacts'.
        The parent page will be created if it doesn't exist.
    .OUTPUTS
        [PSCustomObject] - Object with Id, Title, SpaceKey, Version, Action properties
    .EXAMPLE
        Sync-ConfluenceUserInventory -SpaceKey 'CONTOSO' -Users $cippUsers

        Creates or updates the User Directory page under 'Overview & Contacts' in the CONTOSO space.
    .EXAMPLE
        Sync-ConfluenceUserInventory -SpaceKey 'CONTOSO' -Users $users -Licenses $licenses -MFAData $mfa

        Syncs user inventory with license names and MFA status.
    .EXAMPLE
        Sync-ConfluenceUserInventory -SpaceKey 'CONTOSO' -Users $users -ParentPageTitle 'Company Info'

        Creates User Directory under a custom parent page.
    .EXAMPLE
        Sync-ConfluenceUserInventory -SpaceKey 'CONTOSO' -Users $users -WhatIf

        Shows what would be synced without making changes.
    .NOTES
        This is a public function in the ConfluenceAPI module.
        Part of Story 4.2 - User Inventory Sync Function.

        Dependencies:
        - Get-ConfluenceSpace (Story 2.2)
        - Search-Confluence (Story 2.6)
        - New-ConfluencePage (Story 2.3)
        - Set-ConfluencePage (Story 2.3)
        - ConvertTo-ConfluenceUserPage (Story 4.1)
    .LINK
        Get-ConfluenceSpace
    .LINK
        Search-Confluence
    .LINK
        New-ConfluencePage
    .LINK
        Set-ConfluencePage
    .LINK
        ConvertTo-ConfluenceUserPage
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string]$SpaceKey,

        [Parameter()]
        [object[]]$Users,

        [Parameter()]
        [object[]]$Licenses,

        [Parameter()]
        [object[]]$MFAData,

        [Parameter()]
        [string]$PageTitle = 'User Directory',

        [Parameter()]
        [string]$ParentPageTitle = 'Overview & Contacts'
    )

    Write-Verbose "Syncing user inventory to space '$SpaceKey'"

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

    # Find or create parent page (e.g., 'Overview & Contacts')
    Write-Verbose "Finding or creating parent page '$ParentPageTitle' in space '$SpaceKey'"
    $parentPage = Find-ConfluencePageByTitle -SpaceKey $SpaceKey -Title $ParentPageTitle

    if (-not $parentPage) {
        Write-Verbose "Parent page '$ParentPageTitle' not found - creating it"
        if ($PSCmdlet.ShouldProcess($ParentPageTitle, "Create parent Confluence page")) {
            $parentPage = New-ConfluencePage -SpaceKey $SpaceKey -Title $ParentPageTitle
            Write-Verbose "Created parent page '$ParentPageTitle' (ID: $($parentPage.Id))"
        }
    }
    else {
        Write-Verbose "Found existing parent page '$ParentPageTitle' (ID: $($parentPage.Id))"
    }

    $parentPageId = if ($parentPage) { $parentPage.Id } else { $null }

    # Generate ADF content using Story 4.1 transformer
    $adfContent = ConvertTo-ConfluenceUserPage -Users $Users -Licenses $Licenses -MFAData $MFAData
    $userCount = if ($Users) { $Users.Count } else { 0 }
    Write-Verbose "Generated ADF content for $userCount user(s)"

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
        Write-Verbose "No existing page found - creating new page under parent '$ParentPageTitle'"
        if ($PSCmdlet.ShouldProcess($PageTitle, "Create Confluence page")) {
            try {
                # Create as child of parent page
                $newPageParams = @{
                    SpaceKey = $SpaceKey
                    Title    = $PageTitle
                    Body     = $adfContent
                }
                if ($parentPageId) {
                    $newPageParams['ParentId'] = $parentPageId
                }

                $result = New-ConfluencePage @newPageParams

                # Update cache after successful create (Story 10.4)
                Set-ConfluencePageCache -PageId $result.Id -SpaceKey $SpaceKey -PageTitle $PageTitle -Hash $newHash

                Write-Verbose "Successfully created page '$PageTitle' (ID: $($result.Id)) under parent '$ParentPageTitle'"
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
