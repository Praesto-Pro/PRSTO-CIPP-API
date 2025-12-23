# Tests for New-ADFTable private function
# Pester 3.4.0+ syntax for Windows PowerShell 5.1 compatibility

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
$functionPath = "$here\..\..\Private\$sut"
$privateDir = "$here\..\..\Private"

Describe 'New-ADFTable' {
    BeforeAll {
        # Import the function directly for testing private function
        . $functionPath
        # Also import ConvertTo-ADF for integration tests
        . "$privateDir\New-ADFDocument.ps1"
        . "$privateDir\Add-ADFContent.ps1"
        . "$privateDir\ConvertTo-ADF.ps1"
    }

    Context 'Module Integration' {
        It 'Function file exists at expected path' {
            Test-Path $functionPath | Should Be $true
        }

        It 'Function is callable after dot-sourcing' {
            { New-ADFTable -InputObject @() } | Should Not Throw
        }
    }

    Context 'AC1: Create ADF Table from PowerShell Objects' {
        It 'Returns a hashtable' {
            $users = @([PSCustomObject]@{ Name = 'John'; Email = 'john@test.com' })
            $result = New-ADFTable -InputObject $users
            $result.GetType().Name | Should Be 'Hashtable'
        }

        It 'Returns type=table' {
            $users = @([PSCustomObject]@{ Name = 'John'; Email = 'john@test.com' })
            $result = New-ADFTable -InputObject $users
            $result.type | Should Be 'table'
        }

        It 'Has content array' {
            $users = @([PSCustomObject]@{ Name = 'John'; Email = 'john@test.com' })
            $result = New-ADFTable -InputObject $users
            $result.ContainsKey('content') | Should Be $true
            ($result.content -is [array]) | Should Be $true
        }

        It 'Has attrs with isNumberColumnEnabled and layout' {
            $users = @([PSCustomObject]@{ Name = 'John' })
            $result = New-ADFTable -InputObject $users
            $result.ContainsKey('attrs') | Should Be $true
            $result.attrs.isNumberColumnEnabled | Should Be $false
            $result.attrs.layout | Should Be 'default'
        }

        It 'Creates header row from property names' {
            $users = @([PSCustomObject]@{ Name = 'John'; Email = 'john@test.com' })
            $result = New-ADFTable -InputObject $users
            # First row should be header row
            $headerRow = $result.content[0]
            $headerRow.type | Should Be 'tableRow'
            # Header cells should be tableHeader type
            $headerRow.content[0].type | Should Be 'tableHeader'
        }

        It 'Creates data rows with object values' {
            $users = @([PSCustomObject]@{ Name = 'John'; Email = 'john@test.com' })
            $result = New-ADFTable -InputObject $users
            # Second row should be data row
            $dataRow = $result.content[1]
            $dataRow.type | Should Be 'tableRow'
            # Data cells should be tableCell type
            $dataRow.content[0].type | Should Be 'tableCell'
        }

        It 'Creates multiple data rows for multiple objects' {
            $users = @(
                [PSCustomObject]@{ Name = 'John' }
                [PSCustomObject]@{ Name = 'Jane' }
                [PSCustomObject]@{ Name = 'Bob' }
            )
            $result = New-ADFTable -InputObject $users
            # 1 header row + 3 data rows = 4 rows
            $result.content.Count | Should Be 4
        }

        It 'Cell contains paragraph with text node' {
            $users = @([PSCustomObject]@{ Name = 'John' })
            $result = New-ADFTable -InputObject $users
            # Check data cell structure: tableCell -> paragraph -> text
            $dataRow = $result.content[1]
            $cell = $dataRow.content[0]
            $cell.content[0].type | Should Be 'paragraph'
            $cell.content[0].content[0].type | Should Be 'text'
            $cell.content[0].content[0].text | Should Be 'John'
        }
    }

    Context 'AC2: Specify Columns via Property Parameter' {
        It 'Only includes specified properties when -Property is used' {
            $users = @([PSCustomObject]@{ Name = 'John'; Email = 'john@test.com'; Status = 'Active' })
            $result = New-ADFTable -InputObject $users -Property Name, Status

            $headerRow = $result.content[0]
            # Should have exactly 2 columns
            $headerRow.content.Count | Should Be 2
        }

        It 'Columns appear in order specified by -Property' {
            $users = @([PSCustomObject]@{ A = '1'; B = '2'; C = '3' })
            $result = New-ADFTable -InputObject $users -Property C, A, B

            $headerRow = $result.content[0]
            # Get header text values
            $headerTexts = $headerRow.content | ForEach-Object { $_.content[0].content[0].text }
            $headerTexts[0] | Should Be 'C'
            $headerTexts[1] | Should Be 'A'
            $headerTexts[2] | Should Be 'B'
        }

        It 'Properties not in -Property list are excluded' {
            $users = @([PSCustomObject]@{ Name = 'John'; Email = 'john@test.com'; Secret = 'hidden' })
            $result = New-ADFTable -InputObject $users -Property Name, Email

            $headerRow = $result.content[0]
            $headerTexts = $headerRow.content | ForEach-Object { $_.content[0].content[0].text }
            $headerTexts -contains 'Secret' | Should Be $false
        }
    }

    Context 'AC3: Handle Complex/Nested Data' {
        It 'Arrays are converted to comma-separated strings' {
            $users = @([PSCustomObject]@{ Name = 'John'; Tags = @('admin', 'user', 'guest') })
            $result = New-ADFTable -InputObject $users

            $dataRow = $result.content[1]
            # Find the Tags cell (second column since Name is first)
            $tagsCell = $dataRow.content | Where-Object {
                $_.content[0].content[0].text -eq 'admin, user, guest'
            }
            $tagsCell | Should Not Be $null
        }

        It 'Hashtables are converted to JSON-like string representation' {
            $users = @([PSCustomObject]@{ Name = 'John'; Config = @{ Key = 'Value' } })
            $result = New-ADFTable -InputObject $users

            $dataRow = $result.content[1]
            # Config cell should contain JSON representation
            $configCell = $dataRow.content | Where-Object {
                $_.content[0].content[0].text -match 'Key.*Value'
            }
            $configCell | Should Not Be $null
        }

        It 'Nested objects are converted to JSON-like string representation' {
            $nested = [PSCustomObject]@{ Inner = 'data' }
            $users = @([PSCustomObject]@{ Name = 'John'; Nested = $nested })
            $result = New-ADFTable -InputObject $users

            $dataRow = $result.content[1]
            $nestedCell = $dataRow.content | Where-Object {
                $_.content[0].content[0].text -match 'Inner.*data'
            }
            $nestedCell | Should Not Be $null
        }

        It 'Null values display as empty string' {
            $users = @([PSCustomObject]@{ Name = 'John'; Email = $null })
            $result = New-ADFTable -InputObject $users

            $dataRow = $result.content[1]
            # Find the empty cell (Email column)
            $emptyCell = $dataRow.content | Where-Object {
                $_.content[0].content[0].text -eq ''
            }
            $emptyCell | Should Not Be $null
        }

        It 'Null values do not display as "null" string' {
            $users = @([PSCustomObject]@{ Name = 'John'; Email = $null })
            $result = New-ADFTable -InputObject $users

            $dataRow = $result.content[1]
            # No cell should contain literal "null" string
            $nullCell = $dataRow.content | Where-Object {
                $_.content[0].content[0].text -eq 'null'
            }
            $nullCell | Should Be $null
        }
    }

    Context 'AC4: Single Object Support' {
        It 'Handles single PSCustomObject (not array)' {
            $singleUser = [PSCustomObject]@{ Name = 'John'; Email = 'john@test.com' }
            { New-ADFTable -InputObject $singleUser } | Should Not Throw
        }

        It 'Creates table with one data row for single object' {
            $singleUser = [PSCustomObject]@{ Name = 'John'; Email = 'john@test.com' }
            $result = New-ADFTable -InputObject $singleUser

            # 1 header row + 1 data row = 2 rows
            $result.content.Count | Should Be 2
        }

        It 'Single object creates correct data' {
            $singleUser = [PSCustomObject]@{ Name = 'SingleUser' }
            $result = New-ADFTable -InputObject $singleUser

            $dataRow = $result.content[1]
            $dataRow.content[0].content[0].content[0].text | Should Be 'SingleUser'
        }
    }

    Context 'AC5: Empty Input Handling' {
        It 'Empty array returns valid empty table' {
            { New-ADFTable -InputObject @() } | Should Not Throw
        }

        It 'Empty array returns table with no rows' {
            $result = New-ADFTable -InputObject @()
            $result.type | Should Be 'table'
            $result.content.Count | Should Be 0
        }

        It 'Null input returns valid empty table' {
            { New-ADFTable -InputObject $null } | Should Not Throw
        }

        It 'Null input returns table with type=table' {
            $result = New-ADFTable -InputObject $null
            $result.type | Should Be 'table'
        }

        It 'Empty input with -Property creates headers-only table' {
            $result = New-ADFTable -InputObject @() -Property Name, Email

            $result.content.Count | Should Be 1
            $headerRow = $result.content[0]
            $headerRow.content.Count | Should Be 2
            $headerRow.content[0].type | Should Be 'tableHeader'
        }
    }

    Context 'AC6: Integration with ConvertTo-ADF' {
        It 'Table can be passed to ConvertTo-ADF' {
            $users = @([PSCustomObject]@{ Name = 'John' })
            $table = New-ADFTable -InputObject $users
            { ConvertTo-ADF -InputObject $table } | Should Not Throw
        }

        It 'ConvertTo-ADF produces valid JSON with table' {
            $users = @([PSCustomObject]@{ Name = 'John'; Email = 'john@test.com' })
            $table = New-ADFTable -InputObject $users
            $json = ConvertTo-ADF -InputObject $table

            # Should be valid JSON
            { $json | ConvertFrom-Json } | Should Not Throw
        }

        It 'ConvertTo-ADF JSON contains table node' {
            $users = @([PSCustomObject]@{ Name = 'John' })
            $table = New-ADFTable -InputObject $users
            $json = ConvertTo-ADF -InputObject $table
            $parsed = $json | ConvertFrom-Json

            $parsed.type | Should Be 'doc'
            $parsed.content[0].type | Should Be 'table'
        }

        It 'Deeply nested table structure is preserved in JSON' {
            $users = @([PSCustomObject]@{ Name = 'John' })
            $table = New-ADFTable -InputObject $users
            $json = ConvertTo-ADF -InputObject $table
            $parsed = $json | ConvertFrom-Json

            # Navigate: doc -> content[0] (table) -> content[1] (data row) -> content[0] (cell) -> content[0] (paragraph) -> content[0] (text)
            $textNode = $parsed.content[0].content[1].content[0].content[0].content[0]
            $textNode.type | Should Be 'text'
            $textNode.text | Should Be 'John'
        }

        It 'JSON does not contain System.Object[] truncation' {
            $users = @([PSCustomObject]@{ Name = 'John'; Email = 'john@test.com' })
            $table = New-ADFTable -InputObject $users
            $json = ConvertTo-ADF -InputObject $table

            $json | Should Not Match 'System\.Object\[\]'
        }

        It 'Table integrates with Add-ADFContent in document' {
            $doc = New-ADFDocument
            $users = @([PSCustomObject]@{ Name = 'John' })
            $table = New-ADFTable -InputObject $users
            $doc = Add-ADFContent -Document $doc -Content $table
            $json = ConvertTo-ADF -InputObject $doc

            $parsed = $json | ConvertFrom-Json
            $parsed.content[0].type | Should Be 'table'
        }
    }

    Context 'Pipeline Support' {
        It 'Accepts pipeline input' {
            $users = @(
                [PSCustomObject]@{ Name = 'John' }
                [PSCustomObject]@{ Name = 'Jane' }
            )
            { $users | New-ADFTable } | Should Not Throw
        }

        It 'Pipeline creates correct row count' {
            $users = @(
                [PSCustomObject]@{ Name = 'User1' }
                [PSCustomObject]@{ Name = 'User2' }
                [PSCustomObject]@{ Name = 'User3' }
            )
            $result = $users | New-ADFTable

            # 1 header + 3 data rows
            $result.content.Count | Should Be 4
        }
    }

    Context 'Hashtable Input Support' {
        It 'Accepts hashtable objects' {
            $data = @(
                @{ Name = 'John'; Email = 'john@test.com' }
            )
            { New-ADFTable -InputObject $data } | Should Not Throw
        }

        It 'Creates table from hashtable data' {
            $data = @(
                @{ Name = 'John'; Email = 'john@test.com' }
            )
            $result = New-ADFTable -InputObject $data

            $result.type | Should Be 'table'
            # Header + 1 data row
            $result.content.Count | Should Be 2
        }
    }

    Context 'Edge Cases' {
        It 'Handles objects with no properties gracefully' {
            $empty = [PSCustomObject]@{}
            $result = New-ADFTable -InputObject $empty
            $result.type | Should Be 'table'
        }

        It 'Handles mixed content types in arrays' {
            $mixed = @(
                [PSCustomObject]@{ Value = 123 }
                [PSCustomObject]@{ Value = 'text' }
                [PSCustomObject]@{ Value = $true }
            )
            { New-ADFTable -InputObject $mixed } | Should Not Throw
        }

        It 'Boolean values are stringified correctly' {
            $data = @([PSCustomObject]@{ Active = $true; Disabled = $false })
            $result = New-ADFTable -InputObject $data

            $dataRow = $result.content[1]
            $cellTexts = $dataRow.content | ForEach-Object { $_.content[0].content[0].text }
            $cellTexts -contains 'True' | Should Be $true
            $cellTexts -contains 'False' | Should Be $true
        }

        It 'Numeric values are stringified correctly' {
            $data = @([PSCustomObject]@{ Count = 42; Price = 19.99 })
            $result = New-ADFTable -InputObject $data

            $dataRow = $result.content[1]
            $cellTexts = $dataRow.content | ForEach-Object { $_.content[0].content[0].text }
            $cellTexts -contains '42' | Should Be $true
        }

        It 'DateTime values are stringified correctly' {
            $testDate = [DateTime]::new(2025, 12, 15, 14, 30, 0)
            $data = @([PSCustomObject]@{ LastSignIn = $testDate })
            $result = New-ADFTable -InputObject $data

            $dataRow = $result.content[1]
            $cellText = $dataRow.content[0].content[0].content[0].text
            # DateTime should be stringified (format depends on culture, but should contain date parts)
            $cellText | Should Match '2025'
            $cellText | Should Match '12'
            $cellText | Should Match '15'
        }

        It 'Handles large datasets without error' {
            $largeData = 1..100 | ForEach-Object {
                [PSCustomObject]@{ Id = $_; Name = "User$_"; Email = "user$_@test.com" }
            }
            { New-ADFTable -InputObject $largeData } | Should Not Throw
            $result = New-ADFTable -InputObject $largeData
            # 1 header + 100 data rows
            $result.content.Count | Should Be 101
        }
    }

    Context 'Helper Function: New-ADFTableHeaderRow' {
        It 'Creates tableRow with correct type' {
            $result = New-ADFTableHeaderRow -Properties @('Name', 'Email')
            $result.type | Should Be 'tableRow'
        }

        It 'Creates correct number of header cells' {
            $result = New-ADFTableHeaderRow -Properties @('A', 'B', 'C')
            $result.content.Count | Should Be 3
        }

        It 'Each header cell is type tableHeader' {
            $result = New-ADFTableHeaderRow -Properties @('Name')
            $result.content[0].type | Should Be 'tableHeader'
        }

        It 'Header cell contains paragraph with text' {
            $result = New-ADFTableHeaderRow -Properties @('TestHeader')
            $result.content[0].content[0].type | Should Be 'paragraph'
            $result.content[0].content[0].content[0].type | Should Be 'text'
            $result.content[0].content[0].content[0].text | Should Be 'TestHeader'
        }

        It 'Header cell has empty attrs hashtable' {
            $result = New-ADFTableHeaderRow -Properties @('Name')
            $result.content[0].attrs | Should Not Be $null
            $result.content[0].attrs.GetType().Name | Should Be 'Hashtable'
        }
    }

    Context 'Helper Function: New-ADFTableDataRow' {
        It 'Creates tableRow with correct type' {
            $obj = [PSCustomObject]@{ Name = 'Test' }
            $result = New-ADFTableDataRow -InputObject $obj -Properties @('Name')
            $result.type | Should Be 'tableRow'
        }

        It 'Creates correct number of data cells' {
            $obj = [PSCustomObject]@{ A = '1'; B = '2'; C = '3' }
            $result = New-ADFTableDataRow -InputObject $obj -Properties @('A', 'B', 'C')
            $result.content.Count | Should Be 3
        }

        It 'Each data cell is type tableCell' {
            $obj = [PSCustomObject]@{ Name = 'Test' }
            $result = New-ADFTableDataRow -InputObject $obj -Properties @('Name')
            $result.content[0].type | Should Be 'tableCell'
        }

        It 'Data cell contains paragraph with text value' {
            $obj = [PSCustomObject]@{ Name = 'TestValue' }
            $result = New-ADFTableDataRow -InputObject $obj -Properties @('Name')
            $result.content[0].content[0].type | Should Be 'paragraph'
            $result.content[0].content[0].content[0].type | Should Be 'text'
            $result.content[0].content[0].content[0].text | Should Be 'TestValue'
        }

        It 'Handles missing property gracefully' {
            $obj = [PSCustomObject]@{ Name = 'Test' }
            $result = New-ADFTableDataRow -InputObject $obj -Properties @('Name', 'Missing')
            $result.content.Count | Should Be 2
            # Missing property should result in empty string
            $result.content[1].content[0].content[0].text | Should Be ''
        }

        It 'Works with hashtable input' {
            $obj = @{ Name = 'HashValue' }
            $result = New-ADFTableDataRow -InputObject $obj -Properties @('Name')
            $result.content[0].content[0].content[0].text | Should Be 'HashValue'
        }
    }

    Context 'Helper Function: ConvertTo-CellValue' {
        It 'Returns empty string for null' {
            $result = ConvertTo-CellValue -Value $null
            $result | Should Be ''
        }

        It 'Returns comma-separated string for arrays' {
            $result = ConvertTo-CellValue -Value @('a', 'b', 'c')
            $result | Should Be 'a, b, c'
        }

        It 'Returns JSON for hashtables' {
            $result = ConvertTo-CellValue -Value @{ Key = 'Value' }
            $result | Should Match 'Key'
            $result | Should Match 'Value'
        }

        It 'Returns JSON for PSCustomObjects' {
            $obj = [PSCustomObject]@{ Nested = 'Data' }
            $result = ConvertTo-CellValue -Value $obj
            $result | Should Match 'Nested'
            $result | Should Match 'Data'
        }

        It 'Returns string representation for primitives' {
            ConvertTo-CellValue -Value 42 | Should Be '42'
            ConvertTo-CellValue -Value $true | Should Be 'True'
            ConvertTo-CellValue -Value 'hello' | Should Be 'hello'
        }

        It 'Handles empty array' {
            $result = ConvertTo-CellValue -Value @()
            $result | Should Be ''
        }

        It 'Handles single-element array' {
            $result = ConvertTo-CellValue -Value @('single')
            $result | Should Be 'single'
        }
    }
}
