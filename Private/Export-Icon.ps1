<#
.Synopsis
Created on:   06/11/2023
Created by:   Ben Whitmore
Filename:     Export-Icon.ps1

.Description
Function to export icon from selected ConfigMgr Application

.PARAMETER LogId
The component (script name) passed as LogID to the 'Write-Log' function. 
This parameter is built from the line number of the call from the function up the pipeline

.PARAMETER AppName
The name of the application to export the icon for

.PARAMETER IconPath
The icon path to export the icon to

.PARAMETER IconData
The icon base64 data to export
#>
function Export-Icon {

    param (
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = "The component (script name) passed as LogID to the 'Write-Log' function")]
        [string]$LogId = $($MyInvocation.MyCommand).Name,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 0, HelpMessage = 'The name of the application to export the icon for')]
        [string]$AppName,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 1, HelpMessage = 'The icon path to export the icon to')]
        [string]$IconPath,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 2, HelpMessage = 'The icon base64 data to export')]
        [string]$IconData
    )
    process {

        try {
            
            #Check if the file exists
            if (Test-Path -Path $IconPath) {
                Write-Log -Message ("Application icon for '{0}' already exists at '{1}'" -f $AppName, $IconPath) -LogId $LogId -Severity 2
                Write-Host ("Application icon for '{0}' already exists at '{1}'" -f $AppName, $IconPath) -ForegroundColor Yellow
            }
            else {
                
                # Convert the base64 string to a byte array and save it to a file"
                $icon = [Convert]::FromBase64String($IconData)
                [System.IO.File]::WriteAllBytes($IconPath, $icon)

                # Check if the file exists
                if (Test-Path -Path $IconPath) {
                    Write-Log -Message ("Success: Application icon for '{0}' was exported successfully to '{1}'" -f $AppName, $IconPath) -LogId $LogId
                    Write-Host ("Success: Application icon for '{0}' was exported successfully to '{1}'" -f $AppName, $IconPath) -ForegroundColor Green
                }
            }
        }
        Catch {
            Write-Log -Message ("Could not export icon for '{0}' to '{1}'" -f $AppName, "$workingFolder_Root\Logos") -LogId $LogId -Severity 3
            Write-Warning -Message ("Could not export icon for '{0}' to '{1}'" -f $AppName, "$workingFolder_Root\Logos") 
        }
    }
}