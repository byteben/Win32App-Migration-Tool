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

.PARAMETER Destination
Destination path for content to be copied to

.PARAMETER Flags
Add verbose message if specfic flag is set
#>
function Get-ContentFiles {
    param (
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = "The component (script name) passed as LogID to the 'Write-Log' function")]
        [string]$LogId = $($MyInvocation.MyCommand).Name,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 0, HelpMessage = 'Source path for content to be copied from')]
        [string]$Source,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 1, HelpMessage = 'Destination path for content to be copied to')]
        [string]$Destination,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 2, HelpMessage = 'Add verbose message if specfic flag is set')]
        [string]$Flags
    )
    
    process {

        # Extra message to indicate flag condition
        if ($flags -eq 'UninstallDifferent') {
            Write-Log -Message ("Uninstall content is different for '{0}'. Will copy content to \Uninstall folder" -f $deploymentType.Name) -LogId $LogId
            Write-Host ("`nUninstall content is different for '{0}'. Will copy content to \Uninstall folder" -f $deploymentType.Name) -ForegroundColor Yellow
        }
                
        # Create destination folders if they don't exist
        Write-Log -Message ("Attempting to create the destination folder '{0}'" -f $Destination) -LogId $LogId
        Write-Host ("{0}Attempting to create the destination folder '{1}'" -f $(if ($flags -ne 'UninstallDifferent') { "`n" }), $Destination) -ForegroundColor Cyan

        if (-not (Test-Path -Path $Destination) ) {
            try {
                New-Item -Path $Destination -ItemType Directory -Force | Out-Null
                Write-Log -Message ("Successfully created the destination folder '{0}'" -f $Destination) -LogId $LogId
                Write-Host ("Successfully created the destination folder '{0}'" -f $Destination) -ForegroundColor Green
            }
            catch {
                Write-Log -Message ("Error: Could not create the destination folder '{0}'" -f $Destination) -LogId $LogId -Severity 3
                Write-Warning -Message ("Error: Could not create the destination folder '{0}'" -f $Destination)
                Write-Log -Message ("'{0}'" -f $_.Exception.Message) -LogId $LogId -Severity 3
                throw
            }
        }
        else {
            Write-Log -Message ("The destination folder '{0}' already exists. Continuing with the copy..." -f $Destination) -LogId $LogId -Severity 2
            Write-Host ("The destination folder '{0}' already exists. Continuing with the copy..." -f $Destination) -ForegroundColor Yellow
        }
        Write-Log -Message ("Attempting to copy content from '{0}' to '{1}'" -f $Source, $Destination) -LogId $LogId
        Write-Host ("Attempting to copy content from '{0}' to '{1}'" -f $Source, $Destination) -ForegroundColor Cyan

        # Convert UNC paths to FileSystem paths
        $sourceUNC = "FileSystem::$($Source)"

        try {
            # List files to copy
            $filesToCopy = Get-ChildItem -Path $sourceUNC -Recurse -ErrorAction Stop 
            $filesToCopy | Select-Object -ExpandProperty FullName | foreach-object { Write-Log -Message ("'{0}'" -f $_) -LogId $LogId }
            Write-Log -Message ("There are '{0}' items to copy" -f $filesToCopy.Count) -LogId $LogId
            Write-Host ("There are '{0}' items to copy" -f $filesToCopy.Count) -ForegroundColor Cyan

            # Initialize a counter
            $fileCount = 0

            # Copy items and track progress
            foreach ($file in $filesToCopy) {
                $sourceFile = "FileSystem::$($file.FullName)"
                $relativePath = $file.FullName.Substring($source.Length)

                # Construct the destination path
                $destinationFile = Join-Path -Path $Destination -ChildPath $relativePath

                # Copy the item
                try {
                    Write-Log -Message ("Copying '{0}' to '{1}'" -f $sourceFile, $destinationFile) -LogId $LogId
                    Write-Host ("Copying '{0}' to '{1}'" -f $file.Name, $destinationFile) -ForegroundColor White
                    Copy-Item -Path $sourceFile -Destination $destinationFile -Force

                    # Increment the counter
                    $fileCount++

                    # Calculate and display progress as a percentage
                    $progressPercentage = ($fileCount / ($filesToCopy).Count) * 100
                    Write-Progress -PercentComplete $progressPercentage -Activity 'Copying Files' -Status $file.FullName -CurrentOperation "Progress: $progressPercentage%"
                }
                catch {
                    Write-Log -Message ("Error: Could not copy '{0}' to '{1}'" -f $sourceFile, $destinationFile) -LogId $LogId -Severity 3
                    Write-Warning -Message ("Error: Could not copy '{0}' to '{1}'" -f $sourceFile, $destinationFile)
                    Write-Log -Message ("'{0}'" -f $_.Exception.Message) -LogId $LogId -Severity 3
                    throw
                }
            }

            # Remove the progress bar once the copying is complete
            Write-Progress -Completed -Activity 'File copy completed'
            
            try {
                # Compare the source and destination folders to ensure the copy was successful
                $sourceCompare = Get-ChildItem -Path $sourceUNC -Recurse -ErrorAction Stop
                $destinationCompare = Get-ChildItem -Path $Destination -Recurse -ErrorAction Stop

                # Compare the file hashes
                $compareResult = Compare-Object -ReferenceObject $sourceCompare -DifferenceObject $destinationCompare

                try {
                    # Filter out the differences
                    $differences = $compareResult | Where-Object { $_.SideIndicator -eq '<=' -or $_.SideIndicator -eq '=>' }

                    if ($differences) {

                        # Files are different but this is OK if the uninstall content has been copied. Check if we have all the source files in the destination folder
                        foreach ($difference in $differences) {
                            if ($difference.SideIndicator -eq '<=') { 
                                Write-Log -Message ("'{0}' found in the source folder, but not in the destination folder" -f $difference.InputObject) -LogId $LogId -Severity 3
                                Write-Warning -Message ("'{0}' found in the source folder, but not in the destination folder" -f $difference.InputObject)
                            }
                        }
                    }
                    else {
                        # Files are the same
                        Write-Log -Message 'All files were verified in the destination folder. Copy was successful' -LogId $LogId
                        Write-Host 'All files were verified in the destination folder. Copy was successful' -ForegroundColor Green
                    }
                }
                catch {
                    Write-Log -Message 'Could not compare the source and destination folders' -LogId $LogId -Severity 3
                    Write-Warning -Message 'Could not compare the source and destination folders'
                    Write-Log -Message ("'{0}'" -f $_.Exception.Message) -LogId $LogId -Severity 3
                    Get-ScriptEnd -LogId $LogId -Message $_.Exception.Message    
                }
            }
            catch {
                Write-Log -Message 'Could not compare the source and destination folders' -LogId $LogId -Severity 3
                Write-Warning -Message 'Could not compare the source and destination folders'
                Write-Log -Message ("'{0}'" -f $_.Exception.Message) -LogId $LogId -Severity 3
                Get-ScriptEnd -LogId $LogId -Message $_.Exception.Message
            }
        }
        catch {
            Write-Log -Message ("Could not transfer content from '{0}' to '{1}'" -f $sourceSanitised, $destinationSanitised) -LogId $LogId -Severity 3
            Write-Warning -Message ("Could not transfer content from '{0}' to '{1}'" -f $sourceSanitised, $destinationSanitised)
            Write-Log -Message ("'{0}'" -f $_.Exception.Message) -LogId $LogId -Severity 3
            Get-ScriptEnd -LogId $LogId -Message $_.Exception.Message
        }
    }
}