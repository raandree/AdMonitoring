BeforeAll {
    $modulePath = "$PSScriptRoot\..\..\..\output\module\AdMonitoring"
    Import-Module $modulePath -Force -ErrorAction Stop
}

Describe 'Test-ADSecurityHealth' {
    Context 'Parameter validation' {
        It 'Should have ComputerName parameter' {
            Get-Command Test-ADSecurityHealth | Should -HaveParameter ComputerName -Type string[]
        }

        It 'Should have Credential parameter' {
            Get-Command Test-ADSecurityHealth | Should -HaveParameter Credential -Type PSCredential
        }

        It 'Should have Hours parameter' {
            Get-Command Test-ADSecurityHealth | Should -HaveParameter Hours -Type int
        }

        It 'Should have LockoutThreshold parameter' {
            Get-Command Test-ADSecurityHealth | Should -HaveParameter LockoutThreshold -Type int
        }

        It 'Should have FailedAuthThreshold parameter' {
            Get-Command Test-ADSecurityHealth | Should -HaveParameter FailedAuthThreshold -Type int
        }

        It 'Should accept pipeline input for ComputerName' {
            $param = (Get-Command Test-ADSecurityHealth).Parameters['ComputerName']
            $param.Attributes.ValueFromPipeline | Should -Be $true
            $param.Attributes.ValueFromPipelineByPropertyName | Should -Be $true
        }

        It 'Should have proper aliases for ComputerName' {
            $param = (Get-Command Test-ADSecurityHealth).Parameters['ComputerName']
            $param.Aliases | Should -Contain 'Name'
            $param.Aliases | Should -Contain 'HostName'
            $param.Aliases | Should -Contain 'DnsHostName'
        }

        It 'ComputerName parameter should be optional' {
            $param = (Get-Command Test-ADSecurityHealth).Parameters['ComputerName']
            $param.Attributes.Mandatory | Should -Be $false
        }

        It 'Credential parameter should be optional' {
            $param = (Get-Command Test-ADSecurityHealth).Parameters['Credential']
            $param.Attributes.Mandatory | Should -Be $false
        }

        It 'Hours should have ValidateRange attribute' {
            $param = (Get-Command Test-ADSecurityHealth).Parameters['Hours']
            $param.Attributes.MinRange | Should -Be 1
            $param.Attributes.MaxRange | Should -Be 168
        }

        It 'Hours should have default value of 24' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match '\$Hours\s*=\s*24'
        }

        It 'LockoutThreshold should have ValidateRange attribute' {
            $param = (Get-Command Test-ADSecurityHealth).Parameters['LockoutThreshold']
            $param.Attributes.MinRange | Should -Be 1
            $param.Attributes.MaxRange | Should -Be 100
        }

        It 'LockoutThreshold should have default value of 10' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match '\$LockoutThreshold\s*=\s*10'
        }

        It 'FailedAuthThreshold should have ValidateRange attribute' {
            $param = (Get-Command Test-ADSecurityHealth).Parameters['FailedAuthThreshold']
            $param.Attributes.MinRange | Should -Be 1
            $param.Attributes.MaxRange | Should -Be 1000
        }

        It 'FailedAuthThreshold should have default value of 50' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match '\$FailedAuthThreshold\s*=\s*50'
        }
    }

    Context 'Function availability and help' {
        It 'Should have synopsis' {
            $help = Get-Help Test-ADSecurityHealth
            $help.Synopsis | Should -Not -BeNullOrEmpty
        }

        It 'Should have description' {
            $help = Get-Help Test-ADSecurityHealth
            $help.Description | Should -Not -BeNullOrEmpty
        }

        It 'Should have examples' {
            $help = Get-Help Test-ADSecurityHealth
            $help.Examples.Example.Count | Should -BeGreaterThan 0
        }

        It 'Should have at least 4 examples' {
            $help = Get-Help Test-ADSecurityHealth
            $help.Examples.Example.Count | Should -BeGreaterOrEqual 4
        }

        It 'Should have OutputType attribute' {
            $command = Get-Command Test-ADSecurityHealth
            $command.OutputType | Should -Not -BeNullOrEmpty
        }

        It 'Should have CmdletBinding attribute' {
            $command = Get-Command Test-ADSecurityHealth
            $command.CmdletBinding | Should -Be $true
        }

        It 'Should have help notes section' {
            $help = Get-Help Test-ADSecurityHealth
            $help.alertSet.alert.Text | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Function implementation structure' {
        It 'Should have OutputType declared' {
            $command = Get-Command Test-ADSecurityHealth
            $command.OutputType | Should -Not -BeNullOrEmpty
        }

        It 'Should use Begin/Process/End blocks' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match '\bbegin\s*\{'
            $definition | Should -Match '\bprocess\s*\{'
            $definition | Should -Match '\bend\s*\{'
        }

        It 'Should support auto-discovery of domain controllers' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match 'Get-ADDomainController'
        }

        It 'Should test secure channel status' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match 'Test-ComputerSecureChannel'
        }

        It 'Should check trust relationships' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match 'Get-ADTrust'
        }

        It 'Should scan security event logs' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match 'Get-WinEvent'
            $definition | Should -Match "LogName\s*=\s*['`"]Security['`"]"
        }

        It 'Should monitor account lockout events' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match '4740'
            $definition | Should -Match 'AccountLockouts'
        }

        It 'Should monitor failed authentication events' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match '4625'
            $definition | Should -Match 'FailedAuthentications'
        }

        It 'Should monitor Kerberos ticket requests' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match '4768'
            $definition | Should -Match 'KerberosTicketRequests'
        }

        It 'Should monitor NTLM authentication' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match '4776'
            $definition | Should -Match 'NTLMAuthentications'
        }

        It 'Should calculate NTLM usage percentage' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match 'ntlmPercentage'
            $definition | Should -Match '\$totalAuth'
        }

        It 'Should extract top locked accounts' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match 'Top5LockedAccounts'
            $definition | Should -Match 'TargetUserName'
        }

        It 'Should extract top failed auth sources' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match 'Top5FailedAuthSources'
            $definition | Should -Match 'IpAddress'
        }

        It 'Should create security event summary' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match 'SecurityEventSummary'
        }

        It 'Should have error handling with try-catch' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match '\btry\s*\{'
            $definition | Should -Match '\bcatch\s*\{'
        }

        It 'Should use Write-Verbose for logging' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match 'Write-Verbose'
        }

        It 'Should use Write-Warning for warnings' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match 'Write-Warning'
        }

        It 'Should use Invoke-Command for secure channel test' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match 'Invoke-Command'
        }
    }

    Context 'Output structure validation' {
        It 'Should create result with specific CheckName' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match "CheckName\s*=\s*['`"]SecurityHealth['`"]"
        }

        It 'Should create result with specific Category' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match "Category\s*=\s*['`"]Security['`"]"
        }

        It 'Should set Severity to High' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match "Severity\s*=\s*['`"]High['`"]"
        }

        It 'Should include recommendations array' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match '\$recommendations'
            $definition | Should -Match 'System\.Collections\.Generic\.List'
        }

        It 'Should collect comprehensive details object' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match 'ComputerName'
            $definition | Should -Match 'SecureChannelStatus'
            $definition | Should -Match 'TrustRelationships'
            $definition | Should -Match 'TrustsHealthy'
            $definition | Should -Match 'AccountLockouts'
            $definition | Should -Match 'FailedAuthentications'
            $definition | Should -Match 'KerberosTicketRequests'
            $definition | Should -Match 'NTLMAuthentications'
            $definition | Should -Match 'Top5LockedAccounts'
            $definition | Should -Match 'Top5FailedAuthSources'
            $definition | Should -Match 'SecurityEventSummary'
        }

        It 'Should include RawData property' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match 'RawData'
        }
    }

    Context 'Threshold validation' {
        It 'Should use Hours parameter for event scan window' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match 'AddHours\(-\$Hours\)'
        }

        It 'Should use LockoutThreshold for lockout status determination' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match '\$lockoutEvents\.Count -ge \$LockoutThreshold'
        }

        It 'Should use FailedAuthThreshold for failed auth status determination' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match '\$failedAuthEvents\.Count -ge \$FailedAuthThreshold'
        }

        It 'Should log threshold values at startup' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match 'Write-Verbose.*Thresholds'
            $definition | Should -Match 'Lockouts=.*LockoutThreshold'
            $definition | Should -Match 'Failed Auth=.*FailedAuthThreshold'
        }

        It 'Should check NTLM usage percentage threshold' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match 'ntlmPercentage -gt 50'
        }
    }

    Context 'Status determination logic' {
        It 'Should return Critical when secure channel is broken' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match "SecureChannelStatus = 'Broken'"
            $definition | Should -Match "status = 'Critical'"
            $definition | Should -Match 'Secure channel is broken'
        }

        It 'Should return Critical when trusts are unhealthy' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match 'unhealthyTrusts'
            $definition | Should -Match 'trust relationships are broken'
        }

        It 'Should return Warning when excessive lockouts detected' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match 'Excessive account lockouts detected'
        }

        It 'Should return Warning when excessive failed auths detected' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match 'Excessive failed authentication attempts'
        }

        It 'Should return Warning when high NTLM usage detected' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match 'High NTLM authentication usage'
            $definition | Should -Match 'High NTLM usage detected'
        }

        It 'Should return Warning when cannot scan event logs' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match 'Unable to scan security event logs'
        }

        It 'Should return Healthy when security is good' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match "status = 'Healthy'"
            $definition | Should -Match 'Security health is good'
        }
    }

    Context 'Security-specific recommendations' {
        It 'Should recommend secure channel reset for broken channel' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match 'URGENT.*Reset secure channel'
            $definition | Should -Match 'nltest /sc_reset'
        }

        It 'Should recommend trust investigation' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match 'Investigate trust relationship'
            $definition | Should -Match 'netdom trust.*verify'
        }

        It 'Should recommend lockout investigation' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match 'Investigate.*account lockout events'
            $definition | Should -Match 'Review lockout policy'
            $definition | Should -Match 'password spray or brute force'
        }

        It 'Should recommend failed auth investigation' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match 'Investigate.*failed authentication attempts'
            $definition | Should -Match 'brute force or password spray'
            $definition | Should -Match 'Review IP addresses and user accounts'
        }

        It 'Should recommend NTLM investigation' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match 'Investigate applications using NTLM'
            $definition | Should -Match 'NTLM audit mode'
        }

        It 'Should recommend event log access verification' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match 'Verify remote event log access permissions'
            $definition | Should -Match 'Check firewall rules allow event log access'
        }

        It 'Should recommend security monitoring for healthy state' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match 'Security health is good - continue monitoring'
            $definition | Should -Match 'Review security event logs regularly'
            $definition | Should -Match 'Maintain strong password policies'
        }
    }

    Context 'Secure channel testing' {
        It 'Should use Test-ComputerSecureChannel cmdlet' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match 'Test-ComputerSecureChannel'
        }

        It 'Should use Invoke-Command for remote execution' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match 'Invoke-Command @invokeParams'
        }

        It 'Should handle secure channel test success' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match "SecureChannelStatus = 'Healthy'"
        }

        It 'Should handle secure channel test failure' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match "SecureChannelStatus = 'Broken'"
        }

        It 'Should handle secure channel test error' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match "SecureChannelStatus = 'Error'"
        }
    }

    Context 'Trust relationship validation' {
        It 'Should query trust relationships with Get-ADTrust' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match 'Get-ADTrust -Filter'
        }

        It 'Should check trust attributes for health' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match 'TrustAttributes -band'
            $definition | Should -Match '0x00000020'
        }

        It 'Should create trust relationship objects' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match 'Name\s*='
            $definition | Should -Match 'Direction\s*='
            $definition | Should -Match 'TrustType\s*='
            $definition | Should -Match 'Healthy\s*='
        }

        It 'Should identify unhealthy trusts' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match 'unhealthyTrusts'
            $definition | Should -Match 'Where-Object.*-not.*Healthy'
        }

        It 'Should handle single domain forests' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match 'No trust relationships found'
        }
    }

    Context 'Event log scanning' {
        It 'Should scan Security event log' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match "LogName\s*=\s*['`"]Security['`"]"
        }

        It 'Should use FilterHashtable for efficiency' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match 'FilterHashtable'
        }

        It 'Should apply StartTime filter' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match 'StartTime\s*=\s*\$startTime'
        }

        It 'Should filter for Event ID 4740 (lockouts) in FilterHashtable' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match "Id\s*=\s*4740"
        }

        It 'Should filter for Event ID 4625 (failed auth) in FilterHashtable' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match "Id\s*=\s*4625"
        }

        It 'Should filter for Event ID 4768 (Kerberos) in FilterHashtable' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match "Id\s*=\s*4768"
        }

        It 'Should filter for Event ID 4776 (NTLM) in FilterHashtable' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match "Id\s*=\s*4776"
        }

        It 'Should NOT use Where-Object for Event ID filtering' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Not -Match 'Get-WinEvent.*\|.*Where-Object.*\.Id -eq'
        }

        It 'Should use efficient FilterHashtable-based filtering' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            # Verify we're using FilterHashtable with Id property for each event type
            $definition | Should -Match "FilterHashtable.*=.*@\{"
            $definition | Should -Match "Id\s*=\s*4740"  # Lockout events
            $definition | Should -Match "Id\s*=\s*4625"  # Failed auth events
            $definition | Should -Match "Id\s*=\s*4768"  # Kerberos events
            $definition | Should -Match "Id\s*=\s*4776"  # NTLM events
        }
    }

    Context 'Event data extraction' {
        It 'Should parse XML event data' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match '\[xml\].*ToXml'
        }

        It 'Should extract TargetUserName from lockout events' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match "Name -eq 'TargetUserName'"
        }

        It 'Should extract IpAddress from failed auth events' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match "Name -eq 'IpAddress'"
        }

        It 'Should group and count locked accounts' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match 'Group-Object'
            $definition | Should -Match 'Sort-Object Count -Descending'
        }

        It 'Should limit to top 5 locked accounts' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match 'Select-Object -First 5'
        }

        It 'Should filter out empty IP addresses' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match "Where-Object.*-and.*-ne '-'"
        }
    }

    Context 'Credential handling' {
        It 'Should accept Credential parameter' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match '\[PSCredential\]\$Credential'
        }

        It 'Should check if Credential is bound' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match "PSBoundParameters\.ContainsKey\('Credential'\)"
        }

        It 'Should pass credentials to Invoke-Command' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match "invokeParams\['Credential'\]"
        }

        It 'Should pass credentials to Get-WinEvent' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match "eventParams\['Credential'\]"
        }
    }

    Context 'Error handling scenarios' {
        It 'Should handle Get-ADDomainController failure' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match 'Failed to discover domain controllers'
        }

        It 'Should handle secure channel test failure' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match 'Failed to test secure channel'
        }

        It 'Should handle trust check failure' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match 'Failed to check trust relationships'
        }

        It 'Should handle event log scan failure' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match 'Failed to scan security event logs'
        }

        It 'Should handle unexpected errors' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match 'Unexpected error checking security'
        }

        It 'Should recommend verifying connectivity' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match 'Verify network connectivity'
        }

        It 'Should recommend checking WinRM' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match 'Check Windows Remote Management service'
        }
    }

    Context 'NTLM usage analysis' {
        It 'Should calculate total authentication count' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match '\$totalAuth.*kerberosEvents.*ntlmEvents'
        }

        It 'Should calculate NTLM percentage' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match '\$ntlmPercentage.*ntlmEvents.*totalAuth.*100'
        }

        It 'Should check if NTLM percentage exceeds 50%' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match '\$ntlmPercentage -gt 50'
        }

        It 'Should round NTLM percentage for display' {
            $definition = (Get-Command Test-ADSecurityHealth).Definition
            $definition | Should -Match '\[math\]::Round\(\$ntlmPercentage'
        }
    }
}
