<#
.Synopsis
Created on:   28/10/2023
Updated on:   16/11/2026
Created by:   Ben Whitmore
Filename:     Get-FileFromInternet.ps1

.Description
Function to download a file from the internet. The file is downloaded once to a temporary file. On Windows the
Authenticode signature is verified (valid and signed by Microsoft Corporation) unless -SkipSignatureCheck is used.
The verified file is then moved over the destination. Throws on failure.

.PARAMETER LogID
The component (script name) passed as LogID to the 'Write-Log' function. 
This parameter is built from the line number of the call from the function up the pipeline

.PARAMETER Uri
The URI of the file to download

.PARAMETER Destination
The destination file path to download the file to

.PARAMETER SkipSignatureCheck
Do not verify the Authenticode signature of the downloaded file
#>
function Get-FileFromInternet {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = "The component (script name) passed as LogID to the 'Write-Log' function")]
        [string]$LogId = $($MyInvocation.MyCommand).Name,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 0, HelpMessage = 'The URI of the file to download')]
        [String]$Uri,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 1, HelpMessage = 'The destination file path to download the file to')]
        [String]$Destination,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, HelpMessage = 'Do not verify the Authenticode signature of the downloaded file')]
        [Switch]$SkipSignatureCheck
    )

    begin {
        Write-LogAndHost -Message 'Function: Get-FileFromInternet was called' -LogId $LogId -ForegroundColor Cyan
        Write-LogAndHost -Message ("Attempting to download the file from '{0}'" -f $Uri) -LogId $LogId -ForegroundColor Cyan
        Write-LogAndHost -Message ("File destination will be '{0}'" -f $Destination) -LogId $LogId -ForegroundColor Cyan
    }

    process {
        $tempFile = "$Destination.download"

        try {
            try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { Write-Verbose $_.Exception.Message }
            Invoke-WebRequest -UseBasicParsing -Uri $Uri -OutFile $tempFile -ErrorAction Stop
        }
        catch {
            if (Test-Path -LiteralPath $tempFile) { Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue }
            $message = "Error downloading file '{0}': {1}" -f $Uri, $_.Exception.Message
            Write-LogAndHost -Message $message -LogId $LogId -Severity 3
            throw $message
        }

        if (-not (Test-Path -LiteralPath $tempFile)) {
            $message = "The download of '{0}' did not produce a file" -f $Uri
            Write-LogAndHost -Message $message -LogId $LogId -Severity 3
            throw $message
        }

        $onWindows = ($PSVersionTable.PSVersion.Major -le 5) -or ((Get-Variable -Name IsWindows -ValueOnly -ErrorAction SilentlyContinue) -eq $true)
        if ($onWindows -and -not $SkipSignatureCheck) {
            $signature = Get-AuthenticodeSignature -FilePath $tempFile
            if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'O=Microsoft Corporation') {
                Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
                $message = "The signature of the file downloaded from '{0}' is not a valid Microsoft Corporation signature (Status '{1}'). The file was deleted" -f $Uri, $signature.Status
                Write-LogAndHost -Message $message -LogId $LogId -Severity 3
                throw $message
            }
            Write-LogAndHost -Message 'The Authenticode signature is valid and signed by Microsoft Corporation' -LogId $LogId -ForegroundColor Green
        }

        try {
            Move-Item -LiteralPath $tempFile -Destination $Destination -Force -ErrorAction Stop
        }
        catch {
            $message = "Could not move the downloaded file to '{0}': {1}" -f $Destination, $_.Exception.Message
            Write-LogAndHost -Message $message -LogId $LogId -Severity 3
            throw $message
        }
        Write-LogAndHost -Message ("File download successful. File saved to '{0}'" -f $Destination) -LogId $LogId -ForegroundColor Green
    }
}
