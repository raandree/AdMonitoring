function Get-ADCriticalEvents {
    <#
    .SYNOPSIS
        Retrieves critical Active Directory events from domain controllers.

        Note: This function intentionally uses a plural noun as it returns multiple events,
        which is semantically correct despite PSScriptAnalyzer's PSUseSingularNouns rule.

    .DESCRIPTION
        The Get-ADCriticalEvents function scans Windows Event Logs on domain controllers
        for critical AD-related events that may indicate health issues or security concerns.

        Monitored Event Logs:
        - Directory Service
        - DNS Server
        - DFS Replication
        - File Replication Service
        - System (DC-specific events)

        Critical Event IDs include:
        - 1000-1999: General AD errors
        - 2042: Replication hasn't occurred (topology issues)
        - 4013: DNS zone transfer failure
        - 5805: Session setup failed (trust issue)
        - 13508: DFSR stopped replication
        - And many more critical events

        This function helps identify issues before they cause outages and provides
        actionable insights for remediation.

    .PARAMETER ComputerName
        Specifies one or more domain controller names to check. If not specified,
        all domain controllers in the current domain are discovered and checked.

        Accepts pipeline input and aliases: Name, HostName, DnsHostName.

    .PARAMETER Credential
        Specifies credentials to use when connecting to domain controllers.
        If not specified, current user credentials are used.

    .PARAMETER Hours
        Specifies how many hours back to scan for events. Default is 24 hours.
        Valid range: 1-168 hours (1 week).

    .PARAMETER IncludeWarnings
        If specified, includes Warning level events in addition to Error and Critical events.
        This can significantly increase the number of events returned.

    .PARAMETER MaxEvents
        Specifies the maximum number of events to retrieve per domain controller.
        Default is 100. Valid range: 1-1000.

    .EXAMPLE
        Get-ADCriticalEvents

        Scans all domain controllers for critical AD events in the last 24 hours.

    .EXAMPLE
        Get-ADCriticalEvents -ComputerName 'DC01', 'DC02' -Hours 48

        Scans specified domain controllers for critical events in the last 48 hours.

    .EXAMPLE
        Get-ADCriticalEvents -IncludeWarnings -MaxEvents 50

        Scans all DCs for critical and warning events, limiting to 50 events per DC.

    .EXAMPLE
        Get-ADDomainController -Filter * | Get-ADCriticalEvents -Hours 12

        Uses pipeline input to scan all DCs for events in the last 12 hours.

    .INPUTS
        System.String
        Microsoft.ActiveDirectory.Management.ADDomainController

        You can pipe computer names or ADDomainController objects to this function.

    .OUTPUTS
        AdMonitoring.HealthCheckResult

        Returns health check result objects with event log analysis and recommendations.

    .NOTES
        Author: AdMonitoring Project
        Requires: PowerShell 5.1 or later, appropriate event log permissions

        Common Event IDs and their meanings:
        - 1644: LDAP query timeout
        - 2042: Replication hasn't occurred for tombstone lifetime
        - 2087: DNS lookup failure prevented replication
        - 4013: DNS zone transfer failure
        - 5805: Secure channel authentication failed
        - 13508: DFSR replication stopped
        - 13516: DFSR journal wrap detected

        This function requires network access to domain controllers and permissions
        to read event logs remotely.

    .LINK
        https://docs.microsoft.com/windows-server/identity/ad-ds/manage/troubleshoot/troubleshooting-active-directory-replication-problems
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Function returns multiple events, plural noun is semantically correct')]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Name', 'HostName', 'DnsHostName')]
        [string[]]$ComputerName,

        [Parameter()]
        [PSCredential]$Credential,

        [Parameter()]
        [ValidateRange(1, 168)]
        [int]$Hours = 24,

        [Parameter()]
        [switch]$IncludeWarnings,

        [Parameter()]
        [ValidateRange(1, 1000)]
        [int]$MaxEvents = 100
    )

    begin {
        Write-Verbose "Starting critical event log analysis"

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

        # Define critical event IDs to monitor
        $criticalEventIds = @{
            'Directory Service' = @(
                1000,  # General AD error
                1126,  # Active Directory web services not started
                1168,  # Internal error
                1173,  # Replication access denied
                1645,  # Directory service exceeded configured resource limits
                2042,  # Replication hasn't occurred for tombstone lifetime
                2087,  # DNS lookup failure prevented replication
                2088,  # DNS lookup failure prevented replication with GC
                2089   # DNS lookup failure on replication target
            )
            'DNS Server' = @(
                408,   # DNS server list of forwarders has no valid IP addresses
                4000,  # DNS server waiting for Active Directory
                4004,  # DNS server unable to load zone from Active Directory
                4013,  # DNS zone transfer failure
                4015   # DNS server unable to read security descriptor
            )
            'DFS Replication' = @(
                2104,  # DFSR initial sync failed
                4012,  # DFSR replicated folder conflict
                5002,  # DFSR service unable to communicate
                5004,  # DFSR service unable to read configuration
                13508, # DFSR replication stopped due to error
                13509, # DFSR replication stopped
                13516  # DFSR journal wrap detected
            )
            'File Replication Service' = @(
                13508, # FRS stopped replication
                13568  # FRS detected a journal wrap
            )
            'System' = @(
                5805,  # Session setup from computer failed
                5719,  # Netlogon cannot contact domain controller
                5722,  # Session setup from computer failed (secure channel)
                5723   # Session setup to domain controller failed
            )
        }

        # Calculate start time
        $startTime = (Get-Date).AddHours(-$Hours)
        Write-Verbose "Scanning events from: $startTime"
    }

    process {
        foreach ($dc in $ComputerName) {
            Write-Verbose "Analyzing event logs on: $dc"

            $details = [PSCustomObject]@{
                ComputerName       = $dc
                ScanPeriodHours    = $Hours
                StartTime          = $startTime
                EndTime            = Get-Date
                TotalEventsFound   = 0
                CriticalEvents     = 0
                ErrorEvents        = 0
                WarningEvents      = 0
                EventsByLog        = @{}
                TopEventIds        = @()
                Error              = $null
            }

            $recommendations = [System.Collections.Generic.List[string]]::new()
            $status = 'Healthy'
            $message = "No critical events found in last $Hours hours"
            $allEvents = [System.Collections.Generic.List[PSObject]]::new()

            try {
                # Build event log filter
                $levels = if ($IncludeWarnings) { @(1, 2, 3) } else { @(1, 2) } # Critical, Error, (Warning)

                foreach ($logName in $criticalEventIds.Keys) {
                    Write-Verbose "Scanning $logName log on $dc"

                    try {
                        $filterParams = @{
                            LogName      = $logName
                            Level        = $levels
                            StartTime    = $startTime
                        }

                        # Add event IDs if we're filtering
                        if ($criticalEventIds[$logName].Count -gt 0) {
                            $filterParams['Id'] = $criticalEventIds[$logName]
                        }

                        $getEventParams = @{
                            ComputerName    = $dc
                            FilterHashtable = $filterParams
                            MaxEvents       = $MaxEvents
                            ErrorAction     = 'Stop'
                        }

                        if ($PSBoundParameters.ContainsKey('Credential')) {
                            $getEventParams['Credential'] = $Credential
                        }

                        $events = Get-WinEvent @getEventParams

                        if ($events) {
                            $logEventCount = $events.Count
                            $details.EventsByLog[$logName] = $logEventCount
                            Write-Verbose "Found $logEventCount events in $logName"

                            # Add to master list with log name
                            foreach ($eventItem in $events) {
                                $eventItem | Add-Member -NotePropertyName 'LogCategory' -NotePropertyValue $logName -Force
                                $allEvents.Add($eventItem)
                            }
                        }
                    }
                    catch [System.Exception] {
                        # If log doesn't exist or no events, that's okay
                        if ($_.Exception.Message -notmatch 'No events were found|does not exist') {
                            Write-Warning "Failed to query $logName on $dc : $_"
                        }
                    }
                }

                # Analyze collected events
                if ($allEvents.Count -gt 0) {
                    $details.TotalEventsFound = $allEvents.Count

                    # Count by level
                    $details.CriticalEvents = @($allEvents | Where-Object { $_.Level -eq 1 }).Count
                    $details.ErrorEvents = @($allEvents | Where-Object { $_.Level -eq 2 }).Count
                    $details.WarningEvents = @($allEvents | Where-Object { $_.Level -eq 3 }).Count

                    # Get top 5 event IDs
                    $details.TopEventIds = $allEvents |
                        Group-Object Id |
                        Sort-Object Count -Descending |
                        Select-Object -First 5 -Property Name, Count

                    # Determine health status
                    if ($details.CriticalEvents -gt 0) {
                        $status = 'Critical'
                        $message = "Found $($details.CriticalEvents) critical events in last $Hours hours"
                        $recommendations.Add("Review critical events immediately and address root causes")
                    }
                    elseif ($details.ErrorEvents -gt 10) {
                        $status = 'Critical'
                        $message = "Found $($details.ErrorEvents) error events in last $Hours hours"
                        $recommendations.Add("High error count indicates serious issues requiring attention")
                    }
                    elseif ($details.ErrorEvents -gt 0) {
                        $status = 'Warning'
                        $message = "Found $($details.ErrorEvents) error events in last $Hours hours"
                        $recommendations.Add("Investigate error events to prevent escalation")
                    }
                    elseif ($details.WarningEvents -gt 20) {
                        $status = 'Warning'
                        $message = "Found $($details.WarningEvents) warning events in last $Hours hours"
                        $recommendations.Add("High warning count may indicate developing issues")
                    }

                    # Event-specific recommendations
                    $eventIds = $allEvents.Id | Select-Object -Unique

                    if ($eventIds -contains 2042) {
                        $recommendations.Add("Event 2042: Replication hasn't occurred - check replication topology and connectivity")
                    }
                    if ($eventIds -contains 2087 -or $eventIds -contains 2088) {
                        $recommendations.Add("DNS lookup failure: Verify DNS configuration and forwarders")
                    }
                    if ($eventIds -contains 4013) {
                        $recommendations.Add("DNS zone transfer failure: Check DNS replication and zone settings")
                    }
                    if ($eventIds -contains 5805 -or $eventIds -contains 5719) {
                        $recommendations.Add("Secure channel/Netlogon issue: Run 'nltest /sc_reset:domain.com'")
                    }
                    if ($eventIds -contains 13508 -or $eventIds -contains 13516) {
                        $recommendations.Add("DFSR replication issue: Check 'dfsrdiag ReplicationState' and journal size")
                    }
                    if ($eventIds -contains 1645) {
                        $recommendations.Add("Resource limit exceeded: Increase LDAP policy limits if legitimate load")
                    }

                    # Add general recommendations
                    $recommendations.Add("Review full event details in Event Viewer on $dc")
                    $recommendations.Add("Correlate events with other health checks (replication, DNS, SYSVOL)")
                }
                else {
                    # No events is good
                    $recommendations.Add("Continue monitoring event logs")
                    $recommendations.Add("Review event log configuration to ensure important events are captured")
                }
            }
            catch {
                Write-Warning "Unexpected error analyzing events on $dc : $_"
                $status = 'Critical'
                $message = "Failed to analyze event logs"
                $details.Error = $_.Exception.Message
                $recommendations.Add("Verify remote event log access permissions")
                $recommendations.Add("Check Windows Remote Management service status")
                $recommendations.Add("Verify firewall rules allow event log access")
            }

            # Output result
            [PSCustomObject]@{
                PSTypeName      = 'AdMonitoring.HealthCheckResult'
                CheckName       = 'CriticalEvents'
                Category        = 'Event Log Analysis'
                Status          = $status
                Severity        = 'Medium'
                Timestamp       = Get-Date
                Target          = $dc
                Message         = $message
                Details         = $details
                Recommendations = $recommendations.ToArray()
                RawData         = $allEvents.ToArray()
            }
        }
    }

    end {
        Write-Verbose "Completed critical event log analysis"
    }
}
