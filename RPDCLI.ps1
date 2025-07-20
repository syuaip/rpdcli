# RPDCLI.ps1
# Reksadata Performance Data Collector Command Line Version - PowerShell Edition
# Version 2.5.1
#   Change version text from corp to name.
#   Cover SSAS 2019 counters.
#   Enable function: FileContent
#   Added -debug parameter to allow temp and report files not to be deleted for examination 
# Copyright ©2016-2020, PT. Reksa Data Indonesia (Decommisioned)
# Copyright ©2020-2022, Arief Nugraha (Release to Public - Apache License 2.0)
# Purpose: Windows Performance Data Collector Setup, Ops and Cleaning Up
# PowerShell conversion by Amazon Q

param(
    [Parameter(Position=0)]
    [string]$Action,
    
    [Parameter(Position=1)]
    [switch]$KeepTempFiles
)

# Global variables
$script:SQLServerInstances = @()
$script:OLAPServerInstances = @()
$script:SQLInstance = "[Auto]"
$script:IISExists = $false
$script:ValidParam = $false

# Function to start hidden process and wait for completion
function Start-ProcessHidden {
    param(
        [string]$FileName,
        [bool]$WaitForExit = $true
    )
    
    try {
        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = "cmd.exe"
        $processInfo.Arguments = "/C $FileName"
        $processInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
        $processInfo.CreateNoWindow = $true
        $processInfo.UseShellExecute = $false
        
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processInfo
        
        if ($process.Start()) {
            if ($WaitForExit) {
                $process.WaitForExit()
                $exitCode = $process.ExitCode
                $process.Close()
                return 0
            }
            return 1
        }
        else {
            return 9
        }
    }
    catch {
        Write-Error "Failed to start process: $_"
        return 9
    }
}

# Function to get version information
function Get-BuildInfoAsString {
    return "2.5.1"
}

# Function to check if running on 64-bit system
function Test-Is64Bit {
    return [Environment]::Is64BitOperatingSystem
}

# Function to detect SQL Server instances
function Find-SQLServerInstances {
    Write-Host "Checking installed SQL Instances..."
    
    $script:SQLInstance = "[Auto]"
    $script:IISExists = $false
    $script:SQLServerInstances = @()
    $script:OLAPServerInstances = @()
    
    try {
        $cmdStr = "net start"
        $result = Start-ProcessHidden "$cmdStr > mssqlinst.dat" $true
        Start-Sleep -Milliseconds 2500
        
        if ($result -eq 0) {
            Write-Host "Analyzing running services..."
            
            if (Test-Path "mssqlinst.dat") {
                $services = Get-Content "mssqlinst.dat"
                
                foreach ($line in $services) {
                    $trimmedLine = $line.Trim()
                    
                    # Check for SQL Server instances
                    if ($trimmedLine.StartsWith("SQL Server (")) {
                        $instanceName = $trimmedLine.Substring(12)
                        $instanceName = $instanceName.Substring(0, $instanceName.IndexOf(")"))
                        Write-Host "Found installed SQL Instance: $instanceName"
                        $script:SQLServerInstances += $instanceName
                    }
                    
                    # Check for OLAP instances
                    if ($trimmedLine.StartsWith("SQL Server Analysis Services (")) {
                        $instanceName = $trimmedLine.Substring(31)
                        $instanceName = $instanceName.Substring(0, $instanceName.IndexOf(")"))
                        Write-Host "Found installed OLAP Instance: $instanceName"
                        $script:OLAPServerInstances += $instanceName
                    }
                    
                    # Check for IIS
                    if ($trimmedLine.StartsWith("World Wide Web Publishing Service")) {
                        Write-Host "Found installed IIS Instance."
                        $script:IISExists = $true
                    }
                }
                
                # Determine SQL instance configuration
                if ($script:SQLServerInstances.Count -eq 1 -and $script:SQLServerInstances[0] -eq "MSSQLSERVER") {
                    Write-Host "Found only Default SQL Instance"
                    $script:SQLInstance = "Default"
                }
                elseif ($script:SQLServerInstances.Count -eq 0) {
                    Write-Host "Found no SQL Instance. Dropping to default option/instance."
                    $script:SQLInstance = "Default"
                }
                else {
                    Write-Host "Total SQL Instance(s): $($script:SQLServerInstances.Count)"
                }
                
                if ($script:OLAPServerInstances.Count -eq 0) {
                    Write-Host "Found no OLAP Instance."
                }
                else {
                    Write-Host "Total OLAP Instance(s): $($script:OLAPServerInstances.Count). Set to Auto."
                    $script:SQLInstance = "[Auto]"
                }
                
                if ($script:IISExists) {
                    Write-Host "Found IIS Instance. Set to Auto."
                    $script:SQLInstance = "[Auto]"
                }
            }
        }
        else {
            Write-Host "Failed to check services. Running with default value of SQL instance: default instance."
        }
    }
    catch {
        Write-Error "Error detecting SQL Server instances: $_"
    }
}

# Function to delete a single file
function Remove-SingleFile {
    param([string]$FileName)
    
    if (Test-Path $FileName) {
        Start-Sleep -Milliseconds 50
        try {
            Remove-Item $FileName -Force -ErrorAction SilentlyContinue
        }
        catch {
            # Ignore errors
        }
    }
}

# Function to delete temporary and report files
function Remove-DataFiles {
    $filesToDelete = @(
        "RDIPDC.xml", "RDIPDC.lck", "report.html", "report.xml", 
        "report.xsl", "mssqlinst.dat", "lmimp.dat", "lmsta.dat", 
        "RDIPDC.log", "lmsto.dat", "lmdel.dat"
    )
    
    foreach ($file in $filesToDelete) {
        Remove-SingleFile $file
    }
}

# Function to create Performance Monitor XML configuration
function New-PerfmonXML {
    try {
        $currentDir = Get-Location
        $xmlContent = @"
<?xml version="1.0" encoding="UTF-8"?>
<DataCollectorSet>
<Status>1</Status>
<Duration>0</Duration>
<Description>
</Description>
<DescriptionUnresolved>
</DescriptionUnresolved>
<DisplayName>
</DisplayName>
<DisplayNameUnresolved>
</DisplayNameUnresolved>
<SchedulesEnabled>-1</SchedulesEnabled>
<LatestOutputLocation>$currentDir</LatestOutputLocation>
<n>RPDCLI</n>
<OutputLocation>$currentDir</OutputLocation>
<RootPath>$currentDir</RootPath>
<Segment>-1</Segment>
<SegmentMaxDuration>86400</SegmentMaxDuration>
<SegmentMaxSize>0</SegmentMaxSize>
<SerialNumber>1</SerialNumber>
<Server>
</Server>
<Subdirectory>
</Subdirectory>
<SubdirectoryFormat>1</SubdirectoryFormat>
<SubdirectoryFormatPattern>
</SubdirectoryFormatPattern>
<Task>
</Task>
<TaskRunAsSelf>0</TaskRunAsSelf>
<TaskArguments>
</TaskArguments>
<TaskUserTextArguments>
</TaskUserTextArguments>
<UserAccount>SYSTEM</UserAccount>
<Security>O:BAG:S-1-5-21-2952966170-3714788709-2525979044-513D:AI(A;;FA;;;SY)(A;;FA;;;BA)(A;;FR;;;LU)(A;;0x1301ff;;;S-1-5-80-2661322625-712705077-2999183737-3043590567-590698655)(A;ID;FA;;;SY)(A;ID;FA;;;BA)(A;ID;0x1200ab;;;LU)(A;ID;FR;;;AU)(A;ID;FR;;;LS)(A;ID;FR;;;NS)</Security>
<StopOnCompletion>0</StopOnCompletion>
<PerformanceCounterDataCollector>
<DataCollectorType>0</DataCollectorType>
<n>HealthCheck</n>
<FileName>RDIPDC</FileName>
<FileNameFormat>3</FileNameFormat>
<FileNameFormatPattern>\_yyyyMMdd\_HHmm</FileNameFormatPattern>
<LogAppend>0</LogAppend>
<LogCircular>0</LogCircular>
<LogOverwrite>-1</LogOverwrite>
<LatestOutputLocation>$currentDir\AAA1.blg</LatestOutputLocation>
<DataSourceName>
</DataSourceName>
<SampleInterval>15</SampleInterval>
<SegmentMaxRecords>0</SegmentMaxRecords>
<LogFileFormat>3</LogFileFormat>
<Counter>\.NET CLR Exceptions(*)\*</Counter>
<Counter>\.NET CLR Memory(_Global_)\*</Counter>
"@

        # Add IIS counters if IIS exists
        if ($script:IISExists) {
            $xmlContent += @"
<Counter>\Active Server Pages\*</Counter>
<Counter>\ASP.NET\*</Counter>
<Counter>\HTTP Service\*</Counter>
<Counter>\HTTP Service Request Queues(*)\*</Counter>
<Counter>\HTTP Service Url Groups(*)\*</Counter>
<Counter>\W3SVC_W3WP\*</Counter>
<Counter>\WAS_W3WP\*</Counter>
<Counter>\Web Service(*)\*</Counter>
<Counter>\Web Service Cache\*</Counter>
"@
        }

        # Add basic system counters
        $xmlContent += @"
<Counter>\Processor(*)\*</Counter>
<Counter>\Processor Performance(*)\*</Counter>
<Counter>\PhysicalDisk(*)\*</Counter>
<Counter>\System\*</Counter>
<Counter>\Process(*)\*</Counter>
"@

        # Add SQL Server counters based on detected instances
        if ($script:SQLInstance -eq "[Auto]") {
            # Auto mode - add counters for all detected instances
            foreach ($instance in $script:SQLServerInstances) {
                if ($instance -eq "MSSQLSERVER") {
                    # Default instance
                    $xmlContent += @"
<Counter>\SQLServer:Wait Statistics(*)\*</Counter>
<Counter>\SQLServer:Access Methods\*</Counter>
<Counter>\SQLServer:Buffer Manager\*</Counter>
<Counter>\SQLServer:Databases(*)\*</Counter>
<Counter>\SQLServer:Latches\*</Counter>
<Counter>\SQLServer:Locks(_Total)\*</Counter>
<Counter>\SQLServer:SQL Statistics\*</Counter>
<Counter>\SQLServer:Transactions\*</Counter>
"@
                }
                else {
                    # Named instance
                    $xmlContent += @"
<Counter>\MSSQL`$$instance`:Wait Statistics(*)\*</Counter>
<Counter>\MSSQL`$$instance`:Access Methods\*</Counter>
<Counter>\MSSQL`$$instance`:Buffer Manager\*</Counter>
<Counter>\MSSQL`$$instance`:Databases(*)\*</Counter>
<Counter>\MSSQL`$$instance`:Latches\*</Counter>
<Counter>\MSSQL`$$instance`:Locks(_Total)\*</Counter>
<Counter>\MSSQL`$$instance`:SQL Statistics\*</Counter>
<Counter>\MSSQL`$$instance`:Transactions\*</Counter>
"@
                }
            }
        }
        elseif ($script:SQLInstance -eq "Default") {
            # Default instance only
            $xmlContent += @"
<Counter>\SQLServer:Wait Statistics(*)\*</Counter>
<Counter>\SQLServer:Access Methods\*</Counter>
<Counter>\SQLServer:Buffer Manager\*</Counter>
<Counter>\SQLServer:Databases(*)\*</Counter>
<Counter>\SQLServer:Latches\*</Counter>
<Counter>\SQLServer:Locks(_Total)\*</Counter>
<Counter>\SQLServer:SQL Statistics\*</Counter>
<Counter>\SQLServer:Transactions\*</Counter>
"@
        }
        else {
            # Specific named instance
            $xmlContent += @"
<Counter>\MSSQL`$$($script:SQLInstance)`:Wait Statistics(*)\*</Counter>
<Counter>\MSSQL`$$($script:SQLInstance)`:Access Methods\*</Counter>
<Counter>\MSSQL`$$($script:SQLInstance)`:Buffer Manager\*</Counter>
<Counter>\MSSQL`$$($script:SQLInstance)`:Databases(*)\*</Counter>
<Counter>\MSSQL`$$($script:SQLInstance)`:Latches\*</Counter>
<Counter>\MSSQL`$$($script:SQLInstance)`:Locks(_Total)\*</Counter>
<Counter>\MSSQL`$$($script:SQLInstance)`:SQL Statistics\*</Counter>
<Counter>\MSSQL`$$($script:SQLInstance)`:Transactions\*</Counter>
"@
        }

        # Add OLAP counters if instances detected
        if ($script:OLAPServerInstances.Count -gt 0) {
            foreach ($olapInstance in $script:OLAPServerInstances) {
                if ($olapInstance -eq "MSSQLSERVER") {
                    # Default OLAP instance - add all versions
                    $ssasVersions = @("MSAS10", "MSAS10_50", "MSAS11", "MSAS12", "MSAS13", "MSAS14", "MSAS15", "MSAS16")
                    foreach ($version in $ssasVersions) {
                        $xmlContent += @"
<Counter>\$version`:Cache\*</Counter>
<Counter>\$version`:Connection\*</Counter>
<Counter>\$version`:Locks\*</Counter>
<Counter>\$version`:MDX\*</Counter>
<Counter>\$version`:Memory\*</Counter>
<Counter>\$version`:Proc Aggregations\*</Counter>
<Counter>\$version`:Proc Indexes\*</Counter>
<Counter>\$version`:Processing\*</Counter>
<Counter>\$version`:Storage Engine Query\*</Counter>
<Counter>\$version`:Threads\*</Counter>
"@
                    }
                }
                else {
                    # Named OLAP instance
                    $xmlContent += @"
<Counter>\MSOLAP`$$olapInstance`:Cache\*</Counter>
<Counter>\MSOLAP`$$olapInstance`:Connection\*</Counter>
<Counter>\MSOLAP`$$olapInstance`:Locks\*</Counter>
<Counter>\MSOLAP`$$olapInstance`:MDX\*</Counter>
<Counter>\MSOLAP`$$olapInstance`:Memory\*</Counter>
<Counter>\MSOLAP`$$olapInstance`:Proc Aggregations\*</Counter>
<Counter>\MSOLAP`$$olapInstance`:Proc Indexes\*</Counter>
<Counter>\MSOLAP`$$olapInstance`:Processing\*</Counter>
<Counter>\MSOLAP`$$olapInstance`:Storage Engine Query\*</Counter>
<Counter>\MSOLAP`$$olapInstance`:Threads\*</Counter>
"@
                }
            }
        }

        # Add remaining system counters
        $xmlContent += @"
<Counter>\Network Interface(*)\*</Counter>
<Counter>\Memory\*</Counter>
<Counter>\Paging File\*</Counter>
"@

        # Add CounterDisplayName section (duplicate of Counter section for display purposes)
        $xmlContent += @"
<CounterDisplayName>\.NET CLR Exceptions(*)\*</CounterDisplayName>
<CounterDisplayName>\.NET CLR Memory(_Global_)\*</CounterDisplayName>
"@

        # Repeat the same logic for CounterDisplayName as we did for Counter
        if ($script:IISExists) {
            $xmlContent += @"
<CounterDisplayName>\Active Server Pages\*</CounterDisplayName>
<CounterDisplayName>\ASP.NET\*</CounterDisplayName>
<CounterDisplayName>\HTTP Service\*</CounterDisplayName>
<CounterDisplayName>\HTTP Service Request Queues(*)\*</CounterDisplayName>
<CounterDisplayName>\HTTP Service Url Groups(*)\*</CounterDisplayName>
<CounterDisplayName>\W3SVC_W3WP\*</CounterDisplayName>
<CounterDisplayName>\WAS_W3WP\*</CounterDisplayName>
<CounterDisplayName>\Web Service(*)\*</CounterDisplayName>
<CounterDisplayName>\Web Service Cache\*</CounterDisplayName>
"@
        }

        $xmlContent += @"
<CounterDisplayName>\Processor(*)\*</CounterDisplayName>
<CounterDisplayName>\Processor Performance(*)\*</CounterDisplayName>
<CounterDisplayName>\PhysicalDisk(*)\*</CounterDisplayName>
<CounterDisplayName>\System\*</CounterDisplayName>
<CounterDisplayName>\Process(*)\*</CounterDisplayName>
"@

        # Add SQL Server CounterDisplayName entries
        if ($script:SQLInstance -eq "[Auto]") {
            foreach ($instance in $script:SQLServerInstances) {
                if ($instance -eq "MSSQLSERVER") {
                    $xmlContent += @"
<CounterDisplayName>\SQLServer:Wait Statistics(*)\*</CounterDisplayName>
<CounterDisplayName>\SQLServer:Access Methods\*</CounterDisplayName>
<CounterDisplayName>\SQLServer:Buffer Manager\*</CounterDisplayName>
<CounterDisplayName>\SQLServer:Databases(*)\*</CounterDisplayName>
<CounterDisplayName>\SQLServer:Latches\*</CounterDisplayName>
<CounterDisplayName>\SQLServer:Locks(_Total)\*</CounterDisplayName>
<CounterDisplayName>\SQLServer:SQL Statistics\*</CounterDisplayName>
<CounterDisplayName>\SQLServer:Transactions\*</CounterDisplayName>
"@
                }
                else {
                    $xmlContent += @"
<CounterDisplayName>\MSSQL`$$instance`:Wait Statistics(*)\*</CounterDisplayName>
<CounterDisplayName>\MSSQL`$$instance`:Access Methods\*</CounterDisplayName>
<CounterDisplayName>\MSSQL`$$instance`:Buffer Manager\*</CounterDisplayName>
<CounterDisplayName>\MSSQL`$$instance`:Databases(*)\*</CounterDisplayName>
<CounterDisplayName>\MSSQL`$$instance`:Latches\*</CounterDisplayName>
<CounterDisplayName>\MSSQL`$$instance`:Locks(_Total)\*</CounterDisplayName>
<CounterDisplayName>\MSSQL`$$instance`:SQL Statistics\*</CounterDisplayName>
<CounterDisplayName>\MSSQL`$$instance`:Transactions\*</CounterDisplayName>
"@
                }
            }
        }
        elseif ($script:SQLInstance -eq "Default") {
            $xmlContent += @"
<CounterDisplayName>\SQLServer:Wait Statistics(*)\*</CounterDisplayName>
<CounterDisplayName>\SQLServer:Access Methods\*</CounterDisplayName>
<CounterDisplayName>\SQLServer:Buffer Manager\*</CounterDisplayName>
<CounterDisplayName>\SQLServer:Databases(*)\*</CounterDisplayName>
<CounterDisplayName>\SQLServer:Latches\*</CounterDisplayName>
<CounterDisplayName>\SQLServer:Locks(_Total)\*</CounterDisplayName>
<CounterDisplayName>\SQLServer:SQL Statistics\*</CounterDisplayName>
<CounterDisplayName>\SQLServer:Transactions\*</CounterDisplayName>
"@
        }
        else {
            $xmlContent += @"
<CounterDisplayName>\MSSQL`$$($script:SQLInstance)`:Wait Statistics(*)\*</CounterDisplayName>
<CounterDisplayName>\MSSQL`$$($script:SQLInstance)`:Access Methods\*</CounterDisplayName>
<CounterDisplayName>\MSSQL`$$($script:SQLInstance)`:Buffer Manager\*</CounterDisplayName>
<CounterDisplayName>\MSSQL`$$($script:SQLInstance)`:Databases(*)\*</CounterDisplayName>
<CounterDisplayName>\MSSQL`$$($script:SQLInstance)`:Latches\*</CounterDisplayName>
<CounterDisplayName>\MSSQL`$$($script:SQLInstance)`:Locks(_Total)\*</CounterDisplayName>
<CounterDisplayName>\MSSQL`$$($script:SQLInstance)`:SQL Statistics\*</CounterDisplayName>
<CounterDisplayName>\MSSQL`$$($script:SQLInstance)`:Transactions\*</CounterDisplayName>
"@
        }

        # Add OLAP CounterDisplayName entries
        if ($script:OLAPServerInstances.Count -gt 0) {
            foreach ($olapInstance in $script:OLAPServerInstances) {
                if ($olapInstance -eq "MSSQLSERVER") {
                    $ssasVersions = @("MSAS10", "MSAS10_50", "MSAS11", "MSAS12", "MSAS13", "MSAS14", "MSAS15", "MSAS16")
                    foreach ($version in $ssasVersions) {
                        $xmlContent += @"
<CounterDisplayName>\$version`:Cache\*</CounterDisplayName>
<CounterDisplayName>\$version`:Connection\*</CounterDisplayName>
<CounterDisplayName>\$version`:Locks\*</CounterDisplayName>
<CounterDisplayName>\$version`:MDX\*</CounterDisplayName>
<CounterDisplayName>\$version`:Memory\*</CounterDisplayName>
<CounterDisplayName>\$version`:Proc Aggregations\*</CounterDisplayName>
<CounterDisplayName>\$version`:Proc Indexes\*</CounterDisplayName>
<CounterDisplayName>\$version`:Processing\*</CounterDisplayName>
<CounterDisplayName>\$version`:Storage Engine Query\*</CounterDisplayName>
<CounterDisplayName>\$version`:Threads\*</CounterDisplayName>
"@
                    }
                }
                else {
                    $xmlContent += @"
<CounterDisplayName>\MSOLAP`$$olapInstance`:Cache\*</CounterDisplayName>
<CounterDisplayName>\MSOLAP`$$olapInstance`:Connection\*</CounterDisplayName>
<CounterDisplayName>\MSOLAP`$$olapInstance`:Locks\*</CounterDisplayName>
<CounterDisplayName>\MSOLAP`$$olapInstance`:MDX\*</CounterDisplayName>
<CounterDisplayName>\MSOLAP`$$olapInstance`:Memory\*</CounterDisplayName>
<CounterDisplayName>\MSOLAP`$$olapInstance`:Proc Aggregations\*</CounterDisplayName>
<CounterDisplayName>\MSOLAP`$$olapInstance`:Proc Indexes\*</CounterDisplayName>
<CounterDisplayName>\MSOLAP`$$olapInstance`:Processing\*</CounterDisplayName>
<CounterDisplayName>\MSOLAP`$$olapInstance`:Storage Engine Query\*</CounterDisplayName>
<CounterDisplayName>\MSOLAP`$$olapInstance`:Threads\*</CounterDisplayName>
"@
                }
            }
        }

        $xmlContent += @"
<CounterDisplayName>\Network Interface(*)\*</CounterDisplayName>
<CounterDisplayName>\Memory\*</CounterDisplayName>
<CounterDisplayName>\Paging File\*</CounterDisplayName>
</PerformanceCounterDataCollector>
<Schedule>
	<StartDate>8/17/2014</StartDate>
	<EndDate>
	</EndDate>
	<StartTime>
	</StartTime>
	<Days>127</Days>
</Schedule>
<Schedule>
	<StartDate>8/17/2014</StartDate>
	<EndDate>
	</EndDate>
	<StartTime>12:00:00 PM</StartTime>
	<Days>127</Days>
</Schedule>
<DataManager>
	<Enabled>-1</Enabled>
	<CheckBeforeRunning>-1</CheckBeforeRunning>
	<MinFreeDisk>0</MinFreeDisk>
	<MaxSize>3000</MaxSize>
	<MaxFolderCount>0</MaxFolderCount>
	<ResourcePolicy>1</ResourcePolicy>
	<ReportFileName>report.html</ReportFileName>
	<RuleTargetFileName>report.xml</RuleTargetFileName>
	<EventsFileName>
	</EventsFileName>
	<FolderAction>
		<Size>3000</Size>
		<Age>21</Age>
		<Actions>18</Actions>
		<SendCabTo>
		</SendCabTo>
	</FolderAction>
</DataManager>
</DataCollectorSet>
"@

        # Write XML content to file
        $xmlContent | Out-File -FilePath "RDIPDC.xml" -Encoding UTF8
        Start-Sleep -Milliseconds 500
    }
    catch {
        Write-Error "Write file error: XML - $_"
    }
}

# Function to check file content for specific string
function Test-FileContent {
    param(
        [string]$FileName,
        [string]$StringContent
    )
    
    if (Test-Path $FileName) {
        try {
            $content = Get-Content $FileName -First 1
            return $content.Trim().StartsWith($StringContent)
        }
        catch {
            return $false
        }
    }
    return $false
}

# Function to register/import Performance Monitor XML
function Register-PerfmonXML {
    try {
        $result = Start-ProcessHidden "logman import -n RPDCLI -xml RDIPDC.xml > lmimp.dat" $true
        Start-Sleep -Milliseconds 500
        
        if (Test-FileContent "lmimp.dat" "The command completed successfully") {
            Write-Host "Collector created."
            Write-Host "Run with -2 or -start as parameter to start data collection process."
        }
        else {
            Write-Host "Collector creation failed. Enable debug mode and check the error message on lmimp.dat."
        }
    }
    catch {
        Write-Error "Error registering Performance Monitor XML: $_"
    }
}

# Function to start Performance Monitor data collection
function Start-PerfmonXML {
    try {
        $result = Start-ProcessHidden "logman start RPDCLI > lmsta.dat" $true
        Start-Sleep -Milliseconds 500
        
        if (Test-FileContent "lmsta.dat" "The command completed successfully") {
            Write-Host "Collector started."
            Write-Host "Run with -3 or -stop as parameter to later stop data collection process."
        }
        else {
            Write-Host "Collector starting failed."
            Write-Host "Please ensure collection already registered."
            Write-Host "Enable debug mode and check the error message on lmsta.dat."
        }
    }
    catch {
        Write-Error "Error starting Performance Monitor: $_"
    }
}

# Function to stop Performance Monitor data collection
function Stop-PerfmonXML {
    try {
        $result = Start-ProcessHidden "logman stop RPDCLI > lmsto.dat" $true
        Start-Sleep -Milliseconds 500
        
        if (Test-FileContent "lmsto.dat" "The command completed successfully") {
            Write-Host "Collector stopped."
            Write-Host "Run with -4 or -clean as parameter to remove collector."
        }
        else {
            Write-Host "Collector stopping failed."
            Write-Host "Please ensure collection already registered and started."
            Write-Host "Enable debug mode and check the error message on lmsto.dat."
        }
    }
    catch {
        Write-Error "Error stopping Performance Monitor: $_"
    }
}

# Function to remove/delete Performance Monitor data collector
function Remove-PerfmonXML {
    try {
        $result = Start-ProcessHidden "logman delete RPDCLI > lmdel.dat" $true
        Start-Sleep -Milliseconds 500
        
        if (Test-FileContent "lmdel.dat" "The command completed successfully") {
            Write-Host "Collector removed."
            Write-Host "Run with -1 or -install as parameter to reinstall collector."
        }
        else {
            Write-Host "Collector removal failed."
            Write-Host "Please ensure collection exists and on stopped condition."
            Write-Host "Enable debug mode and check the error message on lmdel.dat."
        }
    }
    catch {
        Write-Error "Error removing Performance Monitor: $_"
    }
}

# Function to check if running with elevated privileges
function Test-IsElevated {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Main execution logic
function Main {
    $script:ValidParam = $false
    
    # Display version information
    if (Test-Is64Bit) {
        Write-Host "RPDC CLI v$(Get-BuildInfoAsString)/X64 - Copyright (c)2016-2022, Arief Nugraha"
    }
    else {
        Write-Host "RPDC CLI v$(Get-BuildInfoAsString)/X86 - Copyright (c)2016-2022, Arief Nugraha"
    }
    
    Write-Host ""
    Remove-DataFiles
    
    # Show help if no parameters provided
    if ([string]::IsNullOrEmpty($Action)) {
        Write-Host "Valid parameters:"
        Write-Host "  -i, -install, -1 : Install/setup/register RPDC Performance Data Collector"
        Write-Host "  -r, -start  , -2 : Run/start RPDC Performance Data Collector"
        Write-Host "  -s, -stop   , -3 : Stop RPDC Performance Data Collector"
        Write-Host "  -c, -clean  , -4 : Clean up/deregister any RPDC Performance Data Collector"
        return
    }
    
    # Check for elevated privileges
    if (-not (Test-IsElevated)) {
        Write-Host "Not started in Elevated mode. Tool cannot run any further."
        Write-Host "Please run from a PowerShell window in Elevated mode and try again..."
        return
    }
    
    # Process install/setup/register commands
    if ($Action -eq "-1" -or $Action.ToUpper() -eq "-I" -or $Action.ToUpper() -eq "-INSTALL" -or 
        $Action.ToUpper() -eq "-SETUP" -or $Action.ToUpper() -eq "-REGISTER") {
        $script:ValidParam = $true
        $script:SQLServerInstances = @()
        $script:OLAPServerInstances = @()
        
        Find-SQLServerInstances
        Write-Host "Registering RPDC Performance Data Collector..."
        New-PerfmonXML
        Register-PerfmonXML
    }
    
    # Process start/run commands
    if ($Action -eq "-2" -or $Action.ToUpper() -eq "-R" -or $Action.ToUpper() -eq "-RUN" -or 
        $Action.ToUpper() -eq "-START") {
        $script:ValidParam = $true
        Write-Host "Starting RPDC Performance Data Collector..."
        Start-PerfmonXML
    }
    
    # Process stop commands
    if ($Action -eq "-3" -or $Action.ToUpper() -eq "-S" -or $Action.ToUpper() -eq "-STOP") {
        $script:ValidParam = $true
        Write-Host "Stopping RPDC Performance Data Collector..."
        Stop-PerfmonXML
    }
    
    # Process clean/clear/deregister commands
    if ($Action -eq "-4" -or $Action.ToUpper() -eq "-C" -or $Action.ToUpper() -eq "-CLEAR" -or 
        $Action.ToUpper() -eq "-CLEAN" -or $Action.ToUpper() -eq "-DEREGISTER") {
        $script:ValidParam = $true
        Write-Host "Cleaning up RPDC Performance Data Collector..."
        Remove-PerfmonXML
    }
    
    # Clean up temporary files unless debug mode is enabled
    if (-not $KeepTempFiles) {
        Remove-DataFiles
    }
    
    # Show error for invalid parameters
    if (-not $script:ValidParam) {
        Write-Host "$Action is not a valid parameter"
    }
    
    Write-Host ""
    Write-Host "Program exit!"
}

# Execute main function
Main
