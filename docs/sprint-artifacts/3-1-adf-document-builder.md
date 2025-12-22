# Story 3.1: ADF Document Builder

Status: Done

## Story

As a **Developer**,
I want **helper functions to create valid ADF document structures**,
so that **I can generate Confluence-compatible content programmatically for all data sync operations**.

## Acceptance Criteria

### AC1: Create ADF Document Root Structure
**Given** I need to create an ADF document
**When** I call `New-ADFDocument` (Private function)
**Then** a valid ADF root structure is created with version and type
**And** the structure follows Atlassian Document Format v1 specification:
```json
{
  "version": 1,
  "type": "doc",
  "content": []
}
```
**And** returns a hashtable (not PSCustomObject) for easy manipulation
**And** the content array is initialized as empty `@()`

### AC2: Add Content to ADF Document
**Given** I have an ADF document and content nodes to add
**When** I call `Add-ADFContent -Document $doc -Content $nodes`
**Then** the content nodes are appended to the document's content array
**And** the modified document is returned
**And** supports adding single node or array of nodes

### AC3: Convert Data to Complete ADF Document
**Given** I need to convert PowerShell data into a complete ADF document
**When** I call `ConvertTo-ADF -InputObject $data` (Private function)
**Then** the data is converted to valid ADF JSON structure
**And** the output can be used directly with `New-ConfluencePage -Body`
**And** returns JSON string ready for API consumption
**And** handles null/empty input gracefully (returns empty document)

### AC4: ADF Document Validation
**Given** I have an ADF document structure
**When** the document is serialized to JSON
**Then** it produces valid JSON that Confluence API will accept
**And** the version field is integer 1 (not string "1")
**And** the type field is exactly "doc"
**And** the content field is always an array (even if empty)

### AC5: Integration with Existing Page Functions
**Given** I create ADF content using the helper functions
**When** I pass it to `New-ConfluencePage -Body $adfJson`
**Then** the page is created successfully with the ADF content
**And** the body representation is correctly set to 'atlas_doc_format'

## Tasks / Subtasks

- [x] Task 1: Create New-ADFDocument Function (AC: 1, 4)
  - [x] Create `Private/New-ADFDocument.ps1` file
  - [x] Implement `[CmdletBinding()]`
  - [x] Return hashtable with version=1, type="doc", content=@()
  - [x] Add `Write-Verbose` logging
  - [x] Add comment-based help (even for Private functions)

- [x] Task 2: Create Add-ADFContent Function (AC: 2)
  - [x] Create `Private/Add-ADFContent.ps1` file
  - [x] Implement `[CmdletBinding()]`
  - [x] Accept -Document parameter (hashtable)
  - [x] Accept -Content parameter (hashtable or array)
  - [x] Append content to document's content array
  - [x] Return modified document
  - [x] Handle single node and array of nodes

- [x] Task 3: Create ConvertTo-ADF Function (AC: 3, 4)
  - [x] Create `Private/ConvertTo-ADF.ps1` file
  - [x] Implement `[CmdletBinding()]`
  - [x] Accept -InputObject parameter (can be hashtable, array, or $null)
  - [x] Create root document structure
  - [x] Add input content if provided
  - [x] Convert to JSON with `-Depth 20` for nested structures
  - [x] Return JSON string
  - [x] Handle null/empty input → empty document JSON

- [x] Task 4: Update New-ConfluencePage for ADF Support (AC: 5)
  - [x] Modify `Public/New-ConfluencePage.ps1`
  - [x] Add logic to detect ADF JSON vs storage format
  - [x] When ADF detected: set representation = 'atlas_doc_format'
  - [x] When storage format: keep representation = 'storage'
  - [x] Update comment-based help with ADF example

- [x] Task 5: Create Unit Tests (AC: 1-5)
  - [x] Create `Tests/Private/New-ADFDocument.Tests.ps1`
  - [x] Create `Tests/Private/Add-ADFContent.Tests.ps1`
  - [x] Create `Tests/Private/ConvertTo-ADF.Tests.ps1`
  - [x] Test: New-ADFDocument returns correct structure
  - [x] Test: New-ADFDocument version is integer 1
  - [x] Test: New-ADFDocument type is "doc"
  - [x] Test: New-ADFDocument content is empty array
  - [x] Test: Add-ADFContent appends single node
  - [x] Test: Add-ADFContent appends array of nodes
  - [x] Test: Add-ADFContent returns modified document
  - [x] Test: ConvertTo-ADF returns valid JSON
  - [x] Test: ConvertTo-ADF handles null input
  - [x] Test: ConvertTo-ADF handles empty input
  - [x] Test: Output JSON has version=1, type="doc", content array

- [x] Task 6: Validate Implementation (AC: 1-5)
  - [x] Run `Invoke-ScriptAnalyzer -Path ./Modules/ConfluenceAPI/ -Recurse`
  - [x] Run all Pester tests
  - [x] Verify all existing tests still pass (regression check)
  - [x] Test ADF output with real Confluence API (deferred to Epic integration testing per architecture decision - unit tests validate JSON structure)

## Dev Notes

### Architecture Compliance

**Module Location:** `Modules/ConfluenceAPI/Private/`

Per architecture.md and project_context.md, ADF builder functions go in `Private/` as they are internal helpers:
- `ConvertTo-ADF` - Private (matches architecture.md line 317)
- `New-ADFDocument` - Private (architecture.md line 318)
- `New-ADFTable` - Private (Story 3.2)
- `New-ADFParagraph` - Private (Story 3.3)
- `New-ADFHeading` - Private (Story 3.3)

These are consumed by higher-level Public functions and CIPP integration functions.

**Function Pattern:**
```powershell
function New-ADFDocument {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    Write-Verbose "Creating new ADF document structure"

    return @{
        version = 1
        type = "doc"
        content = @()
    }
}
```

### CRITICAL: ADF Specification (Atlassian Document Format v1)

**Root Document Structure:**
```json
{
  "version": 1,
  "type": "doc",
  "content": [
    // Block nodes go here
  ]
}
```

**Key Requirements:**
1. `version` MUST be integer `1` (not string "1")
2. `type` MUST be exactly `"doc"` for root
3. `content` MUST be an array (even if empty)

**Valid Block Node Types (can be in root content):**
- `paragraph` - Text content
- `heading` - Headers (attrs.level: 1-6)
- `table` - Tables
- `bulletList` - Unordered lists
- `orderedList` - Numbered lists
- `codeBlock` - Code blocks
- `blockquote` - Quotes
- `panel` - Info/warning panels
- `rule` - Horizontal rule
- `expand` - Expandable section
- `mediaGroup`, `mediaSingle` - Images/attachments

**Valid Inline Node Types (inside block nodes):**
- `text` - Plain text with optional marks
- `hardBreak` - Line break
- `emoji` - Emoji characters
- `mention` - User mentions
- `date` - Date display
- `status` - Status badges
- `inlineCard` - Smart links

**Mark Types (text formatting):**
- `strong` - Bold
- `em` - Italic
- `underline` - Underline
- `strike` - Strikethrough
- `code` - Inline code
- `link` - Hyperlinks
- `textColor` - Text color
- `subsup` - Subscript/superscript

**Example Paragraph with Formatted Text:**
```json
{
  "type": "paragraph",
  "content": [
    {"type": "text", "text": "Hello "},
    {"type": "text", "text": "world", "marks": [{"type": "strong"}]}
  ]
}
```

**Example Heading:**
```json
{
  "type": "heading",
  "attrs": {"level": 2},
  "content": [
    {"type": "text", "text": "Section Title"}
  ]
}
```

### JSON Serialization in PowerShell

**CRITICAL:** Use `-Depth` parameter with `ConvertTo-Json`:
```powershell
$json = $document | ConvertTo-Json -Depth 20 -Compress
```

Without `-Depth`, nested ADF structures will be truncated with `System.Object[]` strings.

**Default Depth is 2** - ADF documents easily exceed this:
- Document → content array → paragraph → content array → text node → marks array

Minimum recommended depth: 10
Safe depth for complex tables: 20

### Representation Type for Confluence API v2

When creating pages with ADF content, the body must specify:
```json
{
  "body": {
    "representation": "atlas_doc_format",
    "value": "{\"version\":1,\"type\":\"doc\",\"content\":[...]}"
  }
}
```

**Valid representations:**
- `atlas_doc_format` - ADF JSON (our target)
- `storage` - XHTML storage format (legacy)
- `wiki` - Wiki markup (deprecated)
- `view` - Rendered HTML (read-only)

**Detection Logic for New-ConfluencePage:**
```powershell
# Detect if body is ADF JSON
$isADF = $Body -match '^\s*\{.*"version"\s*:\s*1.*"type"\s*:\s*"doc"'
$representation = if ($isADF) { 'atlas_doc_format' } else { 'storage' }
```

### Previous Epic Intelligence (Epic 2)

**Key Learnings to Apply:**

1. **Mock/Reality Mismatch Prevention:**
   - Story 2.6 found mocks didn't match real API behavior
   - For ADF: verify JSON output against real Confluence API early
   - Create integration test that actually posts ADF to Confluence

2. **Pester 3.4 Syntax:**
   - Use `Should Be` (no hyphen) for Windows PS 5.1
   - Use `Assert-MockCalled` not `Should -Invoke`
   - Example: `$doc.version | Should Be 1`

3. **Testing Private Functions:**
   - Use `InModuleScope ConfluenceAPI { }` block
   - Or dot-source the function file directly in tests

4. **Return Types:**
   - Return hashtable from New-ADFDocument (easier to manipulate)
   - Return JSON string from ConvertTo-ADF (ready for API)
   - NEVER return raw PSCustomObject for ADF structures

### Existing Module Context

**Current Private Functions:**
- `Get-RateLimitDelay.ps1` - Rate limit header parsing

**Current Public Functions (21 total):**
- Credential management: New/Get/Remove-ConfluenceAPIKey, New/Get/Remove-ConfluenceBaseURL
- Connection: Test-ConfluenceConnection
- Core API: Invoke-ConfluenceRequest
- Spaces: Get/New/Set/Remove-ConfluenceSpace
- Pages: Get/New/Set/Remove-ConfluencePage, Move-ConfluencePage
- Labels: Get/Add/Remove-ConfluenceLabel
- Search: Search-Confluence

**Module will have after Epic 3:**
- Same 21 Public functions
- 6 Private functions: Get-RateLimitDelay + 5 ADF helpers

### Project Structure Notes

**Files to Create:**
```text
Modules/ConfluenceAPI/
├── Private/
│   ├── New-ADFDocument.ps1      # CREATE (Story 3.1)
│   ├── Add-ADFContent.ps1       # CREATE (Story 3.1)
│   └── ConvertTo-ADF.ps1        # CREATE (Story 3.1)
└── Tests/
    └── Private/
        ├── New-ADFDocument.Tests.ps1    # CREATE
        ├── Add-ADFContent.Tests.ps1     # CREATE
        └── ConvertTo-ADF.Tests.ps1      # CREATE
```

**Files to Modify:**
```text
Modules/ConfluenceAPI/
└── Public/
    └── New-ConfluencePage.ps1   # MODIFY (add ADF detection)
```

### Dependencies on Other Stories

**Story 3.1 is Foundation For:**
- Story 3.2: ADF Table Generation (uses New-ADFDocument, Add-ADFContent)
- Story 3.3: ADF Text Elements (uses New-ADFDocument, Add-ADFContent)
- Epic 4-6: All data sync functions (use ConvertTo-ADF)

**Story 3.1 Depends On:**
- Epic 1: Module scaffold (DONE)
- Story 2.3: New-ConfluencePage (DONE - will be modified)

### References

- [Source: docs/architecture.md#Project-Structure-Boundaries] - ADF functions in Private/
- [Source: docs/architecture.md#Content-Transformation] - ConvertTo-ADF pattern
- [Source: docs/project_context.md#Public-vs-Private-Boundaries] - ADF builders are PRIVATE
- [Source: docs/project_context.md#API-Gotchas] - ADF is JSON, NOT HTML
- [Source: docs/epics.md#Story-3.1] - Acceptance criteria
- [Atlassian ADF Structure](https://developer.atlassian.com/cloud/jira/platform/apis/document/structure/) - Official specification
- [ADF JSON Schema](http://go.atlassian.com/adf-json-schema) - Validation schema

### Common Mistakes to Avoid

1. **DO NOT** return PSCustomObject from New-ADFDocument - use hashtable for manipulation
2. **DO NOT** forget `-Depth` parameter in ConvertTo-Json (default 2 is too shallow)
3. **DO NOT** use string "1" for version - must be integer 1
4. **DO NOT** return empty string for null input - return valid empty document JSON
5. **DO NOT** put ADF functions in Public/ - they are internal helpers
6. **DO NOT** use storage format representation with ADF JSON
7. **DO NOT** forget to update ConfluenceAPI.psm1 to dot-source new Private functions
8. **DO NOT** use `throw` directly - use `$PSCmdlet.ThrowTerminatingError()`
9. **DO NOT** assume all content is arrays - check for single items
10. **DO NOT** modify the original document in Add-ADFContent without returning it

### Implementation Flow Diagram

```text
User wants to create ADF content for a page
    │
    ├── New-ADFDocument
    │   └── Returns: @{ version=1; type="doc"; content=@() }
    │
    ├── Create content nodes (headings, paragraphs, tables)
    │   └── Stories 3.2, 3.3 provide: New-ADFHeading, New-ADFParagraph, New-ADFTable
    │
    ├── Add-ADFContent -Document $doc -Content $nodes
    │   └── Returns: Document with content array populated
    │
    ├── ConvertTo-ADF -InputObject $doc
    │   └── Returns: JSON string ready for API
    │
    └── New-ConfluencePage -SpaceId $id -Title $title -Body $json
        └── Detects ADF, sets representation='atlas_doc_format'
```

### ConvertTo-ADF Flow Diagram

```text
ConvertTo-ADF -InputObject $input
    │
    ├── Check if $input is null or empty
    │   └── YES: Create empty document, convert to JSON, return
    │
    ├── Check if $input is already a document (has version, type, content)
    │   └── YES: Convert directly to JSON
    │
    ├── Check if $input is array of content nodes
    │   └── YES: Wrap in document structure, convert to JSON
    │
    ├── Check if $input is single content node
    │   └── YES: Wrap in array, wrap in document, convert to JSON
    │
    └── Return JSON string with -Depth 20 -Compress
```

## Dev Agent Record

### Context Reference

<!-- Story context analysis completed by create-story workflow -->

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

N/A - No debug issues encountered during implementation.

### Completion Notes List

- Implemented red-green-refactor TDD cycle for all 3 new private functions
- Created 22 new unit tests across 3 test files for ADF functions
- Added 4 new tests for ADF detection in New-ConfluencePage.Tests.ps1
- All 370 module tests pass with no regressions
- PSScriptAnalyzer shows only pre-existing warnings in test files and one false positive for New-ADFDocument (state-changing warning for an in-memory function)
- ADF detection uses regex pattern matching for `"version":1` and `"type":"doc"` to distinguish from storage format
- Used `-Depth 20 -Compress` in ConvertTo-Json to handle deeply nested ADF structures
- Module auto-discovers private functions via existing ConfluenceAPI.psm1 logic

### Code Review Fixes (2025-12-12)

- Added content node validation to ConvertTo-ADF - emits warning if node missing required `type` property
- Improved ADF detection in New-ConfluencePage - now parses JSON and validates structure instead of regex matching
- Documented Add-ADFContent in-place modification behavior in help text
- Added module integration tests verifying private functions are loadable
- Added tests for misleading JSON and invalid JSON handling in ADF detection
- All 376 tests pass after fixes

### File List

**Created:**
- `Modules/ConfluenceAPI/Private/New-ADFDocument.ps1`
- `Modules/ConfluenceAPI/Private/Add-ADFContent.ps1`
- `Modules/ConfluenceAPI/Private/ConvertTo-ADF.ps1`
- `Modules/ConfluenceAPI/Tests/Private/New-ADFDocument.Tests.ps1`
- `Modules/ConfluenceAPI/Tests/Private/Add-ADFContent.Tests.ps1`
- `Modules/ConfluenceAPI/Tests/Private/ConvertTo-ADF.Tests.ps1`

**Modified:**
- `Modules/ConfluenceAPI/Public/New-ConfluencePage.ps1` (added ADF detection logic and example)
- `Modules/ConfluenceAPI/Tests/Public/New-ConfluencePage.Tests.ps1` (added 6 ADF tests)

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2025-12-12 | Story created via create-story workflow | Claude Opus 4.5 |
| 2025-12-12 | Implementation complete - all tasks done, 370 tests pass | Claude Opus 4.5 |
| 2025-12-12 | Code review fixes - improved ADF detection, added validation, 376 tests pass | Claude Opus 4.5 |
