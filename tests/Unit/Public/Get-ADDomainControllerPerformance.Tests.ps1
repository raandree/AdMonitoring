BeforeAll {
    $modulePath = "$PSScriptRoot\..\..\..\output\module\AdMonitoring"
    Import-Module $modulePath -Force -ErrorAction Stop
}

Describe 'Get-ADDomainControllerPerformance' {
    Context 'Parameter validation' {
        It 'Should have ComputerName parameter' {
            Get-Command Get-ADDomainControllerPerformance | Should -HaveParameter ComputerName -Type string[]
        }

        It 'Should have Credential parameter' {
            Get-Command Get-ADDomainControllerPerformance | Should -HaveParameter Credential -Type PSCredential
        }

        It 'Should have CPUWarningThreshold parameter' {
            $cmd = Get-Command Get-ADDomainControllerPerformance
            $cmd | Should -HaveParameter CPUWarningThreshold -Type int
            $cmd.Parameters['CPUWarningThreshold'].Attributes.MinRange | Should -Be 1
            $cmd.Parameters['CPUWarningThreshold'].Attributes.MaxRange | Should -Be 100
        }

        It 'Should have CPUCriticalThreshold parameter' {
            $cmd = Get-Command Get-ADDomainControllerPerformance
            $cmd | Should -HaveParameter CPUCriticalThreshold -Type int
            $cmd.Parameters['CPUCriticalThreshold'].Attributes.MinRange | Should -Be 1
            $cmd.Parameters['CPUCriticalThreshold'].Attributes.MaxRange | Should -Be 100
        }

        It 'Should have MemoryWarningThreshold parameter' {
            $cmd = Get-Command Get-ADDomainControllerPerformance
            $cmd | Should -HaveParameter MemoryWarningThreshold -Type int
            $cmd.Parameters['MemoryWarningThreshold'].Attributes.MinRange | Should -Be 1
            $cmd.Parameters['MemoryWarningThreshold'].Attributes.MaxRange | Should -Be 100
        }

        It 'Should have MemoryCriticalThreshold parameter' {
            $cmd = Get-Command Get-ADDomainControllerPerformance
            $cmd | Should -HaveParameter MemoryCriticalThreshold -Type int
            $cmd.Parameters['MemoryCriticalThreshold'].Attributes.MinRange | Should -Be 1
            $cmd.Parameters['MemoryCriticalThreshold'].Attributes.MaxRange | Should -Be 100
        }

        It 'Should have DiskWarningThreshold parameter' {
            $cmd = Get-Command Get-ADDomainControllerPerformance
            $cmd | Should -HaveParameter DiskWarningThreshold -Type int
            $cmd.Parameters['DiskWarningThreshold'].Attributes.MinRange | Should -Be 1
            $cmd.Parameters['DiskWarningThreshold'].Attributes.MaxRange | Should -Be 100
        }

        It 'Should have DiskCriticalThreshold parameter' {
            $cmd = Get-Command Get-ADDomainControllerPerformance
            $cmd | Should -HaveParameter DiskCriticalThreshold -Type int
            $cmd.Parameters['DiskCriticalThreshold'].Attributes.MinRange | Should -Be 1
            $cmd.Parameters['DiskCriticalThreshold'].Attributes.MaxRange | Should -Be 100
        }

        It 'Should accept pipeline input for ComputerName' {
            $param = (Get-Command Get-ADDomainControllerPerformance).Parameters['ComputerName']
            $param.Attributes.ValueFromPipeline | Should -Be $true
        }

        It 'Should have proper aliases for ComputerName' {
            $param = (Get-Command Get-ADDomainControllerPerformance).Parameters['ComputerName']
            $param.Aliases | Should -Contain 'Name'
            $param.Aliases | Should -Contain 'HostName'
            $param.Aliases | Should -Contain 'DnsHostName'
        }

        It 'ComputerName parameter should be optional' {
            $param = (Get-Command Get-ADDomainControllerPerformance).Parameters['ComputerName']
            $param.Attributes.Mandatory | Should -Be $false
        }
    }

    Context 'Function availability and help' {
        It 'Should have synopsis' {
            $help = Get-Help Get-ADDomainControllerPerformance
            $help.Synopsis | Should -Not -BeNullOrEmpty
        }

        It 'Should have description' {
            $help = Get-Help Get-ADDomainControllerPerformance
            $help.Description | Should -Not -BeNullOrEmpty
        }

        It 'Should have examples' {
            $help = Get-Help Get-ADDomainControllerPerformance
            $help.Examples | Should -Not -BeNullOrEmpty
            $help.Examples.Example.Count | Should -BeGreaterOrEqual 2
        }

        It 'Should return PSCustomObject type' {
            $command = Get-Command Get-ADDomainControllerPerformance
            $outputType = $command.OutputType.Name
            $outputType | Should -Match 'PSCustomObject|PSObject'
        }

        It 'Should have notes section' {
            $help = Get-Help Get-ADDomainControllerPerformance
            $help.AlertSet | Should -Not -BeNullOrEmpty
        }

        It 'Should have link section' {
            $help = Get-Help Get-ADDomainControllerPerformance
            $help.relatedLinks | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Function design validation' {
        It 'Should follow Verb-Noun naming convention' {
            'Get-ADDomainControllerPerformance' | Should -Match '^[A-Z][a-z]+-[A-Z]'
        }

        It 'Should be exported from module' {
            $exportedCommands = (Get-Module AdMonitoring).ExportedCommands.Keys
            $exportedCommands | Should -Contain 'Get-ADDomainControllerPerformance'
        }

        It 'Should have CmdletBinding attribute' {
            $command = Get-Command Get-ADDomainControllerPerformance
            $command.CmdletBinding | Should -Be $true
        }

        It 'Should use approved PowerShell verb' {
            $verb = (Get-Command Get-ADDomainControllerPerformance).Verb
            $approvedVerbs = Get-Verb | Select-Object -ExpandProperty Verb
            $approvedVerbs | Should -Contain $verb
        }
    }

    # NOTE: Functional tests require ActiveDirectory module, CIM/WMI access, and live DC environment
    # The tests above validate function structure, parameters, and help documentation
    # Integration testing should be performed in an AD environment with:
    # - Healthy performance scenarios (normal CPU, memory, disk)
    # - Warning scenarios (70-90% CPU, 80-90% memory, <20% disk free)
    # - Critical scenarios (>90% CPU, >90% memory, <10% disk free)
    # - Multiple DC processing
    # - Custom threshold testing
    # - Error handling for unreachable DCs
    # - NTDS drive identification
    # - LDAP connection monitoring
    # - LSASS memory tracking
}
