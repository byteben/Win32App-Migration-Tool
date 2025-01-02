
<#
.Synopsis
Created on:   01/01/2025
Created by:   Ben Whitmore
Filename:     Write-LogAndHost.ps1

.Description
Function to write to a log file and host

.PARAMETER Message
The message to write to the log file

.PARAMETER LogId
The component (script name) passed as LogID to the 'Write-Log' function
This parameter is built from the line number of the call from the function up the pipeline

.PARAMETER ForegroundColor
The foreground color for Write-Host

.PARAMETER NewLine
Create this message on a new line

.PARAMETER Severity
1 = Information (default severity)
2 = Warning
3 = Error
#>

function Write-LogAndHost {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0, HelpMessage = 'Message to write to the log file and host')]
        [String]$Message,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 1, HelpMessage = 'LogId name of the script of the calling function')]
        [String]$LogId,
        [Parameter(Mandatory = $false, ValueFromPipeline = $true, Position = 2, HelpMessage = 'Foreground color for Write-Host')]
        [String]$ForegroundColor = "White",
        [Parameter(Mandatory = $false, ValueFromPipeline = $true, Position = 4, HelpMessage = 'Create this message on a new line')]
        [Switch]$NewLine,
        [Parameter(Mandatory = $false, ValueFromPipeline = $true, Position = 3, HelpMessage = 'Severity of the log entry 1-3')]
        [ValidateSet(1, 2, 3)]
        [int]$Severity = 1
    )

    begin {

        # Set the ForegroundColor based on the severity if not already specified
        switch ($Severity) {
            2 {
                if (-not $PSBoundParameters.ContainsKey('ForegroundColor')) {
                    $ForegroundColor = "Yellow"
                }
            }
            3 {
                if (-not $PSBoundParameters.ContainsKey('ForegroundColor')) {
                    $ForegroundColor = "Red"
                }
            }
        }
    }

    process {
        
        # Call Write-Log function to write the log
        Write-Log -Message $Message -LogId $LogId -Severity $Severity

        # Write the message to the host
        if ($PSBoundParameters.ContainsKey('NewLine')) {
            Write-Host "`n$Message" -ForegroundColor $ForegroundColor
        }
        else {
            Write-Host $Message -ForegroundColor $ForegroundColor
        }
    }
}