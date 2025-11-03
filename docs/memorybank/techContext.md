# Technical Context: Technology Stack & Setup

**Last Updated:** November 3, 2025

## Technology Stack

### Core Technologies

#### PowerShell
- **Primary Version:** PowerShell 5.1 (Windows PowerShell)
- **Supported Version:** PowerShell 7.x (Cross-platform)
- **Minimum Required:** PowerShell 5.1
- **Rationale:** Ensures compatibility with Windows Server 2016+ and Active Directory module

**Key Features Used:**
- Advanced functions with `[CmdletBinding()]`
- Parameter validation and pipeline support
- Classes for structured data (PSCustomObject)
- Parallel job execution
- Error handling with try-catch-finally

#### ActiveDirectory Module
- **Provider:** Microsoft
- **Version:** Varies by OS (comes with RSAT)
- **Installation:** Remote Server Administration Tools (RSAT)
- **Dependency:** Required for all AD cmdlets

**Key Cmdlets:**
```powershell
Get-ADDomainController
Get-ADReplicationFailure
Get-ADReplicationPartnerMetadata
Get-ADForest
Get-ADDomain
Get-ADTrust
Get-ADOptionalFeature
```

#### Sampler Framework
- **Purpose:** PowerShell module scaffolding and build automation
- **Version:** Latest stable (currently 2.x)
- **Components:**
  - Module structure generator
  - Build pipeline (PSake/InvokeBuild)
  - Pester test integration
  - Changelog management
  - Version management

**Benefits:**
- Consistent module structure
- Automated testing pipeline
- Easy version releases
- Community best practices

### Testing Framework

#### Pester
- **Version:** 5.x (latest)
- **Purpose:** Unit and integration testing
- **Coverage Goal:** >80% code coverage

**Test Structure:**
```powershell
BeforeAll {
    # Setup: Import module, mock dependencies
}

Describe ''Function-Name'' {
    Context ''When condition X'' {
        It ''Should do Y'' {
            # Assertion
        }
    }
}
```

**Mocking Strategy:**
- Mock all ActiveDirectory cmdlets
- Mock network calls (Test-Connection, Test-NetConnection)
- Mock WMI/CIM queries
- Mock event log queries

### Build & Development Tools

#### Build System
- **Tool:** Sampler (wraps PSake/InvokeBuild)
- **Build File:** `build.yaml`
- **Build Script:** `build.ps1`

**Build Tasks:**
- `Clean` - Remove build artifacts
- `Build` - Compile module
- `Test` - Run Pester tests
- `Package` - Create distributable package
- `Publish` - Publish to repository

#### Version Control
- **System:** Git
- **Hosting:** GitHub / Azure DevOps / GitLab
- **Branching Strategy:** GitFlow
  - `main` - Production releases
  - `develop` - Integration branch
  - `feature/*` - Feature branches
  - `hotfix/*` - Emergency fixes

#### Code Quality
- **Linter:** PSScriptAnalyzer
- **Settings:** PSGallery ruleset
- **Enforcement:** Pre-commit hooks and CI pipeline

**Critical Rules Enforced:**
- PSUseApprovedVerbs
- PSAvoidUsingCmdletAliases
- PSAvoidUsingWriteHost
- PSUseSingularNouns
- PSAvoidUsingPlainTextForPassword

### Email Delivery

#### Option 1: System.Net.Mail (Selected for Phase 1)
- **Namespace:** System.Net.Mail.SmtpClient
- **Pros:** Built-in, no dependencies, simple
- **Cons:** Limited auth methods, deprecated (but still functional)

```powershell
$smtp = New-Object System.Net.Mail.SmtpClient($smtpServer, $port)
$smtp.EnableSsl = $true
$smtp.Credentials = New-Object System.Net.NetworkCredential($user, $pass)
$smtp.Send($message)
```

#### Option 2: MailKit (Future Enhancement)
- **Source:** NuGet package
- **Pros:** Modern, supports OAuth2, actively maintained
- **Cons:** External dependency, more complex

**Decision:** Start with System.Net.Mail, migrate to MailKit if OAuth2 needed

### Credential Management

#### Phase 1: Encrypted Configuration File
- **Method:** PowerShell CMS encryption
- **Storage:** Encrypted .config file
- **Requirement:** Certificate-based encryption

```powershell
# Encrypt
Protect-CmsMessage -Content $plainText -To $cert -OutFile config.encrypted

# Decrypt
Unprotect-CmsMessage -Path config.encrypted
```

#### Future Options:
- **Windows Credential Manager:** `Get-StoredCredential`
- **Azure Key Vault:** For cloud-connected environments
- **Secret Management Module:** Unified secret management

### Data Storage

#### Report Storage
- **Format:** HTML files
- **Location:** Configurable (default: `C:\ADMonitoring\Reports`)
- **Retention:** Configurable (default: 90 days)
- **Naming:** `ADHealthReport_YYYY-MM-DD_HHmmss.html`

#### Historical Data
- **Format:** JSON
- **Location:** `C:\ADMonitoring\History`
- **Purpose:** Trend analysis
- **Schema:**
```json
{
  "timestamp": "2025-11-03T06:00:00Z",
  "summary": {
    "status": "Healthy",
    "critical": 0,
    "warnings": 2,
    "dcCount": 5
  },
  "checks": [
    {
      "name": "Replication",
      "status": "Healthy",
      "metrics": {...}
    }
  ]
}
```

#### Configuration Storage
- **Format:** PowerShell Data File (.psd1)
- **Location:** `C:\ADMonitoring\config.psd1` or module directory
- **Validation:** Schema validation on load

### External Dependencies

#### Required Modules
```powershell
# Module manifest RequiredModules
@{
    RequiredModules = @(
        @{ ModuleName = ''ActiveDirectory''; ModuleVersion = ''1.0.0.0'' }
    )
}
```

#### Optional Modules (for enhanced features)
```powershell
@(
    ''ChangelogManagement''  # For changelog updates
    ''PSScriptAnalyzer''    # For code quality checks
    ''Pester''              # For testing
)
```

## Development Environment Setup

### Prerequisites

1. **Windows 10/11 or Windows Server 2016+**
2. **PowerShell 5.1 or PowerShell 7+**
3. **Git** - Version control
4. **VS Code** (recommended) with extensions:
   - PowerShell extension
   - GitLens
   - Markdown All in One
5. **RSAT Tools** (includes ActiveDirectory module)

### Installation Steps

#### 1. Install RSAT (if not already installed)
```powershell
# Windows 10/11
Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0

# Windows Server
Install-WindowsFeature -Name RSAT-AD-PowerShell
```

#### 2. Install Sampler
```powershell
Install-Module -Name Sampler -Scope CurrentUser -Force
```

#### 3. Install Development Dependencies
```powershell
Install-Module -Name Pester -MinimumVersion 5.0 -Scope CurrentUser -Force
Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force
Install-Module -Name ChangelogManagement -Scope CurrentUser -Force
```

#### 4. Clone Repository
```powershell
git clone https://github.com/yourorg/AdMonitoring.git
cd AdMonitoring
```

#### 5. Install Module Dependencies
```powershell
./build.ps1 -ResolveDependency -Task noop
```

#### 6. Build Module
```powershell
./build.ps1 -Task Build
```

#### 7. Run Tests
```powershell
./build.ps1 -Task Test
```

## Build Configuration

### build.yaml Structure
```yaml
---
####################################################
#          ModuleBuilder Configuration             #
####################################################
ModuleBuilder:
  Path: source
  VersionedOutputDirectory: true
  CopyPaths:
    - en-US
    - Config
    - Resources

####################################################
#       Pester Configuration                       #
####################################################
Pester:
  OutputFormat: NUnitXML
  ExcludeFromCodeCoverage:
    - Tests
  Script:
    - tests/Unit
  CodeCoverage:
    CoveragePercentTarget: 80
    OutputPath: output/testResults/coverage.xml

####################################################
#       PSScriptAnalyzer Configuration            #
####################################################
PSScriptAnalyzer:
  Rules:
    PSUseApprovedVerbs: true
    PSAvoidUsingCmdletAliases: true
    PSAvoidUsingWriteHost: true
  ExcludeRules:
    - PSUseShouldProcessForStateChangingFunctions # Reports are read-only
  CustomRulePath: []
  IncludeDefaultRules: true
  Severity:
    - Error
    - Warning

####################################################
#       Package Configuration                      #
####################################################
package:
  buildOutputPath: output

####################################################
#       Publishing Configuration                   #
####################################################
publish:
  PSRepository: PSGallery # or private repo
  ApiKey: $(PSGALLERY_API_KEY)
```

### RequiredModules.psd1
```powershell
@{
    PSDependOptions = @{
        Target = ''CurrentUser''
    }
    
    ''ActiveDirectory'' = ''latest''
    ''Pester'' = @{
        Version = ''5.0.0''
        Parameters = @{
            SkipPublisherCheck = $true
        }
    }
    ''PSScriptAnalyzer'' = ''latest''
    ''ChangelogManagement'' = ''latest''
    ''Sampler'' = ''latest''
}
```

## CI/CD Pipeline (Future)

### GitHub Actions Example
```yaml
name: Build and Test

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

jobs:
  build:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Run Build
        shell: pwsh
        run: |
          ./build.ps1 -ResolveDependency -Task Build, Test
          
      - name: Publish Test Results
        uses: EnricoMi/publish-unit-test-result-action@v1
        if: always()
        with:
          files: output/testResults/*.xml
```

## Local Testing Environment

### Lab Environment Requirements

For comprehensive testing, recommend lab environment with:
- **Domain Controllers:** Minimum 2 (multi-DC replication testing)
- **Sites:** Minimum 2 (inter-site replication testing)
- **Domains:** 1 (can expand to 2 for trust testing)
- **Operating Systems:** Windows Server 2016, 2019, 2022 mix

### Lab Setup Options

#### Option 1: Hyper-V Lab
- Use AutomatedLab or MSLab for quick provisioning
- Nested virtualization for flexibility
- Snapshot capability for testing

#### Option 2: Azure Lab
- Azure VMs for domain controllers
- Cost-effective with auto-shutdown
- Accessible from anywhere

#### Option 3: Docker/Containers
- Limited AD support
- Good for module structure testing
- Cannot test full AD health checks

**Recommended:** Hyper-V with MSLab for comprehensive testing

## Performance Considerations

### Execution Time Targets
- **Single DC Check:** < 30 seconds
- **5 DC Environment:** < 2 minutes (parallel execution)
- **20 DC Environment:** < 5 minutes (parallel execution)
- **Report Generation:** < 30 seconds

### Optimization Strategies
1. **Parallel Execution:** Use `Start-Job` or `ForEach-Object -Parallel`
2. **Caching:** Cache DC list, forest/domain info
3. **Selective Checks:** Allow disabling non-critical checks
4. **Timeout Management:** Set reasonable timeouts for unresponsive DCs
5. **Efficient Queries:** Use filters in AD cmdlets

### Resource Usage Targets
- **Memory:** < 500 MB for typical environment
- **CPU:** < 10% average during execution
- **Network:** Minimal bandwidth (LDAP queries only)
- **DC Impact:** Negligible (read-only queries)

## Security Considerations

### Least Privilege
- **Required Permissions:** Domain Users group membership
- **AD Permissions:** Read access to domain (default for authenticated users)
- **WMI/CIM:** Remote access to DCs (default for domain admins)
- **Event Logs:** Remote event log access

**Recommendation:** Run as dedicated monitoring service account with minimal permissions

### Credential Security
1. **No Plain Text:** Never store credentials in plain text
2. **Encryption:** Use CMS or other encryption for stored credentials
3. **Secure Transmission:** Always use SSL/TLS for SMTP
4. **Audit Trail:** Log all credential access

### Code Security
1. **Input Validation:** Validate all user input
2. **No Injection:** Avoid `Invoke-Expression` with user input
3. **Error Handling:** Don''t expose sensitive info in errors
4. **Dependency Scanning:** Regular security updates

## Troubleshooting

### Common Issues

#### Issue: "Module ''ActiveDirectory'' not found"
**Solution:**
```powershell
# Install RSAT
Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0
Import-Module ActiveDirectory
```

#### Issue: "Access Denied" when querying DCs
**Solution:**
- Verify running account has domain read permissions
- Check Windows Firewall on DCs
- Verify WinRM enabled: `Enable-PSRemoting`

#### Issue: Build fails with Pester errors
**Solution:**
```powershell
# Ensure Pester 5.x
Install-Module Pester -MinimumVersion 5.0 -Force -SkipPublisherCheck
Import-Module Pester -MinimumVersion 5.0
```

#### Issue: Email sending fails
**Solution:**
- Verify SMTP server and port
- Check SSL/TLS requirements
- Test credentials manually
- Check firewall rules

## Documentation Standards

### Function Documentation Template
```powershell
<#
.SYNOPSIS
    Brief one-line description.

.DESCRIPTION
    Detailed description of what the function does, including any important
    behavior or considerations.

.PARAMETER ParameterName
    Description of the parameter.

.EXAMPLE
    Function-Name -Parameter Value
    
    Description of what this example demonstrates.

.EXAMPLE
    Function-Name -Parameter Value -Verbose
    
    Another example showing different usage.

.INPUTS
    System.String
    You can pipe strings to this function.

.OUTPUTS
    System.Management.Automation.PSCustomObject
    Returns a custom object with health check results.

.NOTES
    Author: IT Team
    Last Modified: 2025-11-03
    Requires: ActiveDirectory module

.LINK
    https://docs.example.com/admonitoring/function-name
#>
```

### Changelog Format
Uses ChangelogManagement module with Keep a Changelog format:
```markdown
# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

## [1.0.0] - 2025-11-30

### Added
- Initial release
- Core health check functions
- HTML email reporting

### Changed
- N/A

### Deprecated
- N/A

### Removed
- N/A

### Fixed
- N/A

### Security
- N/A
```

## Platform Compatibility

### Windows Versions
- ✅ Windows Server 2016
- ✅ Windows Server 2019
- ✅ Windows Server 2022
- ✅ Windows Server 2025
- ✅ Windows 10 (with RSAT)
- ✅ Windows 11 (with RSAT)

### PowerShell Versions
- ✅ PowerShell 5.1 (Windows PowerShell)
- ✅ PowerShell 7.x (PowerShell Core)

### Active Directory Functional Levels
- ✅ Windows Server 2008 R2 and higher
- ⚠️ Windows Server 2003 (limited support)

## Future Technical Enhancements

### Phase 2+
- **Database Backend:** SQL Server or SQLite for historical data
- **Web Dashboard:** ASP.NET Core or PowerShell Universal
- **REST API:** For programmatic access
- **OAuth2 Support:** Modern authentication for email
- **Multi-Threading:** Replace jobs with runspaces for better performance
- **Azure Integration:** Send metrics to Azure Monitor / Log Analytics