function New-ADFTable {
    <#
    .SYNOPSIS
        Creates an ADF table node from PowerShell objects.
    .DESCRIPTION
        Converts an array of PSCustomObjects into an Atlassian Document Format (ADF)
        table node. Headers are derived from object property names, and rows contain
        the corresponding values.

        The table follows ADF v1 specification with proper nesting:
        table -> tableRow -> tableHeader/tableCell -> paragraph -> text

        Complex values (arrays, hashtables, objects) are automatically stringified.
        Null values are converted to empty strings.
    .PARAMETER InputObject
        One or more PSCustomObjects to convert into table rows.
        Supports pipeline input.
    .PARAMETER Property
        Optional list of property names to include as columns.
        If not specified, all properties from the first object are used.
        Columns appear in the order specified.
    .PARAMETER Layout
        Table layout mode. Valid values: 'default', 'wide', 'full-width'.
        - default: Standard table width
        - wide: Extended width (default if not specified)
        - full-width: Spans entire page width
    .OUTPUTS
        [hashtable] - ADF table node structure ready to be added to an ADF document
    .EXAMPLE
        $users = @(
            [PSCustomObject]@{ Name = 'John'; Email = 'john@example.com' }
            [PSCustomObject]@{ Name = 'Jane'; Email = 'jane@example.com' }
        )
        $table = New-ADFTable -InputObject $users

        Creates a table with Name and Email columns.
    .EXAMPLE
        $table = New-ADFTable -InputObject $users -Property Name, Status

        Creates a table with only Name and Status columns, in that order.
    .EXAMPLE
        $users | New-ADFTable

        Pipeline input creates table from piped objects.
    .NOTES
        This is a private function used internally by the ConfluenceAPI module.
        Use with Add-ADFContent to add tables to ADF documents.
    .LINK
        New-ADFDocument
    .LINK
        Add-ADFContent
    .LINK
        ConvertTo-ADF
    .LINK
        https://developer.atlassian.com/cloud/jira/platform/apis/document/nodes/table/
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Creates in-memory data structure only, no system state changes')]
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(ValueFromPipeline)]
        [object]$InputObject,

        [Parameter()]
        [string[]]$Property,

        [Parameter()]
        [ValidateSet('default', 'wide', 'full-width')]
        [string]$Layout = 'wide'
    )

    begin {
        Write-Verbose "Creating ADF table..."
        $allObjects = @()
    }

    process {
        if ($null -ne $InputObject) {
            $allObjects += $InputObject
        }
    }

    end {
        Write-Verbose "Processing $($allObjects.Count) object(s) for table generation"

        # Initialize table structure
        $table = @{
            type    = 'table'
            attrs   = @{
                isNumberColumnEnabled = $false
                layout                = $Layout
            }
            content = @()
        }

        # Handle empty/null input
        if ($allObjects.Count -eq 0) {
            Write-Verbose "Empty input - returning table with no rows"
            # If Property is specified, create headers-only table
            if ($Property -and $Property.Count -gt 0) {
                Write-Verbose "Creating headers-only table with specified properties: $($Property -join ', ')"
                $headerRow = New-ADFTableHeaderRow -Properties $Property
                $table.content = @($headerRow)
            }
            return $table
        }

        # Determine columns from first object or Property parameter
        $columns = @()
        if ($Property -and $Property.Count -gt 0) {
            Write-Verbose "Using specified properties: $($Property -join ', ')"
            $columns = $Property
        }
        else {
            # Get properties from first object
            $firstObject = $allObjects[0]
            if ($firstObject -is [hashtable]) {
                $columns = @($firstObject.Keys | Sort-Object)
            }
            elseif ($firstObject -is [PSCustomObject]) {
                $columns = @($firstObject.PSObject.Properties.Name)
            }
            else {
                # Fallback for other object types
                $columns = @($firstObject | Get-Member -MemberType Properties | Select-Object -ExpandProperty Name)
            }
            Write-Verbose "Extracted properties from first object: $($columns -join ', ')"
        }

        # Filter out empty strings from columns array
        $columns = @($columns | Where-Object { $_ -and $_.Trim() })

        if ($columns.Count -eq 0) {
            Write-Verbose "No properties found - returning empty table"
            return $table
        }

        # Create header row
        $headerRow = New-ADFTableHeaderRow -Properties $columns
        $table.content = @($headerRow)

        # Create data rows
        foreach ($obj in $allObjects) {
            $dataRow = New-ADFTableDataRow -InputObject $obj -Properties $columns
            $table.content += $dataRow
        }

        Write-Verbose "Created table with $($columns.Count) column(s) and $($allObjects.Count) data row(s)"
        return $table
    }
}

function New-ADFTableHeaderRow {
    <#
    .SYNOPSIS
        Creates an ADF table header row.
    .DESCRIPTION
        Internal helper function that creates a tableRow containing tableHeader cells.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Creates in-memory data structure only, no system state changes')]
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string[]]$Properties
    )

    $headerCells = @()
    foreach ($prop in $Properties) {
        $headerCell = @{
            type    = 'tableHeader'
            attrs   = @{}
            content = @(
                @{
                    type    = 'paragraph'
                    content = @(
                        @{
                            type = 'text'
                            text = [string]$prop
                        }
                    )
                }
            )
        }
        $headerCells += $headerCell
    }

    return @{
        type    = 'tableRow'
        content = $headerCells
    }
}

function New-ADFTableDataRow {
    <#
    .SYNOPSIS
        Creates an ADF table data row.
    .DESCRIPTION
        Internal helper function that creates a tableRow containing tableCell nodes.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Creates in-memory data structure only, no system state changes')]
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [object]$InputObject,

        [Parameter(Mandatory)]
        [string[]]$Properties
    )

    $dataCells = @()
    foreach ($prop in $Properties) {
        # Get property value
        $value = $null
        if ($InputObject -is [hashtable]) {
            if ($InputObject.ContainsKey($prop)) {
                $value = $InputObject[$prop]
            }
        }
        elseif ($InputObject -is [PSCustomObject]) {
            $value = $InputObject.$prop
        }
        else {
            # Try to get property dynamically
            try {
                $value = $InputObject.$prop
            }
            catch {
                $value = $null
            }
        }

        # Stringify the value
        $cellText = ConvertTo-CellValue -Value $value

        $dataCell = @{
            type    = 'tableCell'
            attrs   = @{}
            content = @(
                @{
                    type    = 'paragraph'
                    content = @(
                        @{
                            type = 'text'
                            text = $cellText
                        }
                    )
                }
            )
        }
        $dataCells += $dataCell
    }

    return @{
        type    = 'tableRow'
        content = $dataCells
    }
}

function ConvertTo-CellValue {
    <#
    .SYNOPSIS
        Converts a value to a string suitable for an ADF table cell.
    .DESCRIPTION
        Internal helper function that stringifies values for table cells.
        - Null values become empty string
        - Arrays become comma-separated strings
        - Hashtables/Objects become JSON representation
        - Other types are converted via [string]
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [object]$Value
    )

    if ($null -eq $Value) {
        return ''
    }

    if ($Value -is [array]) {
        return ($Value -join ', ')
    }

    if ($Value -is [hashtable] -or $Value -is [System.Collections.IDictionary]) {
        return ($Value | ConvertTo-Json -Compress -Depth 5)
    }

    if ($Value -is [PSCustomObject]) {
        return ($Value | ConvertTo-Json -Compress -Depth 5)
    }

    return [string]$Value
}
