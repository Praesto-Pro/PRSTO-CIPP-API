function Set-ConfluenceSpace {
    <#
    .SYNOPSIS
        Updates an existing Confluence space.
    .DESCRIPTION
        Updates the properties of an existing Confluence space. At least one update
        parameter (Name, Description, or HomepageId) must be provided.
        The function looks up the space ID from the key, as the API requires the ID for updates.
    .PARAMETER SpaceKey
        The unique key of the space to update.
    .PARAMETER Name
        New display name for the space.
    .PARAMETER Description
        New description for the space.
    .PARAMETER HomepageId
        New homepage ID for the space.
    .EXAMPLE
        Set-ConfluenceSpace -SpaceKey 'CONTOSO' -Name 'Contoso Corporation'

        Updates the space name.
    .EXAMPLE
        Set-ConfluenceSpace -SpaceKey 'PROJ' -Description 'Updated project documentation'

        Updates the space description.
    .EXAMPLE
        Set-ConfluenceSpace -SpaceKey 'TEST' -Name 'New Name' -WhatIf

        Shows what would be updated without making changes.
    .NOTES
        Requires credentials to be configured via New-ConfluenceAPIKey and New-ConfluenceBaseURL.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$SpaceKey,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter()]
        [string]$Description,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$HomepageId
    )

    # Validate at least one update parameter is provided
    if (-not $Name -and -not $PSBoundParameters.ContainsKey('Description') -and -not $HomepageId) {
        $PSCmdlet.ThrowTerminatingError(
            [System.Management.Automation.ErrorRecord]::new(
                [System.ArgumentException]::new("At least one update parameter (Name, Description, or HomepageId) must be provided."),
                "NoUpdateParameters",
                [System.Management.Automation.ErrorCategory]::InvalidArgument,
                $SpaceKey
            )
        )
    }

    # Convert to uppercase
    $SpaceKey = $SpaceKey.ToUpper()

    Write-Verbose "Updating space '$SpaceKey'..."

    # First, look up the space to get its ID
    Write-Verbose "Looking up space ID for '$SpaceKey'..."
    $lookupEndpoint = "/wiki/api/v2/spaces?keys=$SpaceKey"

    try {
        $lookupResponse = Invoke-ConfluenceRequest -Endpoint $lookupEndpoint -Method GET
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new("Failed to look up space '$SpaceKey': $($_.Exception.Message)"),
                "SpaceLookupError",
                [System.Management.Automation.ErrorCategory]::ConnectionError,
                $SpaceKey
            )
        )
    }

    # Handle response - use @() to ensure array (prevents pipeline unwrapping)
    $spaces = @(
        if ($null -ne $lookupResponse.results) {
            $lookupResponse.results
        } elseif ($lookupResponse -is [System.Collections.IEnumerable] -and $lookupResponse -isnot [string] -and $lookupResponse -isnot [hashtable]) {
            $lookupResponse
        } else {
            $lookupResponse
        }
    )

    if ($null -eq $spaces -or $spaces.Count -eq 0) {
        $PSCmdlet.ThrowTerminatingError(
            [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new("Space with key '$SpaceKey' was not found. Verify the space key exists."),
                "SpaceNotFound",
                [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                $SpaceKey
            )
        )
    }

    $spaceId = $spaces[0].id
    Write-Verbose "Found space ID: $spaceId"

    # Build update body - only include provided parameters
    $body = @{}

    if ($Name) {
        $body['name'] = $Name
    }

    if ($PSBoundParameters.ContainsKey('Description')) {
        $body['description'] = @{
            representation = 'plain'
            value          = $Description
        }
    }

    if ($HomepageId) {
        $body['homepageId'] = $HomepageId
    }

    $jsonBody = $body | ConvertTo-Json -Depth 10
    $updateEndpoint = "/wiki/api/v2/spaces/$spaceId"

    if ($PSCmdlet.ShouldProcess($SpaceKey, "Update Confluence space")) {
        try {
            $response = Invoke-ConfluenceRequest -Endpoint $updateEndpoint -Method PUT -Body $jsonBody
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                [System.Management.Automation.ErrorRecord]::new(
                    [System.Exception]::new("Failed to update space '$SpaceKey': $($_.Exception.Message)"),
                    "SpaceUpdateError",
                    [System.Management.Automation.ErrorCategory]::WriteError,
                    $SpaceKey
                )
            )
        }

        Write-Verbose "Space '$SpaceKey' updated successfully"

        # Return mapped object
        return [PSCustomObject]@{
            Id          = $response.id
            Key         = $response.key
            Name        = $response.name
            Type        = $response.type
            Status      = $response.status
            HomepageId  = $response.homepageId
            Description = if ($response.description -and $response.description.plain) { $response.description.plain.value } else { $null }
        }
    }
}
