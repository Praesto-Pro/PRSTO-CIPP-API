# Live Integration Test Plan

**Story:** 11.2: Live Integration Testing
**Date:** 2025-12-21
**Author:** Matthias Kittok
**Status:** IN PROGRESS

---

## Test Environment Setup

### CIPP Instance Configuration

**Instance Requirements:**
- Real CIPP Function App with access to `CacheExtensionSync` table
- CIPP framework functions available: `Get-ExtensionCacheData`, `Get-ExtensionAPIKey`, `Get-CIPPTable`
- Test tenant configured in CIPP system

**Test Tenant Data Requirements:**
- **User Data:** 10+ licensed users with mailboxes and OneDrive
- **Device Data:** 10+ Intune devices with varied compliance statuses
- **License Data:** Multiple license SKUs with assignments
- **MFA Data:** Mix of MFA-enabled and non-MFA users
- **Teams Data:** 5+ Teams with membership
- **SharePoint Data:** 5+ SharePoint sites

### Confluence Cloud Configuration

**Instance Requirements:**
- Confluence Cloud instance (NOT Server)
- Test space created with unique key: `CIPPTESTSPACE`
- API token with required permissions:
  - `write:confluence-content` (page creation/updates)
  - `write:confluence-space` (space management)
  - `read:confluence-content` (CQL queries and page reads)

**API Token Storage:**
- **Production:** Azure Key Vault secret named 'Confluence'
- **Development:** DevSecrets table with PartitionKey = 'Confluence'

### Azure Table Storage Configuration

**Required Tables:**
1. **CacheExtensionSync** - M365 data cache
   - PartitionKey = test tenant ID
   - Must contain representative M365 data for all sync types

2. **CippMapping** - Tenant-to-space mappings
   - PartitionKey = 'ConfluenceMapping'
   - RowKey = test tenant ID
   - SpaceKey = 'CIPPTESTSPACE'

3. **Extensionsconfig** - Extension configuration
   - PartitionKey = 'Confluence'
   - Contains BaseURL, CloudId (if scoped URL)

4. **CacheConfluencePages** - Page cache with MD5 hashes
   - PartitionKey = test tenant ID
   - Used for change detection validation

**Authentication:**
- SAS token or managed identity configured for table access

### Network Configuration

**Outbound Access Required:**
- HTTPS to `*.atlassian.net` (Confluence Cloud)
- HTTPS to Azure Table Storage endpoint
- Ability to handle API rate limiting (429 responses with Retry-After headers)

---

## Test Execution Scripts

### Script 1: Environment Validation

**Purpose:** Verify all prerequisites are met before live testing

**Validation Checks:**
- [ ] CIPP framework functions accessible
- [ ] Confluence API authentication successful
- [ ] Azure Table Storage tables accessible
- [ ] Test tenant data exists in CacheExtensionSync
- [ ] Tenant mapping exists in CippMapping
- [ ] Extension config exists in Extensionsconfig

### Script 2: User Sync Live Test

**Function Under Test:** `Sync-ConfluenceUserInventory`

**Test Steps:**
1. Load test tenant data from CacheExtensionSync
2. Execute sync function
3. Verify Confluence page created/updated
4. Validate data accuracy (users, licenses, mailboxes, OneDrive)
5. Re-execute sync (change detection test)
6. Verify no redundant updates (MD5 hash check)

**Evidence Collection:**
- Screenshot of Confluence page with user data
- Sync execution logs
- Performance metrics (execution time)

### Script 3: Device Sync Live Test

**Function Under Test:** `Sync-ConfluenceEndpointInventory`

**Test Steps:**
1. Load test tenant device data from CacheExtensionSync
2. Execute sync function
3. Verify Confluence page created/updated
4. Validate data accuracy (devices, compliance, user relations)
5. Re-execute sync (change detection test)
6. Verify no redundant updates

**Evidence Collection:**
- Screenshot of Confluence page with device data
- Sync execution logs
- Performance metrics

### Script 4: License Sync Live Test

**Function Under Test:** `Sync-ConfluenceLicenseReport`

**Test Steps:**
1. Load test tenant license data from CacheExtensionSync
2. Execute sync function
3. Verify Confluence page created/updated
4. Validate data accuracy (SKUs, counts, assignments)

**Evidence Collection:**
- Screenshot of Confluence page with license data
- Sync execution logs
- Performance metrics

### Script 5: Security Data Sync Live Tests

**Functions Under Test:**
- `Sync-ConfluenceMFAStatus`
- `Sync-ConfluenceTeamsInventory`
- `Sync-ConfluenceSharePointInventory`

**Test Steps (per function):**
1. Load test tenant data from CacheExtensionSync
2. Execute sync function
3. Verify Confluence page created/updated
4. Validate data accuracy

**Evidence Collection:**
- Screenshots of all 3 Confluence pages
- Sync execution logs
- Performance metrics

### Script 6: Edge Case Tests

**Test Cases:**

1. **Large Tenant (100+ users)**
   - Execute user sync with large dataset
   - Verify performance meets NFR2 (<10s per page update)
   - Confirm cursor pagination works correctly

2. **Empty Tenant (0 devices)**
   - Execute device sync with empty dataset
   - Verify "No devices found" message displayed
   - Confirm no errors logged

3. **Special Characters in Tenant Name**
   - Test tenant with Unicode/emojis/accents
   - Verify page titles render correctly
   - Confirm ADF content handles special characters

4. **API Rate Limiting**
   - Trigger 429 rate limit response
   - Verify Retry-After header respected
   - Confirm sync eventually succeeds

5. **Network Timeouts**
   - Simulate network timeout during API call
   - Verify retry logic (3 attempts per NFR11)
   - Confirm error logged if retries exhausted

**Evidence Collection:**
- Test execution logs for all edge cases
- Screenshots of successful handling
- Performance metrics

### Script 7: Error Handling Tests

**Error Scenarios:**

1. **Invalid Confluence API Key**
   - Test with expired/revoked token
   - Verify error message: "Confluence API authentication failed: Invalid token"
   - Confirm graceful abort

2. **Missing Confluence Space**
   - Test with non-existent space key
   - Verify error message includes space key and guidance
   - Confirm no corrupt data

3. **Duplicate Page Titles**
   - Test when page title exists
   - Verify conflict resolution (update existing)
   - Confirm CQL query finds existing page

4. **Partial Sync Failure**
   - Test scenario: User sync succeeds, Device sync fails
   - Verify error isolation (User data committed)
   - Confirm result object shows partial success

5. **Error Logging Validation**
   - Verify all errors in result object's `Errors` list
   - Confirm actionable error messages
   - Validate `Get-ConfluenceSyncError` retrieves errors

**Evidence Collection:**
- Error logs for all scenarios
- Screenshots of error messages
- Validation of error isolation

---

## Test Execution Checklist

**Prerequisites:**
- [ ] Test environment fully configured
- [ ] All validation checks passed
- [ ] Test data seeded in CacheExtensionSync
- [ ] Tenant mapping configured in CippMapping

**Test Execution:**
- [ ] Environment validation script executed
- [ ] User sync live test executed
- [ ] Device sync live test executed
- [ ] License sync live test executed
- [ ] MFA sync live test executed
- [ ] Teams sync live test executed
- [ ] SharePoint sync live test executed
- [ ] All 5 edge case tests executed
- [ ] All 5 error handling tests executed

**Evidence Collection:**
- [ ] All screenshots captured
- [ ] All logs collected
- [ ] Performance metrics recorded
- [ ] Test execution results documented

**Reporting:**
- [ ] Live integration test report created
- [ ] All ACs validated (pass/fail documented)
- [ ] Failure root cause analysis completed (if applicable)
- [ ] Report stored in `docs/testing/`

---

## Success Criteria

**Must Meet All 8 Acceptance Criteria:**
1. ✅ Test environment setup complete
2. ✅ User sync validated against real APIs
3. ✅ Device sync validated against real APIs
4. ✅ License sync validated against real APIs
5. ✅ Security data syncs validated (MFA, Teams, SharePoint)
6. ✅ Edge cases tested and handled correctly
7. ✅ Error scenarios tested and handled gracefully
8. ✅ Live testing report created

**Zero Critical Issues:**
- No data corruption observed
- No security vulnerabilities exposed
- No unhandled exceptions during testing

**Performance Validated:**
- Sync times meet NFR2 (<10s per page update)

**Change Detection Verified:**
- Re-sync produces 0 updates when data unchanged

---

## Notes

This test plan focuses on **validation of existing implementation** against real environments, not new feature development. The goal is to ensure all 6 sync types (Users, Devices, Licenses, MFA, Teams, SharePoint) work correctly with real APIs, real network conditions, and real data.

**Testing Strategy:**
- Execute tests in isolated test environment
- Document all findings with evidence
- Create comprehensive report for stakeholders

**Environment Safety:**
- Use dedicated test space in Confluence (CIPPTESTSPACE)
- Use test tenant data only (no production data)
- Verify all operations are reversible
