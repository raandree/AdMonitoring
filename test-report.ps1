Import-Module .\output\module\AdMonitoring\0.1.0\AdMonitoring.psd1 -Force

$mockResult = [PSCustomObject]@{
    Status = 'Warning'
    CheckName = 'TestCheck'
    Category = 'Test'
    Target = 'TestServer'
    Timestamp = Get-Date
    Details = @{
        Info = 'Test data'
        Status = 'Warning detected'
    }
    Recommendations = @('Fix this issue', 'Review configuration')
}

Write-Host "Generating test report with -Show switch..." -ForegroundColor Cyan
$report = New-ADHealthReport -HealthCheckResults $mockResult -Show

Write-Host "`nReport saved to:" -ForegroundColor Green
Write-Host $report.FullName -ForegroundColor Yellow
Write-Host "`nReport should have opened in your browser." -ForegroundColor Green
