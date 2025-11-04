function Export-ADHealthData {
    <#
    .SYNOPSIS
        Exports Active Directory health check results to various formats for analysis and archiving.

    .DESCRIPTION
        The Export-ADHealthData function exports health check results to multiple formats:
        - JSON: For programmatic consumption and API integration
        - CSV: For spreadsheet analysis and reporting
        - XML: For structured data exchange and archiving
        - CLIXML: For PowerShell object serialization with full type information

        The function supports filtering, compression, and metadata inclusion.

    .PARAMETER HealthCheckResults
        An array of health check result objects from AD monitoring functions.
        These objects should have the standard AdMonitoring output structure.

    .PARAMETER Path
        The output file path. File extension determines format if -Format not specified:
        - .json for JSON
        - .csv for CSV
        - .xml for XML
        - .clixml for CLIXML

    .PARAMETER Format
        Explicitly specify the output format: JSON, CSV, XML, or CLIXML.
        If not specified, format is inferred from file extension.

    .PARAMETER IncludeHealthy
        If specified, includes checks that returned "Healthy" status in export.
        By default, only Warning and Critical issues are exported.

    .PARAMETER Compress
        If specified, compresses the output file using GZip compression.
        Adds .gz extension to the output filename.

    .PARAMETER IncludeMetadata
        If specified, includes metadata in the export (timestamp, version, statistics).
        Only applicable to JSON and XML formats.

    .PARAMETER Depth
        Maximum depth for JSON serialization. Default: 10
        Only applicable to JSON format.

    .PARAMETER Encoding
        File encoding. Valid values: ASCII, UTF8, UTF32, Unicode, UTF7, Default.
        Default: UTF8

    .PARAMETER NoClobber
        If specified, prevents overwriting existing files.

    .PARAMETER Append
        If specified, appends to existing file instead of overwriting.
        Only applicable to CSV and JSON formats.

    .PARAMETER Force
        If specified, creates directory path if it doesn't exist.

    .EXAMPLE
        $results = Invoke-ADHealthCheck
        Export-ADHealthData -HealthCheckResults $results -Path C:\Reports\AD-Health.json

        Exports results to JSON format (inferred from extension).

    .EXAMPLE
        Invoke-ADHealthCheck | Export-ADHealthData -Path .\results.csv -IncludeHealthy

        Pipes results and exports to CSV including healthy checks.

    .EXAMPLE
        $results = Invoke-ADHealthCheck -Category Replication,DNS
        Export-ADHealthData -HealthCheckResults $results -Path .\critical.json -Format JSON -IncludeMetadata -Compress

        Exports specific categories to compressed JSON with metadata.

    .EXAMPLE
        $results = Invoke-ADHealthCheck
        Export-ADHealthData -HealthCheckResults $results -Path C:\Archive\AD-Health.xml -Format XML -Force

        Exports to XML format, creating directory if needed.

    .EXAMPLE
        Get-ADServiceStatus | Export-ADHealthData -Path .\services.clixml -Format CLIXML

        Exports service status to CLIXML for full PowerShell object preservation.

    .INPUTS
        System.Management.Automation.PSObject[]

        You can pipe health check result objects to this function.

    .OUTPUTS
        System.IO.FileInfo

        Returns a FileInfo object for the exported file.

    .NOTES
        Author: AdMonitoring Module
        Version: 1.0.0
        Requires: PowerShell 5.1 or later

        Format Characteristics:
        - JSON: Human-readable, widely supported, good for APIs
        - CSV: Excel-compatible, simple analysis, flat structure
        - XML: Structured, good for data exchange
        - CLIXML: PowerShell native, preserves all type information

    .LINK
        New-ADHealthReport

    .LINK
        Invoke-ADHealthCheck

    .LINK
        Import-Clixml
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([System.IO.FileInfo])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [PSObject[]]$HealthCheckResults,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter()]
        [ValidateSet('JSON', 'CSV', 'XML', 'CLIXML')]
        [string]$Format,

        [Parameter()]
        [switch]$IncludeHealthy,

        [Parameter()]
        [switch]$Compress,

        [Parameter()]
        [switch]$IncludeMetadata,

        [Parameter()]
        [ValidateRange(1, 100)]
        [int]$Depth = 10,

        [Parameter()]
        [ValidateSet('ASCII', 'UTF8', 'UTF32', 'Unicode', 'UTF7', 'Default')]
        [string]$Encoding = 'UTF8',

        [Parameter()]
        [switch]$NoClobber,

        [Parameter()]
        [switch]$Append,

        [Parameter()]
        [switch]$Force
    )

    begin {
        Write-Verbose "Preparing to export AD health data"

        $allResults = [System.Collections.Generic.List[PSObject]]::new()
    }

    process {
        foreach ($result in $HealthCheckResults) {
            $allResults.Add($result)
        }
    }

    end {
        Write-Verbose "Processing $($allResults.Count) health check results for export"

        # Filter results if not including healthy
        $exportResults = if ($IncludeHealthy) {
            $allResults
        }
        else {
            $allResults | Where-Object { $_.Status -ne 'Healthy' }
        }

        Write-Verbose "Exporting $($exportResults.Count) results"

        # Determine format from extension if not specified
        if (-not $Format) {
            $extension = [System.IO.Path]::GetExtension($Path).ToLower()
            $Format = switch ($extension) {
                '.json' { 'JSON' }
                '.csv' { 'CSV' }
                '.xml' { 'XML' }
                '.clixml' { 'CLIXML' }
                default {
                    Write-Warning "Unable to determine format from extension '$extension', defaulting to JSON"
                    'JSON'
                }
            }
            Write-Verbose "Inferred format from extension: $Format"
        }

        # Ensure directory exists if -Force
        $directory = Split-Path -Path $Path -Parent
        if ($directory -and -not (Test-Path -Path $directory)) {
            if ($Force) {
                Write-Verbose "Creating directory: $directory"
                New-Item -Path $directory -ItemType Directory -Force | Out-Null
            }
            else {
                throw "Directory does not exist: $directory. Use -Force to create it."
            }
        }

        # Check if file exists and handle NoClobber
        if ((Test-Path -Path $Path) -and $NoClobber -and -not $Append) {
            throw "File already exists and -NoClobber was specified: $Path"
        }

        # Export based on format
        if ($PSCmdlet.ShouldProcess($Path, "Export health data as $Format")) {
            try {
                switch ($Format) {
                    'JSON' {
                        Write-Verbose "Exporting to JSON format"

                        if ($IncludeMetadata) {
                            # Create wrapper object with metadata
                            $exportObject = [PSCustomObject]@{
                                Metadata = @{
                                    ExportDate = Get-Date -Format 'o'
                                    ModuleVersion = '1.0.0'
                                    TotalResults = $allResults.Count
                                    ExportedResults = $exportResults.Count
                                    Statistics = @{
                                        Critical = ($allResults | Where-Object { $_.Status -eq 'Critical' }).Count
                                        Warning = ($allResults | Where-Object { $_.Status -eq 'Warning' }).Count
                                        Healthy = ($allResults | Where-Object { $_.Status -eq 'Healthy' }).Count
                                    }
                                }
                                Results = $exportResults
                            }
                        }
                        else {
                            $exportObject = $exportResults
                        }

                        $jsonContent = $exportObject | ConvertTo-Json -Depth $Depth -Compress:$false

                        if ($Append -and (Test-Path -Path $Path)) {
                            # For append, read existing array and add new items
                            Write-Verbose "Appending to existing JSON file"
                            $existing = Get-Content -Path $Path -Raw | ConvertFrom-Json
                            $combined = @($existing) + @($exportResults)
                            $jsonContent = $combined | ConvertTo-Json -Depth $Depth -Compress:$false
                        }

                        $jsonContent | Out-File -FilePath $Path -Encoding $Encoding -Force
                    }

                    'CSV' {
                        Write-Verbose "Exporting to CSV format"

                        # Flatten complex objects for CSV
                        $flatResults = $exportResults | ForEach-Object {
                            $result = $_
                            [PSCustomObject]@{
                                Status = $result.Status
                                CheckName = $result.CheckName
                                Category = $result.Category
                                Target = $result.Target
                                Timestamp = $result.Timestamp.ToString('o')
                                Details = if ($result.Details) { ($result.Details | ConvertTo-Json -Compress) } else { '' }
                                Recommendations = if ($result.Recommendations) { ($result.Recommendations -join '; ') } else { '' }
                            }
                        }

                        if ($Append) {
                            $flatResults | Export-Csv -Path $Path -Encoding $Encoding -NoTypeInformation -Append -Force
                        }
                        else {
                            $flatResults | Export-Csv -Path $Path -Encoding $Encoding -NoTypeInformation -Force
                        }
                    }

                    'XML' {
                        Write-Verbose "Exporting to XML format"

                        if ($IncludeMetadata) {
                            # Create XML with metadata
                            $xmlDoc = [System.Xml.XmlDocument]::new()
                            $root = $xmlDoc.CreateElement('ADHealthData')
                            $xmlDoc.AppendChild($root) | Out-Null

                            # Add metadata
                            $metadata = $xmlDoc.CreateElement('Metadata')
                            $metadata.SetAttribute('ExportDate', (Get-Date -Format 'o'))
                            $metadata.SetAttribute('ModuleVersion', '1.0.0')
                            $metadata.SetAttribute('TotalResults', $allResults.Count)
                            $metadata.SetAttribute('ExportedResults', $exportResults.Count)
                            $root.AppendChild($metadata) | Out-Null

                            # Add results
                            $resultsNode = $xmlDoc.CreateElement('Results')
                            $root.AppendChild($resultsNode) | Out-Null

                            foreach ($result in $exportResults) {
                                $resultNode = $xmlDoc.CreateElement('Result')
                                $resultNode.SetAttribute('Status', $result.Status)
                                $resultNode.SetAttribute('CheckName', $result.CheckName)
                                $resultNode.SetAttribute('Category', $result.Category)
                                $resultNode.SetAttribute('Target', $result.Target)
                                $resultNode.SetAttribute('Timestamp', $result.Timestamp.ToString('o'))

                                if ($result.Details) {
                                    $detailsNode = $xmlDoc.CreateElement('Details')
                                    $detailsNode.InnerText = ($result.Details | ConvertTo-Json -Compress)
                                    $resultNode.AppendChild($detailsNode) | Out-Null
                                }

                                if ($result.Recommendations) {
                                    $recsNode = $xmlDoc.CreateElement('Recommendations')
                                    foreach ($rec in $result.Recommendations) {
                                        $recNode = $xmlDoc.CreateElement('Recommendation')
                                        $recNode.InnerText = $rec
                                        $recsNode.AppendChild($recNode) | Out-Null
                                    }
                                    $resultNode.AppendChild($recsNode) | Out-Null
                                }

                                $resultsNode.AppendChild($resultNode) | Out-Null
                            }

                            $xmlDoc.Save($Path)
                        }
                        else {
                            # Simple XML export
                            $exportResults | Export-Clixml -Path $Path -Encoding $Encoding -Force
                        }
                    }

                    'CLIXML' {
                        Write-Verbose "Exporting to CLIXML format"
                        $exportResults | Export-Clixml -Path $Path -Encoding $Encoding -Force
                    }
                }

                Write-Verbose "Export completed successfully"

                # Compress if requested
                if ($Compress) {
                    Write-Verbose "Compressing output file"
                    $compressedPath = "$Path.gz"

                    try {
                        $inputFile = [System.IO.File]::OpenRead($Path)
                        $outputFile = [System.IO.File]::Create($compressedPath)
                        $gzipStream = [System.IO.Compression.GZipStream]::new($outputFile, [System.IO.Compression.CompressionMode]::Compress)

                        $inputFile.CopyTo($gzipStream)

                        $gzipStream.Close()
                        $outputFile.Close()
                        $inputFile.Close()

                        # Remove uncompressed file
                        Remove-Item -Path $Path -Force
                        $Path = $compressedPath

                        Write-Verbose "Compression completed: $compressedPath"
                    }
                    catch {
                        Write-Error "Compression failed: $_"
                        throw
                    }
                    finally {
                        if ($gzipStream) { $gzipStream.Dispose() }
                        if ($outputFile) { $outputFile.Dispose() }
                        if ($inputFile) { $inputFile.Dispose() }
                    }
                }

                # Return FileInfo object
                $fileInfo = Get-Item -Path $Path
                Write-Host "Data exported successfully to: $($fileInfo.FullName)" -ForegroundColor Green
                Write-Verbose "File size: $($fileInfo.Length) bytes"

                $fileInfo
            }
            catch {
                Write-Error "Export failed: $_"
                throw
            }
        }
    }
}
