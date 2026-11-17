<#
.Synopsis
Created on:   21/10/2023
Updated on:   16/11/2026
Created by:   Ben Whitmore
Filename:     Get-ScriptEnd.ps1

.Description
Function to finish a run. It restores the caller's location (saved in $global:Win32AppMigrationTool_OriginalLocation),
optionally offers to disconnect from Microsoft Graph and then returns. It never exits the PowerShell session.

.PARAMETER LogId
The component (script name) passed as LogID to the 'Write-Log' function. 
This parameter is built from the line number of the call from the function up the

.PARAMETER ErrorMessage
The error message passed to the 'Get-ScriptEnd' function. Also accepted as -Message

.PARAMETER NoPrompt
Do not prompt to disconnect from Microsoft Graph. The connection is left open
#>
function Get-ScriptEnd {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = "The component (script name) passed as LogID to the 'Write-Log' function")]
        [string]$LogId = $($MyInvocation.MyCommand).Name,
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, Position = 0, HelpMessage = "The error message passed to the 'Get-ScriptEnd' function")]
        [Alias('Message')]
        [string]$ErrorMessage,
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = 'Do not prompt to disconnect from Microsoft Graph')]
        [switch]$NoPrompt
    )
    process {
        if ($ErrorMessage) {
            Write-LogAndHost -Message $ErrorMessage -LogId $LogId -Severity 3
        }
    } 
    end {

        # Restore the caller's location
        if ($global:Win32AppMigrationTool_OriginalLocation) {
            try {
                Set-Location -Path $global:Win32AppMigrationTool_OriginalLocation -ErrorAction Stop
            }
            catch {
                Write-LogAndHost -Message ("Failed to restore location to '{0}'" -f $global:Win32AppMigrationTool_OriginalLocation) -LogId $LogId -Severity 3
            }
            Remove-Variable -Name Win32AppMigrationTool_OriginalLocation -Scope Global -ErrorAction SilentlyContinue
        }

        # If connected to Microsoft Graph, offer to disconnect unless the reason for ending is a failed connection
        if ($ErrorMessage -notlike "*Failed to connect to Microsoft Graph*") {
            
            if (Test-MgConnection) {
                if ($NoPrompt -or -not [Environment]::UserInteractive) {
                    Write-LogAndHost -Message "Leaving Microsoft Graph session open" -LogId $LogId -ForegroundColor Cyan
                }
                else {
                    $userInput = Read-Host -Prompt "Do you want to disconnect from Microsoft Graph? (y) or [n]"

                    if ([string]::IsNullOrEmpty($userInput)) {
                        $userInput = 'n'
                    }
                    switch ($userInput.ToLower()) {
                        "n" {
                            Write-LogAndHost -Message "Leaving Microsoft Graph session open" -LogId $LogId -ForegroundColor Cyan
                            Get-MgContext
                        }
                        "y" {
                            Write-LogAndHost -Message "Disconnecting from Microsoft Graph" -LogId $LogId -ForegroundColor Cyan
                            Disconnect-MgGraph | Out-Null
                        }
                        default {
                            Write-Host "Invalid input. Please type 'y' or 'n'." -ForegroundColor Yellow
                        }
                    }
                }
            }
            else {
                Write-LogAndHost -Message "No active Microsoft Graph connection found" -LogId $LogId -Severity 2
            }
        }
    
        Write-LogAndHost -Message "## The Win32AppMigrationTool Script has Finished ##" -LogId $LogId -ForegroundColor Gray
    }
}
