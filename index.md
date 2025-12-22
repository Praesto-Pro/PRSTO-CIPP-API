# CIPP-API Project Index

## Core Configuration Files

- **[.dockerignore](./.dockerignore)** - Docker build exclusion patterns
- **[.editorconfig](./.editorconfig)** - Editor formatting rules for PowerShell and JSON
- **[.env.example](./.env.example)** - Example environment variables for development setup
- **[.gitattributes](./.gitattributes)** - Git line ending and diff configurations
- **[.gitignore](./.gitignore)** - Git exclusion patterns for build artifacts
- **[cspell.json](./cspell.json)** - Custom dictionary for spell checking CIPP terminology
- **[docker-compose.yml](./docker-compose.yml)** - Docker orchestration with Azurite, CIPP API, and nginx
- **[Dockerfile](./Dockerfile)** - Azure Functions PowerShell 7.4 container definition
- **[host.json](./host.json)** - Azure Functions host configuration with Durable Task settings
- **[nginx.conf](./nginx.conf)** - Nginx reverse proxy configuration for function app
- **[package.json](./package.json)** - NPM package file (minimal)
- **[package-lock.json](./package-lock.json)** - NPM package lock file
- **[profile.ps1](./profile.ps1)** - PowerShell profile for Azure Functions startup
- **[requirements.psd1](./requirements.psd1)** - Azure Functions PowerShell module dependencies

## API & Permissions

- **[CIPP-Permissions.json](./CIPP-Permissions.json)** - Microsoft Graph and M365 License Manager permissions
- **[CIPPTimers.json](./CIPPTimers.json)** - Scheduled timer functions and orchestrators configuration
- **[openapi.json](./openapi.json)** - OpenAPI specification for CIPP-API endpoints

## Templates & Data

- **[CommunityRepos.json](./CommunityRepos.json)** - CIPP community template repositories list
- **[ConversionTable.csv](./ConversionTable.csv)** - License SKU and service conversion table
- **[intuneCollection.json](./intuneCollection.json)** - Intune policy and configuration collection
- **[TemplateEmail.html](./TemplateEmail.html)** - HTML email template for notifications
- **[words.txt](./words.txt)** - Word list for validation or spell checking

## Version & License

- **[version_latest.txt](./version_latest.txt)** - Current API version (8.7.2)
- **[license.md](./license.md)** - GNU Affero General Public License v3
- **[LICENSE.CustomLicenses](./LICENSE.CustomLicenses)** - Custom license information for third-party components

## Azure Functions

### [AddChocoApp/](./AddChocoApp/)
- **[Choco.app.json](./AddChocoApp/Choco.app.json)** - Chocolatey app metadata
- **[Choco.App.xml](./AddChocoApp/Choco.App.xml)** - Chocolatey app XML configuration
- **[IntunePackage.intunewin](./AddChocoApp/IntunePackage.intunewin)** - Intune packaged Chocolatey installer

### [AddMSPApp/](./AddMSPApp/)
MSP RMM tool deployment packages for Intune:
- **[automate.app.json](./AddMSPApp/automate.app.json)** - ConnectWise Automate app metadata
- **[automate.app.xml](./AddMSPApp/automate.app.xml)** - ConnectWise Automate XML configuration
- **[automate.detection.ps1](./AddMSPApp/automate.detection.ps1)** - Detection script for Automate installation
- **[automate.intunewin](./AddMSPApp/automate.intunewin)** - Packaged Automate installer
- **[cwcommand.app.json](./AddMSPApp/cwcommand.app.json)** - ConnectWise Command app metadata
- **[cwcommand.app.xml](./AddMSPApp/cwcommand.app.xml)** - ConnectWise Command XML configuration
- **[cwcommand.intunewin](./AddMSPApp/cwcommand.intunewin)** - Packaged Command installer
- **[datto.app.json](./AddMSPApp/datto.app.json)** - Datto RMM app metadata
- **[datto.app.xml](./AddMSPApp/datto.app.xml)** - Datto RMM XML configuration
- **[datto.intunewin](./AddMSPApp/datto.intunewin)** - Packaged Datto installer
- **[huntress.app.json](./AddMSPApp/huntress.app.json)** - Huntress agent app metadata
- **[huntress.app.xml](./AddMSPApp/huntress.app.xml)** - Huntress agent XML configuration
- **[huntress.intunewin](./AddMSPApp/huntress.intunewin)** - Packaged Huntress installer
- **[Immybot.app.json](./AddMSPApp/Immybot.app.json)** - ImmyBot app metadata
- **[immy.app.xml](./AddMSPApp/immy.app.xml)** - ImmyBot XML configuration
- **[immy.intunewin](./AddMSPApp/immy.intunewin)** - Packaged ImmyBot installer
- **[ninjarmm.app.json](./AddMSPApp/ninjarmm.app.json)** - NinjaRMM app metadata
- **[ninjarmm.app.xml](./AddMSPApp/ninjarmm.app.xml)** - NinjaRMM XML configuration
- **[syncro.app.json](./AddMSPApp/syncro.app.json)** - Syncro MSP app metadata
- **[syncro.app.xml](./AddMSPApp/syncro.app.xml)** - Syncro MSP XML configuration
- **[syncro.intunewin](./AddMSPApp/syncro.intunewin)** - Packaged Syncro installer

### [Cache_SAMSetup/](./Cache_SAMSetup/)
- **[PermissionsTranslator.json](./Cache_SAMSetup/PermissionsTranslator.json)** - SAM permissions translation mappings
- **[SAMManifest.json](./Cache_SAMSetup/SAMManifest.json)** - Secure Application Model manifest

### [CIPPActivityFunction/](./CIPPActivityFunction/)
- **[function.json](./CIPPActivityFunction/function.json)** - Azure Durable Activity Function binding

### [CIPPHttpTrigger/](./CIPPHttpTrigger/)
- **[function.json](./CIPPHttpTrigger/function.json)** - Azure HTTP Trigger Function binding

### [CIPPOrchestrator/](./CIPPOrchestrator/)
- **[function.json](./CIPPOrchestrator/function.json)** - Azure Durable Orchestrator Function binding

### [CIPPTimer/](./CIPPTimer/)
- **[function.json](./CIPPTimer/function.json)** - Azure Timer Trigger Function binding

### [ExecMaintenanceScripts/](./ExecMaintenanceScripts/)
Maintenance scripts for CIPP operations

## Configuration Templates

### [Config/](./Config/)
CIPP templates for Conditional Access, Intune, Transport Rules, and BPA:
- **[cipp-roles.json](./Config/cipp-roles.json)** - CIPP role-based access control definitions
- **[ExcludeSkuList.JSON](./Config/ExcludeSkuList.JSON)** - License SKUs to exclude from processing
- **[schemaDefinitions.json](./Config/schemaDefinitions.json)** - JSON schema definitions for validation
- **[SchedulerRateLimits.json](./Config/SchedulerRateLimits.json)** - Rate limiting configuration for schedulers
- **[standards.json](./Config/standards.json)** - Security standards and compliance definitions

#### BPA Templates
- **[CIPPDefaultTable.BPATemplate.json](./Config/CIPPDefaultTable.BPATemplate.json)** - Default best practice analyzer template
- **[CIPPDefaultTenantPage.BPATemplate.json](./Config/CIPPDefaultTenantPage.BPATemplate.json)** - Tenant page BPA template
- **[CIPPTenantFeatures.BPATemplate.json](./Config/CIPPTenantFeatures.BPATemplate.json)** - Tenant features assessment template
- **[CyberEssentials.BPATemplate.json](./Config/CyberEssentials.BPATemplate.json)** - Cyber Essentials compliance template
- **[SharePoint.BPATemplate.json](./Config/SharePoint.BPATemplate.json)** - SharePoint best practices template
- **[StandardsTable.BPATemplate.json](./Config/StandardsTable.BPATemplate.json)** - Standards compliance table template

#### Conditional Access Templates
- **[49a8069e-3b46-4680-a035-9250bc675446.CATemplate.json](./Config/49a8069e-3b46-4680-a035-9250bc675446.CATemplate.json)** - Conditional Access policy template
- **[cba836bb-33b7-4c50-88be-ee80f74cbeac.CATemplate.json](./Config/cba836bb-33b7-4c50-88be-ee80f74cbeac.CATemplate.json)** - Conditional Access policy template
- **[f8be7e58-2419-40a8-a739-714bf5deff90.CATemplate.json](./Config/f8be7e58-2419-40a8-a739-714bf5deff90.CATemplate.json)** - Conditional Access policy template

#### Intune Templates
- **[4d9206b0-4f96-41e6-86a5-f78cdcff5069.IntuneTemplate.json](./Config/4d9206b0-4f96-41e6-86a5-f78cdcff5069.IntuneTemplate.json)** - Intune configuration template
- **[59bd753c-4204-4b3a-b84b-850d4b69f494.IntuneTemplate.json](./Config/59bd753c-4204-4b3a-b84b-850d4b69f494.IntuneTemplate.json)** - Intune configuration template
- **[7547f73c-3cb0-460c-a4bd-391944908007.IntuneTemplate.json](./Config/7547f73c-3cb0-460c-a4bd-391944908007.IntuneTemplate.json)** - Intune configuration template
- **[7b41924e-3051-4a23-b0d0-8cdeadc2c05a.IntuneTemplate.json](./Config/7b41924e-3051-4a23-b0d0-8cdeadc2c05a.IntuneTemplate.json)** - Intune configuration template
- **[7e06b0de-0469-4aae-89be-d83c44b5799f.IntuneTemplate.json](./Config/7e06b0de-0469-4aae-89be-d83c44b5799f.IntuneTemplate.json)** - Intune configuration template
- **[b79d0123-3105-4c5d-9f15-62cc7a7eb7e1.IntuneTemplate.json](./Config/b79d0123-3105-4c5d-9f15-62cc7a7eb7e1.IntuneTemplate.json)** - Intune configuration template

#### Transport Rule Templates
- **[4ec40975-c530-44d1-be9e-12f90cac6e95.TransportRuleTemplate.json](./Config/4ec40975-c530-44d1-be9e-12f90cac6e95.TransportRuleTemplate.json)** - Exchange transport rule template
- **[5e4ce5db-1dcd-4423-8131-1379fa2e7621.TransportRuleTemplate.json](./Config/5e4ce5db-1dcd-4423-8131-1379fa2e7621.TransportRuleTemplate.json)** - Exchange transport rule template
- **[8d57edc3-071d-42e7-86b1-126720645ac6.TransportRuleTemplate.json](./Config/8d57edc3-071d-42e7-86b1-126720645ac6.TransportRuleTemplate.json)** - Exchange transport rule template
- **[adf9f6d1-36fb-438b-a82b-71f3af402b6c.TransportRuleTemplate.json](./Config/adf9f6d1-36fb-438b-a82b-71f3af402b6c.TransportRuleTemplate.json)** - Exchange transport rule template
- **[b39b8d85-1531-420e-baeb-b388f565418b.TransportRuleTemplate.json](./Config/b39b8d85-1531-420e-baeb-b388f565418b.TransportRuleTemplate.json)** - Exchange transport rule template
- **[e82dd7d8-3f13-43cd-bdd4-896e0958493b.TransportRuleTemplate.json](./Config/e82dd7d8-3f13-43cd-bdd4-896e0958493b.TransportRuleTemplate.json)** - Exchange transport rule template

## Documentation

### [docs/](./docs/)
- **[project_context.md](./docs/project_context.md)** - AI agent rules and project patterns
- **[sprint-artifacts/](./docs/sprint-artifacts/)** - Sprint planning and tracking documentation

## PowerShell Modules

### [Modules/](./Modules/)
- **[Az.Accounts/](./Modules/Az.Accounts/)** - Azure account authentication and management
- **[Az.Functions/](./Modules/Az.Functions/)** - Azure Functions management module
- **[Az.KeyVault/](./Modules/Az.KeyVault/)** - Azure Key Vault operations
- **[Az.Storage/](./Modules/Az.Storage/)** - Azure Storage management
- **[AzBobbyTables/](./Modules/AzBobbyTables/)** - Azure Table Storage helper module
- **[AzureFunctions.PowerShell.Durable.SDK/](./Modules/AzureFunctions.PowerShell.Durable.SDK/)** - Durable Functions SDK for PowerShell
- **[CIPPCore/](./Modules/CIPPCore/)** - Core CIPP functionality and logic
- **[CippEntrypoints/](./Modules/CippEntrypoints/)** - API entry point handlers
- **[CippExtensions/](./Modules/CippExtensions/)** - Extension modules for CIPP
- **[ConfluenceAPI/](./Modules/ConfluenceAPI/)** - Atlassian Confluence API wrapper
- **[DNSHealth/](./Modules/DNSHealth/)** - DNS health check and validation
- **[HuduAPI/](./Modules/HuduAPI/)** - Hudu documentation platform API
- **[MicrosoftTeams/](./Modules/MicrosoftTeams/)** - Microsoft Teams management module
- **[PassPushPosh/](./Modules/PassPushPosh/)** - Password sharing service integration

## Development Tools

### [Tools/](./Tools/)
- **[Clear-DevEnvironment.ps1](./Tools/Clear-DevEnvironment.ps1)** - Reset development environment to clean state
- **[Confirm-FunctionRequirements.ps1](./Tools/Confirm-FunctionRequirements.ps1)** - Validate Azure Function requirements and dependencies
- **[Initialize-DevEnvironment.ps1](./Tools/Initialize-DevEnvironment.ps1)** - Set up local development environment
- **[Update-LicenseSKUFiles.ps1](./Tools/Update-LicenseSKUFiles.ps1)** - Update Microsoft license SKU reference files
- **[Update-StandardsComments.ps1](./Tools/Update-StandardsComments.ps1)** - Update documentation comments in standards
- **[Update-StandardsJson.ps1](./Tools/Update-StandardsJson.ps1)** - Update standards JSON configuration

#### OpenAPI Specifications
- **[cipp-openapispec.json](./Tools/cipp-openapispec.json)** - CIPP core API specification
- **[endpoint-openapispec.json](./Tools/endpoint-openapispec.json)** - Endpoint management API specification
- **[identity-openapispec.json](./Tools/identity-openapispec.json)** - Identity management API specification
- **[security-openapispec.json](./Tools/security-openapispec.json)** - Security operations API specification
- **[teams-share-openapispec.json](./Tools/teams-share-openapispec.json)** - Teams and SharePoint API specification
- **[tenant-openapispec.json](./Tools/tenant-openapispec.json)** - Tenant management API specification
- **[tools-openapispec.json](./Tools/tools-openapispec.json)** - Tools and utilities API specification

#### Intune Packaging
- **[IntuneWin/](./Tools/IntuneWin/)** - IntuneWin packaging tool for application deployment

## IDE & AI Configuration

### [.claude/](.//.claude/)
Claude Code CLI configuration and commands

### [.cursor/](.//.cursor/)
Cursor AI editor configuration

### [.gemini/](.//.gemini/)
Google Gemini AI configuration

### [.github/](.//.github/)
- **[pull.yml](./.github/pull.yml)** - GitHub Actions workflow for pull requests

### [.vscode/](.//.vscode/)
- **[CIPP-Confluence.code-workspace](./.vscode/CIPP-Confluence.code-workspace)** - VS Code workspace configuration
- **[extensions.json](./.vscode/extensions.json)** - Recommended VS Code extensions
- **[launch.json](./.vscode/launch.json)** - VS Code debugger configuration
- **[settings.json](./.vscode/settings.json)** - VS Code editor settings
- **[tasks.json](./.vscode/tasks.json)** - VS Code build and task automation

## BMAD Configuration

### [_bmad/](.//_bmad/)
BMAD (Build Management and Deployment) framework configuration and documentation
