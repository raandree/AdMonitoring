function Send-ADHealthReport {
    <#
    .SYNOPSIS
        Sends Active Directory health check results via email with optional HTML report attachment.

    .DESCRIPTION
        The Send-ADHealthReport function sends health check results via email using SMTP.
        It can send results in three formats:
        - Plain text summary in email body
        - HTML report in email body
        - HTML report as attachment

        The function supports both authenticated and anonymous SMTP servers, SSL/TLS,
        and can include multiple recipients.

    .PARAMETER HealthCheckResults
        An array of health check result objects from AD monitoring functions.
        These objects should have the standard AdMonitoring output structure.

    .PARAMETER To
        One or more email addresses to send the report to.

    .PARAMETER From
        The sender's email address.

    .PARAMETER Subject
        The email subject line. Default: "Active Directory Health Report - [Date]"

    .PARAMETER SmtpServer
        The SMTP server hostname or IP address.

    .PARAMETER Port
        The SMTP server port. Default: 25 (or 587 if -UseSsl is specified)

    .PARAMETER UseSsl
        If specified, uses SSL/TLS for the SMTP connection.

    .PARAMETER Credential
        PSCredential object for SMTP authentication. If not provided, uses anonymous SMTP.

    .PARAMETER Priority
        Email priority. Valid values: Low, Normal, High. Default: Normal

    .PARAMETER BodyFormat
        Format of the email body:
        - Text: Plain text summary (default)
        - Html: Full HTML report in body
        - Attachment: Plain text body with HTML report attached

    .PARAMETER IncludeHealthy
        If specified, includes checks that returned "Healthy" status.
        By default, only Warning and Critical issues are included.

    .PARAMETER AttachmentName
        Name for the HTML report attachment. Default: "AD-Health-Report.html"
        Only used when -BodyFormat is set to "Attachment".

    .PARAMETER Cc
        One or more email addresses to CC on the report.

    .PARAMETER Bcc
        One or more email addresses to BCC on the report.

    .PARAMETER ReportTitle
        Custom title for the HTML report. Default: "Active Directory Health Report"

    .EXAMPLE
        $results = Invoke-ADHealthCheck
        Send-ADHealthReport -HealthCheckResults $results -To 'admin@contoso.com' -From 'monitoring@contoso.com' -SmtpServer 'mail.contoso.com'

        Sends a plain text email summary to admin@contoso.com.

    .EXAMPLE
        $results = Invoke-ADHealthCheck
        $params = @{
            HealthCheckResults = $results
            To = 'team@contoso.com'
            From = 'admon@contoso.com'
            SmtpServer = 'smtp.office365.com'
            Port = 587
            UseSsl = $true
            Credential = Get-Credential
            BodyFormat = 'Html'
            Priority = 'High'
        }
        Send-ADHealthReport @params

        Sends an HTML email with full report using authenticated SMTP with SSL.

    .EXAMPLE
        Invoke-ADHealthCheck | Send-ADHealthReport -To 'oncall@contoso.com' -From 'alerts@contoso.com' -SmtpServer 'localhost' -BodyFormat Attachment

        Runs health checks and sends results with HTML report as attachment.

    .EXAMPLE
        $cred = Get-Credential
        $results = Invoke-ADHealthCheck -Category Replication,DNS
        Send-ADHealthReport -HealthCheckResults $results -To 'admin@contoso.com','manager@contoso.com' -Cc 'team@contoso.com' -From 'monitoring@contoso.com' -SmtpServer 'smtp.gmail.com' -Port 587 -UseSsl -Credential $cred -Priority High

        Sends critical category results to multiple recipients with Gmail SMTP.

    .INPUTS
        System.Management.Automation.PSObject[]

        You can pipe health check result objects to this function.

    .OUTPUTS
        None

        This function does not return any output. Success or failure is indicated
        through Write-Verbose and Write-Error messages.

    .NOTES
        Author: AdMonitoring Module
        Version: 1.0.0
        Requires: PowerShell 5.1 or later

        For Office 365/Microsoft 365, use:
        - SmtpServer: smtp.office365.com
        - Port: 587
        - UseSsl: $true
        - Credential: Required

        For Gmail, use:
        - SmtpServer: smtp.gmail.com
        - Port: 587
        - UseSsl: $true
        - Credential: Required (App Password recommended)

    .LINK
        New-ADHealthReport

    .LINK
        Invoke-ADHealthCheck
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Write-Host used intentionally for user feedback on email delivery status')]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [PSObject[]]$HealthCheckResults,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]]$To,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$From,

        [Parameter()]
        [string]$Subject,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$SmtpServer,

        [Parameter()]
        [ValidateRange(1, 65535)]
        [int]$Port,

        [Parameter()]
        [switch]$UseSsl,

        [Parameter()]
        [PSCredential]$Credential,

        [Parameter()]
        [ValidateSet('Low', 'Normal', 'High')]
        [string]$Priority = 'Normal',

        [Parameter()]
        [ValidateSet('Text', 'Html', 'Attachment')]
        [string]$BodyFormat = 'Text',

        [Parameter()]
        [switch]$IncludeHealthy,

        [Parameter()]
        [string]$AttachmentName = 'AD-Health-Report.html',

        [Parameter()]
        [string[]]$Cc,

        [Parameter()]
        [string[]]$Bcc,

        [Parameter()]
        [string]$ReportTitle = 'Active Directory Health Report'
    )

    begin {
        Write-Verbose "Preparing to send AD health report via email"

        $allResults = [System.Collections.Generic.List[PSObject]]::new()

        # Set default port based on SSL
        if (-not $PSBoundParameters.ContainsKey('Port')) {
            $Port = if ($UseSsl) { 587 } else { 25 }
            Write-Verbose "Using default port: $Port"
        }

        # Generate default subject if not provided
        if (-not $Subject) {
            $Subject = "Active Directory Health Report - $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
        }
    }

    process {
        foreach ($result in $HealthCheckResults) {
            $allResults.Add($result)
        }
    }

    end {
        Write-Verbose "Processing $($allResults.Count) health check results"

        # Filter results if not including healthy
        $filteredResults = if ($IncludeHealthy) {
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

        # Determine overall status
        $overallStatus = if ($criticalCount -gt 0) {
            'Critical'
        }
        elseif ($warningCount -gt 0) {
            'Warning'
        }
        else {
            'Healthy'
        }

        # Build email body based on format
        $emailBody = switch ($BodyFormat) {
            'Text' {
                # Plain text summary
                $textBuilder = [System.Text.StringBuilder]::new()
                [void]$textBuilder.AppendLine("Active Directory Health Report")
                [void]$textBuilder.AppendLine("=" * 60)
                [void]$textBuilder.AppendLine("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
                [void]$textBuilder.AppendLine("Overall Status: $overallStatus")
                [void]$textBuilder.AppendLine("")
                [void]$textBuilder.AppendLine("Summary Statistics:")
                [void]$textBuilder.AppendLine("  Total Checks: $totalChecks")
                [void]$textBuilder.AppendLine("  Critical Issues: $criticalCount")
                [void]$textBuilder.AppendLine("  Warnings: $warningCount")
                [void]$textBuilder.AppendLine("  Healthy: $healthyCount")
                [void]$textBuilder.AppendLine("")

                if ($filteredResults.Count -eq 0) {
                    [void]$textBuilder.AppendLine("No issues detected. All systems are healthy.")
                }
                else {
                    [void]$textBuilder.AppendLine("Issues Requiring Attention:")
                    [void]$textBuilder.AppendLine("-" * 60)

                    foreach ($result in $filteredResults) {
                        [void]$textBuilder.AppendLine("")
                        [void]$textBuilder.AppendLine("[$($result.Status)] $($result.CheckName)")
                        [void]$textBuilder.AppendLine("  Category: $($result.Category)")
                        [void]$textBuilder.AppendLine("  Target: $($result.Target)")
                        [void]$textBuilder.AppendLine("  Checked: $($result.Timestamp.ToString('yyyy-MM-dd HH:mm:ss'))")

                        if ($result.Recommendations -and $result.Recommendations.Count -gt 0) {
                            [void]$textBuilder.AppendLine("  Recommendations:")
                            foreach ($rec in $result.Recommendations) {
                                [void]$textBuilder.AppendLine("    - $rec")
                            }
                        }
                    }
                }

                [void]$textBuilder.AppendLine("")
                [void]$textBuilder.AppendLine("=" * 60)
                [void]$textBuilder.AppendLine("This report was generated automatically by the AdMonitoring PowerShell module.")

                $textBuilder.ToString()
            }

            'Html' {
                # Generate full HTML report for body
                Write-Verbose "Generating HTML report for email body"
                $tempFile = [System.IO.Path]::GetTempFileName() + '.html'

                try {
                    $reportParams = @{
                        HealthCheckResults = $allResults
                        OutputPath = $tempFile
                        Title = $ReportTitle
                    }

                    if ($IncludeHealthy) {
                        $reportParams['IncludeHealthyChecks'] = $true
                    }

                    $reportFile = New-ADHealthReport @reportParams
                    Get-Content -Path $reportFile.FullName -Raw
                }
                finally {
                    if (Test-Path -Path $tempFile) {
                        Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
                    }
                }
            }

            'Attachment' {
                # Plain text body with attachment
                $textBuilder = [System.Text.StringBuilder]::new()
                [void]$textBuilder.AppendLine("Active Directory Health Report")
                [void]$textBuilder.AppendLine("")
                [void]$textBuilder.AppendLine("Please see the attached HTML report for complete details.")
                [void]$textBuilder.AppendLine("")
                [void]$textBuilder.AppendLine("Summary:")
                [void]$textBuilder.AppendLine("  Overall Status: $overallStatus")
                [void]$textBuilder.AppendLine("  Total Checks: $totalChecks")
                [void]$textBuilder.AppendLine("  Critical Issues: $criticalCount")
                [void]$textBuilder.AppendLine("  Warnings: $warningCount")
                [void]$textBuilder.AppendLine("  Healthy: $healthyCount")

                $textBuilder.ToString()
            }
        }

        # Prepare Send-MailMessage parameters
        $mailParams = @{
            To = $To
            From = $From
            Subject = $Subject
            Body = $emailBody
            SmtpServer = $SmtpServer
            Port = $Port
            Priority = $Priority
        }

        # Add optional parameters
        if ($UseSsl) {
            $mailParams['UseSsl'] = $true
        }

        if ($Credential) {
            $mailParams['Credential'] = $Credential
        }

        if ($Cc) {
            $mailParams['Cc'] = $Cc
        }

        if ($Bcc) {
            $mailParams['Bcc'] = $Bcc
        }

        # Set body format
        if ($BodyFormat -eq 'Html') {
            $mailParams['BodyAsHtml'] = $true
        }

        # Handle attachment if needed
        $attachmentPath = $null
        if ($BodyFormat -eq 'Attachment') {
            Write-Verbose "Generating HTML report attachment"
            $attachmentPath = Join-Path -Path $env:TEMP -ChildPath $AttachmentName

            try {
                $reportParams = @{
                    HealthCheckResults = $allResults
                    OutputPath = $attachmentPath
                    Title = $ReportTitle
                }

                if ($IncludeHealthy) {
                    $reportParams['IncludeHealthyChecks'] = $true
                }

                $reportFile = New-ADHealthReport @reportParams
                $mailParams['Attachments'] = $reportFile.FullName
                Write-Verbose "Attachment created: $($reportFile.FullName)"
            }
            catch {
                Write-Error "Failed to generate HTML attachment: $_"
                throw
            }
        }

        # Send the email
        if ($PSCmdlet.ShouldProcess("$($To -join ', ')", "Send AD Health Report")) {
            try {
                Write-Verbose "Sending email to: $($To -join ', ')"
                Write-Verbose "SMTP Server: $SmtpServer`:$Port (SSL: $UseSsl)"

                Send-MailMessage @mailParams -ErrorAction Stop

                Write-Host "Email sent successfully to: $($To -join ', ')" -ForegroundColor Green
                Write-Verbose "Email delivery completed"
            }
            catch {
                Write-Error "Failed to send email: $_"
                Write-Debug "SMTP Server: $SmtpServer"
                Write-Debug "Port: $Port"
                Write-Debug "SSL: $UseSsl"
                Write-Debug "Authentication: $(if ($Credential) { 'Yes' } else { 'No' })"
                throw
            }
            finally {
                # Clean up attachment file if created
                if ($attachmentPath -and (Test-Path -Path $attachmentPath)) {
                    try {
                        Remove-Item -Path $attachmentPath -Force -ErrorAction SilentlyContinue
                        Write-Verbose "Cleaned up temporary attachment file"
                    }
                    catch {
                        Write-Warning "Failed to clean up attachment file: $attachmentPath"
                    }
                }
            }
        }
    }
}
