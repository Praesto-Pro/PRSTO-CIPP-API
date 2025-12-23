$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$privateDir = Join-Path (Split-Path -Parent (Split-Path -Parent $here)) 'Private'

Describe 'ConvertTo-ConfluenceEndpointPage' {
    BeforeAll {
        # Dot-source dependencies
        . "$privateDir\New-ADFDocument.ps1"
        . "$privateDir\Add-ADFContent.ps1"
        . "$privateDir\ConvertTo-ADF.ps1"
        . "$privateDir\New-ADFTable.ps1"
        . "$privateDir\New-ADFHeading.ps1"
        . "$privateDir\New-ADFParagraph.ps1"
        . "$privateDir\ConvertTo-ConfluenceEndpointPage.ps1"
    }

    Context 'Empty/Null Input Handling (AC6)' {
        It 'Returns valid ADF with message when Endpoints is null' {
            $result = ConvertTo-ConfluenceEndpointPage -Endpoints $null

            $result | Should Not Be $null
            $result | Should Match 'No endpoint data available'
        }

        It 'Returns valid ADF with message when Endpoints is empty array' {
            $result = ConvertTo-ConfluenceEndpointPage -Endpoints @()

            $result | Should Not Be $null
            $result | Should Match 'No endpoint data available'
        }

        It 'Returns valid JSON when Endpoints is null' {
            $result = ConvertTo-ConfluenceEndpointPage -Endpoints $null

            { $result | ConvertFrom-Json } | Should Not Throw
        }
    }

    Context 'Single Endpoint Transformation (AC1, AC2)' {
        It 'Returns valid ADF JSON string' {
            $endpoint = [PSCustomObject]@{
                deviceName = 'DESKTOP-TEST'
                operatingSystem = 'Windows 10'
                complianceState = 'compliant'
                userDisplayName = 'Test User'
                lastSyncDateTime = '2025-12-13T08:00:00Z'
            }

            $result = ConvertTo-ConfluenceEndpointPage -Endpoints @($endpoint)

            $result | Should Not Be $null
            { $result | ConvertFrom-Json } | Should Not Throw
        }

        It 'Creates table with correct columns' {
            $endpoint = [PSCustomObject]@{
                deviceName = 'DESKTOP-TEST'
                operatingSystem = 'Windows 10'
                complianceState = 'compliant'
                userDisplayName = 'Test User'
                lastSyncDateTime = '2025-12-13T08:00:00Z'
            }

            $result = ConvertTo-ConfluenceEndpointPage -Endpoints @($endpoint)

            $result | Should Match 'Device Name'
            $result | Should Match 'OS'
            $result | Should Match 'Compliance'
            $result | Should Match 'Assigned User'
            $result | Should Match 'Last Sync'
        }

        It 'Maps DeviceName correctly' {
            $endpoint = [PSCustomObject]@{
                deviceName = 'DESKTOP-UNIQUE123'
                operatingSystem = 'Windows 10'
                complianceState = 'compliant'
            }

            $result = ConvertTo-ConfluenceEndpointPage -Endpoints @($endpoint)

            $result | Should Match 'DESKTOP-UNIQUE123'
        }

        It 'Maps OS correctly' {
            $endpoint = [PSCustomObject]@{
                deviceName = 'TEST'
                operatingSystem = 'Windows 11 Enterprise'
                complianceState = 'compliant'
            }

            $result = ConvertTo-ConfluenceEndpointPage -Endpoints @($endpoint)

            $result | Should Match 'Windows 11 Enterprise'
        }

        It 'Maps LastSync correctly' {
            $endpoint = [PSCustomObject]@{
                deviceName = 'TEST'
                operatingSystem = 'Windows'
                complianceState = 'compliant'
                lastSyncDateTime = '2025-12-13T08:00:00Z'
            }

            $result = ConvertTo-ConfluenceEndpointPage -Endpoints @($endpoint)

            $result | Should Match '2025-12-13T08:00:00Z'
        }
    }

    Context 'Compliance Status Mapping (AC5)' {
        It 'Maps compliant to Compliant' {
            $endpoint = [PSCustomObject]@{
                deviceName = 'TEST'
                operatingSystem = 'Windows'
                complianceState = 'compliant'
            }

            $result = ConvertTo-ConfluenceEndpointPage -Endpoints @($endpoint)

            $result | Should Match 'Compliant'
        }

        It 'Maps noncompliant to Non-Compliant' {
            $endpoint = [PSCustomObject]@{
                deviceName = 'TEST'
                operatingSystem = 'Windows'
                complianceState = 'noncompliant'
            }

            $result = ConvertTo-ConfluenceEndpointPage -Endpoints @($endpoint)

            $result | Should Match 'Non-Compliant'
        }

        It 'Maps inGracePeriod to In Grace Period' {
            $endpoint = [PSCustomObject]@{
                deviceName = 'TEST'
                operatingSystem = 'Windows'
                complianceState = 'inGracePeriod'
            }

            $result = ConvertTo-ConfluenceEndpointPage -Endpoints @($endpoint)

            $result | Should Match 'In Grace Period'
        }

        It 'Maps null complianceState to Unknown' {
            $endpoint = [PSCustomObject]@{
                deviceName = 'TEST'
                operatingSystem = 'Windows'
                complianceState = $null
            }

            $result = ConvertTo-ConfluenceEndpointPage -Endpoints @($endpoint)

            $result | Should Match 'Unknown'
        }

        It 'Maps unknown complianceState value to Unknown' {
            $endpoint = [PSCustomObject]@{
                deviceName = 'TEST'
                operatingSystem = 'Windows'
                complianceState = 'someUnknownValue'
            }

            $result = ConvertTo-ConfluenceEndpointPage -Endpoints @($endpoint)

            $result | Should Match 'Unknown'
        }

        It 'Uses case-insensitive matching for compliance state' {
            $endpoint = [PSCustomObject]@{
                deviceName = 'TEST'
                operatingSystem = 'Windows'
                complianceState = 'COMPLIANT'
            }

            $result = ConvertTo-ConfluenceEndpointPage -Endpoints @($endpoint)

            $result | Should Match 'Compliant'
        }

        It 'Maps configmanager to Config Manager' {
            $endpoint = [PSCustomObject]@{
                deviceName = 'TEST'
                operatingSystem = 'Windows'
                complianceState = 'configmanager'
            }

            $result = ConvertTo-ConfluenceEndpointPage -Endpoints @($endpoint)

            $result | Should Match 'Config Manager'
        }
    }

    Context 'User Assignment Display (AC3)' {
        It 'Uses userDisplayName when available' {
            $endpoint = [PSCustomObject]@{
                deviceName = 'TEST'
                operatingSystem = 'Windows'
                complianceState = 'compliant'
                userDisplayName = 'John Smith'
                userPrincipalName = 'john@contoso.com'
            }

            $result = ConvertTo-ConfluenceEndpointPage -Endpoints @($endpoint)

            $result | Should Match 'John Smith'
        }

        It 'Falls back to userPrincipalName when displayName is null' {
            $endpoint = [PSCustomObject]@{
                deviceName = 'TEST'
                operatingSystem = 'Windows'
                complianceState = 'compliant'
                userDisplayName = $null
                userPrincipalName = 'jane@contoso.com'
            }

            $result = ConvertTo-ConfluenceEndpointPage -Endpoints @($endpoint)

            $result | Should Match 'jane@contoso.com'
        }

        It 'Shows Unassigned when both user fields are null' {
            $endpoint = [PSCustomObject]@{
                deviceName = 'TEST'
                operatingSystem = 'Windows'
                complianceState = 'compliant'
                userDisplayName = $null
                userPrincipalName = $null
            }

            $result = ConvertTo-ConfluenceEndpointPage -Endpoints @($endpoint)

            $result | Should Match 'Unassigned'
        }

        It 'Shows Unassigned when user fields are empty strings' {
            $endpoint = [PSCustomObject]@{
                deviceName = 'TEST'
                operatingSystem = 'Windows'
                complianceState = 'compliant'
                userDisplayName = ''
                userPrincipalName = ''
            }

            $result = ConvertTo-ConfluenceEndpointPage -Endpoints @($endpoint)

            $result | Should Match 'Unassigned'
        }
    }

    Context 'Timestamp Display (AC4 - FR44)' {
        It 'Includes data freshness timestamp' {
            $endpoint = [PSCustomObject]@{
                deviceName = 'TEST'
                operatingSystem = 'Windows'
                complianceState = 'compliant'
            }

            $result = ConvertTo-ConfluenceEndpointPage -Endpoints @($endpoint)

            $result | Should Match 'Data as of:'
        }

        It 'Timestamp includes UTC designation' {
            $endpoint = [PSCustomObject]@{
                deviceName = 'TEST'
                operatingSystem = 'Windows'
                complianceState = 'compliant'
            }

            $result = ConvertTo-ConfluenceEndpointPage -Endpoints @($endpoint)

            $result | Should Match 'UTC'
        }

        It 'Timestamp is in correct format' {
            $endpoint = [PSCustomObject]@{
                deviceName = 'TEST'
                operatingSystem = 'Windows'
                complianceState = 'compliant'
            }

            $result = ConvertTo-ConfluenceEndpointPage -Endpoints @($endpoint)

            # Matches format: Data as of: YYYY-MM-DD HH:mm UTC
            $result | Should Match 'Data as of: \d{4}-\d{2}-\d{2} \d{2}:\d{2} UTC'
        }
    }

    Context 'Heading Display (AC1)' {
        It 'Includes Endpoint Inventory heading' {
            $endpoint = [PSCustomObject]@{
                deviceName = 'TEST'
                operatingSystem = 'Windows'
                complianceState = 'compliant'
            }

            $result = ConvertTo-ConfluenceEndpointPage -Endpoints @($endpoint)

            $result | Should Match 'Endpoint Inventory'
        }
    }

    Context 'Multiple Endpoints (AC1, AC2)' {
        It 'Processes multiple endpoints correctly' {
            $endpoints = @(
                [PSCustomObject]@{
                    deviceName = 'DEVICE-001'
                    operatingSystem = 'Windows 10'
                    complianceState = 'compliant'
                    userDisplayName = 'User One'
                    lastSyncDateTime = '2025-12-13T08:00:00Z'
                },
                [PSCustomObject]@{
                    deviceName = 'DEVICE-002'
                    operatingSystem = 'Windows 11'
                    complianceState = 'noncompliant'
                    userDisplayName = 'User Two'
                    lastSyncDateTime = '2025-12-12T10:00:00Z'
                }
            )

            $result = ConvertTo-ConfluenceEndpointPage -Endpoints $endpoints

            $result | Should Match 'DEVICE-001'
            $result | Should Match 'DEVICE-002'
            $result | Should Match 'User One'
            $result | Should Match 'User Two'
        }
    }

    Context 'Verbose Logging (AC7 - NFR19)' {
        It 'Outputs verbose message with endpoint count' {
            $endpoint = [PSCustomObject]@{
                deviceName = 'TEST'
                operatingSystem = 'Windows'
                complianceState = 'compliant'
            }

            $verboseOutput = ConvertTo-ConfluenceEndpointPage -Endpoints @($endpoint) -Verbose 4>&1

            ($verboseOutput -join ' ') | Should Match 'Transforming 1 endpoint'
        }

        It 'Outputs verbose message for empty input' {
            $verboseOutput = ConvertTo-ConfluenceEndpointPage -Endpoints $null -Verbose 4>&1

            ($verboseOutput -join ' ') | Should Match 'No endpoints provided'
        }
    }

    Context 'Property Parameter (Column Selection)' {
        It 'Uses all columns by default' {
            $endpoint = [PSCustomObject]@{
                deviceName = 'TEST'
                operatingSystem = 'Windows'
                complianceState = 'compliant'
                userDisplayName = 'Test User'
                lastSyncDateTime = '2025-12-13T08:00:00Z'
            }

            $result = ConvertTo-ConfluenceEndpointPage -Endpoints @($endpoint)

            $result | Should Match 'Device Name'
            $result | Should Match 'OS'
            $result | Should Match 'Compliance'
            $result | Should Match 'Assigned User'
            $result | Should Match 'Last Sync'
        }

        It 'Limits columns when Property parameter specified' {
            $endpoint = [PSCustomObject]@{
                deviceName = 'TEST'
                operatingSystem = 'Windows'
                complianceState = 'compliant'
                userDisplayName = 'Test User'
                lastSyncDateTime = '2025-12-13T08:00:00Z'
            }

            $result = ConvertTo-ConfluenceEndpointPage -Endpoints @($endpoint) -Property 'Device Name', 'Compliance'

            $result | Should Match 'Device Name'
            $result | Should Match 'Compliance'
        }

        It 'Accepts single column via Property parameter' {
            $endpoint = [PSCustomObject]@{
                deviceName = 'TEST'
                operatingSystem = 'Windows'
                complianceState = 'compliant'
            }

            { ConvertTo-ConfluenceEndpointPage -Endpoints @($endpoint) -Property 'Device Name' } | Should Not Throw
        }
    }

    Context 'Null Field Handling' {
        It 'Handles null deviceName gracefully' {
            $endpoint = [PSCustomObject]@{
                deviceName = $null
                operatingSystem = 'Windows'
                complianceState = 'compliant'
            }

            { ConvertTo-ConfluenceEndpointPage -Endpoints @($endpoint) } | Should Not Throw
        }

        It 'Handles null operatingSystem gracefully' {
            $endpoint = [PSCustomObject]@{
                deviceName = 'TEST'
                operatingSystem = $null
                complianceState = 'compliant'
            }

            { ConvertTo-ConfluenceEndpointPage -Endpoints @($endpoint) } | Should Not Throw
        }

        It 'Handles null lastSyncDateTime with Never fallback' {
            $endpoint = [PSCustomObject]@{
                deviceName = 'TEST'
                operatingSystem = 'Windows'
                complianceState = 'compliant'
                lastSyncDateTime = $null
            }

            $result = ConvertTo-ConfluenceEndpointPage -Endpoints @($endpoint)

            $result | Should Match 'Never'
        }
    }
}
