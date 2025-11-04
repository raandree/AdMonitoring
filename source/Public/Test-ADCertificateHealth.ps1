function Test-ADCertificateHealth {
    <#
    .SYNOPSIS
        Tests Active Directory certificate health and expiration status.

    .DESCRIPTION
        The Test-ADCertificateHealth function monitors certificate health on domain controllers,
        including LDAPS certificates, Kerberos certificates, and other AD-related certificates.

        This function checks:
        - LDAPS (port 636) certificate validity
        - Certificate expiration dates
        - Certificate chain validation
        - Self-signed vs CA-issued certificates
        - Certificate purposes and usage

        Certificates nearing expiration can cause authentication failures, LDAPS outages,
        and other critical AD functionality issues.

    .PARAMETER ComputerName
        Specifies one or more domain controller names to check. If not specified,
        all domain controllers in the current domain are discovered and checked.

        Accepts pipeline input and aliases: Name, HostName, DnsHostName.

    .PARAMETER Credential
        Specifies credentials to use when connecting to domain controllers.
        If not specified, current user credentials are used.

    .PARAMETER WarningDays
        Number of days before expiration to trigger a warning status.
        Default is 30 days. Valid range: 1-365 days.

    .PARAMETER CriticalDays
        Number of days before expiration to trigger a critical status.
        Default is 7 days. Valid range: 1-180 days.

    .PARAMETER IncludeExpiredCertificates
        If specified, includes already-expired certificates in the check.
        By default, only active certificates are evaluated.

    .EXAMPLE
        Test-ADCertificateHealth

        Checks all domain controllers for certificate health using default thresholds
        (30 days warning, 7 days critical).

    .EXAMPLE
        Test-ADCertificateHealth -ComputerName 'DC01', 'DC02' -WarningDays 60 -CriticalDays 14

        Checks specific domain controllers with custom expiration thresholds.

    .EXAMPLE
        Test-ADCertificateHealth -IncludeExpiredCertificates

        Includes already-expired certificates in the health check results.

    .EXAMPLE
        Get-ADDomainController -Filter * | Test-ADCertificateHealth

        Uses pipeline input to check all domain controllers for certificate health.

    .INPUTS
        System.String
        Microsoft.ActiveDirectory.Management.ADDomainController

        You can pipe computer names or ADDomainController objects to this function.

    .OUTPUTS
        AdMonitoring.HealthCheckResult

        Returns health check result objects with certificate analysis and recommendations.

    .NOTES
        Author: AdMonitoring Project
        Requires: PowerShell 5.1 or later, network access to port 636 (LDAPS)

        Certificate health is critical for:
        - LDAPS (Lightweight Directory Access Protocol over SSL)
        - Kerberos authentication
        - Smart card authentication
        - Certificate-based authentication

        This function primarily checks LDAPS certificates. Additional certificate
        checks (Kerberos, etc.) require certificate store access on DCs.

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
        [ValidateRange(1, 365)]
        [int]$WarningDays = 30,

        [Parameter()]
        [ValidateRange(1, 180)]
        [int]$CriticalDays = 7,

        [Parameter()]
        [switch]$IncludeExpiredCertificates
    )

    begin {
        Write-Verbose "Starting certificate health check"

        # Validate threshold relationship
        if ($CriticalDays -ge $WarningDays) {
            throw "CriticalDays ($CriticalDays) must be less than WarningDays ($WarningDays)"
        }

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

        Write-Verbose "Checking certificates with thresholds: Warning=$WarningDays days, Critical=$CriticalDays days"
    }

    process {
        foreach ($dc in $ComputerName) {
            Write-Verbose "Analyzing certificates on: $dc"

            $details = [PSCustomObject]@{
                ComputerName          = $dc
                LdapsPort             = 636
                LdapsCertificate      = $null
                CertificateSubject    = $null
                CertificateIssuer     = $null
                CertificateThumbprint = $null
                ExpirationDate        = $null
                DaysUntilExpiration   = $null
                IsExpired             = $false
                IsSelfSigned          = $false
                ChainStatus           = 'Unknown'
                EnhancedKeyUsage      = @()
                Error                 = $null
            }

            $recommendations = [System.Collections.Generic.List[string]]::new()
            $status = 'Healthy'
            $message = "Certificate is valid and not expiring soon"

            try {
                Write-Verbose "Testing LDAPS connectivity to ${dc}:636"

                # Test LDAPS port connectivity first
                $tcpTest = Test-NetConnection -ComputerName $dc -Port 636 -WarningAction SilentlyContinue -ErrorAction Stop

                if (-not $tcpTest.TcpTestSucceeded) {
                    Write-Warning "LDAPS port 636 is not accessible on $dc"
                    $status = 'Critical'
                    $message = "LDAPS port 636 is not accessible"
                    $details.Error = "Port 636 (LDAPS) not accessible"
                    $recommendations.Add("Verify LDAPS is enabled on $dc")
                    $recommendations.Add("Check firewall rules allow port 636")
                    $recommendations.Add("Ensure AD CS certificate is installed for LDAPS")
                }
                else {
                    Write-Verbose "LDAPS port accessible, retrieving certificate"

                    # Retrieve the LDAPS certificate
                    try {
                        $tcpClient = New-Object System.Net.Sockets.TcpClient($dc, 636)
                        $sslStream = New-Object System.Net.Security.SslStream($tcpClient.GetStream(), $false, {$true})

                        # Initiate SSL handshake to retrieve certificate
                        $sslStream.AuthenticateAsClient($dc)
                        $cert = $sslStream.RemoteCertificate

                        if ($cert) {
                            # Convert to X509Certificate2 for more properties
                            $cert2 = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($cert)

                            $details.LdapsCertificate = $cert2
                            $details.CertificateSubject = $cert2.Subject
                            $details.CertificateIssuer = $cert2.Issuer
                            $details.CertificateThumbprint = $cert2.Thumbprint
                            $details.ExpirationDate = $cert2.NotAfter

                            # Calculate days until expiration
                            $daysUntilExpiration = ($cert2.NotAfter - (Get-Date)).Days
                            $details.DaysUntilExpiration = $daysUntilExpiration
                            $details.IsExpired = $daysUntilExpiration -lt 0

                            # Check if self-signed
                            $details.IsSelfSigned = $cert2.Subject -eq $cert2.Issuer

                            # Get Enhanced Key Usage
                            foreach ($extension in $cert2.Extensions) {
                                if ($extension.Oid.FriendlyName -eq 'Enhanced Key Usage') {
                                    $eku = [System.Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension]$extension
                                    $details.EnhancedKeyUsage = $eku.EnhancedKeyUsages.FriendlyName
                                }
                            }

                            Write-Verbose "Certificate expires: $($cert2.NotAfter) ($daysUntilExpiration days)"

                            # Build certificate chain and validate
                            $chain = New-Object System.Security.Cryptography.X509Certificates.X509Chain
                            $chain.ChainPolicy.RevocationMode = [System.Security.Cryptography.X509Certificates.X509RevocationMode]::NoCheck

                            if ($chain.Build($cert2)) {
                                $details.ChainStatus = 'Valid'
                                Write-Verbose "Certificate chain is valid"
                            }
                            else {
                                $details.ChainStatus = 'Invalid'
                                Write-Warning "Certificate chain validation failed"
                                if ($status -eq 'Healthy') {
                                    $status = 'Warning'
                                }
                                $recommendations.Add("Certificate chain validation failed - verify issuing CA is trusted")
                            }

                            # Determine health status based on expiration
                            if ($details.IsExpired) {
                                $status = 'Critical'
                                $message = "Certificate expired $([Math]::Abs($daysUntilExpiration)) days ago"
                                $recommendations.Add("URGENT: Certificate is expired - LDAPS will fail")
                                $recommendations.Add("Request new certificate immediately from CA")
                                $recommendations.Add("Install new certificate and restart NTDS service")
                            }
                            elseif ($daysUntilExpiration -le $CriticalDays) {
                                $status = 'Critical'
                                $message = "Certificate expires in $daysUntilExpiration days"
                                $recommendations.Add("URGENT: Certificate expires in $daysUntilExpiration days")
                                $recommendations.Add("Request and install new certificate before expiration")
                                $recommendations.Add("Plan certificate replacement immediately")
                            }
                            elseif ($daysUntilExpiration -le $WarningDays) {
                                $status = 'Warning'
                                $message = "Certificate expires in $daysUntilExpiration days"
                                $recommendations.Add("Certificate expires in $daysUntilExpiration days - plan renewal")
                                $recommendations.Add("Request new certificate from CA")
                                $recommendations.Add("Schedule maintenance window for certificate replacement")
                            }

                            # Self-signed certificate warning
                            if ($details.IsSelfSigned) {
                                if ($status -eq 'Healthy') {
                                    $status = 'Warning'
                                }
                                $recommendations.Add("Certificate is self-signed - consider using enterprise CA")
                                $recommendations.Add("Self-signed certificates don't auto-renew")
                            }

                            # Add general recommendations
                            if ($status -eq 'Healthy') {
                                $recommendations.Add("Certificate is healthy - monitor expiration date")
                                $recommendations.Add("Plan certificate renewal $WarningDays days before expiration")
                            }
                        }
                        else {
                            Write-Warning "Failed to retrieve certificate from $dc"
                            $status = 'Critical'
                            $message = "Could not retrieve LDAPS certificate"
                            $details.Error = "Failed to retrieve certificate from SSL stream"
                            $recommendations.Add("Verify LDAPS certificate is installed on $dc")
                            $recommendations.Add("Check certificate store: Cert:\LocalMachine\My")
                        }

                        # Cleanup
                        $sslStream.Close()
                        $tcpClient.Close()
                    }
                    catch {
                        Write-Warning "Error retrieving certificate from ${dc}: $_"
                        $status = 'Critical'
                        $message = "Failed to retrieve LDAPS certificate"
                        $details.Error = $_.Exception.Message
                        $recommendations.Add("Verify LDAPS is properly configured on $dc")
                        $recommendations.Add("Check if certificate exists in machine certificate store")
                        $recommendations.Add("Verify certificate has Server Authentication EKU")
                    }
                }
            }
            catch {
                Write-Warning "Unexpected error checking certificates on ${dc}: $_"
                $status = 'Critical'
                $message = "Failed to check certificate health"
                $details.Error = $_.Exception.Message
                $recommendations.Add("Verify network connectivity to $dc")
                $recommendations.Add("Check firewall rules allow port 636")
                $recommendations.Add("Verify LDAPS is enabled on domain controller")
            }

            # Output result
            [PSCustomObject]@{
                PSTypeName      = 'AdMonitoring.HealthCheckResult'
                CheckName       = 'CertificateHealth'
                Category        = 'Security'
                Status          = $status
                Severity        = 'High'
                Timestamp       = Get-Date
                Target          = $dc
                Message         = $message
                Details         = $details
                Recommendations = $recommendations.ToArray()
                RawData         = $details.LdapsCertificate
            }
        }
    }

    end {
        Write-Verbose "Completed certificate health check"
    }
}
