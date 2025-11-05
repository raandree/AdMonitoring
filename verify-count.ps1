# Verify the count calculation
$ErrorActionPreference = 'Stop'

Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Cyan

# Create test data - 1 Critical, 1 Warning, 1 Healthy
$mockResults = @(
    [PSCustomObject]@{
        Status = 'Healthy'
        CheckName = 'Check1'
        Category = 'Cat1'
        Target = 'DC01'
        Timestamp = Get-Date
        Details = @{}
        Recommendations = @()
    }
    [PSCustomObject]@{
        Status = 'Warning'
        CheckName = 'Check2'
        Category = 'Cat2'
        Target = 'DC02'
        Timestamp = Get-Date
        Details = @{}
        Recommendations = @()
    }
    [PSCustomObject]@{
        Status = 'Critical'
        CheckName = 'Check3'
        Category = 'Cat3'
        Target = 'DC03'
        Timestamp = Get-Date
        Details = @{}
        Recommendations = @()
    }
)

Write-Host "`nTest data created: $($mockResults.Count) results" -ForegroundColor Yellow
Write-Host "  Healthy: $(($mockResults | Where-Object Status -eq 'Healthy').Count)"
Write-Host "  Warning: $(($mockResults | Where-Object Status -eq 'Warning').Count)"
Write-Host "  Critical: $(($mockResults | Where-Object Status -eq 'Critical').Count)"

$criticalCount = ($mockResults | Where-Object { $_.Status -eq 'Critical' }).Count
$warningCount = ($mockResults | Where-Object { $_.Status -eq 'Warning' }).Count
$healthyCount = ($mockResults | Where-Object { $_.Status -eq 'Healthy' }).Count

Write-Host "`nUsing scriptblock filter (like in source):"
Write-Host "  Critical Count: $criticalCount (Type: $($criticalCount.GetType().Name))"
Write-Host "  Warning Count: $warningCount (Type: $($warningCount.GetType().Name))"
Write-Host "  Healthy Count: $healthyCount (Type: $($healthyCount.GetType().Name))"

# Test string interpolation
$testString = "Count is: $criticalCount"
Write-Host "`nString interpolation test: '$testString'"

# Test in StringBuilder
$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine("Count: $criticalCount")
Write-Host "StringBuilder result: '$($sb.ToString())'"
