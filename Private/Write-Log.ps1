
<#
.Synopsis
Created on:   21/03/2021
Created by:   Ben Whitmore
Filename:     Write-Log.ps1

.Description
Function to write to a log file
#>
function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter()]
        [String]$Message,
        [String]$Log,
        [Switch]$ResetLogFile
    )
    If ($ResetLogFile) {
        $Output = (Get-Date -f g) + ": Log File Reset"
        $Output | Out-File -Encoding Ascii (Join-Path -Path $WorkingFolder_Logs -ChildPath $Log) 
    }
    else {

        $Output = (Get-Date -f g) + ": " + $Message
        $Output | Out-File -Encoding Ascii -Append (Join-Path -Path $WorkingFolder_Logs -ChildPath $Log)
    }
}