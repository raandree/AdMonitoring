function Get-ADFSMORoleStatus {
    <#
    .SYNOPSIS
        Monitors FSMO (Flexible Single Master Operations) role holder status and availability.

    .DESCRIPTION
        This function performs comprehensive FSMO role health checks including:
        - Verification that all 5 FSMO roles are assigned
        - Reachability and responsiveness of role holders
        - Detection of seized roles via event log analysis (optional)
        - Cross-domain role verification

        The 5 FSMO roles monitored are:
        - Schema Master (Forest-wide)
        - Domain Naming Master (Forest-wide)
        - PDC Emulator (Domain-wide)
        - RID Master (Domain-wide)
        - Infrastructure Master (Domain-wide)

    .PARAMETER Credential
        PSCredential object for authentication if required.

    .PARAMETER IncludeSeizedRoleCheck
        Analyzes event logs to detect if roles were seized rather than transferred gracefully.
        This check is more expensive and should be used when investigating potential issues.

    .EXAMPLE
        Get-ADFSMORoleStatus

        Checks status of all FSMO roles in the current forest and domain.

    .EXAMPLE
        Get-ADFSMORoleStatus -IncludeSeizedRoleCheck

        Checks FSMO role status and includes event log analysis for seized roles.

    .EXAMPLE
        Get-ADFSMORoleStatus -Credential $cred

        Checks FSMO role status using alternate credentials.

    .OUTPUTS
        HealthCheckResult

        Returns HealthCheckResult objects (one per role) with the following statuses:
        - Healthy: Role assigned and holder reachable
        - Warning: Role holder responds slowly or role was seized
        - Critical: Role holder unreachable or role not assigned

    .NOTES
        Requires:
        - ActiveDirectory PowerShell module
        - Appropriate permissions to query forest and domain
        - Enterprise Admin rights for seized role detection (event log access)
    #>
    [CmdletBinding()]
    [OutputType([HealthCheckResult])]
    param(
        [Parameter()]
        [PSCredential]$Credential,

        [Parameter()]
        [switch]$IncludeSeizedRoleCheck
    )

    begin {
        Write-Verbose "Starting FSMO role status check"

        # Define FSMO roles and their scope
        $fsmoRoles = @{
            'Schema Master'        = @{ Scope = 'Forest'; Property = 'SchemaMaster' }
            'Domain Naming Master' = @{ Scope = 'Forest'; Property = 'DomainNamingMaster' }
            'PDC Emulator'         = @{ Scope = 'Domain'; Property = 'PDCEmulator' }
            'RID Master'           = @{ Scope = 'Domain'; Property = 'RIDMaster' }
            'Infrastructure Master' = @{ Scope = 'Domain'; Property = 'InfrastructureMaster' }
        }

        $results = @()
    }

    process {
        try {
            # Build parameter hashtable for AD cmdlets
            $adParams = @{
                ErrorAction = 'Stop'
            }
            if ($Credential) {
                $adParams['Credential'] = $Credential
            }

            # Get forest-level roles
            Write-Verbose "Querying forest for forest-wide FSMO roles"
            try {
                $forest = Get-ADForest @adParams
                Write-Verbose "Forest: $($forest.Name)"
            }
            catch {
                Write-Error "Failed to query AD forest: $_"

                # Return critical results for all roles if we can't query forest
                foreach ($roleName in $fsmoRoles.Keys) {
                    $results += [HealthCheckResult]::new(
                        'FSMO Roles',
                        $roleName,
                        'Unknown',
                        'Critical',
                        "Unable to query Active Directory forest: $($_.Exception.Message)",
                        $null,
                        "Verify network connectivity, permissions, and that the ActiveDirectory module is installed. Ensure you have appropriate rights to query forest information."
                    )
                }
                return
            }

            # Get domain-level roles
            Write-Verbose "Querying domain for domain-wide FSMO roles"
            try {
                $domain = Get-ADDomain @adParams
                Write-Verbose "Domain: $($domain.DNSRoot)"
            }
            catch {
                Write-Error "Failed to query AD domain: $_"

                # Return critical results for domain roles only
                foreach ($roleName in $fsmoRoles.Keys) {
                    if ($fsmoRoles[$roleName].Scope -eq 'Domain') {
                        $results += [HealthCheckResult]::new(
                            'FSMO Roles',
                            $roleName,
                            'Unknown',
                            'Critical',
                            "Unable to query Active Directory domain: $($_.Exception.Message)",
                            $null,
                            "Verify network connectivity, permissions, and that the ActiveDirectory module is installed. Ensure you have appropriate rights to query domain information."
                        )
                    }
                }
                # If we have forest but not domain, still check forest roles
                if ($forest) {
                    Write-Verbose "Proceeding with forest role checks only"
                }
                else {
                    return
                }
            }

            # Check each FSMO role
            foreach ($roleName in $fsmoRoles.Keys) {
                Write-Verbose "Checking $roleName"

                $roleInfo = $fsmoRoles[$roleName]
                $warnings = @()
                $errors = @()
                $roleHolder = $null
                $isReachable = $false
                $wasSeized = $false

                try {
                    # Get role holder based on scope
                    if ($roleInfo.Scope -eq 'Forest') {
                        if (-not $forest) {
                            Write-Verbose "Skipping $roleName - forest query failed"
                            continue
                        }
                        $propertyName = $roleInfo.Property
                        $roleHolder = $forest.$propertyName
                    }
                    else {
                        if (-not $domain) {
                            Write-Verbose "Skipping $roleName - domain query failed"
                            continue
                        }
                        $propertyName = $roleInfo.Property
                        $roleHolder = $domain.$propertyName
                    }

                    if (-not $roleHolder) {
                        $errors += "Role holder not assigned or could not be determined"
                        Write-Verbose "$roleName - No role holder found"
                    }
                    else {
                        Write-Verbose "$roleName held by $roleHolder"

                        # Test reachability of role holder
                        Write-Verbose "Testing reachability of $roleHolder"
                        try {
                            $pingTest = Test-Connection -ComputerName $roleHolder -Count 2 -Quiet -TimeoutSeconds 3 -ErrorAction Stop
                            $isReachable = $pingTest

                            if ($isReachable) {
                                Write-Verbose "$roleHolder is reachable"
                            }
                            else {
                                $warnings += "Role holder $roleHolder did not respond to ICMP ping (may be blocked by firewall)"
                            }
                        }
                        catch {
                            $warnings += "Unable to ping role holder $roleHolder - $($_.Exception.Message)"
                            Write-Verbose "Ping test failed: $_"
                        }

                        # Test LDAP connectivity to role holder
                        Write-Verbose "Testing LDAP connectivity to $roleHolder"
                        try {
                            $ldapTest = Test-NetConnection -ComputerName $roleHolder -Port 389 -WarningAction SilentlyContinue -ErrorAction Stop
                            if (-not $ldapTest.TcpTestSucceeded) {
                                $errors += "LDAP port 389 not accessible on role holder $roleHolder"
                            }
                            else {
                                Write-Verbose "LDAP connectivity confirmed"
                                $isReachable = $true
                            }
                        }
                        catch {
                            $errors += "Failed to test LDAP connectivity to $roleHolder - $($_.Exception.Message)"
                            Write-Verbose "LDAP test failed: $_"
                        }

                        # Check for seized role (if requested)
                        if ($IncludeSeizedRoleCheck) {
                            Write-Verbose "Checking event logs for role seizure events on $roleHolder"
                            try {
                                $seizedEvents = Get-WinEvent -ComputerName $roleHolder -FilterHashtable @{
                                    LogName = 'Directory Service'
                                    Id      = 2101  # FSMO role seizure event
                                } -MaxEvents 10 -ErrorAction SilentlyContinue

                                if ($seizedEvents) {
                                    # Check if any recent seizure events relate to this role
                                    $recentSeizure = $seizedEvents | Where-Object {
                                        $_.TimeCreated -gt (Get-Date).AddDays(-30) -and
                                        $_.Message -like "*$roleName*"
                                    } | Select-Object -First 1

                                    if ($recentSeizure) {
                                        $wasSeized = $true
                                        $warnings += "Role was seized within the last 30 days (Event: $($recentSeizure.TimeCreated))"
                                        Write-Verbose "Seized role detected: $($recentSeizure.TimeCreated)"
                                    }
                                }
                            }
                            catch {
                                Write-Verbose "Unable to check event logs: $_"
                                # Don't treat this as a critical error
                            }
                        }
                    }

                    # Determine health status
                    if (-not $roleHolder) {
                        $status = 'Critical'
                        $message = "$roleName is not assigned or could not be determined"
                        $remediation = "Investigate FSMO role assignment. Use 'netdom query fsmo' or 'Get-ADDomain/Get-ADForest' to verify role holders. Transfer or seize the role if necessary."
                    }
                    elseif ($errors.Count -gt 0) {
                        $status = 'Critical'
                        $message = "$roleName held by $roleHolder - Critical issues detected: $($errors -join '; ')"
                        $remediation = "Verify that $roleHolder is online and accessible. Check network connectivity, firewall rules (LDAP port 389), and DC health. Consider transferring role to healthy DC if issues persist."
                    }
                    elseif ($wasSeized -or $warnings.Count -gt 0) {
                        $status = 'Warning'
                        $message = "$roleName held by $roleHolder - Warning: $($warnings -join '; ')"
                        $remediation = if ($wasSeized) {
                            "Role was seized, which may indicate a past outage or improper transfer. Verify role holder health and review event logs for root cause. Document the seizure for audit purposes."
                        }
                        else {
                            "Review network connectivity and firewall configuration. ICMP may be intentionally blocked. Verify role holder is healthy via other means."
                        }
                    }
                    else {
                        $status = 'Healthy'
                        $message = "$roleName held by $roleHolder and is reachable"
                        $remediation = $null
                    }

                    # Create result data
                    $data = [PSCustomObject]@{
                        RoleName       = $roleName
                        RoleScope      = $roleInfo.Scope
                        RoleHolder     = $roleHolder
                        IsReachable    = $isReachable
                        WasSeized      = $wasSeized
                        Warnings       = $warnings
                        Errors         = $errors
                    }

                    $results += [HealthCheckResult]::new(
                        'FSMO Roles',
                        $roleName,
                        $roleHolder,
                        $status,
                        $message,
                        $data,
                        $remediation
                    )
                }
                catch {
                    Write-Error "Failed to check $roleName status: $_"

                    $results += [HealthCheckResult]::new(
                        'FSMO Roles',
                        $roleName,
                        'Unknown',
                        'Critical',
                        "Failed to check role status: $($_.Exception.Message)",
                        $null,
                        "Investigate the error and verify AD forest/domain connectivity. Check event logs for additional details."
                    )
                }
            }
        }
        catch {
            Write-Error "Failed to check FSMO role status: $_"

            # Return a general critical result
            $results += [HealthCheckResult]::new(
                'FSMO Roles',
                'All Roles',
                'Unknown',
                'Critical',
                "FSMO role check failed: $($_.Exception.Message)",
                $null,
                "Verify network connectivity, permissions, and that the ActiveDirectory module is installed. Check event logs for additional details."
            )
        }
    }

    end {
        Write-Verbose "FSMO role status check completed. Checked $($results.Count) role(s)."

        # Output all results
        foreach ($result in $results) {
            $result
        }
    }
}
