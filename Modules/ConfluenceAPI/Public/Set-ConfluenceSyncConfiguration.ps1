function Set-ConfluenceSyncConfiguration {
    <#
    .SYNOPSIS
        Configures sync behavior and frequency settings.
    .DESCRIPTION
        Stores sync configuration including frequency, retry behavior, and
        incremental sync settings. Configuration is stored in memory and
        used by sync orchestration functions.
    .PARAMETER SyncFrequency
        How often sync should run: Hourly, Daily, Weekly, or Manual.
    .PARAMETER RetryAttempts
        Number of retry attempts for failed operations (1-10).
    .PARAMETER RetryDelaySeconds
        Base delay between retry attempts in seconds (5-300).
    .PARAMETER EnableIncrementalSync
        When true, sync skips unchanged data for efficiency.
    .OUTPUTS
        [PSCustomObject] The stored sync configuration.
    .EXAMPLE
        Set-ConfluenceSyncConfiguration -SyncFrequency 'Daily' -RetryAttempts 3
        Configures daily sync with 3 retry attempts.
    .EXAMPLE
        Set-ConfluenceSyncConfiguration -EnableIncrementalSync $true
        Enables incremental sync while preserving other settings.
    .EXAMPLE
        Set-ConfluenceSyncConfiguration -SyncFrequency 'Weekly' -WhatIf
        Shows what configuration would be set without making changes.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [ValidateSet('Hourly', 'Daily', 'Weekly', 'Manual')]
        [string]$SyncFrequency,

        [Parameter()]
        [ValidateRange(1, 10)]
        [int]$RetryAttempts,

        [Parameter()]
        [ValidateRange(5, 300)]
        [int]$RetryDelaySeconds,

        [Parameter()]
        [bool]$EnableIncrementalSync
    )

    Write-Verbose "Setting sync configuration"

    # Get current config or defaults
    $currentConfig = if ($script:ConfluenceSyncConfiguration) {
        $script:ConfluenceSyncConfiguration.Clone()
    }
    else {
        @{
            SyncFrequency         = 'Manual'
            RetryAttempts         = 3
            RetryDelaySeconds     = 30
            EnableIncrementalSync = $false
            ConfiguredAt          = $null
        }
    }

    # Apply provided parameters (merge pattern - only update what's specified)
    if ($PSBoundParameters.ContainsKey('SyncFrequency')) {
        Write-Verbose "Setting SyncFrequency to '$SyncFrequency'"
        $currentConfig.SyncFrequency = $SyncFrequency
    }
    if ($PSBoundParameters.ContainsKey('RetryAttempts')) {
        Write-Verbose "Setting RetryAttempts to $RetryAttempts"
        $currentConfig.RetryAttempts = $RetryAttempts
    }
    if ($PSBoundParameters.ContainsKey('RetryDelaySeconds')) {
        Write-Verbose "Setting RetryDelaySeconds to $RetryDelaySeconds"
        $currentConfig.RetryDelaySeconds = $RetryDelaySeconds
    }
    if ($PSBoundParameters.ContainsKey('EnableIncrementalSync')) {
        Write-Verbose "Setting EnableIncrementalSync to $EnableIncrementalSync"
        $currentConfig.EnableIncrementalSync = $EnableIncrementalSync
    }

    # Update timestamp
    $currentConfig.ConfiguredAt = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss UTC')

    if ($PSCmdlet.ShouldProcess('Sync Configuration', 'Set')) {
        $script:ConfluenceSyncConfiguration = $currentConfig
        Write-Verbose "Sync configuration stored successfully"
    }

    # Return configuration object
    [PSCustomObject]@{
        SyncFrequency         = $currentConfig.SyncFrequency
        RetryAttempts         = $currentConfig.RetryAttempts
        RetryDelaySeconds     = $currentConfig.RetryDelaySeconds
        EnableIncrementalSync = $currentConfig.EnableIncrementalSync
        ConfiguredAt          = $currentConfig.ConfiguredAt
    }
}
