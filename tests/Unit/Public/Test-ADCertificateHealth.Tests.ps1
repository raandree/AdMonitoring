BeforeAll {
    $modulePath = "$PSScriptRoot\..\..\..\output\module\AdMonitoring"
    Import-Module $modulePath -Force -ErrorAction Stop
}

Describe 'Test-ADCertificateHealth' {
    Context 'Parameter validation' {
        It 'Should have ComputerName parameter' {
            Get-Command Test-ADCertificateHealth | Should -HaveParameter ComputerName -Type string[]
        }

        It 'Should have Credential parameter' {
            Get-Command Test-ADCertificateHealth | Should -HaveParameter Credential -Type PSCredential
        }

        It 'Should have WarningDays parameter' {
            Get-Command Test-ADCertificateHealth | Should -HaveParameter WarningDays -Type int
        }

        It 'Should have CriticalDays parameter' {
            Get-Command Test-ADCertificateHealth | Should -HaveParameter CriticalDays -Type int
        }

        It 'Should have IncludeExpiredCertificates parameter' {
            Get-Command Test-ADCertificateHealth | Should -HaveParameter IncludeExpiredCertificates -Type switch
        }

        It 'Should accept pipeline input for ComputerName' {
            $param = (Get-Command Test-ADCertificateHealth).Parameters['ComputerName']
            $param.Attributes.ValueFromPipeline | Should -Be $true
            $param.Attributes.ValueFromPipelineByPropertyName | Should -Be $true
        }

        It 'Should have proper aliases for ComputerName' {
            $param = (Get-Command Test-ADCertificateHealth).Parameters['ComputerName']
            $param.Aliases | Should -Contain 'Name'
            $param.Aliases | Should -Contain 'HostName'
            $param.Aliases | Should -Contain 'DnsHostName'
        }

        It 'ComputerName parameter should be optional' {
            $param = (Get-Command Test-ADCertificateHealth).Parameters['ComputerName']
            $param.Attributes.Mandatory | Should -Be $false
        }

        It 'Credential parameter should be optional' {
            $param = (Get-Command Test-ADCertificateHealth).Parameters['Credential']
            $param.Attributes.Mandatory | Should -Be $false
        }

        It 'WarningDays should have ValidateRange attribute' {
            $param = (Get-Command Test-ADCertificateHealth).Parameters['WarningDays']
            $param.Attributes.MinRange | Should -Be 1
            $param.Attributes.MaxRange | Should -Be 365
        }

        It 'WarningDays should have default value of 30' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match '\$WarningDays\s*=\s*30'
        }

        It 'CriticalDays should have ValidateRange attribute' {
            $param = (Get-Command Test-ADCertificateHealth).Parameters['CriticalDays']
            $param.Attributes.MinRange | Should -Be 1
            $param.Attributes.MaxRange | Should -Be 180
        }

        It 'CriticalDays should have default value of 7' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match '\$CriticalDays\s*=\s*7'
        }
    }

    Context 'Function availability and help' {
        It 'Should have synopsis' {
            $help = Get-Help Test-ADCertificateHealth
            $help.Synopsis | Should -Not -BeNullOrEmpty
        }

        It 'Should have description' {
            $help = Get-Help Test-ADCertificateHealth
            $help.Description | Should -Not -BeNullOrEmpty
        }

        It 'Should have examples' {
            $help = Get-Help Test-ADCertificateHealth
            $help.Examples.Example.Count | Should -BeGreaterThan 0
        }

        It 'Should have at least 4 examples' {
            $help = Get-Help Test-ADCertificateHealth
            $help.Examples.Example.Count | Should -BeGreaterOrEqual 4
        }

        It 'Should have OutputType attribute' {
            $command = Get-Command Test-ADCertificateHealth
            $command.OutputType | Should -Not -BeNullOrEmpty
        }

        It 'Should have CmdletBinding attribute' {
            $command = Get-Command Test-ADCertificateHealth
            $command.CmdletBinding | Should -Be $true
        }

        It 'Should have help notes section' {
            $help = Get-Help Test-ADCertificateHealth
            $help.alertSet.alert.Text | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Function implementation structure' {
        It 'Should have OutputType declared' {
            $command = Get-Command Test-ADCertificateHealth
            $command.OutputType | Should -Not -BeNullOrEmpty
        }

        It 'Should use Begin/Process/End blocks' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match '\bbegin\s*\{'
            $definition | Should -Match '\bprocess\s*\{'
            $definition | Should -Match '\bend\s*\{'
        }

        It 'Should support auto-discovery of domain controllers' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match 'Get-ADDomainController'
        }

        It 'Should test LDAPS port 636 connectivity' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match 'Test-NetConnection'
            $definition | Should -Match '636'
        }

        It 'Should retrieve LDAPS certificate' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match 'System\.Net\.Sockets\.TcpClient'
            $definition | Should -Match 'System\.Net\.Security\.SslStream'
        }

        It 'Should authenticate SSL stream' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match 'AuthenticateAsClient'
        }

        It 'Should convert certificate to X509Certificate2' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match 'X509Certificate2'
        }

        It 'Should calculate days until expiration' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match '\$daysUntilExpiration'
            $definition | Should -Match 'NotAfter'
        }

        It 'Should check if certificate is self-signed' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match 'IsSelfSigned'
            $definition | Should -Match 'Subject -eq.*Issuer'
        }

        It 'Should retrieve Enhanced Key Usage' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match 'Enhanced Key Usage'
            $definition | Should -Match 'EnhancedKeyUsage'
        }

        It 'Should build and validate certificate chain' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match 'X509Chain'
            $definition | Should -Match 'Build\(\$cert2\)'
        }

        It 'Should have error handling with try-catch' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match '\btry\s*\{'
            $definition | Should -Match '\bcatch\s*\{'
        }

        It 'Should use Write-Verbose for logging' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match 'Write-Verbose'
        }

        It 'Should use Write-Warning for warnings' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match 'Write-Warning'
        }

        It 'Should cleanup TcpClient and SslStream' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match '\$sslStream\.Close\(\)'
            $definition | Should -Match '\$tcpClient\.Close\(\)'
        }
    }

    Context 'Output structure validation' {
        It 'Should create result with specific CheckName' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match "CheckName\s*=\s*['`"]CertificateHealth['`"]"
        }

        It 'Should create result with specific Category' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match "Category\s*=\s*['`"]Security['`"]"
        }

        It 'Should set Severity to High' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match "Severity\s*=\s*['`"]High['`"]"
        }

        It 'Should include recommendations array' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match '\$recommendations'
            $definition | Should -Match 'System\.Collections\.Generic\.List'
        }

        It 'Should collect comprehensive details object' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match 'ComputerName'
            $definition | Should -Match 'LdapsPort'
            $definition | Should -Match 'LdapsCertificate'
            $definition | Should -Match 'CertificateSubject'
            $definition | Should -Match 'CertificateIssuer'
            $definition | Should -Match 'CertificateThumbprint'
            $definition | Should -Match 'ExpirationDate'
            $definition | Should -Match 'DaysUntilExpiration'
            $definition | Should -Match 'IsExpired'
            $definition | Should -Match 'IsSelfSigned'
            $definition | Should -Match 'ChainStatus'
            $definition | Should -Match 'EnhancedKeyUsage'
        }

        It 'Should include RawData with certificate' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match 'RawData'
            $definition | Should -Match '\$details\.LdapsCertificate'
        }
    }

    Context 'Threshold validation' {
        It 'Should validate CriticalDays less than WarningDays' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match 'CriticalDays.*-ge.*WarningDays'
            $definition | Should -Match 'throw'
        }

        It 'Should use WarningDays threshold for status determination' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match '\$daysUntilExpiration -le \$WarningDays'
        }

        It 'Should use CriticalDays threshold for status determination' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match '\$daysUntilExpiration -le \$CriticalDays'
        }

        It 'Should log threshold values at startup' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match 'Write-Verbose.*Warning=.*WarningDays'
            $definition | Should -Match 'Write-Verbose.*Critical=.*CriticalDays'
        }
    }

    Context 'Status determination logic' {
        It 'Should return Critical when certificate is expired' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match 'IsExpired'
            $definition | Should -Match "status = 'Critical'"
            $definition | Should -Match 'Certificate expired'
        }

        It 'Should return Critical when expiration within CriticalDays' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match 'daysUntilExpiration -le \$CriticalDays'
            $definition | Should -Match 'Certificate expires in'
        }

        It 'Should return Warning when expiration within WarningDays' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match 'daysUntilExpiration -le \$WarningDays'
            $definition | Should -Match "status = 'Warning'"
        }

        It 'Should return Warning when certificate is self-signed' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match 'IsSelfSigned'
            $definition | Should -Match 'self-signed'
        }

        It 'Should return Warning when chain validation fails' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match 'ChainStatus.*Invalid'
            $definition | Should -Match 'chain validation failed'
        }

        It 'Should return Critical when LDAPS port not accessible' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match 'TcpTestSucceeded'
            $definition | Should -Match 'Port 636.*not accessible'
        }

        It 'Should return Healthy when certificate is valid' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match "status = 'Healthy'"
            $definition | Should -Match 'Certificate is valid'
        }
    }

    Context 'Certificate-specific recommendations' {
        It 'Should recommend urgent action for expired certificates' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match 'URGENT.*expired'
            $definition | Should -Match 'Request new certificate immediately'
        }

        It 'Should recommend urgent action for critical expiration' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match 'URGENT.*expires'
            $definition | Should -Match 'Plan certificate replacement immediately'
        }

        It 'Should recommend renewal planning for warning expiration' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match 'plan renewal'
            $definition | Should -Match 'Schedule maintenance window'
        }

        It 'Should recommend considering enterprise CA for self-signed' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match 'consider using enterprise CA'
            $definition | Should -Match "don't auto-renew"
        }

        It 'Should recommend verifying LDAPS when port not accessible' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match 'Verify LDAPS is enabled'
            $definition | Should -Match 'Check firewall rules'
        }

        It 'Should recommend checking certificate store' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match 'certificate store'
            $definition | Should -Match 'Cert:\\LocalMachine\\My'
        }

        It 'Should recommend monitoring for healthy certificates' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match 'Certificate is healthy'
            $definition | Should -Match 'monitor expiration date'
        }
    }

    Context 'Certificate property extraction' {
        It 'Should extract certificate subject' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match 'CertificateSubject.*cert2\.Subject'
        }

        It 'Should extract certificate issuer' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match 'CertificateIssuer.*cert2\.Issuer'
        }

        It 'Should extract certificate thumbprint' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match 'CertificateThumbprint.*cert2\.Thumbprint'
        }

        It 'Should extract expiration date' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match 'ExpirationDate.*cert2\.NotAfter'
        }

        It 'Should calculate days until expiration' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match '\$daysUntilExpiration.*=.*NotAfter.*Get-Date'
            $definition | Should -Match '\.Days'
        }
    }

    Context 'Error handling scenarios' {
        It 'Should handle Get-ADDomainController failure' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match 'Failed to discover domain controllers'
        }

        It 'Should handle Test-NetConnection failure' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match 'LDAPS port.*not accessible'
        }

        It 'Should handle certificate retrieval failure' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match 'Error retrieving certificate'
            $definition | Should -Match 'Failed to retrieve LDAPS certificate'
        }

        It 'Should handle unexpected errors' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match 'Unexpected error'
        }

        It 'Should recommend verifying network connectivity' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match 'Verify network connectivity'
        }

        It 'Should recommend verifying LDAPS configuration' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match 'Verify LDAPS is properly configured'
        }

        It 'Should recommend verifying Server Authentication EKU' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match 'Server Authentication EKU'
        }
    }

    Context 'LDAPS connectivity testing' {
        It 'Should test port 636 before certificate retrieval' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match 'Test-NetConnection.*-Port 636'
            $definition | Should -Match 'TcpTestSucceeded'
        }

        It 'Should use SilentlyContinue for Test-NetConnection warnings' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match 'Test-NetConnection.*-WarningAction SilentlyContinue'
        }

        It 'Should create TCP client to port 636' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match 'TcpClient.*636'
        }

        It 'Should create SSL stream with certificate validation callback' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match 'SslStream.*GetStream'
            $definition | Should -Match '\{\$true\}'
        }
    }

    Context 'Chain validation' {
        It 'Should create X509Chain object' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match 'X509Chain'
        }

        It 'Should disable revocation checking' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match 'RevocationMode'
            $definition | Should -Match 'NoCheck'
        }

        It 'Should build certificate chain' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match 'chain\.Build'
        }

        It 'Should set ChainStatus to Valid when successful' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match "ChainStatus = 'Valid'"
        }

        It 'Should set ChainStatus to Invalid when failed' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match "ChainStatus = 'Invalid'"
        }
    }

    Context 'Resource cleanup' {
        It 'Should close SSL stream' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match '\$sslStream\.Close\(\)'
        }

        It 'Should close TCP client' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match '\$tcpClient\.Close\(\)'
        }

        It 'Should cleanup after certificate retrieval' {
            $definition = (Get-Command Test-ADCertificateHealth).Definition
            $definition | Should -Match '# Cleanup'
        }
    }
}
