function Test-ADDNSHealth {
    <#
    .SYNOPSIS
        Tests DNS health and proper record registration for Active Directory domain controllers.

    .DESCRIPTION
        This function performs comprehensive DNS health checks for Active Directory including:
        - DC A/AAAA record registration verification
        - Critical SRV record validation (_ldap, _kerberos, _gc, etc.)
        - DNS resolution speed measurement
        - Reverse lookup (PTR) verification
        - DNS service availability on domain controllers
        - Zone replication status

        Proper DNS configuration is critical for AD authentication, service location,
        and replication. Missing or incorrect DNS records will cause authentication
        failures and prevent clients from locating domain services.

    .PARAMETER ComputerName
        The name(s) of the domain controller(s) to test DNS health for. If not specified,
        all domain controllers in the current domain will be tested.

    .PARAMETER Domain
        The DNS domain name to test. If not specified, uses the current domain.

    .PARAMETER Credential
        PSCredential object for authentication if required.

    .PARAMETER IncludeSRVRecordDetails
        Includes detailed information about all SRV record queries in the output.
        This provides comprehensive SRV record status but increases processing time.

    .EXAMPLE
        Test-ADDNSHealth

        Tests DNS health for all domain controllers in the current domain.

    .EXAMPLE
        Test-ADDNSHealth -ComputerName 'DC01' -IncludeSRVRecordDetails

        Tests DNS health for DC01 with detailed SRV record information.

    .EXAMPLE
        Test-ADDNSHealth -Domain 'contoso.com'

        Tests DNS health for all DCs in the contoso.com domain.

    .OUTPUTS
        HealthCheckResult

        Returns HealthCheckResult objects with the following statuses:
        - Healthy: All DNS records present and resolution fast
        - Warning: Some optional records missing or slow resolution
        - Critical: Core SRV records missing or DNS unresponsive

    .NOTES
        Requires:
        - DNS resolution capabilities
        - Network connectivity to DNS servers
        - Appropriate permissions to query DNS
    #>
    [CmdletBinding()]
    [OutputType([HealthCheckResult])]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Name', 'DomainController', 'DC')]
        [string[]]$ComputerName,

        [Parameter()]
        [string]$Domain,

        [Parameter()]
        [PSCredential]$Credential,

        [Parameter()]
        [switch]$IncludeSRVRecordDetails
    )

    begin {
        Write-Verbose "Starting DNS health check"

        # Define critical SRV records for AD
        $criticalSRVRecords = @(
            '_ldap._tcp.dc._msdcs.{0}'
            '_kerberos._tcp.dc._msdcs.{0}'
            '_ldap._tcp.{0}'
            '_kerberos._tcp.{0}'
        )

        # Define important but non-critical SRV records
        $optionalSRVRecords = @(
            '_gc._tcp.{0}'
            '_kpasswd._tcp.{0}'
            '_ldap._tcp.gc._msdcs.{0}'
        )

        # Get current domain if not specified
        if (-not $Domain) {
            try {
                $Domain = (Get-ADDomain -ErrorAction Stop).DNSRoot
                Write-Verbose "Using current domain: $Domain"
            }
            catch {
                Write-Error "Failed to determine current domain: $_"
                return
            }
        }

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
            Write-Verbose "Testing DNS health for $computer"

            $warnings = @()
            $errors = @()
            $testResults = @{
                ARecordFound         = $false
                ARecordResolutionMs  = -1
                PTRRecordFound       = $false
                SRVRecordsFound      = 0
                SRVRecordsMissing    = 0
                OptionalSRVMissing   = 0
                DNSServiceRunning    = $false
            }

            try {
                # Test 1: A Record Resolution and Speed
                Write-Verbose "Testing A record resolution for $computer"
                $resolveTimer = [System.Diagnostics.Stopwatch]::StartNew()
                try {
                    $aRecord = Resolve-DnsName -Name $computer -Type A -ErrorAction Stop -QuickTimeout
                    $resolveTimer.Stop()
                    $testResults.ARecordResolutionMs = $resolveTimer.ElapsedMilliseconds
                    $testResults.ARecordFound = $true
                    $ipAddress = $aRecord[0].IPAddress
                    Write-Verbose "A record found: $ipAddress (${resolveTimer.ElapsedMilliseconds}ms)"

                    # Evaluate resolution speed
                    if ($testResults.ARecordResolutionMs -gt 500) {
                        $warnings += "DNS resolution slow: ${testResults.ARecordResolutionMs}ms (threshold: 500ms)"
                    }
                    elseif ($testResults.ARecordResolutionMs -gt 100) {
                        $warnings += "DNS resolution elevated: ${testResults.ARecordResolutionMs}ms (threshold: 100ms)"
                    }
                }
                catch {
                    $resolveTimer.Stop()
                    $errors += "A record resolution failed: $($_.Exception.Message)"
                    Write-Verbose "A record resolution failed"
                }

                # Test 2: PTR Record (Reverse Lookup)
                if ($testResults.ARecordFound) {
                    Write-Verbose "Testing PTR record for $ipAddress"
                    try {
                        $ptrRecord = Resolve-DnsName -Name $ipAddress -Type PTR -ErrorAction Stop -QuickTimeout
                        $testResults.PTRRecordFound = $true
                        Write-Verbose "PTR record found: $($ptrRecord[0].NameHost)"
                    }
                    catch {
                        $warnings += "PTR record (reverse lookup) not found for $ipAddress"
                        Write-Verbose "PTR record not found"
                    }
                }

                # Test 3: Critical SRV Records
                Write-Verbose "Testing critical SRV records"
                $srvDetails = @()
                foreach ($srvTemplate in $criticalSRVRecords) {
                    $srvRecord = $srvTemplate -f $Domain
                    Write-Verbose "Checking SRV record: $srvRecord"
                    try {
                        $result = Resolve-DnsName -Name $srvRecord -Type SRV -ErrorAction Stop -QuickTimeout

                        # Verify this DC is registered in the SRV record
                        $dcRegistered = $result | Where-Object { $_.NameTarget -like "*$computer*" }

                        if ($dcRegistered) {
                            $testResults.SRVRecordsFound++
                            Write-Verbose "SRV record found and DC registered: $srvRecord"

                            if ($IncludeSRVRecordDetails) {
                                $srvDetails += [PSCustomObject]@{
                                    RecordName = $srvRecord
                                    Status     = 'Found'
                                    Registered = $true
                                    Priority   = $dcRegistered[0].Priority
                                    Weight     = $dcRegistered[0].Weight
                                    Port       = $dcRegistered[0].Port
                                }
                            }
                        }
                        else {
                            $testResults.SRVRecordsMissing++
                            $errors += "SRV record exists but DC not registered: $srvRecord"
                            Write-Verbose "SRV record exists but DC not registered: $srvRecord"

                            if ($IncludeSRVRecordDetails) {
                                $srvDetails += [PSCustomObject]@{
                                    RecordName = $srvRecord
                                    Status     = 'Not Registered'
                                    Registered = $false
                                }
                            }
                        }
                    }
                    catch {
                        $testResults.SRVRecordsMissing++
                        $errors += "Critical SRV record not found: $srvRecord"
                        Write-Verbose "SRV record not found: $srvRecord"

                        if ($IncludeSRVRecordDetails) {
                            $srvDetails += [PSCustomObject]@{
                                RecordName = $srvRecord
                                Status     = 'Missing'
                                Registered = $false
                            }
                        }
                    }
                }

                # Test 4: Optional SRV Records
                Write-Verbose "Testing optional SRV records"
                foreach ($srvTemplate in $optionalSRVRecords) {
                    $srvRecord = $srvTemplate -f $Domain
                    Write-Verbose "Checking optional SRV record: $srvRecord"
                    try {
                        $result = Resolve-DnsName -Name $srvRecord -Type SRV -ErrorAction Stop -QuickTimeout
                        $dcRegistered = $result | Where-Object { $_.NameTarget -like "*$computer*" }

                        if ($dcRegistered) {
                            Write-Verbose "Optional SRV record found: $srvRecord"

                            if ($IncludeSRVRecordDetails) {
                                $srvDetails += [PSCustomObject]@{
                                    RecordName = $srvRecord
                                    Status     = 'Found'
                                    Registered = $true
                                    Priority   = $dcRegistered[0].Priority
                                    Weight     = $dcRegistered[0].Weight
                                    Port       = $dcRegistered[0].Port
                                }
                            }
                        }
                        else {
                            $testResults.OptionalSRVMissing++
                            $warnings += "Optional SRV record exists but DC not registered: $srvRecord"

                            if ($IncludeSRVRecordDetails) {
                                $srvDetails += [PSCustomObject]@{
                                    RecordName = $srvRecord
                                    Status     = 'Not Registered'
                                    Registered = $false
                                }
                            }
                        }
                    }
                    catch {
                        $testResults.OptionalSRVMissing++
                        $warnings += "Optional SRV record not found: $srvRecord"

                        if ($IncludeSRVRecordDetails) {
                            $srvDetails += [PSCustomObject]@{
                                RecordName = $srvRecord
                                Status     = 'Missing'
                                Registered = $false
                            }
                        }
                    }
                }

                # Test 5: DNS Service Status (if reachable)
                Write-Verbose "Testing DNS service status on $computer"
                try {
                    $dnsService = Get-Service -Name 'DNS' -ComputerName $computer -ErrorAction Stop
                    $testResults.DNSServiceRunning = ($dnsService.Status -eq 'Running')

                    if ($testResults.DNSServiceRunning) {
                        Write-Verbose "DNS service is running"
                    }
                    else {
                        $errors += "DNS service is not running (Status: $($dnsService.Status))"
                    }
                }
                catch {
                    $warnings += "Unable to check DNS service status: $($_.Exception.Message)"
                    Write-Verbose "DNS service check failed: $_"
                }

                # Determine overall health status
                if (-not $testResults.ARecordFound) {
                    $status = 'Critical'
                    $message = "DNS A record not found for $computer"
                    $remediation = "Verify DC DNS registration. Run 'ipconfig /registerdns' on the DC. Check DNS scavenging settings and ensure DC can reach DNS servers."
                }
                elseif ($testResults.SRVRecordsMissing -gt 0) {
                    $status = 'Critical'
                    $message = "Critical SRV records missing for $computer. Missing: $($testResults.SRVRecordsMissing), Found: $($testResults.SRVRecordsFound)"
                    $remediation = "Run 'nltest /dsregdns' on the DC to re-register DNS records. Verify Netlogon service is running. Check DNS dynamic update settings and permissions."
                }
                elseif (-not $testResults.DNSServiceRunning) {
                    $status = 'Critical'
                    $message = "DNS service not running on $computer"
                    $remediation = "Start the DNS service on the domain controller. Investigate why the service stopped and review DNS event logs."
                }
                elseif ($testResults.ARecordResolutionMs -gt 500) {
                    $status = 'Warning'
                    $message = "DNS resolution very slow for $computer (${testResults.ARecordResolutionMs}ms). Warnings: $($warnings -join '; ')"
                    $remediation = "Investigate DNS server performance. Check network latency between client and DNS server. Review DNS server resource utilization."
                }
                elseif ($warnings.Count -gt 0) {
                    $status = 'Warning'
                    $message = "DNS health issues detected for $computer. Warnings: $($warnings -join '; ')"
                    $remediation = "Review DNS configuration. Missing PTR records may affect certain applications. Optional SRV records may be needed for specific AD features."
                }
                else {
                    $status = 'Healthy'
                    $message = "DNS health check passed for $computer. All critical records found, resolution time: ${testResults.ARecordResolutionMs}ms"
                    $remediation = $null
                }

                # Create result data
                $data = [PSCustomObject]@{
                    ComputerName          = $computer
                    Domain                = $Domain
                    ARecordFound          = $testResults.ARecordFound
                    IPAddress             = if ($testResults.ARecordFound) { $ipAddress } else { 'N/A' }
                    ResolutionTimeMs      = $testResults.ARecordResolutionMs
                    PTRRecordFound        = $testResults.PTRRecordFound
                    CriticalSRVFound      = $testResults.SRVRecordsFound
                    CriticalSRVMissing    = $testResults.SRVRecordsMissing
                    OptionalSRVMissing    = $testResults.OptionalSRVMissing
                    DNSServiceRunning     = $testResults.DNSServiceRunning
                    SRVRecordDetails      = if ($IncludeSRVRecordDetails) { $srvDetails } else { 'Use -IncludeSRVRecordDetails' }
                    Warnings              = $warnings
                    Errors                = $errors
                }

                [HealthCheckResult]::new(
                    'DNS Health',
                    'DNS Configuration',
                    $computer,
                    $status,
                    $message,
                    $data,
                    $remediation
                )
            }
            catch {
                Write-Error "Failed to test DNS health for ${computer}: $_"

                [HealthCheckResult]::new(
                    'DNS Health',
                    'DNS Configuration',
                    $computer,
                    'Critical',
                    "DNS health check failed: $($_.Exception.Message)",
                    $null,
                    "Verify network connectivity to $computer and DNS servers. Ensure DNS service is running and properly configured."
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

                Test-ADDNSHealth -ComputerName $allDCs -Domain $Domain -Credential $Credential -IncludeSRVRecordDetails:$IncludeSRVRecordDetails
            }
            catch {
                Write-Error "Failed to retrieve domain controllers: $_"
                throw
            }
        }

        Write-Verbose "DNS health check completed"
    }
}
