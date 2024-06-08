<#
.Synopsis
Created on:   08/06/2024
Updated on:   08/06/2024
Created by:   Ben Whitmore
Filename:     New-FailedMigration.ps1

.Description
Function to log a failed migration

.PARAMETER LogId
The component (script name) passed as LogID to the 'Write-Log' function. 
This parameter is built from the line number of the call from the function up the pipeline

.PARAMETER Application
The application that failed

.PARAMETER DeploymentType
The type of deployment that failed

.PARAMETER Reason
The reason for the failure

.EXAMPLE
Get-ErrorEntry -Application "App1"

.EXAMPLE
Get-ErrorEntry -DeploymentType "App1_DeploymentType"

.Example
Get-ErrorEntry -Reason "Invalid detection type operands"

#>

function Get-FailedMigrationEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 0, HelpMessage = 'Application that failed')]
        [string]$Application,

        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 1, HelpMessage = 'Type of deployment that failed')]
        [string]$DeploymentType,

        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 2, HelpMessage = 'Type of deployment that failed')]
        [string]$Reason
    )

    Begin {
        Write-Log -Message "Function: Get-FailedMigrationEntry was called" -LogId $LogId
    }

    Process {
        
        # Loop through the global array of failed migrations
        foreach ($failure in $global.failedMigrationArray) {

            # Check if the failure matches the parameters
            if ($PSBoundParameters.ContainsKey('Application')) {
                if ($failure.Application -eq $Application) {
                    return $failure
                }
            }
            elseif ($PSBoundParameters.ContainsKey('DeploymentType')) {
                if ($failure.DeploymentType -eq $DeploymentType) {
                    return $failure
                }
            }
        }
    }
}
