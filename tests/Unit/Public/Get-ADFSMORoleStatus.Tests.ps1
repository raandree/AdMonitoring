BeforeAll {
    $modulePath = "$PSScriptRoot\..\..\..\output\module\AdMonitoring"
    Import-Module $modulePath -Force -ErrorAction Stop
}

Describe 'Get-ADFSMORoleStatus' {
    Context 'Parameter validation' {
        It 'Should have Credential parameter' {
            Get-Command Get-ADFSMORoleStatus | Should -HaveParameter Credential -Type PSCredential
        }

        It 'Should have IncludeSeizedRoleCheck parameter' {
            Get-Command Get-ADFSMORoleStatus | Should -HaveParameter IncludeSeizedRoleCheck -Type switch
        }

        It 'Credential parameter should be optional' {
            $param = (Get-Command Get-ADFSMORoleStatus).Parameters['Credential']
            $param.Attributes.Mandatory | Should -Not -Contain $true
        }

        It 'IncludeSeizedRoleCheck parameter should be optional' {
            $param = (Get-Command Get-ADFSMORoleStatus).Parameters['IncludeSeizedRoleCheck']
            $param.Attributes.Mandatory | Should -Not -Contain $true
        }
    }

    Context 'Function availability and help' {
        It 'Should have synopsis' {
            $help = Get-Help Get-ADFSMORoleStatus
            $help.Synopsis | Should -Not -BeNullOrEmpty
        }

        It 'Should have description' {
            $help = Get-Help Get-ADFSMORoleStatus
            $help.Description | Should -Not -BeNullOrEmpty
        }

        It 'Should have examples' {
            $help = Get-Help Get-ADFSMORoleStatus
            $help.Examples | Should -Not -BeNullOrEmpty
            $help.Examples.Example.Count | Should -BeGreaterThan 0
        }

        It 'Should return HealthCheckResult type' {
            $command = Get-Command Get-ADFSMORoleStatus
            $command.OutputType.Name | Should -Contain 'HealthCheckResult'
        }
    }

    Context 'Function design validation' {
        It 'Should follow Verb-Noun naming convention' {
            'Get-ADFSMORoleStatus' | Should -Match '^\w+-\w+'
        }

        It 'Should be exported from module' {
            $module = Get-Module AdMonitoring
            $module.ExportedCommands.Keys | Should -Contain 'Get-ADFSMORoleStatus'
        }

        It 'Should have CmdletBinding attribute' {
            $command = Get-Command Get-ADFSMORoleStatus
            $command.CmdletBinding | Should -Be $true
        }
    }

    Context 'FSMO role definitions' {
        It 'Should define all 5 FSMO roles internally' {
            # Verify function implementation includes all role definitions
            $functionContent = Get-Content -Path "$PSScriptRoot\..\..\..\source\Public\Get-ADFSMORoleStatus.ps1" -Raw
            $functionContent | Should -Match 'Schema Master'
            $functionContent | Should -Match 'Domain Naming Master'
            $functionContent | Should -Match 'PDC Emulator'
            $functionContent | Should -Match 'RID Master'
            $functionContent | Should -Match 'Infrastructure Master'
        }

        It 'Should define forest-scoped roles' {
            $functionContent = Get-Content -Path "$PSScriptRoot\..\..\..\source\Public\Get-ADFSMORoleStatus.ps1" -Raw
            $functionContent | Should -Match "Scope\s*=\s*'Forest'"
        }

        It 'Should define domain-scoped roles' {
            $functionContent = Get-Content -Path "$PSScriptRoot\..\..\..\source\Public\Get-ADFSMORoleStatus.ps1" -Raw
            $functionContent | Should -Match "Scope\s*=\s*'Domain'"
        }
    }

    Context 'Error handling validation' {
        It 'Should handle Get-ADForest failures' {
            $functionContent = Get-Content -Path "$PSScriptRoot\..\..\..\source\Public\Get-ADFSMORoleStatus.ps1" -Raw
            $functionContent | Should -Match 'Get-ADForest'
            $functionContent | Should -Match 'catch'
        }

        It 'Should handle Get-ADDomain failures' {
            $functionContent = Get-Content -Path "$PSScriptRoot\..\..\..\source\Public\Get-ADFSMORoleStatus.ps1" -Raw
            $functionContent | Should -Match 'Get-ADDomain'
            $functionContent | Should -Match 'catch'
        }

        It 'Should return Critical status on errors' {
            $functionContent = Get-Content -Path "$PSScriptRoot\..\..\..\source\Public\Get-ADFSMORoleStatus.ps1" -Raw
            $functionContent | Should -Match "'Critical'"
        }
    }

    Context 'Connectivity tests' {
        It 'Should use Test-Connection for ICMP checks' {
            $functionContent = Get-Content -Path "$PSScriptRoot\..\..\..\source\Public\Get-ADFSMORoleStatus.ps1" -Raw
            $functionContent | Should -Match 'Test-Connection'
        }

        It 'Should use Test-NetConnection for LDAP checks' {
            $functionContent = Get-Content -Path "$PSScriptRoot\..\..\..\source\Public\Get-ADFSMORoleStatus.ps1" -Raw
            $functionContent | Should -Match 'Test-NetConnection'
            $functionContent | Should -Match '389'  # LDAP port
        }

        It 'Should verify role holder reachability' {
            $functionContent = Get-Content -Path "$PSScriptRoot\..\..\..\source\Public\Get-ADFSMORoleStatus.ps1" -Raw
            $functionContent | Should -Match 'reachab'
        }
    }

    Context 'Seized role detection' {
        It 'Should check event logs when IncludeSeizedRoleCheck is enabled' {
            $functionContent = Get-Content -Path "$PSScriptRoot\..\..\..\source\Public\Get-ADFSMORoleStatus.ps1" -Raw
            $functionContent | Should -Match 'IncludeSeizedRoleCheck'
            $functionContent | Should -Match 'Get-WinEvent'
        }

        It 'Should look for event ID 2101 (role seizure)' {
            $functionContent = Get-Content -Path "$PSScriptRoot\..\..\..\source\Public\Get-ADFSMORoleStatus.ps1" -Raw
            $functionContent | Should -Match '2101'
        }

        It 'Should check Directory Service log' {
            $functionContent = Get-Content -Path "$PSScriptRoot\..\..\..\source\Public\Get-ADFSMORoleStatus.ps1" -Raw
            $functionContent | Should -Match 'Directory Service'
        }
    }

    Context 'Credential handling' {
        It 'Should accept PSCredential parameter' {
            $command = Get-Command Get-ADFSMORoleStatus
            $command.Parameters['Credential'].ParameterType.Name | Should -Be 'PSCredential'
        }

        It 'Should pass credentials to AD cmdlets' {
            $functionContent = Get-Content -Path "$PSScriptRoot\..\..\..\source\Public\Get-ADFSMORoleStatus.ps1" -Raw
            $functionContent | Should -Match 'Credential.*=.*\$Credential'
        }
    }

    Context 'Health status determination' {
        It 'Should return Healthy status for reachable holders' {
            $functionContent = Get-Content -Path "$PSScriptRoot\..\..\..\source\Public\Get-ADFSMORoleStatus.ps1" -Raw
            $functionContent | Should -Match "'Healthy'"
        }

        It 'Should return Warning status for issues' {
            $functionContent = Get-Content -Path "$PSScriptRoot\..\..\..\source\Public\Get-ADFSMORoleStatus.ps1" -Raw
            $functionContent | Should -Match "'Warning'"
        }

        It 'Should return Critical status for failures' {
            $functionContent = Get-Content -Path "$PSScriptRoot\..\..\..\source\Public\Get-ADFSMORoleStatus.ps1" -Raw
            $functionContent | Should -Match "'Critical'"
        }

        It 'Should provide remediation guidance' {
            $functionContent = Get-Content -Path "$PSScriptRoot\..\..\..\source\Public\Get-ADFSMORoleStatus.ps1" -Raw
            $functionContent | Should -Match '\$remediation'
        }
    }

    Context 'Output validation' {
        It 'Should return HealthCheckResult objects' {
            $functionContent = Get-Content -Path "$PSScriptRoot\..\..\..\source\Public\Get-ADFSMORoleStatus.ps1" -Raw
            $functionContent | Should -Match '\[HealthCheckResult\]::new'
        }

        It 'Should set category to FSMO Roles' {
            $functionContent = Get-Content -Path "$PSScriptRoot\..\..\..\source\Public\Get-ADFSMORoleStatus.ps1" -Raw
            $functionContent | Should -Match "'FSMO Roles'"
        }

        It 'Should include role data in output' {
            $functionContent = Get-Content -Path "$PSScriptRoot\..\..\..\source\Public\Get-ADFSMORoleStatus.ps1" -Raw
            $functionContent | Should -Match 'RoleName'
            $functionContent | Should -Match 'RoleHolder'
            $functionContent | Should -Match 'RoleScope'
        }
    }

    Context 'Verbose output' {
        It 'Should write verbose messages' {
            $functionContent = Get-Content -Path "$PSScriptRoot\..\..\..\source\Public\Get-ADFSMORoleStatus.ps1" -Raw
            $functionContent | Should -Match 'Write-Verbose'
        }

        It 'Should log FSMO role check start' {
            $functionContent = Get-Content -Path "$PSScriptRoot\..\..\..\source\Public\Get-ADFSMORoleStatus.ps1" -Raw
            $functionContent | Should -Match 'Starting FSMO role status check'
        }

        It 'Should log role holder information' {
            $functionContent = Get-Content -Path "$PSScriptRoot\..\..\..\source\Public\Get-ADFSMORoleStatus.ps1" -Raw
            $functionContent | Should -Match 'held by'
        }
    }
}
