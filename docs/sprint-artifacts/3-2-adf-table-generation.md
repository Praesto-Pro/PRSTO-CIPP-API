# Story 3.2: ADF Table Generation

Status: done

## Story

As a **Developer**,
I want **to convert PowerShell objects into ADF tables**,
so that **data displays as readable tables in Confluence for user inventory, endpoint, license, and other reports**.

## Acceptance Criteria

### AC1: Create ADF Table from PowerShell Objects
**Given** I have an array of PSCustomObjects
**When** I call `New-ADFTable -InputObject $users` (Private function)
**Then** an ADF table node is created with headers from property names
**And** rows contain the object values
**And** the table is properly formatted for Confluence display
**And** returns a hashtable representing the ADF table node

### AC2: Specify Columns via Property Parameter
**Given** I want to specify which columns to include
**When** I call `New-ADFTable -InputObject $users -Property Name, Email, Status`
**Then** only the specified properties become columns
**And** columns appear in the order specified by -Property parameter
**And** properties not in the list are excluded from the table

### AC3: Handle Complex/Nested Data
**Given** I have nested or complex data (arrays, hashtables, nested objects)
**When** I call `New-ADFTable`
**Then** complex values are stringified appropriately
**And** arrays are converted to comma-separated strings
**And** hashtables/objects are converted to JSON-like string representation
**And** null values display as empty string (not "null")

### AC4: Single Object Support
**Given** I have a single PSCustomObject (not an array)
**When** I call `New-ADFTable -InputObject $singleUser`
**Then** a table with one data row is created
**And** the function handles the single object without errors

### AC5: Empty Input Handling
**Given** I have an empty array or null input
**When** I call `New-ADFTable -InputObject @()` or `New-ADFTable -InputObject $null`
**Then** an empty table node is returned (headers only if properties specified, or no rows)
**And** the function does not throw an error

### AC6: Integration with ConvertTo-ADF
**Given** I create a table using New-ADFTable
**When** I pass it to `ConvertTo-ADF -InputObject $table`
**Then** the table is correctly wrapped in an ADF document
**And** the output JSON can be used with `New-ConfluencePage -Body`

## Tasks / Subtasks

- [x] Task 1: Create New-ADFTable Function Structure (AC: 1, 4, 5)
  - [x] Create `Private/New-ADFTable.ps1` file
  - [x] Implement `[CmdletBinding()]` with `[OutputType([hashtable])]`
  - [x] Add `-InputObject` parameter accepting `[object]` (array or single object)
  - [x] Add `-Property` parameter accepting `[string[]]` for column selection
  - [x] Add `Write-Verbose` logging
  - [x] Add comment-based help documentation

- [x] Task 2: Implement Table Header Generation (AC: 1, 2)
  - [x] Extract property names from first object in InputObject
  - [x] If `-Property` specified, use those names instead (in specified order)
  - [x] Create ADF tableRow with tableHeader cells
  - [x] Each header cell contains paragraph with text node

- [x] Task 3: Implement Table Row Generation (AC: 1, 2, 3, 4)
  - [x] Iterate through each object in InputObject
  - [x] For each property, extract value and create tableCell
  - [x] Handle complex values (arrays → comma-separated, hashtables → JSON string)
  - [x] Handle null values → empty string
  - [x] Handle single object input (wrap in array internally)

- [x] Task 4: Implement Empty/Null Handling (AC: 5)
  - [x] Check for null or empty InputObject
  - [x] Return valid empty table structure
  - [x] If `-Property` provided, create headers-only table
  - [x] Log verbose message for empty input

- [x] Task 5: Assemble Complete ADF Table Node (AC: 1, 6)
  - [x] Create table node with type="table"
  - [x] Add attrs for table layout (isNumberColumnEnabled, layout)
  - [x] Add header row as first element of content
  - [x] Add data rows to content array
  - [x] Return complete hashtable

- [x] Task 6: Create Unit Tests (AC: 1-6)
  - [x] Create `Tests/Private/New-ADFTable.Tests.ps1`
  - [x] Test: Returns hashtable with type="table"
  - [x] Test: Table has content array
  - [x] Test: Headers extracted from object properties
  - [x] Test: -Property parameter filters and orders columns
  - [x] Test: Data rows contain correct values
  - [x] Test: Single object creates one-row table
  - [x] Test: Empty array returns valid empty table
  - [x] Test: Null input returns valid empty table
  - [x] Test: Complex values stringified correctly
  - [x] Test: Null values become empty strings
  - [x] Test: Integration with ConvertTo-ADF produces valid JSON

- [x] Task 7: Run Validation (AC: 1-6)
  - [x] Run `Invoke-ScriptAnalyzer -Path ./Modules/ConfluenceAPI/ -Recurse`
  - [x] Run all Pester tests
  - [x] Verify all existing tests still pass (regression check)
  - [x] Verify ADF output structure matches Atlassian specification

## Dev Notes

### Architecture Compliance

**Module Location:** `Modules/ConfluenceAPI/Private/`

Per architecture.md and project_context.md, `New-ADFTable` is a Private function:
- [Source: docs/architecture.md#Project-Structure-Boundaries] - Line 319: `New-ADFTable.ps1` in Private/
- [Source: docs/project_context.md#Public-vs-Private-Boundaries] - ADF builders are PRIVATE

**Dependencies:**
- `New-ADFDocument` (from Story 3.1) - for creating document wrapper
- `Add-ADFContent` (from Story 3.1) - for adding table to document
- `ConvertTo-ADF` (from Story 3.1) - for final JSON output

### CRITICAL: ADF Table Specification (Atlassian Document Format v1)

**Table Node Structure:**
```json
{
  "type": "table",
  "attrs": {
    "isNumberColumnEnabled": false,
    "layout": "default"
  },
  "content": [
    // tableRow nodes go here
  ]
}
```

**Table Row Node:**
```json
{
  "type": "tableRow",
  "content": [
    // tableCell or tableHeader nodes go here
  ]
}
```

**Table Header Cell:**
```json
{
  "type": "tableHeader",
  "attrs": {},
  "content": [
    {
      "type": "paragraph",
      "content": [
        {"type": "text", "text": "Column Name"}
      ]
    }
  ]
}
```

**Table Data Cell:**
```json
{
  "type": "tableCell",
  "attrs": {},
  "content": [
    {
      "type": "paragraph",
      "content": [
        {"type": "text", "text": "Cell Value"}
      ]
    }
  ]
}
```

**Complete Table Example:**
```json
{
  "type": "table",
  "attrs": {
    "isNumberColumnEnabled": false,
    "layout": "default"
  },
  "content": [
    {
      "type": "tableRow",
      "content": [
        {
          "type": "tableHeader",
          "attrs": {},
          "content": [{"type": "paragraph", "content": [{"type": "text", "text": "Name"}]}]
        },
        {
          "type": "tableHeader",
          "attrs": {},
          "content": [{"type": "paragraph", "content": [{"type": "text", "text": "Email"}]}]
        }
      ]
    },
    {
      "type": "tableRow",
      "content": [
        {
          "type": "tableCell",
          "attrs": {},
          "content": [{"type": "paragraph", "content": [{"type": "text", "text": "John Doe"}]}]
        },
        {
          "type": "tableCell",
          "attrs": {},
          "content": [{"type": "paragraph", "content": [{"type": "text", "text": "john@example.com"}]}]
        }
      ]
    }
  ]
}
```

### Previous Story Intelligence (Story 3.1)

**Key Learnings to Apply:**

1. **Hashtable Return Type:**
   - Return hashtable (not PSCustomObject) for easy manipulation
   - Example: `return @{ type = 'table'; attrs = @{...}; content = @() }`

2. **ConvertTo-Json Depth:**
   - Tables are deeply nested (table → row → cell → paragraph → text)
   - Use `-Depth 20` in ConvertTo-ADF (already implemented)
   - Verify test output doesn't show "System.Object[]" truncation

3. **Pester 3.4 Syntax:**
   - Use `Should Be` (no hyphen) for Windows PS 5.1
   - Use `Should Not Be $null` for null checks
   - Dot-source private function files directly in tests

4. **Testing Pattern:**
   ```powershell
   $here = Split-Path -Parent $MyInvocation.MyCommand.Path
   $privateDir = "$here\..\..\Private"

   Describe 'New-ADFTable' {
       BeforeAll {
           . "$privateDir\New-ADFTable.ps1"
       }
       # Tests here
   }
   ```

5. **Content Node Validation:**
   - Story 3.1 added validation for content nodes missing `type` property
   - Ensure all nodes created have required `type` field

### Function Pattern

```powershell
function New-ADFTable {
    <#
    .SYNOPSIS
        Creates an ADF table node from PowerShell objects.
    .DESCRIPTION
        Converts an array of PSCustomObjects into an Atlassian Document Format (ADF)
        table node. Headers are derived from object property names, and rows contain
        the corresponding values.
    .PARAMETER InputObject
        One or more PSCustomObjects to convert into table rows.
    .PARAMETER Property
        Optional list of property names to include as columns.
        If not specified, all properties from the first object are used.
    .EXAMPLE
        $users = @(
            [PSCustomObject]@{ Name = 'John'; Email = 'john@example.com' }
            [PSCustomObject]@{ Name = 'Jane'; Email = 'jane@example.com' }
        )
        $table = New-ADFTable -InputObject $users
    .EXAMPLE
        $table = New-ADFTable -InputObject $users -Property Name, Status
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(ValueFromPipeline)]
        [object]$InputObject,

        [Parameter()]
        [string[]]$Property
    )

    begin {
        Write-Verbose "Creating ADF table..."
        $allObjects = @()
    }

    process {
        if ($InputObject) {
            $allObjects += $InputObject
        }
    }

    end {
        # Implementation here
    }
}
```

### Value Stringification Logic

```powershell
function ConvertTo-CellValue {
    param([object]$Value)

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
```

### Existing Module Context

**Current Private Functions (after Story 3.1):**
- `Get-RateLimitDelay.ps1` - Rate limit header parsing
- `New-ADFDocument.ps1` - Create ADF document root
- `Add-ADFContent.ps1` - Append content to document
- `ConvertTo-ADF.ps1` - Convert to ADF JSON

**After Story 3.2:**
- `New-ADFTable.ps1` (new)

### Project Structure Notes

**Files to Create:**
```text
Modules/ConfluenceAPI/
├── Private/
│   └── New-ADFTable.ps1           # CREATE
└── Tests/
    └── Private/
        └── New-ADFTable.Tests.ps1  # CREATE
```

### Common Mistakes to Avoid

1. **DO NOT** forget `attrs` property on table, tableHeader, and tableCell nodes
2. **DO NOT** return PSCustomObject - use hashtable for manipulation
3. **DO NOT** put text directly in tableCell - must be paragraph → text
4. **DO NOT** forget to handle single object input (not an array)
5. **DO NOT** leave null values as "null" string - convert to empty string
6. **DO NOT** forget pipeline support with `begin`/`process`/`end` blocks
7. **DO NOT** modify original input objects - work on copies
8. **DO NOT** forget to test deeply nested output with ConvertTo-ADF
9. **DO NOT** use `throw` directly - use `$PSCmdlet.ThrowTerminatingError()` if needed
10. **DO NOT** forget Write-Verbose for all significant operations

### Implementation Flow Diagram

```text
New-ADFTable -InputObject $users -Property Name, Email
    │
    ├── Validate InputObject (null/empty check)
    │   └── Empty? Return empty table structure
    │
    ├── Determine columns
    │   ├── If -Property specified: use that list
    │   └── If not: extract from first object's properties
    │
    ├── Create header row
    │   └── For each column: create tableHeader cell with paragraph
    │
    ├── Create data rows
    │   └── For each object:
    │       └── For each column:
    │           ├── Get property value
    │           ├── Stringify if complex
    │           └── Create tableCell with paragraph
    │
    └── Return table hashtable:
        @{
            type = 'table'
            attrs = @{ isNumberColumnEnabled = $false; layout = 'default' }
            content = @($headerRow, $dataRows...)
        }
```

### Usage in Data Sync (Epic 4-6 Preview)

```powershell
# Future usage in ConvertTo-ConfluenceUserPage (Epic 4)
function ConvertTo-ConfluenceUserPage {
    param([object[]]$Users)

    $doc = New-ADFDocument

    # Add heading
    $heading = @{
        type = 'heading'
        attrs = @{ level = 1 }
        content = @(@{ type = 'text'; text = 'User Inventory' })
    }

    # Add timestamp
    $timestamp = @{
        type = 'paragraph'
        content = @(@{ type = 'text'; text = "Last updated: $(Get-Date -Format 'yyyy-MM-dd HH:mm UTC')" })
    }

    # Add user table
    $table = New-ADFTable -InputObject $Users -Property DisplayName, Email, Status, LastSignIn, MFAStatus

    $doc = Add-ADFContent -Document $doc -Content @($heading, $timestamp, $table)

    return ConvertTo-ADF -InputObject $doc
}
```

### References

- [Source: docs/architecture.md#Project-Structure-Boundaries] - New-ADFTable in Private/
- [Source: docs/architecture.md#Content-Transformation] - ADF helper functions pattern
- [Source: docs/project_context.md#Return-Types] - Return hashtable for ADF structures
- [Source: docs/epics.md#Story-3.2] - Acceptance criteria
- [Source: docs/sprint-artifacts/3-1-adf-document-builder.md] - Previous story learnings
- [Atlassian ADF Table Spec](https://developer.atlassian.com/cloud/jira/platform/apis/document/nodes/table/) - Official table documentation
- [ADF Node Types](https://developer.atlassian.com/cloud/jira/platform/apis/document/structure/) - Block node reference

### FRs Covered

- **FR43**: System can format data as readable tables in Confluence
- **FR45**: System can generate ADF-formatted content for Confluence pages (partial - table component)

## Dev Agent Record

### Context Reference

<!-- Story context analysis completed by create-story workflow -->

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

- PSScriptAnalyzer warnings for `New-*` verb suppressed with `SuppressMessageAttribute` - functions create in-memory structures, not system state changes

### Completion Notes List

- Implemented `New-ADFTable` private function with full ADF v1 table specification compliance
- Created helper functions `New-ADFTableHeaderRow`, `New-ADFTableDataRow`, and `ConvertTo-CellValue`
- Implemented pipeline support via begin/process/end blocks
- Added comprehensive value stringification (arrays to comma-separated, hashtables/objects to JSON, nulls to empty string)
- Created 60 unit tests covering all acceptance criteria (expanded from 40 during code review)
- All tests pass with no regressions (full test suite: 396 tests)
- Fixed edge case for objects with no properties
- Code review fixes applied:
  - Added PSScriptAnalyzer suppression attributes with justification
  - Added `.LINK` sections to comment-based help
  - Added DateTime value test coverage
  - Added large dataset (100+ rows) test coverage
  - Added isolated unit tests for helper functions (New-ADFTableHeaderRow, New-ADFTableDataRow, ConvertTo-CellValue)

### File List

- `Modules/ConfluenceAPI/Private/New-ADFTable.ps1` (created, updated)
- `Modules/ConfluenceAPI/Tests/Private/New-ADFTable.Tests.ps1` (created, updated)

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2025-12-12 | Story created via create-story workflow | Claude Opus 4.5 |
| 2025-12-12 | Implemented New-ADFTable with 40 passing tests | Claude Opus 4.5 |
| 2025-12-12 | Code review completed - added 20 new tests, PSScriptAnalyzer suppressions, and help links | Claude Opus 4.5 |
