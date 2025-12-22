# Live Integration Testing Framework

**Story:** 11.2 - Live Integration Testing
**Purpose:** Validate all Confluence sync operations against real CIPP and Confluence environments
**Status:** Ready for Execution

---

## Overview

This testing framework provides comprehensive live integration testing for the Confluence sync integration. Unlike the 1,657+ mocked unit/integration tests in Epics 1-10, these tests execute against **real APIs, real networks, and real data**.

**Key Differences from Mocked Tests:**
- Real Confluence Cloud REST API v2 calls (cursor pagination, rate limiting, network latency)
- Real CIPP framework function calls (Get-ExtensionCacheData, Get-ExtensionAPIKey, Get-CIPPTable)
- Real Azure Table Storage operations (CacheExtensionSync, CippMapping, Extensionsconfig, CacheConfluencePages)
- Real M365 tenant data (not synthetic test data)
- Real network conditions (timeouts, retries, connection errors)

---

## Test Scope

### Sync Functions Under Test

1. **User Inventory Sync** (`Sync-ConfluenceUserInventory`)
   - Epic 4, Stories 4.1-4.2
   - Data: Users, licenses, mailboxes, OneDrive usage

2. **Device Inventory Sync** (`Sync-ConfluenceEndpointInventory`)
   - Epic 5, Stories 5.1-5.2
   - Data: Intune devices, compliance status, device-user relations

3. **License Report Sync** (`Sync-ConfluenceLicenseReport`)
   - Epic 5, Stories 5.3-5.4
   - Data: License SKUs, counts, assignments

4. **MFA Status Sync** (`Sync-ConfluenceMFAStatus`)
   - Epic 6, Story 6.1
   - Data: MFA registration status, methods

5. **Teams Inventory Sync** (`Sync-ConfluenceTeamsInventory`)
   - Epic 6, Story 6.2
   - Data: Teams list, membership

6. **SharePoint Inventory Sync** (`Sync-ConfluenceSharePointInventory`)
   - Epic 6, Story 6.3
   - Data: SharePoint sites, sizes, URLs

### Test Categories

| Category | Description | Acceptance Criteria |
|----------|-------------|---------------------|
| Environment Setup | Validate all prerequisites | AC1 |
| User Sync | Test user inventory sync | AC2 |
| Device Sync | Test device inventory sync | AC3 |
| License Sync | Test license report sync | AC4 |
| Security Sync | Test MFA, Teams, SharePoint sync | AC5 |
| Edge Cases | Test large tenants, empty tenants, special characters, rate limiting, timeouts | AC6 |
| Error Handling | Test invalid credentials, missing resources, partial failures | AC7 |
| Documentation | Create comprehensive test report | AC8 |

---

## Prerequisites

### Environment Requirements

1. **CIPP Instance**
   - Real CIPP Function App with framework functions accessible
   - Test tenant configured in system
   - CacheExtensionSync table populated with representative M365 data

2. **Confluence Instance**
   - Confluence Cloud instance (NOT Server)
   - Test space created (recommended: `CIPPTESTSPACE`)
   - API token with required permissions (write:confluence-content, write:confluence-space, read:confluence-content)

3. **Azure Table Storage**
   - Access to all 4 tables: CacheExtensionSync, CippMapping, Extensionsconfig, CacheConfluencePages
   - Test tenant mapping configured in CippMapping
   - Confluence extension config in Extensionsconfig

4. **Test Data**
   - 10+ licensed users with mailboxes and OneDrive
   - 10+ Intune devices with varied compliance statuses
   - Multiple license SKUs with assignments
   - MFA-enabled and non-MFA users
   - 5+ Teams with membership
   - 5+ SharePoint sites

### Module Requirements

- ConfluenceAPI module (Epics 1-9)
- CippExtensions module (Epic 10)
- CIPP framework modules (Get-ExtensionAPIKey, Get-ExtensionCacheData, Get-CIPPTable)

---

## Quick Start

### Step 1: Validate Environment

Run the environment validation script to ensure all prerequisites are met:

```powershell
.\docs\testing\scripts\Test-LiveIntegrationEnvironment.ps1 `
    -TestTenantId 'contoso.onmicrosoft.com' `
    -TestSpaceKey 'CIPPTESTSPACE'
```

**Expected Output:** All validation checks should pass (✅)

**If Validation Fails:**
- Review failed checks in output
- Fix environment issues (missing tables, invalid credentials, missing data)
- Re-run validation until all checks pass

### Step 2: Execute Live Tests

Run the comprehensive live integration test suite:

```powershell
.\docs\testing\scripts\Invoke-LiveIntegrationTests.ps1 `
    -TestTenantId 'contoso.onmicrosoft.com' `
    -TestSpaceKey 'CIPPTESTSPACE'
```

**Optional: Run Specific Test Categories**

```powershell
# Run only User and Device sync tests
.\docs\testing\scripts\Invoke-LiveIntegrationTests.ps1 `
    -TestTenantId 'contoso.onmicrosoft.com' `
    -TestCategories UserSync, DeviceSync
```

**Available Test Categories:**
- `UserSync` - User inventory sync tests (AC2)
- `DeviceSync` - Device inventory sync tests (AC3)
- `LicenseSync` - License report sync tests (AC4)
- `SecuritySync` - MFA, Teams, SharePoint sync tests (AC5)
- `EdgeCases` - Edge case testing (AC6)
- `ErrorHandling` - Error handling validation (AC7)
- `All` - All test categories (default)

### Step 3: Review Test Results

Test results are automatically exported to JSON:

```
docs/testing/live-integration-test-results-YYYY-MM-DD-HHmmss.json
```

**Test Result Structure:**
```json
{
  "TestCategory": "UserSync",
  "TestName": "User Inventory Sync Execution",
  "AcceptanceCriteria": "AC2",
  "Passed": true,
  "Message": "Successfully synced 12 users to Confluence",
  "Evidence": {
    "Users": 12,
    "Errors": 0,
    "SyncResult": { ... }
  },
  "PerformanceMetric": "3.45s",
  "ExecutionTimestamp": "2025-12-21T14:30:00"
}
```

### Step 4: Create Test Report

Use the test report template to document findings:

1. Copy template: `docs/testing/live-integration-test-report-template.md`
2. Fill in placeholders with actual test results
3. Add screenshots of Confluence pages
4. Include failure analysis (if any failures)
5. Save as: `docs/testing/live-integration-test-report-YYYY-MM-DD.md`

---

## Test Execution Scripts

### Test-LiveIntegrationEnvironment.ps1

**Purpose:** Validates that the live integration test environment is properly configured.

**Parameters:**
- `TestTenantId` (required) - Tenant ID for testing
- `TestSpaceKey` (optional) - Confluence space key (default: CIPPTESTSPACE)

**Validation Checks:**
1. CIPP framework functions (Get-ExtensionAPIKey, Get-ExtensionCacheData, Get-CIPPTable)
2. Confluence API authentication
3. Azure Table Storage access (CacheExtensionSync, CippMapping, Extensionsconfig, CacheConfluencePages)
4. Test tenant data existence
5. Tenant mapping configuration
6. Confluence extension config
7. Sync module availability (all 6 sync functions)

**Exit Codes:**
- Returns validation results object
- Console output shows pass/fail for each check

### Invoke-LiveIntegrationTests.ps1

**Purpose:** Executes comprehensive live integration tests for all sync functions.

**Parameters:**
- `TestTenantId` (required) - Tenant ID for testing
- `TestSpaceKey` (optional) - Confluence space key (default: CIPPTESTSPACE)
- `SkipEnvironmentValidation` (switch) - Skip validation (not recommended)
- `TestCategories` (optional) - Specific test categories to run

**Test Execution Flow:**
1. Environment validation (unless skipped)
2. Module imports
3. Test category execution:
   - User Sync (AC2)
   - Device Sync (AC3)
   - License Sync (AC4)
   - Security Sync (AC5) - MFA, Teams, SharePoint
   - Edge Cases (AC6) - Large tenants, empty tenants, special characters, rate limiting, timeouts
   - Error Handling (AC7) - Invalid credentials, missing resources, partial failures
4. Results collection and export

**Output:**
- Console output with real-time test status
- JSON export with comprehensive test results
- Performance metrics for all sync operations

---

## Test Report Template

**File:** `docs/testing/live-integration-test-report-template.md`

**Sections:**
1. **Executive Summary** - High-level results, key metrics
2. **Test Environment Configuration** - CIPP, Confluence, Azure Storage, test data
3. **AC Validation Results** - Detailed results for each of 8 acceptance criteria
4. **Performance Metrics** - Execution times, NFR2 compliance
5. **Failure Analysis** - Root cause analysis for any failures
6. **Recommendations** - Immediate actions, follow-up items
7. **Test Artifacts** - Logs, screenshots, evidence files
8. **Conclusion** - Overall assessment, deployment recommendation

**Placeholders:**
- Environment details: `{{cipp_instance_url}}`, `{{test_tenant_id}}`, `{{test_space_key}}`
- Test results: `{{ac1_status}}`, `{{ac2_user_count}}`, `{{ac3_device_count}}`
- Performance: `{{perf_user_time}}`, `{{perf_device_time}}`
- Evidence: `{{ac2_screenshot_path}}`, `{{ac3_evidence}}`

---

## Success Criteria

### All 8 Acceptance Criteria Must Pass

1. ✅ **AC1:** Test environment setup complete
2. ✅ **AC2:** User sync validated against real APIs
3. ✅ **AC3:** Device sync validated against real APIs
4. ✅ **AC4:** License sync validated against real APIs
5. ✅ **AC5:** Security data syncs validated (MFA, Teams, SharePoint)
6. ✅ **AC6:** Edge cases tested and handled correctly
7. ✅ **AC7:** Error scenarios tested and handled gracefully
8. ✅ **AC8:** Live testing report created

### Zero Critical Issues

- No data corruption observed
- No security vulnerabilities exposed
- No unhandled exceptions during testing

### Performance Validated

- **NFR2 Compliance:** All sync operations complete within <10s per page update

### Change Detection Verified

- Re-sync produces 0 updates when data unchanged (MD5 hash-based)

---

## Troubleshooting

### Common Issues

**Environment Validation Fails**

1. **CIPP Framework Functions Not Available**
   - Ensure CIPP modules are imported
   - Verify module paths are correct
   - Check PowerShell execution policy

2. **Confluence API Authentication Failed**
   - Verify API token is valid and not expired
   - Check token permissions (write:confluence-content, write:confluence-space, read:confluence-content)
   - Confirm token is stored correctly (Azure Key Vault in prod, DevSecrets in dev)

3. **Azure Table Storage Not Accessible**
   - Verify SAS token or managed identity authentication
   - Check network connectivity to Azure storage endpoint
   - Confirm table names are correct (case-sensitive)

4. **Test Tenant Data Not Found**
   - Seed CacheExtensionSync table with representative M365 data
   - Verify PartitionKey matches TestTenantId
   - Check data includes all required types (users, devices, licenses, etc.)

5. **Tenant Mapping Not Found**
   - Create mapping entry in CippMapping table
   - PartitionKey = 'ConfluenceMapping'
   - RowKey = TestTenantId
   - SpaceKey = TestSpaceKey (e.g., 'CIPPTESTSPACE')

**Test Execution Fails**

1. **Sync Function Returns Null**
   - Check CIPP cache data availability
   - Verify Get-ExtensionCacheData returns data
   - Review sync function verbose logs

2. **Sync Completes with Errors**
   - Review error details in result object's Errors list
   - Check Confluence API logs
   - Verify network connectivity

3. **Performance Exceeds NFR2 (<10s)**
   - Check network latency to Confluence API
   - Review page size (large pages may exceed threshold)
   - Verify cursor pagination works correctly

4. **Change Detection Not Working**
   - Verify CacheConfluencePages table is accessible
   - Check MD5 hash storage (PartitionKey = tenant, RowKey = page ID)
   - Review hash calculation logic

---

## Best Practices

### Environment Safety

- **Use Dedicated Test Space:** Create isolated Confluence space for testing (e.g., `CIPPTESTSPACE`)
- **Use Test Tenant Data:** Never use production tenant data for live testing
- **Verify Reversibility:** Ensure all operations can be undone (pages can be deleted)

### Test Data Management

- **Representative Samples:** Test data should represent real-world scenarios
- **Edge Cases:** Include edge cases in test data (large datasets, empty datasets, special characters)
- **Data Refresh:** Refresh test data regularly to avoid stale data issues

### Evidence Collection

- **Screenshots:** Capture screenshots of all Confluence pages after sync
- **Logs:** Save all verbose logs from sync executions
- **Performance Metrics:** Record execution times for all sync operations

### Reporting

- **Comprehensive Documentation:** Document all findings with evidence
- **Root Cause Analysis:** Analyze failures to identify root causes
- **Actionable Recommendations:** Provide clear next steps for any issues

---

## Related Documentation

- [Story 11.2 Specification](../sprint-artifacts/11-2-live-integration-testing.md)
- [Epic 11 Details](../epics/epic-11-production-readiness.md)
- [Live Integration Test Plan](live-integration-test-plan.md)
- [Test Report Template](live-integration-test-report-template.md)
- [Project Context](../project_context.md)

---

**Last Updated:** 2025-12-21
**Maintained By:** Matthias Kittok
