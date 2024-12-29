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
        [string[]]$RequiredScopes,
        [switch]$TestScopes
    )

    # If we don't have required scopes, set the default required scopes to create Win32 apps. This assumes the Connect-MgGraphCustom function is used outside of the New-Win32App function
    if (-not $RequiredScopes -and -not $TestScopes) {
        if (Test-Path variable:\global:scopes) {
            $RequiredScopes = $global:scopes
            Write-Log -Message ("Required Scopes are defined already in global variable. Using existing required scopes: {0}" -f $RequiredScopes) -LogId $LogId
            Write-Host ("Required Scopes are defined already in global variable: {0}" -f $RequiredScopes) -ForegroundColor Green
        }
        elseif (-not $TestScopes) {
            $global:scopes = @('DeviceManagementApps.ReadWrite.All')
            $RequiredScopes = $global:scopes
            Write-Log -Message ("Required Scopes are not defined yet. Using default required scopes to create Win32 apps: {0}" -f $RequiredScopes) -LogId $LogId
            Write-Host ("Required Scopes are not defined yet. Using default required scopes to create Win32 apps: {0}" -f $RequiredScopes) -ForegroundColor Green
        }
    }

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

        # Check if the required scopes are in the scopes of the active connection
        $scopes = $context.Scopes
        $missingScopes = $RequiredScopes | Where-Object { $scopes -notcontains $_ }
        if ($missingScopes) {
            Write-Log -Message "Missing required scopes: $($missingScopes -join ', ')" -LogId $LogId
            return $false
        }

        # Connection is valid with required scopes
        if ($TestScopes) {
            Write-Log -Message ("Valid Microsoft Graph connection with required scopes: {0}" -f $RequiredScopes) -LogId $LogId
            Write-Host ("Valid Microsoft Graph connection with required scopes: {0}" -f $RequiredScopes) -ForegroundColor Green
        }
        return $true
    }
    catch {
        Write-Log -Message "Error checking Microsoft Graph connection: $($_.Exception.Message)" -LogId $LogId -Severity 2
        return $false
    }
}