function ConvertTo-ConfluenceClientHomepage {
    <#
    .SYNOPSIS
        Generates ADF content for a client space homepage.
    .DESCRIPTION
        Creates a standard homepage structure for client documentation spaces with
        placeholder sections for all data sync types (Users, Endpoints, Licenses,
        Security Reports, and Collaboration).
    .PARAMETER ClientName
        The display name of the client for the welcome heading.
    .OUTPUTS
        [string] ADF JSON string for the homepage content.
    .EXAMPLE
        $content = ConvertTo-ConfluenceClientHomepage -ClientName 'Contoso Corp'
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ClientName
    )

    Write-Verbose "Generating homepage content for '$ClientName'"

    # Create ADF document
    $doc = New-ADFDocument

    # Welcome heading (Level 1)
    $welcome = New-ADFHeading -Level 1 -Text "Welcome to $ClientName Documentation"

    # Overview section
    $overviewHeading = New-ADFHeading -Level 2 -Text 'Overview'
    $overviewText = New-ADFParagraph -Text 'This space contains automated documentation for your Microsoft 365 environment.'

    # User Inventory placeholder
    $userHeading = New-ADFHeading -Level 2 -Text 'User Inventory'
    $userText = New-ADFParagraph -Text 'User inventory data will appear here after sync.'

    # Endpoint Inventory placeholder
    $endpointHeading = New-ADFHeading -Level 2 -Text 'Endpoint Inventory'
    $endpointText = New-ADFParagraph -Text 'Endpoint inventory data will appear here after sync.'

    # License Report placeholder
    $licenseHeading = New-ADFHeading -Level 2 -Text 'License Report'
    $licenseText = New-ADFParagraph -Text 'License report data will appear here after sync.'

    # Security Reports placeholder
    $securityHeading = New-ADFHeading -Level 2 -Text 'Security Reports'
    $securityText = New-ADFParagraph -Text 'MFA status and security reports will appear here after sync.'

    # Collaboration placeholder
    $collabHeading = New-ADFHeading -Level 2 -Text 'Collaboration'
    $collabText = New-ADFParagraph -Text 'Teams and SharePoint inventory will appear here after sync.'

    # Assemble document
    $doc = Add-ADFContent -Document $doc -Content @(
        $welcome,
        $overviewHeading, $overviewText,
        $userHeading, $userText,
        $endpointHeading, $endpointText,
        $licenseHeading, $licenseText,
        $securityHeading, $securityText,
        $collabHeading, $collabText
    )

    Write-Verbose "Generated homepage with 6 sections for '$ClientName'"
    return ConvertTo-ADF -InputObject $doc
}
