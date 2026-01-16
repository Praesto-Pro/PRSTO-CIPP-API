function ConvertTo-ConfluenceEndpointPage {
    <#
    .SYNOPSIS
        Transforms CIPP endpoint data into ADF content for Confluence pages.
    .DESCRIPTION
        Converts CIPP endpoint objects (from Intune managedDevices API) into Atlassian Document
        Format (ADF) content suitable for creating/updating Confluence pages. Displays
        device inventory including compliance status, OS details, and user assignment.

        The function:
        - Maps device properties to readable column names
        - Converts compliance states to user-friendly labels
        - Shows OS with version information
        - Formats dates for readability
        - Adds a timestamp for data freshness (FR44)

        Returns an ADF JSON string that can be used directly with
        New-ConfluencePage -Body parameter.
    .PARAMETER Endpoints
        Array of CIPP endpoint objects from Intune managedDevices API.
        Expected properties: deviceName, userDisplayName, userPrincipalName,
        operatingSystem, osVersion, complianceState, lastSyncDateTime,
        enrolledDateTime, model, manufacturer, serialNumber,
        managedDeviceOwnerType, joinType.
    .OUTPUTS
        [string] - ADF JSON string ready for Confluence API
        Table columns: Device, User, OS, Compliance, Ownership, Join Type, Model, Last Sync
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

        CIPP Data Source: Intune managedDevices via Graph API beta

        Compliance State Mappings:
        - compliant     -> Compliant
        - noncompliant  -> Non-Compliant
        - inGracePeriod -> Grace Period
        - configmanager -> ConfigMgr
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
        [object[]]$Endpoints
    )

    # Handle empty/null input first
    if (-not $Endpoints -or $Endpoints.Count -eq 0) {
        Write-Verbose "No endpoints provided - returning empty state message"
        $doc = New-ADFDocument
        $heading = New-ADFHeading -Level 2 -Text 'Endpoint Inventory'
        # Add timestamp even for empty state (FR44 compliance)
        $utcTime = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm')
        $timestamp = New-ADFParagraph -Text "Data as of: $utcTime UTC"
        $message = New-ADFParagraph -Text 'No endpoint data available'
        $doc = Add-ADFContent -Document $doc -Content @($heading, $timestamp, $message)
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

    # Generate summary
    $totalDevices = $Endpoints.Count
    $compliantCount = @($Endpoints | Where-Object { $_.complianceState -eq 'compliant' }).Count
    $compliancePercent = if ($totalDevices -gt 0) { [math]::Round(($compliantCount / $totalDevices) * 100, 1) } else { 0 }
    $summaryText = "Total Devices: $totalDevices | Compliant: $compliantCount ($compliancePercent%)"
    $summary = New-ADFParagraph -Text $summaryText

    # Transform endpoints to table data
    $tableData = foreach ($endpoint in $Endpoints) {
        # Device name
        $deviceName = if ($endpoint.deviceName) { $endpoint.deviceName } else { 'Unknown' }

        # User assignment display
        $assignedUser = if ($endpoint.userDisplayName) {
            $endpoint.userDisplayName
        }
        elseif ($endpoint.userPrincipalName) {
            $endpoint.userPrincipalName
        }
        else {
            'Unassigned'
        }

        # OS with version - use non-breaking space to prevent wrapping
        $osDisplay = if ($endpoint.operatingSystem) {
            $os = $endpoint.operatingSystem
            if ($endpoint.osVersion) {
                # Use non-breaking space between OS and version to prevent wrapping
                "$os`u{00A0}$($endpoint.osVersion)"
            }
            else {
                $os
            }
        }
        else {
            'Unknown'
        }

        # Compliance status mapping - case-insensitive
        $complianceDisplay = 'Unknown'
        if ($endpoint.complianceState) {
            $complianceDisplay = switch ($endpoint.complianceState.ToLower()) {
                'compliant' { 'Compliant' }
                'noncompliant' { 'Non-Compliant' }
                'ingraceperiod' { 'Grace Period' }
                'configmanager' { 'ConfigMgr' }
                'unknown' { 'Unknown' }
                default { $endpoint.complianceState }
            }
        }

        # Ownership (managedDeviceOwnerType) - Personal vs Corporate
        $ownership = if ($endpoint.managedDeviceOwnerType) {
            switch ($endpoint.managedDeviceOwnerType.ToLower()) {
                'company' { 'Corporate' }
                'personal' { 'Personal' }
                default { $endpoint.managedDeviceOwnerType }
            }
        }
        else {
            'Unknown'
        }

        # Join Type (joinType or derived from other properties)
        $joinType = if ($endpoint.joinType) {
            switch ($endpoint.joinType.ToLower()) {
                'azureadjoined' { 'Azure AD Joined' }
                'azureadregistered' { 'Azure AD Registered' }
                'hybridazureadjoined' { 'Hybrid Joined' }
                default { $endpoint.joinType }
            }
        }
        elseif ($endpoint.azureADRegistered -eq $true -and $endpoint.azureADDeviceId) {
            # Fallback: determine from registration state
            'Azure AD Registered'
        }
        else {
            ''
        }

        # Model (manufacturer + model if both available)
        $modelDisplay = if ($endpoint.model) {
            if ($endpoint.manufacturer -and $endpoint.manufacturer -ne 'Unknown') {
                "$($endpoint.manufacturer) $($endpoint.model)"
            }
            else {
                $endpoint.model
            }
        }
        else {
            ''
        }

        # Last sync - format as date only
        $lastSync = ''
        if ($endpoint.lastSyncDateTime) {
            try {
                $lastSync = ([DateTime]$endpoint.lastSyncDateTime).ToString('yyyy-MM-dd')
            }
            catch {
                $lastSync = $endpoint.lastSyncDateTime.ToString().Substring(0, 10)
            }
        }

        [PSCustomObject]@{
            'Device'     = $deviceName
            'User'       = $assignedUser
            'OS'         = $osDisplay
            'Compliance' = $complianceDisplay
            'Ownership'  = $ownership
            'Join Type'  = $joinType
            'Model'      = $modelDisplay
            'Last Sync'  = $lastSync
        }
    }

    # Create table with all columns
    $table = New-ADFTable -InputObject $tableData -Property 'Device', 'User', 'OS', 'Compliance', 'Ownership', 'Join Type', 'Model', 'Last Sync'

    # Assemble document
    $doc = Add-ADFContent -Document $doc -Content @($heading, $timestamp, $summary, $table)

    Write-Verbose "Created endpoint page with $($Endpoints.Count) device(s)"
    return ConvertTo-ADF -InputObject $doc
}
