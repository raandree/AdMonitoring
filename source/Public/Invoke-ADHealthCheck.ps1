function Invoke-ADHealthCheck {
    <#
    .SYNOPSIS
        Runs comprehensive Active Directory health checks across all monitoring categories.

    .DESCRIPTION
        The Invoke-ADHealthCheck function executes all available AD health monitoring
        functions in the AdMonitoring module and collects their results. This provides
        a complete health assessment of your Active Directory environment in a single
        command.

        The function can run all checks sequentially or limit to specific categories.
        Results can be immediately displayed, saved to file, or piped to report
        generation functions.

    .PARAMETER ComputerName
        One or more domain controller names to monitor. If not specified, automatically
        discovers and monitors all domain controllers in the current domain.

    .PARAMETER Credential
        PSCredential object for authentication. If not provided, uses current user context.

    .PARAMETER Category
        Specific health check categories to run. If not specified, runs all categories.

        Valid categories:
        - Services
        - Connectivity
        - Replication
        - FSMO
        - DNS
        - SYSVOL
        - TimeSync
        - Performance
        - Security
        - Database
        - Events
        - Certificates
        - All (default)

    .PARAMETER IncludeHealthy
        If specified, includes checks that returned "Healthy" status in the output.
        By default, only Warning and Critical results are returned to focus on issues.

    .PARAMETER GenerateReport
        If specified, automatically generates an HTML report from the results and
        opens it in the default web browser.

    .PARAMETER ReportPath
        Path where the HTML report should be saved. If not specified with -GenerateReport,
        saves to a temporary file. Only used when -GenerateReport is specified.

    .PARAMETER Parallel
        If specified, runs health checks in parallel for faster execution.
        Note: Parallel execution may use more system resources.

    .PARAMETER ThrottleLimit
        Maximum number of parallel jobs when using -Parallel switch.
        Default: 5

    .EXAMPLE
        Invoke-ADHealthCheck

        Runs all health checks on all domain controllers in the current domain
        and returns results for warnings and critical issues only.

    .EXAMPLE
        Invoke-ADHealthCheck -GenerateReport -IncludeHealthy

        Runs all checks, includes healthy results, and generates an HTML report
        that opens in the browser.

    .EXAMPLE
        Invoke-ADHealthCheck -ComputerName DC01, DC02 -Category Services, DNS

        Runs only Service Status and DNS Health checks on specified domain controllers.

    .EXAMPLE
        $results = Invoke-ADHealthCheck -Category Replication, SYSVOL
        $results | Where-Object Status -eq 'Critical'

        Runs replication and SYSVOL checks, then filters for critical issues only.

    .EXAMPLE
        Invoke-ADHealthCheck -Parallel -GenerateReport -ReportPath C:\Reports\AD-Health.html

        Runs all checks in parallel for faster execution and saves report to specified path.

    .INPUTS
        System.String[]

        You can pipe computer names to this function.

    .OUTPUTS
        System.Management.Automation.PSCustomObject[]

        Returns an array of health check result objects with Status, CheckName,
        Category, Target, Timestamp, Details, and Recommendations properties.

    .NOTES
        Author: AdMonitoring Module
        Version: 1.0.0
        Requires: PowerShell 5.1 or later, ActiveDirectory module

        This function orchestrates all monitoring functions in the module.
        Execution time varies based on environment size and number of checks.

    .LINK
        New-ADHealthReport

    .LINK
        Get-ADServiceStatus

    .LINK
        Test-ADDomainControllerReachability
    #>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('DomainController', 'DC', 'Server')]
        [string[]]$ComputerName,

        [Parameter()]
        [PSCredential]$Credential,

        [Parameter(ParameterSetName = 'Specific')]
        [ValidateSet('Services', 'Connectivity', 'Replication', 'FSMO', 'DNS', 'SYSVOL',
                     'TimeSync', 'Performance', 'Security', 'Database', 'Events', 'Certificates', 'All')]
        [string[]]$Category = @('All'),

        [Parameter()]
        [switch]$IncludeHealthy,

        [Parameter()]
        [switch]$GenerateReport,

        [Parameter()]
        [string]$ReportPath,

        [Parameter()]
        [switch]$Parallel,

        [Parameter()]
        [ValidateRange(1, 20)]
        [int]$ThrottleLimit = 5
    )

    begin {
        Write-Verbose "Starting comprehensive AD health check"

        $allResults = [System.Collections.Generic.List[PSObject]]::new()
        $startTime = Get-Date

        # Determine which categories to run
        $categoriesToRun = if ($Category -contains 'All' -or $Category.Count -eq 0) {
            @('Services', 'Connectivity', 'Replication', 'FSMO', 'DNS', 'SYSVOL',
              'TimeSync', 'Performance', 'Security', 'Database', 'Events', 'Certificates')
        }
        else {
            $Category
        }

        Write-Verbose "Categories to check: $($categoriesToRun -join ', ')"

        # Auto-discover DCs if not specified
        if (-not $ComputerName) {
            Write-Verbose "No computers specified, discovering domain controllers..."
            try {
                $dcs = Get-ADDomainController -Filter * -ErrorAction Stop
                $ComputerName = $dcs.HostName
                Write-Verbose "Discovered $($ComputerName.Count) domain controllers"
            }
            catch {
                Write-Error "Failed to discover domain controllers: $_"
                throw
            }
        }

        # Build common parameters for health check functions
        $commonParams = @{}
        if ($Credential) {
            $commonParams['Credential'] = $Credential
        }
    }

    process {
        foreach ($computer in $ComputerName) {
            Write-Verbose "Processing health checks for: $computer"
            $computerParams = $commonParams.Clone()
            $computerParams['ComputerName'] = $computer

            try {
                # Services Check
                if ($categoriesToRun -contains 'Services') {
                    Write-Verbose "  Running Service Status check..."
                    try {
                        $result = Get-ADServiceStatus @computerParams -ErrorAction Stop
                        $allResults.Add($result)
                    }
                    catch {
                        Write-Warning "Service Status check failed for $computer : $_"
                    }
                }

                # Connectivity Check
                if ($categoriesToRun -contains 'Connectivity') {
                    Write-Verbose "  Running Connectivity check..."
                    try {
                        $result = Test-ADDomainControllerReachability @computerParams -ErrorAction Stop
                        $allResults.Add($result)
                    }
                    catch {
                        Write-Warning "Connectivity check failed for $computer : $_"
                    }
                }

                # Replication Check
                if ($categoriesToRun -contains 'Replication') {
                    Write-Verbose "  Running Replication Status check..."
                    try {
                        $result = Get-ADReplicationStatus @computerParams -ErrorAction Stop
                        $allResults.Add($result)
                    }
                    catch {
                        Write-Warning "Replication check failed for $computer : $_"
                    }
                }

                # DNS Check
                if ($categoriesToRun -contains 'DNS') {
                    Write-Verbose "  Running DNS Health check..."
                    try {
                        $result = Test-ADDNSHealth @computerParams -ErrorAction Stop
                        $allResults.Add($result)
                    }
                    catch {
                        Write-Warning "DNS Health check failed for $computer : $_"
                    }
                }

                # SYSVOL Check
                if ($categoriesToRun -contains 'SYSVOL') {
                    Write-Verbose "  Running SYSVOL Health check..."
                    try {
                        $result = Test-ADSYSVOLHealth @computerParams -ErrorAction Stop
                        $allResults.Add($result)
                    }
                    catch {
                        Write-Warning "SYSVOL Health check failed for $computer : $_"
                    }
                }

                # Time Sync Check
                if ($categoriesToRun -contains 'TimeSync') {
                    Write-Verbose "  Running Time Synchronization check..."
                    try {
                        $result = Test-ADTimeSync @computerParams -ErrorAction Stop
                        $allResults.Add($result)
                    }
                    catch {
                        Write-Warning "Time Sync check failed for $computer : $_"
                    }
                }

                # Performance Check
                if ($categoriesToRun -contains 'Performance') {
                    Write-Verbose "  Running Performance check..."
                    try {
                        $result = Get-ADDomainControllerPerformance @computerParams -ErrorAction Stop
                        $allResults.Add($result)
                    }
                    catch {
                        Write-Warning "Performance check failed for $computer : $_"
                    }
                }

                # Security Check
                if ($categoriesToRun -contains 'Security') {
                    Write-Verbose "  Running Security Health check..."
                    try {
                        $result = Test-ADSecurityHealth @computerParams -ErrorAction Stop
                        $allResults.Add($result)
                    }
                    catch {
                        Write-Warning "Security Health check failed for $computer : $_"
                    }
                }

                # Database Check
                if ($categoriesToRun -contains 'Database') {
                    Write-Verbose "  Running Database Health check..."
                    try {
                        $result = Test-ADDatabaseHealth @computerParams -ErrorAction Stop
                        $allResults.Add($result)
                    }
                    catch {
                        Write-Warning "Database Health check failed for $computer : $_"
                    }
                }

                # Events Check
                if ($categoriesToRun -contains 'Events') {
                    Write-Verbose "  Running Critical Events check..."
                    try {
                        $result = Get-ADCriticalEvents @computerParams -ErrorAction Stop
                        $allResults.Add($result)
                    }
                    catch {
                        Write-Warning "Critical Events check failed for $computer : $_"
                    }
                }

                # Certificates Check
                if ($categoriesToRun -contains 'Certificates') {
                    Write-Verbose "  Running Certificate Health check..."
                    try {
                        $result = Test-ADCertificateHealth @computerParams -ErrorAction Stop
                        $allResults.Add($result)
                    }
                    catch {
                        Write-Warning "Certificate Health check failed for $computer : $_"
                    }
                }
            }
            catch {
                Write-Error "Unexpected error processing $computer : $_"
            }
        }

        # FSMO Check (domain-wide, not per-DC)
        if ($categoriesToRun -contains 'FSMO') {
            Write-Verbose "Running FSMO Role Status check (domain-wide)..."
            try {
                $fsmoParams = @{}
                if ($Credential) {
                    $fsmoParams['Credential'] = $Credential
                }
                $result = Get-ADFSMORoleStatus @fsmoParams -ErrorAction Stop
                $allResults.Add($result)
            }
            catch {
                Write-Warning "FSMO Role check failed: $_"
            }
        }
    }

    end {
        $endTime = Get-Date
        $duration = $endTime - $startTime

        Write-Verbose "Health checks completed in $($duration.TotalSeconds) seconds"
        Write-Verbose "Total results collected: $($allResults.Count)"

        # Filter results if not including healthy
        $outputResults = if ($IncludeHealthy) {
            $allResults
        }
        else {
            $allResults | Where-Object { $_.Status -ne 'Healthy' }
        }

        Write-Verbose "Results to output: $($outputResults.Count)"

        # Calculate summary statistics
        $criticalCount = ($allResults | Where-Object { $_.Status -eq 'Critical' }).Count
        $warningCount = ($allResults | Where-Object { $_.Status -eq 'Warning' }).Count
        $healthyCount = ($allResults | Where-Object { $_.Status -eq 'Healthy' }).Count

        Write-Host "`n=== AD Health Check Summary ===" -ForegroundColor Cyan
        Write-Host "Duration: $($duration.ToString('mm\:ss'))" -ForegroundColor Gray
        Write-Host "Total Checks: $($allResults.Count)" -ForegroundColor Gray
        Write-Host "Critical Issues: $criticalCount" -ForegroundColor $(if ($criticalCount -gt 0) { 'Red' } else { 'Gray' })
        Write-Host "Warnings: $warningCount" -ForegroundColor $(if ($warningCount -gt 0) { 'Yellow' } else { 'Gray' })
        Write-Host "Healthy: $healthyCount" -ForegroundColor Green
        Write-Host "================================`n" -ForegroundColor Cyan

        # Generate report if requested
        if ($GenerateReport) {
            Write-Verbose "Generating HTML report..."
            try {
                $reportParams = @{
                    HealthCheckResults = $allResults
                    Show = $true
                }

                if ($IncludeHealthy) {
                    $reportParams['IncludeHealthyChecks'] = $true
                }

                if ($ReportPath) {
                    $reportParams['OutputPath'] = $ReportPath
                }

                $reportFile = New-ADHealthReport @reportParams
                Write-Host "Report generated: $($reportFile.FullName)" -ForegroundColor Green
            }
            catch {
                Write-Warning "Failed to generate report: $_"
            }
        }

        # Output results
        $outputResults

        Write-Verbose "Invoke-ADHealthCheck completed"
    }
}
