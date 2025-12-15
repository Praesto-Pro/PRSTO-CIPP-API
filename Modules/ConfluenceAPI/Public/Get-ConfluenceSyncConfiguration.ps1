function Get-ConfluenceSyncConfiguration {
    <#
    .SYNOPSIS
        Retrieves current sync configuration settings.
    .DESCRIPTION
        Returns the stored sync configuration or default values if no
        configuration has been set.
    .OUTPUTS
        [PSCustomObject] Current sync configuration with all settings.
    .EXAMPLE
        Get-ConfluenceSyncConfiguration
        Returns the current sync configuration.
    .EXAMPLE
        $config = Get-ConfluenceSyncConfiguration
        if ($config.SyncFrequency -eq 'Daily') { ... }
        Gets configuration and checks frequency setting.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    Write-Verbose "Retrieving sync configuration"

    if ($script:ConfluenceSyncConfiguration) {
        Write-Verbose "Returning stored configuration"
        [PSCustomObject]@{
            SyncFrequency         = $script:ConfluenceSyncConfiguration.SyncFrequency
            RetryAttempts         = $script:ConfluenceSyncConfiguration.RetryAttempts
            RetryDelaySeconds     = $script:ConfluenceSyncConfiguration.RetryDelaySeconds
            EnableIncrementalSync = $script:ConfluenceSyncConfiguration.EnableIncrementalSync
            ConfiguredAt          = $script:ConfluenceSyncConfiguration.ConfiguredAt
        }
    }
    else {
        Write-Verbose "No configuration set, returning defaults"
        [PSCustomObject]@{
            SyncFrequency         = 'Manual'
            RetryAttempts         = 3
            RetryDelaySeconds     = 30
            EnableIncrementalSync = $false
            ConfiguredAt          = $null
        }
    }
}
