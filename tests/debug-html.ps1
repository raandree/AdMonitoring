# Debug script to check HTML output differences between PS5 and PS7
$ErrorActionPreference = 'Stop'

Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Cyan

# Import module
Import-Module .\output\module\AdMonitoring -Force

# Create test data
$mockResults = @(
    [PSCustomObject]@{
        PSTypeName = 'AdMonitoring.HealthCheckResult'
        CheckName = 'DiskSpace'
        Category = 'Performance'
        Status = 'Critical'
        Target = 'DC03.contoso.com'
        Timestamp = Get-Date
        Details = [PSCustomObject]@{
            DriveLetter = 'C:'
            FreeSpaceGB = 5
        }
        Recommendations = @('Free up disk space')
    }
)

# Generate report
$fileInfo = New-ADHealthReport -HealthCheckResults $mockResults
$html = Get-Content $fileInfo.FullName -Raw

# Search for the stat-number pattern
Write-Host "`nSearching for stat-number pattern..." -ForegroundColor Yellow
$pattern = '<span class=.stat-number.>1</span>[\s\S]*?<span class=.stat-label.>Critical Issues</span>'

if ($html -match $pattern) {
    Write-Host "MATCH FOUND!" -ForegroundColor Green
    Write-Host "Matched: $($matches[0])" -ForegroundColor Green
} else {
    Write-Host "NO MATCH!" -ForegroundColor Red
    Write-Host "`nLooking for the actual HTML section..." -ForegroundColor Yellow

    # Extract just the stats section
    if ($html -match '(?s)<div class=.summary-stats.>(.*?)</div>\s*</div>') {
        $statsSection = $matches[1]
        Write-Host "`nStats Section:`n$statsSection" -ForegroundColor Cyan
    }

    # Show what we're looking for
    Write-Host "`nSearching for Critical Issues span..." -ForegroundColor Yellow
    if ($html -match "span class=['\x22]stat-label['\x22]>Critical Issues") {
        Write-Host "Found Critical Issues label!" -ForegroundColor Green
        # Get context around it
        $index = $html.IndexOf('Critical Issues')
        $start = [Math]::Max(0, $index - 200)
        $length = [Math]::Min(400, $html.Length - $start)
        $context = $html.Substring($start, $length)
        Write-Host "`nContext around 'Critical Issues':`n$context" -ForegroundColor Cyan
    }
}

Remove-Item $fileInfo.FullName -Force
