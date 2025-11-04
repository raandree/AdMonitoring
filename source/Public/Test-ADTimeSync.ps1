function Test-ADTimeSync {
    <#
    .SYNOPSIS
        Tests time synchronization health across Active Directory domain controllers.

    .DESCRIPTION
        The Test-ADTimeSync function monitors time synchronization status on domain controllers,
        which is critical for Kerberos authentication. It verifies:
        - W32Time service status on all DCs
        - Time offset between DCs (compared to PDC Emulator)
        - NTP configuration on PDC Emulator
        - Time source configuration for all DCs
        - Time stratum levels

        Time synchronization is essential for AD operations. Kerberos authentication will fail
        if time difference exceeds 5 minutes (default maximum tolerance).

        Thresholds:
        - Healthy: Time offset < 5 seconds
        - Warning: Time offset 5-10 seconds
        - Critical: Time offset > 10 seconds or W32Time service stopped

    .PARAMETER ComputerName
        Specifies one or more domain controller names to check. If not specified, all domain
        controllers in the current domain are discovered and tested.

    .PARAMETER Credential
        Specifies credentials to use when connecting to domain controllers. If not specified,
        current user credentials are used.

    .PARAMETER HealthyThresholdSeconds
        Specifies the maximum time offset in seconds for healthy status. Default is 5 seconds.

    .PARAMETER WarningThresholdSeconds
        Specifies the maximum time offset in seconds for warning status. Default is 10 seconds.
        Time offsets exceeding this value are considered critical.

    .EXAMPLE
        Test-ADTimeSync

        Tests time synchronization on all domain controllers in the current domain using current
        user credentials.

    .EXAMPLE
        Test-ADTimeSync -ComputerName 'DC01', 'DC02'

        Tests time synchronization on specified domain controllers only.

    .EXAMPLE
        Test-ADTimeSync -HealthyThresholdSeconds 3 -WarningThresholdSeconds 8

        Tests time synchronization with custom thresholds (3 seconds healthy, 8 seconds warning).

    .EXAMPLE
        Get-ADDomainController -Filter * | Test-ADTimeSync

        Tests time synchronization using pipeline input from Get-ADDomainController.

    .INPUTS
        System.String
        Microsoft.ActiveDirectory.Management.ADDomainController

        You can pipe computer names or ADDomainController objects to this function.

    .OUTPUTS
        AdMonitoring.HealthCheckResult

        Returns health check result objects with time synchronization status and details.

    .NOTES
        Author: AdMonitoring Project
        Requires: PowerShell 5.1 or later, ActiveDirectory module

        The PDC Emulator should be configured to sync with an external NTP source.
        All other DCs should sync with the PDC Emulator (domain hierarchy).

        Common remediation steps:
        - If W32Time service is stopped: Start-Service W32Time
        - If time offset is large: w32tm /resync /force
        - If NTP configuration is wrong: w32tm /config /syncfromflags:domhier /update
        - On PDC Emulator for external NTP: w32tm /config /manualpeerlist:"time.windows.com" /syncfromflags:manual /update

    .LINK
        https://docs.microsoft.com/windows-server/networking/windows-time-service/
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
        [ValidateRange(1, 60)]
        [int]$HealthyThresholdSeconds = 5,

        [Parameter()]
        [ValidateRange(1, 300)]
        [int]$WarningThresholdSeconds = 10
    )

    begin {
        Write-Verbose "Starting time synchronization health check"

        # Validate threshold values
        if ($WarningThresholdSeconds -le $HealthyThresholdSeconds) {
            throw "WarningThresholdSeconds ($WarningThresholdSeconds) must be greater than HealthyThresholdSeconds ($HealthyThresholdSeconds)"
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

        # Get PDC Emulator for time comparison
        try {
            $pdcEmulator = (Get-ADDomain).PDCEmulator
            Write-Verbose "PDC Emulator: $pdcEmulator"
        }
        catch {
            Write-Error "Failed to identify PDC Emulator: $_"
            return
        }

        # Get PDC Emulator time as reference
        Write-Verbose "Retrieving reference time from PDC Emulator: $pdcEmulator"
        try {
            $invokeParams = @{
                ComputerName = $pdcEmulator
                ScriptBlock  = { Get-Date }
                ErrorAction  = 'Stop'
            }
            if ($PSBoundParameters.ContainsKey('Credential')) {
                $invokeParams['Credential'] = $Credential
            }

            $pdcTime = Invoke-Command @invokeParams
            Write-Verbose "PDC Emulator time: $pdcTime"
        }
        catch {
            Write-Error "Failed to retrieve time from PDC Emulator: $_"
            return
        }
    }

    process {
        foreach ($dc in $ComputerName) {
            Write-Verbose "Checking time synchronization on: $dc"

            $details = [PSCustomObject]@{
                ComputerName         = $dc
                IsPDCEmulator        = ($dc -eq $pdcEmulator)
                W32TimeServiceStatus = 'Unknown'
                W32TimeStartType     = 'Unknown'
                LocalTime            = $null
                PDCTime              = $pdcTime
                TimeOffsetSeconds    = $null
                TimeOffsetFormatted  = $null
                TimeSource           = 'Unknown'
                LastSyncTime         = $null
                LastSyncStatus       = 'Unknown'
                Stratum              = $null
                NTPServers           = @()
                Error                = $null
            }

            $recommendations = [System.Collections.Generic.List[string]]::new()
            $status = 'Healthy'
            $message = "Time synchronization is healthy"

            try {
                # Check W32Time service status
                Write-Verbose "Checking W32Time service on $dc"
                try {
                    $serviceParams = @{
                        ClassName    = 'Win32_Service'
                        Filter       = "Name='W32Time'"
                        ComputerName = $dc
                        ErrorAction  = 'Stop'
                    }
                    if ($PSBoundParameters.ContainsKey('Credential')) {
                        $serviceParams['Credential'] = $Credential
                    }

                    $service = Get-CimInstance @serviceParams

                    if ($service) {
                        $details.W32TimeServiceStatus = $service.State
                        $details.W32TimeStartType = $service.StartMode

                        if ($service.State -ne 'Running') {
                            $status = 'Critical'
                            $message = "W32Time service is not running (State: $($service.State))"
                            $recommendations.Add("Start W32Time service: Start-Service W32Time on $dc")
                        }

                        if ($service.StartMode -ne 'Auto' -and $service.StartMode -ne 'Automatic') {
                            if ($status -eq 'Healthy') {
                                $status = 'Warning'
                                $message = "W32Time service is not set to automatic startup"
                            }
                            $recommendations.Add("Set W32Time to automatic: Set-Service W32Time -StartupType Automatic on $dc")
                        }
                    }
                    else {
                        $status = 'Critical'
                        $message = "W32Time service not found"
                        $details.Error = "W32Time service not found on $dc"
                    }
                }
                catch {
                    Write-Warning "Failed to check W32Time service on $dc : $_"
                    $details.Error = "Failed to check service: $($_.Exception.Message)"
                    if ($status -eq 'Healthy') {
                        $status = 'Warning'
                        $message = "Unable to verify W32Time service status"
                    }
                }

                # Get current time and calculate offset
                if ($details.W32TimeServiceStatus -eq 'Running' -or $details.W32TimeServiceStatus -eq 'Unknown') {
                    Write-Verbose "Retrieving current time from $dc"
                    try {
                        $invokeParams = @{
                            ComputerName = $dc
                            ScriptBlock  = { Get-Date }
                            ErrorAction  = 'Stop'
                        }
                        if ($PSBoundParameters.ContainsKey('Credential')) {
                            $invokeParams['Credential'] = $Credential
                        }

                        $dcTime = Invoke-Command @invokeParams
                        $details.LocalTime = $dcTime

                        # Calculate time offset
                        $timeOffset = ($dcTime - $pdcTime).TotalSeconds
                        $details.TimeOffsetSeconds = [math]::Round($timeOffset, 2)
                        $details.TimeOffsetFormatted = "{0:N2} seconds" -f $timeOffset

                        Write-Verbose "Time offset for ${dc}: $($details.TimeOffsetFormatted)"

                        # Evaluate time offset against thresholds
                        $absoluteOffset = [math]::Abs($timeOffset)

                        if ($absoluteOffset -gt $WarningThresholdSeconds) {
                            $status = 'Critical'
                            $message = "Time offset exceeds critical threshold: $($details.TimeOffsetFormatted)"
                            $recommendations.Add("Resynchronize time immediately: w32tm /resync /force on $dc")
                            $recommendations.Add("Verify time source configuration: w32tm /query /source on $dc")
                        }
                        elseif ($absoluteOffset -gt $HealthyThresholdSeconds) {
                            if ($status -eq 'Healthy') {
                                $status = 'Warning'
                                $message = "Time offset exceeds healthy threshold: $($details.TimeOffsetFormatted)"
                                $recommendations.Add("Monitor time offset and consider resyncing: w32tm /resync on $dc")
                            }
                        }
                    }
                    catch {
                        Write-Warning "Failed to retrieve time from $dc : $_"
                        if (-not $details.Error) {
                            $details.Error = "Failed to retrieve time: $($_.Exception.Message)"
                        }
                        if ($status -eq 'Healthy') {
                            $status = 'Warning'
                            $message = "Unable to determine time offset"
                        }
                    }

                    # Get W32Time configuration
                    Write-Verbose "Retrieving W32Time configuration from $dc"
                    try {
                        $invokeParams = @{
                            ComputerName = $dc
                            ScriptBlock  = {
                                $config = [PSCustomObject]@{
                                    Source          = 'Unknown'
                                    LastSyncTime    = $null
                                    LastSyncStatus  = 'Unknown'
                                    Stratum         = $null
                                    NTPServers      = @()
                                }

                                try {
                                    # Get time source
                                    $sourceOutput = w32tm /query /source 2>&1
                                    if ($LASTEXITCODE -eq 0) {
                                        $config.Source = $sourceOutput.Trim()
                                    }

                                    # Get status including stratum and last sync
                                    $statusOutput = w32tm /query /status 2>&1
                                    if ($LASTEXITCODE -eq 0) {
                                        $statusText = $statusOutput -join "`n"

                                        # Parse stratum
                                        if ($statusText -match 'Stratum:\s*(\d+)') {
                                            $config.Stratum = [int]$matches[1]
                                        }

                                        # Parse last successful sync
                                        if ($statusText -match 'Last Successful Sync Time:\s*(.+)') {
                                            try {
                                                $config.LastSyncTime = [datetime]::Parse($matches[1].Trim())
                                            }
                                            catch {
                                                $config.LastSyncTime = $matches[1].Trim()
                                            }
                                        }
                                    }

                                    # Get NTP server configuration
                                    $ntpOutput = w32tm /query /peers 2>&1
                                    if ($LASTEXITCODE -eq 0) {
                                        $ntpText = $ntpOutput -join "`n"
                                        $peers = $ntpText -split '#Peer:' | Where-Object { $_ -match 'Peer:' }
                                        $config.NTPServers = @($peers | ForEach-Object {
                                                if ($_ -match 'Peer:\s*(.+)') {
                                                    $matches[1].Trim()
                                                }
                                            })
                                    }

                                    $config.LastSyncStatus = 'Success'
                                }
                                catch {
                                    $config.LastSyncStatus = "Error: $($_.Exception.Message)"
                                }

                                $config
                            }
                            ErrorAction  = 'Stop'
                        }
                        if ($PSBoundParameters.ContainsKey('Credential')) {
                            $invokeParams['Credential'] = $Credential
                        }

                        $w32config = Invoke-Command @invokeParams

                        $details.TimeSource = $w32config.Source
                        $details.LastSyncTime = $w32config.LastSyncTime
                        $details.LastSyncStatus = $w32config.LastSyncStatus
                        $details.Stratum = $w32config.Stratum
                        $details.NTPServers = $w32config.NTPServers

                        Write-Verbose "Time source for ${dc}: $($details.TimeSource)"
                        Write-Verbose "Stratum for ${dc}: $($details.Stratum)"

                        # Validate PDC Emulator configuration
                        if ($details.IsPDCEmulator) {
                            if ($details.TimeSource -eq 'Local CMOS Clock') {
                                if ($status -eq 'Healthy') {
                                    $status = 'Warning'
                                    $message = "PDC Emulator is using local CMOS clock instead of external NTP"
                                }
                                $recommendations.Add("Configure PDC Emulator to use external NTP: w32tm /config /manualpeerlist:`"time.windows.com`" /syncfromflags:manual /reliable:yes /update")
                                $recommendations.Add("Restart W32Time service after configuration change")
                            }
                        }
                        else {
                            # Non-PDC DCs should sync from domain hierarchy
                            if ($details.TimeSource -ne $pdcEmulator -and $details.TimeSource -notmatch 'DC|Domain Hierarchy') {
                                if ($status -eq 'Healthy') {
                                    $status = 'Warning'
                                    $message = "DC is not syncing from domain hierarchy (Expected: $pdcEmulator, Actual: $($details.TimeSource))"
                                }
                                $recommendations.Add("Configure DC to sync from domain hierarchy: w32tm /config /syncfromflags:domhier /update on $dc")
                                $recommendations.Add("Restart W32Time service: Restart-Service W32Time on $dc")
                            }
                        }
                    }
                    catch {
                        Write-Warning "Failed to retrieve W32Time configuration from $dc : $_"
                        if (-not $details.Error) {
                            $details.Error = "Failed to retrieve configuration: $($_.Exception.Message)"
                        }
                    }
                }

                # Add final recommendations if healthy
                if ($status -eq 'Healthy') {
                    $recommendations.Add("Continue monitoring time synchronization")
                    $recommendations.Add("Verify time sync status periodically: w32tm /query /status")
                }
            }
            catch {
                Write-Warning "Unexpected error checking $dc : $_"
                $status = 'Critical'
                $message = "Unexpected error during time sync check"
                $details.Error = $_.Exception.Message
                $recommendations.Add("Review error details and verify DC connectivity")
                $recommendations.Add("Check W32Time event logs on $dc")
            }

            # Output result
            [PSCustomObject]@{
                PSTypeName      = 'AdMonitoring.HealthCheckResult'
                CheckName       = 'TimeSync'
                Category        = 'Time Synchronization'
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
        Write-Verbose "Completed time synchronization health check"
    }
}
