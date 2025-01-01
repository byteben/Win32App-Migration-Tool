<#
.Synopsis
Created on:   21/10/2023
Updated on:   29/12/2024
Created by:   Ben Whitmore
Filename:     Get-ScriptEnd.ps1

.Description
Function to exit script

.PARAMETER LogId
The component (script name) passed as LogID to the 'Write-Log' function. 
This parameter is built from the line number of the call from the function up the

.PARAMETER ErrorMessage
The error message passed to the 'Get-ScriptEnd' function
#>
function Get-ScriptEnd {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = "The component (script name) passed as LogID to the 'Write-Log' function")]
        [string]$LogId = $($MyInvocation.MyCommand).Name,
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, Position = 0, HelpMessage = "The error message passed to the 'Get-ScriptEnd' function")]
        [string]$ErrorMessage
    )
    process {
        if ($ErrorMessage) {
            Write-Log -Message ("{0}" -f $ErrorMessage) -LogId $LogId -Severity 3
            Write-Warning -Message ("{0}" -f $ErrorMessage)
        }
    } 
    end {

        if (Test-Path -Path $PSScriptRoot ) {
            Set-Location -Path $PSScriptRoot
        }
        else {
            Write-Log -Message "Failed to set location to $PSScriptRoot" -LogId $LogId -Severity 3
        }

        # If connected to Microsoft Graph, disconnect
        if (Test-MgConnection) {
            $userInput = Read-Host -Prompt "Do you want to disconnect from Microsoft Graph? (y) or [n]"
            if ($userInput -eq '') {
                $userInput = 'n'
            }
            switch ($userInput.ToLower()) {
                "n" {
                    Write-Log -Message "Leaving Microsoft Graph connection open" -LogId $LogId
                    Write-Host "Leaving Microsoft Graph connection open" -ForegroundColor Cyan
                    break
                }
                "y" {
                    Write-Host "Disconnecting from Microsoft Graph" -ForegroundColor Cyan
                    Write-Log -Message "Disconnecting from Microsoft Graph" -LogId $LogId
                    Disconnect-MgGraph | Out-Null
                }
                default {
                    Write-Host "Invalid input. Please type 'y' or 'n'." -ForegroundColor Yellow
                }
            }
        }
        else {
            Write-Host "No active Microsoft Graph connection found" -ForegroundColor Yellow
            Write-Log -Message "No active Microsoft Graph connection found" -LogId $LogId
        }
        Write-Log -Message "## The Win32AppMigrationTool Script has Finished ##" -LogId $LogId
        Write-Host '## The Win32AppMigrationTool Script has Finished ##' -ForegroundColor Green
        break
    }
}
