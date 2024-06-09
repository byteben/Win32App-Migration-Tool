<#
.Synopsis
Created on:   09/06/2024
Updated on:   09/06/2024
Created by:   Ben Whitmore
Filename:     Get-IntuneWinInfo.ps1

.Description
Function to get metadata from a .intunewin file

.PARAMETER LogId
The component (script name) passed as LogID to the 'Write-Log' function. 
This parameter is built from the line number of the call from the function up the pipeline

.PARAMETER SetupFile
The .intunewin file to get metadata from

#>
function Get-IntuneWinInfo {
    param(
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = 'The component (script name) passed as LogID to the Write-Log function')]
        [string]$LogId = $($MyInvocation.MyCommand).Name,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 1, HelpMessage = 'The setup file to be used for packaging. Normally the .msi, .exe or .ps1 file used to install the application')]
        [string]$SetupFile
    )
    begin {

        Write-Log -Message "Function: Get-IntuneWinInfo was called" -Log "Main.log"

        try {

            # Explicitly load the System.IO.Compression.FileSystem assembly if the PS version is 5 or lower
            if ($PSVersionTable.PSVersion.Major -lt 6) {
                Add-Type -AssemblyName 'System.IO.Compression.FileSystem' -ErrorAction Stop
            }
        }
        catch {

            Write-Log -Message "Failed to load System.IO.Compression.FileSystem" -LogId $LogId -Severity 3
            throw $_.Exception
            break
        }
    }
    process {

        $intuneWinInfoArray = [ordered]@{}
        $compressedContent = [System.IO.Compression.ZipFile]::OpenRead($SetupFile)

        # Find the entry for Detection.xml in the MetaData folder
        $xmlEntry = $compressedContent.Entries | Where-Object { $_.FullName -match "MetaData/Detection.xml" }

        if (-not [string]::IsNullOrEmpty($xmlEntry)) {

            # Open the XML entry and read its content
            $stream = $xmlEntry.Open()
            $reader = New-Object System.IO.StreamReader($stream)
            $xmlContent = [xml]$reader.ReadToEnd()
            $reader.Close()
            $stream.Close()
        }
        else {

            throw "Detection.xml not found in the MetaData folder."
            break
        }

        # Add the required metadata to the array
        $intuneWinInfoArray['FileName'] = $xmlContent.ApplicationInfo.FileName
        $intuneWinInfoArray['SetupFile'] = $xmlContent.ApplicationInfo.SetupFile
        $intuneWinInfoArray['UnencryptedContentSize'] = $xmlContent.ApplicationInfo.UnencryptedContentSize

        # Close the compressed content
        $compressedContent.Dispose()

        return $intuneWinInfoArray
    }
}