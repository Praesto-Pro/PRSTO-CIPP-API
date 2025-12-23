$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$privateDir = Join-Path (Split-Path -Parent (Split-Path -Parent $here)) 'Private'

Describe 'ConvertTo-ConfluenceClientHomepage' {
    BeforeAll {
        # Dot-source the ADF helper functions
        . "$privateDir\New-ADFDocument.ps1"
        . "$privateDir\Add-ADFContent.ps1"
        . "$privateDir\ConvertTo-ADF.ps1"
        . "$privateDir\New-ADFHeading.ps1"
        . "$privateDir\New-ADFParagraph.ps1"

        # Dot-source the function under test
        . "$privateDir\ConvertTo-ConfluenceClientHomepage.ps1"
    }

    Context 'Valid Input' {
        It 'Returns valid ADF JSON string' {
            $result = ConvertTo-ConfluenceClientHomepage -ClientName 'Test Client'

            $result | Should Not Be $null
            $result | Should BeOfType [string]

            # Should be valid JSON
            { $result | ConvertFrom-Json } | Should Not Throw
        }

        It 'Includes client name in welcome heading' {
            $result = ConvertTo-ConfluenceClientHomepage -ClientName 'Contoso Corp'

            $result | Should Match 'Contoso Corp'
            $result | Should Match 'Welcome to'
        }

        It 'Includes Overview section heading' {
            $result = ConvertTo-ConfluenceClientHomepage -ClientName 'Test Client'

            $result | Should Match 'Overview'
        }

        It 'Includes User Inventory section heading' {
            $result = ConvertTo-ConfluenceClientHomepage -ClientName 'Test Client'

            $result | Should Match 'User Inventory'
        }

        It 'Includes Endpoint Inventory section heading' {
            $result = ConvertTo-ConfluenceClientHomepage -ClientName 'Test Client'

            $result | Should Match 'Endpoint Inventory'
        }

        It 'Includes License Report section heading' {
            $result = ConvertTo-ConfluenceClientHomepage -ClientName 'Test Client'

            $result | Should Match 'License Report'
        }

        It 'Includes Security Reports section heading' {
            $result = ConvertTo-ConfluenceClientHomepage -ClientName 'Test Client'

            $result | Should Match 'Security Reports'
        }

        It 'Includes Collaboration section heading' {
            $result = ConvertTo-ConfluenceClientHomepage -ClientName 'Test Client'

            $result | Should Match 'Collaboration'
        }

        It 'Includes placeholder text for Overview section' {
            $result = ConvertTo-ConfluenceClientHomepage -ClientName 'Test Client'

            $result | Should Match 'Microsoft 365 environment'
        }

        It 'Includes placeholder text for User Inventory section' {
            $result = ConvertTo-ConfluenceClientHomepage -ClientName 'Test Client'

            $result | Should Match 'User inventory data will appear here after sync'
        }

        It 'Includes placeholder text for Endpoint Inventory section' {
            $result = ConvertTo-ConfluenceClientHomepage -ClientName 'Test Client'

            $result | Should Match 'Endpoint inventory data will appear here after sync'
        }

        It 'Includes placeholder text for License Report section' {
            $result = ConvertTo-ConfluenceClientHomepage -ClientName 'Test Client'

            $result | Should Match 'License report data will appear here after sync'
        }

        It 'Includes placeholder text for Security Reports section' {
            $result = ConvertTo-ConfluenceClientHomepage -ClientName 'Test Client'

            $result | Should Match 'MFA status and security reports will appear here after sync'
        }

        It 'Includes placeholder text for Collaboration section' {
            $result = ConvertTo-ConfluenceClientHomepage -ClientName 'Test Client'

            $result | Should Match 'Teams and SharePoint inventory will appear here after sync'
        }

        It 'Returns ADF with doc type' {
            $result = ConvertTo-ConfluenceClientHomepage -ClientName 'Test Client'
            $json = $result | ConvertFrom-Json

            $json.type | Should Be 'doc'
        }

        It 'Returns ADF with version 1' {
            $result = ConvertTo-ConfluenceClientHomepage -ClientName 'Test Client'
            $json = $result | ConvertFrom-Json

            $json.version | Should Be 1
        }
    }

    Context 'Verbose Output' {
        It 'Writes verbose messages when -Verbose is used' {
            $verboseOutput = ConvertTo-ConfluenceClientHomepage -ClientName 'Test Client' -Verbose 4>&1

            $verboseMessages = $verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }
            $verboseMessages.Count | Should BeGreaterThan 0
        }

        It 'Verbose message includes client name' {
            $verboseOutput = ConvertTo-ConfluenceClientHomepage -ClientName 'Contoso Corp' -Verbose 4>&1

            $verboseText = ($verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }) -join ' '
            $verboseText | Should Match 'Contoso Corp'
        }
    }

    Context 'Special Characters in Client Name' {
        It 'Handles client name with ampersand' {
            $result = ConvertTo-ConfluenceClientHomepage -ClientName 'Smith & Jones LLC'

            $result | Should Not Be $null
            # JSON escapes special characters
            { $result | ConvertFrom-Json } | Should Not Throw
        }

        It 'Handles client name with quotes' {
            $result = ConvertTo-ConfluenceClientHomepage -ClientName 'The "Best" Company'

            $result | Should Not Be $null
            { $result | ConvertFrom-Json } | Should Not Throw
        }

        It 'Handles client name with unicode characters' {
            $result = ConvertTo-ConfluenceClientHomepage -ClientName 'Acme GmbH'

            $result | Should Not Be $null
            { $result | ConvertFrom-Json } | Should Not Throw
        }
    }
}
