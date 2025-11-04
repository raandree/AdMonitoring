# AdMonitoring

**Active Directory Health Monitoring and Automated Reporting System**

A comprehensive PowerShell module for monitoring Active Directory infrastructure health, automating routine checks, and generating actionable reports for AD administrators.

## Overview

AdMonitoring provides enterprise-grade health checks for Active Directory environments, enabling proactive monitoring and rapid issue identification across domain controllers, replication partners, and critical AD services.

## Features

### ✅ Implemented Health Checks

#### 1. Service Status Monitoring (`Get-ADServiceStatus`)
- Monitors critical AD services: NTDS, KDC, DNS, Netlogon, ADWS
- Tracks optional services: DFSR, W32Time, EventLog
- Status levels: Healthy, Warning (manual startup), Critical (stopped/disabled)
- Supports credentials for remote monitoring

#### 2. Domain Controller Reachability (`Test-ADDomainControllerReachability`)
- Comprehensive connectivity testing:
  - DNS name resolution
  - ICMP ping (with firewall consideration)
  - LDAP port 389 connectivity
  - Global Catalog port 3268 (optional)
  - WinRM/PowerShell remoting (optional)
- Configurable timeout values
- Status levels: Healthy, Warning (ICMP blocked), Critical (LDAP/DNS failure)

#### 3. AD Replication Status (`Get-ADReplicationStatus`)
- Monitors replication health across domain controllers:
  - Replication failures and consecutive failure counts
  - Replication latency (time since last successful sync)
  - Replication partner metadata
  - USN (Update Sequence Number) consistency
- Latency thresholds:
  - Healthy: < 15 minutes
  - Warning: 15-60 minutes
  - Critical: > 60 minutes or any failures
- Optional detailed partner information

#### 4. FSMO Role Availability (`Get-ADFSMORoleStatus`)
- All 5 FSMO roles: Schema Master, Domain Naming Master, RID Master, PDC Emulator, Infrastructure Master
- Seized role detection and warnings
- Role holder reachability verification
- Domain and forest-level role checks

#### 5. DNS Health (`Test-ADDNSHealth`)
- SRV record validation for AD services
- A and PTR record checks
- DNS service status monitoring
- Zone health and configuration

#### 6. SYSVOL/DFSR Health (`Test-ADSYSVOLHealth`)
- SYSVOL accessibility checks
- DFSR backlog monitoring
- Replication lag detection
- Share permissions validation

#### 7. Time Synchronization (`Test-ADTimeSync`)
- W32Time service monitoring
- Time offset calculations
- PDC Emulator special handling
- NTP configuration validation

#### 8. Performance Metrics (`Get-ADDomainControllerPerformance`)
- CPU and memory utilization
- Disk space monitoring
- NTDS.dit database size tracking
- Performance counter collection

#### 9. Security Health (`Test-ADSecurityHealth`)
- Secure channel testing
- Trust relationship monitoring
- Account lockout tracking
- Failed authentication analysis
- NTLM usage monitoring

#### 10. Database Health (`Test-ADDatabaseHealth`)
- NTDS.dit integrity checks
- Garbage collection monitoring
- Version store health
- Tombstone lifetime validation

#### 11. Event Log Analysis (`Get-ADCriticalEvents`)
- 27 critical Event IDs across 5 event logs
- Replication, authentication, and system events
- Event-specific recommendations
- Configurable scan windows

#### 12. Certificate Health (`Test-ADCertificateHealth`)
- Certificate expiration monitoring
- LDAPS connectivity validation
- CA health checks
- Certificate store enumeration

### ✅ Reporting & Orchestration

#### Master Orchestration (`Invoke-ADHealthCheck`)
- Run all 12 health checks with single command
- Auto-discovery of domain controllers
- Selective category execution
- Integrated report generation
- Console summary display
- Fail-safe execution

#### HTML Report Generation (`New-ADHealthReport`)
- Professional styling with embedded CSS
- Color-coded status indicators
- Executive summary dashboard
- Detailed findings by category
- Company branding support
- Browser integration with -Show switch

#### Email Delivery (`Send-ADHealthReport`)
- Three body formats: Text, Html, Attachment
- SSL/TLS support
- Authenticated SMTP
- Multiple recipients
- Office 365 and Gmail examples

#### Data Export (`Export-ADHealthData`)
- Four formats: JSON, CSV, XML, CLIXML
- Smart format detection
- GZip compression
- Metadata inclusion
- Append mode for incremental collection

## Installation

### From PowerShell Gallery (Coming Soon)

```powershell
Install-Module -Name AdMonitoring -Scope CurrentUser
```

### From Source

```powershell
# Clone the repository
git clone https://github.com/raandree/AdMonitoring.git
cd AdMonitoring

# Build the module
.\build.ps1 -Tasks build

# Import the module
Import-Module .\output\module\AdMonitoring\AdMonitoring.psd1
```

## Quick Start

### Run Complete Health Check (Recommended)

```powershell
# Run all health checks with a single command and generate HTML report
Invoke-ADHealthCheck -GenerateReport

# Run specific categories only
Invoke-ADHealthCheck -Category Replication,DNS,SYSVOL

# Target specific domain controllers
Invoke-ADHealthCheck -ComputerName DC01,DC02 -GenerateReport
```

### Generate Professional HTML Reports

```powershell
# Run checks and create report
$results = Invoke-ADHealthCheck
New-ADHealthReport -HealthCheckResults $results -Show

# Save report to specific location
New-ADHealthReport -HealthCheckResults $results -OutputPath C:\Reports\AD-Health.html -Show

# Include healthy checks and add company branding
New-ADHealthReport -HealthCheckResults $results `
    -IncludeHealthyChecks `
    -CompanyName "Contoso Ltd" `
    -CompanyLogo "https://contoso.com/logo.png" `
    -Show
```

### Send Email Reports

```powershell
# Send plain text summary
$results = Invoke-ADHealthCheck
Send-ADHealthReport -HealthCheckResults $results `
    -To 'admin@contoso.com' `
    -From 'monitoring@contoso.com' `
    -SmtpServer 'localhost'

# Send HTML report via Office 365
Send-ADHealthReport -HealthCheckResults $results `
    -To 'team@contoso.com' `
    -From 'admon@contoso.com' `
    -SmtpServer 'smtp.office365.com' `
    -Port 587 -UseSsl `
    -Credential (Get-Credential) `
    -BodyFormat Html `
    -Priority High

# Send with HTML attachment
Send-ADHealthReport -HealthCheckResults $results `
    -To 'admin@contoso.com' `
    -From 'monitoring@contoso.com' `
    -SmtpServer 'localhost' `
    -BodyFormat Attachment
```

### Export Data for Analysis

```powershell
# Export to JSON
Invoke-ADHealthCheck | Export-ADHealthData -Path .\AD-Health.json -IncludeMetadata

# Export to CSV for Excel
Invoke-ADHealthCheck | Export-ADHealthData -Path .\AD-Health.csv

# Export to compressed JSON
Invoke-ADHealthCheck | Export-ADHealthData -Path .\AD-Health.json -Compress

# Export with full PowerShell object preservation
Invoke-ADHealthCheck | Export-ADHealthData -Path .\AD-Health.clixml
```

### Individual Health Checks

#### Check AD Service Status

```powershell
# Check all DCs in the domain
Get-ADServiceStatus

# Check specific DCs
Get-ADServiceStatus -ComputerName 'DC01', 'DC02'

# Use alternate credentials
$cred = Get-Credential
Get-ADServiceStatus -ComputerName 'DC01' -Credential $cred
```

### Test DC Connectivity

```powershell
# Test all DCs with full connectivity checks
Test-ADDomainControllerReachability

# Test specific DC excluding WinRM
Test-ADDomainControllerReachability -ComputerName 'DC01' -IncludeWinRM:$false

# Pipeline support
'DC01', 'DC02' | Test-ADDomainControllerReachability
```

### Monitor AD Replication

```powershell
# Check replication status for all DCs
Get-ADReplicationStatus

# Check specific DC with detailed partner info
Get-ADReplicationStatus -ComputerName 'DC01' -IncludePartnerDetails

# Use alternate credentials
Get-ADReplicationStatus -Credential $cred
```

## Requirements

- **PowerShell:** 5.1 or later (cross-platform support with PowerShell 7+)
- **ActiveDirectory Module:** Required for full functionality
- **Permissions:** Domain user with read access to AD (elevated permissions for some checks)
- **Network Access:** Connectivity to domain controllers on required ports (LDAP 389, GC 3268, WinRM 5985/5986)

## Output Format

All health check functions return **HealthCheckResult** objects with consistent structure:

```powershell
HealthCheckResult {
    CheckName    : string    # Name of the health check
    Category     : string    # Category (e.g., "Service Status", "Replication")
    Target       : string    # Target computer/resource
    Status       : string    # Healthy, Warning, or Critical
    Timestamp    : datetime  # When the check was performed
    Message      : string    # Human-readable status message
    Data         : object    # Detailed check data
    Remediation  : string    # Recommended fix (if status is Warning/Critical)
}
```

## Examples

### Filter by Status

```powershell
# Show only critical issues
Get-ADServiceStatus | Where-Object Status -eq 'Critical'

# Show warnings and critical across all checks
$allChecks = Get-ADServiceStatus
$allChecks += Test-ADDomainControllerReachability
$allChecks += Get-ADReplicationStatus
$allChecks | Where-Object Status -in 'Warning', 'Critical'
```

### Export Results

```powershell
# Export to CSV
Get-ADServiceStatus | Export-Csv -Path 'AD_ServiceStatus.csv' -NoTypeInformation

# Export to JSON
Get-ADReplicationStatus | ConvertTo-Json -Depth 5 | Out-File 'AD_Replication.json'

# Generate HTML report
$results = Get-ADServiceStatus
$results | ConvertTo-Html -Title "AD Health Report" | Out-File 'AD_Health_Report.html'
```

### Pipeline Workflows

```powershell
# Get all DCs and run multiple checks
$dcs = Get-ADDomainController -Filter * | Select-Object -ExpandProperty HostName

$dcs | ForEach-Object {
    [PSCustomObject]@{
        DC           = $_
        ServiceCheck = Get-ADServiceStatus -ComputerName $_
        Reachability = Test-ADDomainControllerReachability -ComputerName $_
        Replication  = Get-ADReplicationStatus -ComputerName $_
    }
}
```

## Architecture

Built using the **Sampler** module framework with:
- Modular function design (Public/Private separation)
- Comprehensive Pester test coverage
- PSScriptAnalyzer compliance
- Comment-based help documentation
- Pipeline support across all functions
- Consistent error handling

## Development

### Building from Source

```powershell
# Install dependencies
.\build.ps1 -ResolveDependency

# Build module
.\build.ps1 -Tasks build

# Run tests
.\build.ps1 -Tasks test

# Run specific test
Invoke-Pester -Path .\tests\Unit\Public\Get-ADServiceStatus.Tests.ps1
```

### Project Structure

```
AdMonitoring/
├── source/
│   ├── Classes/           # HealthCheckResult class
│   ├── Public/            # Exported functions
│   ├── Private/           # Internal helper functions
│   └── en-US/             # Help documentation
├── tests/
│   ├── Unit/              # Unit tests (Pester 5)
│   └── QA/                # Quality assurance tests
├── docs/
│   └── memorybank/        # Project documentation
├── build.ps1              # Build automation
└── build.yaml             # Sampler configuration
```

## Testing

All functions include comprehensive Pester 5 tests:
- Parameter validation
- Success scenarios
- Failure scenarios
- Pipeline input
- Error handling

**Current Test Status:**
- ✅ 85/85 tests passing (100%)
- ✅ PSScriptAnalyzer: 0 errors, 0 warnings
- ✅ Code coverage: 50%+ (limited by AD module dependency)

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Follow PowerShell best practices (see `.github/instructions/powershell.instructions.md`)
4. Add Pester tests for new functionality
5. Ensure PSScriptAnalyzer compliance
6. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

- **Issues:** [GitHub Issues](https://github.com/raandree/AdMonitoring/issues)
- **Documentation:** See `docs/` folder
- **Examples:** See function help (`Get-Help Get-ADServiceStatus -Examples`)

## Version History

### v0.1.0 (Current)
**Core Monitoring Functions (12/12 Complete)**
- ✅ Service status monitoring (`Get-ADServiceStatus`)
- ✅ Domain controller reachability (`Test-ADDomainControllerReachability`)
- ✅ AD replication status (`Get-ADReplicationStatus`)
- ✅ FSMO role availability (`Get-ADFSMORoleStatus`)
- ✅ DNS health checks (`Test-ADDNSHealth`)
- ✅ SYSVOL/DFSR monitoring (`Test-ADSYSVOLHealth`)
- ✅ Time synchronization (`Test-ADTimeSync`)
- ✅ Performance metrics (`Get-ADDomainControllerPerformance`)
- ✅ Security health (`Test-ADSecurityHealth`)
- ✅ Database health (`Test-ADDatabaseHealth`)
- ✅ Event log analysis (`Get-ADCriticalEvents`)
- ✅ Certificate health (`Test-ADCertificateHealth`)

**Reporting & Orchestration (4 Functions)**
- ✅ Master orchestration (`Invoke-ADHealthCheck`)
- ✅ HTML report generation (`New-ADHealthReport`)
- ✅ Email delivery (`Send-ADHealthReport`)
- ✅ Multi-format export (`Export-ADHealthData`)

**Module Statistics**
- 16 public functions
- 562 unit tests (100% passing)
- PSScriptAnalyzer compliant
- 6,400+ lines of code
- Production-ready

## Authors

- **AutomatedLab Community** - [raandree](https://github.com/raandree)

## Acknowledgments

- Built with [Sampler](https://github.com/gaelcolas/Sampler) module framework
- Inspired by enterprise AD monitoring needs
- Community feedback and contributions
