# Intent Form and Questionnaire

Analysis of the DISA Vendor STIG Intent Form and STIG Applicability Questionnaire, with mapping to Vulcan's data model.

## Vendor STIG Intent Form

### Purpose

The Intent Form is the first step in the DISA STIG process. It formally notifies DISA that a vendor wants to create a STIG for their product.

- **Submitted to:** `disa.stig_spt@mail.mil`
- **Who fills it out:** An engineer knowledgeable about the product and cybersecurity
- **When:** Before any other STIG development activity
- **Outcome:** DISA reviews internally and notifies vendor whether to proceed

**Source:** U_Vendor_STIG_Intent_Form.pdf

### Form Fields

#### Part I — Vendor Contact Information

| Field | Type | Maps to Vulcan |
|-------|------|---------------|
| Vendor Name (Requestor) | Text | Project metadata |
| Date | Date | Project metadata |
| Vendor POC Name | Text | Project admin_name |
| POC Phone | Text | Project metadata |
| POC Email | Text | Project admin_email |

#### Part II — Product Information

| Field | Type | Maps to Vulcan |
|-------|------|---------------|
| Product Name | Text | Project name |
| Product Vendor | Text | Project metadata |
| Product Version | Text | Component version |
| Previously Worked With APL | Yes/No | Project metadata |
| Product/Security Guide URL | URL | Project metadata |
| Brief Product Description | Textarea | Project description |

#### Part III — Components of the Product

This section directly maps to Vulcan's multi-Component model:

| Field | Type | Vulcan Mapping |
|-------|------|---------------|
| Operating System | Text | Component (GPOS SRG) |
| Virtual Software | Text | Component (Virtual SRG) |
| Web Server | Text | Component (Web Server SRG) |
| Cloud Service | Text | Component (Cloud SRG) |
| Database | Text | Component (Database SRG) |

Each populated technology layer implies a separate Component in Vulcan, each based on a different SRG.

#### Part IV — Sponsor Information

| Field | Type | Maps to Vulcan |
|-------|------|---------------|
| DoD Sponsor | Text | Project metadata |
| Suborganization | Text | Project metadata |
| Sponsor POC Name | Text | Project metadata |
| Sponsor POC Phone | Text | Project metadata |
| Sponsor POC Email | Text | Project metadata |

#### Part V — Additional Information

| Field | Type | Maps to Vulcan |
|-------|------|---------------|
| How is the system used? (SaaS, PaaS, client/server, etc.) | Textarea | Project metadata |
| Other DoD organizations using product | Textarea | Project metadata |
| Total licenses/copies/devices in DoD | Number | Project metadata |
| Amount type (Actual/Estimate) | Checkbox | Project metadata |


## STIG Applicability Questionnaire

### Purpose

The Questionnaire determines which SRGs, STIGs, checklists, and SCAP benchmarks apply to a product. It contains ~50+ technology category checkboxes across 8 sections.

- **Filled out by:** An engineer "fully knowledgeable of the system to be tested"
- **When:** After DISA approves the Intent Form
- **Outcome:** DISA determines the complete set of applicable SRGs

**Source:** STIG_Questionnaire-Released-Nov-2017.pdf (V4.3)

### Sections

| Section | Content | Example Checkboxes |
|---------|---------|-------------------|
| 1. Introduction | Product identification, device list | Product name, model, version, APL status |
| 2. General Type/Function | UC category, device type, management, encryption | Voice/Video/Data, Firewall, VPN, FIPS 140-2, PKI, CAC |
| 3. Network | Backbone, routers, switches, wireless | Cisco, Juniper, Router SRG, Firewall SRG |
| 4. Operating System | OS family and version | Windows, Mac OS, Red Hat, GPOS SRG |
| 5. Software/Applications | Web servers, browsers, databases, app servers | Apache, IIS, Oracle, PostgreSQL, Database SRG |
| 6. Mobile Devices | Mobile OS and MDM | Android, iOS, Samsung, MDM SRG |
| 7. Other Features | Virtualization, exchange, IDS/IPS, VPN | ESXi, vCenter, Palo Alto, NAC |
| 8. Protocols | File transfer, encryption, SIP, directory | FTP, TLS, SSH, LDAP, SNMP |

### SRG Determination Logic

The checkbox selections map to specific SRGs:

| If vendor checks... | Then applicable SRG is... |
|---|---|
| Any OS not specifically listed | General Purpose OS SRG (GPOS) |
| Any database not specifically listed | Database SRG |
| Web server (any) | Web Server SRG |
| Separate management application | Application Security and Development STIG |
| Management built into device OS | Network Device Management SRG |
