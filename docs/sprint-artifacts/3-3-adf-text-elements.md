# Story 3.3: ADF Text Elements

Status: done

## Story

As a **Developer**,
I want **to create headings, paragraphs, and formatted text in ADF**,
so that **pages have proper structure and readability with timestamps, section titles, and descriptive content**.

## Acceptance Criteria

### AC1: Create ADF Heading
**Given** I need to add a heading
**When** I call `New-ADFHeading -Level 2 -Text 'User Inventory'` (Private function)
**Then** a valid ADF heading node is created
**And** the heading has the correct level (1-6)
**And** the heading contains the text content
**And** the node follows ADF v1 specification

### AC2: Create ADF Paragraph
**Given** I need to add a paragraph
**When** I call `New-ADFParagraph -Text 'Last updated: 2025-12-09'` (Private function)
**Then** a valid ADF paragraph node is created
**And** the text is properly wrapped in a text node
**And** the node follows ADF v1 specification

### AC3: Display Data Timestamps
**Given** I need to show a timestamp
**When** I call `New-ADFParagraph -Text "Data as of: $(Get-Date -Format 'yyyy-MM-dd HH:mm UTC')"`
**Then** the timestamp is displayed on the page (FR44)
**And** the format is human-readable

### AC4: Support Bold/Italic Text Marks
**Given** I need formatted text
**When** I call `New-ADFParagraph -Text 'Important note' -Bold` or `-Italic`
**Then** the text node includes appropriate marks array
**And** the marks are valid ADF mark types (strong, em)

### AC5: Support Multiple Text Segments
**Given** I need a paragraph with mixed formatting
**When** I call `New-ADFParagraph -Content @($normalText, $boldText, $italicText)`
**Then** the paragraph contains multiple text nodes
**And** each text node has its own marks
**And** the output is a single paragraph with inline content

### AC6: Integration with ADF Document
**Given** I create headings and paragraphs using New-ADFHeading and New-ADFParagraph
**When** I add them to a document using `Add-ADFContent` and convert with `ConvertTo-ADF`
**Then** the output is valid ADF JSON
**And** the JSON can be used with `New-ConfluencePage -Body`

## Tasks / Subtasks

- [x] Task 1: Create New-ADFHeading Function (AC: 1, 6)
  - [x] Create `Private/New-ADFHeading.ps1` file
  - [x] Implement `[CmdletBinding()]` with `[OutputType([hashtable])]`
  - [x] Add `-Level` parameter (1-6, with validation)
  - [x] Add `-Text` parameter for heading content
  - [x] Create ADF heading node structure
  - [x] Add `Write-Verbose` logging
  - [x] Add comment-based help with `.LINK` sections
  - [x] Add PSScriptAnalyzer suppression for `New-*` verb

- [x] Task 2: Create New-ADFParagraph Function (AC: 2, 3, 6)
  - [x] Create `Private/New-ADFParagraph.ps1` file
  - [x] Implement `[CmdletBinding()]` with `[OutputType([hashtable])]`
  - [x] Add `-Text` parameter for simple paragraph
  - [x] Create ADF paragraph node structure
  - [x] Add `Write-Verbose` logging
  - [x] Add comment-based help with `.LINK` sections
  - [x] Add PSScriptAnalyzer suppression for `New-*` verb

- [x] Task 3: Implement Text Marks Support (AC: 4, 5)
  - [x] Add `-Bold` switch parameter to New-ADFParagraph
  - [x] Add `-Italic` switch parameter to New-ADFParagraph
  - [x] Add `-Content` parameter for multiple text segments
  - [x] Create helper function `New-ADFTextNode` for text with marks
  - [x] Implement marks array for strong/em formatting

- [x] Task 4: Create Unit Tests (AC: 1-6)
  - [x] Create `Tests/Private/New-ADFHeading.Tests.ps1`
  - [x] Create `Tests/Private/New-ADFParagraph.Tests.ps1`
  - [x] Test: New-ADFHeading returns hashtable with type="heading"
  - [x] Test: Heading levels 1-6 all work correctly
  - [x] Test: Invalid heading levels are rejected
  - [x] Test: New-ADFParagraph returns hashtable with type="paragraph"
  - [x] Test: Paragraph contains text node with correct text
  - [x] Test: Bold parameter adds strong mark
  - [x] Test: Italic parameter adds em mark
  - [x] Test: Multiple marks can be combined
  - [x] Test: Content parameter accepts multiple text nodes
  - [x] Test: Integration with Add-ADFContent and ConvertTo-ADF
  - [x] Test: Output JSON is valid ADF structure

- [x] Task 5: Run Validation (AC: 1-6)
  - [x] Run `Invoke-ScriptAnalyzer -Path ./Modules/ConfluenceAPI/ -Recurse`
  - [x] Run all Pester tests (target: 0 new warnings)
  - [x] Verify all existing tests still pass (regression check)
  - [x] Verify ADF output structure matches Atlassian specification

## Dev Notes

### Architecture Compliance

**Module Location:** `Modules/ConfluenceAPI/Private/`

Per architecture.md and project_context.md, ADF helper functions are Private functions:
- [Source: docs/architecture.md#Project-Structure-Boundaries] - Lines 318-322: New-ADFParagraph, New-ADFHeading in Private/
- [Source: docs/epics.md#Story-3.3] - Acceptance criteria define private functions

**Dependencies:**
- `New-ADFDocument` (from Story 3.1) - for creating document wrapper
- `Add-ADFContent` (from Story 3.1) - for adding content to document
- `ConvertTo-ADF` (from Story 3.1) - for final JSON output
- `New-ADFTable` (from Story 3.2) - sibling ADF helper (same patterns)

### CRITICAL: ADF Text Element Specification (Atlassian Document Format v1)

**Heading Node Structure:**
```json
{
  "type": "heading",
  "attrs": {
    "level": 2
  },
  "content": [
    {"type": "text", "text": "Heading Text"}
  ]
}
```

**Paragraph Node Structure:**
```json
{
  "type": "paragraph",
  "content": [
    {"type": "text", "text": "Paragraph text"}
  ]
}
```

**Text Node with Marks (Bold/Italic):**
```json
{
  "type": "text",
  "text": "Bold text",
  "marks": [
    {"type": "strong"}
  ]
}
```

```json
{
  "type": "text",
  "text": "Italic text",
  "marks": [
    {"type": "em"}
  ]
}
```

**Combined Marks:**
```json
{
  "type": "text",
  "text": "Bold and italic",
  "marks": [
    {"type": "strong"},
    {"type": "em"}
  ]
}
```

**Paragraph with Multiple Text Segments:**
```json
{
  "type": "paragraph",
  "content": [
    {"type": "text", "text": "Normal text "},
    {"type": "text", "text": "bold text", "marks": [{"type": "strong"}]},
    {"type": "text", "text": " more normal"}
  ]
}
```

### Previous Story Intelligence (Story 3.2)

**Key Learnings to Apply:**

1. **PSScriptAnalyzer Suppression:**
   - Add `[Diagnostics.CodeAnalysis.SuppressMessageAttribute()]` for `New-*` verb warnings
   - Justification: "Creates in-memory data structure only, no system state changes"

2. **Comment-Based Help:**
   - Include `.LINK` sections for related functions
   - Link to Atlassian ADF documentation

3. **Hashtable Return Type:**
   - Return hashtable (not PSCustomObject) for easy manipulation
   - Example: `return @{ type = 'heading'; attrs = @{ level = $Level }; content = @() }`

4. **Pester 3.4 Syntax:**
   - Use `Should Be` (no hyphen) for Windows PS 5.1
   - Use `Should Not Be $null` for null checks
   - Dot-source private function files directly in tests

5. **Testing Pattern:**
   ```powershell
   $here = Split-Path -Parent $MyInvocation.MyCommand.Path
   $privateDir = "$here\..\..\Private"

   Describe 'New-ADFHeading' {
       BeforeAll {
           . "$privateDir\New-ADFHeading.ps1"
       }
       # Tests here
   }
   ```

### Function Patterns

**New-ADFHeading Pattern:**
```powershell
function New-ADFHeading {
    <#
    .SYNOPSIS
        Creates an ADF heading node.
    .DESCRIPTION
        Creates an Atlassian Document Format (ADF) heading node with
        specified level (1-6) and text content.
    .PARAMETER Level
        Heading level from 1 (largest) to 6 (smallest).
    .PARAMETER Text
        The heading text content.
    .EXAMPLE
        $heading = New-ADFHeading -Level 1 -Text 'User Inventory'
    .LINK
        New-ADFDocument
    .LINK
        New-ADFParagraph
    .LINK
        Add-ADFContent
    .LINK
        https://developer.atlassian.com/cloud/jira/platform/apis/document/nodes/heading/
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Creates in-memory data structure only, no system state changes')]
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [ValidateRange(1, 6)]
        [int]$Level,

        [Parameter(Mandatory)]
        [string]$Text
    )

    Write-Verbose "Creating ADF heading level $Level..."

    return @{
        type    = 'heading'
        attrs   = @{ level = $Level }
        content = @(
            @{
                type = 'text'
                text = $Text
            }
        )
    }
}
```

**New-ADFParagraph Pattern:**
```powershell
function New-ADFParagraph {
    <#
    .SYNOPSIS
        Creates an ADF paragraph node.
    .DESCRIPTION
        Creates an Atlassian Document Format (ADF) paragraph node with
        text content and optional formatting marks.
    .PARAMETER Text
        Simple text content for the paragraph.
    .PARAMETER Bold
        Apply bold formatting to the text.
    .PARAMETER Italic
        Apply italic formatting to the text.
    .PARAMETER Content
        Array of pre-built text nodes for complex paragraphs.
    .EXAMPLE
        $para = New-ADFParagraph -Text 'Last updated: 2025-12-12'
    .EXAMPLE
        $para = New-ADFParagraph -Text 'Important!' -Bold
    .LINK
        New-ADFDocument
    .LINK
        New-ADFHeading
    .LINK
        Add-ADFContent
    .LINK
        https://developer.atlassian.com/cloud/jira/platform/apis/document/nodes/paragraph/
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Creates in-memory data structure only, no system state changes')]
    [CmdletBinding(DefaultParameterSetName = 'SimpleText')]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'SimpleText')]
        [string]$Text,

        [Parameter(ParameterSetName = 'SimpleText')]
        [switch]$Bold,

        [Parameter(ParameterSetName = 'SimpleText')]
        [switch]$Italic,

        [Parameter(Mandatory, ParameterSetName = 'Content')]
        [hashtable[]]$Content
    )

    Write-Verbose "Creating ADF paragraph..."

    if ($PSCmdlet.ParameterSetName -eq 'Content') {
        return @{
            type    = 'paragraph'
            content = $Content
        }
    }

    # Build text node with marks
    $textNode = @{
        type = 'text'
        text = $Text
    }

    $marks = @()
    if ($Bold) { $marks += @{ type = 'strong' } }
    if ($Italic) { $marks += @{ type = 'em' } }

    if ($marks.Count -gt 0) {
        $textNode.marks = $marks
    }

    return @{
        type    = 'paragraph'
        content = @($textNode)
    }
}
```

### Existing Module Context

**Current Private Functions (after Story 3.2):**
- `Get-RateLimitDelay.ps1` - Rate limit header parsing
- `New-ADFDocument.ps1` - Create ADF document root
- `Add-ADFContent.ps1` - Append content to document
- `ConvertTo-ADF.ps1` - Convert to ADF JSON
- `New-ADFTable.ps1` - Create ADF table from objects

**After Story 3.3:**
- `New-ADFHeading.ps1` (new)
- `New-ADFParagraph.ps1` (new)

### Project Structure Notes

**Files to Create:**
```text
Modules/ConfluenceAPI/
├── Private/
│   ├── New-ADFHeading.ps1           # CREATE
│   └── New-ADFParagraph.ps1         # CREATE
└── Tests/
    └── Private/
        ├── New-ADFHeading.Tests.ps1  # CREATE
        └── New-ADFParagraph.Tests.ps1 # CREATE
```

### Common Mistakes to Avoid

1. **DO NOT** forget `attrs` property on heading nodes (contains level)
2. **DO NOT** return PSCustomObject - use hashtable for manipulation
3. **DO NOT** put text directly in heading/paragraph - must wrap in text node
4. **DO NOT** forget marks array for bold/italic - it's an array even for single mark
5. **DO NOT** use `throw` directly - use `$PSCmdlet.ThrowTerminatingError()` if needed
6. **DO NOT** forget Write-Verbose for all significant operations
7. **DO NOT** forget PSScriptAnalyzer suppression attributes
8. **DO NOT** forget .LINK sections in comment-based help
9. **DO NOT** validate level outside 1-6 range - use ValidateRange
10. **DO NOT** create empty content arrays - heading/paragraph need at least one text node

### Implementation Flow Diagram

```text
New-ADFHeading -Level 2 -Text 'User Inventory'
    │
    ├── Validate Level (1-6)
    │
    ├── Create text node: @{ type = 'text'; text = $Text }
    │
    └── Return heading hashtable:
        @{
            type = 'heading'
            attrs = @{ level = 2 }
            content = @($textNode)
        }

New-ADFParagraph -Text 'Last updated' -Bold
    │
    ├── Build text node: @{ type = 'text'; text = $Text }
    │
    ├── If Bold: Add @{ type = 'strong' } to marks
    │
    ├── If Italic: Add @{ type = 'em' } to marks
    │
    ├── If marks exist: Add marks array to text node
    │
    └── Return paragraph hashtable:
        @{
            type = 'paragraph'
            content = @($textNode)
        }
```

### Usage in Data Sync (Epic 4-6 Preview)

```powershell
# Future usage in ConvertTo-ConfluenceUserPage (Epic 4)
function ConvertTo-ConfluenceUserPage {
    param([object[]]$Users)

    $doc = New-ADFDocument

    # Add heading (Story 3.3)
    $heading = New-ADFHeading -Level 1 -Text 'User Inventory'

    # Add timestamp (Story 3.3 - FR44)
    $timestamp = New-ADFParagraph -Text "Last updated: $(Get-Date -Format 'yyyy-MM-dd HH:mm UTC')"

    # Add status note with formatting (Story 3.3)
    $note = New-ADFParagraph -Text 'Active users are highlighted' -Italic

    # Add user table (Story 3.2)
    $table = New-ADFTable -InputObject $Users -Property DisplayName, Email, Status, LastSignIn, MFAStatus

    $doc = Add-ADFContent -Document $doc -Content @($heading, $timestamp, $note, $table)

    return ConvertTo-ADF -InputObject $doc
}
```

### Complete Page Example

```powershell
# Build a complete page with headings, paragraphs, and tables
$doc = New-ADFDocument

# Page title
$title = New-ADFHeading -Level 1 -Text 'Client Documentation'

# Timestamp (FR44)
$updated = New-ADFParagraph -Text "Data as of: $(Get-Date -Format 'yyyy-MM-dd HH:mm UTC')"

# Section heading
$section1 = New-ADFHeading -Level 2 -Text 'User Inventory'

# Description
$desc = New-ADFParagraph -Text 'This table shows all users in the tenant with their current status.'

# Warning note with bold
$warning = New-ADFParagraph -Text 'Disabled accounts may still have active licenses!' -Bold

# Add all content
$doc = Add-ADFContent -Document $doc -Content @($title, $updated, $section1, $desc, $warning)

# Convert to JSON for API
$json = ConvertTo-ADF -InputObject $doc
```

### ADF Mark Types Reference

| Mark Type | ADF Value | PowerShell Parameter |
|-----------|-----------|---------------------|
| Bold | `strong` | `-Bold` |
| Italic | `em` | `-Italic` |
| Underline | `underline` | (future) |
| Strikethrough | `strike` | (future) |
| Code | `code` | (future) |
| Link | `link` | (future - requires attrs) |

**Note:** This story implements strong and em marks only. Additional marks can be added in future stories if needed.

### References

- [Source: docs/architecture.md#Project-Structure-Boundaries] - New-ADFParagraph, New-ADFHeading in Private/
- [Source: docs/architecture.md#Content-Transformation] - ADF helper functions pattern
- [Source: docs/epics.md#Story-3.3] - Acceptance criteria
- [Source: docs/sprint-artifacts/3-1-adf-document-builder.md] - Story 3.1 learnings
- [Source: docs/sprint-artifacts/3-2-adf-table-generation.md] - Story 3.2 learnings
- [Atlassian ADF Heading Spec](https://developer.atlassian.com/cloud/jira/platform/apis/document/nodes/heading/) - Official heading documentation
- [Atlassian ADF Paragraph Spec](https://developer.atlassian.com/cloud/jira/platform/apis/document/nodes/paragraph/) - Official paragraph documentation
- [Atlassian ADF Marks](https://developer.atlassian.com/cloud/jira/platform/apis/document/marks/) - Text formatting marks

### FRs Covered

- **FR44**: System can display data freshness timestamp on pages
- **FR45**: System can generate ADF-formatted content for Confluence pages (text elements component)

## Dev Agent Record

### Context Reference

<!-- Story context analysis completed by create-story workflow -->

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

- PSScriptAnalyzer warnings for `New-*` verb suppressed with `SuppressMessageAttribute` - functions create in-memory structures, not system state changes
- Also added suppression to `New-ADFDocument.ps1` (from Story 3.1) for consistency

### Completion Notes List

- Implemented `New-ADFHeading` private function with ADF v1 heading specification compliance
- Implemented `New-ADFParagraph` private function with text content and formatting support
- Implemented `New-ADFTextNode` helper function for building complex paragraphs with mixed formatting
- Added `-Bold` and `-Italic` switch parameters with ADF marks (strong, em)
- Added `-Content` parameter for multiple text segments in a single paragraph
- Used parameter sets (SimpleText, Content) for mutually exclusive usage patterns
- Created 69 unit tests covering all acceptance criteria:
  - 28 tests for New-ADFHeading (includes whitespace-only rejection test added in review)
  - 41 tests for New-ADFParagraph (includes New-ADFTextNode, integration tests, and empty text edge case)
- All tests pass with no regressions
- Timestamp formatting (FR44) verified in tests

### Senior Developer Review (AI)

**Reviewed:** 2025-12-12 by Claude Opus 4.5

**Issues Found:** 0 High, 5 Medium, 3 Low → All MEDIUM issues fixed

**Fixes Applied:**

1. Added `ValidateNotNullOrEmpty` and `ValidateScript` to reject whitespace-only text in `New-ADFHeading`
2. Updated comment-based help example in `New-ADFParagraph` to use `New-ADFTextNode` helper
3. Improved verbose message consistency across paragraph functions
4. Added edge case test for empty text with marks in `New-ADFTextNode`
5. Added whitespace-only rejection test for `New-ADFHeading`

**Notes:**

- BOM encoding issue was identified but unicode characters preserved correctly after fix
- ValidateScript ErrorMessage parameter (PS7+ feature) replaced with PS5.1-compatible throw pattern
- Test count increased from 67 to 69 after adding review tests

### File List

- `Modules/ConfluenceAPI/Private/New-ADFHeading.ps1` (created)
- `Modules/ConfluenceAPI/Private/New-ADFParagraph.ps1` (created) - includes New-ADFTextNode helper
- `Modules/ConfluenceAPI/Private/New-ADFDocument.ps1` (updated - added PSScriptAnalyzer suppression and .LINK sections)
- `Modules/ConfluenceAPI/Tests/Private/New-ADFHeading.Tests.ps1` (created)
- `Modules/ConfluenceAPI/Tests/Private/New-ADFParagraph.Tests.ps1` (created)

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2025-12-12 | Story created via create-story workflow | Claude Opus 4.5 |
| 2025-12-12 | Implemented New-ADFHeading, New-ADFParagraph, New-ADFTextNode with 67 tests | Claude Opus 4.5 |
| 2025-12-12 | Code review: Fixed whitespace validation, verbose messages, added 2 tests (69 total), status → done | Claude Opus 4.5 |
