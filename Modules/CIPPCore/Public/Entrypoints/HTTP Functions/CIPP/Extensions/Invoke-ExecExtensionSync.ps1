Function Invoke-ExecExtensionSync {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        CIPP.Extension.ReadWrite
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)
    switch ($Request.Query.Extension) {
        'Gradient' {
            try {
                Write-LogMessage -API 'Scheduler_Billing' -tenant 'none' -message 'Starting billing processing.' -sev Info
                $Table = Get-CIPPTable -TableName Extensionsconfig
                $Configuration = (Get-CIPPAzDataTableEntity @Table).config | ConvertFrom-Json -Depth 10

                foreach ($ConfigItem in $Configuration.psobject.properties.name) {
                    switch ($ConfigItem) {
                        'Gradient' {
                            If ($Configuration.Gradient.enabled -and $Configuration.Gradient.BillingEnabled) {
                                # Queue the sync function for immediate execution
                                Add-CippQueueMessage -Cmdlet 'New-GradientServiceSyncRun' -Parameters @{}
                                $Results = [pscustomobject]@{'Results' = 'Successfully queued Gradient Sync' }
                            }
                        }
                    }
                }
            } catch {
                $Results = [pscustomobject]@{'Results' = "Could not start Gradient Sync: $($_.Exception.Message)" }

                Write-LogMessage -API 'Scheduler_Billing' -tenant 'none' -message "Could not start billing processing $($_.Exception.Message)" -sev Error
            }
        }

        'NinjaOne' {
            try {
                $Table = Get-CIPPTable -TableName NinjaOneSettings

                $CIPPMapping = Get-CIPPTable -TableName CippMapping
                $Filter = "PartitionKey eq 'NinjaOneMapping'"
                $TenantsToProcess = Get-AzDataTableEntity @CIPPMapping -Filter $Filter | Where-Object { $Null -ne $_.IntegrationId -and $_.IntegrationId -ne '' }

                if ($Request.Query.TenantID) {
                    $Tenant = $TenantsToProcess | Where-Object { $_.RowKey -eq $Request.Query.TenantID }
                    if (($Tenant | Measure-Object).count -eq 1) {
                        $Batch = [PSCustomObject]@{
                            'NinjaAction'  = 'SyncTenant'
                            'MappedTenant' = $Tenant
                            'FunctionName' = 'NinjaOneQueue'
                        }
                        $InputObject = [PSCustomObject]@{
                            OrchestratorName = 'NinjaOneOrchestrator'
                            Batch            = @($Batch)
                        }
                        #Write-Host ($InputObject | ConvertTo-Json)
                        $InstanceId = Start-CIPPOrchestrator -InputObject $InputObject

                        $Results = [pscustomobject]@{'Results' = "NinjaOne Synchronization Queued for $($Tenant.IntegrationName)" }
                    } else {
                        $Results = [pscustomobject]@{'Results' = 'Tenant was not found.' }
                    }

                } else {
                    $Batch = [PSCustomObject]@{
                        'NinjaAction'  = 'SyncTenants'
                        'FunctionName' = 'NinjaOneQueue'
                    }
                    $InputObject = [PSCustomObject]@{
                        OrchestratorName = 'NinjaOneOrchestrator'
                        Batch            = @($Batch)
                    }
                    #Write-Host ($InputObject | ConvertTo-Json)
                    $InstanceId = Start-CIPPOrchestrator -InputObject $InputObject
                    Write-Host "Started permissions orchestration with ID = '$InstanceId'"
                    $Results = [pscustomobject]@{'Results' = "NinjaOne Synchronization Queuing $(($TenantsToProcess | Measure-Object).count) Tenants" }

                }
            } catch {
                $Results = [pscustomobject]@{'Results' = "Could not start NinjaOne Sync: $($_.Exception.Message)" }
                Write-LogMessage -API 'Scheduler_Billing' -tenant 'none' -message "Could not start NinjaOne Sync $($_.Exception.Message)" -sev Error
            }
        }
        'Hudu' {
            Register-CIPPExtensionScheduledTasks -Reschedule -Extensions 'Hudu'
            $Results = [pscustomobject]@{'Results' = 'Extension sync tasks have been rescheduled and will start within 15 minutes' }
        }
        'Confluence' {
            try {
                Write-LogMessage -API 'ConfluenceSync' -tenant 'none' -message 'Starting Confluence force sync' -sev Info

                # Get extension configuration
                $Table = Get-CIPPTable -TableName Extensionsconfig
                $Configuration = (Get-CIPPAzDataTableEntity @Table).config | ConvertFrom-Json -ErrorAction Stop

                if (-not $Configuration.Confluence.Enabled) {
                    $Results = [pscustomobject]@{'Results' = 'Confluence extension is not enabled' }
                } else {
                    # Get mapped tenants
                    $CIPPMapping = Get-CIPPTable -TableName CippMapping
                    $Filter = "PartitionKey eq 'ConfluenceMapping'"
                    $TenantsToProcess = Get-AzDataTableEntity @CIPPMapping -Filter $Filter | Where-Object { $Null -ne $_.IntegrationId -and $_.IntegrationId -ne '' }
                    $TenantCount = ($TenantsToProcess | Measure-Object).Count

                    if ($TenantCount -eq 0) {
                        $Results = [pscustomobject]@{'Results' = 'No tenants mapped to Confluence spaces. Configure tenant mappings first.' }
                    } else {
                        # Get tenant details for domain names
                        $Tenants = Get-Tenants -IncludeErrors
                        $SyncResults = [System.Collections.Generic.List[string]]::new()
                        $ErrorCount = 0

                        foreach ($Mapping in $TenantsToProcess) {
                            $Tenant = $Tenants | Where-Object { $_.customerId -eq $Mapping.RowKey }
                            if ($Tenant) {
                                try {
                                    Write-LogMessage -API 'ConfluenceSync' -tenant $Tenant.defaultDomainName -message "Starting sync for $($Tenant.displayName)" -sev Info
                                    $SyncResult = Push-CippExtensionData -TenantFilter $Tenant.defaultDomainName -Extension 'Confluence'

                                    if ($SyncResult.Errors.Count -gt 0) {
                                        $SyncResults.Add("$($Tenant.displayName): Completed with $($SyncResult.Errors.Count) error(s)")
                                        $ErrorCount += $SyncResult.Errors.Count
                                    } else {
                                        $SyncResults.Add("$($Tenant.displayName): Synced (Users: $($SyncResult.Users), Devices: $($SyncResult.Devices))")
                                    }
                                } catch {
                                    $SyncResults.Add("$($Tenant.displayName): Failed - $_")
                                    $ErrorCount++
                                    Write-LogMessage -API 'ConfluenceSync' -tenant $Tenant.defaultDomainName -message "Sync failed: $_" -sev Error
                                }
                            }
                        }

                        $StatusMessage = if ($ErrorCount -gt 0) {
                            "Confluence sync completed with $ErrorCount error(s) across $TenantCount tenant(s)"
                        } else {
                            "Confluence sync completed successfully for $TenantCount tenant(s)"
                        }

                        Write-LogMessage -API 'ConfluenceSync' -tenant 'none' -message $StatusMessage -sev Info

                        $Results = [pscustomobject]@{
                            'Results' = $StatusMessage
                            'Details' = $SyncResults
                        }
                    }
                }
            } catch {
                $Results = [pscustomobject]@{'Results' = "Could not start Confluence Sync: $($_.Exception.Message)" }
                Write-LogMessage -API 'ConfluenceSync' -tenant 'none' -message "Could not start Confluence Sync: $($_.Exception.Message)" -sev Error
            }
        }

    }


    return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = $Results
        })

}
