BeforeAll {
    $modulePath = "$PSScriptRoot\..\..\..\output\module\AdMonitoring"
    Import-Module $modulePath -Force -ErrorAction Stop
}

Describe 'Get-ADCriticalEvents' {
    Context 'Parameter validation' {
        It 'Should have ComputerName parameter' {
            Get-Command Get-ADCriticalEvents | Should -HaveParameter ComputerName -Type string[]
        }

        It 'Should have Credential parameter' {
            Get-Command Get-ADCriticalEvents | Should -HaveParameter Credential -Type PSCredential
        }

        It 'Should have Hours parameter' {
            Get-Command Get-ADCriticalEvents | Should -HaveParameter Hours -Type int
        }

        It 'Should have IncludeWarnings parameter' {
            Get-Command Get-ADCriticalEvents | Should -HaveParameter IncludeWarnings -Type switch
        }

        It 'Should have MaxEvents parameter' {
            Get-Command Get-ADCriticalEvents | Should -HaveParameter MaxEvents -Type int
        }

        It 'Should accept pipeline input for ComputerName' {
            $param = (Get-Command Get-ADCriticalEvents).Parameters['ComputerName']
            $param.Attributes.ValueFromPipeline | Should -Be $true
            $param.Attributes.ValueFromPipelineByPropertyName | Should -Be $true
        }

        It 'Should have proper aliases for ComputerName' {
            $param = (Get-Command Get-ADCriticalEvents).Parameters['ComputerName']
            $param.Aliases | Should -Contain 'Name'
            $param.Aliases | Should -Contain 'HostName'
            $param.Aliases | Should -Contain 'DnsHostName'
        }

        It 'ComputerName parameter should be optional' {
            $param = (Get-Command Get-ADCriticalEvents).Parameters['ComputerName']
            $param.Attributes.Mandatory | Should -Be $false
        }

        It 'Credential parameter should be optional' {
            $param = (Get-Command Get-ADCriticalEvents).Parameters['Credential']
            $param.Attributes.Mandatory | Should -Be $false
        }

        It 'Hours should have ValidateRange attribute' {
            $param = (Get-Command Get-ADCriticalEvents).Parameters['Hours']
            $param.Attributes.MinRange | Should -Be 1
            $param.Attributes.MaxRange | Should -Be 168
        }

        It 'Hours should have default value of 24' {
            $definition = (Get-Command Get-ADCriticalEvents).Definition
            $definition | Should -Match '\$Hours\s*=\s*24'
        }

        It 'MaxEvents should have ValidateRange attribute' {
            $param = (Get-Command Get-ADCriticalEvents).Parameters['MaxEvents']
            $param.Attributes.MinRange | Should -Be 1
            $param.Attributes.MaxRange | Should -Be 1000
        }

        It 'MaxEvents should have default value of 100' {
            $definition = (Get-Command Get-ADCriticalEvents).Definition
            $definition | Should -Match '\$MaxEvents\s*=\s*100'
        }
    }

    Context 'Function availability and help' {
        It 'Should have synopsis' {
            $help = Get-Help Get-ADCriticalEvents
            $help.Synopsis | Should -Not -BeNullOrEmpty
        }

        It 'Should have description' {
            $help = Get-Help Get-ADCriticalEvents
            $help.Description | Should -Not -BeNullOrEmpty
        }

        It 'Should have examples' {
            $help = Get-Help Get-ADCriticalEvents
            $help.Examples.Example.Count | Should -BeGreaterThan 0
        }

        It 'Should have at least 4 examples' {
            $help = Get-Help Get-ADCriticalEvents
            $help.Examples.Example.Count | Should -BeGreaterOrEqual 4
        }

        It 'Should have OutputType attribute' {
            $command = Get-Command Get-ADCriticalEvents
            $command.OutputType | Should -Not -BeNullOrEmpty
        }

        It 'Should have CmdletBinding attribute' {
            $command = Get-Command Get-ADCriticalEvents
            $command.CmdletBinding | Should -Be $true
        }

        It 'Should have help notes section' {
            $help = Get-Help Get-ADCriticalEvents
            $help.alertSet.alert.Text | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Function implementation structure' {
        It 'Should have OutputType declared' {
            $command = Get-Command Get-ADCriticalEvents
            $command.OutputType | Should -Not -BeNullOrEmpty
        }

        It 'Should use Begin/Process/End blocks' {
            $definition = (Get-Command Get-ADCriticalEvents).Definition
            $definition | Should -Match '\bbegin\s*\{'
            $definition | Should -Match '\bprocess\s*\{'
            $definition | Should -Match '\bend\s*\{'
        }

        It 'Should support auto-discovery of domain controllers' {
            $definition = (Get-Command Get-ADCriticalEvents).Definition
            $definition | Should -Match 'Get-ADDomainController'
        }

        It 'Should query multiple event logs' {
            $definition = (Get-Command Get-ADCriticalEvents).Definition
            $definition | Should -Match 'Directory Service'
            $definition | Should -Match 'DNS Server'
            $definition | Should -Match 'DFS Replication'
            $definition | Should -Match 'File Replication Service'
            $definition | Should -Match 'System'
        }

        It 'Should use Get-WinEvent cmdlet' {
            $definition = (Get-Command Get-ADCriticalEvents).Definition
            $definition | Should -Match 'Get-WinEvent'
        }

        It 'Should define critical event IDs' {
            $definition = (Get-Command Get-ADCriticalEvents).Definition
            $definition | Should -Match '\$criticalEventIds'
            $definition | Should -Match '2042'  # Replication failure
            $definition | Should -Match '4013'  # DNS zone transfer
            $definition | Should -Match '5805'  # Secure channel
            $definition | Should -Match '13508' # DFSR stopped
        }

        It 'Should calculate start time based on Hours parameter' {
            $definition = (Get-Command Get-ADCriticalEvents).Definition
            $definition | Should -Match '\$startTime'
            $definition | Should -Match 'AddHours'
        }

        It 'Should build event log filter parameters' {
            $definition = (Get-Command Get-ADCriticalEvents).Definition
            $definition | Should -Match '\$filterParams'
            $definition | Should -Match 'LogName'
            $definition | Should -Match 'Level'
            $definition | Should -Match 'StartTime'
        }

        It 'Should handle IncludeWarnings switch' {
            $definition = (Get-Command Get-ADCriticalEvents).Definition
            $definition | Should -Match 'IncludeWarnings'
            $definition | Should -Match '@\(1, 2, 3\)' # Critical, Error, Warning
        }

        It 'Should count events by severity level' {
            $definition = (Get-Command Get-ADCriticalEvents).Definition
            $definition | Should -Match 'CriticalEvents'
            $definition | Should -Match 'ErrorEvents'
            $definition | Should -Match 'WarningEvents'
        }

        It 'Should group events by Event ID' {
            $definition = (Get-Command Get-ADCriticalEvents).Definition
            $definition | Should -Match 'Group-Object Id'
            $definition | Should -Match 'TopEventIds'
        }

        It 'Should have error handling with try-catch' {
            $definition = (Get-Command Get-ADCriticalEvents).Definition
            $definition | Should -Match '\btry\s*\{'
            $definition | Should -Match '\bcatch\s*\{'
        }

        It 'Should use Write-Verbose for logging' {
            $definition = (Get-Command Get-ADCriticalEvents).Definition
            $definition | Should -Match 'Write-Verbose'
        }

        It 'Should use Write-Warning for warnings' {
            $definition = (Get-Command Get-ADCriticalEvents).Definition
            $definition | Should -Match 'Write-Warning'
        }
    }

    Context 'Output structure validation' {
        It 'Should create result with specific CheckName' {
            $definition = (Get-Command Get-ADCriticalEvents).Definition
            $definition | Should -Match "['``""]CriticalEvents['``""]"
        }

        It 'Should create result with specific Category' {
            $definition = (Get-Command Get-ADCriticalEvents).Definition
            $definition | Should -Match "['``""]Event Log Analysis['``""]"
        }

        It 'Should set Severity to Medium' {
            $definition = (Get-Command Get-ADCriticalEvents).Definition
            $definition | Should -Match "Severity\s*=\s*['``""]Medium['``""]"
        }

        It 'Should include recommendations array' {
            $definition = (Get-Command Get-ADCriticalEvents).Definition
            $definition | Should -Match '\$recommendations'
            $definition | Should -Match 'System\.Collections\.Generic\.List'
        }

        It 'Should collect comprehensive details object' {
            $definition = (Get-Command Get-ADCriticalEvents).Definition
            $definition | Should -Match 'ComputerName'
            $definition | Should -Match 'ScanPeriodHours'
            $definition | Should -Match 'TotalEventsFound'
            $definition | Should -Match 'CriticalEvents'
            $definition | Should -Match 'ErrorEvents'
            $definition | Should -Match 'WarningEvents'
            $definition | Should -Match 'EventsByLog'
            $definition | Should -Match 'TopEventIds'
        }

        It 'Should include RawData with all events' {
            $definition = (Get-Command Get-ADCriticalEvents).Definition
            $definition | Should -Match 'RawData'
            $definition | Should -Match '\$allEvents\.ToArray\(\)'
        }
    }

    Context 'Status determination logic' {
        It 'Should return Critical when critical events found' {
            $definition = (Get-Command Get-ADCriticalEvents).Definition
            $definition | Should -Match "CriticalEvents -gt 0"
            $definition | Should -Match "status = 'Critical'"
        }

        It 'Should return Critical when error count exceeds 10' {
            $definition = (Get-Command Get-ADCriticalEvents).Definition
            $definition | Should -Match "ErrorEvents -gt 10"
        }

        It 'Should return Warning when errors found' {
            $definition = (Get-Command Get-ADCriticalEvents).Definition
            $definition | Should -Match "ErrorEvents -gt 0"
            $definition | Should -Match "status = 'Warning'"
        }

        It 'Should return Warning when warning count exceeds 20' {
            $definition = (Get-Command Get-ADCriticalEvents).Definition
            $definition | Should -Match "WarningEvents -gt 20"
        }

        It 'Should return Healthy when no events found' {
            $definition = (Get-Command Get-ADCriticalEvents).Definition
            $definition | Should -Match "No critical events found"
        }
    }

    Context 'Event-specific recommendations' {
        It 'Should recommend action for Event 2042 (replication failure)' {
            $definition = (Get-Command Get-ADCriticalEvents).Definition
            $definition | Should -Match "2042"
            $definition | Should -Match "Replication hasn't occurred"
        }

        It 'Should recommend action for DNS lookup failures' {
            $definition = (Get-Command Get-ADCriticalEvents).Definition
            $definition | Should -Match "2087.*2088"
            $definition | Should -Match "DNS lookup failure"
        }

        It 'Should recommend action for DNS zone transfer failure' {
            $definition = (Get-Command Get-ADCriticalEvents).Definition
            $definition | Should -Match "4013"
            $definition | Should -Match "DNS zone transfer failure"
        }

        It 'Should recommend action for secure channel issues' {
            $definition = (Get-Command Get-ADCriticalEvents).Definition
            $definition | Should -Match "5805.*5719"
            $definition | Should -Match "Secure channel|Netlogon"
        }

        It 'Should recommend action for DFSR replication issues' {
            $definition = (Get-Command Get-ADCriticalEvents).Definition
            $definition | Should -Match "13508.*13516"
            $definition | Should -Match "DFSR replication issue"
        }

        It 'Should recommend action for resource limit exceeded' {
            $definition = (Get-Command Get-ADCriticalEvents).Definition
            $definition | Should -Match "1645"
            $definition | Should -Match "Resource limit exceeded"
        }

        It 'Should recommend reviewing Event Viewer' {
            $definition = (Get-Command Get-ADCriticalEvents).Definition
            $definition | Should -Match "Event Viewer"
        }

        It 'Should recommend correlating with other health checks' {
            $definition = (Get-Command Get-ADCriticalEvents).Definition
            $definition | Should -Match "Correlate events"
        }
    }

    Context 'Credential handling' {
        It 'Should conditionally add Credential to Get-WinEvent parameters' {
            $definition = (Get-Command Get-ADCriticalEvents).Definition
            $definition | Should -Match 'PSBoundParameters\.ContainsKey'
            $definition | Should -Match "['``""]Credential['``""]"
        }

        It 'Should add Credential to getEventParams' {
            $definition = (Get-Command Get-ADCriticalEvents).Definition
            $definition | Should -Match '\$getEventParams\[''Credential''\]'
        }
    }

    Context 'Event log iteration' {
        It 'Should iterate through all defined event logs' {
            $definition = (Get-Command Get-ADCriticalEvents).Definition
            $definition | Should -Match 'foreach.*\$logName.*\$criticalEventIds\.Keys'
        }

        It 'Should handle missing event logs gracefully' {
            $definition = (Get-Command Get-ADCriticalEvents).Definition
            $definition | Should -Match 'No events were found'
            $definition | Should -Match 'does not exist'
        }

        It 'Should add LogCategory to events' {
            $definition = (Get-Command Get-ADCriticalEvents).Definition
            $definition | Should -Match 'Add-Member.*LogCategory'
        }

        It 'Should count events by log name' {
            $definition = (Get-Command Get-ADCriticalEvents).Definition
            $definition | Should -Match 'EventsByLog\[\$logName\]'
        }
    }

    Context 'Error handling scenarios' {
        It 'Should handle Get-ADDomainController failure' {
            $definition = (Get-Command Get-ADCriticalEvents).Definition
            $definition | Should -Match "Failed to discover domain controllers"
        }

        It 'Should handle Get-WinEvent failures' {
            $definition = (Get-Command Get-ADCriticalEvents).Definition
            $definition | Should -Match "Failed to query.*log"
        }

        It 'Should handle unexpected errors' {
            $definition = (Get-Command Get-ADCriticalEvents).Definition
            $definition | Should -Match "Unexpected error"
        }

        It 'Should recommend verifying remote event log access' {
            $definition = (Get-Command Get-ADCriticalEvents).Definition
            $definition | Should -Match "remote event log access permissions"
        }

        It 'Should recommend checking WinRM service' {
            $definition = (Get-Command Get-ADCriticalEvents).Definition
            $definition | Should -Match "Windows Remote Management service"
        }

        It 'Should recommend checking firewall rules' {
            $definition = (Get-Command Get-ADCriticalEvents).Definition
            $definition | Should -Match "firewall rules"
        }
    }

    Context 'Time period handling' {
        It 'Should use Hours parameter to calculate start time' {
            $definition = (Get-Command Get-ADCriticalEvents).Definition
            $definition | Should -Match 'AddHours\(-\$Hours\)'
        }

        It 'Should store scan period in details' {
            $definition = (Get-Command Get-ADCriticalEvents).Definition
            $definition | Should -Match 'ScanPeriodHours\s*=\s*\$Hours'
        }

        It 'Should store start and end times in details' {
            $definition = (Get-Command Get-ADCriticalEvents).Definition
            $definition | Should -Match 'StartTime\s*=\s*\$startTime'
            $definition | Should -Match 'EndTime\s*=\s*Get-Date'
        }
    }

    Context 'Event analysis and aggregation' {
        It 'Should count total events found' {
            $definition = (Get-Command Get-ADCriticalEvents).Definition
            $definition | Should -Match 'TotalEventsFound\s*=\s*\$allEvents\.Count'
        }

        It 'Should filter and count by event level' {
            $definition = (Get-Command Get-ADCriticalEvents).Definition
            $definition | Should -Match 'Where-Object.*Level -eq 1'
            $definition | Should -Match 'Where-Object.*Level -eq 2'
            $definition | Should -Match 'Where-Object.*Level -eq 3'
        }

        It 'Should get top 5 event IDs' {
            $definition = (Get-Command Get-ADCriticalEvents).Definition
            $definition | Should -Match 'Select-Object -First 5'
        }

        It 'Should get unique event IDs for recommendations' {
            $definition = (Get-Command Get-ADCriticalEvents).Definition
            $definition | Should -Match 'Select-Object -Unique'
        }
    }
}
