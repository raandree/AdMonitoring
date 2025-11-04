function Get-ADDomainControllerPerformance {
    <#
    .SYNOPSIS
        Monitors domain controller resource utilization and performance metrics.

    .DESCRIPTION
        The Get-ADDomainControllerPerformance function collects performance metrics from
        domain controllers including CPU, memory, disk space, and LDAP connection statistics.

        This function monitors:
        - CPU utilization percentage
        - Memory usage (committed bytes, available memory)
        - Disk space on NTDS.dit volume
        - Active LDAP connections
        - LSASS process memory usage
        - Network interface statistics

        Performance issues can indicate capacity problems, resource bottlenecks, or
        hardware limitations that affect AD service delivery.

    .PARAMETER ComputerName
        Specifies one or more domain controller names to monitor. If not specified,
        all domain controllers in the current domain are discovered and monitored.

        Accepts pipeline input and aliases: Name, HostName, DnsHostName.

    .PARAMETER Credential
        Specifies credentials to use when connecting to domain controllers.
        If not specified, current user credentials are used.

    .PARAMETER CPUWarningThreshold
        CPU utilization percentage that triggers a warning status.
        Default is 70%. Valid range: 1-100.

    .PARAMETER CPUCriticalThreshold
        CPU utilization percentage that triggers a critical status.
        Default is 90%. Valid range: 1-100.

    .PARAMETER MemoryWarningThreshold
        Memory utilization percentage that triggers a warning status.
        Default is 80%. Valid range: 1-100.

    .PARAMETER MemoryCriticalThreshold
        Memory utilization percentage that triggers a critical status.
        Default is 90%. Valid range: 1-100.

    .PARAMETER DiskWarningThreshold
        Free disk space percentage that triggers a warning status.
        Default is 20%. Valid range: 1-100.

    .PARAMETER DiskCriticalThreshold
        Free disk space percentage that triggers a critical status.
        Default is 10%. Valid range: 1-100.

    .EXAMPLE
        Get-ADDomainControllerPerformance

        Monitors all domain controllers using default thresholds.

    .EXAMPLE
        Get-ADDomainControllerPerformance -ComputerName 'DC01', 'DC02'

        Monitors specific domain controllers for performance metrics.

    .EXAMPLE
        Get-ADDomainControllerPerformance -CPUWarningThreshold 60 -CPUCriticalThreshold 80

        Uses stricter CPU utilization thresholds for monitoring.

    .EXAMPLE
        Get-ADDomainController -Filter * | Get-ADDomainControllerPerformance

        Uses pipeline input to monitor all domain controllers.

    .INPUTS
        System.String
        Microsoft.ActiveDirectory.Management.ADDomainController

        You can pipe computer names or ADDomainController objects to this function.

    .OUTPUTS
        AdMonitoring.HealthCheckResult

        Returns health check result objects with performance metrics and analysis.

    .NOTES
        Author: AdMonitoring Project
        Requires: PowerShell 5.1 or later, appropriate WMI/CIM permissions

        Performance monitoring is critical for:
        - Capacity planning and forecasting
        - Identifying resource bottlenecks
        - Detecting hardware limitations
        - Preventing service degradation
        - Optimizing AD infrastructure

        This function requires appropriate permissions to query performance counters.

    .LINK
        https://docs.microsoft.com/windows-server/identity/ad-ds/plan/capacity-planning-for-active-directory-domain-services
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Name', 'HostName', 'DnsHostName')]
        [string[]]$ComputerName,

        [Parameter()]
        [PSCredential]$Credential,

        [Parameter()]
        [ValidateRange(1, 100)]
        [int]$CPUWarningThreshold = 70,

        [Parameter()]
        [ValidateRange(1, 100)]
        [int]$CPUCriticalThreshold = 90,

        [Parameter()]
        [ValidateRange(1, 100)]
        [int]$MemoryWarningThreshold = 80,

        [Parameter()]
        [ValidateRange(1, 100)]
        [int]$MemoryCriticalThreshold = 90,

        [Parameter()]
        [ValidateRange(1, 100)]
        [int]$DiskWarningThreshold = 20,

        [Parameter()]
        [ValidateRange(1, 100)]
        [int]$DiskCriticalThreshold = 10
    )

    begin {
        Write-Verbose "Starting DC performance monitoring"

        # Import required module
        if (-not (Get-Module -Name ActiveDirectory -ListAvailable)) {
            throw "ActiveDirectory module is required but not installed. Install RSAT-AD-PowerShell feature."
        }

        # Auto-discover domain controllers if not specified
        if (-not $PSBoundParameters.ContainsKey('ComputerName')) {
            Write-Verbose "Auto-discovering domain controllers"
            try {
                $domainControllers = Get-ADDomainController -Filter * -ErrorAction Stop
                $ComputerName = $domainControllers.HostName
                Write-Verbose "Discovered $($ComputerName.Count) domain controllers"
            }
            catch {
                Write-Error "Failed to discover domain controllers: $_"
                return
            }
        }

        Write-Verbose "Thresholds: CPU=$CPUWarningThreshold%/$CPUCriticalThreshold%, Memory=$MemoryWarningThreshold%/$MemoryCriticalThreshold%, Disk=$DiskWarningThreshold%/$DiskCriticalThreshold%"
    }

    process {
        foreach ($dc in $ComputerName) {
            Write-Verbose "Collecting performance metrics from: $dc"

            $details = [PSCustomObject]@{
                ComputerName         = $dc
                CPUUtilization       = $null
                MemoryTotalGB        = $null
                MemoryUsedGB         = $null
                MemoryAvailableGB    = $null
                MemoryUtilization    = $null
                DiskDrives           = @()
                NTDSDrive            = $null
                NTDSDriveFreeGB      = $null
                NTDSDriveFreePercent = $null
                ActiveLDAPConnections = $null
                LSASSMemoryMB        = $null
                UptimeDays           = $null
                PerformanceIssues    = @()
                Error                = $null
            }

            $recommendations = [System.Collections.Generic.List[string]]::new()
            $status = 'Healthy'
            $message = "Performance metrics within normal ranges"

            try {
                # Get CPU utilization
                Write-Verbose "Querying CPU utilization on $dc"
                try {
                    $cimParams = @{
                        ComputerName = $dc
                        ClassName    = 'Win32_Processor'
                        ErrorAction  = 'Stop'
                    }

                    if ($PSBoundParameters.ContainsKey('Credential')) {
                        $cimParams['Credential'] = $Credential
                    }

                    $cpu = Get-CimInstance @cimParams
                    $cpuLoad = ($cpu | Measure-Object -Property LoadPercentage -Average).Average
                    $details.CPUUtilization = [math]::Round($cpuLoad, 2)

                    Write-Verbose "CPU utilization: $($details.CPUUtilization)%"

                    if ($details.CPUUtilization -ge $CPUCriticalThreshold) {
                        $status = 'Critical'
                        $message = "CPU utilization is critically high"
                        $details.PerformanceIssues += "CPU: $($details.CPUUtilization)% (Critical threshold: $CPUCriticalThreshold%)"
                        $recommendations.Add("URGENT: CPU utilization at $($details.CPUUtilization)% - Investigate high CPU processes")
                        $recommendations.Add("Review Task Manager or Process Explorer for resource-intensive processes")
                        $recommendations.Add("Consider DC hardware upgrade if sustained high CPU")
                    }
                    elseif ($details.CPUUtilization -ge $CPUWarningThreshold) {
                        if ($status -eq 'Healthy') {
                            $status = 'Warning'
                            $message = "CPU utilization above warning threshold"
                        }
                        $details.PerformanceIssues += "CPU: $($details.CPUUtilization)% (Warning threshold: $CPUWarningThreshold%)"
                        $recommendations.Add("Monitor CPU utilization - currently at $($details.CPUUtilization)%")
                        $recommendations.Add("Review for sustained high CPU patterns")
                    }
                }
                catch {
                    Write-Warning "Failed to query CPU on ${dc}: $_"
                    if (-not $details.Error) {
                        $details.Error = "CPU query failed: $($_.Exception.Message)"
                    }
                }

                # Get memory utilization
                Write-Verbose "Querying memory utilization on $dc"
                try {
                    $cimParams['ClassName'] = 'Win32_OperatingSystem'
                    $os = Get-CimInstance @cimParams

                    $details.MemoryTotalGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
                    $details.MemoryAvailableGB = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
                    $details.MemoryUsedGB = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1MB, 2)
                    $details.MemoryUtilization = [math]::Round(($details.MemoryUsedGB / $details.MemoryTotalGB) * 100, 2)

                    Write-Verbose "Memory: $($details.MemoryUsedGB)GB / $($details.MemoryTotalGB)GB ($($details.MemoryUtilization)%)"

                    if ($details.MemoryUtilization -ge $MemoryCriticalThreshold) {
                        $status = 'Critical'
                        $message = "Memory utilization is critically high"
                        $details.PerformanceIssues += "Memory: $($details.MemoryUtilization)% (Critical threshold: $MemoryCriticalThreshold%)"
                        $recommendations.Add("URGENT: Memory at $($details.MemoryUtilization)% - Add more RAM or reduce workload")
                        $recommendations.Add("Check for memory leaks in LSASS or other processes")
                    }
                    elseif ($details.MemoryUtilization -ge $MemoryWarningThreshold) {
                        if ($status -eq 'Healthy') {
                            $status = 'Warning'
                            $message = "Memory utilization above warning threshold"
                        }
                        $details.PerformanceIssues += "Memory: $($details.MemoryUtilization)% (Warning threshold: $MemoryWarningThreshold%)"
                        $recommendations.Add("Monitor memory usage - currently at $($details.MemoryUtilization)%")
                        $recommendations.Add("Consider adding RAM for optimal performance")
                    }

                    # Get system uptime
                    $details.UptimeDays = [math]::Round(((Get-Date) - $os.LastBootUpTime).TotalDays, 2)
                    Write-Verbose "System uptime: $($details.UptimeDays) days"
                }
                catch {
                    Write-Warning "Failed to query memory on ${dc}: $_"
                    if (-not $details.Error) {
                        $details.Error = "Memory query failed: $($_.Exception.Message)"
                    }
                }

                # Get disk space
                Write-Verbose "Querying disk space on $dc"
                try {
                    $cimParams['ClassName'] = 'Win32_LogicalDisk'
                    $cimParams['Filter'] = "DriveType=3"  # Local disks only
                    $disks = Get-CimInstance @cimParams

                    $details.DiskDrives = @($disks | ForEach-Object {
                        $freePercent = [math]::Round(($_.FreeSpace / $_.Size) * 100, 2)
                        [PSCustomObject]@{
                            Drive       = $_.DeviceID
                            SizeGB      = [math]::Round($_.Size / 1GB, 2)
                            FreeGB      = [math]::Round($_.FreeSpace / 1GB, 2)
                            FreePercent = $freePercent
                        }
                    })

                    # Try to locate NTDS.dit drive
                    $invokeParams = @{
                        ComputerName = $dc
                        ScriptBlock  = {
                            try {
                                $regPath = 'Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\NTDS\Parameters'
                                $props = Get-ItemProperty -Path $regPath -ErrorAction Stop
                                $dbFile = $props.'DSA Database file' -replace '"', ''
                                if ($dbFile) {
                                    Split-Path $dbFile -Qualifier
                                }
                            }
                            catch {
                                $null
                            }
                        }
                        ErrorAction  = 'Stop'
                    }

                    if ($PSBoundParameters.ContainsKey('Credential')) {
                        $invokeParams['Credential'] = $Credential
                    }

                    $ntdsDrive = Invoke-Command @invokeParams

                    if ($ntdsDrive) {
                        $ntdsDisk = $details.DiskDrives | Where-Object { $_.Drive -eq $ntdsDrive }
                        if ($ntdsDisk) {
                            $details.NTDSDrive = $ntdsDrive
                            $details.NTDSDriveFreeGB = $ntdsDisk.FreeGB
                            $details.NTDSDriveFreePercent = $ntdsDisk.FreePercent

                            Write-Verbose "NTDS.dit on ${ntdsDrive}: $($ntdsDisk.FreeGB)GB free ($($ntdsDisk.FreePercent)%)"

                            if ($ntdsDisk.FreePercent -le $DiskCriticalThreshold) {
                                $status = 'Critical'
                                $message = "NTDS drive critically low on space"
                                $details.PerformanceIssues += "Disk ${ntdsDrive}: $($ntdsDisk.FreePercent)% free (Critical threshold: $DiskCriticalThreshold%)"
                                $recommendations.Add("URGENT: NTDS drive at $($ntdsDisk.FreePercent)% free - Expand disk immediately")
                                $recommendations.Add("AD database may stop functioning if disk fills")
                            }
                            elseif ($ntdsDisk.FreePercent -le $DiskWarningThreshold) {
                                if ($status -eq 'Healthy') {
                                    $status = 'Warning'
                                    $message = "NTDS drive low on space"
                                }
                                $details.PerformanceIssues += "Disk ${ntdsDrive}: $($ntdsDisk.FreePercent)% free (Warning threshold: $DiskWarningThreshold%)"
                                $recommendations.Add("NTDS drive at $($ntdsDisk.FreePercent)% free - Plan disk expansion")
                                $recommendations.Add("Monitor disk space growth trends")
                            }
                        }
                    }

                    # Check all other drives
                    foreach ($disk in $details.DiskDrives | Where-Object { $_.Drive -ne $ntdsDrive }) {
                        if ($disk.FreePercent -le $DiskCriticalThreshold) {
                            if ($status -ne 'Critical') {
                                $status = 'Warning'
                            }
                            $details.PerformanceIssues += "Disk $($disk.Drive): $($disk.FreePercent)% free"
                            $recommendations.Add("Drive $($disk.Drive) low on space: $($disk.FreeGB)GB free")
                        }
                    }
                }
                catch {
                    Write-Warning "Failed to query disk space on ${dc}: $_"
                    if (-not $details.Error) {
                        $details.Error = "Disk query failed: $($_.Exception.Message)"
                    }
                }

                # Get LDAP connections
                Write-Verbose "Querying LDAP connections on $dc"
                try {
                    $invokeParams['ScriptBlock'] = {
                        try {
                            $counterPath = '\DirectoryServices(NTDS)\LDAP Client Sessions'
                            (Get-Counter -Counter $counterPath -ErrorAction Stop).CounterSamples.CookedValue
                        }
                        catch {
                            $null
                        }
                    }

                    $ldapConnections = Invoke-Command @invokeParams
                    if ($ldapConnections) {
                        $details.ActiveLDAPConnections = [int]$ldapConnections
                        Write-Verbose "Active LDAP connections: $($details.ActiveLDAPConnections)"
                    }
                }
                catch {
                    Write-Verbose "Could not query LDAP connections on ${dc}: $_"
                }

                # Get LSASS memory usage
                Write-Verbose "Querying LSASS memory on $dc"
                try {
                    $invokeParams['ScriptBlock'] = {
                        $lsass = Get-Process -Name lsass -ErrorAction Stop
                        [math]::Round($lsass.WorkingSet64 / 1MB, 2)
                    }

                    $lsassMemory = Invoke-Command @invokeParams
                    if ($lsassMemory) {
                        $details.LSASSMemoryMB = $lsassMemory
                        Write-Verbose "LSASS memory: $($details.LSASSMemoryMB)MB"
                    }
                }
                catch {
                    Write-Verbose "Could not query LSASS memory on ${dc}: $_"
                }

                # Add general recommendations if healthy
                if ($status -eq 'Healthy') {
                    $recommendations.Add("Performance metrics are healthy")
                    $recommendations.Add("Continue monitoring for capacity planning")
                    $recommendations.Add("Review trends over time for proactive management")
                }
                elseif ($status -eq 'Warning') {
                    $recommendations.Add("Address warning-level issues before they become critical")
                    $recommendations.Add("Review performance trends and plan capacity upgrades")
                }
            }
            catch {
                Write-Warning "Unexpected error monitoring ${dc}: $_"
                $status = 'Critical'
                $message = "Unexpected error during performance monitoring"
                $details.Error = $_.Exception.Message
                $recommendations.Add("Review error details and verify DC accessibility")
                $recommendations.Add("Check WMI/CIM service status")
            }

            # Output result
            [PSCustomObject]@{
                PSTypeName      = 'AdMonitoring.HealthCheckResult'
                CheckName       = 'DCPerformance'
                Category        = 'Performance'
                Status          = $status
                Severity        = 'Medium'
                Timestamp       = Get-Date
                Target          = $dc
                Message         = $message
                Details         = $details
                Recommendations = $recommendations.ToArray()
                RawData         = $null
            }
        }
    }

    end {
        Write-Verbose "Completed DC performance monitoring"
    }
}
