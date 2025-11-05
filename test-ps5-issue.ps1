# Test script to identify PS5 compatibility issues
$ErrorActionPreference = 'Stop'

Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Cyan
Write-Host ""

# Import Pester
Import-Module Pester -MinimumVersion 5.0

# Import the module
$modulePath = ".\output\module\AdMonitoring"
Import-Module $modulePath -Force

Write-Host "Running specific failing tests..." -ForegroundColor Yellow
Write-Host ""

# Run just the New-ADHealthReport tests
Invoke-Pester -Path .\tests\Unit\Public\New-ADHealthReport.Tests.ps1 -Output Detailed
