<#
.Synopsis
Created on:   09/06/2024
Updated on:   16/11/2026
Created by:   Ben Whitmore
Filename:     Get-SasUri.ps1

.Description
Function to get a SAS URI for uploading content to Azure Blob storage. Creates a content version and a content file, then waits for Intune to provide the azureStorageUri.
Throws when the SAS URI cannot be obtained. The SAS token is never logged; only scheme, host and path are written.

.PARAMETER Win32AppId
The ID of the Win32 app to upload content for

.PARAMETER ContentRequest
The content request JSON object containing version information

.PARAMETER TimeoutSeconds
The maximum wait time in seconds until the SAS URI is available. Default is 300 seconds

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
        [Alias('MaxWaitTime')]
        [int]$TimeoutSeconds = 300,

        [Parameter(Mandatory = $false, HelpMessage = 'The component (script name) passed as LogID to the Write-Log function')]
        [string]$LogId = $($MyInvocation.MyCommand).Name
    )

    begin {
        Write-LogAndHost -Message "Function: Get-SasUri was called" -LogId $LogId -ForegroundColor Cyan
    }

    process {

        try {

            # Create new content version for Win32app
            Write-LogAndHost -Message "Creating request for content version" -LogId $LogId -ForegroundColor Cyan
            $contentVersionRequest = Invoke-MgGraphRequestCustom -Method POST -Resource ("deviceAppManagement/mobileApps/{0}/microsoft.graph.win32LobApp/contentVersions" -f $Win32AppId) -Body "{}"

            if (-not $contentVersionRequest -or -not $contentVersionRequest.id) {
                throw "Graph did not return a content version id"
            }

            Write-LogAndHost -Message ("Content Version to use is '{0}'. " -f $contentVersionRequest.id) -LogId $LogId -ForegroundColor Green

            # Create the content request
            Write-LogAndHost -Message ("Creating content file entry for '{0}'. JSON Body: {1}" -f $Win32AppId, $ContentRequest) -LogId $LogId -ForegroundColor Cyan
            $buildContentRequestUri = "deviceAppManagement/mobileApps/{0}/microsoft.graph.win32LobApp/contentVersions/{1}/files" -f $Win32AppId, $contentVersionRequest.id
            $contentFileRequest = Invoke-MgGraphRequestCustom -Method POST -Resource $buildContentRequestUri -Body $ContentRequest

            if (-not $contentFileRequest -or -not $contentFileRequest.id) {
                throw "Graph did not return a content file id"
            }

            # Wait for the content landing zone to be ready
            $contentReady = Wait-IntuneContentFileState -Win32AppId $Win32AppId -ContentVersion $contentVersionRequest.id -ContentFileId $contentFileRequest.id -Stage azureStorageUriRequest -TimeoutSeconds $TimeoutSeconds -PollSeconds 3 -LogId $LogId

            if (-not $contentReady.azureStorageUri) {
                throw "azureStorageUri is empty although uploadState is azureStorageUriRequestSuccess"
            }

            # Log the SAS Uri without the query string (SAS token)
            Write-LogAndHost -Message ("Azure Storage Uri (redacted): {0}" -f (Get-RedactedUri -Uri $contentReady.azureStorageUri)) -LogId $LogId -ForegroundColor Green
            Write-LogAndHost -Message ("Azure Storage Uri expires: {0}" -f $contentReady.azureStorageUriExpirationDateTime) -LogId $LogId -ForegroundColor Green

            return @{
                contentReady     = $contentReady
                contentVersion   = $contentVersionRequest.id
                contentRequestId = $contentFileRequest.id
            }
        }
        catch {
            Write-LogAndHost -Message ("Failed to get Sas Uri: {0}" -f $_.Exception.Message) -LogId $LogId -Severity 3

            throw
        }
    }
}
