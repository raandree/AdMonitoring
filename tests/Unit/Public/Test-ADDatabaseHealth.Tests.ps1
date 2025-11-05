BeforeAll {
    $modulePath = "$PSScriptRoot\..\..\..\output\module\AdMonitoring"
    Import-Module $modulePath -Force -ErrorAction Stop
}

Describe 'Test-ADDatabaseHealth' {
    Context 'Parameter validation' {
        It 'Should have ComputerName parameter' {
            Get-Command Test-ADDatabaseHealth | Should -HaveParameter ComputerName -Type string[]
        }

        It 'Should have Credential parameter' {
            Get-Command Test-ADDatabaseHealth | Should -HaveParameter Credential -Type PSCredential
        }

        It 'Should have FragmentationWarningPercent parameter' {
            $cmd = Get-Command Test-ADDatabaseHealth
            $cmd | Should -HaveParameter FragmentationWarningPercent -Type int
            $cmd.Parameters['FragmentationWarningPercent'].Attributes.MinRange | Should -Be 1
            $cmd.Parameters['FragmentationWarningPercent'].Attributes.MaxRange | Should -Be 100
        }

        It 'Should have FragmentationCriticalPercent parameter' {
            $cmd = Get-Command Test-ADDatabaseHealth
            $cmd | Should -HaveParameter FragmentationCriticalPercent -Type int
            $cmd.Parameters['FragmentationCriticalPercent'].Attributes.MinRange | Should -Be 1
            $cmd.Parameters['FragmentationCriticalPercent'].Attributes.MaxRange | Should -Be 100
        }

        It 'Should have EventHours parameter' {
            $cmd = Get-Command Test-ADDatabaseHealth
            $cmd | Should -HaveParameter EventHours -Type int
            $cmd.Parameters['EventHours'].Attributes.MinRange | Should -Be 1
            $cmd.Parameters['EventHours'].Attributes.MaxRange | Should -Be 168
        }

        It 'Should accept pipeline input for ComputerName' {
            $param = (Get-Command Test-ADDatabaseHealth).Parameters['ComputerName']
            $param.Attributes.ValueFromPipeline | Should -Be $true
        }

        It 'Should have proper aliases for ComputerName' {
            $param = (Get-Command Test-ADDatabaseHealth).Parameters['ComputerName']
            $param.Aliases | Should -Contain 'Name'
            $param.Aliases | Should -Contain 'HostName'
            $param.Aliases | Should -Contain 'DnsHostName'
        }

        It 'ComputerName parameter should be optional' {
            $param = (Get-Command Test-ADDatabaseHealth).Parameters['ComputerName']
            $param.Attributes.Mandatory | Should -Be $false
        }
    }

    Context 'Function availability and help' {
        It 'Should have synopsis' {
            $help = Get-Help Test-ADDatabaseHealth
            $help.Synopsis | Should -Not -BeNullOrEmpty
        }

        It 'Should have description' {
            $help = Get-Help Test-ADDatabaseHealth
            $help.Description | Should -Not -BeNullOrEmpty
        }

        It 'Should have examples' {
            $help = Get-Help Test-ADDatabaseHealth
            $help.Examples | Should -Not -BeNullOrEmpty
            $help.Examples.Example.Count | Should -BeGreaterOrEqual 2
        }

        It 'Should return PSCustomObject type' {
            $command = Get-Command Test-ADDatabaseHealth
            $outputType = $command.OutputType.Name
            $outputType | Should -Match 'PSCustomObject|PSObject'
        }

        It 'Should have notes section' {
            $help = Get-Help Test-ADDatabaseHealth
            $help.AlertSet | Should -Not -BeNullOrEmpty
        }

        It 'Should have link section' {
            $help = Get-Help Test-ADDatabaseHealth
            $help.relatedLinks | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Function design validation' {
        It 'Should follow Verb-Noun naming convention' {
            'Test-ADDatabaseHealth' | Should -Match '^[A-Z][a-z]+-[A-Z]'
        }

        It 'Should be exported from module' {
            $exportedCommands = (Get-Module AdMonitoring).ExportedCommands.Keys
            $exportedCommands | Should -Contain 'Test-ADDatabaseHealth'
        }

        It 'Should have CmdletBinding attribute' {
            $command = Get-Command Test-ADDatabaseHealth
            $command.CmdletBinding | Should -Be $true
        }

        It 'Should use approved PowerShell verb' {
            $verb = (Get-Command Test-ADDatabaseHealth).Verb
            $approvedVerbs = Get-Verb | Select-Object -ExpandProperty Verb
            $approvedVerbs | Should -Contain $verb
        }
    }

    Context 'Event log filtering efficiency' {
        It 'Should use FilterHashtable with Event IDs for efficient filtering' {
            $definition = (Get-Command Test-ADDatabaseHealth).Definition
            # Verify FilterHashtable includes Id property with multiple event IDs
            $definition | Should -Match "FilterHashtable\s*=\s*@\{[^}]*Id\s*=\s*\`$databaseEventIds\.Keys"
        }

        It 'Should NOT use Where-Object for Event ID filtering' {
            $definition = (Get-Command Test-ADDatabaseHealth).Definition
            # Verify we're not piping Get-WinEvent to Where-Object for Id filtering
            $definition | Should -Not -Match 'Get-WinEvent.*\|.*Where-Object.*\.Id -in'
        }

        It 'Should define database event IDs in begin block' {
            $definition = (Get-Command Test-ADDatabaseHealth).Definition
            $definition | Should -Match '\$databaseEventIds\s*=\s*@\{'
            $definition | Should -Match '1014\s*='  # Database corruption
            $definition | Should -Match '1159\s*='  # Version store out of memory
            $definition | Should -Match '2095\s*='  # Garbage collection
            $definition | Should -Match '1168\s*='  # Database error
            $definition | Should -Match '1173\s*='  # Transaction failure
            $definition | Should -Match '467\s*='   # Defragmentation status
            $definition | Should -Match '1646\s*='  # Internal database error
        }

        It 'Should query Directory Service log' {
            $definition = (Get-Command Test-ADDatabaseHealth).Definition
            $definition | Should -Match "LogName\s*=\s*['`"]Directory Service['`"]"
        }

        It 'Should apply StartTime filter' {
            $definition = (Get-Command Test-ADDatabaseHealth).Definition
            $definition | Should -Match 'StartTime\s*=\s*\$startTime'
        }
    }

    # NOTE: Functional tests require ActiveDirectory module, remote registry access, and live DC environment
    # The tests above validate function structure, parameters, and help documentation
    # Integration testing should be performed in an AD environment with:
    # - Database health checks with various database sizes
    # - Fragmentation threshold testing
    # - Garbage collection event verification
    # - Version store error detection
    # - Tombstone lifetime validation
    # - Database corruption scenario testing
    # - Disk space monitoring for database drive
    # - Multiple DC processing
    # - Event log analysis for database errors
    # - Custom threshold configuration
}
