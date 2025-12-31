$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$privateDir = Join-Path (Split-Path -Parent (Split-Path -Parent $here)) 'Private'

Describe 'ConvertTo-ConfluenceSharePointPage' {
    BeforeAll {
        # Dot-source dependencies (ADF helpers)
        . "$privateDir\New-ADFDocument.ps1"
        . "$privateDir\Add-ADFContent.ps1"
        . "$privateDir\ConvertTo-ADF.ps1"
        . "$privateDir\New-ADFTable.ps1"
        . "$privateDir\New-ADFHeading.ps1"
        . "$privateDir\New-ADFParagraph.ps1"
        # Dot-source function under test
        . "$privateDir\ConvertTo-ConfluenceSharePointPage.ps1"
    }

    Context 'Empty/Null Input Handling' {
        It 'Returns valid ADF JSON string when SharePointData is null' {
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData $null
            $result | Should Not Be $null
            $result | Should Match '"type"'
        }

        It 'Returns message when SharePointData is null' {
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData $null
            $result | Should Match 'No SharePoint data available'
        }

        It 'Returns valid ADF JSON string when SharePointData is empty array' {
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData @()
            $result | Should Not Be $null
            $result | Should Match '"type"'
        }

        It 'Returns message when SharePointData is empty array' {
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData @()
            $result | Should Match 'No SharePoint data available'
        }

        It 'Includes timestamp even when SharePointData is null' {
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData $null
            $result | Should Match 'Data as of:'
            $result | Should Match 'UTC'
        }

        It 'Includes timestamp even when SharePointData is empty array' {
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData @()
            $result | Should Match 'Data as of:'
            $result | Should Match 'UTC'
        }

        It 'Includes heading for empty state' {
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData $null
            $result | Should Match 'SharePoint Inventory'
        }
    }

    Context 'Valid ADF Output' {
        It 'Returns valid JSON string' {
            $site = [PSCustomObject]@{
                displayName = 'Test Site'
                webUrl = 'https://contoso.sharepoint.com/sites/test'
            }
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData @($site)
            { $result | ConvertFrom-Json } | Should Not Throw
        }

        It 'Contains ADF document structure' {
            $site = [PSCustomObject]@{
                displayName = 'Test Site'
            }
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData @($site)
            $result | Should Match '"type":\s*"doc"'
            $result | Should Match '"version":\s*1'
        }

        It 'Contains table structure' {
            $site = [PSCustomObject]@{
                displayName = 'Test Site'
            }
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData @($site)
            $result | Should Match '"type":\s*"table"'
        }
    }

    Context 'Site Name Mapping' {
        It 'Maps displayName correctly' {
            $site = [PSCustomObject]@{
                displayName = 'Marketing Team Site'
                webUrl = 'https://contoso.sharepoint.com/sites/marketing'
            }
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData @($site)
            $result | Should Match 'Marketing Team Site'
        }

        It 'Falls back to name when displayName is missing' {
            $site = [PSCustomObject]@{
                name = 'marketing'
                webUrl = 'https://contoso.sharepoint.com/sites/marketing'
            }
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData @($site)
            $result | Should Match 'marketing'
        }

        It 'Falls back to id when displayName and name are missing' {
            $site = [PSCustomObject]@{
                id = 'site-guid-12345'
                webUrl = 'https://contoso.sharepoint.com/sites/test'
            }
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData @($site)
            $result | Should Match 'site-guid-12345'
        }

        It 'Uses Unknown Site when no name properties and no URL' {
            $site = [PSCustomObject]@{
                storageUsedInBytes = 1000
            }
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData @($site)
            $result | Should Match 'Unknown Site'
        }

        It 'Maps ownerDisplayName from OneDrive Usage Report' {
            $site = [PSCustomObject]@{
                ownerDisplayName = 'John Doe'
                siteUrl = 'https://contoso-my.sharepoint.com/personal/john_contoso_com'
            }
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData @($site)
            $result | Should Match 'John Doe'
        }

        It 'Falls back to ownerPrincipalName from OneDrive Usage Report' {
            $site = [PSCustomObject]@{
                ownerPrincipalName = 'john@contoso.com'
                siteUrl = 'https://contoso-my.sharepoint.com/personal/john_contoso_com'
            }
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData @($site)
            $result | Should Match 'john@contoso.com'
        }

        It 'Extracts site name from /sites/ URL when no name property' {
            $site = [PSCustomObject]@{
                siteUrl = 'https://contoso.sharepoint.com/sites/Marketing'
                storageUsedInBytes = 1000000
            }
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData @($site)
            $result | Should Match 'Marketing'
        }

        It 'Extracts site name from /personal/ URL when no name property' {
            $site = [PSCustomObject]@{
                siteUrl = 'https://contoso-my.sharepoint.com/personal/john_doe_contoso_com'
                storageUsedInBytes = 1000000
            }
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData @($site)
            $result | Should Match 'john doe contoso com'
        }

        It 'Handles special characters in site name' {
            $site = [PSCustomObject]@{
                displayName = 'Sales & Marketing Site'
                webUrl = 'https://contoso.sharepoint.com/sites/salesmarketing'
            }
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData @($site)
            # JSON escapes special characters
            $result | Should Match 'Sales'
            $result | Should Match 'Marketing Site'
        }
    }

    Context 'URL Mapping' {
        It 'Maps webUrl correctly' {
            $site = [PSCustomObject]@{
                displayName = 'Test Site'
                webUrl = 'https://contoso.sharepoint.com/sites/test'
            }
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData @($site)
            $result | Should Match 'contoso.sharepoint.com'
        }

        It 'Handles missing webUrl gracefully' {
            $site = [PSCustomObject]@{
                displayName = 'Test Site'
            }
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData @($site)
            $result | Should Not Be $null
            $result | Should Match 'Test Site'
        }

        It 'Maps full URL with path' {
            $site = [PSCustomObject]@{
                displayName = 'Test Site'
                webUrl = 'https://contoso.sharepoint.com/sites/marketing/subsite'
            }
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData @($site)
            $result | Should Match 'marketing/subsite'
        }

        It 'Maps siteUrl from OneDrive Usage Report' {
            $site = [PSCustomObject]@{
                ownerDisplayName = 'Jane Smith'
                siteUrl = 'https://contoso-my.sharepoint.com/personal/jane_contoso_com'
            }
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData @($site)
            $result | Should Match 'contoso-my.sharepoint.com'
        }
    }

    Context 'Site Type Mapping - Template Based' {
        It 'Maps GROUP#0 template to Team Site' {
            $site = [PSCustomObject]@{
                displayName = 'Test Site'
                template = 'GROUP#0'
            }
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData @($site)
            $result | Should Match 'Team Site'
        }

        It 'Maps STS#3 template to Team Site' {
            $site = [PSCustomObject]@{
                displayName = 'Test Site'
                template = 'STS#3'
            }
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData @($site)
            $result | Should Match 'Team Site'
        }

        It 'Maps SITEPAGEPUBLISHING#0 template to Communication Site' {
            $site = [PSCustomObject]@{
                displayName = 'Test Site'
                template = 'SITEPAGEPUBLISHING#0'
            }
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData @($site)
            $result | Should Match 'Communication Site'
        }

        It 'Maps SPSPERS# template to OneDrive' {
            $site = [PSCustomObject]@{
                displayName = 'Test Site'
                template = 'SPSPERS#10'
            }
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData @($site)
            $result | Should Match 'OneDrive'
        }

        It 'Falls back to siteType when template is unrecognized' {
            $site = [PSCustomObject]@{
                displayName = 'Test Site'
                template = 'CUSTOM#1'
                siteType = 'CustomType'
            }
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData @($site)
            $result | Should Match 'CustomType'
        }

        It 'Uses Other when template is unrecognized and no siteType' {
            $site = [PSCustomObject]@{
                displayName = 'Test Site'
                template = 'CUSTOM#1'
            }
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData @($site)
            $result | Should Match 'Other'
        }

        It 'Template takes priority over siteType when both are present' {
            $site = [PSCustomObject]@{
                displayName = 'Test Site'
                template = 'SITEPAGEPUBLISHING#0'
                siteType = 'TeamSite'  # Should be ignored
            }
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData @($site)
            $result | Should Match 'Communication Site'
            $result | Should Not Match 'Team Site'
        }
    }

    Context 'Site Type Mapping - SiteType Based' {
        It 'Maps teamsite siteType to Team Site' {
            $site = [PSCustomObject]@{
                displayName = 'Test Site'
                siteType = 'teamsite'
            }
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData @($site)
            $result | Should Match 'Team Site'
        }

        It 'Maps TeamSite siteType (case insensitive) to Team Site' {
            $site = [PSCustomObject]@{
                displayName = 'Test Site'
                siteType = 'TeamSite'
            }
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData @($site)
            $result | Should Match 'Team Site'
        }

        It 'Maps communicationsite siteType to Communication Site' {
            $site = [PSCustomObject]@{
                displayName = 'Test Site'
                siteType = 'communicationsite'
            }
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData @($site)
            $result | Should Match 'Communication Site'
        }

        It 'Maps onedrive siteType to OneDrive' {
            $site = [PSCustomObject]@{
                displayName = 'Test Site'
                siteType = 'onedrive'
            }
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData @($site)
            $result | Should Match 'OneDrive'
        }

        It 'Uses Unknown when neither template nor siteType is present' {
            $site = [PSCustomObject]@{
                displayName = 'Test Site'
            }
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData @($site)
            $result | Should Match 'Unknown'
        }
    }

    Context 'Storage Size Conversion' {
        It 'Converts bytes to B for small values' {
            $site = [PSCustomObject]@{
                displayName = 'Test Site'
                storageUsedInBytes = 500
            }
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData @($site)
            $result | Should Match '500 B'
        }

        It 'Converts bytes to KB correctly' {
            $site = [PSCustomObject]@{
                displayName = 'Test Site'
                storageUsedInBytes = 2048  # 2 KB
            }
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData @($site)
            $result | Should Match '2.00 KB'
        }

        It 'Converts bytes to MB correctly' {
            $site = [PSCustomObject]@{
                displayName = 'Test Site'
                storageUsedInBytes = 5242880  # 5 MB
            }
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData @($site)
            $result | Should Match '5.00 MB'
        }

        It 'Converts bytes to GB correctly' {
            $site = [PSCustomObject]@{
                displayName = 'Test Site'
                storageUsedInBytes = 5368709120  # 5 GB
            }
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData @($site)
            $result | Should Match '5.00 GB'
        }

        It 'Converts bytes to TB correctly' {
            $site = [PSCustomObject]@{
                displayName = 'Test Site'
                storageUsedInBytes = 1099511627776  # 1 TB
            }
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData @($site)
            $result | Should Match '1.00 TB'
        }

        It 'Handles null storageUsedInBytes as 0' {
            $site = [PSCustomObject]@{
                displayName = 'Test Site'
            }
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData @($site)
            $result | Should Match '0 B'
        }

        It 'Handles 0 storageUsedInBytes' {
            $site = [PSCustomObject]@{
                displayName = 'Test Site'
                storageUsedInBytes = 0
            }
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData @($site)
            $result | Should Match '0 B'
        }

        It 'Handles large GB values with decimals' {
            $site = [PSCustomObject]@{
                displayName = 'Test Site'
                storageUsedInBytes = 16106127360  # 15.00 GB
            }
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData @($site)
            $result | Should Match '15.00 GB'
        }
    }

    Context 'Last Modified Date Formatting' {
        It 'Formats ISO 8601 date correctly' {
            $site = [PSCustomObject]@{
                displayName = 'Test Site'
                lastModifiedDateTime = '2024-12-14T10:30:00Z'
            }
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData @($site)
            $result | Should Match '2024-12-14'
        }

        It 'Formats date with timezone offset' {
            $site = [PSCustomObject]@{
                displayName = 'Test Site'
                lastModifiedDateTime = '2024-06-15T14:30:00+00:00'
            }
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData @($site)
            $result | Should Match '2024-06-15'
        }

        It 'Handles missing lastModifiedDateTime gracefully' {
            $site = [PSCustomObject]@{
                displayName = 'Test Site'
            }
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData @($site)
            $result | Should Not Be $null
        }

        It 'Handles date-only string' {
            $site = [PSCustomObject]@{
                displayName = 'Test Site'
                lastModifiedDateTime = '2024-12-14'
            }
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData @($site)
            $result | Should Match '2024-12-14'
        }

        It 'Maps lastActivityDate from OneDrive Usage Report' {
            $site = [PSCustomObject]@{
                ownerDisplayName = 'John Doe'
                lastActivityDate = '2024-12-20'
            }
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData @($site)
            $result | Should Match '2024-12-20'
        }
    }

    Context 'Summary Statistics' {
        It 'Shows correct total sites count for single site' {
            $site = [PSCustomObject]@{
                displayName = 'Test Site'
            }
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData @($site)
            $result | Should Match 'Total Sites: 1'
        }

        It 'Shows correct total sites count for multiple sites' {
            $sites = @(
                [PSCustomObject]@{ displayName = 'Site1' }
                [PSCustomObject]@{ displayName = 'Site2' }
                [PSCustomObject]@{ displayName = 'Site3' }
            )
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData $sites
            $result | Should Match 'Total Sites: 3'
        }

        It 'Shows total storage in summary' {
            $sites = @(
                [PSCustomObject]@{ displayName = 'Site1'; storageUsedInBytes = 1073741824 }  # 1 GB
                [PSCustomObject]@{ displayName = 'Site2'; storageUsedInBytes = 2147483648 }  # 2 GB
            )
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData $sites
            $result | Should Match 'Total Storage: 3.00 GB'
        }

        It 'Summary appears before table' {
            $site = [PSCustomObject]@{
                displayName = 'Test Site'
                storageUsedInBytes = 1073741824
            }
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData @($site)
            $summaryIndex = $result.IndexOf('Total Sites')
            $tableIndex = $result.IndexOf('"type":"table"')
            $summaryIndex | Should BeLessThan $tableIndex
        }
    }

    Context 'Timestamp (FR44)' {
        It 'Includes timestamp with UTC indicator' {
            $site = [PSCustomObject]@{
                displayName = 'Test Site'
            }
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData @($site)
            $result | Should Match 'Data as of:'
            $result | Should Match 'UTC'
        }

        It 'Timestamp appears before summary' {
            $site = [PSCustomObject]@{
                displayName = 'Test Site'
            }
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData @($site)
            $timestampIndex = $result.IndexOf('Data as of')
            $summaryIndex = $result.IndexOf('Total Sites')
            $timestampIndex | Should BeLessThan $summaryIndex
        }

        It 'Timestamp format matches yyyy-MM-dd HH:mm pattern' {
            $site = [PSCustomObject]@{
                displayName = 'Test Site'
            }
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData @($site)
            $result | Should Match 'Data as of: \d{4}-\d{2}-\d{2} \d{2}:\d{2} UTC'
        }
    }

    Context 'Table Structure' {
        It 'Creates table with Site column' {
            $site = [PSCustomObject]@{
                displayName = 'Test Site'
            }
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData @($site)
            $result | Should Match 'Site'
        }

        It 'Creates table with URL column' {
            $site = [PSCustomObject]@{
                displayName = 'Test Site'
            }
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData @($site)
            $result | Should Match 'URL'
        }

        It 'Creates table with Type column' {
            $site = [PSCustomObject]@{
                displayName = 'Test Site'
            }
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData @($site)
            $result | Should Match 'Type'
        }

        It 'Creates table with Storage column' {
            $site = [PSCustomObject]@{
                displayName = 'Test Site'
            }
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData @($site)
            $result | Should Match 'Storage'
        }

        It 'Creates table with Last Modified column' {
            $site = [PSCustomObject]@{
                displayName = 'Test Site'
            }
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData @($site)
            $result | Should Match 'Last Modified'
        }
    }

    Context 'Verbose Logging' {
        It 'Writes verbose message for transformation count' {
            $site = [PSCustomObject]@{
                displayName = 'Test Site'
            }
            $verboseOutput = ConvertTo-ConfluenceSharePointPage -SharePointData @($site) -Verbose 4>&1
            $verboseMessages = $verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }
            $verboseMessages | Should Not Be $null
        }

        It 'Writes verbose message for empty data' {
            $verboseOutput = ConvertTo-ConfluenceSharePointPage -SharePointData $null -Verbose 4>&1
            $verboseMessages = $verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }
            # Look for any verbose message that indicates empty data handling
            $verboseText = ($verboseMessages | ForEach-Object { $_.Message }) -join ' '
            ($verboseText -match 'No SharePoint data' -or $verboseText -match 'ADF document') | Should Be $true
        }

        It 'Writes verbose message with site count and storage' {
            $sites = @(
                [PSCustomObject]@{ displayName = 'Site1'; storageUsedInBytes = 1073741824 }
                [PSCustomObject]@{ displayName = 'Site2'; storageUsedInBytes = 2147483648 }
            )
            $verboseOutput = ConvertTo-ConfluenceSharePointPage -SharePointData $sites -Verbose 4>&1
            $verboseMessages = $verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }
            $verboseText = $verboseMessages.Message -join ' '
            $verboseText | Should Match '2 site'
        }
    }

    Context 'Multiple Sites' {
        It 'Processes all sites in input array' {
            $sites = @(
                [PSCustomObject]@{ displayName = 'Site Alpha' }
                [PSCustomObject]@{ displayName = 'Site Beta' }
                [PSCustomObject]@{ displayName = 'Site Gamma' }
            )
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData $sites
            $result | Should Match 'Site Alpha'
            $result | Should Match 'Site Beta'
            $result | Should Match 'Site Gamma'
        }

        It 'Calculates total storage across all sites' {
            $sites = @(
                [PSCustomObject]@{ displayName = 'Site1'; storageUsedInBytes = 1073741824 }   # 1 GB
                [PSCustomObject]@{ displayName = 'Site2'; storageUsedInBytes = 2147483648 }   # 2 GB
                [PSCustomObject]@{ displayName = 'Site3'; storageUsedInBytes = 3221225472 }   # 3 GB
            )
            $result = ConvertTo-ConfluenceSharePointPage -SharePointData $sites
            $result | Should Match 'Total Storage: 6.00 GB'
        }
    }
}
