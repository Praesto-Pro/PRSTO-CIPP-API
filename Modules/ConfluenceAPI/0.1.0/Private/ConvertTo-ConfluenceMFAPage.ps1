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
        Array of CIPP MFA report objects from Get-CIPPMFAState.
        Expected properties: UPN, DisplayName, MFARegistration (boolean),
        PerUser (state string), MFAMethods (array), CoveredBySD (boolean),
        CoveredByCA (string like "Enforced - All Apps" or "Not Enforced").
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
    # CIPP properties: MFARegistration (bool), PerUser (state), CoveredBySD (bool), CoveredByCA (string)
    $totalUsers = $MFAData.Count
    $mfaEnabledCount = @($MFAData | Where-Object {
        $_.MFARegistration -eq $true -or
        $_.PerUser -in @('enabled', 'enforced') -or
        $_.CoveredBySD -eq $true -or
        ($_.CoveredByCA -and $_.CoveredByCA -like 'Enforced*')
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
    # CIPP properties: UPN, DisplayName, MFARegistration, PerUser, MFAMethods, CoveredBySD, CoveredByCA
    $tableData = foreach ($user in $MFAData) {
        # Determine display name with fallbacks (CIPP uses DisplayName and UPN)
        $displayName = if ($user.DisplayName) {
            $user.DisplayName
        } elseif ($user.UPN) {
            $user.UPN
        } else {
            'Unknown User'
        }

        # Determine overall MFA status for display
        # CIPP: PerUser (state string), MFARegistration (bool), CoveredBySD (bool), CoveredByCA (string)
        $mfaStatus = if ($user.PerUser -and $user.PerUser.ToLower() -eq 'enforced') {
            'Enforced'
        } elseif (($user.PerUser -and $user.PerUser.ToLower() -eq 'enabled') -or $user.MFARegistration -eq $true) {
            'Enabled'
        } elseif ($user.CoveredBySD -eq $true -or ($user.CoveredByCA -and $user.CoveredByCA -like 'Enforced*')) {
            'Protected (Policy)'
        } else {
            'Disabled'
        }

        # Convert MFA methods array to readable display (CIPP uses MFAMethods)
        $methods = if ($user.MFAMethods) {
            $user.MFAMethods
        } else {
            @()
        }

        $methodsDisplay = if ($methods -and $methods.Count -gt 0) {
            $friendlyNames = @($methods | ForEach-Object {
                $method = $_.ToString().ToLower()
                switch ($method) {
                    'microsoftauthenticatorpush' { 'Authenticator App' }
                    'microsoftauthenticatorpasswordless' { 'Authenticator Passwordless' }
                    'microsoftauthenticator' { 'Authenticator App' }
                    'phonevoice' { 'Phone (Voice)' }
                    'phoneotp' { 'Phone (OTP)' }
                    'phone' { 'Phone' }
                    'mobilephone' { 'Phone' }
                    'sms' { 'SMS' }
                    'fido2' { 'Security Key' }
                    'windowshelloforbusiness' { 'Windows Hello' }
                    'softwareoath' { 'TOTP App' }
                    'email' { 'Email' }
                    'passkeymicrosoftauthenticator' { 'Passkey (Authenticator)' }
                    'passkey' { 'Passkey' }
                    default { $_ }
                }
            } | Select-Object -Unique)
            $friendlyNames -join ', '
        } else {
            'None'
        }

        # Per-User MFA state display (CIPP uses PerUser)
        $perUserDisplay = if ($user.PerUser) {
            # Capitalize first letter
            $state = $user.PerUser.ToString()
            if ($state.Length -gt 0) {
                $state.Substring(0, 1).ToUpper() + $state.Substring(1).ToLower()
            } else {
                'N/A'
            }
        } else {
            'N/A'
        }

        # Security Defaults coverage (CIPP uses CoveredBySD - boolean)
        $sdCovered = if ($user.CoveredBySD -eq $true) { 'Yes' } else { 'No' }

        # Conditional Access coverage (CIPP uses CoveredByCA - string like "Enforced - All Apps")
        $caCovered = if ($user.CoveredByCA -and $user.CoveredByCA -like 'Enforced*') {
            'Yes'
        } else {
            'No'
        }

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
