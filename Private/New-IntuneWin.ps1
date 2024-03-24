<#
.Synopsis
Created on:   11/11/2023
Created by:   Ben Whitmore
Filename:     New-IntuneWin.ps1

.Description
Function to create a .intunewin file

.PARAMETER LogId
The component (script name) passed as LogID to the 'Write-Log' function. 
This parameter is built from the line number of the call from the function up the pipeline

.PARAMETER ContentFolder
The folder containing the content to be packaged

.PARAMETER OutputFolder
The folder to output the .intunewin file to

.PARAMETER SetupFile
The setup file to be used for packaging. Normally the .msi, .exe or .ps1 file used to install the application

.PARAMETER OverrideIntuneWin32FileName
Override intunewin filename. Default is the name calcualted from the install command line
#>
function New-IntuneWin {
    param(
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = 'The component (script name) passed as LogID to the Write-Log function')]
        [string]$LogId = $($MyInvocation.MyCommand).Name,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 0, HelpMessage = 'The folder containing the content to be packaged')]
        [string]$ContentFolder,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 1, HelpMessage = 'The folder to output the .intunewin file to')]
        [string]$OutputFolder,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 2, HelpMessage = 'The setup file to be used for packaging. Normally the .msi, .exe or .ps1 file used to install the application')]
        [string]$SetupFile,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 3, HelpMessage = 'Override intunewin filename. Default is the name calcualted from the install command line')]
        [string]$OverrideIntuneWin32FileName
    )
    begin {
        Write-Log -Message "Function: New-IntuneWin was called" -Log "Main.log"
    }
    process {

        # Search the Install Command line for other the installer type
        if ($SetupFile -match "powershell" -and $SetupFile -match "\.ps1") {
            $commandToUse = Get-InstallCommand -InstallTech '.ps1' -SetupFile $SetupFile
        }
        elseif ($SetupFile -match "\.exe" -and $SetupFile -notmatch "msiexec" -and $SetupFile -notmatch "cscript" -and $SetupFile -notmatch "wscript") {
            $commandToUse = Get-InstallCommand -InstallTech '.exe' -SetupFile $SetupFile
        }
        elseif ($SetupFile -match "\.msi") {
            $commandToUse = Get-InstallCommand -InstallTech '.msi' -SetupFile $SetupFile
        }
        elseif ($SetupFile -match "\.vbs") {
            $commandToUse = Get-InstallCommand -InstallTech '.vbs' -SetupFile $SetupFile
        }
        elseif ($SetupFile -match "\.cmd") {
            $commandToUse = Get-InstallCommand -InstallTech '.cmd' -SetupFile $SetupFile
        }
        elseif ($SetupFile -match "\.bat") {
            $commandToUse = Get-InstallCommand -InstallTech '.bat' -SetupFile $SetupFile
        }
        elseif ($SetupFile -match "\.js") {
            $commandToUse = Get-InstallCommand -InstallTech '.js' -SetupFile $SetupFile
        }
        else {
            # Handle the default case if none of the conditions match
            Write-Host "No matching extension found."
        }
    
        Write-Log -Message ("Building IntuneWinAppUtil.exe execution string: '{0}' -s '{1}' -c '{2}' -o '{3}'" -f "$workingFolder_Root\ContentPrepTool\IntuneWinAppUtil.exe", $commandToUse, $ContentFolder, $OutputFolder) -LogId $LogId
        Write-Host ("Building IntuneWinAppUtil.exe execution string: '{0}' -s '{1}' -c '{2}' -o '{3}'" -f "$workingFolder_Root\ContentPrepTool\IntuneWinAppUtil.exe", $commandToUse, $ContentFolder, $OutputFolder)  -ForegroundColor Cyan

        # Try running the content prep tool to build the intunewin
        try {
            $arguments = @(
                '-s'
                "`"$commandToUse`""
                '-c'
                "`"$ContentFolder`""
                '-o'
                "`"$OutputFolder`""
                '-q'
            )
            Start-Process -FilePath (Join-Path -Path "$workingFolder_Root\ContentPrepTool" -ChildPath "IntuneWinAppUtil.exe") -ArgumentList $arguments -Wait
        
        }
        catch {
            Write-Log -Message ("An error was encountered when attempting to create a intunewin file at '{0}'" -f $OutputFolder) -LogId $LogId -Severity 3
            Write-Warning -Message ("An error was encountered when attempting to create a intunewin file at '{0}'" -f $OutputFolder)
            Get-ScriptEnd -LogId $LogId -Message $_.Exception.Message
        }

        # Check if the intunewin file was created
        $fileToCheck = $commandToUse -replace '\..*', '.intunewin'

        if (Test-Path -Path "$OutputFolder\$fileToCheck" ) {
            Write-Log -Message ("Successfully created intunewin file '{0}' at '{1}'" -f $fileToCheck, $OutputFolder) -LogId $LogId 
            Write-Host ("Successfully created intunewin file '{0}' at '{1}'" -f $fileToCheck, $OutputFolder) -ForegroundColor Green

            # Override the intunewin filename if requested. We can't rename this during the creation of the file so let's rename it now
            if ($OverrideIntuneWin32FileName) { 

                Write-Log -Message ("The 'OverrideIntuneWin32FileName' parameter was passed. Renaming intunewin file '{0}' to '{1}.intunewin'" -f $fileToCheck, $OverrideIntuneWin32FileName) -LogId $LogId
                Write-Host ("The 'OverrideIntuneWin32FileName' parameter was passed. Renaming intunewin file '{0}' to '{1}.intunewin'" -f $fileToCheck, $OverrideIntuneWin32FileName) -ForegroundColor Cyan

                try {

                    # Check if the file already exists and delete it so the rename operation does not fail
                    if (Test-Path -Path "$OutputFolder\$OverrideIntuneWin32FileName.intunewin") {
                        Write-Log -Message ("The file '{0}' already exists. Deleting the existing file before renaming" -f "$OutputFolder\$OverrideIntuneWin32FileName.intunewin") -LogId $LogId
                        Write-Host ("The file '{0}' already exists. Deleting the existing file before renaming" -f "$OutputFolder\$OverrideIntuneWin32FileName.intunewin") -ForegroundColor Yellow
                        Remove-Item -Path "$OutputFolder\$OverrideIntuneWin32FileName.intunewin" -Force -ErrorAction Stop 
                    }

                    Rename-Item -Path "$OutputFolder\$fileToCheck" -NewName "$OverrideIntuneWin32FileName.intunewin" -ErrorAction Stop
                    Write-Log -Message ("Successfully renamed intunewin file '{0}' to '{1}.intunewin'" -f $fileToCheck, $OveideIntuneWin32FileName) -LogId $LogId
                    Write-Host ("Successfully renamed intunewin file '{0}' to '{1}.intunewin'" -f $fileToCheck, $OverrideIntuneWin32FileName) -ForegroundColor Green
                }
                catch {
                    Write-Log -Message ("An error was encountered when attempting to rename intunewin file '{0}' to '{1}.intunewin'" -f $fileToCheck, $OverrideIntuneWin32FileName) -LogId $LogId -Severity 3
                    Write-Warning -Message ("An error was encountered when attempting to rename intunewin file '{0}' to '{1}.intunewin'" -f $fileToCheck, $OverrideIntuneWin32FileName)
                    Write-Log -Message ("'{0}'" -f $_.Exception.Message) -LogId $LogId -Severity 3
                    throw
                }
            }
        }
        else {
            Write-Log -Message ("The content prep tool ran succesfully but failed to create an intunewin file at '{0}'" -f $OutputFolder)  -LogId $LogId
            Write-Warning -Message ("The content prep tool ran succesfully but failed to create an intunewin file at '{0}'" -f $OutputFolder)
            Write-Log -Message ("'{0}'" -f $_.Exception.Message) -LogId $LogId -Severity 3
            throw
        }
    }
}