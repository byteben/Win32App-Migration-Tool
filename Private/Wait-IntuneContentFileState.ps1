<#
.Synopsis
Created on:   16/11/2026
Updated on:   16/11/2026
Created by:   Ben Whitmore
Filename:     Wait-IntuneContentFileState.ps1

.Description
Polls an Intune Win32 app content file (mobileAppContentFile) until the uploadState reports success for the requested stage.
Returns the file resource on success. Throws when the stage reports Failed or TimedOut, or when the timeout elapses.
Any other state (Pending, transientError, unknown, or a state belonging to another stage) is treated as "keep waiting".

.PARAMETER Win32AppId
The ID of the Win32 app

.PARAMETER ContentVersion
The ID of the content version

.PARAMETER ContentFileId
The ID of the content file

.PARAMETER Stage
The stage to wait for. The success state is '<Stage>Success'. One of azureStorageUriRequest, azureStorageUriRenewal, commitFile

.PARAMETER TimeoutSeconds
Maximum number of seconds to wait. Default is 1800

.PARAMETER PollSeconds
Number of seconds between polls. Default is 10

.PARAMETER LogId
Component name for logging
#>
function Wait-IntuneContentFileState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, HelpMessage = 'The ID of the Win32 app')]
        [string]$Win32AppId,

        [Parameter(Mandatory = $true, HelpMessage = 'The ID of the content version')]
        [string]$ContentVersion,

        [Parameter(Mandatory = $true, HelpMessage = 'The ID of the content file')]
        [string]$ContentFileId,

        [Parameter(Mandatory = $true, HelpMessage = 'The stage to wait for')]
        [ValidateSet('azureStorageUriRequest', 'azureStorageUriRenewal', 'commitFile')]
        [string]$Stage,

        [Parameter(Mandatory = $false, HelpMessage = 'Maximum number of seconds to wait')]
        [int]$TimeoutSeconds = 1800,

        [Parameter(Mandatory = $false, HelpMessage = 'Number of seconds between polls')]
        [int]$PollSeconds = 10,

        [Parameter(Mandatory = $false, HelpMessage = 'Component name for logging')]
        [string]$LogId = $($MyInvocation.MyCommand).Name
    )

    $fileUri = "deviceAppManagement/mobileApps/{0}/microsoft.graph.win32LobApp/contentVersions/{1}/files/{2}" -f $Win32AppId, $ContentVersion, $ContentFileId
    $successState = '{0}Success' -f $Stage
    $failedState = '{0}Failed' -f $Stage
    $timedOutState = '{0}TimedOut' -f $Stage

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $lastState = 'unknown'
    $poll = 0

    while ($true) {
        $poll++

        try {
            $response = Invoke-MgGraphRequestCustom -Method GET -Resource $fileUri

            if ($null -ne $response -and $response.uploadState) {
                $lastState = [string]$response.uploadState
            }

            Write-LogAndHost -Message ("Waiting for '{0}': poll {1}, uploadState '{2}', elapsed {3}s of {4}s" -f $Stage, $poll, $lastState, [int]$stopwatch.Elapsed.TotalSeconds, $TimeoutSeconds) -LogId $LogId -ForegroundColor Cyan

            if ($lastState -eq $successState) {
                return $response
            }

            if ($lastState -eq $failedState -or $lastState -eq $timedOutState) {
                throw ("Intune reported uploadState '{0}' while waiting for '{1}'" -f $lastState, $Stage)
            }
        }
        catch {
            if ($lastState -eq $failedState -or $lastState -eq $timedOutState) {
                throw
            }

            # A 4xx (other than 408/429) is permanent, e.g. 401/403 or 404 when the app was deleted
            $errorStatus = $null
            if (Get-Command -Name Get-GraphErrorStatusCode -ErrorAction SilentlyContinue) { $errorStatus = Get-GraphErrorStatusCode -ErrorRecord $_ }
            if ($null -ne $errorStatus -and $errorStatus -ge 400 -and $errorStatus -lt 500 -and $errorStatus -notin @(408, 429)) {
                throw
            }

            # Transient error getting the state. Keep polling until the timeout
            Write-LogAndHost -Message ("Transient error polling '{0}': {1}" -f $Stage, $_.Exception.Message) -LogId $LogId -Severity 2
        }

        if ($stopwatch.Elapsed.TotalSeconds -ge $TimeoutSeconds) {
            $message = "Timed out after {0} seconds waiting for {1}; last state '{2}'" -f $TimeoutSeconds, $Stage, $lastState
            Write-LogAndHost -Message $message -LogId $LogId -Severity 3

            throw $message
        }

        if ($PollSeconds -gt 0) {
            Start-Sleep -Seconds $PollSeconds
        }
    }
}
