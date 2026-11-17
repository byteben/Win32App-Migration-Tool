<#
.Synopsis
Created on:   17/11/2026
Created by:   Ben Whitmore
Filename:     Test-MgGraphAccess.ps1

.Description
Checks that the current Microsoft Graph connection can actually be used, before any app is processed.

Test-MgConnection only reads Get-MgContext. A connection left in the session (for example by an earlier
Connect-MgGraph that didn't finish signing in, or one made with another app registration) can have the right
scopes but no usable token. The Graph SDK then asks for a sign-in on the first real request, partway through the
migration. This function makes one small read request up front, so any sign-in happens at the start, and it
reports a connection made with a different app registration.

Returns $true when the connection works for the given client id, otherwise $false.

.PARAMETER LogId
The component (script name) passed as LogID to the 'Write-Log' function

.PARAMETER ClientId
The app registration the run should use. A connection made with a different one is not reused
#>
function Test-MgGraphAccess {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, HelpMessage = 'LogId name of the script of the calling function')]
        [string]$LogId = $($MyInvocation.MyCommand).Name,
        [Parameter(Mandatory = $false, HelpMessage = 'The app registration the run should use')]
        [string]$ClientId
    )

    $context = Get-MgContext -ErrorAction SilentlyContinue
    if (-not $context) { return $false }

    if ($ClientId -and $context.ClientId -and $context.ClientId -ne $ClientId) {
        Write-LogAndHost -Message ("The current Microsoft Graph connection uses app registration '{0}', not '{1}'" -f $context.ClientId, $ClientId) -LogId $LogId -Severity 2
        return $false
    }

    try {
        Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/beta/deviceAppManagement/mobileApps?$top=1&$select=id' -ErrorAction Stop | Out-Null
        Write-LogAndHost -Message 'The Microsoft Graph connection works' -LogId $LogId -ForegroundColor Green
        return $true
    }
    catch {
        Write-LogAndHost -Message ("The current Microsoft Graph connection can't be used: {0}" -f $_.Exception.Message) -LogId $LogId -Severity 2
        return $false
    }
}
