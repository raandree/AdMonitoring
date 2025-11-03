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

### 🚧 Planned Health Checks

- FSMO Role Availability
- DNS Health
- SYSVOL/DFSR Health
- Time Synchronization
- Database/Log Health
- Security Configuration
- Certificate Health
- Network Configuration
- Performance Metrics

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

### Check AD Service Status

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

### v0.1.0 (In Development)
- ✅ Core health check framework (HealthCheckResult class)
- ✅ Service status monitoring
- ✅ Domain controller reachability testing
- ✅ AD replication status monitoring
- 🚧 FSMO role availability (planned)
- 🚧 HTML report generation (planned)

## Authors

- **AutomatedLab Community** - [raandree](https://github.com/raandree)

## Acknowledgments

- Built with [Sampler](https://github.com/gaelcolas/Sampler) module framework
- Inspired by enterprise AD monitoring needs
- Community feedback and contributions
