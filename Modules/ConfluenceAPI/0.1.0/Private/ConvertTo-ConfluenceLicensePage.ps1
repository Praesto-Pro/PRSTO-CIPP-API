function ConvertTo-ConfluenceLicensePage {
    <#
    .SYNOPSIS
        Transforms CIPP license data into ADF content for Confluence pages.
    .DESCRIPTION
        Converts CIPP license inventory objects into Atlassian Document Format (ADF) content
        suitable for creating/updating Confluence pages. Displays license summary with
        quantities and optionally user assignments.

        The function:
        - Creates a summary table with License Name, Total, Used, Available
        - Optionally creates an assignments table showing user-to-license mapping
        - Adds a timestamp for data freshness (FR44)

        Returns an ADF JSON string that can be used directly with
        New-ConfluencePage -Body parameter.
    .PARAMETER Licenses
        Array of CIPP license inventory objects from ListLicenses API.
        Expected properties: skuId, skuPartNumber, prepaidUnits, consumedUnits.
    .PARAMETER Users
        Optional array of CIPP user objects with assignedLicenses for
        generating the license assignments table.
    .OUTPUTS
        [string] - ADF JSON string ready for Confluence API
        Summary table columns: License Name, Total, Used, Available
        Assignments table columns (if Users provided): User, License
    .EXAMPLE
        $adf = ConvertTo-ConfluenceLicensePage -Licenses $cippLicenses

        Creates ADF content with license summary table only.
    .EXAMPLE
        $adf = ConvertTo-ConfluenceLicensePage -Licenses $licenses -Users $users

        Creates ADF content with both license summary and assignments tables.
    .EXAMPLE
        $body = ConvertTo-ConfluenceLicensePage -Licenses $licenses
        New-ConfluencePage -SpaceKey 'CLIENT' -Title 'License Report' -Body $body

        Creates a Confluence page with license report.
    .NOTES
        This is a private function used internally by the ConfluenceAPI module.
        Part of Story 5.3 - License Data Transformer.

        CIPP Data Sources:
        - Licenses: ListLicenses API
        - Users: ListGraphRequest API (for assignments)
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
        [object[]]$Licenses,

        [Parameter()]
        [object[]]$Users
    )

    # Handle empty/null input first
    if (-not $Licenses -or $Licenses.Count -eq 0) {
        Write-Verbose "No licenses provided - returning empty state message"
        $doc = New-ADFDocument
        $heading = New-ADFHeading -Level 2 -Text 'License Report'
        # Add timestamp even for empty state (FR44 compliance)
        $utcTime = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm')
        $timestamp = New-ADFParagraph -Text "Data as of: $utcTime UTC"
        $message = New-ADFParagraph -Text 'No license data available'
        $doc = Add-ADFContent -Document $doc -Content @($heading, $timestamp, $message)
        return ConvertTo-ADF -InputObject $doc
    }

    Write-Verbose "Transforming $($Licenses.Count) license type(s) to ADF content"

    # Load conversion table once for license name normalization
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

    # Create ADF document
    $doc = New-ADFDocument

    # Add heading
    $heading = New-ADFHeading -Level 2 -Text 'License Report'

    # Add timestamp (FR44) - use actual UTC time
    $utcTime = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm')
    $timestamp = New-ADFParagraph -Text "Data as of: $utcTime UTC"

    # Transform licenses to summary table data
    $summaryData = foreach ($license in $Licenses) {
        # Get quantities with null protection
        $total = 0
        if ($license.prepaidUnits -and $license.prepaidUnits.enabled) {
            $total = [int]$license.prepaidUnits.enabled
        }
        $used = if ($license.consumedUnits) { [int]$license.consumedUnits } else { 0 }

        # Calculate available (min 0 for over-allocation)
        $available = [Math]::Max(0, $total - $used)

        # Normalize license name using conversion table
        $licenseName = 'Unknown'
        if ($license.skuPartNumber) {
            $licenseName = $license.skuPartNumber
            # Try to get friendly name from conversion table
            if ($ConvertTable) {
                $friendlyName = ($ConvertTable | Where-Object { $_.String_Id -eq $license.skuPartNumber } | Select-Object -First 1).'Product_Display_Name'
                if (-not $friendlyName -and $license.skuId) {
                    $friendlyName = ($ConvertTable | Where-Object { $_.GUID -eq $license.skuId } | Select-Object -First 1).'Product_Display_Name'
                }
                if ($friendlyName) {
                    $licenseName = $friendlyName
                }
            }
        }

        [PSCustomObject]@{
            'License Name' = $licenseName
            'Total'        = $total
            'Used'         = $used
            'Available'    = $available
        }
    }

    # Create summary table
    $summaryTable = New-ADFTable -InputObject $summaryData -Property 'License Name', 'Total', 'Used', 'Available'

    # Assemble content - start with heading, timestamp, summary
    $contentItems = @($heading, $timestamp, $summaryTable)

    # Add assignments table if Users provided
    if ($Users -and $Users.Count -gt 0) {
        Write-Verbose "Processing $($Users.Count) user(s) for license assignments"

        # Build license lookup for name resolution (using normalized names)
        $licenseLookup = @{}
        foreach ($lic in $Licenses) {
            if ($lic.skuId) {
                # Use normalized name if available
                $lookupName = if ($lic.skuPartNumber) { $lic.skuPartNumber } else { $lic.skuId }
                if ($ConvertTable) {
                    $friendlyName = ($ConvertTable | Where-Object { $_.String_Id -eq $lic.skuPartNumber } | Select-Object -First 1).'Product_Display_Name'
                    if (-not $friendlyName) {
                        $friendlyName = ($ConvertTable | Where-Object { $_.GUID -eq $lic.skuId } | Select-Object -First 1).'Product_Display_Name'
                    }
                    if ($friendlyName) {
                        $lookupName = $friendlyName
                    }
                }
                $licenseLookup[$lic.skuId] = $lookupName
            }
        }

        # Build assignments data - one row per user with all licenses combined
        $assignmentsData = @($Users | Sort-Object -Property displayName | ForEach-Object {
            $user = $_
            if ($user.assignedLicenses -and $user.assignedLicenses.Count -gt 0) {
                # Collect all license names for this user
                $userLicenses = @()
                foreach ($assigned in $user.assignedLicenses) {
                    $skuId = $assigned.skuId
                    $licenseName = if ($skuId -and $licenseLookup.ContainsKey($skuId)) {
                        $licenseLookup[$skuId]
                    } elseif ($skuId -and $ConvertTable) {
                        # Try to resolve unknown SKU from conversion table
                        $friendlyName = ($ConvertTable | Where-Object { $_.GUID -eq $skuId } | Select-Object -First 1).'Product_Display_Name'
                        if ($friendlyName) { $friendlyName } else { $skuId.Substring(0, [Math]::Min(8, $skuId.Length)) + '...' }
                    } elseif ($skuId) {
                        $skuId.Substring(0, [Math]::Min(8, $skuId.Length)) + '...'
                    } else {
                        'Unknown'
                    }
                    $userLicenses += $licenseName
                }

                # Determine user display with fallbacks
                $userDisplay = if ($user.displayName) {
                    $user.displayName
                } elseif ($user.userPrincipalName) {
                    $user.userPrincipalName
                } else {
                    'Unknown User'
                }

                # Output single row with all licenses joined
                [PSCustomObject]@{
                    'User'     = $userDisplay
                    'Licenses' = ($userLicenses | Sort-Object) -join ', '
                }
            }
        })

        if ($assignmentsData.Count -gt 0) {
            $assignmentsHeading = New-ADFHeading -Level 3 -Text 'License Assignments'
            $assignmentsTable = New-ADFTable -InputObject $assignmentsData -Property 'User', 'Licenses'
            $contentItems += @($assignmentsHeading, $assignmentsTable)
            Write-Verbose "Created assignments table with $($assignmentsData.Count) user(s)"
        }
    }

    # Assemble document
    $doc = Add-ADFContent -Document $doc -Content $contentItems

    Write-Verbose "Created license page with $($Licenses.Count) license type(s)"
    return ConvertTo-ADF -InputObject $doc
}
