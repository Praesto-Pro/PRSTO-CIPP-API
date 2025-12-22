function Remove-ConfluenceSpace {
    <#
    .SYNOPSIS
        Deletes a Confluence space.
    .DESCRIPTION
        Permanently deletes a Confluence space. This operation cannot be undone.
        By default, prompts for confirmation due to the destructive nature of this operation.
        Use -Force to skip the confirmation prompt.
    .PARAMETER SpaceKey
        The unique key of the space to delete.
    .PARAMETER Force
        Skips the confirmation prompt and immediately deletes the space.
    .EXAMPLE
        Remove-ConfluenceSpace -SpaceKey 'CONTOSO'

        Deletes the space after confirmation.
    .EXAMPLE
        Remove-ConfluenceSpace -SpaceKey 'TEST' -Force

        Deletes the space without confirmation.
    .EXAMPLE
        Remove-ConfluenceSpace -SpaceKey 'PROJ' -WhatIf

        Shows what would be deleted without actually deleting.
    .NOTES
        Requires credentials to be configured via New-ConfluenceAPIKey and New-ConfluenceBaseURL.
        This operation is irreversible - all pages and content in the space will be deleted.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$SpaceKey,

        [Parameter()]
        [switch]$Force
    )

    # Convert to uppercase
    $SpaceKey = $SpaceKey.ToUpper()

    Write-Verbose "Preparing to delete space '$SpaceKey'..."

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
    $spaceName = $spaces[0].name
    Write-Verbose "Found space ID: $spaceId (Name: $spaceName)"

    $deleteEndpoint = "/wiki/api/v2/spaces/$spaceId"

    # Handle ShouldProcess with Force parameter
    $shouldDelete = $false
    if ($Force) {
        $shouldDelete = $PSCmdlet.ShouldProcess($SpaceKey, "Delete Confluence space '$spaceName'")
    }
    else {
        $shouldDelete = $PSCmdlet.ShouldProcess($SpaceKey, "Delete Confluence space '$spaceName'")
        if ($shouldDelete -and -not $WhatIfPreference) {
            # Additional confirmation for high-impact operation when not using -Force
            $shouldDelete = $PSCmdlet.ShouldContinue(
                "Are you sure you want to delete space '$SpaceKey' ($spaceName)? This action cannot be undone.",
                "Confirm Space Deletion"
            )
        }
    }

    if ($shouldDelete) {
        try {
            $null = Invoke-ConfluenceRequest -Endpoint $deleteEndpoint -Method DELETE
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                [System.Management.Automation.ErrorRecord]::new(
                    [System.Exception]::new("Failed to delete space '$SpaceKey': $($_.Exception.Message)"),
                    "SpaceDeleteError",
                    [System.Management.Automation.ErrorCategory]::WriteError,
                    $SpaceKey
                )
            )
        }

        Write-Verbose "Space '$SpaceKey' deleted successfully"
    }
}
