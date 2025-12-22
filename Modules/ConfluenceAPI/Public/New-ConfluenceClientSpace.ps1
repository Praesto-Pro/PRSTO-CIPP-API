function New-ConfluenceClientSpace {
    <#
    .SYNOPSIS
        Creates a new Confluence client space with standard structure.
    .DESCRIPTION
        Creates a new Confluence space for a client with a standard homepage structure
        containing placeholder sections for all data sync types. Also stores the
        tenant-to-space mapping in Azure Table Storage for sync operations.
    .PARAMETER SpaceKey
        The unique key for the Confluence space. Must be uppercase letters and numbers only,
        starting with a letter (e.g., 'CONTOSO', 'CLIENT01').
    .PARAMETER ClientName
        The display name of the client, used as the space name and in the welcome heading.
    .PARAMETER TenantId
        The CIPP tenant ID to associate with this space for sync operations.
    .PARAMETER Description
        Optional description for the Confluence space.
    .OUTPUTS
        [PSCustomObject] Object with Id, SpaceKey, Name, HomepageId, TenantId properties.
    .EXAMPLE
        New-ConfluenceClientSpace -SpaceKey 'CONTOSO' -ClientName 'Contoso Corp' -TenantId 'abc-123'
        Creates a new client space for Contoso Corp.
    .EXAMPLE
        New-ConfluenceClientSpace -SpaceKey 'CONTOSO' -ClientName 'Contoso Corp' -TenantId 'abc-123' -Description 'Documentation for Contoso'
        Creates a new client space with a custom description.
    .EXAMPLE
        New-ConfluenceClientSpace -SpaceKey 'TEST' -ClientName 'Test Client' -TenantId 'test-id' -WhatIf
        Shows what would be created without making any changes.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$SpaceKey,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ClientName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$TenantId,

        [Parameter()]
        [string]$Description
    )

    Write-Verbose "Creating client space '$SpaceKey' for tenant '$TenantId'"

    # Validate SpaceKey format (uppercase letters and numbers, starts with letter)
    # Use -cnotmatch for case-sensitive matching
    if ($SpaceKey -cnotmatch '^[A-Z][A-Z0-9]*$') {
        $PSCmdlet.ThrowTerminatingError(
            [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new("SpaceKey '$SpaceKey' is invalid. SpaceKey must start with an uppercase letter and contain only uppercase letters and numbers (A-Z, 0-9)."),
                "InvalidSpaceKey",
                [System.Management.Automation.ErrorCategory]::InvalidArgument,
                $SpaceKey
            )
        )
    }

    # Check if space already exists
    Write-Verbose "Checking if space '$SpaceKey' already exists"
    $existingSpace = Get-ConfluenceSpace -SpaceKey $SpaceKey -ErrorAction SilentlyContinue
    if ($existingSpace) {
        $PSCmdlet.ThrowTerminatingError(
            [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new("Space '$SpaceKey' already exists. Use Get-ConfluenceSpace to verify."),
                "SpaceAlreadyExists",
                [System.Management.Automation.ErrorCategory]::ResourceExists,
                $SpaceKey
            )
        )
    }

    # Check if TenantId already has a mapping
    Write-Verbose "Checking if tenant '$TenantId' already has a mapping"
    $existingMapping = Get-ConfluenceTenantMapping -TenantId $TenantId
    if ($existingMapping) {
        $PSCmdlet.ThrowTerminatingError(
            [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new("Tenant '$TenantId' is already mapped to space '$($existingMapping.SpaceKey)'. Use Get-ConfluenceTenantMapping to verify."),
                "TenantAlreadyMapped",
                [System.Management.Automation.ErrorCategory]::ResourceExists,
                $TenantId
            )
        )
    }

    if ($PSCmdlet.ShouldProcess("$ClientName ($SpaceKey)", "Create Confluence client space")) {
        # Create the space
        Write-Verbose "Creating Confluence space '$SpaceKey' with name '$ClientName'"
        $createParams = @{
            SpaceKey = $SpaceKey
            Name     = $ClientName
        }
        if ($Description) {
            $createParams['Description'] = $Description
        }
        $space = New-ConfluenceSpace @createParams

        # Generate and update homepage content
        Write-Verbose "Generating homepage content for '$ClientName'"
        $homepageContent = ConvertTo-ConfluenceClientHomepage -ClientName $ClientName

        Write-Verbose "Updating homepage (ID: $($space.HomepageId)) with standard structure"
        Set-ConfluencePage -PageId $space.HomepageId -Body $homepageContent | Out-Null

        # Store the tenant-to-space mapping
        Write-Verbose "Storing tenant-to-space mapping for '$TenantId' -> '$SpaceKey'"
        Set-ConfluenceTenantMapping -TenantId $TenantId -SpaceKey $SpaceKey -SpaceName $ClientName

        # Update CLIENTS-INDEX (non-blocking - failure should not fail space creation)
        Write-Verbose "Updating CLIENTS-INDEX with new client '$ClientName'"
        try {
            Update-ConfluenceClientIndex | Out-Null
            Write-Verbose "Successfully updated CLIENTS-INDEX"
        }
        catch {
            Write-Warning "Failed to update CLIENTS-INDEX: $($_.Exception.Message). Space creation succeeded, but index may be stale."
        }

        Write-Verbose "Successfully created client space '$SpaceKey' for tenant '$TenantId'"
        return [PSCustomObject]@{
            Id         = $space.Id
            SpaceKey   = $space.Key
            Name       = $space.Name
            HomepageId = $space.HomepageId
            TenantId   = $TenantId
        }
    }
}
