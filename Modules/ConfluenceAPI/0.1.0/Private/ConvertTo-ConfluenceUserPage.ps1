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
        Array of CIPP user objects from Graph API.
        Expected properties: displayName, userPrincipalName, accountEnabled,
        userType, assignedLicenses, signInActivity, jobTitle, manager,
        officeLocation, mobilePhone (optional).
    .PARAMETER Licenses
        Optional license inventory array for SKU name lookup.
        Expected properties: skuId, skuPartNumber.
    .PARAMETER MFAData
        Optional MFA report data array from Get-CIPPMFAState for MFA status lookup.
        Expected properties: UPN, MFARegistration, PerUser, CoveredBySD, CoveredByCA.
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
    # Store full MFA user object to access all properties (MFARegistration, PerUser, CoveredBySD, CoveredByCA)
    $mfaLookup = @{}
    if ($MFAData) {
        foreach ($mfaUser in $MFAData) {
            if ($mfaUser.UPN) {
                # Normalize UPN to lowercase for case-insensitive lookup
                $mfaLookup[$mfaUser.UPN.ToLower()] = $mfaUser
            }
        }
        Write-Verbose "Created MFA lookup with $($mfaLookup.Count) entries"
    }

    # Load conversion table for license name normalization (same as ConvertTo-ConfluenceLicensePage)
    $ConvertTable = $null
    try {
        $ModuleBase = Get-Module -Name CIPPCore | Select-Object -ExpandProperty ModuleBase
        if ($ModuleBase) {
            $csvPath = Join-Path $ModuleBase 'lib\data\ConversionTable.csv'
            if (Test-Path $csvPath) {
                $ConvertTable = Import-Csv $csvPath
                Write-Verbose "Loaded license conversion table with $($ConvertTable.Count) entries"
            }
        }
    }
    catch {
        Write-Verbose "Could not load conversion table: $_"
    }

    # Build license lookup hashtable with friendly names
    $licenseLookup = @{}
    if ($Licenses) {
        foreach ($lic in $Licenses) {
            if ($lic.skuId) {
                # Use normalized name if available from conversion table
                $lookupName = if ($lic.skuPartNumber) { $lic.skuPartNumber } else { $lic.skuId }
                if ($ConvertTable) {
                    $friendlyName = ($ConvertTable | Where-Object { $_.String_Id -eq $lic.skuPartNumber } | Select-Object -First 1).'Product_Display_Name'
                    if (-not $friendlyName -and $lic.skuId) {
                        $friendlyName = ($ConvertTable | Where-Object { $_.GUID -eq $lic.skuId } | Select-Object -First 1).'Product_Display_Name'
                    }
                    if ($friendlyName) {
                        $lookupName = $friendlyName
                    }
                }
                $licenseLookup[$lic.skuId] = $lookupName
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

        # License mapping (AC4) - with friendly name lookup
        $licenseNames = 'None'
        if ($user.assignedLicenses -and $user.assignedLicenses.Count -gt 0) {
            $names = @()
            foreach ($assigned in $user.assignedLicenses) {
                # Works for both hashtable and PSCustomObject
                $skuId = $assigned.skuId

                if ($skuId -and $licenseLookup.ContainsKey($skuId)) {
                    $names += $licenseLookup[$skuId]
                }
                elseif ($skuId -and $ConvertTable) {
                    # Try to resolve unknown SKU from conversion table directly
                    $friendlyName = ($ConvertTable | Where-Object { $_.GUID -eq $skuId } | Select-Object -First 1).'Product_Display_Name'
                    if ($friendlyName) {
                        $names += $friendlyName
                    }
                    else {
                        # Truncate unknown SKU ID for display
                        $names += $skuId.Substring(0, [Math]::Min(8, $skuId.Length)) + '...'
                    }
                }
                elseif ($skuId) {
                    # Truncate unknown SKU ID for display
                    $names += $skuId.Substring(0, [Math]::Min(8, $skuId.Length)) + '...'
                }
            }
            if ($names.Count -gt 0) {
                $licenseNames = ($names | Sort-Object) -join ', '
            }
        }

        # MFA mapping (AC5) - use full MFA data for accurate status
        $mfaStatus = 'Unknown'
        if ($mfaLookup.Count -gt 0 -and $user.userPrincipalName) {
            $upnLower = $user.userPrincipalName.ToLower()
            if ($mfaLookup.ContainsKey($upnLower)) {
                $mfaUser = $mfaLookup[$upnLower]
                # Determine MFA status using same logic as MFA Report
                if ($mfaUser.PerUser -and $mfaUser.PerUser.ToLower() -eq 'enforced') {
                    $mfaStatus = 'Enforced'
                }
                elseif (($mfaUser.PerUser -and $mfaUser.PerUser.ToLower() -eq 'enabled') -or $mfaUser.MFARegistration -eq $true) {
                    $mfaStatus = 'Enabled'
                }
                elseif ($mfaUser.CoveredBySD -eq $true -or ($mfaUser.CoveredByCA -and $mfaUser.CoveredByCA -like 'Enforced*')) {
                    $mfaStatus = 'Protected'
                }
                else {
                    $mfaStatus = 'Not Protected'
                }
            }
        }

        # Last Login - use signInActivity from beta API
        $lastLogin = ''
        if ($user.signInActivity) {
            # Use most recent of interactive or non-interactive sign-in
            $lastInteractive = $user.signInActivity.lastSignInDateTime
            $lastNonInteractive = $user.signInActivity.lastNonInteractiveSignInDateTime

            $lastSignIn = $null
            if ($lastInteractive -and $lastNonInteractive) {
                $lastSignIn = if ([DateTime]$lastInteractive -gt [DateTime]$lastNonInteractive) { $lastInteractive } else { $lastNonInteractive }
            }
            elseif ($lastInteractive) {
                $lastSignIn = $lastInteractive
            }
            elseif ($lastNonInteractive) {
                $lastSignIn = $lastNonInteractive
            }

            if ($lastSignIn) {
                try {
                    $lastLogin = ([DateTime]$lastSignIn).ToString('yyyy-MM-dd')
                }
                catch {
                    $lastLogin = $lastSignIn.ToString().Substring(0, 10)
                }
            }
        }
        if (-not $lastLogin) {
            $lastLogin = 'Never'
        }

        # Job Title
        $title = if ($user.jobTitle) { $user.jobTitle } else { '' }

        # Manager - can be an object with displayName or just a string
        $managerName = ''
        if ($user.manager) {
            if ($user.manager.displayName) {
                $managerName = $user.manager.displayName
            }
            elseif ($user.manager -is [string]) {
                $managerName = $user.manager
            }
        }

        # Office Location
        $office = if ($user.officeLocation) { $user.officeLocation } else { '' }

        # Mobile Phone
        $mobile = if ($user.mobilePhone) { $user.mobilePhone } else { '' }

        [PSCustomObject]@{
            DisplayName  = $user.displayName
            Email        = $user.userPrincipalName
            Title        = $title
            Manager      = $managerName
            Office       = $office
            Mobile       = $mobile
            Status       = $status
            'Last Login' = $lastLogin
            Licenses     = $licenseNames
            MFA          = $mfaStatus
        }
    }

    # Create table with specific column order
    $table = New-ADFTable -InputObject $tableData -Property DisplayName, Email, Title, Manager, Office, Mobile, Status, 'Last Login', Licenses, MFA

    # Assemble document
    $doc = Add-ADFContent -Document $doc -Content @($heading, $timestamp, $table)

    Write-Verbose "Created user page with $($regularUsers.Count) user(s)"
    return ConvertTo-ADF -InputObject $doc
}
