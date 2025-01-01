<#
.Synopsis
Created on:   11/11/2023
Updated on:   16/12/2023
Created by:   Ben Whitmore
Filename:     Get-IntuneWinEncryptionDetails.ps1

.Description
Function to get extract the .intunewin bin file for encryption details from the XML

.Parameter FilePath
The path to the .intunewin bin file to extract the XML from

.PARAMETER LogId
The component (script name) passed as LogID to the 'Write-Log' function. 
This parameter is built from the line number of the call from the function up the pipeline
#>

function Get-IntuneWinEncryptionInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = 'The path to the .intunewin bin file to extract the XML from')]
        [string]$FilePath
    )

    try {

        # Open the .intunewin archive
        $binFile = [System.IO.Compression.ZipFile]::OpenRead($FilePath)

        # Locate the IntunePackage.intunewin file inside the archive
        $intunePackageEntry = $binFile.Entries | Where-Object { $_.Name -eq "IntunePackage.intunewin" }

        if ($intunePackageEntry) {

            # Create a "temp" folder in the $FilePath directory
            $tempDir = Join-Path -Path (Split-Path -Path $FilePath) -ChildPath "extracted"

            if (-not (Test-Path -Path $tempDir)) {
                New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
            }

            # Extract IntunePackage.intunewin to the "temp" folder
            $tempPath = Join-Path -Path $tempDir -ChildPath "IntunePackage.intunewin"
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($intunePackageEntry, $tempPath, $true)

            Write-Log -Message ("Successfully extracted encrypted IntunePackage.intunewin to '{0}'" -f $tempPath) -LogId $LogId
            Write-Host ("Successfully extracted encrypted IntunePackage.intunewin to '{0}'" -f $tempPath) -ForegroundColor Green
        }
        else {
            Write-Log -Message ("IntunePackage.intunewin not found in the .intunewin archive at '{0}'" -f $FilePath) -LogId $LogId
            Write-Warning ("IntunePackage.intunewin not found in the .intunewin archive at '{0}'" -f $FilePath)
            break
        }

        # Locate the metadata.xml file inside the archive
        $xml = $binFile.Entries | Where-Object { $_.Name -like "Detection.xml" }

        if ([string]::IsNullOrEmpty($xml) -eq $false) {

            # Open the metadata.xml file
            $laserBeams = $xml.Open()

            # Read the XML content
            $beamReader = New-Object -TypeName "System.IO.StreamReader" -ArgumentList $laserBeams
            $xmlMeta = [xml]($beamReader.ReadToEnd())

            # Extract application information
            $contentApplicationInfo = [ordered]@{
                name                   = $xmlMeta.ApplicationInfo.Name
                unencryptedContentSize = $xmlMeta.ApplicationInfo.UnencryptedContentSize
                fileName               = $xmlMeta.ApplicationInfo.FileName
                setupFile              = $xmlMeta.ApplicationInfo.SetupFile
            }

            # Extract encryption details
            $contentEncryptionData = [ordered]@{
                encryptionKey        = $xmlMeta.ApplicationInfo.EncryptionInfo.EncryptionKey
                macKey               = $xmlMeta.ApplicationInfo.EncryptionInfo.MacKey
                initializationVector = $xmlMeta.ApplicationInfo.EncryptionInfo.InitializationVector
                mac                  = $xmlMeta.ApplicationInfo.EncryptionInfo.Mac
                profileIdentifier    = $xmlMeta.ApplicationInfo.EncryptionInfo.ProfileIdentifier
                fileDigest           = $xmlMeta.ApplicationInfo.EncryptionInfo.FileDigest
                fileDigestAlgorithm  = $xmlMeta.ApplicationInfo.EncryptionInfo.FileDigestAlgorithm
            }

            # Close and dispose objects to preserve memory
            $laserBeams.Close()
            $beamReader.Close()
        }
        else {
            Write-Log -Message "metadata.xml not found in the .intunewin archive." -LogId $LogId
            Write-Warning "metadata.xml not found in the .intunewin archive."
        }

        # Dispose of the archive
        $binFile.Dispose()
    }
    catch {
        Write-Log -Message ("Error extracting metadata from the .intunewin file: {0}" -f $_.Exception.Message) -LogId $LogId
        Write-Error ("Error extracting metadata from the .intunewin file: {0}" -f $_.Exception.Message)
        break
    }

    # Return the intunewin encryption details
    if (-not [string]::IsNullOrEmpty($contentEncryptionData)) {

        Write-Log -Message ("Application info details: {0}" -f ($contentApplicationInfo | ConvertTo-Json -Compress)) -LogId $LogId
        Write-Log -Message ("Encryption details: {0}" -f ($contentEncryptionData | ConvertTo-Json -Compress)) -LogId $LogId
        Write-Host ("Application info details: {0}" -f ($contentApplicationInfo | ConvertTo-Json -Compress)) -ForegroundColor Green
        Write-Host ("Encryption details: {0}" -f ($contentEncryptionData | ConvertTo-Json -Compress)) -ForegroundColor Green

        return @{
            encryptionDetails      = ($contentEncryptionData | ConvertTo-Json -Compress)
            contentApplicationInfo = ($contentApplicationInfo | ConvertTo-Json -Compress)
            intuneWinPath          = $tempPath
        }
    }
}