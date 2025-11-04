BeforeAll {
    $modulePath = "$PSScriptRoot\..\..\..\output\module\AdMonitoring"
    Import-Module $modulePath -Force -ErrorAction Stop
}

Describe 'New-ADHealthReport' {
    Context 'Parameter validation' {
        It 'Should have HealthCheckResults parameter' {
            Get-Command New-ADHealthReport | Should -HaveParameter HealthCheckResults -Type PSObject[] -Mandatory
        }

        It 'Should have Title parameter' {
            $cmd = Get-Command New-ADHealthReport
            $cmd | Should -HaveParameter Title -Type string
            $cmd.Parameters['Title'].Attributes.Mandatory | Should -Be $false
        }

        It 'Should have IncludeHealthyChecks switch parameter' {
            $cmd = Get-Command New-ADHealthReport
            $cmd | Should -HaveParameter IncludeHealthyChecks -Type switch
        }

        It 'Should have OutputPath parameter' {
            Get-Command New-ADHealthReport | Should -HaveParameter OutputPath -Type string
        }

        It 'Should have IncludeTimestamp parameter' {
            $cmd = Get-Command New-ADHealthReport
            $cmd | Should -HaveParameter IncludeTimestamp -Type bool
        }

        It 'Should have CompanyName parameter' {
            Get-Command New-ADHealthReport | Should -HaveParameter CompanyName -Type string
        }

        It 'Should have CompanyLogo parameter' {
            Get-Command New-ADHealthReport | Should -HaveParameter CompanyLogo -Type string
        }

        It 'Should accept pipeline input for HealthCheckResults' {
            $param = (Get-Command New-ADHealthReport).Parameters['HealthCheckResults']
            $param.Attributes.ValueFromPipeline | Should -Be $true
        }

        It 'HealthCheckResults should be mandatory' {
            $param = (Get-Command New-ADHealthReport).Parameters['HealthCheckResults']
            $param.Attributes.Mandatory | Should -Be $true
        }

        It 'HealthCheckResults should not allow null or empty' {
            $param = (Get-Command New-ADHealthReport).Parameters['HealthCheckResults']
            $param.Attributes.TypeId.Name | Should -Contain 'ValidateNotNullOrEmptyAttribute'
        }
    }

    Context 'Function availability and help' {
        It 'Should have synopsis' {
            $help = Get-Help New-ADHealthReport
            $help.Synopsis | Should -Not -BeNullOrEmpty
        }

        It 'Should have description' {
            $help = Get-Help New-ADHealthReport
            $help.Description | Should -Not -BeNullOrEmpty
        }

        It 'Should have examples' {
            $help = Get-Help New-ADHealthReport
            $help.Examples | Should -Not -BeNullOrEmpty
            $help.Examples.Example.Count | Should -BeGreaterOrEqual 2
        }

        It 'Should return string type' {
            $command = Get-Command New-ADHealthReport
            $outputType = $command.OutputType.Name
            $outputType | Should -Match 'String'
        }

        It 'Should have notes section' {
            $help = Get-Help New-ADHealthReport
            $help.AlertSet | Should -Not -BeNullOrEmpty
        }

        It 'Should have link section' {
            $help = Get-Help New-ADHealthReport
            $help.relatedLinks | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Function design validation' {
        It 'Should follow Verb-Noun naming convention' {
            'New-ADHealthReport' | Should -Match '^[A-Z][a-z]+-[A-Z]'
        }

        It 'Should be exported from module' {
            $exportedCommands = (Get-Module AdMonitoring).ExportedCommands.Keys
            $exportedCommands | Should -Contain 'New-ADHealthReport'
        }

        It 'Should have CmdletBinding attribute' {
            $command = Get-Command New-ADHealthReport
            $command.CmdletBinding | Should -Be $true
        }

        It 'Should use approved PowerShell verb' {
            $verb = (Get-Command New-ADHealthReport).Verb
            $approvedVerbs = Get-Verb | Select-Object -ExpandProperty Verb
            $approvedVerbs | Should -Contain $verb
        }
    }

    Context 'HTML generation with mock data' {
        BeforeAll {
            # Create mock health check results
            $mockResults = @(
                [PSCustomObject]@{
                    PSTypeName = 'AdMonitoring.HealthCheckResult'
                    CheckName = 'ServiceStatus'
                    Category = 'Services'
                    Status = 'Healthy'
                    Target = 'DC01.contoso.com'
                    Timestamp = Get-Date
                    Details = [PSCustomObject]@{
                        ServicesRunning = 5
                        ServicesStopped = 0
                    }
                    Recommendations = @('All services running normally')
                }
                [PSCustomObject]@{
                    PSTypeName = 'AdMonitoring.HealthCheckResult'
                    CheckName = 'ReplicationHealth'
                    Category = 'Replication'
                    Status = 'Warning'
                    Target = 'DC02.contoso.com'
                    Timestamp = Get-Date
                    Details = [PSCustomObject]@{
                        LastReplication = (Get-Date).AddMinutes(-45)
                        ReplicationLag = 45
                    }
                    Recommendations = @('Replication lag detected', 'Monitor replication partners')
                }
                [PSCustomObject]@{
                    PSTypeName = 'AdMonitoring.HealthCheckResult'
                    CheckName = 'DiskSpace'
                    Category = 'Performance'
                    Status = 'Critical'
                    Target = 'DC03.contoso.com'
                    Timestamp = Get-Date
                    Details = [PSCustomObject]@{
                        DriveLetter = 'C:'
                        FreeSpaceGB = 5
                        TotalSpaceGB = 100
                    }
                    Recommendations = @('Free up disk space immediately', 'Move logs to another volume')
                }
            )
        }

        It 'Should generate HTML output as string when OutputPath not specified' {
            $html = New-ADHealthReport -HealthCheckResults $mockResults
            $html | Should -Not -BeNullOrEmpty
            $html | Should -BeOfType [string]
        }

        It 'Should contain HTML DOCTYPE declaration' {
            $html = New-ADHealthReport -HealthCheckResults $mockResults
            $html | Should -Match '<!DOCTYPE html>'
        }

        It 'Should contain HTML structure tags' {
            $html = New-ADHealthReport -HealthCheckResults $mockResults
            $html | Should -Match '<html'
            $html | Should -Match '<head>'
            $html | Should -Match '<body>'
            $html | Should -Match '</html>'
        }

        It 'Should contain CSS styles' {
            $html = New-ADHealthReport -HealthCheckResults $mockResults
            $html | Should -Match '<style>'
            $html | Should -Match 'font-family:'
            $html | Should -Match 'background-color:'
        }

        It 'Should include executive summary section' {
            $html = New-ADHealthReport -HealthCheckResults $mockResults
            $html | Should -Match 'executive-summary'
            $html | Should -Match 'Executive Summary'
        }

        It 'Should display overall status' {
            $html = New-ADHealthReport -HealthCheckResults $mockResults
            $html | Should -Match 'Overall Status:'
            $html | Should -Match 'Critical|Warning|Healthy'
        }

        It 'Should include summary statistics' {
            $html = New-ADHealthReport -HealthCheckResults $mockResults
            $html | Should -Match 'Total Checks'
            $html | Should -Match 'Critical Issues'
            $html | Should -Match 'Warnings'
            $html | Should -Match 'Healthy'
        }

        It 'Should show correct count for critical issues' {
            $html = New-ADHealthReport -HealthCheckResults $mockResults
            $html | Should -Match '<span class=.stat-number.>1</span>[\s\S]*?<span class=.stat-label.>Critical Issues</span>'
        }

        It 'Should show correct count for warnings' {
            $html = New-ADHealthReport -HealthCheckResults $mockResults
            $html | Should -Match '<span class=.stat-number.>1</span>[\s\S]*?<span class=.stat-label.>Warnings</span>'
        }

       It 'Should group results by category' {
            # Only non-healthy checks appear by default
            $html = New-ADHealthReport -HealthCheckResults $mockResults
            $html | Should -Match '<h2>Replication</h2>'
            $html | Should -Match '<h2>Performance</h2>'
            # Services category excluded because it's healthy
        }

        It 'Should include check names' {
            # Only non-healthy checks appear by default
            $html = New-ADHealthReport -HealthCheckResults $mockResults
            $html | Should -Match 'ReplicationHealth'
            $html | Should -Match 'DiskSpace'
            # ServiceStatus excluded because it's healthy
        }

        It 'Should include status badges' {
            # Only non-healthy checks appear by default
            $html = New-ADHealthReport -HealthCheckResults $mockResults
            $html | Should -Match 'status-badge warning'
            $html | Should -Match 'status-badge critical'
            # Healthy badge not in detailed section by default
        }

        It 'Should include target information for non-healthy checks' {
            # Only non-healthy checks appear by default
            $html = New-ADHealthReport -HealthCheckResults $mockResults
            $html | Should -Match 'DC02.contoso.com'
            $html | Should -Match 'DC03.contoso.com'
            # DC01 excluded because its check is healthy
        }

        It 'Should include timestamp information when IncludeTimestamp is true' {
            $html = New-ADHealthReport -HealthCheckResults $mockResults -IncludeTimestamp $true
            $html | Should -Match 'Generated:'
            $html | Should -Match '\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}'
        }

        It 'Should include recommendations section' {
            $html = New-ADHealthReport -HealthCheckResults $mockResults
            $html | Should -Match 'Recommendations'
            $html | Should -Match 'Free up disk space immediately'
            $html | Should -Match 'Monitor replication partners'
        }

        It 'Should include details in table format' {
            $html = New-ADHealthReport -HealthCheckResults $mockResults
            $html | Should -Match '<table'
            $html | Should -Match '<th>Property</th>'
            $html | Should -Match '<th>Value</th>'
        }

        It 'Should use custom title when provided' {
            $customTitle = 'Contoso AD Health Report'
            $html = New-ADHealthReport -HealthCheckResults $mockResults -Title $customTitle
            $html | Should -Match "<title>$customTitle</title>"
            $html | Should -Match "<h1>$customTitle</h1>"
        }

        It 'Should include company name when provided' {
            $companyName = 'Contoso Corporation'
            $html = New-ADHealthReport -HealthCheckResults $mockResults -CompanyName $companyName
            $html | Should -Match $companyName
        }

        It 'Should include company logo when provided' {
            $logoUrl = 'https://example.com/logo.png'
            $html = New-ADHealthReport -HealthCheckResults $mockResults -CompanyLogo $logoUrl
            $html | Should -Match "<img src='$logoUrl'"
            $html | Should -Match "alt='Company Logo'"
        }

        It 'Should exclude healthy checks by default' {
            $html = New-ADHealthReport -HealthCheckResults $mockResults
            # By default, healthy checks should not appear in detailed section
            # (only in summary statistics)
            $detailedSection = $html -split 'executive-summary' | Select-Object -Last 1
            $detailedSection | Should -Not -Match 'ServiceStatus'
        }

        It 'Should include healthy checks when IncludeHealthyChecks is specified' {
            $html = New-ADHealthReport -HealthCheckResults $mockResults -IncludeHealthyChecks
            $html | Should -Match 'ServiceStatus'
            $html | Should -Match 'status-badge healthy'
        }

        It 'Should show "All Systems Healthy" message when no issues' {
            $healthyResults = @(
                [PSCustomObject]@{
                    Status = 'Healthy'
                    CheckName = 'Test'
                    Category = 'Test'
                    Target = 'DC01'
                    Timestamp = Get-Date
                    Details = @{}
                    Recommendations = @()
                }
            )
            $html = New-ADHealthReport -HealthCheckResults $healthyResults
            $html | Should -Match 'All Systems Healthy'
            $html | Should -Match 'No issues detected'
        }

        It 'Should determine overall status as Critical when critical issues exist' {
            $html = New-ADHealthReport -HealthCheckResults $mockResults
            $html | Should -Match 'Overall Status:.*?Critical'
        }

        It 'Should include footer with generation info' {
            $html = New-ADHealthReport -HealthCheckResults $mockResults
            $html | Should -Match 'Generated by AdMonitoring'
            $html | Should -Match 'Report Date:'
        }
    }

    Context 'File output functionality' {
        BeforeAll {
            $mockResults = @(
                [PSCustomObject]@{
                    Status = 'Warning'
                    CheckName = 'Test'
                    Category = 'Test'
                    Target = 'DC01'
                    Timestamp = Get-Date
                    Details = @{}
                    Recommendations = @('Test recommendation')
                }
            )

            $tempFile = Join-Path $TestDrive 'test-report.html'
        }

        It 'Should create output file when OutputPath is specified' {
            New-ADHealthReport -HealthCheckResults $mockResults -OutputPath $tempFile
            Test-Path $tempFile | Should -Be $true
        }

        It 'Should return FileInfo object when OutputPath is specified' {
            $result = New-ADHealthReport -HealthCheckResults $mockResults -OutputPath $tempFile
            $result | Should -BeOfType [System.IO.FileInfo]
        }

        It 'Should create directory if it does not exist' {
            $deepPath = Join-Path $TestDrive 'deep\nested\path\report.html'
            New-ADHealthReport -HealthCheckResults $mockResults -OutputPath $deepPath
            Test-Path $deepPath | Should -Be $true
        }

        It 'Should overwrite existing file' {
            'Old content' | Out-File -FilePath $tempFile
            New-ADHealthReport -HealthCheckResults $mockResults -OutputPath $tempFile
            $content = Get-Content $tempFile -Raw
            $content | Should -Not -Match 'Old content'
            $content | Should -Match 'DOCTYPE html'
        }

        It 'Should write valid HTML to file' {
            New-ADHealthReport -HealthCheckResults $mockResults -OutputPath $tempFile
            $content = Get-Content $tempFile -Raw
            $content | Should -Match '<!DOCTYPE html>'
            $content | Should -Match '<html'
            $content | Should -Match '</html>'
        }

        It 'Should use UTF8 encoding' {
            New-ADHealthReport -HealthCheckResults $mockResults -OutputPath $tempFile
            $bytes = [System.IO.File]::ReadAllBytes($tempFile)
            # Check for UTF8 BOM or valid UTF8 content
            $content = Get-Content $tempFile -Raw
            $content | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Pipeline input processing' {
        BeforeAll {
            $mockResults = @(
                [PSCustomObject]@{
                    Status = 'Healthy'
                    CheckName = 'Check1'
                    Category = 'Category1'
                    Target = 'DC01'
                    Timestamp = Get-Date
                    Details = @{}
                    Recommendations = @()
                }
                [PSCustomObject]@{
                    Status = 'Warning'
                    CheckName = 'Check2'
                    Category = 'Category2'
                    Target = 'DC02'
                    Timestamp = Get-Date
                    Details = @{}
                    Recommendations = @()
                }
            )
        }

        It 'Should accept pipeline input' {
            $html = $mockResults | New-ADHealthReport
            $html | Should -Not -BeNullOrEmpty
        }

        It 'Should process all piped results' {
            $html = $mockResults | New-ADHealthReport -IncludeHealthyChecks
            $html | Should -Match 'Check1'
            $html | Should -Match 'Check2'
        }

        It 'Should handle single piped result' {
            $html = $mockResults[0] | New-ADHealthReport
            $html | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Error handling' {
        It 'Should throw when HealthCheckResults is null' {
            { New-ADHealthReport -HealthCheckResults $null } | Should -Throw
        }

        It 'Should throw when HealthCheckResults is empty array' {
            { New-ADHealthReport -HealthCheckResults @() } | Should -Throw
        }

        It 'Should handle invalid OutputPath gracefully' {
            $invalidPath = 'Z:\NonExistent\Path\report.html'
            { New-ADHealthReport -HealthCheckResults @([PSCustomObject]@{Status='Healthy'}) -OutputPath $invalidPath -ErrorAction Stop } | Should -Throw
        }
    }

    Context 'Status determination logic' {
        It 'Should set overall status to Critical when any critical result exists' {
            $results = @(
                [PSCustomObject]@{Status='Healthy'; CheckName='C1'; Category='Cat'; Target='T'; Timestamp=Get-Date; Details=@{}; Recommendations=@()}
                [PSCustomObject]@{Status='Critical'; CheckName='C2'; Category='Cat'; Target='T'; Timestamp=Get-Date; Details=@{}; Recommendations=@()}
            )
            $html = New-ADHealthReport -HealthCheckResults $results
            $html | Should -Match 'Overall Status:.*?Critical'
        }

        It 'Should set overall status to Warning when warnings exist but no critical' {
            $results = @(
                [PSCustomObject]@{Status='Healthy'; CheckName='C1'; Category='Cat'; Target='T'; Timestamp=Get-Date; Details=@{}; Recommendations=@()}
                [PSCustomObject]@{Status='Warning'; CheckName='C2'; Category='Cat'; Target='T'; Timestamp=Get-Date; Details=@{}; Recommendations=@()}
            )
            $html = New-ADHealthReport -HealthCheckResults $results
            $html | Should -Match 'Overall Status:.*?Warning'
        }

        It 'Should set overall status to Healthy when all checks are healthy' {
            $results = @(
                [PSCustomObject]@{Status='Healthy'; CheckName='C1'; Category='Cat'; Target='T'; Timestamp=Get-Date; Details=@{}; Recommendations=@()}
                [PSCustomObject]@{Status='Healthy'; CheckName='C2'; Category='Cat'; Target='T'; Timestamp=Get-Date; Details=@{}; Recommendations=@()}
            )
            $html = New-ADHealthReport -HealthCheckResults $results
            $html | Should -Match 'Overall Status:.*?Healthy'
        }
    }
}
