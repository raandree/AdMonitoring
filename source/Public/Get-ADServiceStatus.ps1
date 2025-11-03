function Get-ADServiceStatus {
    <#
    .SYNOPSIS
        Retrieves the status of critical Active Directory services on domain controllers.

    .DESCRIPTION
        This function checks the status of essential Active Directory services on specified
        domain controllers. It validates that services are running and configured with
        appropriate startup types.

        The following services are checked:
        - NTDS (Active Directory Domain Services)
        - KDC (Kerberos Key Distribution Center)
        - DNS (DNS Server)
        - Netlogon (Net Logon)
        - ADWS (Active Directory Web Services)
        - DFSR (DFS Replication) or FRS (File Replication Service)

    .PARAMETER ComputerName
        The name(s) of the domain controller(s) to check. If not specified,
        all domain controllers in the current domain will be checked.

    .PARAMETER Credential
        Credentials to use for remote connection. If not specified, current user
        credentials are used.

    .EXAMPLE
        Get-ADServiceStatus

        Checks AD service status on all domain controllers in the current domain.

    .EXAMPLE
        Get-ADServiceStatus -ComputerName 'DC01', 'DC02'

        Checks AD service status on specific domain controllers.

    .EXAMPLE
        Get-ADServiceStatus -ComputerName 'DC01' -Credential (Get-Credential)

        Checks AD service status using alternate credentials.

    .OUTPUTS
        HealthCheckResult

        Returns HealthCheckResult objects with the following statuses:
        - Healthy: All required services are running with automatic startup
        - Warning: Services running but startup type is manual
        - Critical: One or more required services are stopped or disabled

    .NOTES
        Requires:
        - ActiveDirectory PowerShell module
        - Remote management enabled on target DCs
        - Appropriate permissions to query services
    #>
    [CmdletBinding()]
    [OutputType([HealthCheckResult])]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Name', 'DomainController', 'DC')]
        [string[]]$ComputerName,

        [Parameter()]
        [PSCredential]$Credential
    )

    begin {
        Write-Verbose "Starting AD service status check"

        # Define required services
        $requiredServices = @(
            'NTDS'      # Active Directory Domain Services
            'KDC'       # Kerberos Key Distribution Center
            'DNS'       # DNS Server
            'Netlogon'  # Net Logon
            'ADWS'      # Active Directory Web Services
        )

        # Optional services (check if exists, don't fail if missing)
        $optionalServices = @(
            'DFSR'      # DFS Replication
            'FRS'       # File Replication Service (legacy)
        )

        # If no computer names specified, get all DCs from current domain
        if (-not $ComputerName) {
            try {
                Write-Verbose "No ComputerName specified, retrieving all domain controllers"
                $ComputerName = Get-ADDomainController -Filter * -ErrorAction Stop |
                    Select-Object -ExpandProperty HostName
                Write-Verbose "Found $($ComputerName.Count) domain controller(s)"
            }
            catch {
                Write-Error "Failed to retrieve domain controllers: $_"
                throw
            }
        }
    }

    process {
        foreach ($computer in $ComputerName) {
            Write-Verbose "Checking services on $computer"

            try {
                if ($Credential) {
                    # Note: Get-Service doesn't support -Credential in PS 5.1
                    # Use Invoke-Command instead for credential support
                    $services = Invoke-Command -ComputerName $computer -Credential $Credential -ScriptBlock {
                        Get-Service -Name $using:requiredServices, $using:optionalServices -ErrorAction SilentlyContinue
                    } -ErrorAction Stop
                }
                else {
                    $services = Get-Service -ComputerName $computer -Name ($requiredServices + $optionalServices) -ErrorAction SilentlyContinue
                }

                # Analyze service status
                $stoppedServices = @()
                $manualServices = @()
                $healthyServices = @()

                foreach ($serviceName in $requiredServices) {
                    $service = $services | Where-Object { $_.Name -eq $serviceName }

                    if (-not $service) {
                        $stoppedServices += $serviceName
                        continue
                    }

                    if ($service.Status -ne 'Running') {
                        $stoppedServices += "$serviceName ($($service.Status))"
                    }
                    elseif ($service.StartType -notin @('Automatic', 'AutomaticDelayedStart')) {
                        $manualServices += "$serviceName ($($service.StartType))"
                    }
                    else {
                        $healthyServices += $serviceName
                    }
                }

                # Check optional services (informational only)
                $optionalServiceStatus = @{}
                foreach ($serviceName in $optionalServices) {
                    $service = $services | Where-Object { $_.Name -eq $serviceName }
                    if ($service) {
                        $optionalServiceStatus[$serviceName] = $service.Status
                    }
                }

                # Determine overall health status
                if ($stoppedServices.Count -gt 0) {
                    $status = 'Critical'
                    $message = "Critical services not running: $($stoppedServices -join ', ')"
                    $remediation = "Start the stopped services and investigate root cause. Check Event Logs for service-specific errors."
                }
                elseif ($manualServices.Count -gt 0) {
                    $status = 'Warning'
                    $message = "Services running but not set to automatic: $($manualServices -join ', ')"
                    $remediation = "Set service startup type to Automatic to ensure services start after reboot."
                }
                else {
                    $status = 'Healthy'
                    $message = "All $($healthyServices.Count) required services are running and configured correctly"
                    $remediation = $null
                }

                # Create result object
                $data = [PSCustomObject]@{
                    RequiredServices = $requiredServices
                    HealthyServices  = $healthyServices
                    StoppedServices  = $stoppedServices
                    ManualServices   = $manualServices
                    OptionalServices = $optionalServiceStatus
                }

                [HealthCheckResult]::new(
                    'Service Status',
                    'AD Service Health',
                    $computer,
                    $status,
                    $message,
                    $data,
                    $remediation
                )
            }
            catch {
                Write-Error "Failed to check services on ${computer}: $_"

                [HealthCheckResult]::new(
                    'Service Status',
                    'AD Service Health',
                    $computer,
                    'Unknown',
                    "Failed to retrieve service status: $($_.Exception.Message)",
                    $null,
                    "Verify network connectivity, WinRM configuration, and appropriate permissions."
                )
            }
        }
    }

    end {
        Write-Verbose "AD service status check completed"
    }
}
