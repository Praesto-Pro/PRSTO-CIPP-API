function ConvertTo-ConfluenceUserPage {
    <#
    .SYNOPSIS
        Transforms CIPP user data into ADF content for Confluence pages.
    .DESCRIPTION
        Converts CIPP user objects into Atlassian Document Format (ADF) content
        suitable for creating/updating Confluence pages. Includes user status,
        license assignments, and MFA status.

        The function:
        - Filters out guest users (userType -eq 'Guest')
        - Maps accountEnabled to Active/Disabled status
        - Looks up license names from SKU IDs
        - Looks up MFA registration status by UPN
        - Adds a timestamp for data freshness (FR44)

        Returns an ADF JSON string that can be used directly with
        New-ConfluencePage -Body parameter.
    .PARAMETER Users
        Array of CIPP user objects from ListGraphRequest API.
        Expected properties: displayName, userPrincipalName, accountEnabled,
        userType, assignedLicenses.
    .PARAMETER Licenses
        Optional license inventory array for SKU name lookup.
        Expected properties: skuId, skuPartNumber.
    .PARAMETER MFAData
        Optional MFA report data array for MFA status lookup.
        Expected properties: UPN, MFARegistration.
    .OUTPUTS
        [string] - ADF JSON string ready for Confluence API
    .EXAMPLE
        $adf = ConvertTo-ConfluenceUserPage -Users $cippUsers

        Creates ADF content from user data with default status mappings.
    .EXAMPLE
        $adf = ConvertTo-ConfluenceUserPage -Users $users -Licenses $licenses -MFAData $mfa

        Creates ADF content with license names and MFA status lookup.
    .EXAMPLE
        $body = ConvertTo-ConfluenceUserPage -Users $users
        New-ConfluencePage -SpaceKey 'CLIENT' -Title 'User Inventory' -Body $body

        Creates a Confluence page with user inventory table.
    .NOTES
        This is a private function used internally by the ConfluenceAPI module.
        Part of Story 4.1 - User Data Transformer.

        CIPP Data Sources:
        - Users: ListGraphRequest API
        - Licenses: ListLicenses API
        - MFAData: ListMFAUsers API
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
        [object[]]$Users,

        [Parameter()]
        [object[]]$Licenses,

        [Parameter()]
        [object[]]$MFAData
    )

    Write-Verbose "Converting CIPP user data to Confluence page content..."

    # Create ADF document
    $doc = New-ADFDocument

    # Add heading
    $heading = New-ADFHeading -Level 1 -Text 'User Inventory'

    # Add timestamp (FR44)
    $timestamp = New-ADFParagraph -Text "Last updated: $(Get-Date -Format 'yyyy-MM-dd HH:mm') UTC"

    # Handle empty/null input
    if (-not $Users -or $Users.Count -eq 0) {
        Write-Verbose "No user data provided - creating placeholder content"
        $noData = New-ADFParagraph -Text 'No user data available' -Italic
        $doc = Add-ADFContent -Document $doc -Content @($heading, $timestamp, $noData)
        return ConvertTo-ADF -InputObject $doc
    }

    # Filter guest users
    $regularUsers = @($Users | Where-Object { $_.userType -ne 'Guest' })
    $guestCount = $Users.Count - $regularUsers.Count
    Write-Verbose "Filtered $guestCount guest user(s), processing $($regularUsers.Count) regular user(s)"

    # Handle case where all users are guests
    if ($regularUsers.Count -eq 0) {
        Write-Verbose "All users were guests - creating placeholder content"
        $noData = New-ADFParagraph -Text 'No user data available' -Italic
        $doc = Add-ADFContent -Document $doc -Content @($heading, $timestamp, $noData)
        return ConvertTo-ADF -InputObject $doc
    }

    # Build MFA lookup hashtable (case-insensitive for UPN matching)
    $mfaLookup = @{}
    if ($MFAData) {
        foreach ($mfaUser in $MFAData) {
            if ($mfaUser.UPN) {
                # Normalize UPN to lowercase for case-insensitive lookup
                $mfaLookup[$mfaUser.UPN.ToLower()] = $mfaUser.MFARegistration
            }
        }
        Write-Verbose "Created MFA lookup with $($mfaLookup.Count) entries"
    }

    # Build license lookup hashtable
    $licenseLookup = @{}
    if ($Licenses) {
        foreach ($lic in $Licenses) {
            if ($lic.skuId) {
                $licenseLookup[$lic.skuId] = $lic.skuPartNumber
            }
        }
        Write-Verbose "Created license lookup with $($licenseLookup.Count) entries"
    }

    # Transform users to table data
    $tableData = foreach ($user in $regularUsers) {
        # Status mapping (AC3)
        $status = 'Unknown'
        if ($null -ne $user.accountEnabled) {
            if ($user.accountEnabled -eq $true) {
                $status = 'Active'
            }
            else {
                $status = 'Disabled'
            }
        }

        # License mapping (AC4)
        $licenseNames = 'None'
        if ($user.assignedLicenses -and $user.assignedLicenses.Count -gt 0) {
            $names = @()
            foreach ($assigned in $user.assignedLicenses) {
                # Works for both hashtable and PSCustomObject
                $skuId = $assigned.skuId

                if ($skuId -and $licenseLookup.ContainsKey($skuId)) {
                    $names += $licenseLookup[$skuId]
                }
                elseif ($skuId) {
                    # Truncate unknown SKU ID for display
                    $names += $skuId.Substring(0, [Math]::Min(8, $skuId.Length)) + '...'
                }
            }
            if ($names.Count -gt 0) {
                $licenseNames = $names -join ', '
            }
        }

        # MFA mapping (AC5) - use lowercase for case-insensitive lookup
        $mfaStatus = 'Unknown'
        if ($mfaLookup.Count -gt 0 -and $user.userPrincipalName) {
            $upnLower = $user.userPrincipalName.ToLower()
            if ($mfaLookup.ContainsKey($upnLower)) {
                $mfaStatus = if ($mfaLookup[$upnLower]) { 'Registered' } else { 'Not Registered' }
            }
        }

        [PSCustomObject]@{
            DisplayName = $user.displayName
            Email       = $user.userPrincipalName
            Status      = $status
            Licenses    = $licenseNames
            MFAStatus   = $mfaStatus
        }
    }

    # Create table with specific column order
    $table = New-ADFTable -InputObject $tableData -Property DisplayName, Email, Status, Licenses, MFAStatus

    # Assemble document
    $doc = Add-ADFContent -Document $doc -Content @($heading, $timestamp, $table)

    Write-Verbose "Created user page with $($regularUsers.Count) user(s)"
    return ConvertTo-ADF -InputObject $doc
}
