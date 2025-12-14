function Sync-ConfluenceLicenseReport {
    <#
    .SYNOPSIS
        Syncs CIPP license report to a Confluence page.
    .DESCRIPTION
        Creates or updates a License Report page in the specified Confluence space
        with license data from CIPP. The page displays license summary with
        quantities and optionally user assignments.

        The function:
        - Validates the target space exists
        - Searches for an existing License Report page
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
        Title for the page. Defaults to 'License Report'.
    .PARAMETER ParentPageId
        Optional parent page ID for hierarchical organization.
        Note: Only applies when creating new pages. Existing pages are not moved.
        Use Move-ConfluencePage to relocate an existing page.
    .OUTPUTS
        [PSCustomObject] - Object with Id, Title, SpaceKey, Version, Action properties
    .EXAMPLE
        Sync-ConfluenceLicenseReport -SpaceKey 'CONTOSO' -Licenses $cippLicenses

        Creates or updates the License Report page in the CONTOSO space.
    .EXAMPLE
        Sync-ConfluenceLicenseReport -SpaceKey 'CONTOSO' -Licenses $licenses -Users $users

        Creates page with both license summary and user assignments tables.
    .EXAMPLE
        Sync-ConfluenceLicenseReport -SpaceKey 'CONTOSO' -Licenses $licenses -WhatIf

        Shows what would be synced without making changes.
    .EXAMPLE
        Sync-ConfluenceLicenseReport -SpaceKey 'CONTOSO' -Licenses $licenses -ParentPageId '12345'

        Creates or updates the page as a child of the specified parent page.
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
        [string]$PageTitle = 'License Report',

        [Parameter()]
        [string]$ParentPageId
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

    # Generate ADF content using Story 5.3 transformer
    $adfContent = ConvertTo-ConfluenceLicensePage -Licenses $Licenses -Users $Users
    $licenseCount = if ($Licenses) { $Licenses.Count } else { 0 }
    Write-Verbose "Generated ADF content for $licenseCount license type(s)"

    # Search for existing page using CQL (escape single quotes to prevent CQL injection)
    $escapedSpaceKey = $SpaceKey -replace "'", "''"
    $escapedTitle = $PageTitle -replace "'", "''"
    $cql = "space = '$escapedSpaceKey' AND title = '$escapedTitle' AND type = page"
    Write-Verbose "Searching for existing page with CQL: $cql"
    $existingPage = Search-Confluence -CQL $cql | Select-Object -First 1

    if ($existingPage) {
        Write-Verbose "Found existing page (ID: $($existingPage.Id)) - updating"
        if ($PSCmdlet.ShouldProcess($PageTitle, "Update Confluence page")) {
            $result = Set-ConfluencePage -PageId $existingPage.Id -Body $adfContent
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
