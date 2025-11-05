function Test-ADDomainControllerReachability {
    <#
    .SYNOPSIS
        Tests network connectivity and availability of domain controllers.

    .DESCRIPTION
        This function performs comprehensive connectivity tests on domain controllers including:
        - Network ping (ICMP)
        - LDAP port 389 connectivity
        - Global Catalog port 3268 connectivity (if applicable)
        - DNS name resolution
        - WinRM/PowerShell remoting availability

        Results indicate whether DCs are accessible for AD operations.

    .PARAMETER ComputerName
        The name(s) of the domain controller(s) to test. If not specified,
        all domain controllers in the current domain will be tested.

    .PARAMETER IncludeGlobalCatalog
        Tests Global Catalog connectivity on port 3268. Default is $true.

    .PARAMETER IncludeWinRM
        Tests WinRM/PowerShell remoting connectivity. Default is $true.

    .PARAMETER Timeout
        Timeout in seconds for each connectivity test. Default is 5 seconds.

    .EXAMPLE
        Test-ADDomainControllerReachability

        Tests connectivity to all domain controllers in the current domain.

    .EXAMPLE
        Test-ADDomainControllerReachability -ComputerName 'DC01', 'DC02'

        Tests connectivity to specific domain controllers.

    .EXAMPLE
        Test-ADDomainControllerReachability -ComputerName 'DC01' -IncludeWinRM:$false

        Tests connectivity excluding WinRM checks.

    .OUTPUTS
        HealthCheckResult

        Returns HealthCheckResult objects with the following statuses:
        - Healthy: All connectivity tests passed
        - Warning: ICMP blocked but LDAP responsive
        - Critical: LDAP unresponsive or DNS resolution failed

    .NOTES
        Requires:
        - Network connectivity to target DCs
        - Appropriate firewall rules for LDAP (389), GC (3268), WinRM (5985/5986)
    #>
    [CmdletBinding()]
    [OutputType([HealthCheckResult])]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Name', 'DomainController', 'DC')]
        [string[]]$ComputerName,

        [Parameter()]
        [bool]$IncludeGlobalCatalog = $true,

        [Parameter()]
        [bool]$IncludeWinRM = $true,

        [Parameter()]
        [int]$Timeout = 5
    )

    begin {
        Write-Verbose "Starting DC reachability check"

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
            Write-Verbose "Testing connectivity to $computer"

            $testResults = @{
                DnsResolution = $false
                Ping          = $false
                Ldap          = $false
                GlobalCatalog = $false
                WinRM         = $false
            }

            $warnings = @()
            $errors = @()

            try {
                # Test 1: DNS Resolution
                Write-Verbose "Testing DNS resolution for $computer"
                try {
                    $resolved = Resolve-DnsName -Name $computer -ErrorAction Stop -QuickTimeout
                    $testResults.DnsResolution = $true
                    Write-Verbose "DNS resolution successful: $($resolved[0].IPAddress)"
                }
                catch {
                    $errors += "DNS resolution failed: $($_.Exception.Message)"
                    Write-Verbose "DNS resolution failed"
                }

                # Test 2: ICMP Ping
                if ($testResults.DnsResolution) {
                    Write-Verbose "Testing ICMP ping to $computer"
                    try {
                        # Note: PowerShell 5.1 doesn't have -TimeoutSeconds parameter
                        # Using -Count 2 which typically completes within a few seconds
                        $pingResult = Test-Connection -ComputerName $computer -Count 2 -Quiet -ErrorAction Stop
                        $testResults.Ping = $pingResult
                        if ($pingResult) {
                            Write-Verbose "Ping successful"
                        }
                        else {
                            $warnings += "ICMP ping failed (may be blocked by firewall)"
                        }
                    }
                    catch {
                        $warnings += "ICMP ping failed: $($_.Exception.Message)"
                        Write-Verbose "Ping failed"
                    }
                }

                # Test 3: LDAP Port 389
                if ($testResults.DnsResolution) {
                    Write-Verbose "Testing LDAP connectivity (port 389) to $computer"
                    try {
                        $ldapTest = Test-NetConnection -ComputerName $computer -Port 389 -WarningAction SilentlyContinue -ErrorAction Stop
                        $testResults.Ldap = $ldapTest.TcpTestSucceeded
                        if ($testResults.Ldap) {
                            Write-Verbose "LDAP port 389 accessible"
                        }
                        else {
                            $errors += "LDAP port 389 not accessible"
                        }
                    }
                    catch {
                        $errors += "LDAP connectivity test failed: $($_.Exception.Message)"
                        Write-Verbose "LDAP test failed"
                    }
                }

                # Test 4: Global Catalog Port 3268 (if requested)
                if ($IncludeGlobalCatalog -and $testResults.DnsResolution) {
                    Write-Verbose "Testing Global Catalog connectivity (port 3268) to $computer"
                    try {
                        $gcTest = Test-NetConnection -ComputerName $computer -Port 3268 -WarningAction SilentlyContinue -ErrorAction Stop
                        $testResults.GlobalCatalog = $gcTest.TcpTestSucceeded
                        if ($testResults.GlobalCatalog) {
                            Write-Verbose "Global Catalog port 3268 accessible"
                        }
                        else {
                            $warnings += "Global Catalog port 3268 not accessible (may not be a GC)"
                        }
                    }
                    catch {
                        $warnings += "Global Catalog test failed: $($_.Exception.Message)"
                        Write-Verbose "GC test failed"
                    }
                }

                # Test 5: WinRM (if requested)
                if ($IncludeWinRM -and $testResults.DnsResolution) {
                    Write-Verbose "Testing WinRM connectivity to $computer"
                    try {
                        $null = Test-WSMan -ComputerName $computer -ErrorAction Stop
                        $testResults.WinRM = $true
                        Write-Verbose "WinRM accessible"
                    }
                    catch {
                        $warnings += "WinRM not accessible: $($_.Exception.Message)"
                        Write-Verbose "WinRM test failed"
                    }
                }

                # Determine overall health status
                if (-not $testResults.DnsResolution) {
                    $status = 'Critical'
                    $message = "DNS resolution failed for $computer"
                    $remediation = "Verify DNS configuration and network connectivity. Ensure DC hostname is correctly registered in DNS."
                }
                elseif (-not $testResults.Ldap) {
                    $status = 'Critical'
                    $message = "LDAP port 389 not accessible on $computer. Errors: $($errors -join '; ')"
                    $remediation = "Verify DC is running, firewall allows LDAP traffic (TCP 389), and network routing is correct."
                }
                elseif ($warnings.Count -gt 0) {
                    $status = 'Warning'
                    $message = "DC reachable but some connectivity issues detected: $($warnings -join '; ')"
                    $remediation = "Review firewall rules and network configuration. ICMP and WinRM may be intentionally blocked."
                }
                else {
                    $status = 'Healthy'
                    $message = "All connectivity tests passed for $computer"
                    $remediation = $null
                }

                # Create result data
                $data = [PSCustomObject]@{
                    ComputerName      = $computer
                    DnsResolution     = $testResults.DnsResolution
                    Ping              = $testResults.Ping
                    LdapConnectivity  = $testResults.Ldap
                    GCConnectivity    = if ($IncludeGlobalCatalog) { $testResults.GlobalCatalog } else { 'Not Tested' }
                    WinRMConnectivity = if ($IncludeWinRM) { $testResults.WinRM } else { 'Not Tested' }
                    Warnings          = $warnings
                    Errors            = $errors
                }

                [HealthCheckResult]::new(
                    'DC Reachability',
                    'Network Connectivity',
                    $computer,
                    $status,
                    $message,
                    $data,
                    $remediation
                )
            }
            catch {
                Write-Error "Failed to test connectivity to ${computer}: $_"

                [HealthCheckResult]::new(
                    'DC Reachability',
                    'Network Connectivity',
                    $computer,
                    'Critical',
                    "Connectivity test failed: $($_.Exception.Message)",
                    $null,
                    "Verify network connectivity and DNS configuration. Check firewall rules and DC availability."
                )
            }
        }
    }

    end {
        # If no pipeline input was received and no parameter was provided, get all DCs
        if (-not $pipelineInputReceived) {
            try {
                Write-Verbose "No ComputerName specified, retrieving all domain controllers"
                # Wrap in @() to ensure .Count works in PowerShell 5.1
                $allDCs = @(Get-ADDomainController -Filter * -ErrorAction Stop |
                    Select-Object -ExpandProperty HostName)
                Write-Verbose "Found $($allDCs.Count) domain controller(s)"

                # Call the function recursively with the discovered DCs
                Test-ADDomainControllerReachability -ComputerName $allDCs -IncludeGlobalCatalog $IncludeGlobalCatalog -IncludeWinRM $IncludeWinRM -Timeout $Timeout
            }
            catch {
                Write-Error "Failed to retrieve domain controllers: $_"
                throw
            }
        }

        Write-Verbose "DC reachability check completed"
    }
}
