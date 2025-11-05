BeforeAll {
    $modulePath = "$PSScriptRoot\..\..\..\output\module\AdMonitoring"
    Import-Module $modulePath -Force -ErrorAction Stop
}

Describe 'Send-ADHealthReport' {
    Context 'Parameter validation' {
        It 'Should have HealthCheckResults parameter' {
            Get-Command Send-ADHealthReport | Should -HaveParameter HealthCheckResults
        }

        It 'Should have To parameter' {
            Get-Command Send-ADHealthReport | Should -HaveParameter To
        }

        It 'Should have From parameter' {
            Get-Command Send-ADHealthReport | Should -HaveParameter From -Type string
        }

        It 'Should have SmtpServer parameter' {
            Get-Command Send-ADHealthReport | Should -HaveParameter SmtpServer -Type string
        }

        It 'Should have Subject parameter' {
            Get-Command Send-ADHealthReport | Should -HaveParameter Subject -Type string
        }

        It 'Should have Credential parameter' {
            Get-Command Send-ADHealthReport | Should -HaveParameter Credential -Type PSCredential
        }
    }

    Context 'Function availability and help' {
        It 'Should have synopsis' {
            $help = Get-Help Send-ADHealthReport
            $help.Synopsis | Should -Not -BeNullOrEmpty
        }

        It 'Should have description' {
            $help = Get-Help Send-ADHealthReport
            $help.Description | Should -Not -BeNullOrEmpty
        }

        It 'Should have examples' {
            $help = Get-Help Send-ADHealthReport
            $help.Examples.Example.Count | Should -BeGreaterThan 0
        }

        It 'Should have CmdletBinding attribute' {
            $command = Get-Command Send-ADHealthReport
            $command.CmdletBinding | Should -Be $true
        }
    }

    Context 'Function design validation' {
        It 'Should follow Verb-Noun naming convention' {
            Get-Command Send-ADHealthReport | Should -Not -BeNullOrEmpty
        }

        It 'Should be exported from module' {
            $exported = Get-Command -Module AdMonitoring
            $exported.Name | Should -Contain 'Send-ADHealthReport'
        }

        It 'Should use approved PowerShell verb' {
            $verb = (Get-Command Send-ADHealthReport).Verb
            $approvedVerbs = Get-Verb | Select-Object -ExpandProperty Verb
            $approvedVerbs | Should -Contain $verb
        }
    }
}
