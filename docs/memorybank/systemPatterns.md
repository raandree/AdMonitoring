# System Patterns: AD Monitoring Architecture

**Last Updated:** November 3, 2025

## Overview

This document defines the architecture, patterns, and monitoring categories for the AdMonitoring system. It establishes the systematic approach to Active Directory health assessment based on Microsoft best practices and industry standards.

## Architecture Philosophy

### Core Principles

1. **Separation of Concerns**
   - **Data Collection:** Functions that gather raw health data
   - **Analysis:** Functions that interpret data and determine health status
   - **Reporting:** Functions that format and deliver results
   - **Configuration:** Centralized settings management

2. **Single Responsibility**
   - Each health check function focuses on ONE specific aspect
   - No monolithic "check everything" functions
   - Compose comprehensive reports from modular checks

3. **Testability First**
   - All functions designed for unit testing
   - Mock-friendly interfaces
   - Predictable inputs and outputs

4. **Defensive Coding**
   - Assume DCs may be unreachable
   - Graceful degradation on partial failures
   - Never let one check failure abort entire report

5. **Performance Conscious**
   - Parallel execution where possible
   - Caching of repeated queries
   - Configurable timeouts
   - Minimal DC impact

## Health Check Categories

Based on Microsoft best practices and industry standards, AD health monitoring is organized into these categories:

### 1. Domain Controller Service Status
**Priority:** CRITICAL  
**Description:** Verifies all essential AD services are running on each DC

**Services to Monitor:**
- Active Directory Domain Services (NTDS)
- Kerberos Key Distribution Center (KDC)
- DNS Server
- Netlogon
- Intersite Messaging (IsmServ)
- DFS Replication (DFSR)
- File Replication Service (FRS) - if not using DFSR
- Active Directory Web Services (ADWS)

**Health Criteria:**
- 🟢 **Healthy:** All services running and automatic startup
- 🟡 **Warning:** Service running but manual startup configured
- 🔴 **Critical:** Any service stopped or disabled

**PowerShell Approach:**
```powershell
Get-Service -ComputerName $DomainController -Name NTDS, KDC, DNS, Netlogon
Test-ServiceStatus -RequiredServices @(''NTDS'', ''KDC'', ''DNS'', ''Netlogon'')
```

**Implementation Functions:**
- `Get-ADServiceStatus` - Collects service status from DCs
- `Test-ADServiceHealth` - Analyzes service status and returns health state

---

### 2. Domain Controller Reachability
**Priority:** CRITICAL  
**Description:** Ensures all DCs are network-accessible and responding

**Checks:**
- Network ping (ICMP)
- LDAP port 389 connectivity
- Global Catalog port 3268 connectivity (if GC)
- WinRM/PowerShell remoting availability
- DNS name resolution

**Health Criteria:**
- 🟢 **Healthy:** All connectivity tests pass
- 🟡 **Warning:** Ping fails but LDAP responsive (firewall blocks ICMP)
- 🔴 **Critical:** LDAP unresponsive or DNS resolution fails

**PowerShell Approach:**
```powershell
Test-Connection -ComputerName $DC -Count 2 -Quiet
Test-NetConnection -ComputerName $DC -Port 389
Test-NetConnection -ComputerName $DC -Port 3268
Test-WSMan -ComputerName $DC
```

**Implementation Functions:**
- `Test-ADDomainControllerReachability` - Tests DC connectivity
- `Get-ADDomainControllerConnectivity` - Returns connectivity status object

---

### 3. Active Directory Replication
**Priority:** CRITICAL  
**Description:** Monitors replication health between all domain controllers

**Checks:**
- Replication failures (last error, consecutive failures)
- Replication latency (time since last successful sync)
- Replication queue depth
- Replication partner status
- Inter-site replication health
- USN (Update Sequence Number) consistency

**Health Criteria:**
- 🟢 **Healthy:** No failures, latency < 15 minutes
- 🟡 **Warning:** Latency 15-60 minutes, no failures
- 🔴 **Critical:** Any replication failures or latency > 60 minutes

**PowerShell Approach:**
```powershell
Get-ADReplicationFailure -Target $DC
Get-ADReplicationPartnerMetadata -Target $DC
Get-ADReplicationUpToDatenessVectorTable -Target $DC
repadmin /showrepl $DC
```

**Implementation Functions:**
- `Get-ADReplicationStatus` - Collects replication metadata
- `Test-ADReplicationHealth` - Analyzes replication health
- `Get-ADReplicationLatency` - Calculates replication lag

---

### 4. FSMO Role Availability
**Priority:** CRITICAL  
**Description:** Verifies all 5 FSMO roles are available and responsive

**FSMO Roles to Monitor:**
1. **Schema Master** (Forest-wide)
2. **Domain Naming Master** (Forest-wide)
3. **PDC Emulator** (Per-domain)
4. **RID Master** (Per-domain)
5. **Infrastructure Master** (Per-domain)

**Checks:**
- Identify current role holders
- Verify role holder DC is online
- Test role responsiveness
- Check for seized roles (event log)
- Validate Infrastructure Master not on GC (unless all DCs are GCs)

**Health Criteria:**
- 🟢 **Healthy:** All roles available, proper placement
- 🟡 **Warning:** Role holder high load, Infrastructure Master placement issue
- 🔴 **Critical:** Any role holder offline or unresponsive

**PowerShell Approach:**
```powershell
Get-ADForest | Select-Object SchemaMaster, DomainNamingMaster
Get-ADDomain | Select-Object PDCEmulator, RIDMaster, InfrastructureMaster
Test-Connection -ComputerName $FSMOHolder
```

**Implementation Functions:**
- `Get-ADFSMORoleHolder` - Identifies all FSMO role holders
- `Test-ADFSMOAvailability` - Tests FSMO role holder availability
- `Test-ADFSMOPlacement` - Validates FSMO placement best practices

---

### 5. DNS Health
**Priority:** CRITICAL  
**Description:** Validates DNS functionality critical to AD operations

**Checks:**
- DNS service running on DCs
- DNS zone loading and replication
- AD-integrated zones (primary zones on all DCs)
- SRV record registration (_ldap, _kerberos, _gc)
- Forward and reverse lookup zones
- Aging/scavenging configuration
- Dynamic updates enabled

**Health Criteria:**
- 🟢 **Healthy:** All checks pass, SRV records registered
- 🟡 **Warning:** Scavenging not configured, zone transfer delays
- 🔴 **Critical:** SRV records missing, zone not loading, service stopped

**PowerShell Approach:**
```powershell
Get-DnsServerZone -ComputerName $DC
Get-DnsServerResourceRecord -ZoneName $Domain -RRType SRV
Resolve-DnsName -Name "_ldap._tcp.$Domain" -Type SRV
Test-DnsServer -IPAddress $DCIP -ZoneName $Domain
```

**Implementation Functions:**
- `Get-ADDnsZoneHealth` - Collects DNS zone status
- `Test-ADDnsSrvRecords` - Validates SRV record registration
- `Test-ADDnsHealth` - Overall DNS health assessment

---

### 6. SYSVOL and DFSR Health
**Priority:** HIGH  
**Description:** Monitors SYSVOL replication status (Group Policy dependency)

**Checks:**
- SYSVOL share accessibility
- DFSR replication state (or FRS if not migrated)
- DFSR backlog queue depth
- SYSVOL/Netlogon share sharing
- Group Policy template replication
- DFSR database health

**Health Criteria:**
- 🟢 **Healthy:** SYSVOL accessible, backlog < 100, no errors
- 🟡 **Warning:** Backlog 100-500, replication lag < 1 hour
- 🔴 **Critical:** SYSVOL not shared, backlog > 500, replication stopped

**PowerShell Approach:**
```powershell
Get-SmbShare -Name SYSVOL -CimSession $DC
Test-Path "\\$DC\SYSVOL"
Get-DfsrBacklog -GroupName "Domain System Volume" -FolderName "SYSVOL Share"
dfsrdiag ReplicationState /member:$DC
```

**Implementation Functions:**
- `Get-ADSysvolShareStatus` - Checks SYSVOL share availability
- `Get-ADDfsrBacklog` - Measures DFSR backlog
- `Test-ADSysvolHealth` - Overall SYSVOL health assessment

---

### 7. Time Synchronization
**Priority:** HIGH  
**Description:** Ensures accurate time sync (critical for Kerberos)

**Checks:**
- PDC Emulator configured as authoritative time source
- PDC sync with external NTP source
- Other DCs sync with PDC Emulator
- Time offset between DCs (threshold: 5 minutes)
- W32Time service status
- Time sync stratum levels

**Health Criteria:**
- 🟢 **Healthy:** All DCs within 30 seconds, PDC synced with NTP
- 🟡 **Warning:** DCs within 5 minutes, PDC not synced externally
- 🔴 **Critical:** Any DC offset > 5 minutes (Kerberos will fail)

**PowerShell Approach:**
```powershell
w32tm /query /source
w32tm /query /status
Get-Date on each DC and compare
w32tm /monitor /computers:$DC1,$DC2,$DC3
```

**Implementation Functions:**
- `Get-ADTimeConfiguration` - Gets time source configuration
- `Get-ADTimeOffset` - Calculates time difference between DCs
- `Test-ADTimeSync` - Validates time synchronization health

---

### 8. Domain Controller Performance
**Priority:** MEDIUM  
**Description:** Monitors DC resource utilization and performance

**Checks:**
- CPU utilization
- Memory usage (committed bytes, available)
- Disk space (especially NTDS.dit location)
- NTDS.dit and log file size
- Network bandwidth utilization
- Active LDAP connections
- LSASS process memory usage

**Health Criteria:**
- 🟢 **Healthy:** CPU < 70%, Memory < 80%, Disk > 20% free
- 🟡 **Warning:** CPU 70-90%, Memory 80-90%, Disk 10-20% free
- 🔴 **Critical:** CPU > 90%, Memory > 90%, Disk < 10% free

**PowerShell Approach:**
```powershell
Get-Counter -ComputerName $DC -Counter "\Processor(_Total)\% Processor Time"
Get-CimInstance -ClassName Win32_OperatingSystem -ComputerName $DC
Get-PSDrive -PSProvider FileSystem -ComputerName $DC
Get-Counter "\DirectoryServices(NTDS)\LDAP Client Sessions"
```

**Implementation Functions:**
- `Get-ADDomainControllerPerformance` - Collects performance metrics
- `Test-ADDomainControllerResources` - Analyzes resource health
- `Get-ADNtdsDatabaseSize` - Reports AD database size and growth

---

### 9. Security and Authentication
**Priority:** HIGH  
**Description:** Monitors authentication health and security posture

**Checks:**
- Kerberos authentication functionality
- NTLM authentication (should be minimal)
- Secure channel status (domain member trust)
- Trust relationships (if multi-domain)
- Certificate services (if ADCS integrated)
- Account lockout events (excessive lockouts)
- Failed authentication attempts (potential attacks)

**Health Criteria:**
- 🟢 **Healthy:** Kerberos working, trusts healthy, no excessive lockouts
- 🟡 **Warning:** High NTLM usage, some lockouts, cert expiring soon
- 🔴 **Critical:** Kerberos failures, trust broken, cert expired

**PowerShell Approach:**
```powershell
Test-ComputerSecureChannel -Server $DC
Get-ADTrust -Filter *
nltest /query /domain:$Domain
Get-WinEvent -FilterHashtable @{LogName=''Security''; Id=4740,4625}
```

**Implementation Functions:**
- `Test-ADKerberosHealth` - Tests Kerberos functionality
- `Get-ADTrustStatus` - Monitors trust relationships
- `Get-ADAuthenticationMetrics` - Analyzes auth patterns and failures

---

### 10. Active Directory Database Health
**Priority:** MEDIUM  
**Description:** Monitors AD database integrity and optimization

**Checks:**
- NTDS.dit integrity
- Database fragmentation
- Tombstone lifetime remaining
- Deleted object cleanup (garbage collection)
- Semantic database analysis
- Version store utilization
- Transaction log growth

**Health Criteria:**
- 🟢 **Healthy:** Database intact, fragmentation < 20%, tombstones cleaned
- 🟡 **Warning:** Fragmentation 20-40%, high version store usage
- 🔴 **Critical:** Database corruption detected, fragmentation > 40%

**PowerShell Approach:**
```powershell
Get-WinEvent -FilterHashtable @{LogName=''Directory Service''; Id=1014,1159,2095}
ntdsutil "activate instance ntds" "files" "info" quit quit
Get-ADObject -SearchBase "CN=Deleted Objects,$((Get-ADDomain).DistinguishedName)"
```

**Implementation Functions:**
- `Get-ADDatabaseHealth` - Checks database integrity
- `Get-ADDatabaseFragmentation` - Reports fragmentation level
- `Test-ADGarbageCollection` - Validates deleted object cleanup

---

### 11. Event Log Analysis
**Priority:** MEDIUM  
**Description:** Scans critical event logs for AD-related errors

**Event Logs to Monitor:**
- Directory Services log
- DNS Server log
- DFS Replication log
- File Replication Service log
- System log (DC-related events)

**Critical Event IDs:**
- **1000-1999:** General AD errors
- **2042:** Replication hasn''t occurred (topology issues)
- **4013:** DNS zone transfer failure
- **13508:** DFSR stopped replication
- **5805:** Session setup from computer failed (trust issue)

**Health Criteria:**
- 🟢 **Healthy:** No critical errors in last 24 hours
- 🟡 **Warning:** Some warnings, no critical errors
- 🔴 **Critical:** Critical errors present (replication, service failures)

**PowerShell Approach:**
```powershell
Get-WinEvent -ComputerName $DC -FilterHashtable @{
    LogName=''Directory Service'',''DNS Server'',''DFS Replication''
    Level=1,2,3
    StartTime=(Get-Date).AddHours(-24)
}
```

**Implementation Functions:**
- `Get-ADCriticalEvents` - Extracts critical AD events
- `Get-ADEventLogSummary` - Summarizes event log findings
- `Test-ADEventLogHealth` - Analyzes event patterns

---

### 12. Backup and Disaster Recovery
**Priority:** MEDIUM  
**Description:** Verifies AD backup status and DR readiness

**Checks:**
- System State backup age (should be < 7 days)
- Backup success/failure status
- Tombstone lifetime vs. backup age
- DSRM (Directory Services Restore Mode) password age
- AD Recycle Bin status
- Backup destination availability

**Health Criteria:**
- 🟢 **Healthy:** Backup < 24 hours old, successful, Recycle Bin enabled
- 🟡 **Warning:** Backup 1-7 days old, DSRM password old
- 🔴 **Critical:** No backup > 7 days, backup older than tombstone lifetime

**PowerShell Approach:**
```powershell
Get-WinEvent -FilterHashtable @{LogName=''Microsoft-Windows-Backup''; Id=4,5}
wbadmin get versions
Get-ADOptionalFeature -Filter {Name -eq ''Recycle Bin Feature''}
```

**Implementation Functions:**
- `Get-ADBackupStatus` - Retrieves latest backup information
- `Test-ADBackupCompliance` - Validates backup meets requirements
- `Get-ADRecycleBinStatus` - Checks Recycle Bin configuration

---

## Module Structure

### Folder Organization
```
AdMonitoring/
├── source/
│   ├── Classes/
│   │   └── HealthCheckResult.ps1          # Class for standardized results
│   ├── Private/
│   │   ├── Internal/
│   │   │   ├── ConvertTo-HealthStatus.ps1 # Helper functions
│   │   │   ├── Get-ThresholdValue.ps1
│   │   │   └── Write-HealthLog.ps1
│   │   └── Helpers/
│   ├── Public/
│   │   ├── ServiceStatus/
│   │   │   ├── Get-ADServiceStatus.ps1
│   │   │   └── Test-ADServiceHealth.ps1
│   │   ├── Replication/
│   │   │   ├── Get-ADReplicationStatus.ps1
│   │   │   ├── Test-ADReplicationHealth.ps1
│   │   │   └── Get-ADReplicationLatency.ps1
│   │   ├── FSMO/
│   │   │   ├── Get-ADFSMORoleHolder.ps1
│   │   │   ├── Test-ADFSMOAvailability.ps1
│   │   │   └── Test-ADFSMOPlacement.ps1
│   │   ├── DNS/
│   │   │   ├── Get-ADDnsZoneHealth.ps1
│   │   │   ├── Test-ADDnsSrvRecords.ps1
│   │   │   └── Test-ADDnsHealth.ps1
│   │   ├── Reporting/
│   │   │   ├── New-ADHealthReport.ps1
│   │   │   ├── Send-ADHealthReport.ps1
│   │   │   └── ConvertTo-ADHealthHtml.ps1
│   │   └── Orchestration/
│   │       ├── Invoke-ADHealthCheck.ps1   # Master orchestration
│   │       └── Get-ADHealthSummary.ps1
│   ├── Config/
│   │   └── DefaultThresholds.psd1
│   └── Resources/
│       └── EmailTemplate.html
├── tests/
│   └── Unit/
│       ├── Public/
│       │   ├── ServiceStatus/
│       │   ├── Replication/
│       │   └── ...
│       └── Private/
└── docs/
    ├── memorybank/
    ├── examples/
    └── runbooks/
```

### Function Naming Conventions

**Collection Functions:** `Get-AD<Component><Metric>`
- Example: `Get-ADReplicationStatus`, `Get-ADServiceStatus`
- Returns raw or lightly processed data
- Minimal business logic

**Analysis Functions:** `Test-AD<Component>Health`
- Example: `Test-ADReplicationHealth`, `Test-ADServiceHealth`
- Analyzes data and returns health status
- Applies thresholds and rules

**Action Functions:** `Invoke-AD<Action>` or `Send-AD<Target>`
- Example: `Invoke-ADHealthCheck`, `Send-ADHealthReport`
- Orchestrates operations or performs actions

### Standardized Output Objects

All health check functions return standardized `HealthCheckResult` objects:

```powershell
[PSCustomObject]@{
    PSTypeName    = ''AdMonitoring.HealthCheckResult''
    CheckName     = ''ReplicationHealth''
    Category      = ''Replication''
    Status        = ''Healthy'' # Healthy, Warning, Critical, Unknown
    Severity      = ''High''    # Critical, High, Medium, Low
    Timestamp     = Get-Date
    Target        = ''DC01.contoso.com''
    Message       = ''Replication is functioning normally''
    Details       = [PSCustomObject]@{...} # Check-specific details
    Recommendations = @(
        ''No action required''
    )
    RawData       = $rawData # Original data for troubleshooting
}
```

## Reporting Architecture

### Report Structure

**1. Executive Summary**
- Overall health status (Red/Yellow/Green)
- Critical issues count
- Warnings count
- DCs monitored / DCs total

**2. Critical Issues Section**
- Only red status items
- Prioritized by severity
- Clear remediation steps

**3. Warnings Section**
- Yellow status items
- Preventive action recommendations

**4. Detailed Findings**
- All checks organized by category
- Expandable sections for details
- Charts and visualizations

**5. Historical Trends** (if available)
- Week-over-week comparison
- Capacity metrics over time

### Report Formats

- **HTML Email:** Primary delivery method, rich formatting
- **JSON Export:** For API integration or data analysis
- **Plain Text:** For systems without HTML support
- **CSV:** For specific metrics/trends

## Configuration Management

### Configuration File Structure (AdMonitoring.config.psd1)
```powershell
@{
    # Email Settings
    SmtpServer = ''smtp.contoso.com''
    SmtpPort = 587
    UseSsl = $true
    From = ''admonitoring@contoso.com''
    To = @(''admins@contoso.com'', ''ops@contoso.com'')
    
    # Monitoring Scope
    IncludedDomainControllers = @() # Empty = all
    ExcludedDomainControllers = @(''RODC01'')
    
    # Thresholds
    Thresholds = @{
        ReplicationLatencyWarning = 900  # 15 minutes in seconds
        ReplicationLatencyCritical = 3600 # 1 hour
        CpuWarning = 70
        CpuCritical = 90
        DiskSpaceWarning = 20 # Percent free
        DiskSpaceCritical = 10
        # ... more thresholds
    }
    
    # Execution Settings
    ParallelChecks = $true
    MaxParallelJobs = 5
    TimeoutSeconds = 300
    
    # Report Settings
    IncludeCharts = $true
    DetailLevel = ''Standard'' # Minimal, Standard, Detailed
    RetainReportDays = 90
    
    # Features
    EnableHistoricalTrends = $true
    EnableComplianceReporting = $false
}
```

## Error Handling Pattern

All functions follow defensive error handling:

```powershell
function Get-ADServiceStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ComputerName
    )
    
    try {
        # Attempt operation
        $services = Get-Service -ComputerName $ComputerName -ErrorAction Stop
        
        # Return success result
        [PSCustomObject]@{
            Success = $true
            Data = $services
            Error = $null
        }
    }
    catch {
        # Log error, return failure result (don''t throw)
        Write-Warning "Failed to get services from $ComputerName : $_"
        
        [PSCustomObject]@{
            Success = $false
            Data = $null
            Error = $_.Exception.Message
        }
    }
}
```

## Performance Patterns

### Parallel Execution
```powershell
# Use jobs for parallel DC queries
$dcs = Get-ADDomainController -Filter *
$jobs = $dcs | ForEach-Object {
    Start-Job -ScriptBlock {
        param($DC)
        Test-ADServiceHealth -ComputerName $DC
    } -ArgumentList $_.HostName
}

$results = $jobs | Wait-Job | Receive-Job
$jobs | Remove-Job
```

### Caching Pattern
```powershell
# Cache domain controller list for session
if (-not $script:CachedDCs) {
    $script:CachedDCs = Get-ADDomainController -Filter *
}
```

## Testing Strategy

### Unit Tests (Pester)
- Mock all external dependencies (AD cmdlets, WMI, etc.)
- Test each function in isolation
- Test success and failure paths
- Validate output object structure

### Integration Tests
- Test against lab AD environment
- Validate end-to-end report generation
- Test with various health states

### Performance Tests
- Measure execution time for large environments
- Validate parallel execution benefits
- Ensure timeout mechanisms work

## Deployment Pattern

### Scheduled Task
```powershell
$action = New-ScheduledTaskAction -Execute ''PowerShell.exe'' `
    -Argument ''-NoProfile -Command "Import-Module AdMonitoring; Invoke-ADHealthCheck"''
$trigger = New-ScheduledTaskTrigger -Daily -At 6:00AM
Register-ScheduledTask -TaskName ''AD Health Check'' -Action $action -Trigger $trigger
```

### Azure Automation Runbook
```powershell
# Runbook that runs in Azure Automation
# Uses Hybrid Worker connected to domain
Import-Module AdMonitoring
Invoke-ADHealthCheck -ConfigFile ''C:\Config\prod.psd1''
```

## Future Patterns to Consider

- **Machine Learning:** Anomaly detection for unusual patterns
- **API:** REST API for programmatic access
- **Dashboard:** Real-time web dashboard
- **ChatOps:** Integration with Teams/Slack for alerts
- **Auto-Remediation:** Self-healing for common issues