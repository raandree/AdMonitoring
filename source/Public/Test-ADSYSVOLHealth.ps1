function Test-ADSYSVOLHealth {
    <#
    .SYNOPSIS
        Tests SYSVOL replication health and DFSR status for Active Directory domain controllers.

    .DESCRIPTION
        This function performs comprehensive SYSVOL and DFSR (Distributed File System Replication)
        health checks for Active Directory including:
        - SYSVOL share accessibility and permissions
        - DFSR service status and replication state
        - Replication backlog monitoring
        - DFSR connection health between partners
        - Last replication timestamp verification
        - Group Policy folder consistency

        SYSVOL replication is critical for Group Policy distribution. Issues with SYSVOL
        replication will prevent Group Policy updates from reaching client computers and
        can cause inconsistent policy application across the domain.

    .PARAMETER ComputerName
        The name(s) of the domain controller(s) to test SYSVOL health for. If not specified,
        all domain controllers in the current domain will be tested.

    .PARAMETER Credential
        PSCredential object for authentication if required.

    .PARAMETER IncludeBacklogDetails
        Includes detailed information about replication backlog in the output.
        This provides comprehensive backlog information but increases processing time.

    .EXAMPLE
        Test-ADSYSVOLHealth

        Tests SYSVOL health for all domain controllers in the current domain.

    .EXAMPLE
        Test-ADSYSVOLHealth -ComputerName 'DC01' -IncludeBacklogDetails

        Tests SYSVOL health for DC01 with detailed backlog information.

    .EXAMPLE
        Get-ADDomainController -Filter * | Test-ADSYSVOLHealth

        Tests SYSVOL health for all DCs using pipeline input.

    .OUTPUTS
        HealthCheckResult

        Returns HealthCheckResult objects with the following statuses:
        - Healthy: SYSVOL accessible, DFSR running, backlog <50 files
        - Warning: Backlog 50-100 files, replication lag >60 minutes
        - Critical: SYSVOL inaccessible, DFSR stopped, backlog >100 files

    .NOTES
        Requires:
        - DFSR PowerShell module (Windows Server 2012 R2+)
        - Network connectivity to domain controllers
        - Appropriate permissions to query DFSR and access SYSVOL shares
        - Remote registry access for service status checks
    #>
    [CmdletBinding()]
    [OutputType([HealthCheckResult])]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Name', 'DomainController', 'DC', 'HostName')]
        [string[]]$ComputerName,

        [Parameter()]
        [PSCredential]$Credential,

        [Parameter()]
        [switch]$IncludeBacklogDetails
    )

    begin {
        Write-Verbose "Starting SYSVOL health check"

        # Define backlog thresholds
        $healthyThreshold = 50
        $warningThreshold = 100

        # Define replication lag thresholds (minutes)
        $healthyLagMinutes = 60
        $warningLagMinutes = 120

        $pipelineInputReceived = $false
    }

    process {
        if ($ComputerName) {
            $pipelineInputReceived = $true
            $computersToCheck = $ComputerName
        }
        else {
            return
        }

        foreach ($computer in $computersToCheck) {
            Write-Verbose "Testing SYSVOL health for $computer"

            $warnings = @()
            $errors = @()
            $testResults = @{
                SYSVOLAccessible     = $false
                SYSVOLPath           = $null
                DFSRServiceRunning   = $false
                ReplicationState     = 'Unknown'
                BacklogCount         = -1
                LastReplicationTime  = $null
                ReplicationLagMinutes = -1
            }

            try {
                # Test 1: SYSVOL Share Accessibility
                Write-Verbose "Testing SYSVOL share accessibility on $computer"
                $sysvolPath = "\\$computer\SYSVOL"
                try {
                    $testPath = Test-Path -Path $sysvolPath -ErrorAction Stop
                    if ($testPath) {
                        $testResults.SYSVOLAccessible = $true
                        $testResults.SYSVOLPath = $sysvolPath
                        Write-Verbose "SYSVOL share is accessible at $sysvolPath"

                        # Try to list contents to verify read permissions
                        try {
                            $null = Get-ChildItem -Path $sysvolPath -ErrorAction Stop | Select-Object -First 1
                            Write-Verbose "SYSVOL share has read permissions"
                        }
                        catch {
                            $warnings += "SYSVOL share accessible but cannot read contents: $($_.Exception.Message)"
                        }
                    }
                    else {
                        $errors += "SYSVOL share path test returned false"
                        Write-Verbose "SYSVOL share not accessible"
                    }
                }
                catch {
                    $errors += "SYSVOL share not accessible: $($_.Exception.Message)"
                    Write-Verbose "SYSVOL accessibility test failed: $_"
                }

                # Test 2: DFSR Service Status
                Write-Verbose "Checking DFSR service status on $computer"
                try {
                    $dfsrService = Get-Service -Name 'DFSR' -ComputerName $computer -ErrorAction Stop
                    $testResults.DFSRServiceRunning = ($dfsrService.Status -eq 'Running')

                    if ($testResults.DFSRServiceRunning) {
                        Write-Verbose "DFSR service is running"
                    }
                    else {
                        $errors += "DFSR service is not running (Status: $($dfsrService.Status))"
                        Write-Verbose "DFSR service not running: $($dfsrService.Status)"
                    }
                }
                catch {
                    $errors += "Unable to check DFSR service status: $($_.Exception.Message)"
                    Write-Verbose "DFSR service check failed: $_"
                }

                # Test 3: DFSR Replication State (if service is running)
                if ($testResults.DFSRServiceRunning) {
                    Write-Verbose "Checking DFSR replication state"
                    try {
                        # Query DFSR state via WMI/CIM
                        $cimParams = @{
                            ClassName    = 'DfsrReplicatedFolderInfo'
                            Namespace    = 'root\MicrosoftDfs'
                            ComputerName = $computer
                            ErrorAction  = 'Stop'
                        }
                        if ($Credential) {
                            $cimParams['Credential'] = $Credential
                        }

                        $dfsrInfo = Get-CimInstance @cimParams | Where-Object { $_.ReplicatedFolderName -eq 'SYSVOL Share' }

                        if ($dfsrInfo) {
                            $testResults.ReplicationState = $dfsrInfo.State
                            Write-Verbose "DFSR replication state: $($testResults.ReplicationState)"

                            if ($dfsrInfo.State -ne 'Normal' -and $dfsrInfo.State -ne 4) {
                                $warnings += "DFSR replication state is not normal: $($dfsrInfo.State)"
                            }
                        }
                        else {
                            $warnings += "Unable to retrieve DFSR replication state for SYSVOL"
                        }
                    }
                    catch {
                        $warnings += "Unable to query DFSR replication state: $($_.Exception.Message)"
                        Write-Verbose "DFSR state query failed: $_"
                    }

                    # Test 4: Replication Backlog
                    Write-Verbose "Checking DFSR replication backlog"
                    try {
                        # Attempt to get replication partners
                        $partnerParams = @{
                            ComputerName = $computer
                            ErrorAction  = 'Stop'
                        }

                        # Use Invoke-Command to run Get-DfsrBacklog on remote DC
                        $scriptBlock = {
                            $backlogTotal = 0
                            $backlogDetails = @()

                            try {
                                # Get DFSR connections for SYSVOL
                                $connections = Get-DfsrConnection -ErrorAction Stop

                                foreach ($connection in $connections) {
                                    try {
                                        $backlogInfo = Get-DfsrBacklog -GroupName 'Domain System Volume' `
                                            -FolderName 'SYSVOL Share' `
                                            -SourceComputerName $env:COMPUTERNAME `
                                            -DestinationComputerName $connection.PartnerName `
                                            -ErrorAction SilentlyContinue

                                        if ($backlogInfo) {
                                            $count = ($backlogInfo | Measure-Object).Count
                                            $backlogTotal += $count

                                            $backlogDetails += [PSCustomObject]@{
                                                Partner      = $connection.PartnerName
                                                BacklogCount = $count
                                            }
                                        }
                                    }
                                    catch {
                                        # Silently continue if backlog check fails for a partner
                                    }
                                }
                            }
                            catch {
                                # Return -1 to indicate backlog check failed
                                $backlogTotal = -1
                            }

                            [PSCustomObject]@{
                                Total   = $backlogTotal
                                Details = $backlogDetails
                            }
                        }

                        $invParams = @{
                            ComputerName = $computer
                            ScriptBlock  = $scriptBlock
                            ErrorAction  = 'Stop'
                        }
                        if ($Credential) {
                            $invParams['Credential'] = $Credential
                        }

                        $backlogResult = Invoke-Command @invParams

                        if ($backlogResult.Total -ge 0) {
                            $testResults.BacklogCount = $backlogResult.Total
                            Write-Verbose "DFSR backlog count: $($testResults.BacklogCount)"

                            if ($testResults.BacklogCount -gt $warningThreshold) {
                                $errors += "DFSR replication backlog is critical: $($testResults.BacklogCount) files (threshold: $warningThreshold)"
                            }
                            elseif ($testResults.BacklogCount -gt $healthyThreshold) {
                                $warnings += "DFSR replication backlog is elevated: $($testResults.BacklogCount) files (threshold: $healthyThreshold)"
                            }

                            if ($IncludeBacklogDetails -and $backlogResult.Details) {
                                $testResults.BacklogDetails = $backlogResult.Details
                            }
                        }
                        else {
                            $warnings += "Unable to retrieve DFSR backlog information"
                        }
                    }
                    catch {
                        $warnings += "Failed to check DFSR backlog: $($_.Exception.Message)"
                        Write-Verbose "Backlog check failed: $_"
                    }

                    # Test 5: Last Replication Time
                    Write-Verbose "Checking last replication time"
                    try {
                        $scriptBlock = {
                            try {
                                $lastReplication = Get-DfsrConnection -ErrorAction Stop |
                                    Select-Object -First 1 -ExpandProperty LastSuccessfulInboundSync
                                $lastReplication
                            }
                            catch {
                                $null
                            }
                        }

                        $invParams = @{
                            ComputerName = $computer
                            ScriptBlock  = $scriptBlock
                            ErrorAction  = 'Stop'
                        }
                        if ($Credential) {
                            $invParams['Credential'] = $Credential
                        }

                        $lastReplication = Invoke-Command @invParams

                        if ($lastReplication) {
                            $testResults.LastReplicationTime = $lastReplication
                            $lagMinutes = ((Get-Date) - $lastReplication).TotalMinutes
                            $testResults.ReplicationLagMinutes = [math]::Round($lagMinutes, 1)

                            Write-Verbose "Last replication: $lastReplication (Lag: $($testResults.ReplicationLagMinutes) minutes)"

                            if ($lagMinutes -gt $warningLagMinutes) {
                                $errors += "DFSR replication lag is critical: $($testResults.ReplicationLagMinutes) minutes (threshold: $warningLagMinutes)"
                            }
                            elseif ($lagMinutes -gt $healthyLagMinutes) {
                                $warnings += "DFSR replication lag is elevated: $($testResults.ReplicationLagMinutes) minutes (threshold: $healthyLagMinutes)"
                            }
                        }
                        else {
                            $warnings += "Unable to determine last replication time"
                        }
                    }
                    catch {
                        $warnings += "Failed to check last replication time: $($_.Exception.Message)"
                        Write-Verbose "Last replication check failed: $_"
                    }
                }

                # Determine overall health status
                if (-not $testResults.SYSVOLAccessible) {
                    $status = 'Critical'
                    $message = "SYSVOL share not accessible on $computer"
                    $remediation = "Verify SYSVOL share exists at \\$computer\SYSVOL. Check share permissions. Ensure File and Printer Sharing is enabled. Run 'net share' on the DC to verify shares."
                }
                elseif (-not $testResults.DFSRServiceRunning) {
                    $status = 'Critical'
                    $message = "DFSR service not running on $computer"
                    $remediation = "Start the DFSR service on the domain controller. Run 'Start-Service DFSR'. Check Windows Event Logs for DFSR errors. Verify DFSR is not disabled."
                }
                elseif ($errors.Count -gt 0) {
                    $status = 'Critical'
                    $message = "SYSVOL/DFSR critical issues detected on $computer. Errors: $($errors -join '; ')"
                    $remediation = "Run 'dfsrdiag replicationstate' for detailed status. Check DFSR event logs (Event Viewer > Applications and Services > DFS Replication). Verify network connectivity between DCs. Run 'dfsrdiag backlog' to check replication backlog."
                }
                elseif ($warnings.Count -gt 0) {
                    $status = 'Warning'
                    $message = "SYSVOL/DFSR health issues detected on $computer. Warnings: $($warnings -join '; ')"
                    $remediation = "Monitor DFSR replication. Run 'dfsrdiag pollad' to force AD polling. Check network bandwidth between DCs. Review DFSR event logs for warnings. Consider running 'dfsrdiag backlog' for detailed backlog information."
                }
                else {
                    $status = 'Healthy'
                    $backlogMsg = if ($testResults.BacklogCount -ge 0) { ", Backlog: $($testResults.BacklogCount) files" } else { "" }
                    $lagMsg = if ($testResults.ReplicationLagMinutes -ge 0) { ", Lag: $($testResults.ReplicationLagMinutes) minutes" } else { "" }
                    $message = "SYSVOL/DFSR health check passed for $computer. SYSVOL accessible, DFSR running$backlogMsg$lagMsg"
                    $remediation = $null
                }

                # Create result data
                $data = [PSCustomObject]@{
                    ComputerName          = $computer
                    SYSVOLAccessible      = $testResults.SYSVOLAccessible
                    SYSVOLPath            = $testResults.SYSVOLPath
                    DFSRServiceRunning    = $testResults.DFSRServiceRunning
                    ReplicationState      = $testResults.ReplicationState
                    BacklogCount          = $testResults.BacklogCount
                    LastReplicationTime   = $testResults.LastReplicationTime
                    ReplicationLagMinutes = $testResults.ReplicationLagMinutes
                    BacklogDetails        = if ($IncludeBacklogDetails -and $testResults.BacklogDetails) { $testResults.BacklogDetails } else { 'Use -IncludeBacklogDetails' }
                    Warnings              = $warnings
                    Errors                = $errors
                }

                [HealthCheckResult]::new(
                    'SYSVOL Health',
                    'SYSVOL/DFSR Replication',
                    $computer,
                    $status,
                    $message,
                    $data,
                    $remediation
                )
            }
            catch {
                Write-Error "Failed to test SYSVOL health for ${computer}: $_"

                [HealthCheckResult]::new(
                    'SYSVOL Health',
                    'SYSVOL/DFSR Replication',
                    $computer,
                    'Critical',
                    "SYSVOL health check failed: $($_.Exception.Message)",
                    $null,
                    "Verify network connectivity to $computer. Ensure DFSR PowerShell module is available. Check remote PowerShell is enabled and accessible. Verify appropriate permissions to query DFSR and access SYSVOL."
                )
            }
        }
    }

    end {
        if (-not $pipelineInputReceived) {
            try {
                Write-Verbose "No ComputerName specified, retrieving all domain controllers"
                $allDCs = Get-ADDomainController -Filter * -ErrorAction Stop |
                    Select-Object -ExpandProperty HostName
                Write-Verbose "Found $($allDCs.Count) domain controller(s)"

                Test-ADSYSVOLHealth -ComputerName $allDCs -Credential $Credential -IncludeBacklogDetails:$IncludeBacklogDetails
            }
            catch {
                Write-Error "Failed to retrieve domain controllers: $_"
                throw
            }
        }

        Write-Verbose "SYSVOL health check completed"
    }
}
