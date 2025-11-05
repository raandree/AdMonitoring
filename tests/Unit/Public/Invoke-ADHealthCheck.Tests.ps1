BeforeAll {
    $modulePath = "$PSScriptRoot\..\..\..\output\module\AdMonitoring"
    Import-Module $modulePath -Force -ErrorAction Stop
}

Describe 'Invoke-ADHealthCheck' {
    Context 'Parameter validation' {
        It 'Should have ComputerName parameter' {
            Get-Command Invoke-ADHealthCheck | Should -HaveParameter ComputerName
        }

        It 'Should have Credential parameter' {
            Get-Command Invoke-ADHealthCheck | Should -HaveParameter Credential -Type PSCredential
        }

        It 'Should have Category parameter' {
            Get-Command Invoke-ADHealthCheck | Should -HaveParameter Category
        }

        It 'Should have GenerateReport parameter' {
            Get-Command Invoke-ADHealthCheck | Should -HaveParameter GenerateReport
        }

        It 'Should have ReportPath parameter' {
            Get-Command Invoke-ADHealthCheck | Should -HaveParameter ReportPath -Type string
        }
    }

    Context 'Function availability and help' {
        It 'Should have synopsis' {
            $help = Get-Help Invoke-ADHealthCheck
            $help.Synopsis | Should -Not -BeNullOrEmpty
        }

        It 'Should have description' {
            $help = Get-Help Invoke-ADHealthCheck
            $help.Description | Should -Not -BeNullOrEmpty
        }

        It 'Should have examples' {
            $help = Get-Help Invoke-ADHealthCheck
            $help.Examples.Example.Count | Should -BeGreaterThan 0
        }

        It 'Should have CmdletBinding attribute' {
            $command = Get-Command Invoke-ADHealthCheck
            $command.CmdletBinding | Should -Be $true
        }
    }

    Context 'Function design validation' {
        It 'Should follow Verb-Noun naming convention' {
            Get-Command Invoke-ADHealthCheck | Should -Not -BeNullOrEmpty
        }

        It 'Should be exported from module' {
            $exported = Get-Command -Module AdMonitoring
            $exported.Name | Should -Contain 'Invoke-ADHealthCheck'
        }
    }
}
