function ConvertTo-ConfluenceEndpointPage {
    <#
    .SYNOPSIS
        Transforms CIPP endpoint data into ADF content for Confluence pages.
    .DESCRIPTION
        Converts CIPP endpoint objects (from Intune/Graph API) into Atlassian Document
        Format (ADF) content suitable for creating/updating Confluence pages. Displays
        device inventory including compliance status and user assignment.

        The function:
        - Maps device properties to readable column names
        - Converts compliance states to user-friendly labels
        - Shows assigned user with fallback logic
        - Adds a timestamp for data freshness (FR44)

        Returns an ADF JSON string that can be used directly with
        New-ConfluencePage -Body parameter.
    .PARAMETER Endpoints
        Array of CIPP endpoint objects from Intune/Graph API.
        Expected properties: deviceName, operatingSystem, complianceState,
        lastSyncDateTime, userPrincipalName, userDisplayName.
    .PARAMETER Property
        Optional array of column names to include in the table.
        Valid values: 'Device Name', 'OS', 'Compliance', 'Assigned User', 'Last Sync'
        Defaults to all columns if not specified.
    .OUTPUTS
        [string] - ADF JSON string ready for Confluence API
        Table columns (default): Device Name, OS, Compliance, Assigned User, Last Sync
    .EXAMPLE
        $adf = ConvertTo-ConfluenceEndpointPage -Endpoints $cippEndpoints

        Creates ADF content from endpoint data.
    .EXAMPLE
        $body = ConvertTo-ConfluenceEndpointPage -Endpoints $endpoints
        New-ConfluencePage -SpaceKey 'CLIENT' -Title 'Endpoint Inventory' -Body $body

        Creates a Confluence page with endpoint inventory table.
    .NOTES
        This is a private function used internally by the ConfluenceAPI module.
        Part of Story 5.1 - Endpoint Data Transformer.

        CIPP Data Source: Intune devices via Graph API

        Compliance State Mappings:
        - compliant     -> Compliant
        - noncompliant  -> Non-Compliant
        - inGracePeriod -> In Grace Period
        - configmanager -> Config Manager
        - unknown/null  -> Unknown
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
        [object[]]$Endpoints,

        [Parameter()]
        [ValidateSet('Device Name', 'OS', 'Compliance', 'Assigned User', 'Last Sync')]
        [string[]]$Property
    )

    # Default columns if not specified
    $defaultColumns = @('Device Name', 'OS', 'Compliance', 'Assigned User', 'Last Sync')
    if (-not $Property) {
        $Property = $defaultColumns
    }

    # Handle empty/null input first
    if (-not $Endpoints -or $Endpoints.Count -eq 0) {
        Write-Verbose "No endpoints provided - returning empty state message"
        $doc = New-ADFDocument
        $heading = New-ADFHeading -Level 2 -Text 'Endpoint Inventory'
        $message = New-ADFParagraph -Text 'No endpoint data available'
        $doc = Add-ADFContent -Document $doc -Content @($heading, $message)
        return ConvertTo-ADF -InputObject $doc
    }

    Write-Verbose "Transforming $($Endpoints.Count) endpoint(s) to ADF content"

    # Create ADF document
    $doc = New-ADFDocument

    # Add heading
    $heading = New-ADFHeading -Level 2 -Text 'Endpoint Inventory'

    # Add timestamp (FR44) - use actual UTC time
    $utcTime = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm')
    $timestamp = New-ADFParagraph -Text "Data as of: $utcTime UTC"

    # Transform endpoints to table data
    $tableData = foreach ($endpoint in $Endpoints) {
        # Compliance status mapping (AC5) - case-insensitive
        $complianceDisplay = 'Unknown'
        if ($endpoint.complianceState) {
            $complianceDisplay = switch ($endpoint.complianceState.ToLower()) {
                'compliant' { 'Compliant' }
                'noncompliant' { 'Non-Compliant' }
                'ingraceperiod' { 'In Grace Period' }
                'configmanager' { 'Config Manager' }
                'unknown' { 'Unknown' }
                default { 'Unknown' }
            }
        }

        # User assignment display (AC3)
        $assignedUser = 'Unassigned'
        if ($endpoint.userDisplayName) {
            $assignedUser = $endpoint.userDisplayName
        }
        elseif ($endpoint.userPrincipalName) {
            $assignedUser = $endpoint.userPrincipalName
        }

        # Last sync with fallback
        $lastSync = 'Never'
        if ($endpoint.lastSyncDateTime) {
            $lastSync = $endpoint.lastSyncDateTime
        }

        [PSCustomObject]@{
            'Device Name'   = if ($endpoint.deviceName) { $endpoint.deviceName } else { '' }
            'OS'            = if ($endpoint.operatingSystem) { $endpoint.operatingSystem } else { '' }
            'Compliance'    = $complianceDisplay
            'Assigned User' = $assignedUser
            'Last Sync'     = $lastSync
        }
    }

    # Create table with specified columns (or default all)
    $table = New-ADFTable -InputObject $tableData -Property $Property

    # Assemble document
    $doc = Add-ADFContent -Document $doc -Content @($heading, $timestamp, $table)

    Write-Verbose "Created endpoint page with $($Endpoints.Count) device(s)"
    return ConvertTo-ADF -InputObject $doc
}
