Function Invoke-ExecExtensionMapping {
  <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        CIPP.Extension.ReadWrite
    #>
  [CmdletBinding()]
  param($Request, $TriggerMetadata)

  $APIName = $Request.Params.CIPPEndpoint
  $Headers = $Request.Headers


  $Table = Get-CIPPTable -TableName CippMapping

  if ($Request.Query.List) {
    switch ($Request.Query.List) {
      'HaloPSA' {
        $Result = Get-HaloMapping -CIPPMapping $Table
      }
      'NinjaOne' {
        $Result = Get-NinjaOneOrgMapping -CIPPMapping $Table
      }
      'NinjaOneFields' {
        $Result = Get-NinjaOneFieldMapping -CIPPMapping $Table
      }
      'Hudu' {
        $Result = Get-HuduMapping -CIPPMapping $Table
      }
      'HuduFields' {
        $Result = Get-HuduFieldMapping -CIPPMapping $Table
      }
      'Sherweb' {
        $Result = Get-SherwebMapping -CIPPMapping $Table
      }
      'HaloPSAFields' {
        $TicketTypes = Get-HaloTicketType
        $Outcomes = Get-HaloTicketOutcome
        $Result = @{
          'TicketTypes' = $TicketTypes
          'Outcomes'    = $Outcomes
        }
      }
      'PWPushFields' {
        $Accounts = Get-PwPushAccount
        $Result = @{
          'Accounts' = $Accounts
        }
      }
      'Confluence' {
        # Get existing mappings
        $Mappings = Get-ConfluenceMapping

        # Get configuration and connect to Confluence API
        # Use different variable name to avoid overwriting $Table (CippMapping)
        $ExtConfigTable = Get-CIPPTable -TableName Extensionsconfig
        try {
          $Configuration = (Get-CIPPAzDataTableEntity @ExtConfigTable).config | ConvertFrom-Json -ErrorAction Stop

          # Connect to Confluence API using extension credentials
          $ConnectionResult = Connect-ConfluenceAPI -Configuration $Configuration
          if (-not $ConnectionResult -or -not $ConnectionResult.Success) {
            $errorMsg = if ($ConnectionResult -and $ConnectionResult.Error) { $ConnectionResult.Error } else { 'Connection failed - check configuration' }
            throw $errorMsg
          }

          # Get available spaces for dropdown
          $Spaces = Get-ConfluenceSpace

          # Filter out already-mapped spaces (like tenant list shows only unmapped tenants)
          $MappedSpaceKeys = @($Mappings | ForEach-Object { $_.IntegrationId })
          $SpacesList = $Spaces | Where-Object { $_.Key -notin $MappedSpaceKeys } | ForEach-Object {
            [PSCustomObject]@{
              name  = $_.Name
              value = $_.Key
            }
          }
        }
        catch {
          $Message = if ($_.ErrorDetails.Message) {
            Get-NormalizedError -Message $_.ErrorDetails.Message
          } else {
            $_.Exception.Message
          }
          Write-LogMessage -API 'ExecExtensionMapping' -message "Failed to get Confluence spaces: $Message" -Sev 'Error'
          $SpacesList = @(@{name = "Could not get Confluence spaces: $Message"; value = '-1' })
        }

        # Return both mappings and available spaces
        $Result = @{
          'Mappings'  = @($Mappings)
          'Companies' = @($SpacesList)
        }
      }
    }
  }

  try {
    if ($Request.Query.AddMapping) {
      switch ($Request.Query.AddMapping) {
        'Sherweb' {
          $Result = Set-SherwebMapping -CIPPMapping $Table -APIName $APIName -Request $Request
        }
        'HaloPSA' {
          $Result = Set-HaloMapping -CIPPMapping $Table -APIName $APIName -Request $Request
        }
        'NinjaOne' {
          $Result = Set-NinjaOneOrgMapping -CIPPMapping $Table -APIName $APIName -Request $Request
          Register-CIPPExtensionScheduledTasks
        }
        'NinjaOneFields' {
          $Result = Set-NinjaOneFieldMapping -CIPPMapping $Table -APIName $APIName -Request $Request -TriggerMetadata $TriggerMetadata
          Register-CIPPExtensionScheduledTasks
        }
        'Hudu' {
          $Result = Set-HuduMapping -CIPPMapping $Table -APIName $APIName -Request $Request
          Register-CIPPExtensionScheduledTasks
        }
        'HuduFields' {
          $Result = Set-ExtensionFieldMapping -CIPPMapping $Table -APIName $APIName -Request $Request -Extension 'Hudu'
          Register-CIPPExtensionScheduledTasks
        }
        'Confluence' {
          $Result = Set-ConfluenceMapping -CIPPMapping $Table -APIName $APIName -Request $Request
          Register-CIPPExtensionScheduledTasks
        }
      }
    }
    $StatusCode = [HttpStatusCode]::OK
  }
  catch {
    $ErrorMessage = Get-CippException -Exception $_
    $Result = "Mapping API failed. $($ErrorMessage.NormalizedError)"
    Write-LogMessage -API $APIName -headers $Headers -message $Result -Sev 'Error' -LogData $ErrorMessage
    $StatusCode = [HttpStatusCode]::InternalServerError
  }

  try {
    if ($Request.Query.AutoMapping) {
      switch ($Request.Query.AutoMapping) {
        'NinjaOne' {
          $Batch = [PSCustomObject]@{
            'NinjaAction'  = 'StartAutoMapping'
            'FunctionName' = 'NinjaOneQueue'
          }
          $InputObject = [PSCustomObject]@{
            OrchestratorName = 'NinjaOneOrchestrator'
            Batch            = @($Batch)
          }
          #Write-Host ($InputObject | ConvertTo-Json)
          $InstanceId = Start-CIPPOrchestrator -InputObject $InputObject
          Write-Host "Started permissions orchestration with ID = '$InstanceId'"
          $Result = 'AutoMapping Request has been queued. Exact name matches will appear first and matches on device names and serials will take longer. Please check the CIPP Logbook and refresh the page once complete.'
        }
        'Confluence' {
          # Get configuration and connect to Confluence API
          $ConfigTable = Get-CIPPTable -TableName Extensionsconfig
          $Configuration = (Get-CIPPAzDataTableEntity @ConfigTable).config | ConvertFrom-Json -ErrorAction Stop
          $ConnectionResult = Connect-ConfluenceAPI -Configuration $Configuration
          if (-not $ConnectionResult -or -not $ConnectionResult.Success) {
            throw 'Failed to connect to Confluence API'
          }

          # Get all Confluence spaces and CIPP tenants
          $Spaces = Get-ConfluenceSpace
          $Tenants = Get-Tenants -IncludeErrors
          $ExistingMappings = Get-ExtensionMapping -Extension 'Confluence'
          $MappedTenantIds = @($ExistingMappings | ForEach-Object { $_.RowKey })

          # Ensure we use CippMapping table for storing mappings
          $MappingTable = Get-CIPPTable -TableName CippMapping

          # Auto-map by matching tenant displayName to space name (case-insensitive)
          $AutoMappedCount = 0
          foreach ($Tenant in $Tenants) {
            # Skip already mapped tenants
            if ($Tenant.RowKey -in $MappedTenantIds) { continue }

            # Try to find matching space by name
            $MatchingSpace = $Spaces | Where-Object {
              $_.Name -eq $Tenant.displayName -or
              $_.Name -like "*$($Tenant.displayName)*" -or
              $Tenant.displayName -like "*$($_.Name)*"
            } | Select-Object -First 1

            if ($MatchingSpace) {
              # Create mapping in CippMapping table
              $AddObject = @{
                PartitionKey    = 'ConfluenceMapping'
                RowKey          = $Tenant.RowKey
                IntegrationId   = $MatchingSpace.Key
                IntegrationName = $MatchingSpace.Name
              }
              Add-CIPPAzDataTableEntity @MappingTable -Entity $AddObject -Force
              Write-LogMessage -API $APIName -headers $Headers -message "Auto-mapped $($Tenant.displayName) to Confluence space $($MatchingSpace.Name)" -Sev 'Info'
              $AutoMappedCount++
            }
          }
          $Result = "AutoMapping complete. Matched $AutoMappedCount tenant(s) to Confluence spaces. Refresh the page to see results."
        }
      }
    }
    $StatusCode = [HttpStatusCode]::OK
  }
  catch {
    $ErrorMessage = Get-CippException -Exception $_
    $Result = "Mapping API failed. $($ErrorMessage.NormalizedError)"
    Write-LogMessage -API $APIName -headers $Headers -message $Result -Sev 'Error' -LogData $ErrorMessage
    $StatusCode = [HttpStatusCode]::InternalServerError
  }

  return ([HttpResponseContext]@{
      StatusCode = $StatusCode
      Body       = $Result
    })

}
