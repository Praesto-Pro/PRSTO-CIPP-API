# CLIENT-TEMPLATE Space Creation Guide

**Purpose:** Step-by-step instructions to create the master client template space
**Time Required:** 2-3 hours
**Prerequisites:** Confluence admin access

---

## Step 1: Create the Space

1. Go to Confluence: https://praestoworks.atlassian.net/wiki
2. Click **Spaces** (top navigation) → **Create space**
3. Select **Knowledge base** space type
4. Enter space details:
   - **Space name:** `CLIENT-TEMPLATE`
   - **Space key:** `TEMPLATE`
   - **Description:** `Master template for all client documentation spaces. DO NOT EDIT - Copy this space for new clients.`
5. Click **Create**

---

## Step 2: Create Space Home Page

Replace the default home page content with:

```markdown
# CLIENT-TEMPLATE

⚠️ **DO NOT EDIT THIS SPACE**

This is the master template for all client documentation spaces. When onboarding a new client, copy this entire space structure.

---

## Purpose

This template provides a standardized structure for documenting all client environments, ensuring consistency and completeness across all client spaces.

---

## How to Use This Template

### For New Client Onboarding:

1. **Create New Space:**
   - Space name: `CLIENT - [Client Name]`
   - Space key: `[4-5 letter code]`
   - Type: Knowledge base

2. **Copy Structure:**
   - Copy each parent page from this template to the new space
   - Include all child pages when copying
   - Update placeholders with client-specific information

3. **Configure Permissions:**
   - Space Admin: Operations Manager + Account Manager
   - Can Edit: Technical Lead + Assigned Technicians
   - Can View: (Optional) Client contacts

4. **Register in CLIENTS-INDEX:**
   - Add client to master directory
   - Link to their space
   - Document account manager and service tier

---

## Template Structure

Use the navigation tree to explore the complete structure:

📋 **Overview & Contacts** - Client profile, contacts, SLA, contracts
🖥️ **Infrastructure Documentation** - Networks, servers, cloud, endpoints
🔐 **Security & Compliance** - Policies, deployments, assessments
💾 **Backup & Disaster Recovery** - Configurations, testing, procedures
🔑 **Credentials Reference** - 1Password vault links (never store actual passwords)
📝 **Client-Specific Procedures** - Custom SOPs, special configs
📞 **Support & Service History** - Incidents, projects, maintenance

---

## Documentation Standards

### Required for All Clients:
- [ ] Overview & Contacts (100% complete within 7 days of onboarding)
- [ ] Credentials Reference (100% complete within 7 days)
- [ ] Security & Compliance (100% complete within 14 days)
- [ ] Backup & DR (100% complete within 14 days)

### Best Practices:
- Update documentation within 24 hours of any infrastructure change
- Include network diagrams (physical and logical)
- Reference 1Password for all credentials (NEVER store passwords in Confluence)
- Link to related SOPs in INTOPS space
- Add revision date to each major section

---

**Template Version:** 1.0
**Last Updated:** December 2, 2025
**Owner:** Operations Manager
```

---

## Step 3: Create Parent Pages

Create the following parent pages (direct children of space home):

### Page 1: Overview & Contacts

**Title:** `Overview & Contacts`

**Content:**
```markdown
# Overview & Contacts

## Client Profile

| Field | Information |
|-------|-------------|
| **Client Name** | [Client Name] |
| **Industry** | [Industry] |
| **Employee Count** | [Number] |
| **Service Tier** | [Basic / Business / Pro] |
| **Account Manager** | [Name] |
| **Technical Lead** | [Name] |
| **Onboarding Date** | [MM/DD/YYYY] |

---

## Primary Contacts

### Executive Leadership

| Name | Title | Email | Phone | Notes |
|------|-------|-------|-------|-------|
| [Name] | CEO / President | [email] | [phone] | Primary decision maker |
| [Name] | CFO | [email] | [phone] | Billing contact |

### IT Contacts

| Name | Title | Email | Phone | Notes |
|------|-------|-------|-------|-------|
| [Name] | IT Manager | [email] | [phone] | Primary technical contact |
| [Name] | IT Admin | [email] | [phone] | Day-to-day operations |

---

## Escalation Matrix

| Priority | Contact | Response Time | Contact Method |
|----------|---------|---------------|----------------|
| **Critical** (P1) | [Name] | 15 minutes | Call: [phone] |
| **High** (P2) | [Name] | 30 minutes | Call: [phone] |
| **Medium** (P3) | [Name] | 1 hour | Email + Portal |
| **Low** (P4) | Portal | 4-24 hours | Portal ticket |

---

## Service Package & SLA

### Service Tier: [Basic / Business / Pro]

**Coverage Hours:**
- Business Hours: [Hours]
- After-Hours Support: [Yes/No]
- Weekend Support: [Yes/No]

**Response Time SLAs:**

| Priority | Description | Response Time | Resolution Target |
|----------|-------------|---------------|-------------------|
| Critical | Business-critical systems down | 15 minutes | 4 hours |
| High | Major service degradation | 30 minutes | 8 hours |
| Medium | Non-critical issue | 1 hour | 24 hours |
| Low | General request | 4 hours | 48 hours |

**Included Services:**
- [List services included in package]

**Exclusions:**
- [List what's not included]

---

## Contract Information

| Field | Details |
|-------|---------|
| **Contract Start Date** | [MM/DD/YYYY] |
| **Contract End Date** | [MM/DD/YYYY] |
| **Renewal Terms** | [Auto-renew / Manual] |
| **Notice Period** | [Days] |
| **Monthly Recurring Revenue** | $[amount] |

**Contract Location:** [1Password vault link or SharePoint location]

---

**Last Updated:** [Date]
**Updated By:** [Name]
```

**Child Pages to Create:**
1. `Client Profile & Service Agreement`
2. `Key Contacts & Escalation Matrix`
3. `Service Package & SLA Details`
4. `Billing & Contract Information`

---

### Page 2: Infrastructure Documentation

**Title:** `Infrastructure Documentation`

**Content:**
```markdown
# Infrastructure Documentation

This section contains complete technical documentation of the client's IT infrastructure.

---

## Sections

### 🌐 Network Topology
Complete network documentation including physical and logical diagrams, device configurations, and IP allocations.

### 🖥️ Server Environment
Documentation of all servers: domain controllers, file servers, application servers, and virtualization platforms.

### ☁️ Cloud Services
Microsoft 365, Azure, AWS, and other cloud service configurations.

### 💻 Workstations & Endpoints
Standard build documentation, hardware inventory, and software licensing.

---

## Documentation Standards

- **Network diagrams must be updated** within 24 hours of any topology change
- **Server documentation must include** hostname, IP, role, OS version, specs
- **Asset inventories must be reviewed** quarterly
- **All credentials must be referenced** from 1Password (never stored here)

---

**Last Updated:** [Date]
```

**Child Pages (Level 1):**
1. `Network Topology`
2. `Server Environment`
3. `Cloud Services`
4. `Workstations & Endpoints`

**Child Pages (Level 2) - Under "Network Topology":**
1. `Network Diagram (Physical)`
2. `Network Diagram (Logical)`
3. `Firewall Configuration`
4. `Switch Configuration`
5. `WiFi Configuration & AP Locations`
6. `VPN Configuration`
7. `IP Allocation Table`
8. `DNS Configuration`

**Child Pages (Level 2) - Under "Server Environment":**
1. `Server Inventory`
2. `Domain Controller(s)`
3. `File Servers`
4. `Application Servers`
5. `Virtualization Platform`

**Child Pages (Level 2) - Under "Cloud Services":**
1. `Microsoft 365 Configuration`
2. `Azure Resources`
3. `Third-Party SaaS Applications`
4. `Cloud Backup Configuration`

**Child Pages (Level 2) - Under "Workstations & Endpoints":**
1. `Standard Build Documentation`
2. `Hardware Inventory`
3. `Software Licensing`

---

### Page 3: Security & Compliance

**Title:** `Security & Compliance`

**Content:**
```markdown
# Security & Compliance

This section documents all security controls, policies, and compliance requirements for this client.

---

## Security Posture Overview

| Category | Status | Last Review | Notes |
|----------|--------|-------------|-------|
| **Endpoint Protection** | [✅/⚠️/❌] | [Date] | Coro Security deployed |
| **Email Security** | [✅/⚠️/❌] | [Date] | Ironscales configured |
| **Firewall** | [✅/⚠️/❌] | [Date] | [Vendor/Model] |
| **MFA** | [✅/⚠️/❌] | [Date] | [%] of users enrolled |
| **Backup** | [✅/⚠️/❌] | [Date] | [Solution name] |
| **Patch Management** | [✅/⚠️/❌] | [Date] | [%] compliance |

---

## Compliance Requirements

**Industry:** [Industry]

**Applicable Frameworks:**
- [ ] HIPAA (Healthcare)
- [ ] PCI-DSS (Payment processing)
- [ ] GDPR (EU data)
- [ ] SOC 2 (Service organization)
- [ ] ISO 27001 (Information security)
- [ ] NIST CSF (Cybersecurity framework)
- [ ] None / General best practices

**Compliance Status:** [Compliant / In Progress / Non-Compliant]

**Last Assessment:** [Date]

---

## Security Incident History

| Date | Incident Type | Severity | Resolution | Status |
|------|---------------|----------|------------|--------|
| [Date] | [Type] | [Critical/High/Medium/Low] | [Summary] | [Resolved/Ongoing] |

---

**Last Updated:** [Date]
```

**Child Pages:**
1. `Security Policies`
2. `Compliance Requirements`
3. `Coro Security Deployment`
4. `EDR/Antivirus Configuration`
5. `Firewall Security Rules`
6. `MFA Implementation Status`
7. `Vulnerability Assessments`
8. `Incident History`

---

### Page 4: Backup & Disaster Recovery

**Title:** `Backup & Disaster Recovery`

**Content:**
```markdown
# Backup & Disaster Recovery

Complete documentation of backup systems, disaster recovery plans, and business continuity procedures.

---

## Backup Configuration Summary

| System/Service | Backup Solution | Frequency | Retention | Last Successful Backup |
|----------------|----------------|-----------|-----------|------------------------|
| **Servers** | [Slide/Axcient/Other] | [Daily/Hourly] | [Days] | [Timestamp] |
| **Microsoft 365** | Appriver SaaS Backup | Daily | 7 years | [Timestamp] |
| **File Shares** | [Solution] | [Frequency] | [Retention] | [Timestamp] |
| **Databases** | [Solution] | [Frequency] | [Retention] | [Timestamp] |

---

## Recovery Objectives

| Metric | Target | Notes |
|--------|--------|-------|
| **RTO** (Recovery Time Objective) | [Hours] | Maximum acceptable downtime |
| **RPO** (Recovery Point Objective) | [Hours] | Maximum acceptable data loss |

---

## DR Testing Schedule

| Test Date | Test Type | Result | Issues Found | Resolution |
|-----------|-----------|--------|--------------|------------|
| [Date] | [Full/Partial/Tabletop] | [Pass/Fail] | [Description] | [Action taken] |

**Next Scheduled Test:** [Date]

---

**Last Updated:** [Date]
```

**Child Pages:**
1. `Backup Configuration (Slide/Axcient)`
2. `SaaS Backup (Appriver)`
3. `Recovery Objectives (RTO/RPO)`
4. `DR Testing Results`
5. `Failover/Failback Procedures`

---

### Page 5: Credentials Reference

**Title:** `Credentials Reference`

**Content:**
```markdown
# Credentials Reference

⚠️ **CRITICAL: All credentials are stored in 1Password**

**1Password Vault:** `[Client Name] - Credentials`

**NEVER store actual passwords or credentials in Confluence. This page contains ONLY links to 1Password items.**

---

## Microsoft 365 / Azure AD

| Service | Item in 1Password | Notes |
|---------|-------------------|-------|
| Global Admin | [View in 1Password](1password-link) | Primary admin account |
| Break Glass Account 1 | [View in 1Password](1password-link) | Emergency access |
| Break Glass Account 2 | [View in 1Password](1password-link) | Emergency access |

---

## Network Infrastructure

| Device | Management URL | Item in 1Password | Notes |
|--------|----------------|-------------------|-------|
| Firewall | https://[IP or hostname] | [View in 1Password](1password-link) | [Make/Model] |
| Core Switch | https://[IP] | [View in 1Password](1password-link) | [Make/Model] |
| Wireless Controller | https://[IP] | [View in 1Password](1password-link) | [Make/Model] |

---

## Servers

| Server | Purpose | Item in 1Password | Notes |
|--------|---------|-------------------|-------|
| [Hostname] | Domain Controller | [View in 1Password](1password-link) | Windows Server [version] |
| [Hostname] | File Server | [View in 1Password](1password-link) | Windows Server [version] |
| [Hostname] | Application Server | [View in 1Password](1password-link) | [OS] |

---

## Cloud Services

| Service | Item in 1Password | Notes |
|---------|-------------------|-------|
| Azure Subscription | [View in 1Password](1password-link) | Production subscription |
| AWS Account | [View in 1Password](1password-link) | [Account name] |

---

## Vendor Portals

| Vendor | Item in 1Password | Notes |
|--------|-------------------|-------|
| ISP - [Provider] | [View in 1Password](1password-link) | Internet service portal |
| Domain Registrar | [View in 1Password](1password-link) | [Registrar name] |

---

## Line-of-Business Applications

| Application | Item in 1Password | Notes |
|-------------|-------------------|-------|
| [App name] | [View in 1Password](1password-link) | [Purpose] |

---

**Last Updated:** [Date]
```

**Child Pages:**
1. `Microsoft 365 / Azure AD`
2. `Network Infrastructure`
3. `Servers`
4. `Cloud Services`
5. `Vendor Portals`

---

### Page 6: Client-Specific Procedures

**Title:** `Client-Specific Procedures`

**Content:**
```markdown
# Client-Specific Procedures

This section contains custom procedures, special configurations, and known issues specific to this client that differ from standard operating procedures.

---

## Custom SOPs

| SOP Title | Purpose | Last Updated |
|-----------|---------|--------------|
| [SOP name] | [Description] | [Date] |

---

## Special Configurations

| System/Service | Configuration | Reason | Date Implemented |
|----------------|---------------|--------|------------------|
| [System] | [Description] | [Business requirement] | [Date] |

---

## Known Issues & Workarounds

| Issue | Impact | Workaround | Status | Owner |
|-------|--------|------------|--------|-------|
| [Description] | [High/Medium/Low] | [Workaround steps] | [Open/Resolved] | [Name] |

---

## Change History

| Date | Change Description | Changed By | Reason | Approver |
|------|-------------------|------------|--------|----------|
| [Date] | [What changed] | [Name] | [Why] | [Name] |

---

**Last Updated:** [Date]
```

**Child Pages:**
1. `Custom SOPs`
2. `Special Configurations`
3. `Known Issues & Workarounds`
4. `Change History`

---

### Page 7: Support & Service History

**Title:** `Support & Service History`

**Content:**
```markdown
# Support & Service History

Historical record of major incidents, projects, and maintenance activities for this client.

---

## Major Incidents

| Date | Incident | Severity | Impact | Resolution | Duration | Root Cause |
|------|----------|----------|--------|------------|----------|------------|
| [Date] | [Description] | [P1/P2/P3/P4] | [Business impact] | [Summary] | [Time] | [Analysis] |

---

## Projects Completed

| Date | Project | Scope | Status | Notes |
|------|---------|-------|--------|-------|
| [Date] | [Project name] | [Description] | [Complete/In Progress] | [Summary] |

---

## Maintenance History

| Date | Maintenance Type | Systems Affected | Duration | Issues |
|------|------------------|------------------|----------|--------|
| [Date] | [Patching/Upgrade/Other] | [Systems] | [Time] | [Any issues encountered] |

---

## SLA Performance Tracking

### Monthly Metrics

| Month | P1 Response | P2 Response | P3 Response | P4 Response | SLA Compliance |
|-------|-------------|-------------|-------------|-------------|----------------|
| [Month/Year] | [Avg time] | [Avg time] | [Avg time] | [Avg time] | [%] |

---

**Last Updated:** [Date]
```

**Child Pages:**
1. `Major Incidents`
2. `Projects Completed`
3. `Maintenance History`
4. `SLA Performance Tracking`

---

## Step 4: Add Space Restrictions

1. Go to **Space settings** → **Permissions**
2. Remove public access
3. Add specific permissions:
   - **Space Admin:** Operations Manager
   - **View:** Technical team members who need to copy the template
4. Add warning banner (if available in Confluence)

---

## Step 5: Document Template Version

Create a page called "Template Version History":

```markdown
# Template Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0 | December 2, 2025 | Initial template creation | Operations Manager |

---

## Future Enhancements

- [ ] Add network diagram templates
- [ ] Create asset inventory Excel templates
- [ ] Add DR plan checklist
- [ ] Integrate with 1Password API for credential validation
```

---

## Verification Checklist

After creating the template, verify:

- [ ] Space name is "CLIENT-TEMPLATE"
- [ ] Space key is "TEMPLATE"
- [ ] Space home page has clear "DO NOT EDIT" warning
- [ ] All 7 major parent pages created
- [ ] All child pages created under appropriate parents
- [ ] Placeholder content uses `[Brackets]` for easy find/replace
- [ ] No actual client data in template
- [ ] Permissions restrict editing to admins only
- [ ] Template documented in CLIENTS-INDEX space

---

## Next Steps

1. Test the template by creating a pilot client space
2. Copy one section at a time to verify structure
3. Document any improvements needed
4. Create automation script (future enhancement)

---

**Time to Complete:** 2-3 hours
**Status:** Ready to implement
**Owner:** Operations Manager
