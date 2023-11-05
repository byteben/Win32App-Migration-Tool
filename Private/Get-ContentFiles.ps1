<#
.Synopsis
Created on:   04/11/2023
Created by:   Ben Whitmore
Filename:     Get-ContentFiles.ps1

.Description
Function to get content from the content source folder for the deployment type and copy it to the content destination folder

.PARAMETER LogId
The component (script name) passed as LogID to the 'Write-Log' function. 
This parameter is built from the line number of the call from the function up the

.PARAMETER Source
Source path for content to be copied from

.PARAMETER UninstallContent
Destination path for content to be copied to
#>
function Get-ContentFiles {
    param (
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = "The component (script name) passed as LogID to the 'Write-Log' function")]
        [string]$LogId = $($MyInvocation.MyCommand).Name,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 0, HelpMessage = 'Source path for content to be copied from')]
        [string]$Source,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 1, HelpMessage = 'Destination path for content to be copied to')]
        [string]$Destination
    )
    
    process {

        # Create destination folders if they don't exist
        Write-Log -Message ("Attempting to create the destination folder '{0}'" -f $Destination) -LogId $LogId
        Write-Host ("`nAttempting to create the destination folder '{0}'" -f $Destination) -ForegroundColor Cyan

        if (-not (Test-Path -Path $Destination) ) {
            try {
                New-Item -Path $Destination -ItemType Directory -Force | Out-Null
                Write-Log -Message ("Successfully created the destination folder '{0}'" -f $Destination) -LogId $LogId
                Write-Host ("Successfully created the destination folder '{0}'" -f $Destination) -ForegroundColor Green
            }
            catch {
                Write-Log -Message ("Error: Could not create the destination folder '{0}'" -f $Destination) -LogId $LogId -Severity 3
                Write-Warning -Message ("Error: Could not create the destination folder '{0}'" -f $Destination)
                throw
            }
        }
        else {
            Write-Log -Message ("The destination folder '{0}' already exists. Continuing with the copy..." -f $Destination) -LogId $LogId -Severity 2
            Write-Host ("The destination folder '{0}' already exists. Continuing with the copy..." -f $Destination) -ForegroundColor Yellow
        }

        Write-Log -Message ("Attempting to copy content from '{0}' to '{1}'" -f $Source, $Destination) -LogId $LogId
        Write-Host ("Attempting to copy content from '{0}' to '{1}'" -f $Source, $Destination) -ForegroundColor Cyan

        # Build Robocopy parameters
        $uniLog = Join-Path -Path $workingFolder_Root -ChildPath "Logs\Main.log"

        # Pad path names because Robocopy requires space at the end of the path
        $SourcePadded = "`"" + $Source + " `""
        $DestinationPadded = "`"" + $Destination + " `""

        try {
            Write-Log -Message ("Invoking robocopy.exe '{0}' '{1}' /MIR /E /Z /R:5 /W:1 /NDL /NJH /NJS /NC /NS /NP /V /TEE  /UNILOG+:'{2}'" -f $Source, $Destination, $uniLog) -LogId $LogId 
            Write-Host ("Invoking robocopy.exe '{0}' '{1}' /MIR /E /Z /R:5 /W:1 /NDL /NJH /NJS /NC /NS /NP /V /TEE  /UNILOG+:'{2}'" -f $Source, $Destination, $uniLog) -ForegroundColor Cyan
        
            $args = @(
                $SourcePadded,
                $DestinationPadded,
                '/MIR',
                '/E',
                '/Z',
                '/R:5',
                '/W:1',
                '/NDL',
                '/NJH',
                '/NJS',
                '/NC',
                '/NS',
                '/NP',
                '/V',
                '/TEE',
                "/UNILOG+:""$($uniLog)"""
            )

            # Invoke robocopy.exe
            Start-Process Robocopy.exe -ArgumentList $args -Wait -NoNewWindow -PassThru 
        }
        catch {
            Write-Log -Message ("Error: Could not transfer content from '{0}' to '{1}'" -f $Source, $Destination) -LogId $LogId -Severity 3
            Write-Warning -Message ("Error: Could not transfer content from '{0}' to '{1}'" -f $Source, $Destination)
        }

        # Compare the source and destination folders to ensure the copy was successful
        # Get the list of files from both directories
        $sourceUNC = "FileSystem::$($Source)"
        $destinationUNC = "FileSystem::$($Destination)"

        try {
            $sourceCompare = Get-ChildItem -LiteralPath $sourceUNC -Recurse
            $destinationCompare = Get-ChildItem -LiteralPath $destinationUNC -Recurse

            # Compare the file hashes
            $compareResult = Compare-Object -ReferenceObject $sourceCompare -DifferenceObject $destinationCompare

            # Display the results
            if ($compareResult) {
                # Files are different
                Write-Log -Message 'Error: the files in the destination do not match the files in the source after the copy' -LogId $LogId -Severity 3
                Write-Log -Message ("'{0}'" -f $compareResult) -LogId $LogId -Severity 3
                Write-Warning -Message ("Error: Could not transfer content from '{0}' to '{1}'" -f $Source, $Destination)
                Write-Warning -Message ("'{0}'" -f $compareResult)
            }
            else {
                # Files are the same
                Write-Log -Message 'File check pass. Copy was succesful' -LogId $LogId
                Write-Host 'File check pass. Copy was succesful' -ForegroundColor Green
            }
        }
        catch {
            Write-Log -Message 'Error: Could not compare the source and destination folders' -LogId $LogId -Severity 3
            Write-Warning -Message 'Error: Could not compare the source and destination folders'
        }
    }
}