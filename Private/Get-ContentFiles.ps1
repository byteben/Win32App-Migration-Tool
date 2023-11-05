<#
.Synopsis
Created on:   04/11/2023
Created by:   Ben Whitmore
Filename:     Get-ContentFiles.ps1

.Description
Function to get content from the content source folder for the deployment type and copy it to the content destination folder

.PARAMETER LogId
The component (script name) passed as LogID to the 'Write-Log' function. 
This parameter is built from the line number of the call from the function up the

.PARAMETER Source
Source path for content to be copied from

.PARAMETER UninstallContent
Destination path for content to be copied to
#>
function Get-ContentFiles {
    param (
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = "The component (script name) passed as LogID to the 'Write-Log' function")]
        [string]$LogId = $($MyInvocation.MyCommand).Name,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 0, HelpMessage = 'Source path for content to be copied from')]
        [string]$Source,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 1, HelpMessage = 'Destination path for content to be copied to')]
        [string]$Destination
    )
    
    process {

        Write-Log -Message ("Attempting to to copy content from '{0}' to '{1}'" -f $Source, $Destination) -LogId $LogId
        Write-Host ("Attempting to to copy content from '{0}' to '{1}'" -f $Source, $Destination) -ForegroundColor Cyan
            
        # Build Robocopy parameters
        $uniLog = Join-Path -Path $workingFolder_Root -ChildPath "\Logs\Main.log"

        try {
            Write-Log -Message ("Invoking robocopy.exe '{0}' '{1}' /MIR /E /Z /R:5 /W:1 /NDL /NJH /NJS /NC /NS /NP /V /TEE  /UNILOG+:'{2}'" -f $Source, $Destination, $uniLog) -LogId $LogId 
        
            $args = @(
                $Source
                $Destination
                /MIR
                /E
                /Z
                /R:5
                /W:1
                /NDL
                /NJH
                /NJS
                /NC
                /NS
                /NP
                /V
                /TEE
                /UNILOG+:$uniLog
            )

            # Invoke robocopy.exe
            Start-Process Robocopy.exe -ArgumentList $args -Wait -NoNewWindow -PassThru 

            if ((Get-ChildItem -Path $Destination | Measure-Object).Count -eq 0 ) {

                Write-Log -Message ("Error: Could not transfer content from '{0}' to '{1}'" -f $Source, $Destination) -LogId $LogId -Severity 3
                Write-Warning -Message ("Error: Could not transfer content from '{0}' to '{1}'" -f $Source, $Destination)
            }
        }
        catch {
            Write-Log -Message ("Error: Could not transfer content from '{0}' to '{1}'" -f $Source, $Destination)  -LogId $LogId -Severity 3
            Write-Warning -Message ("Error: Could not transfer content from '{0}' to '{1}'" -f $Source, $Destination) 
        }
    }
}