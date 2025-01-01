<#
.SYNOPSIS
Uploads content to Azure Blob Storage using Az.Storage module

.DESCRIPTION
Uses Az.Storage module to upload content to Azure Blob Storage with retry logic and progress tracking

.PARAMETER Uri
The Azure Storage SAS URI for upload

.PARAMETER FilePath
Path to the file to upload

.PARAMETER FileSize
The size of the encrypted file

.PARAMETER ContentVersion
The content version ID

.PARAMETER ContentRequestId

.PARAMETER ContentRequest
The content request object

.PARAMETER Win32AppId
The ID of the Win32 app

.PARAMETER RetryCount
Number of retry attempts (default: 3)

.PARAMETER RetryDelay
Seconds between retries (default: 5)

.PARAMETER LogId
Component name for logging
#>
function Invoke-StorageUpload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = 'The Azure Storage SAS URI for upload')]
        [string]$Uri,

        [Parameter(Mandatory = $true, Position = 1, HelpMessage = 'Path to the file to upload')]
        [string]$FilePath,

        [Parameter(Mandatory = $true, Position = 2, HelpMessage = 'The size of the encrypted file')]
        [string]$FileSize,

        [Parameter(Mandatory = $true, Position = 3, HelpMessage = 'The content version ID')]
        [string]$ContentVersion,

        [Parameter(Mandatory = $true, Position = 4, HelpMessage = 'The ID of the content request')]
        [string]$ContentRequestId,

        [Parameter(Mandatory = $true, Position = 5, HelpMessage = 'The ID of the content request')]
        [object]$ContentRequest,

        [Parameter(Mandatory = $true, Position = 6, HelpMessage = 'The ID of the Win32 app')]
        [string]$Win32AppId,

        [Parameter(Mandatory = $false, Position = 7, HelpMessage = 'Number of retry attempts (default: 10)')]
        [int]$RetryCount = 10,

        [Parameter(Mandatory = $false, Position = 8, HelpMessage = 'Seconds between retries (default: 5)')]
        [int]$RetryDelay = 5,

        [Parameter(Mandatory = $false, HelpMessage = 'Component name for logging')]
        [string]$LogId = $($MyInvocation.MyCommand).Name
    )

    begin {
        # Check for required module
        Initialize-Module -Modules @('Az.Storage')

        try {

            $sasUri = [System.Uri]::new($Uri)
            
            # Get container (second segment)
            $container = $sasUri.AbsolutePath.Split('/')[1]

            # Get full blob path (all segments after container)
            $blobPath = $sasUri.AbsolutePath.Substring($container.Length + 2)

            # Get SAS token
            $sasToken = $sasUri.Query.TrimStart('?')

            # LLog the results
            $uploadInfo = [PSCustomObject]@{
                Container = $container
                BlobPath  = $blobPath
                SasToken  = $sasToken
            }

            Write-Log -Message ($uploadInfo | ConvertTo-Json -Compress) -LogId $LogId
            Write-Host ($uploadInfo | ConvertTo-Json -Compress) -ForegroundColor Green
        }
        catch {
            Write-Log -Message ("Error parsing Sas Uri: {0}" -f $_.Exception.Message) -LogId $LogId -Severity 3
            Write-Warning -Message ("Error parsing Sas Uri: {0}" -f $_.Exception.Message)
            throw
        }
    }

    process {

        try {

            # Upload content file information to Win32 app
            Write-Log -Message ("Adding Content information to '{0}'" -f $Win32AppId) -LogId $LogId
            Write-Host ("Adding Content information to '{0}'" -f $Win32AppId) -ForegroundColor Cyan
                        
            Write-Log -Message ("Starting upload of '{0}' to Azure Storage using Set-AzStorageBlobContent" -f $FilePath) -LogId $LogId
            Write-Host ("Starting upload of '{0}' to Azure Storage using Set-AzStorageBlobContent" -f $FilePath) -ForegroundColor Cyan

            $attempt = 1
            $success = $false

            # Initialize block size (e.g., 4 MB)
            $blockSize = 4 * 1024 * 1024

            $fileSize = (Get-Item $FilePath).Length
            $blocks = [Math]::Ceiling($fileSize / $blockSize)

            do {
                try {
                    # Create a context for the storage account
                    $context = New-AzStorageContext -SasToken $sasToken -StorageAccountName $sasUri.Host.Split('.')[0]
                    $blobClient = [Microsoft.Azure.Storage.Blob.CloudBlockBlob]::new($sasUri)

                    # Initialize upload parameters
                    $fileStream = [System.IO.File]::OpenRead($FilePath)
                    $buffer = New-Object Byte[] $blockSize
                    $blockIds = New-Object 'System.Collections.Generic.List[System.String]'

                    Write-Log -Message ("Uploading file in chunks of {0} bytes" -f $blockSize) -LogId $LogId
                    Write-Host ("Uploading file in chunks of {0} bytes" -f $blockSize) -ForegroundColor Cyan

                    try {
                        $i = 0
                        while (($bytesRead = $fileStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                            $blockId = [Guid]::NewGuid().ToString()
                            $encodedBlockId = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($blockId))
                            $blockIds.Add($encodedBlockId)

                            # Create a memory stream for the current chunk
                            $memoryStream = New-Object System.IO.MemoryStream
                            $memoryStream.Write($buffer, 0, $bytesRead)
                            $memoryStream.Position = 0

                            # Upload the chunk
                            $blobClient.PutBlock($encodedBlockId, $memoryStream, $null)

                            # Dispose of the memory stream
                            $memoryStream.Dispose()
                            $i++
                            Write-Log -Message ("Uploading block {0} of {1}" -f $i, $blocks) -LogId $LogId
                            Write-Host ("Uploading block {0} of {1}" -f $i, $blocks) -ForegroundColor Cyan
                        }

                        # Commit the blocks
                        $blobClient.PutBlockList($blockIds)
                        Write-Log -Message "Upload reported as completed successfully" -LogId $LogId
                        Write-Host "Upload reported as completed successfully" -ForegroundColor Green
                        $success = $true
                    }
                    finally {
                        $fileStream.Dispose()
                    }
                }
                catch {
                    if ($attempt -ge $RetryCount) {
                        Write-Log -Message ("Upload failed after {0} attempts: {1}" -f $RetryCount, $_.Exception.Message) -LogId $LogId -Severity 3
                        Write-Warning ("Upload failed after {0} attempts: {1}" -f $RetryCount, $_.Exception.Message)
                        throw
                    }

                    Write-Log -Message ("Attempt {0}/{1} failed. Retrying... Error: {2}" -f $attempt, $RetryCount, $_.Exception.Message) -LogId $LogId -Severity 2
                    Write-Warning -Message ("Attempt {0}/{1} failed. Retrying... Error: {2}" -f $attempt, $RetryCount, $_.Exception.Message)
                    Start-Sleep -Seconds $RetryDelay
                }
                $attempt++
            } while (-not $success -and $attempt -le $RetryCount)
            
            # Verify upload success
            Write-Log -Message "Verifying upload success..." -LogId $LogId
            Write-Host "Verifying upload success..." -ForegroundColor Cyan
            
            # Delay to allow Azure to update blob properties
            Start-Sleep -Seconds $RetryDelay
            
            # Verify upload success
            $blob = Get-AzStorageBlob -Context $context -Container $container -Blob $blobPath

            if ($blob) {
                $blobInfo = [PSCustomObject]@{
                    Name         = $blob.Name
                    BlobType     = $blob.BlobType
                    Length       = $blob.Length
                    Uri          = $blob.ICloudBlob.Uri.AbsoluteUri
                    LastModified = $blob.ICloudBlob.Properties.LastModified
                    ContentType  = $blob.ICloudBlob.Properties.ContentType
                }
                $json = $blobInfo | ConvertTo-Json -Compress
                Write-Log -Message ("Blob info: {0}" -f $json) -LogId $LogId
                Write-Host ("Blob info: {0}" -f $json) -ForegroundColor Green
            }
            else {
                Write-Warning -Message "Blob not found in the specified container and path."
            }

            $attempt = 1
            $success = $false

            do {
                try {

                    # Get blob size and compare
                    if ($blob) {
                        $blob.ICloudBlob.FetchAttributes()
                        $FileSize = (Get-Item $FilePath).Length
                        $blobSize = $blob.ICloudBlob.Properties.Length
            
                        Write-Log -Message ("Comparing file size: Local file size is {0} bytes, Blob file size is {1} bytes" -f $FileSize, $blobSize) -LogId $LogId
                        Write-Host ("Comparing file size: Local file size is {0} bytes, Blob file size is {1} bytes" -f $FileSize, $blobSize) -ForegroundColor Cyan
            
                        if ($FileSize -eq $blobSize) {
                            Write-Log -Message "Upload verification successful: File sizes match" -LogId $LogId
                            Write-Host "Upload verification successful: File sizes match" -ForegroundColor Green
                            $success = $true
                        }
                        else {
                            throw "Upload verification failed: File sizes do not match"
                        }
                    }
                    else {
                        throw "Upload verification failed: Blob not found"
                    } 
                }
                catch {
                    if ($attempt -ge $RetryCount) {
                        Write-Log -Message ("Upload verification failed after {0} attempts: {1}" -f $RetryCount, $_.Exception.Message) -LogId $LogId -Severity 3
                        throw
                    }
            
                    Write-Log -Message ("Attempt {0}/{1} failed. Retrying..." -f $attempt, $RetryCount) -LogId $LogId -Severity 2
                    Write-Warnging -Message ("Attempt {0}/{1} failed. Retrying..." -f $attempt, $RetryCount)
                    Start-Sleep -Seconds $RetryDelay
                    $attempt++
                }
            } while (-not $success -and $attempt -le $RetryCount)
        }
        catch {
            Write-Log -Message ("Upload failed: {0}" -f $_.Exception.Message) -LogId $LogId -Severity 3
            Write-Warning -Message ("Upload failed: {0}" -f $_.Exception.Message)
            throw
        }

        if ($success -eq $true) {

            # Verify upload state
            Write-Log -Message "Verifying upload state..." -LogId $LogId
            Write-Host "Verifying upload state..." -ForegroundColor Cyan

            $attempt = 1
            $success = $false

            do {
                try {
                    # Construct the status URI
                    $statusUri = "deviceAppManagement/mobileApps/{0}/microsoft.graph.win32LobApp/contentVersions/{1}/files/{2}" -f $Win32AppId, $ContentVersion, $ContentRequestId

                    # Make the GET request to check upload state
                    $statusResponse = Invoke-MgGraphRequestCustom -Method GET -Resource $statusUri

                    # Check if the upload state is acceptable
                    if (($statusResponse.uploadState) -eq "azureStorageUriRequestSuccess" ) {
                        Write-Log -Message ("Upload state is '{0}'." -f ($statusResponse.uploadState)) -LogId $LogId
                        Write-Host ("Upload state is '{0}'." -f ($statusResponse.uploadState)) -ForegroundColor Green
                        $success = $true
                    }
                    else {
                        Write-Log -Message ("Upload state is '{0}'. Waiting..." -f ($statusResponse.uploadState)) -LogId $LogId
                        Write-Warning -Message ("Upload state is '{0}'. Waiting..." -f ($statusResponse.uploadState))
                        Start-Sleep -Seconds $RetryDelay
                    }
                }
                catch {

                    # Log error and decide whether to retry
                    Write-Log -Message ("Attempt {0}/{1} failed. Error: {2}" -f $attempt, $RetryCount, $_.Exception.Message) -LogId $LogId -Severity 3
                    Write-Warning ("Attempt {0}/{1} failed. Retrying in {2} seconds." -f $attempt, $RetryCount, $RetryDelay)
                    Start-Sleep -Seconds $RetryDelay
                }

                # Increment attempt counter only after each iteration
                $attempt++

            } while (-not $success -and $attempt -le $RetryCount)

            if ($success -eq $true) {
                Write-Log -Message "Upload completed successfully" -LogId $LogId
                Write-Host "Upload completed successfully" -ForegroundColor Green
                return $true
            }
            else {
                Write-Log -Message "Upload verification failed" -LogId $LogId -Severity 3
                Write-Warning "Upload verification failed"
            }
        }
    }
}