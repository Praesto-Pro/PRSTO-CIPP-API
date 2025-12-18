function Sync-ConfluenceUserInventory {
    <#
    .SYNOPSIS
        Syncs CIPP user inventory to a Confluence page.
    .DESCRIPTION
        Creates or updates a User Inventory page in the specified Confluence space
        with user data from CIPP. The page displays user information in table format
        including status, licenses, and MFA status.

        The function:
        - Validates the target space exists
        - Searches for an existing User Inventory page
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
        Title for the page. Defaults to 'User Inventory'.
    .OUTPUTS
        [PSCustomObject] - Object with Id, Title, SpaceKey, Version, Action properties
    .EXAMPLE
        Sync-ConfluenceUserInventory -SpaceKey 'CONTOSO' -Users $cippUsers

        Creates or updates the User Inventory page in the CONTOSO space.
    .EXAMPLE
        Sync-ConfluenceUserInventory -SpaceKey 'CONTOSO' -Users $users -Licenses $licenses -MFAData $mfa

        Syncs user inventory with license names and MFA status.
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
        [string]$PageTitle = 'User Inventory'
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

    # Generate ADF content using Story 4.1 transformer
    $adfContent = ConvertTo-ConfluenceUserPage -Users $Users -Licenses $Licenses -MFAData $MFAData
    $userCount = if ($Users) { $Users.Count } else { 0 }
    Write-Verbose "Generated ADF content for $userCount user(s)"

    # Generate content hash for change detection (Story 10.4)
    $newHash = Get-ConfluenceContentHash -Content $adfContent

    # Search for existing page using CQL (escape single quotes to prevent CQL injection)
    $escapedSpaceKey = $SpaceKey -replace "'", "''"
    $escapedTitle = $PageTitle -replace "'", "''"
    $cql = "space = '$escapedSpaceKey' AND title = '$escapedTitle' AND type = page"
    Write-Verbose "Searching for existing page with CQL: $cql"
    $existingPage = Search-Confluence -CQL $cql | Select-Object -First 1

    if ($existingPage) {
        # Check cache for change detection (Story 10.4)
        $cachedEntry = Get-ConfluencePageCache -PageId $existingPage.Id
        if ($cachedEntry -and $cachedEntry.Hash -eq $newHash) {
            Write-Verbose "Page '$PageTitle' unchanged, skipping update"
            return [PSCustomObject]@{
                Id       = $existingPage.Id
                Title    = $PageTitle
                SpaceKey = $SpaceKey
                Version  = $null
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
            $result = New-ConfluencePage -SpaceKey $SpaceKey -Title $PageTitle -Body $adfContent

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
    }
}
