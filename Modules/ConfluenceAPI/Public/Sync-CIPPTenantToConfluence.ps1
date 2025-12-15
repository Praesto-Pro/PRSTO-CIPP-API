function Sync-CIPPTenantToConfluence {
    <#
    .SYNOPSIS
        Syncs all CIPP data for a tenant to their Confluence space.
    .DESCRIPTION
        Orchestrates the sync of all 6 data types (Users, Endpoints, Licenses,
        MFA, Teams, SharePoint) for a specific tenant to their mapped Confluence
        space. Continues on partial failures and reports comprehensive results.
    .PARAMETER TenantId
        The CIPP tenant ID to sync. Required.
    .PARAMETER Users
        Array of user data objects from CIPP.
    .PARAMETER Endpoints
        Array of endpoint data objects from CIPP.
    .PARAMETER Licenses
        Array of license data objects from CIPP.
    .PARAMETER MFAData
        Array of MFA status data objects from CIPP.
    .PARAMETER Teams
        Array of Teams data objects from CIPP.
    .PARAMETER SharePointSites
        Array of SharePoint site data objects from CIPP.
    .OUTPUTS
        [PSCustomObject] Comprehensive sync result with status per data type.
    .EXAMPLE
        $result = Sync-CIPPTenantToConfluence -TenantId 'abc-123' -Users $users -Endpoints $endpoints
        Syncs only user and endpoint data for the tenant.
    .EXAMPLE
        Sync-CIPPTenantToConfluence -TenantId 'abc-123' -Users $u -Endpoints $e -Licenses $l -MFAData $m -Teams $t -SharePointSites $s
        Syncs all data types for the tenant.
    .EXAMPLE
        Sync-CIPPTenantToConfluence -TenantId 'abc-123' -Users $users -WhatIf
        Shows what would be synced without making changes.
    .NOTES
        Part of Story 8.1 - Manual Tenant Sync.
        FR34: Technical Lead can trigger manual sync for a specific tenant.
        NFR18: Module must include -WhatIf support for all write operations.
        NFR19: Module must include -Verbose logging for troubleshooting.
    .LINK
        Get-ConfluenceTenantMapping
    .LINK
        Sync-ConfluenceUserInventory
    .LINK
        Sync-ConfluenceEndpointInventory
    .LINK
        Sync-ConfluenceLicenseReport
    .LINK
        Sync-ConfluenceMFAReport
    .LINK
        Sync-ConfluenceTeamsInventory
    .LINK
        Sync-ConfluenceSharePointInventory
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$TenantId,

        [Parameter()]
        [array]$Users,

        [Parameter()]
        [array]$Endpoints,

        [Parameter()]
        [array]$Licenses,

        [Parameter()]
        [array]$MFAData,

        [Parameter()]
        [array]$Teams,

        [Parameter()]
        [array]$SharePointSites
    )

    $startTime = (Get-Date).ToUniversalTime()
    Write-Verbose "Starting sync for tenant '$TenantId' at $($startTime.ToString('yyyy-MM-dd HH:mm:ss')) UTC"

    # Resolve tenant to space mapping
    Write-Verbose "Resolving tenant '$TenantId' to Confluence space"
    $mapping = Get-ConfluenceTenantMapping -TenantId $TenantId

    if (-not $mapping) {
        $errorMessage = "No Confluence space mapping found for tenant '$TenantId'. Run Set-ConfluenceTenantMapping first."
        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
            [System.InvalidOperationException]::new($errorMessage),
            'TenantMappingNotFound',
            [System.Management.Automation.ErrorCategory]::ObjectNotFound,
            $TenantId
        )
        $PSCmdlet.ThrowTerminatingError($errorRecord)
    }

    $spaceKey = $mapping.SpaceKey
    Write-Verbose "Tenant '$TenantId' maps to space '$spaceKey'"

    # Initialize results tracking
    $syncResults = @()
    $errors = @()

    # Define sync operations with correct parameter names for each function
    $syncOperations = @(
        @{ Name = 'UserInventory'; ParamName = 'Users'; Data = $Users; Function = 'Sync-ConfluenceUserInventory'; DataParam = 'Users' },
        @{ Name = 'EndpointInventory'; ParamName = 'Endpoints'; Data = $Endpoints; Function = 'Sync-ConfluenceEndpointInventory'; DataParam = 'Endpoints' },
        @{ Name = 'LicenseReport'; ParamName = 'Licenses'; Data = $Licenses; Function = 'Sync-ConfluenceLicenseReport'; DataParam = 'Licenses' },
        @{ Name = 'MFAReport'; ParamName = 'MFAData'; Data = $MFAData; Function = 'Sync-ConfluenceMFAReport'; DataParam = 'MFAData' },
        @{ Name = 'TeamsInventory'; ParamName = 'Teams'; Data = $Teams; Function = 'Sync-ConfluenceTeamsInventory'; DataParam = 'TeamsData' },
        @{ Name = 'SharePointInventory'; ParamName = 'SharePointSites'; Data = $SharePointSites; Function = 'Sync-ConfluenceSharePointInventory'; DataParam = 'SharePointData' }
    )

    foreach ($op in $syncOperations) {
        # Check if this data type was provided (using $PSBoundParameters)
        if (-not $PSBoundParameters.ContainsKey($op.ParamName)) {
            Write-Verbose "Skipping $($op.Name) - no data provided"
            $syncResults += [PSCustomObject]@{
                DataType = $op.Name
                Status   = 'Skipped'
                PageId   = $null
                Message  = 'No data provided'
            }
            continue
        }

        Write-Verbose "Syncing $($op.Name) to space '$spaceKey'"

        if ($PSCmdlet.ShouldProcess("$($op.Name) in $spaceKey", "Sync CIPP data")) {
            try {
                # Build parameters for sync function
                $syncParams = @{
                    SpaceKey = $spaceKey
                }
                $syncParams[$op.DataParam] = $op.Data

                # Call sync function
                $syncFunctionResult = & $op.Function @syncParams

                $syncResults += [PSCustomObject]@{
                    DataType = $op.Name
                    Status   = 'Success'
                    PageId   = $syncFunctionResult.Id
                    Message  = "Synced successfully"
                }
                Write-Verbose "$($op.Name) sync completed successfully"
            }
            catch {
                Write-Warning "$($op.Name) sync failed: $($_.Exception.Message)"
                $syncResults += [PSCustomObject]@{
                    DataType = $op.Name
                    Status   = 'Failed'
                    PageId   = $null
                    Message  = $_.Exception.Message
                }
                $errors += [PSCustomObject]@{
                    DataType  = $op.Name
                    Error     = $_.Exception.Message
                    Timestamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss')
                }
            }
        }
        else {
            $syncResults += [PSCustomObject]@{
                DataType = $op.Name
                Status   = 'WhatIf'
                PageId   = $null
                Message  = 'Would sync'
            }
        }
    }

    $endTime = (Get-Date).ToUniversalTime()
    $duration = $endTime - $startTime

    # Determine overall status (use @() to ensure array for .Count in PS 5.1)
    $successCount = @($syncResults | Where-Object { $_.Status -eq 'Success' }).Count
    $failedCount = @($syncResults | Where-Object { $_.Status -eq 'Failed' }).Count
    $skippedCount = @($syncResults | Where-Object { $_.Status -eq 'Skipped' }).Count
    $whatIfCount = @($syncResults | Where-Object { $_.Status -eq 'WhatIf' }).Count

    if ($whatIfCount -gt 0) {
        $overallStatus = 'WhatIf'
    }
    elseif ($failedCount -eq 0 -and $successCount -gt 0) {
        $overallStatus = 'Success'
    }
    elseif ($failedCount -gt 0 -and $successCount -gt 0) {
        $overallStatus = 'PartialFailure'
    }
    elseif ($failedCount -gt 0 -and $successCount -eq 0) {
        $overallStatus = 'Failed'
    }
    else {
        $overallStatus = 'NoOperation'
    }

    Write-Verbose "Sync completed for tenant '$TenantId': $overallStatus ($successCount succeeded, $failedCount failed, $skippedCount skipped)"

    return [PSCustomObject]@{
        TenantId      = $TenantId
        SpaceKey      = $spaceKey
        StartTime     = $startTime.ToString('yyyy-MM-dd HH:mm:ss UTC')
        EndTime       = $endTime.ToString('yyyy-MM-dd HH:mm:ss UTC')
        Duration      = $duration.ToString('hh\:mm\:ss')
        SyncResults   = $syncResults
        OverallStatus = $overallStatus
        SuccessCount  = $successCount
        FailedCount   = $failedCount
        SkippedCount  = $skippedCount
        ErrorCount    = $errors.Count
        Errors        = $errors
    }
}
