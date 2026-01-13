function ConvertTo-ConfluenceTeamsPage {
    <#
    .SYNOPSIS
        Transforms CIPP Teams inventory data into ADF content for Confluence pages.
    .DESCRIPTION
        Converts CIPP Teams data objects into Atlassian Document Format (ADF) content
        suitable for creating/updating Confluence pages. Displays Teams inventory with
        team names, visibility, member counts, and descriptions.

        The function:
        - Creates a summary section with total teams count
        - Creates a table showing each team's details
        - Adds a timestamp for data freshness (FR44)

        Returns an ADF JSON string that can be used directly with
        New-ConfluencePage -Body parameter.
    .PARAMETER TeamsData
        Array of CIPP Teams data objects from the Teams Report API.
        Expected properties: displayName, visibility, memberCount (or members), description.
    .OUTPUTS
        [string] - ADF JSON string ready for Confluence API
        Table columns: Team, Visibility, Members, Description
    .EXAMPLE
        $adf = ConvertTo-ConfluenceTeamsPage -TeamsData $cippTeamsReport

        Creates ADF content with Teams inventory table.
    .EXAMPLE
        $body = ConvertTo-ConfluenceTeamsPage -TeamsData $teamsData
        New-ConfluencePage -SpaceKey 'CLIENT' -Title 'Teams Inventory' -Body $body

        Creates a Confluence page with Teams inventory report.
    .NOTES
        This is a private function used internally by the ConfluenceAPI module.
        Part of Story 6.2 - Teams Inventory Transformer & Sync.

        CIPP Data Source:
        - TeamsData: CIPP Teams Report API
    .LINK
        New-ADFDocument
    .LINK
        New-ADFTable
    .LINK
        New-ADFHeading
    .LINK
        New-ADFParagraph
    .LINK
        ConvertTo-ADF
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [object[]]$TeamsData
    )

    # Handle empty/null input first
    if (-not $TeamsData -or $TeamsData.Count -eq 0) {
        Write-Verbose "No Teams data provided - returning empty state message"
        $doc = New-ADFDocument
        $heading = New-ADFHeading -Level 2 -Text 'Teams Inventory'
        # Add timestamp even for empty state (FR44 compliance)
        $utcTime = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm')
        $timestamp = New-ADFParagraph -Text "Data as of: $utcTime UTC"
        $message = New-ADFParagraph -Text 'No Teams data available'
        $doc = Add-ADFContent -Document $doc -Content @($heading, $timestamp, $message)
        return ConvertTo-ADF -InputObject $doc
    }

    Write-Verbose "Transforming $($TeamsData.Count) team record(s) to ADF content"

    # Create ADF document
    $doc = New-ADFDocument

    # Add heading
    $heading = New-ADFHeading -Level 2 -Text 'Teams Inventory'

    # Add timestamp (FR44) - use actual UTC time
    $utcTime = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm')
    $timestamp = New-ADFParagraph -Text "Data as of: $utcTime UTC"

    # Calculate summary statistics
    $totalTeams = $TeamsData.Count

    Write-Verbose "Teams inventory: $totalTeams team(s)"

    # Generate summary paragraph
    $summaryText = "Total Teams: $totalTeams"
    $summary = New-ADFParagraph -Text $summaryText

    # Transform to table format
    $tableData = foreach ($team in $TeamsData) {
        # Determine display name with fallbacks
        $teamName = if ($team.displayName) {
            $team.displayName
        } elseif ($team.id) {
            $team.id
        } else {
            'Unknown Team'
        }

        # Determine visibility with capitalization
        $visibility = if ($team.visibility) {
            $vis = $team.visibility.ToString()
            $vis.Substring(0, 1).ToUpper() + $vis.Substring(1).ToLower()
        } else {
            'Unknown'
        }

        # Determine member count with fallback to members array
        $memberCount = if ($null -ne $team.memberCount) {
            $team.memberCount
        } elseif ($team.members) {
            $team.members.Count
        } else {
            0
        }

        # Truncate description if too long (100 char limit)
        $description = if ($team.description) {
            if ($team.description.Length -gt 100) {
                $team.description.Substring(0, 97) + '...'
            } else {
                $team.description
            }
        } else {
            ''
        }

        [PSCustomObject]@{
            'Team'        = $teamName
            'Visibility'  = $visibility
            'Members'     = $memberCount
            'Description' = $description
        }
    }

    # Create table
    $table = New-ADFTable -InputObject $tableData -Property 'Team', 'Visibility', 'Members', 'Description'

    # Assemble document
    $doc = Add-ADFContent -Document $doc -Content @($heading, $timestamp, $summary, $table)

    Write-Verbose "Created Teams inventory page with $totalTeams team(s)"
    return ConvertTo-ADF -InputObject $doc
}
