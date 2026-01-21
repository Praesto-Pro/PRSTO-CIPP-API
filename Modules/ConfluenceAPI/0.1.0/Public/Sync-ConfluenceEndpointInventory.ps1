function Sync-ConfluenceEndpointInventory {
    <#
    .SYNOPSIS
        Syncs CIPP endpoint inventory to a Confluence page.
    .DESCRIPTION
        Creates or updates a Workstations & Endpoints page as a subpage under the
        specified parent page (defaults to 'Infrastructure Documentation') in the
        Confluence space. The page displays device information in table format
        including compliance status, assigned user, and last sync time.

        The function:
        - Validates the target space exists
        - Finds or creates the parent page (e.g., 'Infrastructure Documentation')
        - Searches for an existing Workstations & Endpoints page under that parent
        - Creates a new page or updates the existing one
        - Returns a PSCustomObject with page details

        Supports -WhatIf to preview operations without making changes.
    .PARAMETER SpaceKey
        The Confluence space key where the page will be created/updated.
        The space must already exist.
    .PARAMETER Endpoints
        Array of CIPP endpoint objects from Intune/Graph API.
    .PARAMETER PageTitle
        Title for the page. Defaults to 'Workstations & Endpoints'.
    .PARAMETER ParentPageTitle
        Title for the parent page. Defaults to 'Infrastructure Documentation'.
        The parent page will be created if it doesn't exist.
    .OUTPUTS
        [PSCustomObject] - Object with Id, Title, SpaceKey, Version, Action properties
    .EXAMPLE
        Sync-ConfluenceEndpointInventory -SpaceKey 'CONTOSO' -Endpoints $cippEndpoints

        Creates or updates the Workstations & Endpoints page under 'Infrastructure Documentation' in the CONTOSO space.
    .EXAMPLE
        Sync-ConfluenceEndpointInventory -SpaceKey 'CONTOSO' -Endpoints $endpoints -WhatIf

        Shows what would be synced without making changes.
    .EXAMPLE
        Sync-ConfluenceEndpointInventory -SpaceKey 'CONTOSO' -Endpoints $endpoints -ParentPageTitle 'IT Assets'

        Creates Workstations & Endpoints under a custom parent page.
    .NOTES
        This is a public function in the ConfluenceAPI module.
        Part of Story 5.2 - Endpoint Inventory Sync Function.

        Dependencies:
        - Get-ConfluenceSpace (Story 2.2)
        - Search-Confluence (Story 2.6)
        - New-ConfluencePage (Story 2.3)
        - Set-ConfluencePage (Story 2.3)
        - ConvertTo-ConfluenceEndpointPage (Story 5.1)
    .LINK
        Get-ConfluenceSpace
    .LINK
        Search-Confluence
    .LINK
        New-ConfluencePage
    .LINK
        Set-ConfluencePage
    .LINK
        ConvertTo-ConfluenceEndpointPage
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string]$SpaceKey,

        [Parameter()]
        [object[]]$Endpoints,

        [Parameter()]
        [string]$PageTitle = 'Workstations & Endpoints',

        [Parameter()]
        [string]$ParentPageTitle = 'Infrastructure Documentation'
    )

    Write-Verbose "Syncing endpoint inventory to space '$SpaceKey'"

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

    # Find or create parent page (e.g., 'Infrastructure Documentation')
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

    # Generate ADF content using Story 5.1 transformer
    $adfContent = ConvertTo-ConfluenceEndpointPage -Endpoints $Endpoints
    $endpointCount = if ($Endpoints) { $Endpoints.Count } else { 0 }
    Write-Verbose "Generated ADF content for $endpointCount endpoint(s)"

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
