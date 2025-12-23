function Remove-ConfluenceSyncConfiguration {
    <#
    .SYNOPSIS
        Clears the stored sync configuration.
    .DESCRIPTION
        Removes the stored sync configuration, reverting to default values
        for subsequent Get-ConfluenceSyncConfiguration calls.
    .EXAMPLE
        Remove-ConfluenceSyncConfiguration
        Clears the sync configuration.
    .EXAMPLE
        Remove-ConfluenceSyncConfiguration -WhatIf
        Shows what would happen without clearing configuration.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param()

    Write-Verbose "Removing sync configuration"

    if ($PSCmdlet.ShouldProcess('Sync Configuration', 'Remove')) {
        $script:ConfluenceSyncConfiguration = $null
        Write-Verbose "Sync configuration cleared"
    }
}
