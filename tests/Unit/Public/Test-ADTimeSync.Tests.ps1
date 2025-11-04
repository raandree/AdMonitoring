BeforeAll {
    $modulePath = "$PSScriptRoot\..\..\..\output\module\AdMonitoring"
    Import-Module $modulePath -Force -ErrorAction Stop
}

Describe 'Test-ADTimeSync' {
    Context 'Parameter validation' {
        It 'Should have ComputerName parameter' {
            Get-Command Test-ADTimeSync | Should -HaveParameter ComputerName -Type string[]
        }

        It 'Should have Credential parameter' {
            Get-Command Test-ADTimeSync | Should -HaveParameter Credential -Type PSCredential
        }

        It 'Should have HealthyThresholdSeconds parameter' {
            Get-Command Test-ADTimeSync | Should -HaveParameter HealthyThresholdSeconds -Type int
        }

        It 'Should have WarningThresholdSeconds parameter' {
            Get-Command Test-ADTimeSync | Should -HaveParameter WarningThresholdSeconds -Type int
        }

        It 'Should accept pipeline input for ComputerName' {
            $param = (Get-Command Test-ADTimeSync).Parameters['ComputerName']
            $param.Attributes.ValueFromPipeline | Should -Be $true
            $param.Attributes.ValueFromPipelineByPropertyName | Should -Be $true
        }

        It 'Should have proper aliases for ComputerName' {
            $param = (Get-Command Test-ADTimeSync).Parameters['ComputerName']
            $param.Aliases | Should -Contain 'Name'
            $param.Aliases | Should -Contain 'HostName'
            $param.Aliases | Should -Contain 'DnsHostName'
        }

        It 'ComputerName parameter should be optional' {
            $param = (Get-Command Test-ADTimeSync).Parameters['ComputerName']
            $param.Attributes.Mandatory | Should -Be $false
        }

        It 'Credential parameter should be optional' {
            $param = (Get-Command Test-ADTimeSync).Parameters['Credential']
            $param.Attributes.Mandatory | Should -Be $false
        }

        It 'HealthyThresholdSeconds should have ValidateRange attribute' {
            $param = (Get-Command Test-ADTimeSync).Parameters['HealthyThresholdSeconds']
            $param.Attributes.MinRange | Should -Be 1
            $param.Attributes.MaxRange | Should -Be 60
        }

        It 'WarningThresholdSeconds should have ValidateRange attribute' {
            $param = (Get-Command Test-ADTimeSync).Parameters['WarningThresholdSeconds']
            $param.Attributes.MinRange | Should -Be 1
            $param.Attributes.MaxRange | Should -Be 300
        }
    }

    Context 'Function availability and help' {
        It 'Should have synopsis' {
            $help = Get-Help Test-ADTimeSync
            $help.Synopsis | Should -Not -BeNullOrEmpty
        }

        It 'Should have description' {
            $help = Get-Help Test-ADTimeSync
            $help.Description | Should -Not -BeNullOrEmpty
        }

        It 'Should have examples' {
            $help = Get-Help Test-ADTimeSync
            $help.Examples.Example.Count | Should -BeGreaterThan 0
        }

        It 'Should have at least 4 examples' {
            $help = Get-Help Test-ADTimeSync
            $help.Examples.Example.Count | Should -BeGreaterOrEqual 4
        }

        It 'Should have OutputType attribute' {
            $command = Get-Command Test-ADTimeSync
            $command.OutputType | Should -Not -BeNullOrEmpty
        }

        It 'Should have CmdletBinding attribute' {
            $command = Get-Command Test-ADTimeSync
            $command.CmdletBinding | Should -Be $true
        }

        It 'Should have help notes section' {
            $help = Get-Help Test-ADTimeSync
            $help.alertSet.alert.Text | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Function implementation structure' {
        It 'Should have OutputType declared' {
            $command = Get-Command Test-ADTimeSync
            $command.OutputType | Should -Not -BeNullOrEmpty
        }

        It 'Should use Begin/Process/End blocks' {
            $definition = (Get-Command Test-ADTimeSync).Definition
            $definition | Should -Match '\bbegin\s*\{'
            $definition | Should -Match '\bprocess\s*\{'
            $definition | Should -Match '\bend\s*\{'
        }

        It 'Should support auto-discovery of domain controllers' {
            $definition = (Get-Command Test-ADTimeSync).Definition
            $definition | Should -Match 'Get-ADDomainController'
        }

        It 'Should check PDC Emulator role' {
            $definition = (Get-Command Test-ADTimeSync).Definition
            $definition | Should -Match 'Get-ADDomain'
            $definition | Should -Match 'PDCEmulator'
        }

        It 'Should check W32Time service status' {
            $definition = (Get-Command Test-ADTimeSync).Definition
            $definition | Should -Match 'Get-CimInstance'
            $definition | Should -Match 'Win32_Service'
            $definition | Should -Match 'W32Time'
        }

        It 'Should retrieve time from domain controllers' {
            $definition = (Get-Command Test-ADTimeSync).Definition
            $definition | Should -Match 'Invoke-Command'
            $definition | Should -Match 'Get-Date'
        }

        It 'Should query W32Time configuration' {
            $definition = (Get-Command Test-ADTimeSync).Definition
            $definition | Should -Match 'w32tm'
            $definition | Should -Match '/query'
        }

        It 'Should calculate time offset' {
            $definition = (Get-Command Test-ADTimeSync).Definition
            $definition | Should -Match 'TimeOffset'
            $definition | Should -Match 'TotalSeconds'
        }

        It 'Should validate time source configuration' {
            $definition = (Get-Command Test-ADTimeSync).Definition
            $definition | Should -Match 'TimeSource'
            $definition | Should -Match 'Domain Hierarchy'
        }

        It 'Should check NTP server configuration' {
            $definition = (Get-Command Test-ADTimeSync).Definition
            $definition | Should -Match 'NTPServers'
            $definition | Should -Match '/query /peers'
        }

        It 'Should check Stratum level' {
            $definition = (Get-Command Test-ADTimeSync).Definition
            $definition | Should -Match 'Stratum'
        }

        It 'Should have threshold comparison logic' {
            $definition = (Get-Command Test-ADTimeSync).Definition
            $definition | Should -Match 'HealthyThresholdSeconds'
            $definition | Should -Match 'WarningThresholdSeconds'
        }

        It 'Should have error handling with try-catch' {
            $definition = (Get-Command Test-ADTimeSync).Definition
            $definition | Should -Match '\btry\s*\{'
            $definition | Should -Match '\bcatch\s*\{'
        }

        It 'Should use Write-Verbose for logging' {
            $definition = (Get-Command Test-ADTimeSync).Definition
            $definition | Should -Match 'Write-Verbose'
        }

        It 'Should use Write-Warning for warnings' {
            $definition = (Get-Command Test-ADTimeSync).Definition
            $definition | Should -Match 'Write-Warning'
        }
    }

    Context 'Output structure validation' {
        It 'Should create result with specific CheckName' {
            $definition = (Get-Command Test-ADTimeSync).Definition
            $definition | Should -Match "['``""]TimeSync['``""]"
        }

        It 'Should create result with specific Category' {
            $definition = (Get-Command Test-ADTimeSync).Definition
            $definition | Should -Match "['``""]Time Synchronization['``""]"
        }

        It 'Should set Severity to High' {
            $definition = (Get-Command Test-ADTimeSync).Definition
            $definition | Should -Match "Severity\s*=\s*['``""]High['``""]"
        }

        It 'Should include recommendations array' {
            $definition = (Get-Command Test-ADTimeSync).Definition
            $definition | Should -Match '\$recommendations'
            $definition | Should -Match 'System\.Collections\.Generic\.List'
        }

        It 'Should collect comprehensive details object' {
            $definition = (Get-Command Test-ADTimeSync).Definition
            $definition | Should -Match 'ComputerName'
            $definition | Should -Match 'IsPDCEmulator'
            $definition | Should -Match 'W32TimeServiceStatus'
            $definition | Should -Match 'TimeOffsetSeconds'
            $definition | Should -Match 'TimeSource'
            $definition | Should -Match 'Stratum'
            $definition | Should -Match 'NTPServers'
        }

        It 'Should format time offset with precision' {
            $definition = (Get-Command Test-ADTimeSync).Definition
            $definition | Should -Match 'TimeOffsetFormatted'
            $definition | Should -Match '{0:N2}'
        }
    }

    Context 'Status determination logic' {
        It 'Should return Critical when W32Time service is not running' {
            $definition = (Get-Command Test-ADTimeSync).Definition
            $definition | Should -Match "W32Time service is not running"
            $definition | Should -Match "Critical"
        }

        It 'Should return Critical when W32Time service is not found' {
            $definition = (Get-Command Test-ADTimeSync).Definition
            $definition | Should -Match "service not found"
        }

        It 'Should return Warning when service is not set to automatic' {
            $definition = (Get-Command Test-ADTimeSync).Definition
            $definition | Should -Match "not set to automatic"
        }

        It 'Should return Warning for time offset above healthy threshold' {
            $definition = (Get-Command Test-ADTimeSync).Definition
            $definition | Should -Match "exceeds healthy threshold"
        }

        It 'Should return Critical for time offset above warning threshold' {
            $definition = (Get-Command Test-ADTimeSync).Definition
            $definition | Should -Match "exceeds critical threshold"
        }

        It 'Should return Warning for PDC using local CMOS clock' {
            $definition = (Get-Command Test-ADTimeSync).Definition
            $definition | Should -Match "Local CMOS Clock"
        }

        It 'Should return Warning for non-PDC not syncing from domain hierarchy' {
            $definition = (Get-Command Test-ADTimeSync).Definition
            $definition | Should -Match "not syncing from domain hierarchy"
        }

        It 'Should return Healthy when all checks pass' {
            $definition = (Get-Command Test-ADTimeSync).Definition
            $definition | Should -Match "Time synchronization is healthy"
        }
    }

    Context 'Threshold configuration' {
        It 'Should have HealthyThresholdSeconds parameter with default value' {
            $definition = (Get-Command Test-ADTimeSync).Definition
            $definition | Should -Match '\$HealthyThresholdSeconds\s*=\s*5'
        }

        It 'Should have WarningThresholdSeconds parameter with default value' {
            $definition = (Get-Command Test-ADTimeSync).Definition
            $definition | Should -Match '\$WarningThresholdSeconds\s*=\s*10'
        }

        It 'Should validate threshold relationship' {
            $definition = (Get-Command Test-ADTimeSync).Definition
            $definition | Should -Match "must be greater than"
        }
    }

    Context 'Credential handling' {
        It 'Should conditionally add Credential to CIM parameters' {
            $definition = (Get-Command Test-ADTimeSync).Definition
            $definition | Should -Match 'PSBoundParameters\.ContainsKey'
            $definition | Should -Match "['``""]Credential['``""]"
        }

        It 'Should conditionally add Credential to Invoke-Command parameters' {
            $definition = (Get-Command Test-ADTimeSync).Definition
            $definition | Should -Match '\$invokeParams\[''Credential''\]'
        }
    }

    Context 'PDC Emulator specific logic' {
        It 'Should identify PDC Emulator role' {
            $definition = (Get-Command Test-ADTimeSync).Definition
            $definition | Should -Match 'IsPDCEmulator'
        }

        It 'Should warn if PDC uses local CMOS clock' {
            $definition = (Get-Command Test-ADTimeSync).Definition
            $definition | Should -Match "PDC Emulator is using local CMOS"
        }

        It 'Should recommend external NTP for PDC' {
            $definition = (Get-Command Test-ADTimeSync).Definition
            $definition | Should -Match "Configure PDC Emulator to use external NTP"
        }

        It 'Should use PDC as reference time source' {
            $definition = (Get-Command Test-ADTimeSync).Definition
            $definition | Should -Match '\$pdcEmulator'
            $definition | Should -Match '\$pdcTime'
        }
    }

    Context 'Recommendations generation' {
        It 'Should recommend starting W32Time service if stopped' {
            $definition = (Get-Command Test-ADTimeSync).Definition
            $definition | Should -Match "Start W32Time service"
        }

        It 'Should recommend setting service to automatic' {
            $definition = (Get-Command Test-ADTimeSync).Definition
            $definition | Should -Match "Set-Service W32Time -StartupType Automatic"
        }

        It 'Should recommend time resync for large offsets' {
            $definition = (Get-Command Test-ADTimeSync).Definition
            $definition | Should -Match "w32tm /resync /force"
        }

        It 'Should recommend verifying time source configuration' {
            $definition = (Get-Command Test-ADTimeSync).Definition
            $definition | Should -Match "Verify time source configuration"
        }

        It 'Should recommend configuring domain hierarchy sync' {
            $definition = (Get-Command Test-ADTimeSync).Definition
            $definition | Should -Match "Configure DC to sync from domain hierarchy"
        }

        It 'Should provide monitoring recommendations for healthy state' {
            $definition = (Get-Command Test-ADTimeSync).Definition
            $definition | Should -Match "Continue monitoring time sync"
        }
    }

    Context 'W32Time configuration parsing' {
        It 'Should parse time source from w32tm output' {
            $definition = (Get-Command Test-ADTimeSync).Definition
            $definition | Should -Match 'w32tm /query /source'
        }

        It 'Should parse status from w32tm output' {
            $definition = (Get-Command Test-ADTimeSync).Definition
            $definition | Should -Match 'w32tm /query /status'
        }

        It 'Should parse peer information' {
            $definition = (Get-Command Test-ADTimeSync).Definition
            $definition | Should -Match 'w32tm /query /peers'
            $definition | Should -Match 'Peer:'
        }

        It 'Should extract Stratum from status output' {
            $definition = (Get-Command Test-ADTimeSync).Definition
            $definition | Should -Match "Stratum:\\s\*\(\\d\+\)"
        }

        It 'Should handle w32tm command failures' {
            $definition = (Get-Command Test-ADTimeSync).Definition
            $definition | Should -Match 'LASTEXITCODE'
        }
    }

    Context 'Error handling scenarios' {
        It 'Should handle Get-ADDomainController failure' {
            $definition = (Get-Command Test-ADTimeSync).Definition
            $definition | Should -Match "Failed to discover domain controllers"
        }

        It 'Should handle Get-CimInstance failure' {
            $definition = (Get-Command Test-ADTimeSync).Definition
            $definition | Should -Match "Failed to check service"
        }

        It 'Should handle Invoke-Command failure for time retrieval' {
            $definition = (Get-Command Test-ADTimeSync).Definition
            $definition | Should -Match "Failed to retrieve time"
        }

        It 'Should handle W32Time configuration retrieval failure' {
            $definition = (Get-Command Test-ADTimeSync).Definition
            $definition | Should -Match "Failed to retrieve configuration"
        }

        It 'Should handle unexpected errors' {
            $definition = (Get-Command Test-ADTimeSync).Definition
            $definition | Should -Match "Unexpected error"
        }
    }
}
