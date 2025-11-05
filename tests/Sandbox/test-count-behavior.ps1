# Test .Count behavior difference between PS5 and PS7
Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Cyan

$items = @(
    [PSCustomObject]@{ Status = 'Critical' }
)

Write-Host "`nTest 1: Array with 1 item"
$result1 = $items | Where-Object { $_.Status -eq 'Critical' }
Write-Host "  Result type: $($result1.GetType().Name)"
Write-Host "  Result.Count: $($result1.Count)"
Write-Host "  Result.Count is null: $($null -eq $result1.Count)"

Write-Host "`nTest 2: Array with 0 matches"
$result2 = $items | Where-Object { $_.Status -eq 'Warning' }
Write-Host "  Result type: $(if ($result2) { $result2.GetType().Name } else { 'null' })"
Write-Host "  Result.Count: $($result2.Count)"
Write-Host "  Result.Count is null: $($null -eq $result2.Count)"

Write-Host "`nTest 3: Using @() to force array"
$result3 = @($items | Where-Object { $_.Status -eq 'Critical' })
Write-Host "  Result type: $($result3.GetType().Name)"
Write-Host "  Result.Count: $($result3.Count)"
Write-Host "  Result.Count is null: $($null -eq $result3.Count)"

Write-Host "`nTest 4: Using Measure-Object"
$result4 = ($items | Where-Object { $_.Status -eq 'Critical' } | Measure-Object).Count
Write-Host "  Result type: $($result4.GetType().Name)"
Write-Host "  Result value: $result4"
Write-Host "  Result is null: $($null -eq $result4)"
