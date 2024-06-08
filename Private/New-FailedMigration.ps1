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
Write-ErrorEntry -Date "08/06/2024" -Time "12:00" -Application "App1" -DeploymentType "Win32" -Reason "Failed to copy file"

#>

function Write-FailedMigrationEntry {
    [CmdletBinding()]
    param(

        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 0, HelpMessage = 'Application that failed')]
        [string]$Application,

        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 1, HelpMessage = 'Type of deployment that failed')]
        [string]$DeploymentType,

        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 2, HelpMessage = 'Reason for the failure')]
        [string]$Reason
    )

    Begin {
        
        # Create a global array to store the failed migration entries
        if (-not $global:FailedMigrationArray) {
            $global:FailedMigrationArray = @()
        } 

        Write-Log -Message "Function: Write-FailedMigrationEntry was called" -LogId $LogId
    }

    Process {
        $errorEntry = @{
            Application    = $Application
            DeploymentType = $DeploymentType
            Reason         = $Reason
        }

        # Append the error entry as a custom object to the global array
        $errorToWrite = New-Object PSObject -Property $ErrorEntry

        try {
            $global:FailedMigrationArray += $errorToWrite
            Write-Log -Message ("The application '{0}' with deployment Type '{1}'could not be migrated because '{2}'" -f $errorEntry.Application, $errorEntry.DeploymentType, $errorEntry.Reason)  -LogId $LogId -Severity 3
        }
        catch {
            throw "Failed to write error entry to global array"

            # Start with a basic error message
            $message = "Failed to write error entry to global array. "

            # Check if Application has a value and append it to the message if it does
            if ($errorEntry.Application) {
                $message += ("Application: '{0}'; " -f $errorEntry.Application)
            }

            # Check if DeploymentType has a value and append it to the message if it does
            if ($errorEntry.DeploymentType) {
                $message += ("DeploymentType: '{1}'; " -f $errorEntry.DeploymentType)
            }

            Write-Log -Message $message -LogId $LogId -Severity 3
        }
    }
}