BeforeAll {
    $modulePath = "$PSScriptRoot\..\..\..\output\module\AdMonitoring"
    Import-Module $modulePath -Force -ErrorAction Stop
}

Describe 'Get-ADReplicationStatus' {
    Context 'Parameter validation' {
        It 'Should have ComputerName parameter' {
            Get-Command Get-ADReplicationStatus | Should -HaveParameter ComputerName -Type string[]
        }

        It 'Should have Credential parameter' {
            Get-Command Get-ADReplicationStatus | Should -HaveParameter Credential -Type PSCredential
        }

        It 'Should have IncludePartnerDetails parameter' {
            Get-Command Get-ADReplicationStatus | Should -HaveParameter IncludePartnerDetails -Type bool
        }

        It 'Should accept pipeline input for ComputerName' {
            $param = (Get-Command Get-ADReplicationStatus).Parameters['ComputerName']
            $param.Attributes.ValueFromPipeline | Should -Be $true
        }

        It 'Should have proper aliases for ComputerName' {
            $param = (Get-Command Get-ADReplicationStatus).Parameters['ComputerName']
            $param.Aliases | Should -Contain 'Name'
            $param.Aliases | Should -Contain 'DomainController'
            $param.Aliases | Should -Contain 'DC'
        }

        It 'ComputerName parameter should be optional' {
            $param = (Get-Command Get-ADReplicationStatus).Parameters['ComputerName']
            $param.Attributes.Mandatory | Should -Be $false
        }
    }

    Context 'Function availability and help' {
        It 'Should have synopsis' {
            $help = Get-Help Get-ADReplicationStatus
            $help.Synopsis | Should -Not -BeNullOrEmpty
        }

        It 'Should have description' {
            $help = Get-Help Get-ADReplicationStatus
            $help.Description | Should -Not -BeNullOrEmpty
        }

        It 'Should have examples' {
            $help = Get-Help Get-ADReplicationStatus
            $help.Examples | Should -Not -BeNullOrEmpty
        }

        It 'Should return HealthCheckResult type' {
            $command = Get-Command Get-ADReplicationStatus
            $outputType = $command.OutputType.Name
            $outputType | Should -Be 'HealthCheckResult'
        }
    }

    Context 'Function design validation' {
        It 'Should follow Verb-Noun naming convention' {
            'Get-ADReplicationStatus' | Should -Match '^[A-Z][a-z]+-[A-Z]'
        }

        It 'Should be exported from module' {
            $exportedCommands = (Get-Module AdMonitoring).ExportedCommands.Keys
            $exportedCommands | Should -Contain 'Get-ADReplicationStatus'
        }

        It 'Should have CmdletBinding attribute' {
            $command = Get-Command Get-ADReplicationStatus
            $command.CmdletBinding | Should -Be $true
        }
    }

    # NOTE: Functional tests require ActiveDirectory module and live AD environment
    # The tests above validate function structure, parameters, and help documentation
    # Integration testing should be performed in an AD environment with:
    # - Healthy replication scenarios
    # - Elevated latency scenarios (15-60 minutes)
    # - Critical latency scenarios (>60 minutes)
    # - Replication failure scenarios
    # - No replication partners (single DC)
    # - Multiple computers processing
}
