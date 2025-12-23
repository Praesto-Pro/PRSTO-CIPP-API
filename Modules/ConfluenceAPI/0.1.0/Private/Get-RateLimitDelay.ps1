function Get-RateLimitDelay {
    <#
    .SYNOPSIS
        Extracts delay seconds from rate limit response.
    .DESCRIPTION
        Parses the Retry-After header from a 429 response.
        Returns default delay if header not present.
    .PARAMETER Response
        The HTTP response object from Invoke-RestMethod exception.
    .PARAMETER DefaultDelay
        Default delay in seconds if Retry-After header is not present.
    .EXAMPLE
        Get-RateLimitDelay -Response $_.Exception.Response -DefaultDelay 5
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter()]
        $Response,

        [Parameter()]
        [int]$DefaultDelay = 5
    )

    $delay = $DefaultDelay

    if ($Response -and $Response.Headers) {
        try {
            $retryAfter = $Response.Headers['Retry-After']
            if ($retryAfter) {
                $parsedDelay = 0
                if ([int]::TryParse($retryAfter, [ref]$parsedDelay)) {
                    $delay = $parsedDelay
                    Write-Verbose "Retry-After header: $delay seconds"
                }
            }
        }
        catch {
            Write-Verbose "Could not parse Retry-After header, using default delay"
        }
    }

    return $delay
}
