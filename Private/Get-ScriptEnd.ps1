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
            Write-LogAndHost -Message $ErrorMessage -LogId $LogId -Severity 3
        }
    } 
    end {

        if (Test-Path -Path $PSScriptRoot ) {
            Set-Location -Path $PSScriptRoot
        }
        else {
            Write-LogAndHost -Message "Failed to set location to $PSScriptRoot" -LogId $LogId -Severity 3
        }

        # If connected to Microsoft Graph, disconnect unless the reason the script is ending is due to a failed connection
        if ($ErrorMessage -notlike "*Failed to connect to Microsoft Graph*") {
            
            if (Test-MgConnection) {
                $userInput = Read-Host -Prompt "Do you want to disconnect from Microsoft Graph? (y) or [n]"

                if ($userInput -eq '') {
                    $userInput = 'n'
                }
                switch ($userInput.ToLower()) {
                    "n" {
                        Write-LogAndHost -Message "Leaving Microsoft Graph session open" -LogId $LogId -ForegroundColor Cyan
                        Get-MgContext
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
                Write-LogAndHost "No active Microsoft Graph connection found" -LogId $LogId -Severity 2
            }
        }
    
        Write-LogAndHost -Message "## The Win32AppMigrationTool Script has Finished ##" -LogId $LogId -ForegroundColor Gray

        Exit 0
    }
}
