# PSScriptAnalyzer Write-Host Suppressions

## Summary

Added PSScriptAnalyzer suppression attributes to all PowerShell functions that use `Write-Host` for intentional user feedback. This prevents the `PSAvoidUsingWriteHost` rule from generating warnings for these justified use cases.

## Modified Files

### 1. Send-ADHealthReport.ps1
**Location:** `source/Public/Send-ADHealthReport.ps1`

**Suppression Added:**
```powershell
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Write-Host used intentionally for user feedback on email delivery status')]
```

**Write-Host Usage:**
- Line 412: `Write-Host "Email sent successfully to: $($To -join ', ')" -ForegroundColor Green`

**Justification:** Write-Host is used to provide immediate visual feedback to users when emails are successfully sent, using color coding for better visibility.

---

### 2. Invoke-ADHealthCheck.ps1
**Location:** `source/Public/Invoke-ADHealthCheck.ps1`

**Suppression Added:**
```powershell
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Write-Host used intentionally for interactive console summary display with color formatting')]
```

**Write-Host Usage:**
- Line 321: `Write-Host "`n=== AD Health Check Summary ===" -ForegroundColor Cyan`
- Line 322: `Write-Host "Duration: $($duration.ToString('mm\:ss'))" -ForegroundColor Gray`
- Line 323: `Write-Host "Total Checks: $($allResults.Count)" -ForegroundColor Gray`
- Line 324: `Write-Host "Critical Issues: $criticalCount" -ForegroundColor $(if ($criticalCount -gt 0) { 'Red' } else { 'Gray' })`
- Line 325: `Write-Host "Warnings: $warningCount" -ForegroundColor $(if ($warningCount -gt 0) { 'Yellow' } else { 'Gray' })`
- Line 326: `Write-Host "Healthy: $healthyCount" -ForegroundColor Green`
- Line 327: `Write-Host "================================`n" -ForegroundColor Cyan`
- Line 344: `Write-Host "Report generated: $($reportFile.FullName)" -ForegroundColor Green`

**Justification:** Write-Host is used to display a formatted console summary with color-coded status indicators, providing immediate visual feedback about health check results.

---

### 3. Export-ADHealthData.ps1
**Location:** `source/Public/Export-ADHealthData.ps1`

**Suppression Added:**
```powershell
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Write-Host used intentionally for user feedback on successful data export')]
```

**Write-Host Usage:**
- Line 389: `Write-Host "Data exported successfully to: $($fileInfo.FullName)" -ForegroundColor Green`

**Justification:** Write-Host is used to provide immediate visual confirmation to users when data export operations complete successfully.

---

## Technical Details

### Suppression Attribute Syntax
The suppression uses the standard .NET Code Analysis suppression attribute:

```powershell
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('RuleName', 'CheckId', Justification = 'Reason')]
```

**Parameters:**
- **RuleName:** `'PSAvoidUsingWriteHost'` - The PSScriptAnalyzer rule to suppress
- **CheckId:** `''` - Empty string as no specific check ID is needed
- **Justification:** Clear explanation of why the rule is being suppressed

### Placement
The suppression attribute is placed at the function level, immediately before the `param()` block, alongside other function attributes like `[CmdletBinding()]` and `[OutputType()]`.

### Why Write-Host Is Used Here

While `Write-Host` is generally discouraged in PowerShell functions because it bypasses the output stream and cannot be captured or redirected, these specific use cases are valid exceptions:

1. **Interactive User Feedback:** These functions are designed for interactive console use where immediate, color-coded visual feedback enhances user experience.

2. **Non-Pipeline Output:** The Write-Host calls are used for status messages separate from the function's actual output objects, which are properly returned via the pipeline.

3. **Color Formatting:** The functions use color to indicate status (Green for success, Red for critical, Yellow for warnings), which is only possible with Write-Host.

4. **User-Facing Functions:** All three functions are public, user-facing cmdlets designed for direct console interaction, not internal library functions.

### Best Practices Applied

1. ✅ **Clear Justification:** Each suppression includes a specific reason
2. ✅ **Minimal Scope:** Suppression only affects the specific functions that need it
3. ✅ **Documented:** This document explains all suppressions
4. ✅ **Intentional Usage:** Write-Host is used deliberately for user experience, not as a shortcut

### Verification

To verify the suppressions are working correctly:

```powershell
# Install PSScriptAnalyzer if needed
Install-Module -Name PSScriptAnalyzer -Scope CurrentUser

# Run analysis on suppressed files
Invoke-ScriptAnalyzer -Path .\source\Public\Send-ADHealthReport.ps1 -Settings PSGallery
Invoke-ScriptAnalyzer -Path .\source\Public\Invoke-ADHealthCheck.ps1 -Settings PSGallery
Invoke-ScriptAnalyzer -Path .\source\Public\Export-ADHealthData.ps1 -Settings PSGallery

# Filter for Write-Host rule specifically
Invoke-ScriptAnalyzer -Path .\source\Public\ -Recurse -Settings PSGallery | 
    Where-Object { $_.RuleName -eq 'PSAvoidUsingWriteHost' }
```

Expected result: No `PSAvoidUsingWriteHost` warnings for these three files.

---

## Date
2025-11-04

## Related Issues
This change addresses PSScriptAnalyzer warnings about Write-Host usage while maintaining the intended user experience for interactive console functions.
