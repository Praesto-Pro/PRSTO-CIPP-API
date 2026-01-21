function ConvertTo-ConfluenceSaaSPage {
    <#
    .SYNOPSIS
        Transforms CIPP service principal data into ADF content for Third-Party SaaS Applications page.
    .DESCRIPTION
        Converts CIPP service principal (enterprise application) data into Atlassian Document Format (ADF)
        content suitable for creating/updating Confluence pages. Automatically filters out Microsoft
        built-in applications to show only third-party SaaS applications.

        The function:
        - Filters out Microsoft applications by:
          * appOwnerOrganizationId = f8cdef31-a31e-4b4a-93e4-5f571e91255a
          * Publishers: "Microsoft", "Microsoft Accounts"
          * App names: "Azure Media Service", "Management Object-1573247360274"
        - Creates a summary section with total third-party app count
        - Creates a table showing each app's details
        - Optionally shows credential expiry warnings
        - Adds a timestamp for data freshness (FR44)

        Returns an ADF JSON string that can be used directly with
        New-ConfluencePage -Body parameter.
    .PARAMETER ServicePrincipals
        Array of CIPP service principal objects from the Graph API.
        Expected properties: id, appId, displayName, createdDateTime, accountEnabled,
        publisherName, signInAudience, appOwnerOrganizationId, verifiedPublisher,
        passwordCredentials, keyCredentials.
    .PARAMETER IncludeMicrosoftApps
        Switch to include Microsoft apps in the output. By default, Microsoft apps
        are filtered out.
    .OUTPUTS
        [string] - ADF JSON string ready for Confluence API
        Table columns: #, Application, Publisher, Status, Sign-In Audience, Created
    .EXAMPLE
        $adf = ConvertTo-ConfluenceSaaSPage -ServicePrincipals $cippServicePrincipals

        Creates ADF content with third-party SaaS applications table (Microsoft apps filtered out).
    .EXAMPLE
        $adf = ConvertTo-ConfluenceSaaSPage -ServicePrincipals $apps -IncludeMicrosoftApps

        Creates ADF content including Microsoft apps.
    .NOTES
        This is a private function used internally by the ConfluenceAPI module.
        Part of Third-Party SaaS Applications Sync feature.

        Microsoft Tenant ID: f8cdef31-a31e-4b4a-93e4-5f571e91255a
        Apps with this appOwnerOrganizationId are Microsoft built-in apps.

        CIPP Data Source:
        - ServicePrincipals: Graph API /beta/servicePrincipals endpoint
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
        [object[]]$ServicePrincipals,

        [Parameter()]
        [switch]$IncludeMicrosoftApps
    )

    # Microsoft's tenant ID - used to filter out built-in Microsoft apps
    $MicrosoftTenantId = 'f8cdef31-a31e-4b4a-93e4-5f571e91255a'

    # Publishers to exclude (Microsoft-related)
    $ExcludedPublishers = @(
        'Microsoft'
        'Microsoft Accounts'
    )

    # Specific application names to exclude
    $ExcludedAppNames = @(
        'Azure Media Service'
        'Management Object-1573247360274'
    )

    # Handle empty/null input first
    if (-not $ServicePrincipals -or $ServicePrincipals.Count -eq 0) {
        Write-Verbose "No service principal data provided - returning empty state message"
        $doc = New-ADFDocument
        $heading = New-ADFHeading -Level 2 -Text 'Third-Party SaaS Applications'
        # Add timestamp even for empty state (FR44 compliance)
        $utcTime = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm')
        $timestamp = New-ADFParagraph -Text "Data as of: $utcTime UTC"
        $message = New-ADFParagraph -Text 'No service principal data available'
        $doc = Add-ADFContent -Document $doc -Content @($heading, $timestamp, $message)
        return ConvertTo-ADF -InputObject $doc
    }

    # Filter out Microsoft apps unless explicitly included
    if (-not $IncludeMicrosoftApps) {
        $filteredApps = $ServicePrincipals | Where-Object {
            # Filter by Microsoft tenant ID
            $_.appOwnerOrganizationId -ne $MicrosoftTenantId -and
            # Filter by publisher name
            $_.publisherName -notin $ExcludedPublishers -and
            (-not $_.verifiedPublisher -or $_.verifiedPublisher.displayName -notin $ExcludedPublishers) -and
            # Filter by specific app names
            $_.displayName -notin $ExcludedAppNames
        }
        Write-Verbose "Filtered from $($ServicePrincipals.Count) to $($filteredApps.Count) apps (excluded Microsoft apps)"
    }
    else {
        $filteredApps = $ServicePrincipals
        Write-Verbose "Including all $($ServicePrincipals.Count) apps (Microsoft apps included)"
    }

    # Handle case where all apps were Microsoft apps
    if (-not $filteredApps -or $filteredApps.Count -eq 0) {
        Write-Verbose "No third-party apps found after filtering - returning empty state message"
        $doc = New-ADFDocument
        $heading = New-ADFHeading -Level 2 -Text 'Third-Party SaaS Applications'
        $utcTime = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm')
        $timestamp = New-ADFParagraph -Text "Data as of: $utcTime UTC"
        $message = New-ADFParagraph -Text 'No third-party SaaS applications found (Microsoft built-in apps excluded)'
        $doc = Add-ADFContent -Document $doc -Content @($heading, $timestamp, $message)
        return ConvertTo-ADF -InputObject $doc
    }

    Write-Verbose "Transforming $($filteredApps.Count) third-party app record(s) to ADF content"

    # Create ADF document
    $doc = New-ADFDocument

    # Add heading
    $heading = New-ADFHeading -Level 2 -Text 'Third-Party SaaS Applications'

    # Add timestamp (FR44) - use actual UTC time
    $utcTime = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm')
    $timestamp = New-ADFParagraph -Text "Data as of: $utcTime UTC"

    # Calculate summary statistics
    $totalApps = $filteredApps.Count
    $enabledApps = ($filteredApps | Where-Object { $_.accountEnabled -eq $true }).Count
    $disabledApps = $totalApps - $enabledApps

    # Count apps with credentials (potential security concern)
    $appsWithCredentials = ($filteredApps | Where-Object {
        ($_.passwordCredentials -and $_.passwordCredentials.Count -gt 0) -or
        ($_.keyCredentials -and $_.keyCredentials.Count -gt 0)
    }).Count

    Write-Verbose "SaaS apps: $totalApps total, $enabledApps enabled, $disabledApps disabled, $appsWithCredentials with credentials"

    # Generate summary paragraph
    $summaryParts = @("Total Third-Party Apps: $totalApps")
    if ($enabledApps -gt 0) { $summaryParts += "Enabled: $enabledApps" }
    if ($disabledApps -gt 0) { $summaryParts += "Disabled: $disabledApps" }
    $summaryText = $summaryParts -join ' | '
    $summary = New-ADFParagraph -Text $summaryText

    # Sort apps by display name for consistent ordering
    $sortedApps = $filteredApps | Sort-Object -Property displayName

    # Transform to table format with serial number
    $serial = 0
    $tableData = foreach ($app in $sortedApps) {
        $serial++

        # Determine display name with fallbacks
        $appName = if ($app.displayName) {
            $app.displayName
        }
        elseif ($app.appDisplayName) {
            $app.appDisplayName
        }
        elseif ($app.appId) {
            $app.appId
        }
        else {
            'Unknown App'
        }

        # Determine publisher with fallbacks
        $publisher = if ($app.verifiedPublisher -and $app.verifiedPublisher.displayName) {
            $app.verifiedPublisher.displayName
        }
        elseif ($app.publisherName) {
            $app.publisherName
        }
        else {
            'Unknown'
        }

        # Determine status
        $status = if ($null -eq $app.accountEnabled) {
            'Unknown'
        }
        elseif ($app.accountEnabled -eq $true) {
            'Enabled'
        }
        else {
            'Disabled'
        }

        # Format sign-in audience for readability
        $audience = switch ($app.signInAudience) {
            'AzureADMyOrg' { 'Single Tenant' }
            'AzureADMultipleOrgs' { 'Multi-Tenant' }
            'AzureADandPersonalMicrosoftAccount' { 'Multi-Tenant + Personal' }
            'PersonalMicrosoftAccount' { 'Personal Only' }
            default { if ($app.signInAudience) { $app.signInAudience } else { 'Unknown' } }
        }

        # Format created date
        $created = if ($app.createdDateTime) {
            try {
                ([DateTime]$app.createdDateTime).ToString('yyyy-MM-dd')
            }
            catch {
                $app.createdDateTime
            }
        }
        else {
            'Unknown'
        }

        [PSCustomObject]@{
            '#'           = $serial
            'Application' = $appName
            'Publisher'   = $publisher
            'Status'      = $status
            'Audience'    = $audience
            'Created'     = $created
        }
    }

    # Create table
    $table = New-ADFTable -InputObject $tableData -Property '#', 'Application', 'Publisher', 'Status', 'Audience', 'Created'

    # Assemble document
    $doc = Add-ADFContent -Document $doc -Content @($heading, $timestamp, $summary, $table)

    Write-Verbose "Created Third-Party SaaS Applications page with $totalApps app(s)"
    return ConvertTo-ADF -InputObject $doc
}
