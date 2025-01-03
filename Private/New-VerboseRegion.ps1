<#
.Synopsis
Created on:   26/10/2023
Updated on:   03/01/2025
Created by:   Ben Whitmore
Filename:     New-VerboseRegion.ps1

.Description
Write verbose messages

.PARAMETER LogID
The component (script name) passed as LogID to the 'Write-Log' function. 
This parameter is built from the line number of the call from the function up the pipeline

.PARAMETER Messages
The message to write

.PARAMETER ForegroundColor
The colour of the message to write
#>
function New-VerboseRegion {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = 'The component (script name) passed as LogID to the Write-Log function')]
        [string]$LogId = $($MyInvocation.MyCommand).Name,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 0, HelpMessage = 'The message to write')]
        [String]$Message,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 1, HelpMessage = 'The colour of the message to write')]
        [String]$ForegroundColor = 'White'
    )
    Write-Log -Message "--------------------------------------------"
    Write-Log -Message ("{0}..." -f $Message )
    Write-Log -Message "--------------------------------------------"
    Write-Host ''
    Write-Host '--------------------------------------------' -ForegroundColor $ForegroundColor
    Write-Host ("{0}..." -f $Message) -ForegroundColor $ForegroundColor
    Write-Host '--------------------------------------------' -ForegroundColor $ForegroundColor
    Write-Host ''
}