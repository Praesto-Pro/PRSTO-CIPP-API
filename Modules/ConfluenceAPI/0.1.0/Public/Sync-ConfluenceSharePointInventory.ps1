function Sync-ConfluenceSharePointInventory {
    <#
    .SYNOPSIS
        Syncs CIPP SharePoint inventory to a Confluence page.
    .DESCRIPTION
        Creates or updates a SharePoint Inventory page in the specified Confluence space
        with SharePoint site data from CIPP. The page displays storage summary with
        per-site details including URL, type, storage usage, and last modified date.

        The function:
        - Validates the target space exists
        - Searches for an existing SharePoint Inventory page
        - Creates a new page or updates the existing one
        - Returns a PSCustomObject with page details

        Supports -WhatIf to preview operations without making changes.
    .PARAMETER SpaceKey
        The Confluence space key where the page will be created/updated.
        The space must already exist.
    .PARAMETER SharePointData
        Array of CIPP SharePoint site objects from the SharePoint Report API.
        Expected properties: displayName, name, webUrl, template, siteType,
        storageUsedInBytes, lastModifiedDateTime.
    .PARAMETER PageTitle
        Title for the page. Defaults to 'SharePoint Inventory'.
    .PARAMETER ParentPageId
        Optional parent page ID for hierarchical organization.
        Note: Only applies when creating new pages. Existing pages are not moved.
        Use Move-ConfluencePage to relocate an existing page.
    .OUTPUTS
        [PSCustomObject] - Object with Id, Title, SpaceKey, Version, Action properties
    .EXAMPLE
        Sync-ConfluenceSharePointInventory -SpaceKey 'CONTOSO' -SharePointData $cippSharePointReport

        Creates or updates the SharePoint Inventory page in the CONTOSO space.
    .EXAMPLE
        Sync-ConfluenceSharePointInventory -SpaceKey 'CONTOSO' -SharePointData $sites -WhatIf

        Shows what would be synced without making changes.
    .EXAMPLE
        Sync-ConfluenceSharePointInventory -SpaceKey 'CONTOSO' -SharePointData $sites -ParentPageId '12345'

        Creates or updates the page as a child of the specified parent page.
    .EXAMPLE
        Sync-ConfluenceSharePointInventory -SpaceKey 'CONTOSO' -SharePointData $sites -PageTitle 'Storage - SharePoint Sites'

        Creates or updates the page with a custom title.
    .NOTES
        This is a public function in the ConfluenceAPI module.
        Part of Story 6.3 - SharePoint Inventory Transformer & Sync.

        Dependencies:
        - Get-ConfluenceSpace (Story 2.2)
        - Search-Confluence (Story 2.6)
        - New-ConfluencePage (Story 2.3)
        - Set-ConfluencePage (Story 2.3)
        - ConvertTo-ConfluenceSharePointPage (Story 6.3)
    .LINK
        Get-ConfluenceSpace
    .LINK
        Search-Confluence
    .LINK
        New-ConfluencePage
    .LINK
        Set-ConfluencePage
    .LINK
        ConvertTo-ConfluenceSharePointPage
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string]$SpaceKey,

        [Parameter()]
        [object[]]$SharePointData,

        [Parameter()]
        [string]$PageTitle = 'SharePoint Inventory',

        [Parameter()]
        [string]$ParentPageId
    )

    Write-Verbose "Syncing SharePoint inventory to space '$SpaceKey'"

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

    # Generate ADF content using Story 6.3 transformer
    $siteCount = if ($SharePointData) { $SharePointData.Count } else { 0 }
    Write-Verbose "Transforming $siteCount SharePoint site(s) to ADF content"
    $adfContent = ConvertTo-ConfluenceSharePointPage -SharePointData $SharePointData
    Write-Verbose "Generated ADF content for $siteCount site(s)"

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
        Write-Verbose "No existing page found - creating new page"
        if ($PSCmdlet.ShouldProcess($PageTitle, "Create Confluence page")) {
            try {
                $createParams = @{
                    SpaceKey = $SpaceKey
                    Title    = $PageTitle
                    Body     = $adfContent
                }
                if ($ParentPageId) {
                    $createParams['ParentId'] = $ParentPageId
                    Write-Verbose "Creating page under parent ID: $ParentPageId"
                }
                $result = New-ConfluencePage @createParams

                # Update cache after successful create (Story 10.4)
                Set-ConfluencePageCache -PageId $result.Id -SpaceKey $SpaceKey -PageTitle $PageTitle -Hash $newHash

                Write-Verbose "Successfully created page '$PageTitle' (ID: $($result.Id))"
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
