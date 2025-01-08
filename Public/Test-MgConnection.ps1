<#
.Synopsis
Created on:   28/12/2024
Created by:   Ben Whitmore
Filename:     Test-MgConnection.ps1

.Description
Function to test Microsoft Graph connection status and required scopes

.PARAMETER LogID
The component (script name) passed as LogID to the 'Write-Log' function

.PARAMETER RequiredScopes
Array of scopes that should be present in the connection

.PARAMETER TestScopes
Switch to test the scopes of the connection
#>
function Test-MgConnection {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, HelpMessage = 'LogId name of the script of the calling function')]
        [string]$LogId = $($MyInvocation.MyCommand).Name,
        [Parameter(Mandatory = $false, HelpMessage = 'Scopes required for Microsoft Graph API access')]
        [string[]]$RequiredScopes,
        [Parameter(Mandatory = $false, HelpMessage = 'Test if scopes are defined')]
        [switch]$TestScopes
    )
    
    # If we don't have required scopes, set the default required scopes to create Win32 apps. This assumes the Connect-MgGraphCustom function is used outside of the New-Win32App function
    if (-not $RequiredScopes -and $TestScopes) {
        if (Test-Path variable:\global:scopes) {
            $RequiredScopes = $global:scopes
            Write-LogAndHost -Message ("Required Scopes are defined already in global variable. Using existing required scopes: {0}" -f ($RequiredScopes -join ', ')) -LogId $LogId -ForegroundColor Green
        }
    }
    elseif (-not $RequiredScopes -and -not $TestScopes) {
        $global:scopes = @('DeviceManagementApps.ReadWrite.All')
        $RequiredScopes = $global:scopes
    }
    
    try {
        # Check if we have an active connection
        $context = Get-MgContext -ErrorAction Stop
        
        if (-not $context) {
            Write-LogAndHost -Message "No active Microsoft Graph connection found" -LogId $LogId -Severity 2 -ForegroundColor Yellow
            return $false
        }
    
        # Check if the required scopes are in the scopes of the active connection
        $scopes = $context.Scopes
        $missingScopes = $RequiredScopes | Where-Object { $scopes -notcontains $_ }
        
        if ($missingScopes) {
            Write-LogAndHost -Message ("Missing required scopes: {0}" -f ($missingScopes -join ', ')) -LogId $LogId -Severity 2 -ForegroundColor Yellow

            return $false
        }
    
        # If we get here, we have a valid connection with the required scopes
        return $true
    }
    catch {
        Write-LogAndHost -Message ("Error while checking Microsoft Graph connection: {0}" -f $_.Exception.Message) -LogId $LogId -Severity 3 -ForegroundColor Red

        return $false
    }
}