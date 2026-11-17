<#
.SYNOPSIS
Commits the uploaded Win32 content to Intune

Created on:   30/12/2024
Updated on:   16/11/2026
Created by:   Ben Whitmore
Filename:     Invoke-IntuneContentCommit.ps1

.DESCRIPTION
This function commits the uploaded Win32 content to Intune by creating a commit request and waiting for Intune to process it.
Large files can take several minutes to commit, so the wait is time based. Throws if the commit fails or times out.

.PARAMETER Win32AppId
The ID of the Win32 app

.PARAMETER ContentVersion
The ID of the content version

.PARAMETER ContentRequestId
The ID of the content request

.PARAMETER EncryptionInfo
The encryption information for the file (JSON string)

.PARAMETER TimeoutSeconds
The maximum number of seconds to wait for the commit to complete. Default is 1800

.PARAMETER PollSeconds
The number of seconds between status checks. Default is 10

.PARAMETER LogId
Component name for logging

.EXAMPLE
Invoke-IntuneContentCommit -Win32AppId $Win32AppId -ContentVersion $ContentVersion -ContentRequestId $ContentRequestId -EncryptionInfo $EncryptionInfo -LogId "CommitWin32Content"
#>
function Invoke-IntuneContentCommit {
    param (
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = 'The ID of the Win32 app')]
        [string]$Win32AppId,

        [Parameter(Mandatory = $true, Position = 1, HelpMessage = 'The content version ID')]
        [string]$ContentVersion,

        [Parameter(Mandatory = $true, Position = 2, HelpMessage = 'The ID of the content request')]
        [string]$ContentRequestId,

        [Parameter(Mandatory = $true, Position = 3, HelpMessage = 'The encryption information for the file')]
        [string]$EncryptionInfo,

        [Parameter(Mandatory = $false, Position = 4, HelpMessage = 'The maximum number of seconds to wait for the commit to complete')]
        [int]$TimeoutSeconds = 1800,

        [Parameter(Mandatory = $false, Position = 5, HelpMessage = 'The number of seconds between status checks')]
        [int]$PollSeconds = 10,

        [Parameter(Mandatory = $false, HelpMessage = 'Component name for logging')]
        [string]$LogId = $($MyInvocation.MyCommand).Name
    )

    process {

        # Prepare the JSON for the commit request
        $encryptionInfoObject = $EncryptionInfo | ConvertFrom-Json
        $commitJSONEntry = @{ "fileEncryptionInfo" = $encryptionInfoObject } | ConvertTo-Json -Depth 5 -Compress

        # Resource Uri for the commit request
        $commitUri = "deviceAppManagement/mobileApps/{0}/microsoft.graph.win32LobApp/contentVersions/{1}/files/{2}" -f $Win32AppId, $ContentVersion, $ContentRequestId

        # Commit the content
        try {
            $null = Invoke-MgGraphRequestCustom -Method POST -Resource ("{0}/commit" -f $commitUri) -Body $commitJSONEntry
            Write-LogAndHost -Message ("Commit request sent successfully to {0} (encryption info sent, values not logged)" -f $commitUri) -LogId $LogId -ForegroundColor Green
        }
        catch {
            Write-LogAndHost -Message ("Failed to commit content to {0}: {1}" -f $commitUri, $_.Exception.Message) -LogId $LogId -Severity 3

            throw
        }

        # Wait for the commit to complete
        try {
            $null = Wait-IntuneContentFileState -Win32AppId $Win32AppId -ContentVersion $ContentVersion -ContentFileId $ContentRequestId -Stage commitFile -TimeoutSeconds $TimeoutSeconds -PollSeconds $PollSeconds -LogId $LogId
        }
        catch {
            Write-LogAndHost -Message ("Commit did not complete: {0}" -f $_.Exception.Message) -LogId $LogId -Severity 3

            throw
        }

        Write-LogAndHost -Message "Commit operation completed successfully." -LogId $LogId -ForegroundColor Green

        # Now update the app with the committed content version
        Write-LogAndHost -Message ("Updating committed content version for app {0} to {1}..." -f $Win32AppId, $ContentVersion) -LogId $LogId -ForegroundColor Cyan

        $updateAppUri = "deviceAppManagement/mobileApps/{0}" -f $Win32AppId
        $updateDataJson = @{
            "@odata.type"           = "#microsoft.graph.win32LobApp"
            committedContentVersion = $ContentVersion
        } | ConvertTo-Json -Compress

        try {
            $null = Invoke-MgGraphRequestCustom -Method PATCH -Resource $updateAppUri -Body $updateDataJson
            Write-LogAndHost -Message ("Successfully updated the content version in Intune for '{0}'" -f $Win32AppId) -LogId $LogId -ForegroundColor Green

            return $true
        }
        catch {
            Write-LogAndHost -Message ("Failed to update app {0} with committed content version: {1}" -f $Win32AppId, $_.Exception.Message) -LogId $LogId -Severity 3

            throw
        }
    }
}
