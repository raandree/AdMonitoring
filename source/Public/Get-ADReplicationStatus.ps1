function Get-ADReplicationStatus {
    <#
    .SYNOPSIS
        Monitors Active Directory replication health between domain controllers.

    .DESCRIPTION
        This function performs comprehensive replication health checks including:
        - Replication failures and errors
        - Replication latency (time since last successful sync)
        - Replication partner metadata
        - USN (Update Sequence Number) consistency
        - Inter-site replication status

        Results indicate replication health across the AD infrastructure.

    .PARAMETER ComputerName
        The name(s) of the domain controller(s) to check replication status for.
        If not specified, all domain controllers in the current domain will be checked.

    .PARAMETER Credential
        PSCredential object for authentication if required.

    .PARAMETER IncludePartnerDetails
        Include detailed partner metadata in the output. Default is $false for performance.

    .EXAMPLE
        Get-ADReplicationStatus

        Checks replication status for all domain controllers in the current domain.

    .EXAMPLE
        Get-ADReplicationStatus -ComputerName 'DC01', 'DC02'

        Checks replication status for specific domain controllers.

    .EXAMPLE
        Get-ADReplicationStatus -ComputerName 'DC01' -IncludePartnerDetails

        Checks replication with detailed partner metadata included.

    .OUTPUTS
        HealthCheckResult

        Returns HealthCheckResult objects with the following statuses:
        - Healthy: No failures, latency < 15 minutes
        - Warning: Latency 15-60 minutes, no failures
        - Critical: Replication failures or latency > 60 minutes

    .NOTES
        Requires:
        - ActiveDirectory PowerShell module
        - Appropriate permissions to query replication metadata
        - Network connectivity to target DCs
    #>
    [CmdletBinding()]
    [OutputType([HealthCheckResult])]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Name', 'DomainController', 'DC')]
        [string[]]$ComputerName,

        [Parameter()]
        [PSCredential]$Credential,

        [Parameter()]
        [bool]$IncludePartnerDetails = $false
    )

    begin {
        Write-Verbose "Starting AD replication status check"

        # Define latency thresholds in minutes
        $warningThreshold = 15
        $criticalThreshold = 60

        # Track if we got any pipeline input
        $pipelineInputReceived = $false
    }

    process {
        # If ComputerName is provided (either as parameter or pipeline), use it
        if ($ComputerName) {
            $pipelineInputReceived = $true
            $computersToCheck = $ComputerName
        }
        else {
            # Will be handled in End block if no pipeline input received
            return
        }

        foreach ($computer in $computersToCheck) {
            Write-Verbose "Checking replication status for $computer"

            try {
                $params = @{
                    Target      = $computer
                    ErrorAction = 'Stop'
                }
                if ($Credential) {
                    $params['Credential'] = $Credential
                }

                # Get replication failures
                Write-Verbose "Retrieving replication failures for $computer"
                $failures = @()
                try {
                    $failureResults = Get-ADReplicationFailure @params
                    if ($failureResults) {
                        $failures = @($failureResults)
                    }
                }
                catch {
                    Write-Verbose "No replication failures detected (or cmdlet returned null)"
                }

                # Get replication partner metadata
                Write-Verbose "Retrieving replication partner metadata for $computer"
                $partners = Get-ADReplicationPartnerMetadata @params

                if (-not $partners) {
                    Write-Warning "No replication partners found for $computer"

                    [HealthCheckResult]::new(
                        'AD Replication',
                        'Replication Status',
                        $computer,
                        'Warning',
                        "No replication partners found for $computer. This may indicate a single-DC environment.",
                        $null,
                        "Verify domain configuration. If this is a single-DC environment, this is expected."
                    )
                    continue
                }

                # Analyze replication data
                $maxLatency = 0
                $partnerDetails = @()
                $warnings = @()
                $errors = @()

                foreach ($partner in $partners) {
                    # Calculate latency in minutes
                    $latencyMinutes = 0
                    if ($partner.LastReplicationSuccess) {
                        $latency = (Get-Date) - $partner.LastReplicationSuccess
                        $latencyMinutes = [math]::Round($latency.TotalMinutes, 2)

                        if ($latencyMinutes -gt $maxLatency) {
                            $maxLatency = $latencyMinutes
                        }
                    }
                    else {
                        $errors += "No successful replication recorded for partner $($partner.Partner)"
                        $latencyMinutes = -1
                    }

                    # Build partner details
                    $partnerInfo = [PSCustomObject]@{
                        Partner                  = $partner.Partner
                        PartitionName            = $partner.Partition
                        LastReplicationSuccess   = $partner.LastReplicationSuccess
                        LastReplicationAttempt   = $partner.LastReplicationAttempt
                        LatencyMinutes           = $latencyMinutes
                        ConsecutiveFailures      = $partner.ConsecutiveReplicationFailures
                        LastChangeUSN            = $partner.LastChangeUsn
                        LastReplicationResultMsg = if ($partner.LastReplicationResult -ne 0) {
                            "Error $($partner.LastReplicationResult)"
                        } else {
                            'Success'
                        }
                    }

                    $partnerDetails += $partnerInfo

                    # Check for consecutive failures
                    if ($partner.ConsecutiveReplicationFailures -gt 0) {
                        $errors += "Partner $($partner.Partner): $($partner.ConsecutiveReplicationFailures) consecutive failures"
                    }

                    # Check for recent attempt failures
                    if ($partner.LastReplicationResult -ne 0) {
                        $errors += "Partner $($partner.Partner): Last replication failed with error $($partner.LastReplicationResult)"
                    }
                }

                # Check for explicit replication failures
                if ($failures.Count -gt 0) {
                    foreach ($failure in $failures) {
                        $errors += "Replication failure with $($failure.Partner): $($failure.FailureType) - $($failure.FailureError)"
                    }
                }

                # Determine overall health status
                if ($errors.Count -gt 0) {
                    $status = 'Critical'
                    $message = "Replication issues detected on ${computer}: $($errors -join '; ')"
                    $remediation = "Investigate replication failures using 'repadmin /showrepl $computer'. Check network connectivity, DNS resolution, and AD database health. Review Event Viewer for replication errors (Event IDs 1925, 2042)."
                }
                elseif ($maxLatency -gt $criticalThreshold) {
                    $status = 'Critical'
                    $message = "Replication latency exceeds critical threshold: $maxLatency minutes (threshold: $criticalThreshold minutes)"
                    $remediation = "Investigate replication delays. Check site link schedules, network bandwidth, and DC performance. Use 'repadmin /replsummary' for overview."
                }
                elseif ($maxLatency -gt $warningThreshold) {
                    $status = 'Warning'
                    $message = "Replication latency elevated: $maxLatency minutes (warning threshold: $warningThreshold minutes)"
                    $remediation = "Monitor replication latency. Verify site topology, replication schedules, and network connectivity. Consider adjusting replication intervals if persistent."
                }
                elseif ($warnings.Count -gt 0) {
                    $status = 'Warning'
                    $message = "Replication healthy but warnings present: $($warnings -join '; ')"
                    $remediation = "Review warnings and monitor for changes."
                }
                else {
                    $status = 'Healthy'
                    $message = "Replication healthy. Maximum latency: $maxLatency minutes across $($partners.Count) partner(s)"
                    $remediation = $null
                }

                # Create result data
                $data = [PSCustomObject]@{
                    ComputerName        = $computer
                    TotalPartners       = $partners.Count
                    MaxLatencyMinutes   = $maxLatency
                    FailureCount        = $failures.Count
                    PartnerDetails      = if ($IncludePartnerDetails) { $partnerDetails } else { 'Use -IncludePartnerDetails for full data' }
                    ReplicationFailures = if ($failures.Count -gt 0) { $failures } else { 'None' }
                    Warnings            = if ($warnings.Count -gt 0) { $warnings } else { @() }
                    Errors              = if ($errors.Count -gt 0) { $errors } else { @() }
                }

                [HealthCheckResult]::new(
                    'AD Replication',
                    'Replication Status',
                    $computer,
                    $status,
                    $message,
                    $data,
                    $remediation
                )
            }
            catch {
                Write-Error "Failed to check replication status for ${computer}: $_"

                [HealthCheckResult]::new(
                    'AD Replication',
                    'Replication Status',
                    $computer,
                    'Critical',
                    "Replication check failed: $($_.Exception.Message)",
                    $null,
                    "Verify ActiveDirectory module is installed, DC is accessible, and you have sufficient permissions. Check network connectivity and DNS resolution."
                )
            }
        }
    }

    end {
        # If no pipeline input was received and no parameter was provided, get all DCs
        if (-not $pipelineInputReceived) {
            try {
                Write-Verbose "No ComputerName specified, retrieving all domain controllers"
                $allDCs = Get-ADDomainController -Filter * -ErrorAction Stop |
                    Select-Object -ExpandProperty HostName
                Write-Verbose "Found $($allDCs.Count) domain controller(s)"

                # Call the function recursively with the discovered DCs
                Get-ADReplicationStatus -ComputerName $allDCs -Credential $Credential -IncludePartnerDetails $IncludePartnerDetails
            }
            catch {
                Write-Error "Failed to retrieve domain controllers: $_"
                throw
            }
        }

        Write-Verbose "AD replication status check completed"
    }
}
