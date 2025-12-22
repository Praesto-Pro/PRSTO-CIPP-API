# Tech-Spec: NoSQL Injection Remediation - Azure Table Storage OData Filters

**Created:** 2025-12-21
**Completed:** 2025-12-21
**Status:** ✅ Completed
**Security Severity:** High (RESOLVED)
**Epic:** Epic 11 - Production Readiness & Process Improvements
**Related Story:** Story 11.1 - Comprehensive Security Code Review

## Overview

### Problem Statement

The security code review identified a **high-severity NoSQL injection vulnerability** (confidence: 9/10) in Azure Table Storage OData filter queries across the Confluence integration. Four functions construct OData filter strings using direct string interpolation with user-controlled input (TenantId, SpaceKey, PageId) without escaping single quotes.

**Attack Vector:**
```powershell
# Vulnerable code:
$filter = "PartitionKey eq 'ConfluenceMapping' and RowKey eq '$TenantId'"

# Malicious input:
$TenantId = "abc' or PartitionKey eq 'ConfluenceMapping"

# Resulting filter bypasses tenant isolation:
"PartitionKey eq 'ConfluenceMapping' and RowKey eq 'abc' or PartitionKey eq 'ConfluenceMapping'"
# Returns ALL tenant mappings instead of just one
```

**Impact:**
- **Tenant Isolation Bypass:** Attackers can access mappings/cache data for other tenants
- **Data Exfiltration:** Retrieve sensitive SpaceKey, SpaceName, PageId across all tenants
- **Cache Manipulation:** Delete cache entries for other tenants (DoS potential)
- **Authorization Bypass:** Circumvent multi-tenant security boundaries

### Solution

Apply the **OData filter escaping pattern** already documented in `project_context.md` (used for CQL injection prevention) to all Azure Table Storage filter queries. Escape single quotes by doubling them (`'` → `''`) before interpolation, following the OData specification standard.

Add input validation using PowerShell's `[ValidatePattern()]` attribute for parameters that should conform to GUID format (TenantId, PageId).

### Scope (In/Out)

**In Scope:**
- Fix 4 identified vulnerable functions with OData filter escaping
- Add input validation (GUID pattern) where applicable
- Add security-focused unit tests with injection payloads
- Update `project_context.md` with OData filter security guidance
- Verify fixes with Pester tests (100% coverage of affected code paths)

**Out of Scope:**
- Audit other Table Storage queries across CIPP Core (tracked separately)
- Parameterized query support (Azure Table Storage SDK limitation)
- Centralized input sanitization helper function (defer to future refactoring)
- Performance optimization or caching improvements

## Context for Development

### Codebase Patterns

**PowerShell Security Best Practices:**
```powershell
# CORRECT: Escape single quotes before OData filter interpolation
$escapedTenantId = $TenantId -replace "'", "''"
$filter = "PartitionKey eq 'ConfluenceMapping' and RowKey eq '$escapedTenantId'"

# WRONG: Direct interpolation allows injection
$filter = "PartitionKey eq 'ConfluenceMapping' and RowKey eq '$TenantId'"
```

**Input Validation Pattern:**
```powershell
# GUID validation for TenantId/PageId parameters
[Parameter(Mandatory)]
[ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$|^[a-zA-Z0-9.-]+$')]
[string]$TenantId
```

**Testing Pattern:**
```powershell
It 'Prevents NoSQL injection via single quote in TenantId' {
    Mock Get-CIPPAzDataTableEntity { return $null }

    Get-ConfluenceTenantMapping -TenantId "abc' or PartitionKey eq 'ConfluenceMapping"

    Assert-MockCalled Get-CIPPAzDataTableEntity -Scope It -ParameterFilter {
        $Filter -eq "PartitionKey eq 'ConfluenceMapping' and RowKey eq 'abc'' or PartitionKey eq ''ConfluenceMapping'"
    }
}
```

### Files to Reference

- **Security Review Report:** `docs/security/security-review-2025-12-21.md` (Vulnerability details)
- **Project Context:** `docs/project_context.md` (CQL injection prevention at line 230-239)
- **Existing Test Patterns:** `Modules/ConfluenceAPI/Tests/Public/Get-ConfluenceTenantMapping.Tests.ps1`
- **Story Documentation:** `docs/sprint-artifacts/11-1-comprehensive-security-code-review.md`

### Technical Decisions

1. **Escaping vs. Validation:**
   - **Decision:** Use BOTH escaping (defense in depth) AND validation
   - **Rationale:** Escaping handles all edge cases; validation provides early rejection of malformed input
   - **Implementation:** Apply `-replace "'", "''"` to ALL user inputs before filter construction

2. **GUID Validation Scope:**
   - **Decision:** Apply strict GUID validation to `TenantId` and `PageId` parameters ONLY
   - **Rationale:** `SpaceKey` is alphanumeric (e.g., "CONTOSO"), not GUID format
   - **Pattern:** `^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$|^[a-zA-Z0-9.-]+$`
   - **Fallback:** Allow domain names (e.g., "contoso.onmicrosoft.com") as TenantId

3. **Backward Compatibility:**
   - **Decision:** NO breaking changes to function signatures
   - **Implementation:** Validation happens at parameter level; existing callers unaffected unless passing invalid data

4. **Test Coverage:**
   - **Decision:** Add dedicated "NoSQL Injection Prevention" test context to each affected test file
   - **Tests Required:** Malicious single quotes, doubled quotes, escaped sequences, empty strings

5. **Documentation Updates:**
   - **Decision:** Add "OData Filter Security" section to `project_context.md` next to existing CQL injection guidance
   - **Content:** Same escaping pattern applies to both CQL and OData filters

## Implementation Plan

### Tasks

- [ ] **Task 1:** Fix `Get-ConfluenceTenantMapping.ps1`
  - [ ] Escape `$TenantId` on line 42 before filter construction
  - [ ] Escape `$SpaceKey` on line 57 before filter construction
  - [ ] Escape `$TenantId` on line 72 (all mappings query - verify no user input)
  - [ ] Add `[ValidatePattern()]` to `$TenantId` parameter (allow GUID or domain format)
  - [ ] Update tests with NoSQL injection prevention context

- [ ] **Task 2:** Fix `Remove-ConfluenceTenantMapping.ps1`
  - [ ] Escape `$TenantId` on line 35 before filter construction
  - [ ] Add `[ValidatePattern()]` to `$TenantId` parameter
  - [ ] Update tests with injection prevention coverage

- [ ] **Task 3:** Fix `Get-ConfluencePageCache.ps1`
  - [ ] Escape `$PageId` on line 36 before filter construction
  - [ ] Add `[ValidatePattern()]` to `$PageId` parameter (strict GUID format)
  - [ ] Update tests with injection prevention coverage

- [ ] **Task 4:** Fix `Clear-ConfluencePageCache.ps1`
  - [ ] Escape `$SpaceKey` on line 35 before filter construction
  - [ ] Add `[ValidatePattern()]` to `$SpaceKey` parameter (alphanumeric only)
  - [ ] Update tests with injection prevention coverage

- [ ] **Task 5:** Update Project Documentation
  - [ ] Add "OData Filter Security" section to `docs/project_context.md`
  - [ ] Document escaping pattern with before/after examples
  - [ ] Link to security review report

- [ ] **Task 6:** Verify All Fixes
  - [ ] Run all Pester tests: `Invoke-Pester -Path Modules/ConfluenceAPI/Tests/Public/*.Tests.ps1`
  - [ ] Run all Pester tests: `Invoke-Pester -Path Modules/CippExtensions/Tests/Confluence/*.Tests.ps1`
  - [ ] Manual validation: Test with injection payloads in local dev environment
  - [ ] Verify no regression in existing functionality

### Acceptance Criteria

- [ ] **AC1:** All 4 vulnerable functions escape user input before OData filter construction
  - **Given** a user provides input containing single quotes (e.g., `"abc' or 1=1"`)
  - **When** the function constructs an OData filter
  - **Then** single quotes are doubled (`"abc'' or 1=1"`) to prevent injection

- [ ] **AC2:** All applicable parameters have `[ValidatePattern()]` validation
  - **Given** a function accepts TenantId or PageId parameters
  - **When** the parameter is defined
  - **Then** it includes GUID or domain name validation pattern
  - **And** invalid formats (e.g., SQL injection payloads) are rejected at parameter binding

- [ ] **AC3:** Security tests prevent regression
  - **Given** each affected function has a test file
  - **When** tests are executed with `Invoke-Pester`
  - **Then** a "NoSQL Injection Prevention" context exists with 3+ test cases
  - **And** tests verify escaped filter strings using `Assert-MockCalled` with `-ParameterFilter`

- [ ] **AC4:** Project documentation is updated
  - **Given** `docs/project_context.md` contains security guidance
  - **When** developers reference the security section
  - **Then** OData filter escaping is documented with examples
  - **And** guidance matches the CQL injection prevention pattern

- [ ] **AC5:** No functionality regression
  - **Given** all existing tests for affected functions
  - **When** tests are executed after fixes
  - **Then** all existing tests pass (no breaking changes)
  - **And** functions behave identically for non-malicious input

- [ ] **AC6:** Production deployment blocker resolved
  - **Given** Story 11.1 security review identified this as HIGH severity
  - **When** all tasks are complete and tests pass
  - **Then** the vulnerability is marked as RESOLVED in security review report
  - **And** Epic 11 production readiness gate can proceed

## Additional Context

### Dependencies

- **CIPP Framework:** `Get-CIPPTable`, `Get-CIPPAzDataTableEntity` (mocked in tests)
- **Pester Testing Framework:** v5.x (already in project)
- **Azure Table Storage SDK:** OData filter syntax (no SDK changes required)

### Testing Strategy

**Unit Tests (Required):**
1. **Injection Prevention Tests:**
   - Single quote in parameter value
   - Multiple single quotes
   - Already-escaped quotes (double single quotes)
   - Empty string edge case

2. **Validation Tests:**
   - Valid GUID format accepted
   - Valid domain name accepted
   - Invalid format rejected (SQL injection payload)
   - Special characters rejected

3. **Regression Tests:**
   - All existing test cases continue to pass
   - Verify exact filter string construction in mock assertions

**Manual Testing (Recommended):**
- Test in local CIPP dev environment with DevSecrets table
- Use malicious TenantId via REST API endpoint (if exposed)
- Verify error messages don't expose sensitive data

### Notes

**Security Context:**
- This vulnerability was discovered during Story 11.1 security review (Epic 11)
- Categorized as HIGH severity with 9/10 confidence (production blocker)
- Epic 11 Goal: Enable safe production deployment of Confluence integration
- All CRITICAL and HIGH findings must be resolved before production

**Related Issues:**
- **MEDIUM #1:** PowerShell 5.1 compatibility (already mitigated in Story 11.1)
- **LOW #1-3:** Non-blocking issues tracked for future sprints

**Post-Fix Actions:**
1. Update Story 11.1 status to "complete" after verification
2. Update security review report with remediation details
3. Consider codebase-wide audit for similar OData filter patterns (Epic 12+)

**PowerShell Escaping Reference:**
```powershell
# OData/SQL standard: Single quote escaped by doubling
"O'Reilly" → "O''Reilly"

# PowerShell replace operator:
$safe = $input -replace "'", "''"

# Filter construction:
$filter = "PartitionKey eq 'ConfluenceMapping' and RowKey eq '$safe'"
```
