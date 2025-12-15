function Update-ConfluenceClientIndex {
    <#
    .SYNOPSIS
        Updates the CLIENTS-INDEX page with current tenant-to-space mappings.
    .DESCRIPTION
        Retrieves all tenant-to-space mappings from Azure Table Storage and
        updates (or creates) the CLIENTS-INDEX page with a table listing all
        client spaces with clickable links.

        The CLIENTS-INDEX page provides a master list of all client spaces
        for easy navigation and serves as a central directory.

        When no mappings exist, the page displays a helpful message instead
        of an empty table.
    .PARAMETER RootSpaceKey
        The space key where the CLIENTS-INDEX page lives. Defaults to 'MSP'.
    .PARAMETER IndexPageTitle
        The title of the index page. Defaults to 'CLIENTS-INDEX'.
    .OUTPUTS
        [PSCustomObject] Object with PageId, ClientCount, Status properties.
    .EXAMPLE
        Update-ConfluenceClientIndex
        Updates the CLIENTS-INDEX page in the default MSP space.
    .EXAMPLE
        Update-ConfluenceClientIndex -RootSpaceKey 'DOCS' -Verbose
        Updates the index in the DOCS space with verbose logging.
    .EXAMPLE
        Update-ConfluenceClientIndex -WhatIf
        Shows what would be updated without making changes.
    .EXAMPLE
        Update-ConfluenceClientIndex -IndexPageTitle 'Client Directory'
        Updates the index page with a custom title.
    .NOTES
        This function is called automatically by New-ConfluenceClientSpace to keep
        the index current. It can also be run manually to rebuild the index.

        Requires credentials to be configured via New-ConfluenceAPIKey and New-ConfluenceBaseURL.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$RootSpaceKey = 'MSP',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$IndexPageTitle = 'CLIENTS-INDEX'
    )

    Write-Verbose "Updating CLIENTS-INDEX in space '$RootSpaceKey'"

    # Get all current tenant-to-space mappings
    Write-Verbose "Retrieving current tenant-to-space mappings"
    $mappings = @(Get-ConfluenceTenantMapping)
    Write-Verbose "Found $($mappings.Count) client mapping(s)"

    # Get base URL for generating space links
    $baseURL = Get-ConfluenceBaseURL
    if (-not $baseURL) {
        $PSCmdlet.ThrowTerminatingError(
            [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new("Confluence base URL is not configured. Use New-ConfluenceBaseURL to set the URL."),
                "BaseURLNotConfigured",
                [System.Management.Automation.ErrorCategory]::InvalidOperation,
                $null
            )
        )
    }

    # Generate ADF content
    Write-Verbose "Generating CLIENTS-INDEX page content"
    $indexContent = ConvertTo-ConfluenceClientIndex -Mappings $mappings -BaseURL $baseURL

    # Check if index page already exists
    Write-Verbose "Searching for existing CLIENTS-INDEX page in space '$RootSpaceKey'"
    # Escape single quotes in parameters to prevent CQL syntax issues
    $escapedTitle = $IndexPageTitle.Replace("'", "''")
    $escapedSpaceKey = $RootSpaceKey.Replace("'", "''")
    $cql = "title = '$escapedTitle' and space = '$escapedSpaceKey' and type = page"
    $existingPage = Search-Confluence -CQL $cql | Select-Object -First 1

    if ($PSCmdlet.ShouldProcess("$IndexPageTitle in $RootSpaceKey", "Update client index page")) {
        if ($existingPage) {
            Write-Verbose "Updating existing CLIENTS-INDEX page (ID: $($existingPage.Id))"
            Set-ConfluencePage -PageId $existingPage.Id -Body $indexContent | Out-Null
            $pageId = $existingPage.Id
            $status = 'Updated'
        }
        else {
            Write-Verbose "Creating new CLIENTS-INDEX page in space '$RootSpaceKey'"
            $newPage = New-ConfluencePage -SpaceKey $RootSpaceKey -Title $IndexPageTitle -Body $indexContent
            $pageId = $newPage.Id
            $status = 'Created'
        }

        Write-Verbose "Successfully $($status.ToLower()) CLIENTS-INDEX with $($mappings.Count) client(s)"

        return [PSCustomObject]@{
            PageId      = $pageId
            ClientCount = $mappings.Count
            Status      = $status
        }
    }
}
