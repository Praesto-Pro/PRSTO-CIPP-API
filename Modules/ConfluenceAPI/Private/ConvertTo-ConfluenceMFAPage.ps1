function ConvertTo-ConfluenceMFAPage {
    <#
    .SYNOPSIS
        Transforms CIPP MFA status data into ADF content for Confluence pages.
    .DESCRIPTION
        Converts CIPP MFA report objects into Atlassian Document Format (ADF) content
        suitable for creating/updating Confluence pages. Displays MFA status summary
        with coverage statistics and per-user MFA details.

        The function:
        - Creates a summary section with total users, MFA-enabled count, and percentage
        - Creates a table showing each user's MFA status, methods, and coverage
        - Adds a timestamp for data freshness (FR44)

        Returns an ADF JSON string that can be used directly with
        New-ConfluencePage -Body parameter.
    .PARAMETER MFAData
        Array of CIPP MFA report objects from the MFA Report API.
        Expected properties: userPrincipalName, displayName, isMfaRegistered,
        perUserMfaState, isSecurityDefaultsCovered, isConditionalAccessCovered,
        authenticationMethods (or methodsRegistered).
    .OUTPUTS
        [string] - ADF JSON string ready for Confluence API
        Table columns: User, MFA Status, MFA Methods, Per-User MFA,
        Security Defaults, Conditional Access
    .EXAMPLE
        $adf = ConvertTo-ConfluenceMFAPage -MFAData $cippMfaReport

        Creates ADF content with MFA status table.
    .EXAMPLE
        $body = ConvertTo-ConfluenceMFAPage -MFAData $mfaData
        New-ConfluencePage -SpaceKey 'CLIENT' -Title 'MFA Status' -Body $body

        Creates a Confluence page with MFA status report.
    .NOTES
        This is a private function used internally by the ConfluenceAPI module.
        Part of Story 6.1 - MFA Status Transformer & Sync.

        CIPP Data Source:
        - MFAData: CIPP MFA Report API
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
        [object[]]$MFAData
    )

    # Handle empty/null input first
    if (-not $MFAData -or $MFAData.Count -eq 0) {
        Write-Verbose "No MFA data provided - returning empty state message"
        $doc = New-ADFDocument
        $heading = New-ADFHeading -Level 2 -Text 'MFA Status Report'
        # Add timestamp even for empty state (FR44 compliance)
        $utcTime = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm')
        $timestamp = New-ADFParagraph -Text "Data as of: $utcTime UTC"
        $message = New-ADFParagraph -Text 'No MFA data available'
        $doc = Add-ADFContent -Document $doc -Content @($heading, $timestamp, $message)
        return ConvertTo-ADF -InputObject $doc
    }

    Write-Verbose "Transforming $($MFAData.Count) user MFA record(s) to ADF content"

    # Create ADF document
    $doc = New-ADFDocument

    # Add heading
    $heading = New-ADFHeading -Level 2 -Text 'MFA Status Report'

    # Add timestamp (FR44) - use actual UTC time
    $utcTime = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm')
    $timestamp = New-ADFParagraph -Text "Data as of: $utcTime UTC"

    # Calculate MFA coverage summary
    $totalUsers = $MFAData.Count
    $mfaEnabledCount = @($MFAData | Where-Object {
        $_.isMfaRegistered -or
        $_.perUserMfaState -in @('enabled', 'enforced') -or
        $_.isSecurityDefaultsCovered -or
        $_.isConditionalAccessCovered
    }).Count
    $percentage = if ($totalUsers -gt 0) {
        [math]::Round(($mfaEnabledCount / $totalUsers) * 100, 1)
    } else {
        0
    }

    Write-Verbose "MFA coverage: $mfaEnabledCount of $totalUsers users ($percentage%)"

    # Generate summary paragraph
    $summaryText = "MFA Coverage: $mfaEnabledCount of $totalUsers users ($percentage%) protected by MFA"
    $summary = New-ADFParagraph -Text $summaryText

    # Transform to table format
    $tableData = foreach ($user in $MFAData) {
        # Determine display name with fallbacks
        $displayName = if ($user.displayName) {
            $user.displayName
        } elseif ($user.userPrincipalName) {
            $user.userPrincipalName
        } else {
            'Unknown User'
        }

        # Determine overall MFA status for display
        $mfaStatus = if ($user.perUserMfaState -and $user.perUserMfaState.ToLower() -eq 'enforced') {
            'Enforced'
        } elseif (($user.perUserMfaState -and $user.perUserMfaState.ToLower() -eq 'enabled') -or $user.isMfaRegistered) {
            'Enabled'
        } elseif ($user.isSecurityDefaultsCovered -or $user.isConditionalAccessCovered) {
            'Protected (Policy)'
        } else {
            'Disabled'
        }

        # Convert authentication methods array to readable display
        $methods = if ($user.authenticationMethods) {
            $user.authenticationMethods
        } elseif ($user.methodsRegistered) {
            $user.methodsRegistered
        } else {
            @()
        }

        $methodsDisplay = if ($methods -and $methods.Count -gt 0) {
            $friendlyNames = @($methods | ForEach-Object {
                $method = $_.ToString().ToLower()
                switch ($method) {
                    'microsoftauthenticator' { 'Authenticator App' }
                    'microsoftauthenticatorpush' { 'Authenticator App' }
                    'phone' { 'Phone' }
                    'mobilephone' { 'Phone' }
                    'sms' { 'SMS' }
                    'fido2' { 'Security Key' }
                    'windowshelloforbusiness' { 'Windows Hello' }
                    'softwareoath' { 'TOTP App' }
                    'email' { 'Email' }
                    default { $_ }
                }
            } | Select-Object -Unique)
            $friendlyNames -join ', '
        } else {
            'None'
        }

        # Per-User MFA state display
        $perUserDisplay = if ($user.perUserMfaState) {
            # Capitalize first letter
            $state = $user.perUserMfaState.ToString()
            $state.Substring(0, 1).ToUpper() + $state.Substring(1).ToLower()
        } else {
            'N/A'
        }

        # Security Defaults and Conditional Access coverage
        $sdCovered = if ($user.isSecurityDefaultsCovered) { 'Yes' } else { 'No' }
        $caCovered = if ($user.isConditionalAccessCovered) { 'Yes' } else { 'No' }

        [PSCustomObject]@{
            'User'               = $displayName
            'MFA Status'         = $mfaStatus
            'MFA Methods'        = $methodsDisplay
            'Per-User MFA'       = $perUserDisplay
            'Security Defaults'  = $sdCovered
            'Conditional Access' = $caCovered
        }
    }

    # Create table
    $table = New-ADFTable -InputObject $tableData -Property 'User', 'MFA Status', 'MFA Methods', 'Per-User MFA', 'Security Defaults', 'Conditional Access'

    # Assemble document
    $doc = Add-ADFContent -Document $doc -Content @($heading, $timestamp, $summary, $table)

    Write-Verbose "Created MFA status page with $totalUsers user(s)"
    return ConvertTo-ADF -InputObject $doc
}
