function New-ADHealthReport {
    <#
    .SYNOPSIS
        Generates a comprehensive HTML health report from AD monitoring results.

    .DESCRIPTION
        The New-ADHealthReport function takes health check results from various
        AD monitoring functions and generates a comprehensive, formatted HTML report.
        The report includes an executive summary, detailed findings by category,
        color-coded status indicators, and actionable recommendations.

        The report is designed to be sent via email or saved to disk for review.

    .PARAMETER HealthCheckResults
        An array of health check result objects from AD monitoring functions.
        These objects should have the standard AdMonitoring output structure
        with Status, CheckName, Category, Details, and Recommendations properties.

    .PARAMETER Title
        The title for the report. Default: "Active Directory Health Report"

    .PARAMETER IncludeHealthyChecks
        If specified, includes checks that returned "Healthy" status in the report.
        By default, only Warning and Critical issues are included to focus on
        items requiring attention.

    .PARAMETER OutputPath
        Optional file path to save the HTML report. If not specified, saves to
        a temporary file in the system temp directory.

    .PARAMETER IncludeTimestamp
        If specified, includes timestamp information in the report header.
        Default: $true

    .PARAMETER CompanyName
        Optional company name to display in the report header.

    .PARAMETER CompanyLogo
        Optional URL or base64-encoded image data for company logo in report header.

    .PARAMETER Show
        If specified, opens the generated HTML report in the default web browser
        (Microsoft Edge on Windows).

    .EXAMPLE
        $results = Test-ADDNSHealth, Test-ADSYSVOLHealth
        New-ADHealthReport -HealthCheckResults $results -Show

        Generates an HTML report from DNS and SYSVOL health checks, saves to temp file,
        and opens it in the default web browser.

    .EXAMPLE
        $allResults = @()
        $allResults += Get-ADServiceStatus
        $allResults += Test-ADDomainControllerReachability
        $allResults += Get-ADReplicationStatus
        $report = New-ADHealthReport -HealthCheckResults $allResults -OutputPath "C:\Reports\AD-Health.html"

        Collects results from multiple health checks, generates an HTML report,
        and saves it to the specified path. Returns a FileInfo object for the saved file.

    .EXAMPLE
        $results = Import-Clixml .\HealthCheckResults.xml
        New-ADHealthReport -HealthCheckResults $results -CompanyName "Contoso" -Show

        Generates a report from previously saved results with company branding,
        saves to temp file, and opens it in the browser.

    .EXAMPLE
        Get-ADServiceStatus | New-ADHealthReport -IncludeHealthyChecks -OutputPath .\Report.html

        Pipes service status results directly to report generation, includes healthy
        checks, and saves to the current directory.

    .INPUTS
        System.Management.Automation.PSObject[]

        You can pipe health check result objects to this function.

    .OUTPUTS
        System.IO.FileInfo

        Returns a FileInfo object for the generated HTML report file.

    .NOTES
        Author: AdMonitoring Module
        Version: 1.0.0
        Requires: PowerShell 5.1 or later

        The function generates self-contained HTML with embedded CSS for portability.

    .LINK
        Send-ADHealthReport

    .LINK
        Invoke-ADHealthCheck
    #>
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'File creation is the primary purpose of this function, not a side effect. Adding ShouldProcess would make the function awkward to use.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseBOMForUnicodeEncodedFile', '', Justification = 'HTML output uses UTF-8 without BOM for better web browser compatibility')]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [PSObject[]]$HealthCheckResults,

        [Parameter()]
        [string]$Title = 'Active Directory Health Report',

        [Parameter()]
        [switch]$IncludeHealthyChecks,

        [Parameter()]
        [string]$OutputPath,

        [Parameter()]
        [bool]$IncludeTimestamp = $true,

        [Parameter()]
        [string]$CompanyName,

        [Parameter()]
        [string]$CompanyLogo,

        [Parameter()]
        [switch]$Show
    )

    begin {
        Write-Verbose "Starting HTML report generation"

        $allResults = [System.Collections.Generic.List[PSObject]]::new()

        # Report generation timestamp
        $reportTimestamp = Get-Date

        # CSS styles for the report
        $css = @'
<style>
    body {
        font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
        margin: 0;
        padding: 20px;
        background-color: #f5f5f5;
        color: #333;
    }
    .container {
        max-width: 1200px;
        margin: 0 auto;
        background-color: white;
        padding: 30px;
        border-radius: 8px;
        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }
    .header {
        border-bottom: 3px solid #0078d4;
        padding-bottom: 20px;
        margin-bottom: 30px;
        display: flex;
        justify-content: space-between;
        align-items: center;
    }
    .header h1 {
        margin: 0;
        color: #0078d4;
        font-size: 28px;
    }
    .header .logo {
        max-height: 60px;
    }
    .timestamp {
        color: #666;
        font-size: 14px;
        margin-top: 5px;
    }
    .executive-summary {
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        color: white;
        padding: 25px;
        border-radius: 8px;
        margin-bottom: 30px;
    }
    .executive-summary h2 {
        margin-top: 0;
        font-size: 24px;
    }
    .summary-stats {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
        gap: 15px;
        margin-top: 20px;
    }
    .stat-card {
        background: rgba(255,255,255,0.2);
        padding: 15px;
        border-radius: 6px;
        text-align: center;
    }
    .stat-number {
        font-size: 36px;
        font-weight: bold;
        display: block;
    }
    .stat-label {
        font-size: 14px;
        opacity: 0.9;
    }
    .section {
        margin-bottom: 30px;
    }
    .section h2 {
        color: #0078d4;
        border-bottom: 2px solid #e0e0e0;
        padding-bottom: 10px;
        font-size: 22px;
    }
    .check-item {
        background: #fafafa;
        border-left: 4px solid #ddd;
        padding: 20px;
        margin-bottom: 15px;
        border-radius: 4px;
    }
    .check-item.critical {
        border-left-color: #d32f2f;
        background: #ffebee;
    }
    .check-item.warning {
        border-left-color: #f57c00;
        background: #fff3e0;
    }
    .check-item.healthy {
        border-left-color: #388e3c;
        background: #e8f5e9;
    }
    .check-header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        margin-bottom: 15px;
    }
    .check-title {
        font-size: 18px;
        font-weight: 600;
        color: #333;
    }
    .status-badge {
        padding: 6px 16px;
        border-radius: 20px;
        font-size: 12px;
        font-weight: 600;
        text-transform: uppercase;
        letter-spacing: 0.5px;
    }
    .status-badge.critical {
        background-color: #d32f2f;
        color: white;
    }
    .status-badge.warning {
        background-color: #f57c00;
        color: white;
    }
    .status-badge.healthy {
        background-color: #388e3c;
        color: white;
    }
    .check-info {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
        gap: 15px;
        margin-bottom: 15px;
    }
    .info-item {
        font-size: 14px;
    }
    .info-label {
        font-weight: 600;
        color: #666;
        display: block;
        margin-bottom: 4px;
    }
    .info-value {
        color: #333;
    }
    .recommendations {
        background: white;
        border: 1px solid #e0e0e0;
        border-radius: 4px;
        padding: 15px;
        margin-top: 15px;
    }
    .recommendations h4 {
        margin-top: 0;
        color: #0078d4;
        font-size: 16px;
    }
    .recommendations ul {
        margin: 10px 0;
        padding-left: 20px;
    }
    .recommendations li {
        margin-bottom: 8px;
        line-height: 1.6;
    }
    .footer {
        margin-top: 40px;
        padding-top: 20px;
        border-top: 2px solid #e0e0e0;
        text-align: center;
        color: #666;
        font-size: 12px;
    }
    .no-issues {
        text-align: center;
        padding: 40px;
        background: #e8f5e9;
        border-radius: 8px;
        color: #388e3c;
    }
    .no-issues h3 {
        margin-top: 0;
        font-size: 24px;
    }
    table {
        width: 100%;
        border-collapse: collapse;
        margin-top: 10px;
    }
    table th {
        background: #f5f5f5;
        padding: 10px;
        text-align: left;
        font-weight: 600;
        border-bottom: 2px solid #ddd;
    }
    table td {
        padding: 10px;
        border-bottom: 1px solid #eee;
    }
    .detail-table {
        font-size: 13px;
    }
</style>
'@
    }

    process {
        foreach ($result in $HealthCheckResults) {
            $allResults.Add($result)
        }
    }

    end {
        Write-Verbose "Processing $($allResults.Count) health check results"

        # Filter results based on IncludeHealthyChecks parameter
        $filteredResults = if ($IncludeHealthyChecks) {
            $allResults
        }
        else {
            $allResults | Where-Object { $_.Status -ne 'Healthy' }
        }

        Write-Verbose "Filtered to $($filteredResults.Count) results for report"

        # Calculate summary statistics
        $criticalCount = ($allResults | Where-Object { $_.Status -eq 'Critical' }).Count
        $warningCount = ($allResults | Where-Object { $_.Status -eq 'Warning' }).Count
        $healthyCount = ($allResults | Where-Object { $_.Status -eq 'Healthy' }).Count
        $totalChecks = $allResults.Count

        # Determine overall health status
        $overallStatus = if ($criticalCount -gt 0) {
            'Critical'
        }
        elseif ($warningCount -gt 0) {
            'Warning'
        }
        else {
            'Healthy'
        }

        # Group results by category
        $resultsByCategory = $filteredResults | Group-Object -Property Category

        # Build HTML content
        $htmlBuilder = [System.Text.StringBuilder]::new()

        # HTML header
        [void]$htmlBuilder.AppendLine('<!DOCTYPE html>')
        [void]$htmlBuilder.AppendLine('<html lang="en">')
        [void]$htmlBuilder.AppendLine('<head>')
        [void]$htmlBuilder.AppendLine('    <meta charset="UTF-8">')
        [void]$htmlBuilder.AppendLine('    <meta name="viewport" content="width=device-width, initial-scale=1.0">')
        [void]$htmlBuilder.AppendLine("    <title>$Title</title>")
        [void]$htmlBuilder.AppendLine($css)
        [void]$htmlBuilder.AppendLine('</head>')
        [void]$htmlBuilder.AppendLine('<body>')
        [void]$htmlBuilder.AppendLine('    <div class="container">')

        # Header section
        [void]$htmlBuilder.AppendLine('        <div class="header">')
        [void]$htmlBuilder.AppendLine('            <div>')
        [void]$htmlBuilder.AppendLine("                <h1>$Title</h1>")

        if ($CompanyName) {
            [void]$htmlBuilder.AppendLine("                <div style='font-size: 16px; color: #666;'>$CompanyName</div>")
        }

        if ($IncludeTimestamp) {
            [void]$htmlBuilder.AppendLine("                <div class='timestamp'>Generated: $($reportTimestamp.ToString('yyyy-MM-dd HH:mm:ss'))</div>")
        }

        [void]$htmlBuilder.AppendLine('            </div>')

        if ($CompanyLogo) {
            [void]$htmlBuilder.AppendLine("            <img src='$CompanyLogo' class='logo' alt='Company Logo' />")
        }

        [void]$htmlBuilder.AppendLine('        </div>')

        # Executive Summary
        [void]$htmlBuilder.AppendLine('        <div class="executive-summary">')
        [void]$htmlBuilder.AppendLine('            <h2>Executive Summary</h2>')
        [void]$htmlBuilder.AppendLine("            <p>Overall Status: <strong style='font-size: 20px;'>$overallStatus</strong></p>")
        [void]$htmlBuilder.AppendLine('            <div class="summary-stats">')
        [void]$htmlBuilder.AppendLine('                <div class="stat-card">')
        [void]$htmlBuilder.AppendLine("                    <span class='stat-number'>$totalChecks</span>")
        [void]$htmlBuilder.AppendLine("                    <span class='stat-label'>Total Checks</span>")
        [void]$htmlBuilder.AppendLine('                </div>')
        [void]$htmlBuilder.AppendLine('                <div class="stat-card">')
        [void]$htmlBuilder.AppendLine("                    <span class='stat-number'>$criticalCount</span>")
        [void]$htmlBuilder.AppendLine("                    <span class='stat-label'>Critical Issues</span>")
        [void]$htmlBuilder.AppendLine('                </div>')
        [void]$htmlBuilder.AppendLine('                <div class="stat-card">')
        [void]$htmlBuilder.AppendLine("                    <span class='stat-number'>$warningCount</span>")
        [void]$htmlBuilder.AppendLine("                    <span class='stat-label'>Warnings</span>")
        [void]$htmlBuilder.AppendLine('                </div>')
        [void]$htmlBuilder.AppendLine('                <div class="stat-card">')
        [void]$htmlBuilder.AppendLine("                    <span class='stat-number'>$healthyCount</span>")
        [void]$htmlBuilder.AppendLine("                    <span class='stat-label'>Healthy</span>")
        [void]$htmlBuilder.AppendLine('                </div>')
        [void]$htmlBuilder.AppendLine('            </div>')
        [void]$htmlBuilder.AppendLine('        </div>')

        # Check if there are any issues to report
        if ($filteredResults.Count -eq 0 -and -not $IncludeHealthyChecks) {
            [void]$htmlBuilder.AppendLine('        <div class="no-issues">')
            [void]$htmlBuilder.AppendLine('            <h3>✓ All Systems Healthy</h3>')
            [void]$htmlBuilder.AppendLine('            <p>No issues detected during this monitoring cycle. All Active Directory health checks passed successfully.</p>')
            [void]$htmlBuilder.AppendLine('        </div>')
        }
        else {
            # Detailed findings by category
            foreach ($category in $resultsByCategory) {
                $categoryName = if ($category.Name) { $category.Name } else { 'General' }

                [void]$htmlBuilder.AppendLine('        <div class="section">')
                [void]$htmlBuilder.AppendLine("            <h2>$categoryName</h2>")

                foreach ($check in $category.Group) {
                    $statusClass = $check.Status.ToLower()

                    [void]$htmlBuilder.AppendLine("            <div class='check-item $statusClass'>")
                    [void]$htmlBuilder.AppendLine('                <div class="check-header">')
                    [void]$htmlBuilder.AppendLine("                    <div class='check-title'>$($check.CheckName)</div>")
                    [void]$htmlBuilder.AppendLine("                    <span class='status-badge $statusClass'>$($check.Status)</span>")
                    [void]$htmlBuilder.AppendLine('                </div>')

                    # Check information
                    [void]$htmlBuilder.AppendLine('                <div class="check-info">')

                    if ($check.Target) {
                        [void]$htmlBuilder.AppendLine('                    <div class="info-item">')
                        [void]$htmlBuilder.AppendLine('                        <span class="info-label">Target:</span>')
                        [void]$htmlBuilder.AppendLine("                        <span class='info-value'>$($check.Target)</span>")
                        [void]$htmlBuilder.AppendLine('                    </div>')
                    }

                    if ($check.Timestamp) {
                        [void]$htmlBuilder.AppendLine('                    <div class="info-item">')
                        [void]$htmlBuilder.AppendLine('                        <span class="info-label">Checked:</span>')
                        [void]$htmlBuilder.AppendLine("                        <span class='info-value'>$($check.Timestamp.ToString('yyyy-MM-dd HH:mm:ss'))</span>")
                        [void]$htmlBuilder.AppendLine('                    </div>')
                    }

                    [void]$htmlBuilder.AppendLine('                </div>')

                    # Details table if available
                    if ($check.Details) {
                        [void]$htmlBuilder.AppendLine('                <table class="detail-table">')
                        [void]$htmlBuilder.AppendLine('                    <tr><th>Property</th><th>Value</th></tr>')

                        $check.Details.PSObject.Properties | ForEach-Object {
                            $value = if ($null -eq $_.Value) { 'N/A' }
                                    elseif ($_.Value -is [array]) { ($_.Value | Out-String).Trim() }
                                    else { $_.Value.ToString() }

                            [void]$htmlBuilder.AppendLine("                    <tr><td>$($_.Name)</td><td>$value</td></tr>")
                        }

                        [void]$htmlBuilder.AppendLine('                </table>')
                    }

                    # Recommendations
                    if ($check.Recommendations -and $check.Recommendations.Count -gt 0) {
                        [void]$htmlBuilder.AppendLine('                <div class="recommendations">')
                        [void]$htmlBuilder.AppendLine('                    <h4>Recommendations</h4>')
                        [void]$htmlBuilder.AppendLine('                    <ul>')

                        foreach ($recommendation in $check.Recommendations) {
                            [void]$htmlBuilder.AppendLine("                        <li>$recommendation</li>")
                        }

                        [void]$htmlBuilder.AppendLine('                    </ul>')
                        [void]$htmlBuilder.AppendLine('                </div>')
                    }

                    [void]$htmlBuilder.AppendLine('            </div>')
                }

                [void]$htmlBuilder.AppendLine('        </div>')
            }
        }

        # Footer
        [void]$htmlBuilder.AppendLine('        <div class="footer">')
        [void]$htmlBuilder.AppendLine('            <p>Generated by AdMonitoring PowerShell Module</p>')
        [void]$htmlBuilder.AppendLine("            <p>Report Date: $($reportTimestamp.ToString('yyyy-MM-dd HH:mm:ss'))</p>")
        [void]$htmlBuilder.AppendLine('        </div>')

        [void]$htmlBuilder.AppendLine('    </div>')
        [void]$htmlBuilder.AppendLine('</body>')
        [void]$htmlBuilder.AppendLine('</html>')

        $htmlContent = $htmlBuilder.ToString()

        # Determine output file path (use temp file if not specified)
        if (-not $OutputPath) {
            $tempFileName = "ADHealthReport_$($reportTimestamp.ToString('yyyyMMdd_HHmmss')).html"
            $OutputPath = Join-Path -Path $env:TEMP -ChildPath $tempFileName
            Write-Verbose "No output path specified, using temp file: $OutputPath"
        }

        Write-Verbose "Saving report to: $OutputPath"

        try {
            # Ensure directory exists
            $directory = Split-Path -Path $OutputPath -Parent
            if ($directory -and -not (Test-Path -Path $directory)) {
                New-Item -Path $directory -ItemType Directory -Force | Out-Null
            }

            $htmlContent | Out-File -FilePath $OutputPath -Encoding UTF8 -Force
            Write-Verbose "Report saved successfully to: $OutputPath"

            # Open in browser if -Show switch is specified
            if ($Show) {
                Write-Verbose "Opening report in default web browser..."
                try {
                    # Use Start-Process to open in default browser
                    Start-Process $OutputPath
                    Write-Verbose "Report opened in browser"
                }
                catch {
                    Write-Warning "Failed to open report in browser: $_"
                }
            }

            # Return the file info
            Get-Item -Path $OutputPath
        }
        catch {
            Write-Error "Failed to save report to $OutputPath : $_"
            throw
        }

        Write-Verbose "HTML report generation completed"
    }
}
