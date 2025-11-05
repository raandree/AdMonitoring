function Test-ADSecurityHealth {
    <#
    .SYNOPSIS
        Tests Active Directory security and authentication health.

    .DESCRIPTION
        The Test-ADSecurityHealth function monitors authentication health and security posture
        on domain controllers. This includes Kerberos functionality, secure channel status,
        trust relationships, and authentication patterns.

        This function checks:
        - Secure channel status (domain member trust)
        - Trust relationships health (if multi-domain)
        - Account lockout events (excessive lockouts)
        - Failed authentication attempts (potential attacks)
        - Kerberos service ticket requests
        - NTLM authentication usage

        Security issues can indicate attacks, misconfigurations, or trust problems that
        affect authentication and access control.

    .PARAMETER ComputerName
        Specifies one or more domain controller names to check. If not specified,
        all domain controllers in the current domain are discovered and checked.

        Accepts pipeline input and aliases: Name, HostName, DnsHostName.

    .PARAMETER Credential
        Specifies credentials to use when connecting to domain controllers.
        If not specified, current user credentials are used.

    .PARAMETER Hours
        Number of hours to scan for security events in the event logs.
        Default is 24 hours. Valid range: 1-168 hours (1 week).

    .PARAMETER LockoutThreshold
        Number of account lockout events that triggers a warning status.
        Default is 10 lockouts. Valid range: 1-100.

    .PARAMETER FailedAuthThreshold
        Number of failed authentication events that triggers a warning status.
        Default is 50 failed attempts. Valid range: 1-1000.

    .EXAMPLE
        Test-ADSecurityHealth

        Checks all domain controllers for security health using default thresholds
        (24 hours, 10 lockouts, 50 failed auths).

    .EXAMPLE
        Test-ADSecurityHealth -ComputerName 'DC01', 'DC02' -Hours 48

        Checks specific domain controllers with a 48-hour event scan window.

    .EXAMPLE
        Test-ADSecurityHealth -LockoutThreshold 5 -FailedAuthThreshold 25

        Uses stricter thresholds for lockout and failed authentication detection.

    .EXAMPLE
        Get-ADDomainController -Filter * | Test-ADSecurityHealth

        Uses pipeline input to check all domain controllers for security health.

    .INPUTS
        System.String
        Microsoft.ActiveDirectory.Management.ADDomainController

        You can pipe computer names or ADDomainController objects to this function.

    .OUTPUTS
        AdMonitoring.HealthCheckResult

        Returns health check result objects with security analysis and recommendations.

    .NOTES
        Author: AdMonitoring Project
        Requires: PowerShell 5.1 or later, ActiveDirectory module

        Security monitoring is critical for:
        - Detecting authentication attacks (brute force, password spray)
        - Identifying trust relationship issues
        - Monitoring for account lockouts
        - Validating secure channel status
        - Tracking authentication patterns

        This function requires appropriate permissions to query security event logs.

    .LINK
        https://docs.microsoft.com/windows-server/identity/ad-ds/plan/security-best-practices/best-practices-for-securing-active-directory
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
        [ValidateRange(1, 168)]
        [int]$Hours = 24,

        [Parameter()]
        [ValidateRange(1, 100)]
        [int]$LockoutThreshold = 10,

        [Parameter()]
        [ValidateRange(1, 1000)]
        [int]$FailedAuthThreshold = 50
    )

    begin {
        Write-Verbose "Starting security health check"

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

        # Calculate start time for event log scan
        $startTime = (Get-Date).AddHours(-$Hours)
        Write-Verbose "Scanning events from: $startTime (last $Hours hours)"
        Write-Verbose "Thresholds: Lockouts=$LockoutThreshold, Failed Auth=$FailedAuthThreshold"
    }

    process {
        foreach ($dc in $ComputerName) {
            Write-Verbose "Analyzing security health on: $dc"

            $details = [PSCustomObject]@{
                ComputerName           = $dc
                SecureChannelStatus    = 'Unknown'
                TrustRelationships     = @()
                TrustsHealthy          = $true
                AccountLockouts        = 0
                FailedAuthentications  = 0
                KerberosTicketRequests = 0
                NTLMAuthentications    = 0
                Top5LockedAccounts     = @()
                Top5FailedAuthSources  = @()
                SecurityEventSummary   = @()
                Error                  = $null
            }

            $recommendations = [System.Collections.Generic.List[string]]::new()
            $status = 'Healthy'
            $message = "Security health is good"

            try {
                Write-Verbose "Testing secure channel on: $dc"

                # Test secure channel status
                try {
                    $invokeParams = @{
                        ComputerName = $dc
                        ScriptBlock  = {
                            Test-ComputerSecureChannel -ErrorAction Stop
                        }
                        ErrorAction  = 'Stop'
                    }

                    if ($PSBoundParameters.ContainsKey('Credential')) {
                        $invokeParams['Credential'] = $Credential
                    }

                    $secureChannelResult = Invoke-Command @invokeParams

                    if ($secureChannelResult) {
                        $details.SecureChannelStatus = 'Healthy'
                        Write-Verbose "Secure channel is healthy on $dc"
                    }
                    else {
                        $details.SecureChannelStatus = 'Broken'
                        $status = 'Critical'
                        $message = "Secure channel is broken"
                        Write-Warning "Secure channel is broken on $dc"
                        $recommendations.Add("URGENT: Reset secure channel: nltest /sc_reset:$env:USERDNSDOMAIN")
                        $recommendations.Add("Rejoin domain if reset fails")
                    }
                }
                catch {
                    $details.SecureChannelStatus = 'Error'
                    Write-Warning "Failed to test secure channel on ${dc}: $_"
                    if (-not $details.Error) {
                        $details.Error = "Secure channel test failed: $($_.Exception.Message)"
                    }
                    if ($status -eq 'Healthy') {
                        $status = 'Warning'
                    }
                    $recommendations.Add("Verify network connectivity to $dc")
                    $recommendations.Add("Check Windows Remote Management service")
                }

                # Check trust relationships (if multi-domain)
                Write-Verbose "Checking trust relationships"
                try {
                    $trusts = Get-ADTrust -Filter * -Server $dc -ErrorAction Stop

                    if ($trusts) {
                        $details.TrustRelationships = @($trusts | ForEach-Object {
                            [PSCustomObject]@{
                                Name      = $_.Name
                                Direction = $_.Direction
                                TrustType = $_.TrustType
                                Healthy   = ($_.TrustAttributes -band 0x00000020) -eq 0  # Not disabled
                            }
                        })

                        $unhealthyTrusts = $details.TrustRelationships | Where-Object { -not $_.Healthy }

                        if ($unhealthyTrusts) {
                            $details.TrustsHealthy = $false
                            $status = 'Critical'
                            $message = "One or more trust relationships are broken"
                            Write-Warning "Unhealthy trusts detected on $dc"
                            foreach ($trust in $unhealthyTrusts) {
                                $recommendations.Add("Investigate trust relationship with: $($trust.Name)")
                            }
                            $recommendations.Add("Run: netdom trust /Domain:$env:USERDNSDOMAIN /verify")
                        }
                        else {
                            Write-Verbose "All trust relationships are healthy"
                        }
                    }
                    else {
                        Write-Verbose "No trust relationships found (single domain forest)"
                    }
                }
                catch {
                    Write-Warning "Failed to check trust relationships on ${dc}: $_"
                    if (-not $details.Error) {
                        $details.Error = "Trust check failed: $($_.Exception.Message)"
                    }
                }

                # Scan security event logs
                Write-Verbose "Scanning security event logs on $dc"
                try {
                    # Base parameters for event queries
                    $baseEventParams = @{
                        ComputerName  = $dc
                        ErrorAction   = 'Stop'
                        WarningAction = 'SilentlyContinue'
                    }

                    if ($PSBoundParameters.ContainsKey('Credential')) {
                        $baseEventParams['Credential'] = $Credential
                    }

                    # Event ID 4740: Account lockout
                    Write-Verbose "Querying account lockout events (ID 4740)"
                    $lockoutParams = $baseEventParams.Clone()
                    $lockoutParams['FilterHashtable'] = @{
                        LogName   = 'Security'
                        Id        = 4740
                        StartTime = $startTime
                    }
                    $lockoutEvents = @(Get-WinEvent @lockoutParams)
                    $details.AccountLockouts = $lockoutEvents.Count

                    if ($lockoutEvents.Count -gt 0) {
                        # Get top 5 locked accounts
                        $lockedAccounts = $lockoutEvents | ForEach-Object {
                            $xml = [xml]$_.ToXml()
                            $xml.Event.EventData.Data | Where-Object { $_.Name -eq 'TargetUserName' } | Select-Object -ExpandProperty '#text'
                        } | Group-Object | Sort-Object Count -Descending | Select-Object -First 5

                        $details.Top5LockedAccounts = @($lockedAccounts | ForEach-Object {
                            [PSCustomObject]@{
                                Account = $_.Name
                                Count   = $_.Count
                            }
                        })

                        Write-Verbose "Found $($lockoutEvents.Count) account lockout events"

                        if ($lockoutEvents.Count -ge $LockoutThreshold) {
                            if ($status -eq 'Healthy') {
                                $status = 'Warning'
                                $message = "Excessive account lockouts detected"
                            }
                            $recommendations.Add("Investigate $($lockoutEvents.Count) account lockout events")
                            $recommendations.Add("Review lockout policy and user behavior")
                            $recommendations.Add("Check for password spray or brute force attacks")
                        }
                    }

                    # Event ID 4625: Failed authentication attempts
                    Write-Verbose "Querying failed authentication events (ID 4625)"
                    $failedAuthParams = $baseEventParams.Clone()
                    $failedAuthParams['FilterHashtable'] = @{
                        LogName   = 'Security'
                        Id        = 4625
                        StartTime = $startTime
                    }
                    $failedAuthEvents = @(Get-WinEvent @failedAuthParams)
                    $details.FailedAuthentications = $failedAuthEvents.Count

                    if ($failedAuthEvents.Count -gt 0) {
                        # Get top 5 failed auth sources
                        $failedAuthSources = $failedAuthEvents | ForEach-Object {
                            $xml = [xml]$_.ToXml()
                            $xml.Event.EventData.Data | Where-Object { $_.Name -eq 'IpAddress' } | Select-Object -ExpandProperty '#text'
                        } | Where-Object { $_ -and $_ -ne '-' } | Group-Object | Sort-Object Count -Descending | Select-Object -First 5

                        $details.Top5FailedAuthSources = @($failedAuthSources | ForEach-Object {
                            [PSCustomObject]@{
                                IPAddress = $_.Name
                                Count     = $_.Count
                            }
                        })

                        Write-Verbose "Found $($failedAuthEvents.Count) failed authentication events"

                        if ($failedAuthEvents.Count -ge $FailedAuthThreshold) {
                            if ($status -eq 'Healthy') {
                                $status = 'Warning'
                                $message = "Excessive failed authentication attempts"
                            }
                            $recommendations.Add("Investigate $($failedAuthEvents.Count) failed authentication attempts")
                            $recommendations.Add("Check for brute force or password spray attacks")
                            $recommendations.Add("Review IP addresses and user accounts involved")
                        }
                    }

                    # Event ID 4768: Kerberos TGT requested
                    Write-Verbose "Querying Kerberos ticket request events (ID 4768)"
                    $kerberosParams = $baseEventParams.Clone()
                    $kerberosParams['FilterHashtable'] = @{
                        LogName   = 'Security'
                        Id        = 4768
                        StartTime = $startTime
                    }
                    $kerberosEvents = @(Get-WinEvent @kerberosParams)
                    $details.KerberosTicketRequests = $kerberosEvents.Count
                    Write-Verbose "Found $($kerberosEvents.Count) Kerberos ticket requests"

                    # Event ID 4776: NTLM authentication
                    Write-Verbose "Querying NTLM authentication events (ID 4776)"
                    $ntlmParams = $baseEventParams.Clone()
                    $ntlmParams['FilterHashtable'] = @{
                        LogName   = 'Security'
                        Id        = 4776
                        StartTime = $startTime
                    }
                    $ntlmEvents = @(Get-WinEvent @ntlmParams)
                    $details.NTLMAuthentications = $ntlmEvents.Count
                    Write-Verbose "Found $($ntlmEvents.Count) NTLM authentication events"

                    # Check NTLM usage ratio
                    $totalAuth = $kerberosEvents.Count + $ntlmEvents.Count
                    if ($totalAuth -gt 0) {
                        $ntlmPercentage = ($ntlmEvents.Count / $totalAuth) * 100

                        if ($ntlmPercentage -gt 50) {
                            if ($status -eq 'Healthy') {
                                $status = 'Warning'
                                $message = "High NTLM authentication usage"
                            }
                            $recommendations.Add("High NTLM usage detected: $([math]::Round($ntlmPercentage, 2))%")
                            $recommendations.Add("Investigate applications using NTLM instead of Kerberos")
                            $recommendations.Add("Consider NTLM audit mode to identify sources")
                        }
                    }

                    # Create event summary
                    $details.SecurityEventSummary = @(
                        [PSCustomObject]@{ EventType = 'Account Lockouts'; Count = $details.AccountLockouts }
                        [PSCustomObject]@{ EventType = 'Failed Authentications'; Count = $details.FailedAuthentications }
                        [PSCustomObject]@{ EventType = 'Kerberos Tickets'; Count = $details.KerberosTicketRequests }
                        [PSCustomObject]@{ EventType = 'NTLM Authentications'; Count = $details.NTLMAuthentications }
                    )
                }
                catch {
                    Write-Warning "Failed to scan security event logs on ${dc}: $_"
                    if (-not $details.Error) {
                        $details.Error = "Event log scan failed: $($_.Exception.Message)"
                    }
                    if ($status -eq 'Healthy') {
                        $status = 'Warning'
                        $message = "Unable to scan security event logs"
                    }
                    $recommendations.Add("Verify remote event log access permissions")
                    $recommendations.Add("Check firewall rules allow event log access")
                    $recommendations.Add("Verify Security log is enabled and accessible")
                }

                # Add general recommendations if healthy
                if ($status -eq 'Healthy') {
                    $recommendations.Add("Security health is good - continue monitoring")
                    $recommendations.Add("Review security event logs regularly")
                    $recommendations.Add("Maintain strong password policies")
                    $recommendations.Add("Enable and monitor Advanced Audit Policy")
                }
            }
            catch {
                Write-Warning "Unexpected error checking security on ${dc}: $_"
                $status = 'Critical'
                $message = "Unexpected error during security check"
                $details.Error = $_.Exception.Message
                $recommendations.Add("Review error details and event logs")
                $recommendations.Add("Verify DC accessibility and permissions")
            }

            # Output result
            [PSCustomObject]@{
                PSTypeName      = 'AdMonitoring.HealthCheckResult'
                CheckName       = 'SecurityHealth'
                Category        = 'Security'
                Status          = $status
                Severity        = 'High'
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
        Write-Verbose "Completed security health check"
    }
}
