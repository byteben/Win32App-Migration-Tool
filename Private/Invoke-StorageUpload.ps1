<#
.Synopsis
Uploads content to Azure Blob Storage using the Azure Blob REST API (Put Block / Put Block List)

Created on:   28/12/2024
Updated on:   16/11/2026
Created by:   Ben Whitmore
Filename:     Invoke-StorageUpload.ps1

.Description
Uploads the encrypted .intunewin content to the Azure Storage SAS URI issued by Intune, in blocks, using System.Net.Http.HttpClient.
No Az.Storage module is required. Each block is retried individually (exponential backoff), the SAS URI is renewed through the
Graph renewUpload action before it expires, and the block list is committed at the end. The SAS token is never logged.
Throws on failure.

.PARAMETER Win32AppId
The ID of the Win32 app

.PARAMETER ContentVersion
The content version ID

.PARAMETER ContentFileId
The ID of the content file

.PARAMETER SasUri
The Azure Storage SAS URI (azureStorageUri) for upload

.PARAMETER FilePath
Path to the file to upload

.PARAMETER BlockSizeBytes
The size of each block in bytes. Default is 6MB

.PARAMETER MaxBlockRetries
The maximum number of attempts for each block (and the block list). Default is 8, which waits about three minutes in total before giving up

.PARAMETER SasRenewalSeconds
Renew the SAS URI when it is older than this many seconds. Default is 420

.PARAMETER LogId
Component name for logging
#>
function Invoke-StorageUpload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, HelpMessage = 'The ID of the Win32 app')]
        [string]$Win32AppId,

        [Parameter(Mandatory = $true, HelpMessage = 'The content version ID')]
        [string]$ContentVersion,

        [Parameter(Mandatory = $true, HelpMessage = 'The ID of the content file')]
        [string]$ContentFileId,

        [Parameter(Mandatory = $true, HelpMessage = 'The Azure Storage SAS URI for upload')]
        [string]$SasUri,

        [Parameter(Mandatory = $true, HelpMessage = 'Path to the file to upload')]
        [string]$FilePath,

        [Parameter(Mandatory = $false, HelpMessage = 'The size of each block in bytes')]
        [int]$BlockSizeBytes = (6 * 1024 * 1024),

        [Parameter(Mandatory = $false, HelpMessage = 'The maximum number of attempts for each block')]
        [int]$MaxBlockRetries = 8,

        [Parameter(Mandatory = $false, HelpMessage = 'Renew the SAS URI when it is older than this many seconds')]
        [int]$SasRenewalSeconds = 420,

        [Parameter(Mandatory = $false, HelpMessage = 'Component name for logging')]
        [string]$LogId = $($MyInvocation.MyCommand).Name
    )

    begin {
        Write-LogAndHost -Message "Function: Invoke-StorageUpload was called" -LogId $LogId -ForegroundColor Cyan

        # System.Net.Http is not loaded by default in Windows PowerShell 5.1
        # Windows PowerShell 5.1 (.NET Framework) may not offer TLS 1.2 by default. Azure Storage requires it
        try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { Write-Verbose $_.Exception.Message }
        try { Add-Type -AssemblyName System.Net.Http -ErrorAction Stop } catch { Write-Verbose "System.Net.Http assembly: $($_.Exception.Message)" }
    }

    process {

        if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) {
            throw ("File to upload was not found: '{0}'" -f $FilePath)
        }
        if ($BlockSizeBytes -lt 1) {
            throw "BlockSizeBytes must be greater than zero"
        }

        $fileSize = (Get-Item -LiteralPath $FilePath).Length
        if ($fileSize -lt 1) {
            throw ("File to upload is empty: '{0}'" -f $FilePath)
        }
        $blockCount = [int][Math]::Ceiling($fileSize / $BlockSizeBytes)
        if ($blockCount -gt 50000) {
            throw ("File needs {0} blocks with a block size of {1} bytes which exceeds the 50,000 block limit. Increase BlockSizeBytes" -f $blockCount, $BlockSizeBytes)
        }

        $fileResource = "deviceAppManagement/mobileApps/{0}/microsoft.graph.win32LobApp/contentVersions/{1}/files/{2}" -f $Win32AppId, $ContentVersion, $ContentFileId

        # Mutable state shared with the helper functions
        $state = @{
            SasUri    = $SasUri
            Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        }
        $renewal = @{
            FileResource = $fileResource
            Win32AppId   = $Win32AppId
            ContentVersion = $ContentVersion
            ContentFileId = $ContentFileId
            LogId        = $LogId
        }

        $fileStream = $null
        $client = $null

        try {
            Write-LogAndHost -Message ("Starting upload of '{0}' ({1} bytes) to '{2}' in {3} block(s) of up to {4} bytes" -f $FilePath, $fileSize, (Get-RedactedUri -Uri $SasUri), $blockCount, $BlockSizeBytes) -LogId $LogId -ForegroundColor Cyan

            $client = New-Object -TypeName 'System.Net.Http.HttpClient'
            $client.Timeout = [TimeSpan]::FromMinutes(10)

            $fileStream = [System.IO.File]::OpenRead($FilePath)
            $buffer = New-Object byte[] $BlockSizeBytes
            $blockIds = New-Object 'System.Collections.Generic.List[string]'

            for ($index = 0; $index -lt $blockCount; $index++) {

                # Renew the SAS URI if it is getting old
                if ($state.Stopwatch.Elapsed.TotalSeconds -ge $SasRenewalSeconds) {
                    Update-StorageSasUri -State $state -Renewal $renewal
                }

                # Fill the buffer (FileStream.Read can return fewer bytes than requested)
                $bytesInBlock = 0
                while ($bytesInBlock -lt $BlockSizeBytes) {
                    $read = $fileStream.Read($buffer, $bytesInBlock, $BlockSizeBytes - $bytesInBlock)
                    if ($read -le 0) { break }
                    $bytesInBlock += $read
                }
                if ($bytesInBlock -lt 1) {
                    throw ("Unexpected end of file while reading block {0} of {1}" -f ($index + 1), $blockCount)
                }

                $blockId = Get-BlockId -Index $index
                $blockIds.Add($blockId)

                Invoke-BlobPut -Client $client -State $state -Renewal $renewal -Query ("comp=block&blockid={0}" -f [Uri]::EscapeDataString($blockId)) -Buffer $buffer -Count $bytesInBlock -MaxAttempts $MaxBlockRetries -Description ("block {0} of {1}" -f ($index + 1), $blockCount) -LogId $LogId

                $percent = [int]((($index + 1) / $blockCount) * 100)
                Write-Progress -Id 1 -Activity "Uploading file to Azure Storage" -Status ("Uploaded block {0} of {1}" -f ($index + 1), $blockCount) -PercentComplete $percent
                Write-LogAndHost -Message ("Uploaded block {0} of {1}" -f ($index + 1), $blockCount) -LogId $LogId -ForegroundColor Cyan
            }

            # Commit the block list
            $xml = New-Object System.Text.StringBuilder
            $null = $xml.Append('<?xml version="1.0" encoding="utf-8"?><BlockList>')
            foreach ($id in $blockIds) {
                $null = $xml.Append("<Latest>$id</Latest>")
            }
            $null = $xml.Append('</BlockList>')
            $xmlBytes = [System.Text.Encoding]::UTF8.GetBytes($xml.ToString())

            if ($state.Stopwatch.Elapsed.TotalSeconds -ge $SasRenewalSeconds) {
                Update-StorageSasUri -State $state -Renewal $renewal
            }

            Invoke-BlobPut -Client $client -State $state -Renewal $renewal -Query 'comp=blocklist' -Buffer $xmlBytes -Count $xmlBytes.Length -ContentType 'application/xml' -MaxAttempts $MaxBlockRetries -Description 'block list' -LogId $LogId

            Write-LogAndHost -Message ("Upload of {0} block(s) completed successfully" -f $blockCount) -LogId $LogId -ForegroundColor Green

            return $true
        }
        catch {
            Write-LogAndHost -Message ("Upload failed: {0}" -f $_.Exception.Message) -LogId $LogId -Severity 3

            throw
        }
        finally {
            Write-Progress -Id 1 -Activity "Uploading file to Azure Storage" -Completed
            if ($fileStream) { $fileStream.Dispose() }
            if ($client) { $client.Dispose() }
        }
    }
}

# Returns the URI without its query string (scheme, host and path only) so a SAS token is never logged
function Get-RedactedUri {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri
    )

    try {
        return ([System.Uri]$Uri).GetLeftPart([System.UriPartial]::Path)
    }
    catch {
        $queryStart = $Uri.IndexOf('?')
        if ($queryStart -ge 0) { return $Uri.Substring(0, $queryStart) }

        return $Uri
    }
}

# Block ids must be Base64 and all the same length for a blob. Base64 of the ASCII index formatted as D6
function Get-BlockId {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$Index
    )

    return [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($Index.ToString('D6')))
}

# Sends a single PUT to Azure Blob Storage and returns the HTTP status code and any Retry-After. Network failures throw
function Send-BlobRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Client,

        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [Parameter(Mandatory = $true)]
        [byte[]]$Buffer,

        [Parameter(Mandatory = $true)]
        [int]$Count,

        [Parameter(Mandatory = $false)]
        [string]$ContentType,

        [Parameter(Mandatory = $false)]
        [switch]$BlockBlob
    )

    $request = $null
    $response = $null
    try {
        $content = New-Object -TypeName 'System.Net.Http.ByteArrayContent' -ArgumentList $Buffer, 0, $Count
        if ($ContentType) {
            $content.Headers.ContentType = New-Object -TypeName 'System.Net.Http.Headers.MediaTypeHeaderValue' -ArgumentList $ContentType
        }

        $request = New-Object -TypeName 'System.Net.Http.HttpRequestMessage' -ArgumentList (New-Object -TypeName 'System.Net.Http.HttpMethod' -ArgumentList 'PUT'), $Uri
        $request.Content = $content
        if ($BlockBlob) {
            $null = $request.Headers.TryAddWithoutValidation('x-ms-blob-type', 'BlockBlob')
        }

        $response = $Client.SendAsync($request).GetAwaiter().GetResult()

        # Retry-After can be a number of seconds or a date
        $retryAfterSeconds = $null
        $retryAfter = $response.Headers.RetryAfter
        if ($null -ne $retryAfter) {
            if ($null -ne $retryAfter.Delta) { $retryAfterSeconds = $retryAfter.Delta.TotalSeconds }
            elseif ($null -ne $retryAfter.Date) { $retryAfterSeconds = ($retryAfter.Date.UtcDateTime - [DateTime]::UtcNow).TotalSeconds }
        }

        return [pscustomobject]@{ StatusCode = [int]$response.StatusCode; RetryAfterSeconds = $retryAfterSeconds }
    }
    finally {
        if ($response) { $response.Dispose() }
        if ($request) { $request.Dispose() }
    }
}

# PUT with retry. Retries network errors and 408/429/500/502/503/504 with exponential backoff and jitter, honouring
# Retry-After, and renews the SAS once on 403. Re-sending a block with the same block id replaces it, so retries are safe
function Invoke-BlobPut {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Client,

        [Parameter(Mandatory = $true)]
        [hashtable]$State,

        [Parameter(Mandatory = $true)]
        [hashtable]$Renewal,

        [Parameter(Mandatory = $true)]
        [string]$Query,

        [Parameter(Mandatory = $true)]
        [byte[]]$Buffer,

        [Parameter(Mandatory = $true)]
        [int]$Count,

        [Parameter(Mandatory = $false)]
        [string]$ContentType,

        [Parameter(Mandatory = $true)]
        [int]$MaxAttempts,

        [Parameter(Mandatory = $true)]
        [string]$Description,

        [Parameter(Mandatory = $false)]
        [string]$LogId = $($MyInvocation.MyCommand).Name
    )

    $transientCodes = @(408, 429, 500, 502, 503, 504)
    $renewed = $false
    $attempt = 0

    while ($true) {
        $attempt++

        $separator = '&'
        if ($State.SasUri.IndexOf('?') -lt 0) { $separator = '?' }
        $uri = '{0}{1}{2}' -f $State.SasUri, $separator, $Query

        $status = $null
        $retryAfterSeconds = $null
        $errorText = $null
        try {
            $sendParams = @{ Client = $Client; Uri = $uri; Buffer = $Buffer; Count = $Count }
            if ($ContentType) { $sendParams.ContentType = $ContentType } else { $sendParams.BlockBlob = $true }
            $result = Send-BlobRequest @sendParams
            if ($result -is [int]) { $status = $result }
            else {
                $status = [int]$result.StatusCode
                $retryAfterSeconds = $result.RetryAfterSeconds
            }
        }
        catch {
            $errorText = $_.Exception.Message
        }

        if ($null -ne $status -and $status -eq 201) {
            return
        }

        $redacted = Get-RedactedUri -Uri $State.SasUri

        if ($null -ne $status -and $status -eq 403 -and -not $renewed) {
            Write-LogAndHost -Message ("HTTP 403 for {0} at '{1}'. Renewing the SAS URI and retrying" -f $Description, $redacted) -LogId $LogId -Severity 2
            $renewed = $true
            Update-StorageSasUri -State $State -Renewal $Renewal
            continue
        }

        $retryable = ($null -eq $status) -or ($transientCodes -contains $status)
        if (-not $retryable) {
            throw ("Azure Storage returned HTTP {0} for {1} at '{2}'" -f $status, $Description, $redacted)
        }

        if ($attempt -ge $MaxAttempts) {
            $reason = "HTTP $status"
            if ($null -eq $status) { $reason = $errorText }
            throw ("Azure Storage upload of {0} failed after {1} attempts at '{2}': {3}" -f $Description, $attempt, $redacted, $reason)
        }

        # Exponential backoff (2, 4, 8 ... capped at 60 seconds) plus up to 20% jitter. A Retry-After from the
        # service is used when it asks for longer, up to 5 minutes
        $delay = [int][Math]::Min(60, [Math]::Pow(2, $attempt))
        $delay += Get-Random -Minimum 0 -Maximum ([Math]::Max(1, [int]($delay * 0.2)) + 1)
        if ($null -ne $retryAfterSeconds -and $retryAfterSeconds -gt $delay) {
            $delay = [int][Math]::Min(300, [Math]::Ceiling($retryAfterSeconds))
        }
        $reason = "HTTP $status"
        if ($null -eq $status) { $reason = $errorText }
        Write-LogAndHost -Message ("Attempt {0}/{1} for {2} failed ({3}). Retrying in {4} seconds" -f $attempt, $MaxAttempts, $Description, $reason, $delay) -LogId $LogId -Severity 2
        Start-Sleep -Seconds $delay
    }
}

# Renews the SAS URI through the Graph renewUpload action and stores the new azureStorageUri in $State
function Update-StorageSasUri {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$State,

        [Parameter(Mandatory = $true)]
        [hashtable]$Renewal
    )

    $logId = $Renewal.LogId
    Write-LogAndHost -Message "Renewing the Azure Storage SAS URI" -LogId $logId -ForegroundColor Cyan

    $null = Invoke-MgGraphRequestCustom -Method POST -Resource ("{0}/renewUpload" -f $Renewal.FileResource) -Body ""
    $file = Wait-IntuneContentFileState -Win32AppId $Renewal.Win32AppId -ContentVersion $Renewal.ContentVersion -ContentFileId $Renewal.ContentFileId -Stage azureStorageUriRenewal -LogId $logId

    if (-not $file.azureStorageUri) {
        throw "SAS renewal succeeded but no azureStorageUri was returned"
    }

    $State.SasUri = [string]$file.azureStorageUri
    $State.Stopwatch.Restart()
    Write-LogAndHost -Message ("SAS URI renewed for '{0}', expires {1}" -f (Get-RedactedUri -Uri $State.SasUri), $file.azureStorageUriExpirationDateTime) -LogId $logId -ForegroundColor Green
}
