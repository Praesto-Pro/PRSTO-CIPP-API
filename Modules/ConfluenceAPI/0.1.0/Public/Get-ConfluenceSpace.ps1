function Get-ConfluenceSpace {
    <#
    .SYNOPSIS
        Gets Confluence space(s) by key or lists all spaces.
    .DESCRIPTION
        Retrieves Confluence space information. When called with a SpaceKey parameter,
        returns a single space. When called without parameters, returns all spaces
        with automatic pagination handling.
    .PARAMETER SpaceKey
        The unique key of the Confluence space to retrieve. If not specified,
        all spaces are returned.
    .EXAMPLE
        Get-ConfluenceSpace -SpaceKey 'CONTOSO'

        Returns the space with key 'CONTOSO'.
    .EXAMPLE
        Get-ConfluenceSpace

        Returns all spaces in the Confluence instance.
    .EXAMPLE
        Get-ConfluenceSpace -SpaceKey 'PROJ' -Verbose

        Returns the space with verbose logging.
    .NOTES
        Requires credentials to be configured via New-ConfluenceAPIKey and New-ConfluenceBaseURL.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject], [PSCustomObject[]])]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$SpaceKey
    )

    # Convert to uppercase if provided (Confluence keys are uppercase)
    if ($SpaceKey) {
        $SpaceKey = $SpaceKey.ToUpper()
    }

    if ($SpaceKey) {
        Write-Verbose "Getting space '$SpaceKey'..."

        # Use keys filter to find space by key
        $endpoint = "/wiki/api/v2/spaces?keys=$SpaceKey"

        try {
            $response = Invoke-ConfluenceRequest -Endpoint $endpoint -Method GET
        }
        catch {
            # Re-throw with more context
            $PSCmdlet.ThrowTerminatingError(
                [System.Management.Automation.ErrorRecord]::new(
                    [System.Exception]::new("Failed to get space '$SpaceKey': $($_.Exception.Message)"),
                    "SpaceGetError",
                    [System.Management.Automation.ErrorCategory]::ConnectionError,
                    $SpaceKey
                )
            )
        }

        # Handle response - could be array of results or single result
        # Use @() to ensure we always get an array (prevents pipeline unwrapping)
        $spaces = @(
            if ($null -ne $response.results) {
                $response.results
            } elseif ($response -is [System.Collections.IEnumerable] -and $response -isnot [string] -and $response -isnot [hashtable]) {
                $response
            } else {
                $response
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

        # Return mapped object for single space
        $space = $spaces[0]
        return [PSCustomObject]@{
            Id          = $space.id
            Key         = $space.key
            Name        = $space.name
            Type        = $space.type
            Status      = $space.status
            HomepageId  = $space.homepageId
            Description = if ($space.description -and $space.description.plain) { $space.description.plain.value } else { $null }
        }
    }
    else {
        Write-Verbose "Getting all spaces..."

        # Get all spaces - pagination handled by Invoke-ConfluenceRequest
        $endpoint = "/wiki/api/v2/spaces"

        try {
            $response = Invoke-ConfluenceRequest -Endpoint $endpoint -Method GET
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                [System.Management.Automation.ErrorRecord]::new(
                    [System.Exception]::new("Failed to get spaces: $($_.Exception.Message)"),
                    "SpaceListError",
                    [System.Management.Automation.ErrorCategory]::ConnectionError,
                    $null
                )
            )
        }

        # Handle response - could be array of results or single result
        # Use @() to ensure we always get an array (prevents pipeline unwrapping)
        $spaces = @(
            if ($response -is [System.Collections.IEnumerable] -and $response -isnot [string] -and $response -isnot [hashtable]) {
                $response
            } else {
                $response
            }
        )

        if ($null -eq $spaces -or $spaces.Count -eq 0) {
            Write-Verbose "No spaces found"
            return @()
        }

        Write-Verbose "Found $($spaces.Count) space(s)"

        # Map all spaces to PSCustomObjects
        $result = foreach ($space in $spaces) {
            [PSCustomObject]@{
                Id          = $space.id
                Key         = $space.key
                Name        = $space.name
                Type        = $space.type
                Status      = $space.status
                HomepageId  = $space.homepageId
                Description = if ($space.description -and $space.description.plain) { $space.description.plain.value } else { $null }
            }
        }

        return $result
    }
}
