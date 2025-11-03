BeforeAll {
    $modulePath = "$PSScriptRoot\..\..\..\output\module\AdMonitoring"
    Import-Module $modulePath -Force -ErrorAction Stop
}

Describe 'Test-ADDomainControllerReachability' {
    Context 'Parameter Validation' {
        It 'Should have ComputerName parameter' {
            Get-Command Test-ADDomainControllerReachability | Should -HaveParameter ComputerName -Type string[]
        }

        It 'Should have IncludeGlobalCatalog parameter' {
            Get-Command Test-ADDomainControllerReachability | Should -HaveParameter IncludeGlobalCatalog -Type bool
        }

        It 'Should have IncludeWinRM parameter' {
            Get-Command Test-ADDomainControllerReachability | Should -HaveParameter IncludeWinRM -Type bool
        }

        It 'Should have Timeout parameter' {
            Get-Command Test-ADDomainControllerReachability | Should -HaveParameter Timeout -Type int
        }

        It 'Should accept pipeline input for ComputerName' {
            $param = (Get-Command Test-ADDomainControllerReachability).Parameters['ComputerName']
            $param.Attributes.ValueFromPipeline | Should -Be $true
        }

        It 'Should have proper aliases for ComputerName' {
            $param = (Get-Command Test-ADDomainControllerReachability).Parameters['ComputerName']
            $param.Aliases | Should -Contain 'Name'
            $param.Aliases | Should -Contain 'DomainController'
            $param.Aliases | Should -Contain 'DC'
        }
    }

    Context 'When all connectivity tests pass' {
        BeforeAll {
            # Mock DNS resolution
            Mock -CommandName Resolve-DnsName -ModuleName AdMonitoring {
                [PSCustomObject]@{
                    Name      = 'DC01.contoso.com'
                    IPAddress = '192.168.1.10'
                }
            }

            # Mock Test-Connection
            Mock -CommandName Test-Connection -ModuleName AdMonitoring { $true }

            # Mock Test-NetConnection for LDAP
            Mock -CommandName Test-NetConnection -ModuleName AdMonitoring {
                param($ComputerName, $Port)
                [PSCustomObject]@{
                    ComputerName     = $ComputerName
                    RemotePort       = $Port
                    TcpTestSucceeded = $true
                }
            }

            # Mock Test-WSMan
            Mock -CommandName Test-WSMan -ModuleName AdMonitoring {
                [PSCustomObject]@{
                    ProductVersion = '3.0'
                }
            }
        }

        It 'Should return Healthy status' {
            $result = Test-ADDomainControllerReachability -ComputerName 'DC01'
            $result.Status | Should -Be 'Healthy'
        }

        It 'Should return HealthCheckResult object' {
            $result = Test-ADDomainControllerReachability -ComputerName 'DC01'
            $result.PSObject.TypeNames[0] | Should -Be 'HealthCheckResult'
        }

        It 'Should have correct category' {
            $result = Test-ADDomainControllerReachability -ComputerName 'DC01'
            $result.Category | Should -Be 'DC Reachability'
        }

        It 'Should show all tests passed in message' {
            $result = Test-ADDomainControllerReachability -ComputerName 'DC01'
            $result.Message | Should -BeLike '*connectivity tests passed*'
        }

        It 'Should include test results in data' {
            $result = Test-ADDomainControllerReachability -ComputerName 'DC01'
            $result.Data.DnsResolution | Should -Be $true
            $result.Data.Ping | Should -Be $true
            $result.Data.LdapConnectivity | Should -Be $true
        }
    }

    Context 'When DNS resolution fails' {
        BeforeAll {
            # Mock DNS resolution failure
            Mock -CommandName Resolve-DnsName -ModuleName AdMonitoring {
                throw 'DNS name not found'
            }
        }

        It 'Should return Critical status' {
            $result = Test-ADDomainControllerReachability -ComputerName 'INVALIDDC' -ErrorAction SilentlyContinue
            $result.Status | Should -Be 'Critical'
        }

        It 'Should indicate DNS resolution failed' {
            $result = Test-ADDomainControllerReachability -ComputerName 'INVALIDDC' -ErrorAction SilentlyContinue
            $result.Message | Should -BeLike '*DNS resolution failed*'
        }

        It 'Should provide remediation guidance' {
            $result = Test-ADDomainControllerReachability -ComputerName 'INVALIDDC' -ErrorAction SilentlyContinue
            $result.Remediation | Should -Not -BeNullOrEmpty
            $result.Remediation | Should -BeLike '*DNS*'
        }
    }

    Context 'When LDAP port is not accessible' {
        BeforeAll {
            # Mock DNS resolution success
            Mock -CommandName Resolve-DnsName -ModuleName AdMonitoring {
                [PSCustomObject]@{
                    Name      = 'DC01.contoso.com'
                    IPAddress = '192.168.1.10'
                }
            }

            # Mock Test-Connection success
            Mock -CommandName Test-Connection -ModuleName AdMonitoring { $true }

            # Mock Test-NetConnection - LDAP fails, GC succeeds
            Mock -CommandName Test-NetConnection -ModuleName AdMonitoring {
                param($ComputerName, $Port)
                [PSCustomObject]@{
                    ComputerName     = $ComputerName
                    RemotePort       = $Port
                    TcpTestSucceeded = ($Port -eq 3268)  # Only GC port succeeds
                }
            }
        }

        It 'Should return Critical status' {
            $result = Test-ADDomainControllerReachability -ComputerName 'DC01' -ErrorAction SilentlyContinue
            $result.Status | Should -Be 'Critical'
        }

        It 'Should indicate LDAP not accessible' {
            $result = Test-ADDomainControllerReachability -ComputerName 'DC01' -ErrorAction SilentlyContinue
            $result.Message | Should -BeLike '*LDAP*not accessible*'
        }
    }

    Context 'When ICMP is blocked but LDAP works' {
        BeforeAll {
            # Mock DNS resolution
            Mock -CommandName Resolve-DnsName -ModuleName AdMonitoring {
                [PSCustomObject]@{
                    Name      = 'DC01.contoso.com'
                    IPAddress = '192.168.1.10'
                }
            }

            # Mock Test-Connection fails
            Mock -CommandName Test-Connection -ModuleName AdMonitoring { $false }

            # Mock Test-NetConnection success
            Mock -CommandName Test-NetConnection -ModuleName AdMonitoring {
                param($ComputerName, $Port)
                [PSCustomObject]@{
                    ComputerName     = $ComputerName
                    RemotePort       = $Port
                    TcpTestSucceeded = $true
                }
            }

            # Mock Test-WSMan success
            Mock -CommandName Test-WSMan -ModuleName AdMonitoring {
                [PSCustomObject]@{
                    ProductVersion = '3.0'
                }
            }
        }

        It 'Should return Warning status' {
            $result = Test-ADDomainControllerReachability -ComputerName 'DC01'
            $result.Status | Should -Be 'Warning'
        }

        It 'Should mention ICMP blocked in warnings' {
            $result = Test-ADDomainControllerReachability -ComputerName 'DC01'
            $result.Data.Warnings | Should -BeLike '*ICMP*'
        }
    }

    Context 'When testing multiple computers' {
        BeforeAll {
            # Mock DNS resolution
            Mock -CommandName Resolve-DnsName -ModuleName AdMonitoring {
                [PSCustomObject]@{
                    Name      = $args[0]
                    IPAddress = '192.168.1.10'
                }
            }

            # Mock Test-Connection
            Mock -CommandName Test-Connection -ModuleName AdMonitoring { $true }

            # Mock Test-NetConnection
            Mock -CommandName Test-NetConnection -ModuleName AdMonitoring {
                param($ComputerName, $Port)
                [PSCustomObject]@{
                    ComputerName     = $ComputerName
                    RemotePort       = $Port
                    TcpTestSucceeded = $true
                }
            }

            # Mock Test-WSMan
            Mock -CommandName Test-WSMan -ModuleName AdMonitoring {
                [PSCustomObject]@{
                    ProductVersion = '3.0'
                }
            }
        }

        It 'Should test multiple computers' {
            $results = Test-ADDomainControllerReachability -ComputerName 'DC01', 'DC02'
            $results.Count | Should -Be 2
        }

        It 'Should set correct target for each result' {
            $results = Test-ADDomainControllerReachability -ComputerName 'DC01', 'DC02'
            $results[0].Target | Should -Be 'DC01'
            $results[1].Target | Should -Be 'DC02'
        }
    }

    Context 'When IncludeGlobalCatalog is false' {
        BeforeAll {
            # Mock DNS resolution
            Mock -CommandName Resolve-DnsName -ModuleName AdMonitoring {
                [PSCustomObject]@{
                    Name      = 'DC01.contoso.com'
                    IPAddress = '192.168.1.10'
                }
            }

            # Mock Test-Connection
            Mock -CommandName Test-Connection -ModuleName AdMonitoring { $true }

            # Mock Test-NetConnection
            Mock -CommandName Test-NetConnection -ModuleName AdMonitoring {
                param($ComputerName, $Port)
                [PSCustomObject]@{
                    ComputerName     = $ComputerName
                    RemotePort       = $Port
                    TcpTestSucceeded = $true
                }
            }

            # Mock Test-WSMan
            Mock -CommandName Test-WSMan -ModuleName AdMonitoring {
                [PSCustomObject]@{
                    ProductVersion = '3.0'
                }
            }
        }

        It 'Should not test GC connectivity' {
            $result = Test-ADDomainControllerReachability -ComputerName 'DC01' -IncludeGlobalCatalog $false
            $result.Data.GCConnectivity | Should -Be 'Not Tested'
        }

        It 'Should not invoke Test-NetConnection for port 3268' {
            Test-ADDomainControllerReachability -ComputerName 'DC01' -IncludeGlobalCatalog $false
            Should -Invoke -CommandName Test-NetConnection -ModuleName AdMonitoring -ParameterFilter { $Port -eq 3268 } -Times 0 -Exactly
        }
    }

    Context 'When IncludeWinRM is false' {
        BeforeAll {
            # Mock DNS resolution
            Mock -CommandName Resolve-DnsName -ModuleName AdMonitoring {
                [PSCustomObject]@{
                    Name      = 'DC01.contoso.com'
                    IPAddress = '192.168.1.10'
                }
            }

            # Mock Test-Connection
            Mock -CommandName Test-Connection -ModuleName AdMonitoring { $true }

            # Mock Test-NetConnection
            Mock -CommandName Test-NetConnection -ModuleName AdMonitoring {
                param($ComputerName, $Port)
                [PSCustomObject]@{
                    ComputerName     = $ComputerName
                    RemotePort       = $Port
                    TcpTestSucceeded = $true
                }
            }

            # Mock Test-WSMan (even though it shouldn't be called)
            Mock -CommandName Test-WSMan -ModuleName AdMonitoring {
                [PSCustomObject]@{
                    ProductVersion = '3.0'
                }
            }
        }

        It 'Should not test WinRM' {
            $result = Test-ADDomainControllerReachability -ComputerName 'DC01' -IncludeWinRM $false
            $result.Data.WinRMConnectivity | Should -Be 'Not Tested'
        }

        It 'Should not invoke Test-WSMan' {
            Test-ADDomainControllerReachability -ComputerName 'DC01' -IncludeWinRM $false
            Should -Invoke -CommandName Test-WSMan -ModuleName AdMonitoring -Times 0 -Exactly
        }
    }

    Context 'Pipeline Input' {
        BeforeAll {
            # Mock DNS resolution
            Mock -CommandName Resolve-DnsName -ModuleName AdMonitoring {
                [PSCustomObject]@{
                    Name      = $args[0]
                    IPAddress = '192.168.1.10'
                }
            }

            # Mock Test-Connection
            Mock -CommandName Test-Connection -ModuleName AdMonitoring { $true }

            # Mock Test-NetConnection
            Mock -CommandName Test-NetConnection -ModuleName AdMonitoring {
                param($ComputerName, $Port)
                [PSCustomObject]@{
                    ComputerName     = $ComputerName
                    RemotePort       = $Port
                    TcpTestSucceeded = $true
                }
            }

            # Mock Test-WSMan
            Mock -CommandName Test-WSMan -ModuleName AdMonitoring {
                [PSCustomObject]@{
                    ProductVersion = '3.0'
                }
            }

            # Create function stub for Get-ADDomainController if it doesn't exist
            if (-not (Get-Command Get-ADDomainController -ErrorAction SilentlyContinue)) {
                function Get-ADDomainController { }
            }
        }

        It 'Should accept pipeline input' {
            $results = 'DC01', 'DC02' | Test-ADDomainControllerReachability
            $results.Count | Should -Be 2
        }

        It 'Should accept objects with Name property' {
            $dcs = @(
                [PSCustomObject]@{ Name = 'DC01' }
                [PSCustomObject]@{ Name = 'DC02' }
            )
            $results = $dcs | Test-ADDomainControllerReachability
            $results.Count | Should -Be 2
        }
    }
}
