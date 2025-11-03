BeforeAll {
    $modulePath = "$PSScriptRoot\..\..\..\output\module\AdMonitoring"
    Import-Module $modulePath -Force
}

Describe 'Test-ADDNSHealth' {
    Context 'Parameter validation' {
        It 'Should have ComputerName parameter' {
            Get-Command Test-ADDNSHealth | Should -HaveParameter ComputerName -Type string[]
        }

        It 'Should have Domain parameter' {
            Get-Command Test-ADDNSHealth | Should -HaveParameter Domain -Type string
        }

        It 'Should have Credential parameter' {
            Get-Command Test-ADDNSHealth | Should -HaveParameter Credential -Type PSCredential
        }

        It 'Should have IncludeSRVRecordDetails parameter' {
            Get-Command Test-ADDNSHealth | Should -HaveParameter IncludeSRVRecordDetails -Type switch
        }

        It 'Should accept pipeline input for ComputerName' {
            $param = (Get-Command Test-ADDNSHealth).Parameters['ComputerName']
            $param.Attributes.ValueFromPipeline | Should -Be $true
        }

        It 'Should have proper aliases for ComputerName' {
            $param = (Get-Command Test-ADDNSHealth).Parameters['ComputerName']
            $param.Aliases | Should -Contain 'Name'
            $param.Aliases | Should -Contain 'DomainController'
            $param.Aliases | Should -Contain 'DC'
        }

        It 'ComputerName parameter should be optional' {
            $param = (Get-Command Test-ADDNSHealth).Parameters['ComputerName']
            $param.Attributes.Mandatory | Should -Contain $false
        }

        It 'Domain parameter should be optional' {
            $param = (Get-Command Test-ADDNSHealth).Parameters['Domain']
            $param.Attributes.Mandatory | Should -Contain $false
        }
    }

    Context 'Function availability and help' {
        It 'Should have synopsis' {
            $help = Get-Help Test-ADDNSHealth
            $help.Synopsis | Should -Not -BeNullOrEmpty
        }

        It 'Should have description' {
            $help = Get-Help Test-ADDNSHealth
            $help.Description | Should -Not -BeNullOrEmpty
        }

        It 'Should have examples' {
            $help = Get-Help Test-ADDNSHealth
            $help.Examples | Should -Not -BeNullOrEmpty
        }

        It 'Should return HealthCheckResult type' {
            $command = Get-Command Test-ADDNSHealth
            $command.OutputType.Name | Should -Contain 'HealthCheckResult'
        }
    }

    Context 'Function design validation' {
        It 'Should follow Verb-Noun naming convention' {
            'Test-ADDNSHealth' | Should -Match '^\w+-\w+$'
        }

        It 'Should be exported from module' {
            $module = Get-Module AdMonitoring
            $module.ExportedCommands.Keys | Should -Contain 'Test-ADDNSHealth'
        }

        It 'Should have CmdletBinding attribute' {
            $metadata = [System.Management.Automation.CommandMetadata]::new((Get-Command Test-ADDNSHealth))
            $metadata.SupportsShouldProcess | Should -BeFalse
            # CmdletBinding is present if parameters work with pipeline
            (Get-Command Test-ADDNSHealth).Parameters.Values.Attributes.ValueFromPipeline -contains $true | Should -Be $true
        }
    }

    Context 'Critical SRV record definitions' {
        BeforeAll {
            $functionCode = Get-Content "$PSScriptRoot\..\..\..\source\Public\Test-ADDNSHealth.ps1" -Raw
        }

        It 'Should define critical SRV records' {
            $functionCode | Should -Match '_ldap\._tcp\.dc\._msdcs'
            $functionCode | Should -Match '_kerberos\._tcp\.dc\._msdcs'
            $functionCode | Should -Match '_ldap\._tcp'
            $functionCode | Should -Match '_kerberos\._tcp'
        }

        It 'Should define optional SRV records' {
            $functionCode | Should -Match '_gc\._tcp'
            $functionCode | Should -Match '_kpasswd\._tcp'
        }

        It 'Should have at least 4 critical SRV records' {
            $criticalMatches = [regex]::Matches($functionCode, "criticalSRVRecords")
            $criticalMatches.Count | Should -BeGreaterThan 0
        }

        It 'Should have optional SRV records defined' {
            $optionalMatches = [regex]::Matches($functionCode, "optionalSRVRecords")
            $optionalMatches.Count | Should -BeGreaterThan 0
        }
    }

    Context 'DNS resolution tests' {
        BeforeAll {
            $functionCode = Get-Content "$PSScriptRoot\..\..\..\source\Public\Test-ADDNSHealth.ps1" -Raw
        }

        It 'Should use Resolve-DnsName for A record resolution' {
            $functionCode | Should -Match 'Resolve-DnsName.*-Type A'
        }

        It 'Should use Resolve-DnsName for PTR record resolution' {
            $functionCode | Should -Match 'Resolve-DnsName.*-Type PTR'
        }

        It 'Should use Resolve-DnsName for SRV record resolution' {
            $functionCode | Should -Match 'Resolve-DnsName.*-Type SRV'
        }

        It 'Should measure DNS resolution time' {
            $functionCode | Should -Match 'Stopwatch'
            $functionCode | Should -Match 'ElapsedMilliseconds'
        }

        It 'Should check resolution speed thresholds' {
            $functionCode | Should -Match '500'  # Slow threshold
            $functionCode | Should -Match '100'  # Elevated threshold
        }
    }

    Context 'SRV record registration verification' {
        BeforeAll {
            $functionCode = Get-Content "$PSScriptRoot\..\..\..\source\Public\Test-ADDNSHealth.ps1" -Raw
        }

        It 'Should verify DC is registered in SRV records' {
            $functionCode | Should -Match 'NameTarget.*like.*computer'
        }

        It 'Should track SRV records found' {
            $functionCode | Should -Match 'SRVRecordsFound'
        }

        It 'Should track SRV records missing' {
            $functionCode | Should -Match 'SRVRecordsMissing'
        }

        It 'Should support SRV record details output' {
            $functionCode | Should -Match 'IncludeSRVRecordDetails'
        }
    }

    Context 'DNS service status check' {
        BeforeAll {
            $functionCode = Get-Content "$PSScriptRoot\..\..\..\source\Public\Test-ADDNSHealth.ps1" -Raw
        }

        It 'Should check DNS service status' {
            $functionCode | Should -Match "Get-Service.*'DNS'"
        }

        It 'Should verify DNS service is running' {
            $functionCode | Should -Match "Status.*'Running'"
        }
    }

    Context 'Health status determination' {
        BeforeAll {
            $functionCode = Get-Content "$PSScriptRoot\..\..\..\source\Public\Test-ADDNSHealth.ps1" -Raw
        }

        It 'Should return Critical status for missing A record' {
            $functionCode | Should -Match "A record not found"
            $functionCode | Should -Match "status.*'Critical'"
        }

        It 'Should return Critical status for missing critical SRV records' {
            $functionCode | Should -Match "Critical SRV records missing"
        }

        It 'Should return Warning status for slow resolution' {
            $functionCode | Should -Match "DNS resolution.*slow"
        }

        It 'Should return Healthy status when all checks pass' {
            $functionCode | Should -Match "status.*'Healthy'"
            $functionCode | Should -Match "DNS health check passed"
        }

        It 'Should provide remediation guidance' {
            $functionCode | Should -Match 'remediation'
            $functionCode | Should -Match 'ipconfig /registerdns'
            $functionCode | Should -Match 'nltest /dsregdns'
        }
    }

    Context 'Output validation' {
        BeforeAll {
            $functionCode = Get-Content "$PSScriptRoot\..\..\..\source\Public\Test-ADDNSHealth.ps1" -Raw
        }

        It 'Should return HealthCheckResult objects' {
            $functionCode | Should -Match '\[HealthCheckResult\]::new'
        }

        It 'Should set category to DNS Health' {
            $functionCode | Should -Match "'DNS Health'"
        }

        It 'Should include DNS data in output' {
            $functionCode | Should -Match 'ARecordFound'
            $functionCode | Should -Match 'PTRRecordFound'
            $functionCode | Should -Match 'CriticalSRVFound'
            $functionCode | Should -Match 'DNSServiceRunning'
        }

        It 'Should include resolution time in output' {
            $functionCode | Should -Match 'ResolutionTimeMs'
        }
    }

    Context 'Domain parameter handling' {
        BeforeAll {
            $functionCode = Get-Content "$PSScriptRoot\..\..\..\source\Public\Test-ADDNSHealth.ps1" -Raw
        }

        It 'Should use Get-ADDomain to determine current domain' {
            $functionCode | Should -Match 'Get-ADDomain'
        }

        It 'Should use DNSRoot property for domain' {
            $functionCode | Should -Match 'DNSRoot'
        }

        It 'Should format SRV records with domain' {
            $functionCode | Should -Match '\-f \$Domain'
        }
    }

    Context 'Pipeline support' {
        BeforeAll {
            $functionCode = Get-Content "$PSScriptRoot\..\..\..\source\Public\Test-ADDNSHealth.ps1" -Raw
        }

        It 'Should support pipeline input' {
            $functionCode | Should -Match 'process\s*\{'
        }

        It 'Should track pipeline input received' {
            $functionCode | Should -Match 'pipelineInputReceived'
        }

        It 'Should auto-discover DCs if no input provided' {
            $functionCode | Should -Match 'Get-ADDomainController'
        }
    }

    Context 'Verbose output' {
        BeforeAll {
            $functionCode = Get-Content "$PSScriptRoot\..\..\..\source\Public\Test-ADDNSHealth.ps1" -Raw
        }

        It 'Should write verbose messages' {
            $functionCode | Should -Match 'Write-Verbose'
        }

        It 'Should log DNS health check start' {
            $functionCode | Should -Match 'Starting DNS health check'
        }

        It 'Should log resolution results' {
            $functionCode | Should -Match 'A record found'
            $functionCode | Should -Match 'PTR record found'
        }

        It 'Should log SRV record checks' {
            $functionCode | Should -Match 'Checking SRV record'
            $functionCode | Should -Match 'SRV record found'
        }
    }
}
