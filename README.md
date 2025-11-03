# AdMonitoring - Active Directory Health Monitoring System

## Overview

AdMonitoring is a PowerShell-based monitoring solution that performs comprehensive Active Directory health checks and sends automated daily email reports to technical staff.

## Project Status

**Phase:** Requirements & Design (Phase 1)  
**Last Updated:** November 3, 2025  
**Completion:** 20%

## Key Features

- **Automated Health Monitoring:** Scheduled health checks across 12 critical AD categories
- **Daily Email Reports:** HTML-formatted health reports delivered every morning
- **Proactive Issue Detection:** Identify problems before they impact users
- **Actionable Insights:** Clear status indicators with remediation guidance
- **Historical Tracking:** Trend analysis for capacity planning

## Health Check Categories

Based on Microsoft best practices and industry standards, the system monitors:

1. **Domain Controller Service Status** (CRITICAL)
2. **DC Reachability & Connectivity** (CRITICAL)
3. **Active Directory Replication** (CRITICAL)
4. **FSMO Role Availability** (CRITICAL)
5. **DNS Health** (CRITICAL)
6. **SYSVOL & DFS Replication** (CRITICAL)
7. **Time Synchronization** (HIGH)
8. **Event Log Analysis** (HIGH)
9. **Database & Log Files** (MEDIUM)
10. **Backup Status** (HIGH)
11. **Trust Relationships** (MEDIUM)
12. **Performance Metrics** (LOW)

## Architecture

Built using the **Sampler PowerShell module framework** with:
- Modular health check functions (Public/Private separation)
- Comprehensive Pester test coverage
- PSScriptAnalyzer compliance
- Automated build pipeline

## Technology Stack

- **PowerShell:** 5.1+ / 7.x
- **Framework:** Sampler
- **Testing:** Pester 5.x
- **Required Modules:** ActiveDirectory, MailKit/System.Net.Mail
- **Platform:** Windows Server 2016 or later

## Documentation

Complete project documentation is maintained in the Memory Bank:

- 📋 **[Project Brief](docs/memorybank/projectbrief.md)** - Overview and objectives
- 🎯 **[Product Context](docs/memorybank/productContext.md)** - Problems solved and value proposition
- 🚀 **[Active Context](docs/memorybank/activeContext.md)** - Current work focus and recent decisions
- 🏗️ **[System Patterns](docs/memorybank/systemPatterns.md)** - Architecture and monitoring categories
- ⚙️ **[Tech Context](docs/memorybank/techContext.md)** - Technology stack and setup
- 📊 **[Progress](docs/memorybank/progress.md)** - Status tracking and roadmap

## Next Steps

1. ✅ Memory Bank establishment (COMPLETE)
2. ✅ AD health monitoring research (COMPLETE)
3. ⏳ Create module scaffold with Sampler
4. ⏳ Implement core monitoring functions
5. ⏳ Build reporting engine
6. ⏳ Integration testing
7. ⏳ Deployment documentation

## Getting Started

(Coming soon - module not yet implemented)

## License

(To be determined)

## Contributors

IT Infrastructure Team
