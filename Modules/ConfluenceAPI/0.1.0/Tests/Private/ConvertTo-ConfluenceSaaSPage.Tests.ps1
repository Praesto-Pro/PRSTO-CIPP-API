$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$privateDir = Join-Path (Split-Path -Parent (Split-Path -Parent $here)) 'Private'

Describe 'ConvertTo-ConfluenceSaaSPage' {
    BeforeAll {
        # Dot-source all required dependencies
        . "$privateDir\New-ADFDocument.ps1"
        . "$privateDir\Add-ADFContent.ps1"
        . "$privateDir\ConvertTo-ADF.ps1"
        . "$privateDir\New-ADFTable.ps1"
        . "$privateDir\New-ADFHeading.ps1"
        . "$privateDir\New-ADFParagraph.ps1"
        . "$privateDir\ConvertTo-ConfluenceSaaSPage.ps1"

        # Microsoft tenant ID for test data
        $script:MicrosoftTenantId = 'f8cdef31-a31e-4b4a-93e4-5f571e91255a'
    }

    Context 'Empty/Null Input Handling' {
        It 'Returns valid ADF JSON when ServicePrincipals is null' {
            $result = ConvertTo-ConfluenceSaaSPage -ServicePrincipals $null
            $result | Should Not Be $null
            { $result | ConvertFrom-Json } | Should Not Throw
        }

        It 'Returns valid ADF JSON when ServicePrincipals is empty array' {
            $result = ConvertTo-ConfluenceSaaSPage -ServicePrincipals @()
            $result | Should Not Be $null
            { $result | ConvertFrom-Json } | Should Not Throw
        }

        It 'Shows "No service principal data available" message when ServicePrincipals is null' {
            $result = ConvertTo-ConfluenceSaaSPage -ServicePrincipals $null
            $result | Should Match 'No service principal data available'
        }

        It 'Shows "No service principal data available" message when ServicePrincipals is empty' {
            $result = ConvertTo-ConfluenceSaaSPage -ServicePrincipals @()
            $result | Should Match 'No service principal data available'
        }

        It 'Includes timestamp even when ServicePrincipals is null (FR44)' {
            $result = ConvertTo-ConfluenceSaaSPage -ServicePrincipals $null
            $result | Should Match 'Data as of:'
            $result | Should Match 'UTC'
        }

        It 'Includes timestamp even when ServicePrincipals is empty (FR44)' {
            $result = ConvertTo-ConfluenceSaaSPage -ServicePrincipals @()
            $result | Should Match 'Data as of:'
        }

        It 'Includes heading even when ServicePrincipals is empty' {
            $result = ConvertTo-ConfluenceSaaSPage -ServicePrincipals @()
            $result | Should Match 'Third-Party SaaS Applications'
        }
    }

    Context 'Microsoft App Filtering' {
        It 'Filters out Microsoft apps by default' {
            $apps = @(
                [PSCustomObject]@{
                    displayName = 'Microsoft Teams'
                    appOwnerOrganizationId = $MicrosoftTenantId
                    accountEnabled = $true
                }
                [PSCustomObject]@{
                    displayName = 'Third Party App'
                    appOwnerOrganizationId = 'other-tenant-guid'
                    accountEnabled = $true
                }
            )
            $result = ConvertTo-ConfluenceSaaSPage -ServicePrincipals $apps
            $result | Should Match 'Third Party App'
            $result | Should Not Match 'Microsoft Teams'
            $result | Should Match 'Total Third-Party Apps: 1'
        }

        It 'Includes Microsoft apps when IncludeMicrosoftApps switch is used' {
            $apps = @(
                [PSCustomObject]@{
                    displayName = 'Microsoft Teams'
                    appOwnerOrganizationId = $MicrosoftTenantId
                    accountEnabled = $true
                }
                [PSCustomObject]@{
                    displayName = 'Third Party App'
                    appOwnerOrganizationId = 'other-tenant-guid'
                    accountEnabled = $true
                }
            )
            $result = ConvertTo-ConfluenceSaaSPage -ServicePrincipals $apps -IncludeMicrosoftApps
            $result | Should Match 'Microsoft Teams'
            $result | Should Match 'Third Party App'
            $result | Should Match 'Total Third-Party Apps: 2'
        }

        It 'Shows empty state message when all apps are Microsoft apps' {
            $apps = @(
                [PSCustomObject]@{
                    displayName = 'Microsoft Teams'
                    appOwnerOrganizationId = $MicrosoftTenantId
                }
                [PSCustomObject]@{
                    displayName = 'Microsoft Graph'
                    appOwnerOrganizationId = $MicrosoftTenantId
                }
            )
            $result = ConvertTo-ConfluenceSaaSPage -ServicePrincipals $apps
            $result | Should Match 'No third-party SaaS applications found'
            $result | Should Match 'Microsoft built-in apps excluded'
        }

        It 'Handles apps with null appOwnerOrganizationId (includes them)' {
            $apps = @(
                [PSCustomObject]@{
                    displayName = 'Unknown App'
                    appOwnerOrganizationId = $null
                    accountEnabled = $true
                }
            )
            $result = ConvertTo-ConfluenceSaaSPage -ServicePrincipals $apps
            $result | Should Match 'Unknown App'
            $result | Should Match 'Total Third-Party Apps: 1'
        }
    }

    Context 'Valid ADF Output' {
        It 'Returns valid ADF JSON string with app data' {
            $app = [PSCustomObject]@{
                displayName = 'Test App'
                appOwnerOrganizationId = 'other-tenant'
                accountEnabled = $true
            }
            $result = ConvertTo-ConfluenceSaaSPage -ServicePrincipals @($app)
            $result | Should Not Be $null
            { $result | ConvertFrom-Json } | Should Not Throw
        }

        It 'ADF contains doc type and version' {
            $app = [PSCustomObject]@{
                displayName = 'Test App'
                appOwnerOrganizationId = 'other-tenant'
            }
            $result = ConvertTo-ConfluenceSaaSPage -ServicePrincipals @($app)
            $json = $result | ConvertFrom-Json
            $json.type | Should Be 'doc'
            $json.version | Should Be 1
        }

        It 'ADF contains content array' {
            $app = [PSCustomObject]@{
                displayName = 'Test App'
                appOwnerOrganizationId = 'other-tenant'
            }
            $result = ConvertTo-ConfluenceSaaSPage -ServicePrincipals @($app)
            $json = $result | ConvertFrom-Json
            $json.content | Should Not Be $null
            $json.content.Count | Should BeGreaterThan 0
        }
    }

    Context 'Application Name Mapping' {
        It 'Maps displayName correctly' {
            $app = [PSCustomObject]@{
                displayName = 'Salesforce'
                appOwnerOrganizationId = 'other-tenant'
            }
            $result = ConvertTo-ConfluenceSaaSPage -ServicePrincipals @($app)
            $result | Should Match 'Salesforce'
        }

        It 'Falls back to appDisplayName when displayName is missing' {
            $app = [PSCustomObject]@{
                appDisplayName = 'Slack Enterprise'
                appOwnerOrganizationId = 'other-tenant'
            }
            $result = ConvertTo-ConfluenceSaaSPage -ServicePrincipals @($app)
            $result | Should Match 'Slack Enterprise'
        }

        It 'Falls back to appId when both names are missing' {
            $app = [PSCustomObject]@{
                appId = 'app-guid-12345'
                appOwnerOrganizationId = 'other-tenant'
            }
            $result = ConvertTo-ConfluenceSaaSPage -ServicePrincipals @($app)
            $result | Should Match 'app-guid-12345'
        }

        It 'Shows Unknown App when all name fields are missing' {
            $app = [PSCustomObject]@{
                appOwnerOrganizationId = 'other-tenant'
            }
            $result = ConvertTo-ConfluenceSaaSPage -ServicePrincipals @($app)
            $result | Should Match 'Unknown App'
        }

        It 'Handles special characters in app name' {
            $app = [PSCustomObject]@{
                displayName = "App & Partners <Test>"
                appOwnerOrganizationId = 'other-tenant'
            }
            $result = ConvertTo-ConfluenceSaaSPage -ServicePrincipals @($app)
            # JSON escapes special characters - verify the name is present
            $result | Should Match 'App'
            $result | Should Match 'Partners'
        }
    }

    Context 'Publisher Mapping' {
        It 'Maps verifiedPublisher.displayName correctly' {
            $app = [PSCustomObject]@{
                displayName = 'Test App'
                appOwnerOrganizationId = 'other-tenant'
                verifiedPublisher = @{
                    displayName = 'Verified Corp'
                }
            }
            $result = ConvertTo-ConfluenceSaaSPage -ServicePrincipals @($app)
            $result | Should Match 'Verified Corp'
        }

        It 'Falls back to publisherName when verifiedPublisher is missing' {
            $app = [PSCustomObject]@{
                displayName = 'Test App'
                appOwnerOrganizationId = 'other-tenant'
                publisherName = 'Publisher Inc'
            }
            $result = ConvertTo-ConfluenceSaaSPage -ServicePrincipals @($app)
            $result | Should Match 'Publisher Inc'
        }

        It 'Shows Unknown when no publisher info available' {
            $app = [PSCustomObject]@{
                displayName = 'Test App'
                appOwnerOrganizationId = 'other-tenant'
            }
            $result = ConvertTo-ConfluenceSaaSPage -ServicePrincipals @($app)
            $result | Should Match 'Unknown'
        }
    }

    Context 'Status Mapping' {
        It 'Maps accountEnabled true to Enabled' {
            $app = [PSCustomObject]@{
                displayName = 'Test App'
                appOwnerOrganizationId = 'other-tenant'
                accountEnabled = $true
            }
            $result = ConvertTo-ConfluenceSaaSPage -ServicePrincipals @($app)
            $result | Should Match 'Enabled'
        }

        It 'Maps accountEnabled false to Disabled' {
            $app = [PSCustomObject]@{
                displayName = 'Test App'
                appOwnerOrganizationId = 'other-tenant'
                accountEnabled = $false
            }
            $result = ConvertTo-ConfluenceSaaSPage -ServicePrincipals @($app)
            $result | Should Match 'Disabled'
        }

        It 'Maps null accountEnabled to Unknown' {
            $app = [PSCustomObject]@{
                displayName = 'Test App'
                appOwnerOrganizationId = 'other-tenant'
            }
            $result = ConvertTo-ConfluenceSaaSPage -ServicePrincipals @($app)
            $result | Should Match 'Unknown'
        }
    }

    Context 'Sign-In Audience Mapping' {
        It 'Maps AzureADMyOrg to Single Tenant' {
            $app = [PSCustomObject]@{
                displayName = 'Test App'
                appOwnerOrganizationId = 'other-tenant'
                signInAudience = 'AzureADMyOrg'
            }
            $result = ConvertTo-ConfluenceSaaSPage -ServicePrincipals @($app)
            $result | Should Match 'Single Tenant'
        }

        It 'Maps AzureADMultipleOrgs to Multi-Tenant' {
            $app = [PSCustomObject]@{
                displayName = 'Test App'
                appOwnerOrganizationId = 'other-tenant'
                signInAudience = 'AzureADMultipleOrgs'
            }
            $result = ConvertTo-ConfluenceSaaSPage -ServicePrincipals @($app)
            $result | Should Match 'Multi-Tenant'
        }

        It 'Maps AzureADandPersonalMicrosoftAccount correctly' {
            $app = [PSCustomObject]@{
                displayName = 'Test App'
                appOwnerOrganizationId = 'other-tenant'
                signInAudience = 'AzureADandPersonalMicrosoftAccount'
            }
            $result = ConvertTo-ConfluenceSaaSPage -ServicePrincipals @($app)
            $result | Should Match 'Multi-Tenant.*Personal'
        }

        It 'Maps PersonalMicrosoftAccount to Personal Only' {
            $app = [PSCustomObject]@{
                displayName = 'Test App'
                appOwnerOrganizationId = 'other-tenant'
                signInAudience = 'PersonalMicrosoftAccount'
            }
            $result = ConvertTo-ConfluenceSaaSPage -ServicePrincipals @($app)
            $result | Should Match 'Personal Only'
        }

        It 'Shows Unknown when signInAudience is null' {
            $app = [PSCustomObject]@{
                displayName = 'Test App'
                appOwnerOrganizationId = 'other-tenant'
            }
            $result = ConvertTo-ConfluenceSaaSPage -ServicePrincipals @($app)
            $result | Should Match 'Unknown'
        }
    }

    Context 'Created Date Mapping' {
        It 'Formats createdDateTime correctly' {
            $app = [PSCustomObject]@{
                displayName = 'Test App'
                appOwnerOrganizationId = 'other-tenant'
                createdDateTime = '2024-06-15T10:30:00Z'
            }
            $result = ConvertTo-ConfluenceSaaSPage -ServicePrincipals @($app)
            $result | Should Match '2024-06-15'
        }

        It 'Shows Unknown when createdDateTime is null' {
            $app = [PSCustomObject]@{
                displayName = 'Test App'
                appOwnerOrganizationId = 'other-tenant'
            }
            $result = ConvertTo-ConfluenceSaaSPage -ServicePrincipals @($app)
            $result | Should Match 'Unknown'
        }
    }

    Context 'Summary Statistics' {
        It 'Shows total apps count in summary' {
            $apps = @(
                [PSCustomObject]@{ displayName = 'App1'; appOwnerOrganizationId = 'other' }
                [PSCustomObject]@{ displayName = 'App2'; appOwnerOrganizationId = 'other' }
                [PSCustomObject]@{ displayName = 'App3'; appOwnerOrganizationId = 'other' }
            )
            $result = ConvertTo-ConfluenceSaaSPage -ServicePrincipals $apps
            $result | Should Match 'Total Third-Party Apps: 3'
        }

        It 'Shows enabled count in summary' {
            $apps = @(
                [PSCustomObject]@{ displayName = 'App1'; appOwnerOrganizationId = 'other'; accountEnabled = $true }
                [PSCustomObject]@{ displayName = 'App2'; appOwnerOrganizationId = 'other'; accountEnabled = $true }
                [PSCustomObject]@{ displayName = 'App3'; appOwnerOrganizationId = 'other'; accountEnabled = $false }
            )
            $result = ConvertTo-ConfluenceSaaSPage -ServicePrincipals $apps
            $result | Should Match 'Enabled: 2'
        }

        It 'Shows disabled count in summary' {
            $apps = @(
                [PSCustomObject]@{ displayName = 'App1'; appOwnerOrganizationId = 'other'; accountEnabled = $true }
                [PSCustomObject]@{ displayName = 'App2'; appOwnerOrganizationId = 'other'; accountEnabled = $false }
            )
            $result = ConvertTo-ConfluenceSaaSPage -ServicePrincipals $apps
            $result | Should Match 'Disabled: 1'
        }
    }

    Context 'Timestamp (FR44)' {
        It 'Includes UTC timestamp in output' {
            $app = [PSCustomObject]@{ displayName = 'Test App'; appOwnerOrganizationId = 'other' }
            $result = ConvertTo-ConfluenceSaaSPage -ServicePrincipals @($app)
            $result | Should Match 'Data as of:'
            $result | Should Match 'UTC'
        }

        It 'Timestamp follows yyyy-MM-dd HH:mm format' {
            $app = [PSCustomObject]@{ displayName = 'Test App'; appOwnerOrganizationId = 'other' }
            $result = ConvertTo-ConfluenceSaaSPage -ServicePrincipals @($app)
            # Should match pattern like 2025-12-14 10:30
            $result | Should Match '\d{4}-\d{2}-\d{2} \d{2}:\d{2}'
        }
    }

    Context 'Table Structure' {
        It 'Creates table with serial number column' {
            $app = [PSCustomObject]@{ displayName = 'Test App'; appOwnerOrganizationId = 'other' }
            $result = ConvertTo-ConfluenceSaaSPage -ServicePrincipals @($app)
            $result | Should Match '"#"'
        }

        It 'Creates table with Application column' {
            $app = [PSCustomObject]@{ displayName = 'Test App'; appOwnerOrganizationId = 'other' }
            $result = ConvertTo-ConfluenceSaaSPage -ServicePrincipals @($app)
            $result | Should Match 'Application'
        }

        It 'Creates table with Publisher column' {
            $app = [PSCustomObject]@{ displayName = 'Test App'; appOwnerOrganizationId = 'other' }
            $result = ConvertTo-ConfluenceSaaSPage -ServicePrincipals @($app)
            $result | Should Match 'Publisher'
        }

        It 'Creates table with Status column' {
            $app = [PSCustomObject]@{ displayName = 'Test App'; appOwnerOrganizationId = 'other' }
            $result = ConvertTo-ConfluenceSaaSPage -ServicePrincipals @($app)
            $result | Should Match 'Status'
        }

        It 'Creates table with Audience column' {
            $app = [PSCustomObject]@{ displayName = 'Test App'; appOwnerOrganizationId = 'other' }
            $result = ConvertTo-ConfluenceSaaSPage -ServicePrincipals @($app)
            $result | Should Match 'Audience'
        }

        It 'Creates table with Created column' {
            $app = [PSCustomObject]@{ displayName = 'Test App'; appOwnerOrganizationId = 'other' }
            $result = ConvertTo-ConfluenceSaaSPage -ServicePrincipals @($app)
            $result | Should Match 'Created'
        }
    }

    Context 'Sorting' {
        It 'Sorts apps alphabetically by display name' {
            $apps = @(
                [PSCustomObject]@{ displayName = 'Zoom'; appOwnerOrganizationId = 'other' }
                [PSCustomObject]@{ displayName = 'Adobe'; appOwnerOrganizationId = 'other' }
                [PSCustomObject]@{ displayName = 'Slack'; appOwnerOrganizationId = 'other' }
            )
            $result = ConvertTo-ConfluenceSaaSPage -ServicePrincipals $apps
            $adobeIndex = $result.IndexOf('Adobe')
            $slackIndex = $result.IndexOf('Slack')
            $zoomIndex = $result.IndexOf('Zoom')
            $adobeIndex | Should BeLessThan $slackIndex
            $slackIndex | Should BeLessThan $zoomIndex
        }
    }

    Context 'Verbose Logging' {
        It 'Writes verbose message when transforming apps' {
            $app = [PSCustomObject]@{ displayName = 'Test App'; appOwnerOrganizationId = 'other' }
            $verboseOutput = ConvertTo-ConfluenceSaaSPage -ServicePrincipals @($app) -Verbose 4>&1
            $verboseMessages = $verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }
            $verboseMessages | Should Not Be $null
        }

        It 'Writes verbose message about filtering' {
            $apps = @(
                [PSCustomObject]@{ displayName = 'MS App'; appOwnerOrganizationId = $MicrosoftTenantId }
                [PSCustomObject]@{ displayName = 'Other App'; appOwnerOrganizationId = 'other' }
            )
            $verboseOutput = ConvertTo-ConfluenceSaaSPage -ServicePrincipals $apps -Verbose 4>&1
            $verboseText = ($verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }) -join ' '
            $verboseText | Should Match 'Filtered'
        }
    }

    Context 'Multiple Apps Processing' {
        It 'Processes multiple apps correctly' {
            $apps = @(
                [PSCustomObject]@{
                    displayName = 'Salesforce'
                    appOwnerOrganizationId = 'salesforce-tenant'
                    accountEnabled = $true
                    signInAudience = 'AzureADMultipleOrgs'
                }
                [PSCustomObject]@{
                    displayName = 'Slack'
                    appOwnerOrganizationId = 'slack-tenant'
                    accountEnabled = $true
                    signInAudience = 'AzureADMultipleOrgs'
                }
            )
            $result = ConvertTo-ConfluenceSaaSPage -ServicePrincipals $apps
            $result | Should Match 'Salesforce'
            $result | Should Match 'Slack'
            $result | Should Match 'Total Third-Party Apps: 2'
        }

        It 'Handles mixed data quality across apps' {
            $apps = @(
                [PSCustomObject]@{
                    displayName = 'Complete App'
                    appOwnerOrganizationId = 'other'
                    accountEnabled = $true
                    signInAudience = 'AzureADMultipleOrgs'
                    publisherName = 'Publisher Inc'
                    createdDateTime = '2024-01-01T00:00:00Z'
                }
                [PSCustomObject]@{
                    displayName = 'Minimal App'
                    appOwnerOrganizationId = 'other'
                }
            )
            $result = ConvertTo-ConfluenceSaaSPage -ServicePrincipals $apps
            $result | Should Match 'Complete App'
            $result | Should Match 'Minimal App'
        }
    }
}
