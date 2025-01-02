<#
.Synopsis
Created on:   09/06/2024
Updated on:   01/01/2025
Created by:   Ben Whitmore
Filename:     Get-SasUri.ps1

.Description
Function to get a SAS URI for uploading content to Azure Blob storage

.PARAMETER Win32AppId
The ID of the Win32 app to upload content for

.PARAMETER ContentRequest
The content request JSONobject containing version information

.PARAMETER MaxWaitTime
The maximum wait time in seconds until the SAS URI is available. Default is 300 seconds

.PARAMETER MaxRetries
The maximum number of retries. Default is 10

.PARAMETER LogId
The component (script name) passed as LogID to the Write-Log function

#>
function Get-SasUri {
    param(
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = 'The ID of the Win32 app')]
        [string]$Win32AppId,

        [Parameter(Mandatory = $true, Position = 1, HelpMessage = 'The content request object')]
        [string]$ContentRequest,

        [Parameter(Mandatory = $false, Position = 2, HelpMessage = 'The maximum wait time in seconds until the SAS URI is available.')]
        [int]$MaxWaitTime = 300,

        [Parameter(Mandatory = $false, Position = 3, HelpMessage = 'The maximum number of retries.')]
        [int]$MaxRetries = 10,

        [Parameter(Mandatory = $false,  HelpMessage = 'The component (script name) passed as LogID to the Write-Log function')]
        [string]$LogId = $($MyInvocation.MyCommand).Name
    )

    begin {
        Write-LogAndHost -Message "Function: Get-SasUri was called" -LogId $LogId -ForegroundColor Cyan
    }

    process {

        try {

            # Create new content request for Win32app
            Write-LogAndHost -Message "Creating request for content version" -LogId $LogId -ForegroundColor Cyan
            $contentVersionRequest = Invoke-MgGraphRequestCustom -Method POST -Resource ("deviceAppManagement/mobileApps/{0}/microsoft.graph.win32LobApp/contentVersions" -f $Win32AppId) -Body "{}"

            if ($contentVersionRequest.Id) {
                Write-LogAndHost -Message ("Content Version to use is '{0}'. " -f $contentVersionRequest.id) -LogId $LogId -ForegroundColor Green
            }
            
            # Build the Uri's
            Write-LogAndHost -Message ("Committing content information for '{0}'. JSON Body: {1}" -f $Win32AppId, $contentRequest) -LogId $LogId -ForegroundColor Cyan
            $buildContentRequestUri = "deviceAppManagement/mobileApps/{0}/microsoft.graph.Win32LobApp/contentVersions/{1}/files" -f $Win32AppId, $contentVersionRequest.id

            # Create the content request
            $contentRequestUri = Invoke-MgGraphRequestCustom -Method POST -Resource $buildContentRequestUri -Body $contentRequest
            $probeContentRequestUri = "deviceAppManagement/mobileApps/{0}/microsoft.graph.Win32LobApp/contentVersions/{1}/files/{2}" -f $Win32AppId, $contentVersionRequest.id, $contentRequestUri.id

            # Let's wait for the conetnt landing zone to be ready
            $tries = 0
            $startTime = Get-Date
            do {
                try {

                    # Get the content ready state
                    $contentReady = Invoke-MgGraphRequestCustom -Method 'GET' -Resource $probeContentRequestUri
                    $tries++

                    if ($contentReady.uploadState -eq 'azureStorageUriRequestSuccess') {
                        Write-LogAndHost -Message ("Probe content request Sas Uri attempt {0}/{1}" -f $tries, $MaxRetries) -LogId $LogId -ForegroundColor Cyan
                        Write-LogAndHost -Message ("Sas Uri state is '{0}'" -f $contentReady.uploadState) -LogId $LogId -ForegroundColor Green

                        break
                    } else {
                        Write-LogAndHost -Message ("Probe content request Sas Uri attempt {0}/{1}" -f $tries, $MaxRetries) -LogId $LogId -Severity 2
                        Write-LogAndHost -Message ("Sas Uri state is '{0}'" -f $contentReady.uploadState) -LogId $LogId -Severity 2
                    }
                }
                catch {
                    Write-LogAndHost -Message ("Error during probe content request: {0}" -f $_.Exception.Message) -LogId $LogId -Severity 3
                }

                Start-Sleep -Seconds 3
            } until ($contentReady.uploadState -eq 'azureStorageUriRequestSuccess' -or [int]((Get-Date) - $startTime).TotalSeconds -gt $MaxWaitTime -or $tries -ge $MaxRetries)

            # Output the SAS Uri information to the console and log
            $contentReadyOutput = @{}
            $contentReadyOutputJson = @()

            foreach ($property in $contentReady.GetEnumerator() | Sort-Object -Property Key) {

                # Skip the manifest property (It's too long to output!)
                if ($property.Key -ne 'manifest') {
                    $contentReadyOutputJson += [PSCustomObject]@{Key = $property.Key; Value = $property.Value }
                    $contentReadyOutput[$property.Key] = $property.Value
                }
            }

            # Make sure we have a Sas Uri - sometimes null is returned
            if ($contentReadyOutput["azureStorageUri"]) {
                Write-Host ("{0}" -f ($contentReadyOutputJson | ConvertTo-Json -Depth 5 -Compress)) -ForegroundColor Green
                Write-Log -Message ("{0}" -f ($contentReadyOutput | ConvertTo-Json -Depth 5 -Compress)) -LogId $LogId
                
                return @{
                    contentReady     = $contentReady
                    contentVersion   = $contentVersionRequest.id
                    contentRequestId = $contentRequestUri.id
                }
            } else {
                Write-LogAndHost -Message "azureStorageUri is null" -LogId $LogId -Severity 3
            }
        }
        catch {
            Write-LogAndHost -Message ("Failed to get Sas Uri: {0}" -f $_) -LogId $LogId -Severity 3
        }
    }
}