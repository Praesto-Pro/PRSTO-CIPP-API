function ConvertTo-ConfluenceClientIndex {
    <#
    .SYNOPSIS
        Generates ADF content for the CLIENTS-INDEX page.
    .DESCRIPTION
        Takes tenant-to-space mappings and generates an ADF document with
        a table of all client spaces including clickable links.

        The generated content includes:
        - A heading "Client Spaces Index"
        - A timestamp paragraph showing when the index was last updated
        - A table with columns: Client Name, Space Key, Link (clickable)
        - Or a "No client spaces configured" message if no mappings exist
    .PARAMETER Mappings
        Array of mapping objects with TenantId, SpaceKey, SpaceName properties.
        If null or empty, generates an empty state message.
    .PARAMETER BaseURL
        The Confluence base URL for generating space links (e.g., 'https://example.atlassian.net').
    .OUTPUTS
        [string] ADF JSON content ready for Confluence API.
    .EXAMPLE
        ConvertTo-ConfluenceClientIndex -Mappings @() -BaseURL 'https://example.atlassian.net'
        Generates index with "No client spaces configured" message.
    .EXAMPLE
        $mappings = Get-ConfluenceTenantMapping
        $content = ConvertTo-ConfluenceClientIndex -Mappings $mappings -BaseURL 'https://example.atlassian.net'
        Generates index table with all client spaces.
    .NOTES
        This is a private function used internally by Update-ConfluenceClientIndex.
        Links are created using ADF link marks for clickability in Confluence UI.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [array]$Mappings,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$BaseURL
    )

    Write-Verbose "Generating CLIENTS-INDEX content for $($Mappings.Count) clients"

    $doc = New-ADFDocument

    # Page heading
    $heading = New-ADFHeading -Level 1 -Text 'Client Spaces Index'

    # Timestamp (use actual UTC time)
    $utcTime = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm')
    $timestamp = New-ADFParagraph -Text "Last updated: $utcTime UTC"

    if (-not $Mappings -or $Mappings.Count -eq 0) {
        Write-Verbose "No mappings found, generating empty state message"
        $emptyMessage = New-ADFParagraph -Text 'No client spaces configured. Use New-ConfluenceClientSpace to create your first client.'

        $doc = Add-ADFContent -Document $doc -Content @($heading, $timestamp, $emptyMessage)
    }
    else {
        Write-Verbose "Generating table with $($Mappings.Count) client entries"

        # Normalize BaseURL (remove trailing slash if present)
        $BaseURL = $BaseURL.TrimEnd('/')

        # Build table with clickable links
        # Since New-ADFTable doesn't support links, build table structure manually
        $table = @{
            type    = 'table'
            attrs   = @{
                isNumberColumnEnabled = $false
                layout                = 'default'
            }
            content = @()
        }

        # Create header row
        $headerRow = @{
            type    = 'tableRow'
            content = @(
                @{
                    type    = 'tableHeader'
                    attrs   = @{}
                    content = @(
                        @{
                            type    = 'paragraph'
                            content = @(
                                @{
                                    type = 'text'
                                    text = 'Client Name'
                                }
                            )
                        }
                    )
                },
                @{
                    type    = 'tableHeader'
                    attrs   = @{}
                    content = @(
                        @{
                            type    = 'paragraph'
                            content = @(
                                @{
                                    type = 'text'
                                    text = 'Space Key'
                                }
                            )
                        }
                    )
                },
                @{
                    type    = 'tableHeader'
                    attrs   = @{}
                    content = @(
                        @{
                            type    = 'paragraph'
                            content = @(
                                @{
                                    type = 'text'
                                    text = 'Link'
                                }
                            )
                        }
                    )
                }
            )
        }
        $table.content = @($headerRow)

        # Create data rows with clickable links
        foreach ($mapping in $Mappings) {
            $spaceURL = "$BaseURL/wiki/spaces/$($mapping.SpaceKey)"
            Write-Verbose "Adding row for '$($mapping.SpaceName)' with link to $spaceURL"

            $dataRow = @{
                type    = 'tableRow'
                content = @(
                    # Client Name cell
                    @{
                        type    = 'tableCell'
                        attrs   = @{}
                        content = @(
                            @{
                                type    = 'paragraph'
                                content = @(
                                    @{
                                        type = 'text'
                                        text = [string]$mapping.SpaceName
                                    }
                                )
                            }
                        )
                    },
                    # Space Key cell
                    @{
                        type    = 'tableCell'
                        attrs   = @{}
                        content = @(
                            @{
                                type    = 'paragraph'
                                content = @(
                                    @{
                                        type = 'text'
                                        text = [string]$mapping.SpaceKey
                                    }
                                )
                            }
                        )
                    },
                    # Link cell (clickable)
                    @{
                        type    = 'tableCell'
                        attrs   = @{}
                        content = @(
                            @{
                                type    = 'paragraph'
                                content = @(
                                    @{
                                        type  = 'text'
                                        text  = 'View Space'
                                        marks = @(
                                            @{
                                                type  = 'link'
                                                attrs = @{
                                                    href = $spaceURL
                                                }
                                            }
                                        )
                                    }
                                )
                            }
                        )
                    }
                )
            }
            $table.content += $dataRow
        }

        $doc = Add-ADFContent -Document $doc -Content @($heading, $timestamp, $table)
    }

    Write-Verbose "Generated CLIENTS-INDEX ADF content"
    return ConvertTo-ADF -InputObject $doc
}
