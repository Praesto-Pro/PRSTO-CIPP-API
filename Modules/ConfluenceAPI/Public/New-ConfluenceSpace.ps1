function New-ConfluenceSpace {
    <#
    .SYNOPSIS
        Creates a new Confluence space.
    .DESCRIPTION
        Creates a new Confluence space with the specified key, name, and optional description.
        The space key is automatically converted to uppercase as required by Confluence.
    .PARAMETER SpaceKey
        The unique key for the space. Must be uppercase alphanumeric characters only,
        maximum 255 characters. Lowercase input will be converted to uppercase.
    .PARAMETER Name
        The display name for the space.
    .PARAMETER Description
        Optional description for the space.
    .EXAMPLE
        New-ConfluenceSpace -SpaceKey 'CONTOSO' -Name 'Contoso Corp'

        Creates a new space with key CONTOSO and name 'Contoso Corp'.
    .EXAMPLE
        New-ConfluenceSpace -SpaceKey 'PROJ' -Name 'Project Docs' -Description 'Project documentation'

        Creates a new space with a description.
    .EXAMPLE
        New-ConfluenceSpace -SpaceKey 'TEST' -Name 'Test Space' -WhatIf

        Shows what would be created without actually creating the space.
    .NOTES
        Requires credentials to be configured via New-ConfluenceAPIKey and New-ConfluenceBaseURL.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateLength(1, 255)]
        [string]$SpaceKey,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter()]
        [string]$Description
    )

    # Convert to uppercase (Confluence keys must be uppercase)
    $SpaceKey = $SpaceKey.ToUpper()

    # Validate SpaceKey format after uppercase conversion
    if ($SpaceKey -notmatch '^[A-Z0-9]+$') {
        $PSCmdlet.ThrowTerminatingError(
            [System.Management.Automation.ErrorRecord]::new(
                [System.ArgumentException]::new("Space key '$SpaceKey' is invalid. Use uppercase alphanumeric characters only (A-Z, 0-9)."),
                "InvalidSpaceKey",
                [System.Management.Automation.ErrorCategory]::InvalidArgument,
                $SpaceKey
            )
        )
    }

    Write-Verbose "Creating space '$SpaceKey' with name '$Name'..."

    # Build request body
    $body = @{
        key  = $SpaceKey
        name = $Name
    }

    # Add description if provided
    if ($Description) {
        $body['description'] = @{
            representation = 'plain'
            value          = $Description
        }
    }

    $jsonBody = $body | ConvertTo-Json -Depth 10

    if ($PSCmdlet.ShouldProcess($SpaceKey, "Create Confluence space")) {
        try {
            $response = Invoke-ConfluenceRequest -Endpoint '/wiki/api/v2/spaces' -Method POST -Body $jsonBody
        }
        catch {
            # Check for specific error conditions
            $errorMessage = $_.Exception.Message
            if ($errorMessage -match '409' -or $errorMessage -match 'already exists') {
                $PSCmdlet.ThrowTerminatingError(
                    [System.Management.Automation.ErrorRecord]::new(
                        [System.Exception]::new("Space key '$SpaceKey' already exists. Choose a unique key."),
                        "SpaceAlreadyExists",
                        [System.Management.Automation.ErrorCategory]::ResourceExists,
                        $SpaceKey
                    )
                )
            }

            $PSCmdlet.ThrowTerminatingError(
                [System.Management.Automation.ErrorRecord]::new(
                    [System.Exception]::new("Failed to create space '$SpaceKey': $errorMessage"),
                    "SpaceCreateError",
                    [System.Management.Automation.ErrorCategory]::WriteError,
                    $SpaceKey
                )
            )
        }

        Write-Verbose "Space '$SpaceKey' created successfully"

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
