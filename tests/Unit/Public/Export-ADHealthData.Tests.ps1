BeforeAll {
    $modulePath = "$PSScriptRoot\..\..\..\output\module\AdMonitoring"
    Import-Module $modulePath -Force -ErrorAction Stop
}

Describe 'Export-ADHealthData' {
    Context 'Parameter validation' {
        It 'Should have HealthCheckResults parameter' {
            Get-Command Export-ADHealthData | Should -HaveParameter HealthCheckResults
        }

        It 'Should have Path parameter' {
            Get-Command Export-ADHealthData | Should -HaveParameter Path -Type string
        }

        It 'Should have Format parameter' {
            Get-Command Export-ADHealthData | Should -HaveParameter Format -Type string
        }
    }

    Context 'Function availability and help' {
        It 'Should have synopsis' {
            $help = Get-Help Export-ADHealthData
            $help.Synopsis | Should -Not -BeNullOrEmpty
        }

        It 'Should have description' {
            $help = Get-Help Export-ADHealthData
            $help.Description | Should -Not -BeNullOrEmpty
        }

        It 'Should have examples' {
            $help = Get-Help Export-ADHealthData
            $help.Examples.Example.Count | Should -BeGreaterThan 0
        }

        It 'Should have CmdletBinding attribute' {
            $command = Get-Command Export-ADHealthData
            $command.CmdletBinding | Should -Be $true
        }
    }
}
