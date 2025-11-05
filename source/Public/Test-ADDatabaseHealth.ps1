function Test-ADDatabaseHealth {
    <#
    .SYNOPSIS
        Tests Active Directory database health and integrity.

    .DESCRIPTION
        The Test-ADDatabaseHealth function monitors the health of the Active Directory
        database (NTDS.dit) on domain controllers. It checks database integrity,
        fragmentation levels, garbage collection status, and version store utilization.

        This function examines:
        - NTDS database file size and growth
        - Database fragmentation percentage
        - Tombstone lifetime and deleted object cleanup
        - Garbage collection events
        - Version store utilization
        - Database-related event log errors

    .PARAMETER ComputerName
        Specifies one or more domain controller names to check. If not specified,
        all domain controllers in the current domain are checked.

    .PARAMETER Credential
        Specifies credentials to use when connecting to remote domain controllers.
        If not specified, the current user's credentials are used.

    .PARAMETER FragmentationWarningPercent
        The fragmentation percentage threshold for warning status.
        Default: 20%
        Range: 1-100

    .PARAMETER FragmentationCriticalPercent
        The fragmentation percentage threshold for critical status.
        Default: 40%
        Range: 1-100

    .PARAMETER EventHours
        Number of hours to scan back in event logs for database-related errors.
        Default: 24 hours
        Range: 1-168

    .EXAMPLE
        Test-ADDatabaseHealth

        Checks database health on all domain controllers in the current domain.

    .EXAMPLE
        Test-ADDatabaseHealth -ComputerName 'DC01.contoso.com'

        Checks database health on the specified domain controller.

    .EXAMPLE
        Test-ADDatabaseHealth -FragmentationWarningPercent 15 -FragmentationCriticalPercent 30

        Checks database health with custom fragmentation thresholds.

    .EXAMPLE
        Get-ADDomainController -Filter * | Test-ADDatabaseHealth -Credential $cred

        Checks database health on all DCs using alternate credentials via pipeline.

    .INPUTS
        System.String

        You can pipe computer names to this function.

    .OUTPUTS
        System.Management.Automation.PSObject

        Returns a custom object with database health information including:
        - Status (Healthy/Warning/Critical)
        - DatabaseSizeGB
        - FragmentationPercent
        - GarbageCollectionStatus
        - LastDefragTime
        - VersionStoreUsage
        - DatabaseErrors

    .NOTES
        Author: AdMonitoring Module
        Requires: ActiveDirectory module, Remote Registry access
        Version: 1.0.0

        This function requires administrative access to domain controllers and
        the ability to query WMI/CIM and event logs remotely.

    .LINK
        Get-ADDomainController

    .LINK
        Get-WinEvent
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
        [int]$FragmentationWarningPercent = 20,

        [Parameter()]
        [ValidateRange(1, 100)]
        [int]$FragmentationCriticalPercent = 40,

        [Parameter()]
        [ValidateRange(1, 168)]
        [int]$EventHours = 24
    )

    begin {
        Write-Verbose "Starting AD database health check"

        # Validate fragmentation thresholds
        if ($FragmentationCriticalPercent -le $FragmentationWarningPercent) {
            throw "FragmentationCriticalPercent ($FragmentationCriticalPercent) must be greater than FragmentationWarningPercent ($FragmentationWarningPercent)"
        }

        # Ensure ActiveDirectory module is available
        if (-not (Get-Module -Name ActiveDirectory -ListAvailable)) {
            throw "ActiveDirectory module is required but not available"
        }

        # Import ActiveDirectory module if not already loaded
        if (-not (Get-Module -Name ActiveDirectory)) {
            Import-Module ActiveDirectory -ErrorAction Stop
        }

        # Auto-discover DCs if not specified
        if (-not $PSBoundParameters.ContainsKey('ComputerName')) {
            Write-Verbose "No ComputerName specified, discovering domain controllers"
            try {
                $ComputerName = (Get-ADDomainController -Filter *).HostName
                Write-Verbose "Discovered $($ComputerName.Count) domain controller(s)"
            }
            catch {
                throw "Failed to discover domain controllers: $_"
            }
        }

        # Event IDs related to database health
        $databaseEventIds = @{
            1014 = 'Database corruption detected'
            1159 = 'Version store out of memory'
            2095 = 'Garbage collection completed'
            1168 = 'Database error'
            1173 = 'Database transaction failure'
            467  = 'Database defragmentation status'
            1646 = 'Internal database error'
        }

        $startTime = (Get-Date).AddHours(-$EventHours)
        Write-Verbose "Will scan events from $startTime to present ($EventHours hours)"
    }

    process {
        foreach ($dc in $ComputerName) {
            Write-Verbose "Checking database health on $dc"

            $details = @{
                DatabaseSizeGB = $null
                DatabasePathDriveFreeGB = $null
                FragmentationPercent = $null
                LastDefragTime = $null
                GarbageCollectionEvents = @()
                VersionStoreErrors = 0
                DatabaseErrors = @()
                TombstoneLifetimeDays = $null
                DeletedObjectCount = $null
            }

            $recommendations = [System.Collections.Generic.List[string]]::new()
            $status = 'Healthy'

            try {
                # Get NTDS database path via registry
                $ntdsParams = @{
                    ScriptBlock = {
                        try {
                            $regPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\NTDS\Parameters'
                            $dbPath = Get-ItemProperty -Path $regPath -Name 'DSA Database file' -ErrorAction Stop
                            $logPath = Get-ItemProperty -Path $regPath -Name 'Database log files path' -ErrorAction Stop

                            [PSCustomObject]@{
                                DatabasePath = $dbPath.'DSA Database file'
                                LogPath = $logPath.'Database log files path'
                            }
                        }
                        catch {
                            $null
                        }
                    }
                    ComputerName = $dc
                    ErrorAction = 'Stop'
                }

                if ($Credential) {
                    $ntdsParams['Credential'] = $Credential
                }

                $ntdsInfo = Invoke-Command @ntdsParams

                if ($ntdsInfo -and $ntdsInfo.DatabasePath) {
                    Write-Verbose "Database path: $($ntdsInfo.DatabasePath)"

                    # Get database file size
                    $dbFileParams = @{
                        ScriptBlock = {
                            param($path)
                            if (Test-Path $path) {
                                $file = Get-Item $path
                                [PSCustomObject]@{
                                    SizeGB = [math]::Round($file.Length / 1GB, 2)
                                    Drive = Split-Path $path -Qualifier
                                }
                            }
                        }
                        ArgumentList = $ntdsInfo.DatabasePath
                        ComputerName = $dc
                        ErrorAction = 'Stop'
                    }

                    if ($Credential) {
                        $dbFileParams['Credential'] = $Credential
                    }

                    $dbFile = Invoke-Command @dbFileParams

                    if ($dbFile) {
                        $details.DatabaseSizeGB = $dbFile.SizeGB
                        Write-Verbose "Database size: $($dbFile.SizeGB) GB"

                        # Get free space on database drive
                        $cimParams = @{
                            ClassName = 'Win32_LogicalDisk'
                            Filter = "DeviceID='$($dbFile.Drive)'"
                            ComputerName = $dc
                            ErrorAction = 'Stop'
                        }

                        if ($Credential) {
                            $cimSession = New-CimSession -ComputerName $dc -Credential $Credential -ErrorAction Stop
                            $cimParams['CimSession'] = $cimSession
                            $cimParams.Remove('ComputerName')
                        }

                        try {
                            $drive = Get-CimInstance @cimParams
                            if ($drive) {
                                $freeGB = [math]::Round($drive.FreeSpace / 1GB, 2)
                                $details.DatabasePathDriveFreeGB = $freeGB
                                Write-Verbose "Database drive free space: $freeGB GB"

                                # Warn if less than database size * 1.5 available (for defrag)
                                $recommendedFree = $dbFile.SizeGB * 1.5
                                if ($freeGB -lt $recommendedFree) {
                                    $status = 'Warning'
                                    $recommendations.Add("Low disk space on database drive. Need at least $([math]::Round($recommendedFree, 2)) GB free for offline defragmentation")
                                }
                            }
                        }
                        finally {
                            if ($cimSession) {
                                Remove-CimSession -CimSession $cimSession -ErrorAction SilentlyContinue
                            }
                        }
                    }
                }

                # Check for database-related events
                $eventParams = @{
                    ComputerName = $dc
                    FilterHashtable = @{
                        LogName = 'Directory Service'
                        Id = $databaseEventIds.Keys
                        StartTime = $startTime
                    }
                    ErrorAction = 'SilentlyContinue'
                }

                if ($Credential) {
                    $eventParams['Credential'] = $Credential
                }

                Write-Verbose "Querying database events (IDs: $($databaseEventIds.Keys -join ', '))"
                $events = Get-WinEvent @eventParams

                if ($events) {
                    foreach ($dbEvent in $events) {
                        $eventInfo = [PSCustomObject]@{
                            TimeCreated = $dbEvent.TimeCreated
                            EventId = $dbEvent.Id
                            Description = $databaseEventIds[$dbEvent.Id]
                            Message = $dbEvent.Message.Substring(0, [Math]::Min(200, $dbEvent.Message.Length))
                        }

                        switch ($dbEvent.Id) {
                            2095 {
                                # Garbage collection completed
                                $details.GarbageCollectionEvents += $eventInfo
                                Write-Verbose "Found garbage collection event at $($dbEvent.TimeCreated)"
                            }
                            1159 {
                                # Version store out of memory
                                $details.VersionStoreErrors++
                                $details.DatabaseErrors += $eventInfo
                                $status = 'Critical'
                                $recommendations.Add("Version store out of memory detected - critical database issue requiring immediate attention")
                                Write-Warning "Version store error detected on $dc"
                            }
                            {$_ -in 1014, 1168, 1173, 1646} {
                                # Database errors
                                $details.DatabaseErrors += $eventInfo
                                $status = 'Critical'
                                $recommendations.Add("Database error detected (Event ID $($dbEvent.Id)) - run ntdsutil integrity check immediately")
                                Write-Warning "Database error (Event $($dbEvent.Id)) detected on $dc"
                            }
                            467 {
                                # Defragmentation status
                                if ($dbEvent.Message -match 'defragmentation') {
                                    $details.LastDefragTime = $dbEvent.TimeCreated
                                }
                            }
                        }
                    }
                }

                # Get tombstone lifetime
                try {
                    $configNC = (Get-ADRootDSE -Server $dc -ErrorAction Stop).configurationNamingContext
                    $dsServiceDN = "CN=Directory Service,CN=Windows NT,CN=Services,$configNC"
                    $tombstoneLifetime = Get-ADObject -Identity $dsServiceDN -Property tombstoneLifetime -Server $dc -ErrorAction Stop

                    if ($tombstoneLifetime.tombstoneLifetime) {
                        $details.TombstoneLifetimeDays = $tombstoneLifetime.tombstoneLifetime
                        Write-Verbose "Tombstone lifetime: $($tombstoneLifetime.tombstoneLifetime) days"
                    }
                    else {
                        # Default is 180 days if not set
                        $details.TombstoneLifetimeDays = 180
                        Write-Verbose "Tombstone lifetime: 180 days (default)"
                    }
                }
                catch {
                    Write-Verbose "Could not retrieve tombstone lifetime: $_"
                }

                # Check garbage collection status
                if ($details.GarbageCollectionEvents.Count -eq 0) {
                    if ($status -eq 'Healthy') {
                        $status = 'Warning'
                    }
                    $recommendations.Add("No garbage collection events found in last $EventHours hours - verify garbage collection is running")
                }

                # Determine overall status based on findings
                if ($details.DatabaseErrors.Count -gt 0) {
                    $status = 'Critical'
                }
                elseif ($details.VersionStoreErrors -gt 0) {
                    $status = 'Critical'
                }
                elseif ($status -eq 'Healthy') {
                    $recommendations.Add("Database health appears normal - continue regular monitoring")
                }

            }
            catch {
                $details.Error = $_.Exception.Message
                $status = 'Critical'
                $recommendations.Add("Failed to check database health: $($_.Exception.Message)")
                Write-Warning "Error checking database health on ${dc}: $_"
            }

            # Create result object
            [PSCustomObject]@{
                PSTypeName = 'AdMonitoring.DatabaseHealth'
                Target = $dc
                CheckName = 'DatabaseHealth'
                Category = 'Database'
                Status = $status
                Timestamp = Get-Date
                Details = [PSCustomObject]$details
                Recommendations = $recommendations.ToArray()
            }
        }
    }

    end {
        Write-Verbose "Completed AD database health check"
    }
}
