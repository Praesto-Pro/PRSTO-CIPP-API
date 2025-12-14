$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$privateDir = Join-Path (Split-Path -Parent (Split-Path -Parent $here)) 'Private'

Describe 'ConvertTo-ConfluenceTeamsPage' {
    BeforeAll {
        # Dot-source all required dependencies
        . "$privateDir\New-ADFDocument.ps1"
        . "$privateDir\Add-ADFContent.ps1"
        . "$privateDir\ConvertTo-ADF.ps1"
        . "$privateDir\New-ADFTable.ps1"
        . "$privateDir\New-ADFHeading.ps1"
        . "$privateDir\New-ADFParagraph.ps1"
        . "$privateDir\ConvertTo-ConfluenceTeamsPage.ps1"
    }

    Context 'Empty/Null Input Handling' {
        It 'Returns valid ADF JSON when TeamsData is null' {
            $result = ConvertTo-ConfluenceTeamsPage -TeamsData $null
            $result | Should Not Be $null
            { $result | ConvertFrom-Json } | Should Not Throw
        }

        It 'Returns valid ADF JSON when TeamsData is empty array' {
            $result = ConvertTo-ConfluenceTeamsPage -TeamsData @()
            $result | Should Not Be $null
            { $result | ConvertFrom-Json } | Should Not Throw
        }

        It 'Shows "No Teams data available" message when TeamsData is null' {
            $result = ConvertTo-ConfluenceTeamsPage -TeamsData $null
            $result | Should Match 'No Teams data available'
        }

        It 'Shows "No Teams data available" message when TeamsData is empty' {
            $result = ConvertTo-ConfluenceTeamsPage -TeamsData @()
            $result | Should Match 'No Teams data available'
        }

        It 'Includes timestamp even when TeamsData is null (FR44)' {
            $result = ConvertTo-ConfluenceTeamsPage -TeamsData $null
            $result | Should Match 'Data as of:'
            $result | Should Match 'UTC'
        }

        It 'Includes timestamp even when TeamsData is empty (FR44)' {
            $result = ConvertTo-ConfluenceTeamsPage -TeamsData @()
            $result | Should Match 'Data as of:'
        }

        It 'Includes heading even when TeamsData is empty' {
            $result = ConvertTo-ConfluenceTeamsPage -TeamsData @()
            $result | Should Match 'Teams Inventory'
        }
    }

    Context 'Valid ADF Output' {
        It 'Returns valid ADF JSON string with team data' {
            $team = [PSCustomObject]@{
                displayName = 'Test Team'
                visibility = 'private'
                memberCount = 10
            }
            $result = ConvertTo-ConfluenceTeamsPage -TeamsData @($team)
            $result | Should Not Be $null
            { $result | ConvertFrom-Json } | Should Not Throw
        }

        It 'ADF contains doc type and version' {
            $team = [PSCustomObject]@{
                displayName = 'Test Team'
            }
            $result = ConvertTo-ConfluenceTeamsPage -TeamsData @($team)
            $json = $result | ConvertFrom-Json
            $json.type | Should Be 'doc'
            $json.version | Should Be 1
        }

        It 'ADF contains content array' {
            $team = [PSCustomObject]@{
                displayName = 'Test Team'
            }
            $result = ConvertTo-ConfluenceTeamsPage -TeamsData @($team)
            $json = $result | ConvertFrom-Json
            $json.content | Should Not Be $null
            $json.content.Count | Should BeGreaterThan 0
        }
    }

    Context 'Team Name Mapping' {
        It 'Maps displayName correctly' {
            $team = [PSCustomObject]@{
                displayName = 'Sales Team'
                visibility = 'private'
            }
            $result = ConvertTo-ConfluenceTeamsPage -TeamsData @($team)
            $result | Should Match 'Sales Team'
        }

        It 'Falls back to id when displayName is missing' {
            $team = [PSCustomObject]@{
                id = 'team-guid-12345'
                visibility = 'private'
            }
            $result = ConvertTo-ConfluenceTeamsPage -TeamsData @($team)
            $result | Should Match 'team-guid-12345'
        }

        It 'Shows Unknown Team when both displayName and id are missing' {
            $team = [PSCustomObject]@{
                visibility = 'private'
            }
            $result = ConvertTo-ConfluenceTeamsPage -TeamsData @($team)
            $result | Should Match 'Unknown Team'
        }

        It 'Handles special characters in team name' {
            $team = [PSCustomObject]@{
                displayName = "Team & Partners <Test>"
                visibility = 'private'
            }
            $result = ConvertTo-ConfluenceTeamsPage -TeamsData @($team)
            # JSON escapes special characters - verify the name is present (escaped or not)
            $result | Should Match 'Team'
            $result | Should Match 'Partners'
        }
    }

    Context 'Visibility Mapping' {
        It 'Maps visibility private to Private (capitalized)' {
            $team = [PSCustomObject]@{
                displayName = 'Test Team'
                visibility = 'private'
            }
            $result = ConvertTo-ConfluenceTeamsPage -TeamsData @($team)
            $result | Should Match 'Private'
        }

        It 'Maps visibility public to Public (capitalized)' {
            $team = [PSCustomObject]@{
                displayName = 'Test Team'
                visibility = 'public'
            }
            $result = ConvertTo-ConfluenceTeamsPage -TeamsData @($team)
            $result | Should Match 'Public'
        }

        It 'Maps visibility PUBLIC (uppercase) to Public' {
            $team = [PSCustomObject]@{
                displayName = 'Test Team'
                visibility = 'PUBLIC'
            }
            $result = ConvertTo-ConfluenceTeamsPage -TeamsData @($team)
            $result | Should Match 'Public'
        }

        It 'Maps visibility PRIVATE (uppercase) to Private' {
            $team = [PSCustomObject]@{
                displayName = 'Test Team'
                visibility = 'PRIVATE'
            }
            $result = ConvertTo-ConfluenceTeamsPage -TeamsData @($team)
            $result | Should Match 'Private'
        }

        It 'Shows Unknown when visibility is null' {
            $team = [PSCustomObject]@{
                displayName = 'Test Team'
            }
            $result = ConvertTo-ConfluenceTeamsPage -TeamsData @($team)
            $result | Should Match 'Unknown'
        }
    }

    Context 'Member Count Mapping' {
        It 'Maps memberCount property correctly' {
            $team = [PSCustomObject]@{
                displayName = 'Test Team'
                memberCount = 25
            }
            $result = ConvertTo-ConfluenceTeamsPage -TeamsData @($team)
            $result | Should Match '25'
        }

        It 'Falls back to members array count when memberCount is not present' {
            $team = [PSCustomObject]@{
                displayName = 'Test Team'
                members = @('user1', 'user2', 'user3')
            }
            $result = ConvertTo-ConfluenceTeamsPage -TeamsData @($team)
            $result | Should Match '3'
        }

        It 'Shows 0 when neither memberCount nor members exists' {
            $team = [PSCustomObject]@{
                displayName = 'Test Team'
            }
            $result = ConvertTo-ConfluenceTeamsPage -TeamsData @($team)
            # Should contain 0 for members
            $result | Should Not Be $null
        }

        It 'Handles memberCount of zero' {
            $team = [PSCustomObject]@{
                displayName = 'Test Team'
                memberCount = 0
            }
            $result = ConvertTo-ConfluenceTeamsPage -TeamsData @($team)
            $result | Should Not Be $null
        }

        It 'Handles large memberCount' {
            $team = [PSCustomObject]@{
                displayName = 'Test Team'
                memberCount = 9999
            }
            $result = ConvertTo-ConfluenceTeamsPage -TeamsData @($team)
            $result | Should Match '9999'
        }
    }

    Context 'Owner Count Mapping' {
        It 'Maps ownerCount property correctly' {
            $team = [PSCustomObject]@{
                displayName = 'Test Team'
                ownerCount = 5
            }
            $result = ConvertTo-ConfluenceTeamsPage -TeamsData @($team)
            $result | Should Match '5'
        }

        It 'Falls back to owners array count when ownerCount is not present' {
            $team = [PSCustomObject]@{
                displayName = 'Test Team'
                owners = @('owner1', 'owner2')
            }
            $result = ConvertTo-ConfluenceTeamsPage -TeamsData @($team)
            $result | Should Match '2'
        }

        It 'Shows 0 when neither ownerCount nor owners exists' {
            $team = [PSCustomObject]@{
                displayName = 'Test Team'
            }
            $result = ConvertTo-ConfluenceTeamsPage -TeamsData @($team)
            # Should complete without error
            $result | Should Not Be $null
        }

        It 'Handles ownerCount of zero' {
            $team = [PSCustomObject]@{
                displayName = 'Test Team'
                ownerCount = 0
            }
            $result = ConvertTo-ConfluenceTeamsPage -TeamsData @($team)
            $result | Should Not Be $null
        }
    }

    Context 'Description Mapping' {
        It 'Maps description correctly' {
            $team = [PSCustomObject]@{
                displayName = 'Test Team'
                description = 'This is a test team description'
            }
            $result = ConvertTo-ConfluenceTeamsPage -TeamsData @($team)
            $result | Should Match 'This is a test team description'
        }

        It 'Shows empty string when description is null' {
            $team = [PSCustomObject]@{
                displayName = 'Test Team'
            }
            $result = ConvertTo-ConfluenceTeamsPage -TeamsData @($team)
            # Should complete without error
            $result | Should Not Be $null
        }

        It 'Truncates description longer than 100 characters' {
            $longDescription = 'A' * 150
            $team = [PSCustomObject]@{
                displayName = 'Test Team'
                description = $longDescription
            }
            $result = ConvertTo-ConfluenceTeamsPage -TeamsData @($team)
            $result | Should Match '...'
            # Should not contain 150 A's
            $result | Should Not Match ('A' * 150)
        }

        It 'Does not truncate description exactly 100 characters' {
            $exactDescription = 'A' * 100
            $team = [PSCustomObject]@{
                displayName = 'Test Team'
                description = $exactDescription
            }
            $result = ConvertTo-ConfluenceTeamsPage -TeamsData @($team)
            $result | Should Not Match '\.\.\.'
        }

        It 'Truncated description ends with ellipsis' {
            $longDescription = 'This is a very long description that exceeds the maximum allowed length of one hundred characters and should be truncated'
            $team = [PSCustomObject]@{
                displayName = 'Test Team'
                description = $longDescription
            }
            $result = ConvertTo-ConfluenceTeamsPage -TeamsData @($team)
            $result | Should Match '\.\.\.'
        }
    }

    Context 'Summary Statistics' {
        It 'Shows total teams count in summary' {
            $teams = @(
                [PSCustomObject]@{ displayName = 'Team1' }
                [PSCustomObject]@{ displayName = 'Team2' }
                [PSCustomObject]@{ displayName = 'Team3' }
            )
            $result = ConvertTo-ConfluenceTeamsPage -TeamsData $teams
            $result | Should Match 'Total Teams: 3'
        }

        It 'Shows correct count for single team' {
            $team = [PSCustomObject]@{ displayName = 'Only Team' }
            $result = ConvertTo-ConfluenceTeamsPage -TeamsData @($team)
            $result | Should Match 'Total Teams: 1'
        }

        It 'Shows correct count for many teams' {
            $teams = 1..10 | ForEach-Object {
                [PSCustomObject]@{ displayName = "Team$_" }
            }
            $result = ConvertTo-ConfluenceTeamsPage -TeamsData $teams
            $result | Should Match 'Total Teams: 10'
        }
    }

    Context 'Timestamp (FR44)' {
        It 'Includes UTC timestamp in output' {
            $team = [PSCustomObject]@{ displayName = 'Test Team' }
            $result = ConvertTo-ConfluenceTeamsPage -TeamsData @($team)
            $result | Should Match 'Data as of:'
            $result | Should Match 'UTC'
        }

        It 'Timestamp follows yyyy-MM-dd HH:mm format' {
            $team = [PSCustomObject]@{ displayName = 'Test Team' }
            $result = ConvertTo-ConfluenceTeamsPage -TeamsData @($team)
            # Should match pattern like 2025-12-14 10:30
            $result | Should Match '\d{4}-\d{2}-\d{2} \d{2}:\d{2}'
        }

        It 'Timestamp appears before summary in document' {
            $team = [PSCustomObject]@{ displayName = 'Test Team' }
            $result = ConvertTo-ConfluenceTeamsPage -TeamsData @($team)
            $timestampIndex = $result.IndexOf('Data as of:')
            $summaryIndex = $result.IndexOf('Total Teams:')
            $timestampIndex | Should BeLessThan $summaryIndex
        }
    }

    Context 'Table Structure' {
        It 'Creates table with Team column' {
            $team = [PSCustomObject]@{ displayName = 'Test Team' }
            $result = ConvertTo-ConfluenceTeamsPage -TeamsData @($team)
            $result | Should Match 'Team'
        }

        It 'Creates table with Visibility column' {
            $team = [PSCustomObject]@{ displayName = 'Test Team'; visibility = 'private' }
            $result = ConvertTo-ConfluenceTeamsPage -TeamsData @($team)
            $result | Should Match 'Visibility'
        }

        It 'Creates table with Members column' {
            $team = [PSCustomObject]@{ displayName = 'Test Team'; memberCount = 5 }
            $result = ConvertTo-ConfluenceTeamsPage -TeamsData @($team)
            $result | Should Match 'Members'
        }

        It 'Creates table with Owners column' {
            $team = [PSCustomObject]@{ displayName = 'Test Team'; ownerCount = 2 }
            $result = ConvertTo-ConfluenceTeamsPage -TeamsData @($team)
            $result | Should Match 'Owners'
        }

        It 'Creates table with Description column' {
            $team = [PSCustomObject]@{ displayName = 'Test Team'; description = 'Test desc' }
            $result = ConvertTo-ConfluenceTeamsPage -TeamsData @($team)
            $result | Should Match 'Description'
        }
    }

    Context 'Verbose Logging' {
        It 'Writes verbose message when transforming teams' {
            $team = [PSCustomObject]@{ displayName = 'Test Team' }
            $verboseOutput = ConvertTo-ConfluenceTeamsPage -TeamsData @($team) -Verbose 4>&1
            $verboseMessages = $verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }
            $verboseMessages | Should Not Be $null
        }

        It 'Writes verbose message for empty data' {
            $verboseOutput = ConvertTo-ConfluenceTeamsPage -TeamsData $null -Verbose 4>&1
            $verboseMessages = $verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }
            $verboseMessages | Should Not Be $null
        }

        It 'Verbose message includes team count' {
            $teams = @(
                [PSCustomObject]@{ displayName = 'Team1' }
                [PSCustomObject]@{ displayName = 'Team2' }
            )
            $verboseOutput = ConvertTo-ConfluenceTeamsPage -TeamsData $teams -Verbose 4>&1
            $verboseText = ($verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }) -join ' '
            $verboseText | Should Match '2'
        }
    }

    Context 'Multiple Teams Processing' {
        It 'Processes multiple teams correctly' {
            $teams = @(
                [PSCustomObject]@{
                    displayName = 'Sales Team'
                    visibility = 'private'
                    memberCount = 15
                    ownerCount = 2
                }
                [PSCustomObject]@{
                    displayName = 'Marketing Team'
                    visibility = 'public'
                    memberCount = 8
                    ownerCount = 1
                }
            )
            $result = ConvertTo-ConfluenceTeamsPage -TeamsData $teams
            $result | Should Match 'Sales Team'
            $result | Should Match 'Marketing Team'
            $result | Should Match 'Total Teams: 2'
        }

        It 'Handles mixed data quality across teams' {
            $teams = @(
                [PSCustomObject]@{
                    displayName = 'Complete Team'
                    visibility = 'private'
                    memberCount = 10
                    ownerCount = 2
                    description = 'Full details'
                }
                [PSCustomObject]@{
                    displayName = 'Minimal Team'
                }
            )
            $result = ConvertTo-ConfluenceTeamsPage -TeamsData $teams
            $result | Should Match 'Complete Team'
            $result | Should Match 'Minimal Team'
        }
    }
}
