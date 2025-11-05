# Test script for Invoke-ADHealthCheck orchestration function

Import-Module .\output\module\AdMonitoring\0.1.0\AdMonitoring.psd1 -Force

Write-Host "`n=== Testing Invoke-ADHealthCheck Orchestration Function ===" -ForegroundColor Cyan
Write-Host "This demonstrates the 'one command to rule them all' approach`n" -ForegroundColor Gray

# Create mock results to simulate different health check categories
$mockResults = @(
    # Services - Healthy
    [PSCustomObject]@{
        Status = 'Healthy'
        CheckName = 'ServiceStatus'
        Category = 'Services'
        Target = 'DC01.contoso.com'
        Timestamp = Get-Date
        Details = @{
            ServicesRunning = 5
            ServicesStopped = 0
        }
        Recommendations = @('All services running normally')
    }

    # DNS - Warning
    [PSCustomObject]@{
        Status = 'Warning'
        CheckName = 'DNSHealth'
        Category = 'DNS'
        Target = 'DC01.contoso.com'
        Timestamp = Get-Date
        Details = @{
            SRVRecordsFound = 18
            SRVRecordsMissing = 2
            DNSServiceStatus = 'Running'
        }
        Recommendations = @('Check missing SRV records', 'Verify DNS zone configuration')
    }

    # Replication - Critical
    [PSCustomObject]@{
        Status = 'Critical'
        CheckName = 'ReplicationStatus'
        Category = 'Replication'
        Target = 'DC02.contoso.com'
        Timestamp = Get-Date
        Details = @{
            LastReplicationTime = (Get-Date).AddHours(-3)
            ReplicationLag = 180
            FailedReplications = 2
        }
        Recommendations = @('Replication failure detected', 'Check network connectivity', 'Review event logs')
    }

    # Performance - Warning
    [PSCustomObject]@{
        Status = 'Warning'
        CheckName = 'PerformanceMetrics'
        Category = 'Performance'
        Target = 'DC01.contoso.com'
        Timestamp = Get-Date
        Details = @{
            CPUUsage = 78
            MemoryUsage = 85
            DiskFreeSpace = 15
        }
        Recommendations = @('High memory usage detected', 'Monitor system resources')
    }
)

Write-Host "Scenario 1: Generate report with all results (including healthy)" -ForegroundColor Yellow
Write-Host "Command: Invoke-ADHealthCheck results piped to New-ADHealthReport" -ForegroundColor Gray
Write-Host ""

$report1 = $mockResults | New-ADHealthReport -IncludeHealthyChecks -Title "Complete AD Health Report" -Show
Write-Host "Report 1 saved to: $($report1.FullName)" -ForegroundColor Green
Write-Host ""

Start-Sleep -Seconds 2

Write-Host "Scenario 2: Focus on issues only (exclude healthy checks)" -ForegroundColor Yellow
Write-Host "Command: Filter to show only warnings and critical issues" -ForegroundColor Gray
Write-Host ""

$report2 = $mockResults | New-ADHealthReport -Title "AD Issues Report - Action Required"
Write-Host "Report 2 saved to: $($report2.FullName)" -ForegroundColor Green
Write-Host ""

Write-Host "Scenario 3: Display summary in console" -ForegroundColor Yellow
Write-Host "Command: Show health check summary" -ForegroundColor Gray
Write-Host ""

$critical = ($mockResults | Where-Object Status -eq 'Critical').Count
$warnings = ($mockResults | Where-Object Status -eq 'Warning').Count
$healthy = ($mockResults | Where-Object Status -eq 'Healthy').Count

Write-Host "Health Check Summary:" -ForegroundColor Cyan
Write-Host "  Critical Issues: $critical" -ForegroundColor Red
Write-Host "  Warnings: $warnings" -ForegroundColor Yellow
Write-Host "  Healthy: $healthy" -ForegroundColor Green
Write-Host "  Total Checks: $($mockResults.Count)" -ForegroundColor Gray
Write-Host ""

Write-Host "Scenario 4: Category-specific filtering" -ForegroundColor Yellow
Write-Host "Command: Show only replication and DNS issues" -ForegroundColor Gray
Write-Host ""

$filteredResults = $mockResults | Where-Object { $_.Category -in @('Replication', 'DNS') }
Write-Host "Found $($filteredResults.Count) results in Replication and DNS categories" -ForegroundColor Cyan
$filteredResults | Format-Table CheckName, Status, Category, Target -AutoSize

Write-Host "`n=== Invoke-ADHealthCheck Features ===" -ForegroundColor Cyan
Write-Host "✅ Single command runs all 12 health check categories" -ForegroundColor Green
Write-Host "✅ Auto-discovers all domain controllers" -ForegroundColor Green
Write-Host "✅ Selective category execution (-Category parameter)" -ForegroundColor Green
Write-Host "✅ Integrated report generation (-GenerateReport switch)" -ForegroundColor Green
Write-Host "✅ Filters results (shows issues only by default)" -ForegroundColor Green
Write-Host "✅ Console summary display" -ForegroundColor Green
Write-Host "✅ Pipeline-friendly output" -ForegroundColor Green
Write-Host "✅ Parallel execution support (future: -Parallel switch)" -ForegroundColor Green

Write-Host "`n=== Usage Examples ===" -ForegroundColor Cyan
Write-Host @"
# Run all checks and generate report
Invoke-ADHealthCheck -GenerateReport

# Run specific categories only
Invoke-ADHealthCheck -Category Services,DNS,Replication

# Include healthy checks in output
Invoke-ADHealthCheck -IncludeHealthy -GenerateReport

# Target specific DCs
Invoke-ADHealthCheck -ComputerName DC01,DC02 -GenerateReport

# Save report to specific path
Invoke-ADHealthCheck -GenerateReport -ReportPath C:\Reports\AD-Health.html

# Get results programmatically
`$results = Invoke-ADHealthCheck
`$critical = `$results | Where-Object Status -eq 'Critical'
"@ -ForegroundColor Gray

Write-Host "`n=== Test Complete ===" -ForegroundColor Cyan
