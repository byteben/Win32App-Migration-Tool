<#
.SYNOPSIS
Commits the uploaded Win32 content to Intune

Created on:   30/12/2024
Updated on:   01/01/2025
Created by:   Ben Whitmore
Filename:     Invoke-IntuneContentCommit.ps1

.DESCRIPTION
This function commits the uploaded Win32 content to Intune by creating a commit request and waiting for processing.

.PARAMETER Win32AppId
The ID of the Win32 app

.PARAMETER ContentVersion
The ID of the content version

.PARAMETER ContentRequestId
The ID of the content request

.PARAMETER EncryptionInfo
The encryption information for the file

.PARAMETER RetryCount
The number of times to retry the commit request if it fails

.PARAMETER RetryDelay
The number of seconds to delay between retries

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

        [Parameter(Mandatory = $false, Position = 4, HelpMessage = 'The number of times to retry the commit request if it fails')]
        [int]$RetryCount = 10,

        [Parameter(Mandatory = $false, Position = 5, HelpMessage = 'The number of seconds to delay between retries')]
        [int]$RetryDelay = 5,

        [Parameter(Mandatory = $false, HelpMessage = 'Component name for logging')]
        [string]$LogId = $($MyInvocation.MyCommand).Name
    )

    process {

        try {

            # Prepare the JSON for the commit request
            $EncryptionInfoObject = $EncryptionInfo | ConvertFrom-Json
            $json = @{ 
                "fileEncryptionInfo" = $EncryptionInfoObject 
            } 
            $commitJSONEntry = $json | ConvertTo-Json -Compress

            # Resource Uri for the commit request
            $commitUri = "deviceAppManagement/mobileApps/{0}/microsoft.graph.win32LobApp/contentVersions/{1}/files/{2}" -f $Win32AppId, $ContentVersion, $ContentRequestId

            # Commit the content
            try {
                $commitPostResponse = Invoke-MgGraphRequestCustom -Method POST -Resource "$($commitUri)/commit" -Body $commitJSONEntry
                Write-LogAndHost -Message ("Commit request sent successfully to {0}:" -f $commitUri) -LogId $LogId -ForegroundColor Green
                Write-LogAndHost -Message ("Commit Body: {0}" -f $commitJSONEntry) -LogId $LogId -ForegroundColor Green
            }
            catch {
                Write-LogAndHost -Message ("Failed to commit content to {0}: {1}" -f $commitUri, $_.Exception.Message) -LogId $LogId -Severity 3

                throw
            }
                    
            # Check upload state
            $success = $false
            $attempt = 1

            do {
                try {

                    # Make the GET request to check upload state
                    $statusResponse = Invoke-MgGraphRequestCustom -Method GET -Resource $commitUri

                    # Check if the upload state is acceptable
                    if (($statusResponse.uploadState) -eq "commitFileSuccess" ) {
                        Write-LogAndHost -Message ("Upload state is '{0}'." -f ($statusResponse.uploadState)) -LogId $LogId -ForegroundColor Green
                        $success = $true
                    }
                    elseif (($statusResponse.uploadState) -eq "commitFileFailed" ) {
                        $contentReadyOutput = [ordered]@{}

                        foreach ($property in $statusResponse.GetEnumerator() | Sort-Object -Property Key) {

                            # Skip the manifest property (it's too long to output!)
                            if ($property.Key -ne 'manifest') {
                                $contentReadyOutput[$property.Key] = $property.Value
                            }
                        }
                        $contentReadyOutputJson = $contentReadyOutput | ConvertTo-Json -Compress
                        Write-Log -Message ("Upload state is '{0}'. The commit failed. The response was: {1}" -f ($statusResponse.uploadState), $contentReadyOutputJson) -LogId $LogId -Severity 2
                        $success = $false

                        break
                    }
                    else {
                        Write-LogAndHost -Message ("Attempt {0}/{1}. Upload state is '{2}'. Waiting for commit..." -f $attempt, $RetryCount, ($statusResponse.uploadState)) -LogId $LogId -Severity 2
                        Start-Sleep -Seconds $RetryDelay
                    }
                }
                catch {

                    # Log error and decide whether to retry
                    Write-LogAndHost -Message ("Attempt {0}/{1} failed. Error: {2}" -f $attempt, $RetryCount, $_.Exception.Message) -LogId $LogId -Severity 2
                    Write-LogAndHost -Message ("Attempt {0}/{1} failed. Retrying in {2} seconds." -f $attempt, $RetryCount, $RetryDelay) -LogId $LogId -Severity 2
                    Start-Sleep -Seconds $RetryDelay
                }

                # Increment attempt counter only after each iteration
                $attempt++

            } while (-not $success -and $attempt -le $RetryCount)

            if ($success) {
                Write-LogAndHost -Message "Commit operation completed successfully." -LogId $LogId -ForegroundColor Green

                # Now update the app with the committed content version
                Write-LogAndHost -Message ("Updating committed content version for app {0} to {1}..." -f $Win32Appid, $ContentVersion) -LogId $LogId -ForegroundColor Cyan

                $updateAppUri = "deviceAppManagement/mobileApps/$($Win32AppId)"
                $updateData = @{
                    "@odata.type"           = "#microsoft.graph.Win32LobApp"
                    committedContentVersion = $contentVersion
                }

                $updateDataJson = $updateData | ConvertTo-Json -Compress
                Write-LogAndHost -Message ("Committed content version data: {0}" -f $updateDataJson) -LogId $LogId -ForegroundColor Green
                
                try {
                    $updateResponse = Invoke-MgGraphRequestCustom -Method PATCH -Resource $updateAppUri -Body $updateDataJson
                    Write-LogAndHost -Message ("Successfully updated the content version in Intune for '{0}'" -f $Win32AppId) -LogId $LogId -ForegroundColor Green

                    return $true
                }
                catch {
                    Write-LogAndHost -Message ("Failed to update app {0} with committed content version: {1}" -f $Win32AppId, $_.Exception.Message) -LogId $LogId -Severity 3

                    return $false
                }
                
            }
        }
        catch {
            Write-LogAndHost -Message ("Commit operation failed: {0}" -f $_.Exception.Message) -LogId $LogId -Severity 3

            return $false
        }
    }
}
