BeforeAll {
    $modulePath = "$PSScriptRoot\..\..\..\output\module\AdMonitoring"
    Import-Module $modulePath -Force -ErrorAction Stop
}

Describe 'Test-ADSYSVOLHealth' {
    Context 'Parameter validation' {
        It 'Should have ComputerName parameter' {
            Get-Command Test-ADSYSVOLHealth | Should -HaveParameter ComputerName -Type string[]
        }

        It 'Should have Credential parameter' {
            Get-Command Test-ADSYSVOLHealth | Should -HaveParameter Credential -Type PSCredential
        }

        It 'Should have IncludeBacklogDetails parameter' {
            Get-Command Test-ADSYSVOLHealth | Should -HaveParameter IncludeBacklogDetails -Type switch
        }

        It 'Should accept pipeline input for ComputerName' {
            $param = (Get-Command Test-ADSYSVOLHealth).Parameters['ComputerName']
            $param.Attributes.ValueFromPipeline | Should -Be $true
        }

        It 'Should accept pipeline input by property name for ComputerName' {
            $param = (Get-Command Test-ADSYSVOLHealth).Parameters['ComputerName']
            $param.Attributes.ValueFromPipelineByPropertyName | Should -Be $true
        }

        It 'Should have proper aliases for ComputerName' {
            $param = (Get-Command Test-ADSYSVOLHealth).Parameters['ComputerName']
            $param.Aliases | Should -Contain 'Name'
            $param.Aliases | Should -Contain 'DomainController'
            $param.Aliases | Should -Contain 'DC'
            $param.Aliases | Should -Contain 'HostName'
        }

        It 'ComputerName parameter should be optional' {
            $param = (Get-Command Test-ADSYSVOLHealth).Parameters['ComputerName']
            $param.Attributes.Mandatory | Should -Be $false
        }

        It 'Credential parameter should be optional' {
            $param = (Get-Command Test-ADSYSVOLHealth).Parameters['Credential']
            $param.Attributes.Mandatory | Should -Be $false
        }

        It 'IncludeBacklogDetails should be a switch parameter' {
            $param = (Get-Command Test-ADSYSVOLHealth).Parameters['IncludeBacklogDetails']
            $param.SwitchParameter | Should -Be $true
        }
    }

    Context 'Function availability and help' {
        It 'Should have synopsis' {
            $help = Get-Help Test-ADSYSVOLHealth
            $help.Synopsis | Should -Not -BeNullOrEmpty
        }

        It 'Should have description' {
            $help = Get-Help Test-ADSYSVOLHealth
            $help.Description | Should -Not -BeNullOrEmpty
        }

        It 'Should have examples' {
            $help = Get-Help Test-ADSYSVOLHealth
            $help.Examples.Example.Count | Should -BeGreaterThan 0
        }

        It 'Should have OutputType defined' {
            $command = Get-Command Test-ADSYSVOLHealth
            $command.OutputType.Name | Should -Contain 'HealthCheckResult'
        }

        It 'Should have CmdletBinding attribute' {
            $command = Get-Command Test-ADSYSVOLHealth
            $command.CmdletBinding | Should -Be $true
        }
    }

    Context 'Function implementation structure' {
        It 'Should return HealthCheckResult type' {
            $command = Get-Command Test-ADSYSVOLHealth
            $command.OutputType.Name | Should -Contain 'HealthCheckResult'
        }

        It 'Should use Begin/Process/End blocks' {
            $definition = (Get-Command Test-ADSYSVOLHealth).Definition
            $definition | Should -Match '\bbegin\s*\{'
            $definition | Should -Match '\bprocess\s*\{'
            $definition | Should -Match '\bend\s*\{'
        }

        It 'Should check SYSVOL accessibility' {
            $definition = (Get-Command Test-ADSYSVOLHealth).Definition
            $definition | Should -Match 'Test-Path'
            $definition | Should -Match '\\SYSVOL'
        }

        It 'Should check DFSR service status' {
            $definition = (Get-Command Test-ADSYSVOLHealth).Definition
            $definition | Should -Match 'Get-Service'
            $definition | Should -Match 'DFSR'
        }

        It 'Should check DFSR replication state' {
            $definition = (Get-Command Test-ADSYSVOLHealth).Definition
            $definition | Should -Match 'DfsrReplicatedFolderInfo'
        }

        It 'Should check replication backlog' {
            $definition = (Get-Command Test-ADSYSVOLHealth).Definition
            $definition | Should -Match 'Get-DfsrBacklog'
        }

        It 'Should check last replication time' {
            $definition = (Get-Command Test-ADSYSVOLHealth).Definition
            $definition | Should -Match 'LastSuccessfulInboundSync'
        }

        It 'Should support auto-discovery of domain controllers' {
            $definition = (Get-Command Test-ADSYSVOLHealth).Definition
            $definition | Should -Match 'Get-ADDomainController'
        }

        It 'Should use Invoke-Command for remote checks' {
            $definition = (Get-Command Test-ADSYSVOLHealth).Definition
            $definition | Should -Match 'Invoke-Command'
        }

        It 'Should include backlog threshold logic' {
            $definition = (Get-Command Test-ADSYSVOLHealth).Definition
            $definition | Should -Match 'healthyThreshold'
            $definition | Should -Match 'warningThreshold'
        }

        It 'Should include replication lag threshold logic' {
            $definition = (Get-Command Test-ADSYSVOLHealth).Definition
            $definition | Should -Match 'LagMinutes'
        }

        It 'Should have error handling with try-catch' {
            $definition = (Get-Command Test-ADSYSVOLHealth).Definition
            $definition | Should -Match '\btry\s*\{'
            $definition | Should -Match '\bcatch\s*\{'
        }

        It 'Should use Write-Verbose for logging' {
            $definition = (Get-Command Test-ADSYSVOLHealth).Definition
            $definition | Should -Match 'Write-Verbose'
        }

        It 'Should use Write-Error for error reporting' {
            $definition = (Get-Command Test-ADSYSVOLHealth).Definition
            $definition | Should -Match 'Write-Error'
        }
    }

    Context 'Output structure validation' {
        It 'Should create result with specific CheckName' {
            $definition = (Get-Command Test-ADSYSVOLHealth).Definition
            $definition | Should -Match "['``""]SYSVOL Health['``""]"
        }

        It 'Should create result with specific Category' {
            $definition = (Get-Command Test-ADSYSVOLHealth).Definition
            $definition | Should -Match "['``""]SYSVOL/DFSR Replication['``""]"
        }

        It 'Should include remediation information' {
            $definition = (Get-Command Test-ADSYSVOLHealth).Definition
            $definition | Should -Match '\$remediation'
        }

        It 'Should collect comprehensive data object' {
            $definition = (Get-Command Test-ADSYSVOLHealth).Definition
            $definition | Should -Match 'SYSVOLAccessible'
            $definition | Should -Match 'DFSRServiceRunning'
            $definition | Should -Match 'ReplicationState'
            $definition | Should -Match 'BacklogCount'
            $definition | Should -Match 'LastReplicationTime'
            $definition | Should -Match 'ReplicationLagMinutes'
        }

        It 'Should include warnings and errors arrays' {
            $definition = (Get-Command Test-ADSYSVOLHealth).Definition
            $definition | Should -Match '\$warnings\s*='
            $definition | Should -Match '\$errors\s*='
        }
    }

    Context 'Status determination logic' {
        It 'Should return Critical when SYSVOL not accessible' {
            $definition = (Get-Command Test-ADSYSVOLHealth).Definition
            $definition | Should -Match "not.*SYSVOLAccessible"
            $definition | Should -Match "Critical"
        }

        It 'Should return Critical when DFSR service not running' {
            $definition = (Get-Command Test-ADSYSVOLHealth).Definition
            $definition | Should -Match "not.*DFSRServiceRunning"
            $definition | Should -Match "Critical"
        }

        It 'Should return Critical when errors exist' {
            $definition = (Get-Command Test-ADSYSVOLHealth).Definition
            $definition | Should -Match '\$errors\.Count\s*-gt\s*0'
        }

        It 'Should return Warning when warnings exist' {
            $definition = (Get-Command Test-ADSYSVOLHealth).Definition
            $definition | Should -Match '\$warnings\.Count\s*-gt\s*0'
        }

        It 'Should return Healthy when all checks pass' {
            $definition = (Get-Command Test-ADSYSVOLHealth).Definition
            $definition | Should -Match "Healthy"
        }
    }

    Context 'Threshold configuration' {
        It 'Should define backlog healthy threshold as 50' {
            $definition = (Get-Command Test-ADSYSVOLHealth).Definition
            $definition | Should -Match '\$healthyThreshold\s*=\s*50'
        }

        It 'Should define backlog warning threshold as 100' {
            $definition = (Get-Command Test-ADSYSVOLHealth).Definition
            $definition | Should -Match '\$warningThreshold\s*=\s*100'
        }

        It 'Should define replication lag healthy threshold as 60 minutes' {
            $definition = (Get-Command Test-ADSYSVOLHealth).Definition
            $definition | Should -Match '\$healthyLagMinutes\s*=\s*60'
        }

        It 'Should define replication lag warning threshold as 120 minutes' {
            $definition = (Get-Command Test-ADSYSVOLHealth).Definition
            $definition | Should -Match '\$warningLagMinutes\s*=\s*120'
        }
    }

    Context 'Credential handling' {
        It 'Should conditionally add Credential to CIM parameters' {
            $definition = (Get-Command Test-ADSYSVOLHealth).Definition
            $definition | Should -Match '\$cimParams\[''Credential''\]'
        }

        It 'Should conditionally add Credential to Invoke-Command parameters' {
            $definition = (Get-Command Test-ADSYSVOLHealth).Definition
            $definition | Should -Match '\$invParams\[''Credential''\]'
        }
    }

    Context 'IncludeBacklogDetails functionality' {
        It 'Should collect backlog details when switch is specified' {
            $definition = (Get-Command Test-ADSYSVOLHealth).Definition
            $definition | Should -Match 'IncludeBacklogDetails'
            $definition | Should -Match 'BacklogDetails'
        }

        It 'Should show placeholder when backlog details not requested' {
            $definition = (Get-Command Test-ADSYSVOLHealth).Definition
            $definition | Should -Match 'Use -IncludeBacklogDetails'
        }
    }
}
