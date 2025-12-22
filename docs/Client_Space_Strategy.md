# Client Space Strategy - Per-Client Space Model

**Decision Date:** December 2, 2025
**Decision:** Separate Confluence Space per Client (not child pages)
**Rationale:** Scalability, security, compliance, and premium positioning

---

## Overview

Each client will receive their own dedicated Confluence space with:
- **Complete isolation** via space-level permissions
- **Standardized structure** copied from CLIENT-TEMPLATE
- **Client-specific branding** and customization
- **Audit-friendly** access controls

---

## Space Naming Convention

### Space Name Format:
```
CLIENT - [SPACE KEY] - [Client Name]
```

**Examples:**
- `CLIENT - ACME - Acme Corporation`
- `CLIENT - TECH - TechStart LLC`
- `CLIENT - GLOBA - Global Ventures Inc`

### Space Key Format:
```
[4-5 letter abbreviation]
```

**Examples:**
- `ACME` (Acme Corporation)
- `TECH` (TechStart LLC)
- `GLOBA` (Global Ventures Inc)

### Space Description Template:
```
Client documentation for [Client Name] | Managed by Praesto Pro | Service Tier: [Basic/Business/Pro]
```

---

## CLIENT-TEMPLATE Space Structure

### Space Details:
- **Space Name:** `CLIENT-TEMPLATE`
- **Space Key:** `TEMPLATE`
- **Type:** Knowledge Base
- **Description:** "Master template for all client documentation spaces. DO NOT EDIT - Copy this space for new clients."

### Page Hierarchy:

```
CLIENT-TEMPLATE (Space Home)
│
├── 📋 Overview & Contacts
│   ├── Client Profile & Service Agreement
│   ├── Key Contacts & Escalation Matrix
│   ├── Service Package & SLA Details
│   └── Billing & Contract Information
│
├── 🖥️ Infrastructure Documentation
│   ├── Network Topology
│   │   ├── Network Diagram (Physical)
│   │   ├── Network Diagram (Logical)
│   │   ├── Firewall Configuration
│   │   ├── Switch Configuration
│   │   ├── WiFi Configuration & AP Locations
│   │   ├── VPN Configuration
│   │   ├── IP Allocation Table
│   │   └── DNS Configuration
│   │
│   ├── Server Environment
│   │   ├── Server Inventory
│   │   ├── Domain Controller(s)
│   │   ├── File Servers
│   │   ├── Application Servers
│   │   └── Virtualization Platform
│   │
│   ├── Cloud Services
│   │   ├── Microsoft 365 Configuration
│   │   ├── Azure Resources
│   │   ├── Third-Party SaaS Applications
│   │   └── Cloud Backup Configuration
│   │
│   └── Workstations & Endpoints
│       ├── Standard Build Documentation
│       ├── Hardware Inventory
│       └── Software Licensing
│
├── 🔐 Security & Compliance
│   ├── Security Policies
│   ├── Compliance Requirements
│   ├── Coro Security Deployment
│   ├── EDR/Antivirus Configuration
│   ├── Firewall Security Rules
│   ├── MFA Implementation Status
│   ├── Vulnerability Assessments
│   └── Incident History
│
├── 💾 Backup & Disaster Recovery
│   ├── Backup Configuration (Slide/Axcient)
│   ├── SaaS Backup (Appriver)
│   ├── Recovery Objectives (RTO/RPO)
│   ├── DR Testing Results
│   └── Failover/Failback Procedures
│
├── 🔑 Credentials Reference
│   ├── Microsoft 365 / Azure AD
│   ├── Network Infrastructure
│   ├── Servers
│   ├── Cloud Services
│   └── Vendor Portals
│   └── [NOTE: All credentials stored in 1Password - links only]
│
├── 📝 Client-Specific Procedures
│   ├── Custom SOPs
│   ├── Special Configurations
│   ├── Known Issues & Workarounds
│   └── Change History
│
└── 📞 Support & Service History
    ├── Major Incidents
    ├── Projects Completed
    ├── Maintenance History
    └── SLA Performance Tracking
```

---

## Space Creation Procedure

### Step 1: Create New Space in Confluence

1. Go to Confluence → **Spaces** → **Create Space**
2. Select **Knowledge base** space type
3. Enter space details:
   - **Space name:** `CLIENT - [Client Name]`
   - **Space key:** `[4-5 letter code]`
   - **Description:** `Client documentation for [Client Name] | Managed by Praesto Pro | Service Tier: [tier]`
4. Click **Create**

### Step 2: Configure Space Permissions

**Space Admins:**
- Operations Manager (Matthias)
- Assigned Account Manager

**Can Edit:**
- Assigned Technical Lead
- Assigned L2/L3 Technicians

**Can View (Optional):**
- Client POC contacts (if providing client access)
- Management (for reviews)

### Step 3: Copy Template Structure

1. Navigate to CLIENT-TEMPLATE space
2. For each parent page:
   - Click **•••** → **Copy**
   - Select destination: New client space
   - Include child pages: **Yes**
3. Repeat for all major sections

### Step 4: Customize for Client

1. Update space home page with client name
2. Replace all `[Client Name]` placeholders
3. Remove template instructions
4. Add client logo (if available)
5. Update "Credentials Reference" page with 1Password vault links

### Step 5: Register in CLIENTS-INDEX

Add entry to master client list:
- Client name
- Space link
- Account Manager
- Technical Lead
- Service Tier
- Last Review Date
- Creation Date

---

## Permission Templates by Service Tier

### Basic Package
**Space Admins:**
- Operations Manager

**Can Edit:**
- Assigned Account Manager only

**Can View:**
- Technical team (read-only for reference)

### Business Package
**Space Admins:**
- Operations Manager
- Assigned Account Manager

**Can Edit:**
- Assigned Technical Lead
- Assigned L2/L3 Technicians (as needed)

**Can View:**
- L1 Technicians (read-only)

### Pro Package
**Space Admins:**
- Operations Manager
- Assigned Account Manager
- Client Administrator (optional)

**Can Edit:**
- Assigned Technical Lead
- All assigned technicians
- Client Technical Contact (optional)

**Can View:**
- Client users (read-only to their documentation)

---

## CLIENTS-INDEX Space

### Purpose
Central directory and documentation standards for all client spaces.

### Space Details:
- **Current Space:** CLIENTS (key: CLIENTS)
- **Action Required:** Rename to CLIENTS-INDEX (key: CLIENTIDX or keep CLIENTS)
- **Type:** Knowledge Base
- **Description:** "Master directory of all client documentation spaces | Internal use only"

### Page Structure:

```
CLIENTS-INDEX (Space Home)
│
├── 📚 Master Client Directory
│   └── [Table of all clients with links to their spaces]
│
├── 📋 Documentation Standards
│   ├── Client Documentation Standards
│   ├── Space Creation Procedure
│   ├── Template Structure Reference
│   └── Credential Storage Guidelines
│
├── 🔧 Templates & Resources
│   ├── Network Diagram Templates
│   ├── Asset Inventory Template
│   ├── DR Plan Template
│   └── Client Onboarding Checklist
│
└── 📊 Documentation Health Dashboard
    ├── Completeness Tracking
    ├── Last Review Dates
    └── Quality Metrics
```

---

## Migration Strategy

### Phase 1: Foundation (Week 1)
- [ ] Create CLIENT-TEMPLATE space
- [ ] Build complete page hierarchy in template
- [ ] Create all parent pages with placeholder content
- [ ] Document template in CLIENTS-INDEX

### Phase 2: Pilot (Week 2-3)
- [ ] Identify 3 pilot clients
- [ ] Create spaces for pilot clients
- [ ] Migrate Hudu content using `template_mapped_migration.ps1`
- [ ] Test permissions and access
- [ ] Gather feedback from team

### Phase 3: Bulk Rollout (Week 4-6)
- [ ] Create spaces for all remaining clients
- [ ] Bulk migration of Hudu articles
- [ ] Update 1Password vault links
- [ ] Train team on navigation

### Phase 4: Cleanup (Week 7-8)
- [ ] Archive Hudu (read-only for 30 days)
- [ ] Complete CLIENTS-INDEX directory
- [ ] Final permission audits
- [ ] Document lessons learned

---

## Hudu Article Mapping to Client Spaces

### From Hudu CSV Data:

**File:** `data/client_articles_list.csv`

**Process:**
1. Read CSV to identify client-specific articles
2. For each client:
   - Create their space (if not exists)
   - Map article to appropriate section based on content:
     - Network docs → Infrastructure Documentation > Network Topology
     - Server docs → Infrastructure Documentation > Server Environment
     - Security configs → Security & Compliance
     - Backup docs → Backup & Disaster Recovery
     - Credentials → [DO NOT MIGRATE - reference 1Password]
3. Use `template_mapped_migration.ps1` with space parameter
4. Verify page created in correct section

---

## Automation Opportunities

### PowerShell Script: `create_client_space.ps1`

**Purpose:** Automate client space creation from template

**Features:**
- Accept client name as parameter
- Generate space key automatically
- Copy entire CLIENT-TEMPLATE space structure
- Apply default permissions
- Register in CLIENTS-INDEX
- Output space URL

**Usage:**
```powershell
.\create_client_space.ps1 -ClientName "Acme Corporation" -ServiceTier "Business" -AccountManager "Matthias"
```

**Status:** To be developed in Month 2

---

## Maintenance & Governance

### Quarterly Reviews
- [ ] Review all client space permissions
- [ ] Audit documentation completeness
- [ ] Update outdated information
- [ ] Remove access for departed team members
- [ ] Archive spaces for churned clients

### Annual Reviews
- [ ] Full documentation audit per client
- [ ] Update network diagrams
- [ ] Refresh asset inventories
- [ ] Review and update credentials
- [ ] Client feedback on documentation quality

### Trigger-Based Updates
- **After infrastructure change:** Update relevant docs within 24 hours
- **After security incident:** Update incident history and lessons learned
- **After client onboarding:** Complete all sections within 30 days
- **Before client review:** QA check of all documentation

---

## Success Metrics

### Documentation Completeness (Per Client)
- [ ] Overview & Contacts: 100% complete
- [ ] Infrastructure: 90%+ complete
- [ ] Security: 100% complete
- [ ] Backup & DR: 100% complete
- [ ] Credentials Reference: 100% complete

### Team Adoption
- [ ] 100% of technicians can navigate client spaces
- [ ] 90%+ of tickets reference client documentation
- [ ] Average documentation update within 48 hours of change

### Client Satisfaction
- [ ] Client feedback on documentation quality
- [ ] Reduced escalations due to better documentation
- [ ] Faster onboarding of new clients

---

## Related Documentation

- `docs/Confluence_Upload_Instructions.md` - API usage
- `docs/Hudu_to_Confluence_Migration_Workflow.md` - Migration process
- `CLAUDE.md` - Overall project documentation
- `scripts/template_mapped_migration.ps1` - Migration script

---

**Document Owner:** Operations Manager
**Review Cycle:** Quarterly
**Last Updated:** December 2, 2025

---

**Status:** ✅ APPROVED - Ready for implementation
