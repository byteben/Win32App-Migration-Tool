
<#
.Synopsis
Created on:   26/10/2023
Created by:   Ben Whitmore
Filename:     Write-Log.ps1

.Description
Function to write to a log file

.PARAMETER Message
The message to write to the log file

.PARAMETER LogFolder
The location of the log file to write to

.PARAMETER Log
The name of the log file to write to

.PARAMETER Severity
1 = Information (default severity)
2 = Warning
3 = Error

.PARAMETER Component
The component (script name) passed as LogID to the 'Write-Log' function
This parameter is built from the line number of the call from the function up the pipeline

.PARAMETER ResetLogFile
If specified, the log file will be reset
#>

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0, HelpMessage = "Message to write to the log file")]
        [String]$Message,
        [Parameter(Mandatory = $false, ValueFromPipeline = $true, Position = 1, HelpMessage = "Location of the log file to write to")]
        [String]$LogFolder = $workingFolder_Logs, #$workingFolder_Logs is defined as a Global parameter in the main script
        [Parameter(Mandatory = $false, ValueFromPipeline = $true, Position = 2, HelpMessage = "Name of the log file to write to. Main is the default log file")]
        [String]$Log = 'Main.log',
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, HelpMessage = "LogId name of the script of the calling function")]
        [String]$LogId = $($MyInvocation.MyCommand).Name,
        [Parameter(Mandatory = $false, ValueFromPipeline = $true, Position = 3, HelpMessage = "Severity of the log entry 1-3")]
        [ValidateSet(1, 2, 3)]
        [string]$Severity = 1,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, HelpMessage = "The component (script name) passed as LogID to the 'Write-Log' function including line number of invociation")]
        [string]$Component = [string]::Format('{0}:{1}', $logID, $($MyInvocation.ScriptLineNumber)),
        [Parameter(Mandatory = $false, ValueFromPipeline = $true, Position = 4, HelpMessage = "If specified, the log file will be reset")]
        [Switch]$ResetLogFile
    )

    Begin {
        $dateTime = Get-Date
        $date = $dateTime.ToString("MM-dd-yyyy", [Globalization.CultureInfo]::InvariantCulture)
        $time = $dateTime.ToString("HH:mm:ss.ffffff", [Globalization.CultureInfo]::InvariantCulture)
        $logToWrite = Join-Path -Path $LogFolder -ChildPath $Log
    }

    Process {
        if ($PSBoundParameters.ContainsKey('ResetLogFile')) {
            try {

                # Check if the logfile exists. We only need to reset it if it already exists
                if (Test-Path -Path $logToWrite) {

                    # Create a StreamWriter instance and open the file for writing
                    $streamWriter = New-Object -TypeName System.IO.StreamWriter -ArgumentList $logToWrite
        
                    # Write an empty string to the file without the append parameter
                    $streamWriter.Write("")
        
                    # Close the StreamWriter, which also flushes the content to the file
                    $streamWriter.Close()
                    Write-Host ("Log file '{0}' wiped" -f $logToWrite) -ForegroundColor Yellow
                }
                else {
                    Write-Warning ("Log file not found at '{0}'" -f $logToWrite)
                }
            }
            catch {
                Write-Error -Message ("Unable to wipe log file. Error message: {0}" -f $_.Exception.Message)
            }
        }
            
        try {

            # Extract log object and construct format for log line entry
            foreach ($messageLine in $Message) {
                $logDetail = [string]::Format('<![LOG[{0}]LOG]!><time="{1}" date="{2}" component="{3}" context="{4}" type="{5}" thread="{6}" file="">', $messageLine, $time, $date, $Component, $Context, $Severity, $PID)

                # Attempt log write
                try {
                    $streamWriter = New-Object -TypeName System.IO.StreamWriter -ArgumentList $logToWrite, 'Append'
                    $streamWriter.WriteLine($logDetail)
                    $streamWriter.Close()
                }
                catch {
                    Write-Error -Message ("Unable to append log entry to '{0}' file. Error message: {1}" -f $logToWrite, $_.Exception.Message)
                }
            }
        }
        catch [System.Exception] {
            Write-Warning -Message ("Unable to append log entry to '{0}' file" -f $logToWrite)
        }
    }
}