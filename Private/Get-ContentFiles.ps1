<#
.Synopsis
Created on:   04/11/2023
Updated on:   16/11/2026
Created by:   Ben Whitmore
Filename:     Get-ContentFiles.ps1

.Description
Function to get content from the content source folder for the deployment type and copy it to the content destination folder.
After the copy every source file is verified in the destination (relative path and size). Throws on failure.
Test-ContentCopy performs the verification and returns $true or $false.

.PARAMETER LogId
The component (script name) passed as LogID to the 'Write-Log' function. 
This parameter is built from the line number of the call from the function up the

.PARAMETER Source
Source path for content to be copied from

.PARAMETER Destination
Destination path for content to be copied to

.PARAMETER Flags
Add verbose message if specfic flag is set

.PARAMETER DeploymentTypeName
The name of the deployment type (used in log messages)
#>
function Get-ContentRelativeFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Root
    )

    $rootFull = (Get-Item -LiteralPath "FileSystem::$Root" -ErrorAction Stop).FullName.TrimEnd('\', '/')
    Get-ChildItem -LiteralPath "FileSystem::$Root" -Recurse -File -ErrorAction Stop | ForEach-Object {
        [PSCustomObject]@{
            RelativePath = $_.FullName.Substring($rootFull.Length).TrimStart('\', '/')
            Length       = $_.Length
        }
    }
}

function Test-ContentCopy {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $false)]
        [string]$LogId = $($MyInvocation.MyCommand).Name,
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Source,
        [Parameter(Mandatory = $true, Position = 1)]
        [string]$Destination
    )

    $sourceFiles = @(Get-ContentRelativeFile -Root $Source)
    $destinationFiles = @{}
    foreach ($item in @(Get-ContentRelativeFile -Root $Destination)) {
        $destinationFiles[$item.RelativePath.ToLowerInvariant()] = $item.Length
    }

    $ok = $true
    foreach ($item in $sourceFiles) {
        $key = $item.RelativePath.ToLowerInvariant()
        if (-not $destinationFiles.ContainsKey($key)) {
            Write-LogAndHost -Message ("'{0}' found in the source folder, but not in the destination folder" -f $item.RelativePath) -LogId $LogId -Severity 3
            $ok = $false
        }
        elseif ($destinationFiles[$key] -ne $item.Length) {
            Write-LogAndHost -Message ("'{0}' has a different size in the destination folder (source {1} bytes, destination {2} bytes)" -f $item.RelativePath, $item.Length, $destinationFiles[$key]) -LogId $LogId -Severity 3
            $ok = $false
        }
    }
    return $ok
}

function Get-ContentFiles {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = "The component (script name) passed as LogID to the 'Write-Log' function")]
        [string]$LogId = $($MyInvocation.MyCommand).Name,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 0, HelpMessage = 'Source path for content to be copied from')]
        [string]$Source,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 1, HelpMessage = 'Destination path for content to be copied to')]
        [string]$Destination,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 2, HelpMessage = 'Add verbose message if specfic flag is set')]
        [string]$Flags,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, HelpMessage = 'The name of the deployment type')]
        [string]$DeploymentTypeName
    )

    process {

        if ($Flags -eq 'UninstallDifferent') {
            Write-LogAndHost -Message ("Uninstall content is different for '{0}'. Will copy content to \Uninstall folder" -f $DeploymentTypeName) -LogId $LogId -Severity 2 -NewLine
        }

        # Create destination folders if they don't exist
        Write-LogAndHost -Message ("Attempting to create the destination folder '{0}'" -f $Destination) -LogId $LogId -ForegroundColor Cyan

        if (-not (Test-Path -LiteralPath $Destination)) {
            try {
                New-Item -Path $Destination -ItemType Directory -Force -ErrorAction Stop | Out-Null
                Write-LogAndHost -Message ("Successfully created the destination folder '{0}'" -f $Destination) -LogId $LogId -ForegroundColor Green
            }
            catch {
                Write-LogAndHost -Message ("Error: Could not create the destination folder '{0}'. {1}" -f $Destination, $_.Exception.Message) -LogId $LogId -Severity 3
                throw
            }
        }
        else {
            Write-LogAndHost -Message ("The destination folder '{0}' already exists. Continuing with the copy..." -f $Destination) -LogId $LogId -Severity 2
        }
        Write-LogAndHost -Message ("Attempting to copy content from '{0}' to '{1}'" -f $Source, $Destination) -LogId $LogId -ForegroundColor Cyan

        try {
            $sourceRoot = (Get-Item -LiteralPath "FileSystem::$Source" -ErrorAction Stop).FullName.TrimEnd('\', '/')

            # List items to copy
            $itemsToCopy = @(Get-ChildItem -LiteralPath "FileSystem::$Source" -Recurse -ErrorAction Stop)
            $itemsToCopy | ForEach-Object { Write-Log -Message ("'{0}'" -f $_.FullName) -LogId $LogId }
            Write-LogAndHost -Message ("There are '{0}' items to copy" -f $itemsToCopy.Count) -LogId $LogId -ForegroundColor Cyan

            $itemCount = 0
            foreach ($item in $itemsToCopy) {
                $relativePath = $item.FullName.Substring($sourceRoot.Length).TrimStart('\', '/')
                $destinationItem = Join-Path -Path $Destination -ChildPath $relativePath

                try {
                    if ($item.PSIsContainer) {
                        if (-not (Test-Path -LiteralPath $destinationItem)) {
                            New-Item -Path $destinationItem -ItemType Directory -Force -ErrorAction Stop | Out-Null
                        }
                    }
                    else {
                        Write-LogAndHost -Message ("Copying '{0}' to '{1}'" -f $item.FullName, $destinationItem) -LogId $LogId -ForegroundColor Cyan
                        $destinationParent = Split-Path -Path $destinationItem -Parent
                        if (-not (Test-Path -LiteralPath $destinationParent)) {
                            New-Item -Path $destinationParent -ItemType Directory -Force -ErrorAction Stop | Out-Null
                        }
                        Copy-Item -LiteralPath "FileSystem::$($item.FullName)" -Destination $destinationItem -Force -ErrorAction Stop
                    }

                    $itemCount++
                    $progressPercentage = [int](($itemCount / $itemsToCopy.Count) * 100)
                    Write-Progress -PercentComplete $progressPercentage -Activity 'Copying Files' -Status $item.FullName -CurrentOperation "Progress: $progressPercentage%"
                }
                catch {
                    Write-LogAndHost -Message ("Error: Could not copy '{0}' to '{1}'. {2}" -f $item.FullName, $destinationItem, $_.Exception.Message) -LogId $LogId -Severity 3
                    throw
                }
            }
            Write-Progress -Completed -Activity 'Copying Files'
        }
        catch {
            Write-Progress -Completed -Activity 'Copying Files'
            Write-LogAndHost -Message ("Could not transfer content from '{0}' to '{1}'. {2}" -f $Source, $Destination, $_.Exception.Message) -LogId $LogId -Severity 3
            throw
        }

        # Verify the copy
        if (Test-ContentCopy -Source $Source -Destination $Destination -LogId $LogId) {
            Write-LogAndHost -Message 'All files were verified in the destination folder. Copy was successful' -LogId $LogId -ForegroundColor Green
        }
        else {
            throw ("Content copy verification failed for '{0}'" -f $Source)
        }
    }
}
