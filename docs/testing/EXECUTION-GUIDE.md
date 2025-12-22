# Live Integration Testing Execution Guide

**Story:** 11.2 - Live Integration Testing
**Created:** 2025-12-21
**Status:** Framework Ready - Awaiting Live Execution

---

## Important Notice

**This story requires MANUAL execution by a QA engineer with access to a live CIPP and Confluence environment.**

The dev agent (Claude) has completed **Task 1: Prepare Live Test Environment** by creating the comprehensive testing framework. However, **Tasks 2-8 cannot be automated** because they require:

1. Access to a real CIPP Function App instance
2. Access to a real Confluence Cloud instance
3. Access to Azure Table Storage with live M365 tenant data
4. Manual evidence collection (screenshots of Confluence pages)
5. Analysis of live test results

---

## What Has Been Completed (Task 1)

✅ **Live Integration Testing Framework Created**

The following test framework components are ready for use:

1. **Test Plan** - [docs/testing/live-integration-test-plan.md](live-integration-test-plan.md)
2. **Environment Validation Script** - [docs/testing/scripts/Test-LiveIntegrationEnvironment.ps1](scripts/Test-LiveIntegrationEnvironment.ps1)
3. **Live Test Execution Script** - [docs/testing/scripts/Invoke-LiveIntegrationTests.ps1](scripts/Invoke-LiveIntegrationTests.ps1)
4. **Test Report Template** - [docs/testing/live-integration-test-report-template.md](live-integration-test-report-template.md)
5. **Testing Framework README** - [docs/testing/README.md](README.md)

---

## What Needs to Be Done (Tasks 2-8)

### Prerequisites

Before executing live tests, you need:

1. **CIPP Instance Access**
   - Real CIPP Function App (not local dev environment)
   - Test tenant configured in CIPP
   - CacheExtensionSync table populated with M365 data for test tenant
   - CIPP framework modules available (Get-ExtensionAPIKey, Get-ExtensionCacheData, Get-CIPPTable)

2. **Confluence Instance Access**
   - Confluence Cloud instance (your organization's instance OR Atlassian trial)
   - Test space created (recommended: `CIPPTESTSPACE`)
   - API token with required permissions:
     - `write:confluence-content`
     - `write:confluence-space`
     - `read:confluence-content`
   - API token stored in Azure Key Vault (prod) or DevSecrets table (dev)

3. **Azure Table Storage Access**
   - CacheExtensionSync - M365 data cache (test tenant data required)
   - CippMapping - Tenant mapping (test tenant → test space mapping required)
   - Extensionsconfig - Extension config (Confluence BaseURL required)
   - CacheConfluencePages - Page cache (for change detection testing)

4. **Test Data Requirements**
   - 10+ licensed users with mailboxes and OneDrive
   - 10+ Intune devices with varied compliance statuses
   - Multiple license SKUs with assignments
   - MFA-enabled and non-MFA users
   - 5+ Teams with membership
   - 5+ SharePoint sites

### Option 1: Execute Tests Yourself (Recommended if you have access)

If you have access to the required environments:

**Step 1: Validate Environment**
```powershell
cd C:\Dev\PRSTO-CIPP-API
.\docs\testing\scripts\Test-LiveIntegrationEnvironment.ps1 `
    -TestTenantId 'YOUR-TENANT-ID' `
    -TestSpaceKey 'CIPPTESTSPACE'
```

**Expected:** All validation checks pass (✅)

**If validation fails:**
- Review failed checks
- Fix environment issues
- Re-run validation

**Step 2: Execute Live Tests**
```powershell
.\docs\testing\scripts\Invoke-LiveIntegrationTests.ps1 `
    -TestTenantId 'YOUR-TENANT-ID' `
    -TestSpaceKey 'CIPPTESTSPACE'
```

**Expected:** Test execution completes with results exported to JSON

**Step 3: Collect Evidence**
- Take screenshots of all Confluence pages created during testing
- Save test execution logs
- Record performance metrics
- Document any failures with root cause analysis

**Step 4: Create Test Report**
- Copy `docs/testing/live-integration-test-report-template.md`
- Fill in placeholders with actual test results
- Add screenshots and evidence
- Save as `docs/testing/live-integration-test-report-YYYY-MM-DD.md`

**Step 5: Mark Tasks Complete**
- Update story file: Mark Tasks 2-8 as complete [x]
- Update sprint status: Change story status to 'review'

### Option 2: Delegate to QA Engineer (Dana)

If you don't have access to the required environments, delegate to the QA engineer (Dana from Epic 10 Retrospective):

**Handoff Documentation:**
1. Share this execution guide with QA engineer
2. Ensure QA engineer has access to:
   - CIPP Function App instance
   - Confluence Cloud instance
   - Azure Table Storage
   - Test tenant with representative M365 data
3. Provide test scripts location: `docs/testing/scripts/`
4. Request comprehensive test report with evidence

**QA Engineer Responsibilities:**
- Execute environment validation script
- Execute live integration tests
- Collect evidence (screenshots, logs, performance metrics)
- Create comprehensive test report
- Document any failures with root cause analysis
- Provide production readiness recommendation

### Option 3: Skip Live Testing (NOT RECOMMENDED)

**⚠️ WARNING: This option is NOT recommended and violates Epic 11 goals.**

Epic 11 was created specifically to enable safe production deployment. Story 11.2 (Live Integration Testing) is a **CRITICAL** blocker for production deployment because:

- All existing tests (1,657+) are **mocked** unit/integration tests
- Real APIs, real networks, and real data have **NOT** been validated
- Edge cases (rate limiting, timeouts, large datasets) have **NOT** been tested
- Error handling with real API failures has **NOT** been validated

**If you choose to skip:**
1. Document the decision and risk in story file
2. Mark story as 'blocked' (not 'done')
3. Create follow-up story for live testing in future sprint
4. **DO NOT** deploy to production without live testing

---

## Execution Timeline

From Epic 10 Retrospective (Action Item #4):
- **Owner:** Dana (QA Engineer)
- **Priority:** CRITICAL
- **Estimated Timeline:** 2-3 days
- **Dependencies:** Epic 11.1 (Security Review) complete

**Recommended Schedule:**
- **Day 1:** Environment setup and validation
- **Day 2:** Test execution (all 6 sync types, edge cases, error handling)
- **Day 3:** Evidence collection and test report creation

---

## Decision Required

**Matthias, you need to decide:**

1. **Execute tests yourself** (if you have access to live CIPP + Confluence)
2. **Delegate to QA engineer** (Dana or equivalent)
3. **Skip live testing** (NOT recommended - blocks production deployment)

**Recommended Action:**
- If you have access: Execute tests yourself using the provided scripts
- If you don't have access: Delegate to QA engineer with comprehensive handoff
- Document decision in story file

---

## Support

If you encounter issues during live test execution:

1. **Environment Validation Failures:**
   - Review troubleshooting section in [docs/testing/README.md](README.md#troubleshooting)
   - Check CIPP framework function availability
   - Verify Confluence API token permissions
   - Confirm Azure Table Storage access

2. **Test Execution Failures:**
   - Review error details in JSON results export
   - Check verbose logs from sync functions
   - Verify test tenant data is populated
   - Confirm tenant mapping exists

3. **Performance Issues:**
   - Check network latency to Confluence API
   - Review page sizes (large pages may exceed 10s threshold)
   - Verify cursor pagination works correctly

4. **Questions:**
   - Review testing framework README: [docs/testing/README.md](README.md)
   - Review test plan: [docs/testing/live-integration-test-plan.md](live-integration-test-plan.md)
   - Consult Epic 11.2 specification: [docs/sprint-artifacts/11-2-live-integration-testing.md](../sprint-artifacts/11-2-live-integration-testing.md)

---

## Next Steps

**Immediate:**
1. Review this execution guide
2. Decide on execution approach (self-execute, delegate, or skip)
3. If delegating: Create handoff documentation for QA engineer
4. If self-executing: Validate environment access

**After Tests Complete:**
1. Review test report
2. Address any critical issues found
3. Mark story as 'review' in sprint status
4. Proceed to Story 11.3 (CI/CD Pipeline Verification)

---

**Created:** 2025-12-21
**Author:** Claude Sonnet 4.5 (via dev-story workflow)
**Story:** 11.2 - Live Integration Testing
