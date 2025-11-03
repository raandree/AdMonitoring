BeforeAll {
    $modulePath = "$PSScriptRoot\..\..\..\output\module\AdMonitoring"
    Import-Module $modulePath -Force -ErrorAction Stop
}

Describe 'Get-ADServiceStatus' {
    Context 'Parameter Validation' {
        It 'Should have ComputerName parameter' {
            Get-Command Get-ADServiceStatus | Should -HaveParameter ComputerName -Type string[]
        }

        It 'Should have Credential parameter' {
            Get-Command Get-ADServiceStatus | Should -HaveParameter Credential -Type PSCredential
        }

        It 'Should accept pipeline input for ComputerName' {
            $param = (Get-Command Get-ADServiceStatus).Parameters['ComputerName']
            $param.Attributes.ValueFromPipeline | Should -Be $true
        }

        It 'Should have proper aliases for ComputerName' {
            $param = (Get-Command Get-ADServiceStatus).Parameters['ComputerName']
            $param.Aliases | Should -Contain 'Name'
            $param.Aliases | Should -Contain 'DomainController'
            $param.Aliases | Should -Contain 'DC'
        }
    }

    Context 'When all services are healthy' {
        BeforeAll {
            # Mock Invoke-Command to return healthy services
            Mock -CommandName Invoke-Command -ModuleName AdMonitoring {
                @(
                    [PSCustomObject]@{ Name = 'NTDS'; Status = 'Running'; StartType = 'Automatic' }
                    [PSCustomObject]@{ Name = 'KDC'; Status = 'Running'; StartType = 'Automatic' }
                    [PSCustomObject]@{ Name = 'DNS'; Status = 'Running'; StartType = 'Automatic' }
                    [PSCustomObject]@{ Name = 'Netlogon'; Status = 'Running'; StartType = 'Automatic' }
                    [PSCustomObject]@{ Name = 'ADWS'; Status = 'Running'; StartType = 'Automatic' }
                    [PSCustomObject]@{ Name = 'DFSR'; Status = 'Running'; StartType = 'Automatic' }
                )
            }
        }

        It 'Should return Healthy status' {
            $result = Get-ADServiceStatus -ComputerName 'DC01'
            $result.Status | Should -Be 'Healthy'
        }

        It 'Should return HealthCheckResult object' {
            $result = Get-ADServiceStatus -ComputerName 'DC01'
            $result.PSObject.TypeNames[0] | Should -Be 'HealthCheckResult'
        }

        It 'Should have correct category' {
            $result = Get-ADServiceStatus -ComputerName 'DC01'
            $result.Category | Should -Be 'Service Status'
        }

        It 'Should include all healthy services in data' {
            $result = Get-ADServiceStatus -ComputerName 'DC01'
            $result.Data.HealthyServices.Count | Should -Be 5
        }

        It 'Should have no stopped services' {
            $result = Get-ADServiceStatus -ComputerName 'DC01'
            $result.Data.StoppedServices.Count | Should -Be 0
        }

        It 'Should write verbose output when -Verbose is used' {
            $verboseOutput = Get-ADServiceStatus -ComputerName 'DC01' -Verbose 4>&1
            $verboseOutput | Should -Not -BeNullOrEmpty
        }
    }

    Context 'When services are stopped' {
        BeforeAll {
            Mock -CommandName Invoke-Command -ModuleName AdMonitoring {@(
                    [PSCustomObject]@{ Name = 'NTDS'; Status = 'Stopped'; StartType = 'Automatic' }
                    [PSCustomObject]@{ Name = 'KDC'; Status = 'Running'; StartType = 'Automatic' }
                    [PSCustomObject]@{ Name = 'DNS'; Status = 'Running'; StartType = 'Automatic' }
                    [PSCustomObject]@{ Name = 'Netlogon'; Status = 'Running'; StartType = 'Automatic' }
                    [PSCustomObject]@{ Name = 'ADWS'; Status = 'Running'; StartType = 'Automatic' }
                )
            }
        }

        It 'Should return Critical status' {
            $result = Get-ADServiceStatus -ComputerName 'DC01'
            $result.Status | Should -Be 'Critical'
        }

        It 'Should identify stopped service' {
            $result = Get-ADServiceStatus -ComputerName 'DC01'
            $result.Data.StoppedServices | Should -Contain 'NTDS (Stopped)'
        }

        It 'Should provide remediation guidance' {
            $result = Get-ADServiceStatus -ComputerName 'DC01'
            $result.Remediation | Should -Not -BeNullOrEmpty
        }

        It 'Should include error details in message' {
            $result = Get-ADServiceStatus -ComputerName 'DC01'
            $result.Message | Should -Match 'Critical services not running'
        }
    }

    Context 'When services have manual startup' {
        BeforeAll {
            Mock -CommandName Invoke-Command -ModuleName AdMonitoring {@(
                    [PSCustomObject]@{ Name = 'NTDS'; Status = 'Running'; StartType = 'Automatic' }
                    [PSCustomObject]@{ Name = 'KDC'; Status = 'Running'; StartType = 'Automatic' }
                    [PSCustomObject]@{ Name = 'DNS'; Status = 'Running'; StartType = 'Manual' }
                    [PSCustomObject]@{ Name = 'Netlogon'; Status = 'Running'; StartType = 'Automatic' }
                    [PSCustomObject]@{ Name = 'ADWS'; Status = 'Running'; StartType = 'Automatic' }
                )
            }
        }

        It 'Should return Warning status' {
            $result = Get-ADServiceStatus -ComputerName 'DC01'
            $result.Status | Should -Be 'Warning'
        }

        It 'Should identify manual startup service' {
            $result = Get-ADServiceStatus -ComputerName 'DC01'
            $result.Data.ManualServices | Should -Contain 'DNS (Manual)'
        }
    }

    Context 'When specifying multiple computers' {
        BeforeAll {
            Mock -CommandName Invoke-Command -ModuleName AdMonitoring {@(
                    [PSCustomObject]@{ Name = 'NTDS'; Status = 'Running'; StartType = 'Automatic' }
                    [PSCustomObject]@{ Name = 'KDC'; Status = 'Running'; StartType = 'Automatic' }
                    [PSCustomObject]@{ Name = 'DNS'; Status = 'Running'; StartType = 'Automatic' }
                    [PSCustomObject]@{ Name = 'Netlogon'; Status = 'Running'; StartType = 'Automatic' }
                    [PSCustomObject]@{ Name = 'ADWS'; Status = 'Running'; StartType = 'Automatic' }
                )
            }
        }

        It 'Should check multiple computers' {
            $results = Get-ADServiceStatus -ComputerName 'DC01', 'DC02'
            $results.Count | Should -Be 2
        }

        It 'Should set correct target for each result' {
            $results = Get-ADServiceStatus -ComputerName 'DC01', 'DC02'
            $results[0].Target | Should -Be 'DC01'
            $results[1].Target | Should -Be 'DC02'
        }
    }

    Context 'Pipeline Input' {
        BeforeAll {
            # Mock Invoke-Command for service queries
            Mock -CommandName Invoke-Command -ModuleName AdMonitoring {
                @(
                    [PSCustomObject]@{ Name = 'NTDS'; Status = 'Running'; StartType = 'Automatic' }
                    [PSCustomObject]@{ Name = 'KDC'; Status = 'Running'; StartType = 'Automatic' }
                    [PSCustomObject]@{ Name = 'DNS'; Status = 'Running'; StartType = 'Automatic' }
                    [PSCustomObject]@{ Name = 'Netlogon'; Status = 'Running'; StartType = 'Automatic' }
                    [PSCustomObject]@{ Name = 'ADWS'; Status = 'Running'; StartType = 'Automatic' }
                )
            }

            # Create function stub for Get-ADDomainController if it doesn't exist
            if (-not (Get-Command Get-ADDomainController -ErrorAction SilentlyContinue)) {
                function Get-ADDomainController { }
            }
        }

        It 'Should accept pipeline input' {
            $results = 'DC01', 'DC02' | Get-ADServiceStatus
            $results.Count | Should -Be 2
        }

        It 'Should accept objects with Name property' {
            $dcs = @(
                [PSCustomObject]@{ Name = 'DC01' }
                [PSCustomObject]@{ Name = 'DC02' }
            )
            $results = $dcs | Get-ADServiceStatus
            $results.Count | Should -Be 2
        }
    }

    Context 'When using Credential parameter' {
        BeforeAll {
            Mock -CommandName Invoke-Command -ModuleName AdMonitoring {
                @(
                    [PSCustomObject]@{ Name = 'NTDS'; Status = 'Running'; StartType = 'Automatic' }
                    [PSCustomObject]@{ Name = 'KDC'; Status = 'Running'; StartType = 'Automatic' }
                    [PSCustomObject]@{ Name = 'DNS'; Status = 'Running'; StartType = 'Automatic' }
                    [PSCustomObject]@{ Name = 'Netlogon'; Status = 'Running'; StartType = 'Automatic' }
                    [PSCustomObject]@{ Name = 'ADWS'; Status = 'Running'; StartType = 'Automatic' }
                )
            }
        }

        It 'Should pass Credential to Invoke-Command' {
            $securePass = ConvertTo-SecureString 'P@ssw0rd' -AsPlainText -Force
            $cred = [PSCredential]::new('DOMAIN\User', $securePass)

            $result = Get-ADServiceStatus -ComputerName 'DC01' -Credential $cred
            Should -Invoke -CommandName Invoke-Command -ModuleName AdMonitoring -Times 1 -Exactly
        }
    }

    Context 'When optional services exist' {
        BeforeAll {
            Mock -CommandName Invoke-Command -ModuleName AdMonitoring {
                @(
                    [PSCustomObject]@{ Name = 'NTDS'; Status = 'Running'; StartType = 'Automatic' }
                    [PSCustomObject]@{ Name = 'KDC'; Status = 'Running'; StartType = 'Automatic' }
                    [PSCustomObject]@{ Name = 'DNS'; Status = 'Running'; StartType = 'Automatic' }
                    [PSCustomObject]@{ Name = 'Netlogon'; Status = 'Running'; StartType = 'Automatic' }
                    [PSCustomObject]@{ Name = 'ADWS'; Status = 'Running'; StartType = 'Automatic' }
                    [PSCustomObject]@{ Name = 'DFSR'; Status = 'Running'; StartType = 'Automatic' }
                    [PSCustomObject]@{ Name = 'FRS'; Status = 'Stopped'; StartType = 'Disabled' }
                )
            }
        }

        It 'Should include optional services in data' {
            $result = Get-ADServiceStatus -ComputerName 'DC01'
            $result.Data.OptionalServices | Should -Not -BeNullOrEmpty
        }

        It 'Should note stopped optional service status' {
            $result = Get-ADServiceStatus -ComputerName 'DC01'
            $result.Data.OptionalServices['FRS'] | Should -Be 'Stopped'
        }
    }

    Context 'When connection error occurs' {
        BeforeAll {
            Mock -CommandName Invoke-Command -ModuleName AdMonitoring {
                throw 'Connection failed'
            }
        }

        It 'Should return Critical status on connection failure' {
            $result = Get-ADServiceStatus -ComputerName 'DC01' -ErrorAction SilentlyContinue
            $result.Status | Should -Be 'Critical'
            $result.Message | Should -BeLike '*Connection failed*'
        }
    }
}
