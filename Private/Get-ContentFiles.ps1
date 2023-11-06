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

        # Sanitize UNC paths
        $sourceUNC = "FileSystem::$($sourceSanitised)"
        $destinationUNC = "FileSystem::$($destinationSanitised)"      

        try {
            # List files to copy
            Write-Log -Message 'Files to copy are:' -LogId $LogId
            Write-Host 'Files to copy are:' -ForegroundColor Cyan
            Get-ChildItem -Path $sourceUNC -Recurse -ErrorAction Stop | Select-Object -ExpandProperty FullName | foreach-object { Write-Log -Message ("'{0}'" -f $_) -LogId $LogId; Write-Host ("'{0}'" -f $_) -ForegroundColor Cyan }

            # Copy files from source to destination
            Copy-Item -Path "$sourceUNC\*" -Destination $destinationUNC -Recurse -Force -ErrorAction Stop

            # Compare the source and destination folders to ensure the copy was successful
            try {
                $sourceCompare = Get-ChildItem -Path $sourceUNC -Recurse -ErrorAction Stop
                $destinationCompare = Get-ChildItem -Path $destinationUNC -Recurse -ErrorAction Stop

                # Compare the file hashes
                $compareResult = Compare-Object -ReferenceObject $sourceCompare -DifferenceObject $destinationCompare

                try {
                    # Filter out the differences
                    $differences = $compareResult | Where-Object { $_.SideIndicator -eq '<=' -or $_.SideIndicator -eq '=>' }

                    if ($differences) {

                        # Files are different
                        Write-Log -Message 'The files in the destination do not match the files in the source after the copy' -LogId $LogId -Severity 3
                        Write-Warning -Message 'The files in the destination do not match the files in the source after the copy'

                        foreach ($difference in $differences) {
                            $side = if ($difference.SideIndicator -eq '<=') { "found in source, not in destination" } else { "found in destination, not in source" }
                            Write-Log -Message ("'{0}' {1}" -f $difference.InputObject, $side) -LogId $LogId -Severity 3
                            Write-Warning -Message ("'{0}' {1}" -f $difference.InputObject, $side)
                        }
                        Get-ScriptEnd -ErrorMessage $_.Exception.Message
                    }
                    else {
                        # Files are the same
                        Write-Log -Message 'File check pass. Copy was succesful' -LogId $LogId
                        Write-Host 'File check pass. Copy was succesful' -ForegroundColor Green
                    }
                }
                catch {
                    Write-Log -Message 'Could not compare the source and destination folders' -LogId $LogId -Severity 3
                    Write-Warning -Message 'Could not compare the source and destination folders'
                    Get-ScriptEnd -ErrorMessage $_.Exception.Message
                }
            }
            catch {
                Write-Log -Message 'Could not compare the source and destination folders' -LogId $LogId -Severity 3
                Write-Warning -Message 'Could not compare the source and destination folders'
                Get-ScriptEnd -ErrorMessage $_.Exception.Message
            }
        }
        catch {
            Write-Log -Message ("Could not transfer content from '{0}' to '{1}'" -f $sourceSanitised, $destinationSanitised) -LogId $LogId -Severity 3
            Write-Warning -Message ("Could not transfer content from '{0}' to '{1}'" -f $sourceSanitised, $destinationSanitised)
            Get-ScriptEnd -ErrorMessage $_.Exception.Message
        }
    }
}