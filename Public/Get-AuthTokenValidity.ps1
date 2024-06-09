<#
.Synopsis
Created on:   09/06/2024
Updated on:   09/06/2024
Created by:   Ben Whitmore
Filename:     Get-AuthTokenValidity.ps1

.Description
Function to check if the global authenication token is still valid

.PARAMETER LogID
The component (script name) passed as LogID to the '#Write-Log' function. 
This parameter is built from the line number of the call from the function up the pipeline

.PARAMETER Token
The token object to check

.PARAMETER WarningThresholdHours
The number of hours before the token expires to issue a warning.Default is 1 hour

#>
function Get-AuthTokenValidity {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = 'The component (script name) passed as LogID to the "#Write-Log" function')]
        [string]$LogId = $($MyInvocation.MyCommand).Name,
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = 'Module Name to connect to Graph')]
        [object]$Token = $global:token,
        [int]$WarningThresholdHours = 1
    )

    begin {

        Write-Log -Message "Function: Get-AuthTokenValidity was called" -LogId $LogId

        $expiresDate = $global:token.ExpiresOn.UtcDateTime
        $expiresOn = [DateTime]::Parse($expiresDate)
        $currentTime = [DateTime]::UtcNow

        Write-Log -Message ("The current token expires on: '{0}' (Utc)" -f $expiresOn) -LogId $LogId
        Write-Host ("The current token expires on: '{0}' (Utc)" -f $expiresOn) -ForegroundColor Yellow
    }

    process {

        # Check if the token has expired
        if ($currentTime -gt $expiresOn) {
            Write-Log -Message "The token has expired. Need to renew token by using the Get-AuthToken module" -LogId $LogId -Severity 2
            Write-Host "The token has expired. Need to renew token by using the Get-AuthToken module" -ForegroundColor Yellow
            return "Expired" | Out-Null
        }
        else {

            # Check if the token is within the warning threshold of expiring
            $WarningThreshold = $CurrentTime.AddHours($WarningThresholdHours)

            if ($WarningThreshold -gt $ExpiresOn) {
                Write-Log -Message ("The token is within '{0}' hour(s) of expiring." -f $WarningThresholdHours) -LogId $LogId
                Write-Host ("The token is within '{0}' hour(s) of expiring." -f $WarningThresholdHours) -ForegroundColor Green
            }
            else {
                Write-Log -Message ("The token is valid and not within '{0}' hour(s) of expiring." -f $WarningThresholdHours) -LogId $LogId
                Write-Host ("The token is valid and not within '{0}' hour(s) of expiring." -f $WarningThresholdHours) -ForegroundColor Green
            }
            return "Valid" | Out-Null
        }
    }
}