<#
.SYNOPSIS
Created on:   09/06/2024
Updated on:   09/06/2024
Created by:   Ben Whitmore
Filename:     Get-SasUri.ps1

.DESCRIPTION
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
        Write-Log -Message "Function: Get-SasUri was called" -LogId $LogId
    }

    process {

        try {

            # Create new content request for Win32app
            Write-Log -Message "Creating request for content version" -LogId $LogId
            Write-Host "Creating request for content version" -ForegroundColor Cyan
            $contentVersionRequest = Invoke-MgGraphRequestCustom -Method POST -Resource ("deviceAppManagement/mobileApps/{0}/microsoft.graph.win32LobApp/contentVersions" -f $Win32AppId) -Body "{}"

            if ($contentVersionRequest.Id) {
                Write-Log -Message ("Content Version to use is '{0}'. " -f $contentVersionRequest.id) -LogId $LogId
                Write-Host ("Content Version to use is '{0}'. " -f $contentVersionRequest.id) -ForegroundColor Green
            }
            
            # Build the Uri's
            Write-Log -Message ("Committing content information for '{0}'. JSON Body: {1}" -f $Win32AppId, $contentRequest) -LogId $LogId
            Write-Host ("Committing content information for '{0}'. JSON Body: {1}" -f $Win32AppId, $contentRequest) -ForegroundColor Cyan

            $buildContentRequestUri = "deviceAppManagement/mobileApps/{0}/microsoft.graph.Win32LobApp/contentVersions/{1}/files" -f $Win32AppId, $contentVersionRequest.id
            $contentRequestUri = Invoke-MgGraphRequestCustom -Method POST -Resource $buildContentRequestUri -Body $contentRequest

            $probeContentRequestUri = "deviceAppManagement/mobileApps/{0}/microsoft.graph.Win32LobApp/contentVersions/{1}/files/{2}" -f $Win32AppId, $contentVersionRequest.id, $contentRequestUri.id

            # Let's wait for the conetnt landing zone to be ready
            $tries = 0
            $startTime = Get-Date
            do {
                try {
                    $contentReady = Invoke-MgGraphRequestCustom -Method 'GET' -Resource $probeContentRequestUri
                    $tries++
                    if ($contentReady.uploadState -eq 'azureStorageUriRequestSuccess') {
                        Write-Log -Message ("Probe content request Sas Uri try {0}/{1}. Upload state is '{2}'" -f $tries, $MaxRetries, $contentReady.uploadState) -LogId $LogId
                        Write-Host ("Probe content request Uri try {0}/{1}." -f $tries, $MaxRetries) -ForegroundColor Cyan
                        Write-Host ("Sas Uri state is '{0}'" -f $contentReady.uploadState) -ForegroundColor Green
                        break
                    } else {
                        Write-Log -Message ("Probe content request Sas Uri try {0}/{1}. Upload state is '{2}'" -f $tries, $MaxRetries, $contentReady.uploadState) -LogId $LogId
                        Write-Host ("Probe content request Uri try {0}/{1}." -f $tries, $MaxRetries) -ForegroundColor Yellow
                        Write-Host ("Sas Uri state is '{0}'" -f $contentReady.uploadState) -ForegroundColor Yellow
                    }
                }
                catch {
                    Write-Log -Message ("Error during probe content request: {0}" -f $_.Exception.Message) -LogId $LogId -Severity 3
                    Write-Warning -Message ("Error during probe content request: {0}" -f $_.Exception.Message)
                }
                Start-Sleep -Seconds 3
            } until ($contentReady.uploadState -eq 'azureStorageUriRequestSuccess' -or [int]((Get-Date) - $startTime).TotalSeconds -gt $MaxWaitTime -or $tries -ge $MaxRetries)

            # Output the SAS Uri information to the console and log
            $contentReadyOutput = @{}
            $contentReadyOutputJson = @()
            foreach ($property in $contentReady.GetEnumerator() | Sort-Object -Property Key) {
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
                Write-Log -Message "azureStorageUri is null" -LogId $LogId -Severity 3
                Write-Warning -Message "azureStorageUri is null"
            }
        }
        catch {
            Write-Log -Message ("Failed to get Sas Uri: {0}" -f $_) -LogId $LogId -Severity 3
            Write-Error -Message $_
        }
    }
}