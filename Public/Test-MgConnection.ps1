<#
.Synopsis
Created on:   28/12/2023
Created by:   Ben Whitmore
Filename:     Test-MgConnection.ps1

.Description
Function to test Microsoft Graph connection status and required scopes

.PARAMETER LogID
The component (script name) passed as LogID to the 'Write-Log' function

.PARAMETER RequiredScopes
Array of scopes that should be present in the connection
#>
function Test-MgConnection {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$LogId = $($MyInvocation.MyCommand).Name,
        [Parameter(Mandatory = $false)]
        [string[]]$RequiredScopes = @('https://graph.microsoft.com/.default')
    )

    try {
        # Check if we have an active connection
        $context = Get-MgContext -ErrorAction Stop
        
        if (-not $context) {
            Write-Log -Message "No active Microsoft Graph connection found" -LogId $LogId
            return $false
        }

        # Check if we have the required scopes
        $missingScopes = $RequiredScopes | Where-Object { $context.Scopes -notcontains $_ }
        if ($missingScopes) {
            Write-Log -Message "Missing required scopes: $($missingScopes -join ', ')" -LogId $LogId
            return $false
        }

        # Connection is valid with required scopes
        Write-Log -Message "Valid Microsoft Graph connection with required scopes" -LogId $LogId
        return $true
    }
    catch {
        Write-Log -Message "Error checking Microsoft Graph connection: $($_.Exception.Message)" -LogId $LogId -Severity 2
        return $false
    }
}
