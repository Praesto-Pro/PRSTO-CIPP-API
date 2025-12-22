$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleRoot = Split-Path -Parent (Split-Path -Parent $here)
$privateDir = Join-Path $moduleRoot 'Private'

Describe 'ConvertTo-ConfluenceClientIndex' {
    BeforeAll {
        # Dot-source required private functions
        . "$privateDir\New-ADFDocument.ps1"
        . "$privateDir\Add-ADFContent.ps1"
        . "$privateDir\ConvertTo-ADF.ps1"
        . "$privateDir\New-ADFHeading.ps1"
        . "$privateDir\New-ADFParagraph.ps1"

        # Dot-source function under test
        . "$privateDir\ConvertTo-ConfluenceClientIndex.ps1"
    }

    Context 'Basic ADF Generation' {
        It 'Returns valid JSON string' {
            $result = ConvertTo-ConfluenceClientIndex -Mappings @() -BaseURL 'https://example.atlassian.net'
            { $result | ConvertFrom-Json } | Should Not Throw
        }

        It 'Returns ADF document structure' {
            $result = ConvertTo-ConfluenceClientIndex -Mappings @() -BaseURL 'https://example.atlassian.net'
            $adf = $result | ConvertFrom-Json
            $adf.version | Should Be 1
            $adf.type | Should Be 'doc'
            $adf.content | Should Not Be $null
        }
    }

    Context 'Page Heading' {
        It 'Includes Client Spaces Index heading' {
            $result = ConvertTo-ConfluenceClientIndex -Mappings @() -BaseURL 'https://example.atlassian.net'
            $result | Should Match 'Client Spaces Index'
        }

        It 'Uses heading level 1' {
            $result = ConvertTo-ConfluenceClientIndex -Mappings @() -BaseURL 'https://example.atlassian.net'
            $adf = $result | ConvertFrom-Json
            $heading = $adf.content | Where-Object { $_.type -eq 'heading' } | Select-Object -First 1
            $heading.attrs.level | Should Be 1
        }
    }

    Context 'Timestamp' {
        It 'Includes timestamp paragraph' {
            $result = ConvertTo-ConfluenceClientIndex -Mappings @() -BaseURL 'https://example.atlassian.net'
            $result | Should Match 'Last updated:'
        }

        It 'Timestamp includes date format' {
            $result = ConvertTo-ConfluenceClientIndex -Mappings @() -BaseURL 'https://example.atlassian.net'
            $result | Should Match '\d{4}-\d{2}-\d{2}'
        }
    }

    Context 'Empty Mappings State' {
        It 'Shows no client spaces configured message when no mappings' {
            $result = ConvertTo-ConfluenceClientIndex -Mappings @() -BaseURL 'https://example.atlassian.net'
            $result | Should Match 'No client spaces configured'
        }

        It 'Does not contain table when no mappings' {
            $result = ConvertTo-ConfluenceClientIndex -Mappings @() -BaseURL 'https://example.atlassian.net'
            $adf = $result | ConvertFrom-Json
            $table = $adf.content | Where-Object { $_.type -eq 'table' }
            $table | Should Be $null
        }

        It 'Handles null Mappings parameter' {
            $result = ConvertTo-ConfluenceClientIndex -Mappings $null -BaseURL 'https://example.atlassian.net'
            $result | Should Match 'No client spaces configured'
        }
    }

    Context 'Table Generation with Mappings' {
        BeforeAll {
            $script:testMappings = @(
                [PSCustomObject]@{ TenantId = 't1'; SpaceKey = 'SPACE1'; SpaceName = 'Client One' },
                [PSCustomObject]@{ TenantId = 't2'; SpaceKey = 'SPACE2'; SpaceName = 'Client Two' }
            )
        }

        It 'Generates table when mappings provided' {
            $result = ConvertTo-ConfluenceClientIndex -Mappings $script:testMappings -BaseURL 'https://example.atlassian.net'
            $adf = $result | ConvertFrom-Json
            $table = $adf.content | Where-Object { $_.type -eq 'table' }
            $table | Should Not Be $null
        }

        It 'Table has correct number of rows (header + data rows)' {
            $result = ConvertTo-ConfluenceClientIndex -Mappings $script:testMappings -BaseURL 'https://example.atlassian.net'
            $adf = $result | ConvertFrom-Json
            $table = $adf.content | Where-Object { $_.type -eq 'table' }
            $table.content.Count | Should Be 3  # 1 header + 2 data rows
        }

        It 'Includes Client Name column header' {
            $result = ConvertTo-ConfluenceClientIndex -Mappings $script:testMappings -BaseURL 'https://example.atlassian.net'
            $result | Should Match 'Client Name'
        }

        It 'Includes Space Key column header' {
            $result = ConvertTo-ConfluenceClientIndex -Mappings $script:testMappings -BaseURL 'https://example.atlassian.net'
            $result | Should Match 'Space Key'
        }

        It 'Includes Link column header' {
            $result = ConvertTo-ConfluenceClientIndex -Mappings $script:testMappings -BaseURL 'https://example.atlassian.net'
            $result | Should Match '"text":"Link"'
        }

        It 'Includes all client names in table' {
            $result = ConvertTo-ConfluenceClientIndex -Mappings $script:testMappings -BaseURL 'https://example.atlassian.net'
            $result | Should Match 'Client One'
            $result | Should Match 'Client Two'
        }

        It 'Includes all space keys in table' {
            $result = ConvertTo-ConfluenceClientIndex -Mappings $script:testMappings -BaseURL 'https://example.atlassian.net'
            $result | Should Match 'SPACE1'
            $result | Should Match 'SPACE2'
        }
    }

    Context 'Link Generation' {
        BeforeAll {
            $script:singleMapping = @(
                [PSCustomObject]@{ TenantId = 't1'; SpaceKey = 'CONTOSO'; SpaceName = 'Contoso Corp' }
            )
        }

        It 'Generates correct space link URL' {
            $result = ConvertTo-ConfluenceClientIndex -Mappings $script:singleMapping -BaseURL 'https://example.atlassian.net'
            $result | Should Match 'https://example.atlassian.net/wiki/spaces/CONTOSO'
        }

        It 'Uses View Space as link text' {
            $result = ConvertTo-ConfluenceClientIndex -Mappings $script:singleMapping -BaseURL 'https://example.atlassian.net'
            $result | Should Match 'View Space'
        }

        It 'Creates ADF link mark structure' {
            $result = ConvertTo-ConfluenceClientIndex -Mappings $script:singleMapping -BaseURL 'https://example.atlassian.net'
            $adf = $result | ConvertFrom-Json
            # Find table cell with link mark
            $result | Should Match '"type":"link"'
            $result | Should Match '"href":'
        }

        It 'Link is clickable (has link mark with href)' {
            $result = ConvertTo-ConfluenceClientIndex -Mappings $script:singleMapping -BaseURL 'https://example.atlassian.net'
            $adf = $result | ConvertFrom-Json
            $table = $adf.content | Where-Object { $_.type -eq 'table' }
            $dataRow = $table.content | Where-Object { $_.content[0].type -eq 'tableCell' } | Select-Object -First 1
            $linkCell = $dataRow.content[2]  # Third column (Link)
            $linkContent = $linkCell.content[0].content[0]
            $linkContent.marks | Should Not Be $null
            $linkContent.marks[0].type | Should Be 'link'
            $linkContent.marks[0].attrs.href | Should Match '/wiki/spaces/'
        }
    }

    Context 'Multiple Mappings' {
        It 'Handles single mapping correctly' {
            $singleMapping = @(
                [PSCustomObject]@{ TenantId = 't1'; SpaceKey = 'SINGLE'; SpaceName = 'Single Client' }
            )
            $result = ConvertTo-ConfluenceClientIndex -Mappings $singleMapping -BaseURL 'https://example.atlassian.net'
            $adf = $result | ConvertFrom-Json
            $table = $adf.content | Where-Object { $_.type -eq 'table' }
            $table.content.Count | Should Be 2  # 1 header + 1 data row
        }

        It 'Handles many mappings correctly' {
            $manyMappings = 1..10 | ForEach-Object {
                [PSCustomObject]@{ TenantId = "t$_"; SpaceKey = "SPACE$_"; SpaceName = "Client $_" }
            }
            $result = ConvertTo-ConfluenceClientIndex -Mappings $manyMappings -BaseURL 'https://example.atlassian.net'
            $adf = $result | ConvertFrom-Json
            $table = $adf.content | Where-Object { $_.type -eq 'table' }
            $table.content.Count | Should Be 11  # 1 header + 10 data rows
        }
    }

    Context 'BaseURL Handling' {
        It 'Uses provided BaseURL in link generation' {
            $mapping = @(
                [PSCustomObject]@{ TenantId = 't1'; SpaceKey = 'TEST'; SpaceName = 'Test' }
            )
            $result = ConvertTo-ConfluenceClientIndex -Mappings $mapping -BaseURL 'https://custom.atlassian.net'
            $result | Should Match 'https://custom.atlassian.net/wiki/spaces/TEST'
        }

        It 'Does not add trailing slash to BaseURL' {
            $mapping = @(
                [PSCustomObject]@{ TenantId = 't1'; SpaceKey = 'TEST'; SpaceName = 'Test' }
            )
            $result = ConvertTo-ConfluenceClientIndex -Mappings $mapping -BaseURL 'https://example.atlassian.net'
            $result | Should Not Match 'atlassian\.net//wiki'
        }

        It 'Handles BaseURL with trailing slash' {
            $mapping = @(
                [PSCustomObject]@{ TenantId = 't1'; SpaceKey = 'TEST'; SpaceName = 'Test' }
            )
            $result = ConvertTo-ConfluenceClientIndex -Mappings $mapping -BaseURL 'https://example.atlassian.net/'
            $result | Should Not Match 'atlassian\.net//wiki'
            $result | Should Match 'https://example.atlassian.net/wiki/spaces/TEST'
        }

        It 'Requires BaseURL parameter' {
            { ConvertTo-ConfluenceClientIndex -Mappings @() } | Should Throw
        }
    }

    Context 'Verbose Logging' {
        It 'Writes verbose messages' {
            $mappings = @(
                [PSCustomObject]@{ TenantId = 't1'; SpaceKey = 'TEST'; SpaceName = 'Test' }
            )
            $verboseOutput = ConvertTo-ConfluenceClientIndex -Mappings $mappings -BaseURL 'https://example.atlassian.net' -Verbose 4>&1
            $verboseMessages = $verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }
            $verboseMessages.Count | Should BeGreaterThan 0
        }

        It 'Logs mapping count' {
            $mappings = @(
                [PSCustomObject]@{ TenantId = 't1'; SpaceKey = 'TEST'; SpaceName = 'Test' }
            )
            $verboseOutput = ConvertTo-ConfluenceClientIndex -Mappings $mappings -BaseURL 'https://example.atlassian.net' -Verbose 4>&1
            $verboseText = ($verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }).Message -join ' '
            $verboseText | Should Match '1 client'
        }
    }

    Context 'Special Characters in Client Names' {
        It 'Handles client names with special characters' {
            $mapping = @(
                [PSCustomObject]@{ TenantId = 't1'; SpaceKey = 'TEST'; SpaceName = 'Acme & Co. "Partners"' }
            )
            $result = ConvertTo-ConfluenceClientIndex -Mappings $mapping -BaseURL 'https://example.atlassian.net'
            { $result | ConvertFrom-Json } | Should Not Throw
        }

        It 'Handles client names with unicode characters' {
            $mapping = @(
                [PSCustomObject]@{ TenantId = 't1'; SpaceKey = 'TEST'; SpaceName = 'Über Technologies' }
            )
            $result = ConvertTo-ConfluenceClientIndex -Mappings $mapping -BaseURL 'https://example.atlassian.net'
            { $result | ConvertFrom-Json } | Should Not Throw
        }
    }
}
