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
            # Mock Get-Service to return healthy services
            Mock -CommandName Get-Service -ModuleName AdMonitoring {
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
            $result = Get-ADServiceStatus
            $result.Status | Should -Be 'Healthy'
        }
        
        It 'Should return HealthCheckResult object' {
            $result = Get-ADServiceStatus
            $result | Should -BeOfType [HealthCheckResult]
        }
        
        It 'Should have correct category' {
            $result = Get-ADServiceStatus
            $result.Category | Should -Be 'Service Status'
        }
        
        It 'Should include all healthy services in data' {
            $result = Get-ADServiceStatus
            $result.Data.HealthyServices.Count | Should -Be 5
        }
        
        It 'Should have no stopped services' {
            $result = Get-ADServiceStatus
            $result.Data.StoppedServices.Count | Should -Be 0
        }
        
        It 'Should write verbose output when -Verbose is used' {
            $verboseOutput = Get-ADServiceStatus -ComputerName 'DC01' -Verbose 4>&1
            $verboseOutput | Should -Not -BeNullOrEmpty
        }
    }
    
    Context 'When services are stopped' {
        BeforeAll {
                        Mock -CommandName Get-Service -ModuleName AdMonitoring {
                @(
                    [PSCustomObject]@{ Name = 'NTDS'; Status = 'Stopped'; StartType = 'Automatic' }
                    [PSCustomObject]@{ Name = 'KDC'; Status = 'Running'; StartType = 'Automatic' }
                    [PSCustomObject]@{ Name = 'DNS'; Status = 'Running'; StartType = 'Automatic' }
                    [PSCustomObject]@{ Name = 'Netlogon'; Status = 'Running'; StartType = 'Automatic' }
                    [PSCustomObject]@{ Name = 'ADWS'; Status = 'Running'; StartType = 'Automatic' }
                )
            }
        }
        
        It 'Should return Critical status' {
            $result = Get-ADServiceStatus
            $result.Status | Should -Be 'Critical'
        }
        
        It 'Should identify stopped service' {
            $result = Get-ADServiceStatus
            $result.Data.StoppedServices | Should -Contain 'NTDS (Stopped)'
        }
        
        It 'Should provide remediation guidance' {
            $result = Get-ADServiceStatus
            $result.Remediation | Should -Not -BeNullOrEmpty
        }
        
        It 'Should include error details in message' {
            $result = Get-ADServiceStatus
            $result.Message | Should -Match 'Critical services not running'
        }
    }
    
    Context 'When services have manual startup' {
        BeforeAll {
                        Mock -CommandName Get-Service -ModuleName AdMonitoring {
                @(
                    [PSCustomObject]@{ Name = 'NTDS'; Status = 'Running'; StartType = 'Automatic' }
                    [PSCustomObject]@{ Name = 'KDC'; Status = 'Running'; StartType = 'Automatic' }
                    [PSCustomObject]@{ Name = 'DNS'; Status = 'Running'; StartType = 'Manual' }
                    [PSCustomObject]@{ Name = 'Netlogon'; Status = 'Running'; StartType = 'Automatic' }
                    [PSCustomObject]@{ Name = 'ADWS'; Status = 'Running'; StartType = 'Automatic' }
                )
            }
        }
        
        It 'Should return Warning status' {
            $result = Get-ADServiceStatus
            $result.Status | Should -Be 'Warning'
        }
        
        It 'Should identify manual startup service' {
            $result = Get-ADServiceStatus
            $result.Data.ManualServices | Should -Contain 'DNS (Manual)'
        }
    }
    
    Context 'When specifying multiple computers' {
        BeforeAll {
            Mock -CommandName Get-Service -ModuleName AdMonitoring {
                param($ComputerName)
                @(
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
    
    Context 'When connection fails' {
        BeforeAll {
                        Mock -CommandName Get-Service -ModuleName AdMonitoring {
                throw "RPC server is unavailable"
            }
        }
        
        It 'Should return Unknown status on error' {
            $result = Get-ADServiceStatus -ComputerName 'DC01' -ErrorAction SilentlyContinue
            $result.Status | Should -Be 'Unknown'
        }
        
        It 'Should provide connectivity remediation' {
            $result = Get-ADServiceStatus -ComputerName 'DC01' -ErrorAction SilentlyContinue
            $result.Remediation | Should -Match 'network connectivity'
        }
        
        It 'Should capture error message' {
            $result = Get-ADServiceStatus -ComputerName 'DC01' -ErrorAction SilentlyContinue
            $result.Message | Should -Match 'Failed to retrieve service status'
        }
    }
    
    Context 'Pipeline Input' {
        BeforeAll {
            Mock -CommandName Get-Service -ModuleName AdMonitoring {
                @(
                    [PSCustomObject]@{ Name = 'NTDS'; Status = 'Running'; StartType = 'Automatic' }
                    [PSCustomObject]@{ Name = 'KDC'; Status = 'Running'; StartType = 'Automatic' }
                    [PSCustomObject]@{ Name = 'DNS'; Status = 'Running'; StartType = 'Automatic' }
                    [PSCustomObject]@{ Name = 'Netlogon'; Status = 'Running'; StartType = 'Automatic' }
                    [PSCustomObject]@{ Name = 'ADWS'; Status = 'Running'; StartType = 'Automatic' }
                )
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
}
