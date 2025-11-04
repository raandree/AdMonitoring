# Changelog for AdMonitoring

The format is based on and uses the types of changes according to [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- New reporting and orchestration functions for comprehensive AD monitoring workflow:
  - `Invoke-ADHealthCheck` - Master orchestration function that runs all 12 health check categories with a single command
  - `New-ADHealthReport` - Generates professional HTML reports with embedded CSS, color-coded status indicators, and executive summary
  - `Send-ADHealthReport` - Email delivery with support for Text/Html/Attachment body formats, SSL/TLS, and authenticated SMTP
  - `Export-ADHealthData` - Multi-format data export (JSON, CSV, XML, CLIXML) with compression and metadata support
- HTML report features:
  - Professional styling with gradient headers and card-based layout
  - Executive summary dashboard with overall status and statistics
  - Color-coded status badges (Critical/Warning/Healthy)
  - Detailed findings grouped by category
  - Expandable details tables and recommendation lists
  - Company branding support (logo and name)
  - Always saves to file (temp or specified path), returns FileInfo object
  - `-Show` switch to automatically open report in default browser
- Orchestration capabilities:
  - Auto-discovery of domain controllers
  - Selective category execution with `-Category` parameter
  - Integrated report generation with `-GenerateReport` switch
  - Smart filtering (shows issues only by default, `-IncludeHealthy` for all results)
  - Console summary display with statistics
  - Fail-safe execution (individual check failures don't stop pipeline)
  - Support for 12 health check categories: Services, Connectivity, Replication, FSMO, DNS, SYSVOL, TimeSync, Performance, Security, Database, Events, Certificates
- Email delivery features:
  - Three body formats: Text (summary), Html (full report), Attachment (summary + HTML file)
  - SSL/TLS support for secure SMTP connections
  - Authenticated and anonymous SMTP support
  - Multiple recipients (To, Cc, Bcc)
  - Priority levels (Low, Normal, High)
  - Pre-configured examples for Office 365 and Gmail
  - Automatic temp file cleanup
- Data export features:
  - Smart format detection from file extension
  - Optional metadata inclusion (timestamp, version, statistics)
  - GZip compression support with automatic .gz extension
  - Append mode for incremental data collection
  - CSV flattening for complex objects
  - Full PowerShell object preservation with CLIXML format
  - Force parameter to create directory path if needed

### Changed

- For changes in existing functionality.

### Deprecated

- For soon-to-be removed features.

### Removed

- For now removed features.

### Fixed

- For any bug fix.

### Security

- In case of vulnerabilities.
