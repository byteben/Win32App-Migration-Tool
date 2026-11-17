<#
.Synopsis
Created on:   11/11/2023
Updated on:   16/11/2026
Created by:   Ben Whitmore
Filename:     New-IntuneWin.ps1

.Description
Function to create a .intunewin file. Returns the full path of the .intunewin file. Throws on failure.

.PARAMETER LogId
The component (script name) passed as LogID to the 'Write-Log' function. 
This parameter is built from the line number of the call from the function up the pipeline

.PARAMETER ContentFolder
The folder containing the content to be packaged

.PARAMETER OutputFolder
The folder to output the .intunewin file to

.PARAMETER SetupFile
The install command line. The setup file used for packaging is calculated from this command line

.PARAMETER OverrideIntuneWin32FileName
Override intunewin filename. Default is the name calcualted from the install command line
#>
function New-IntuneWin {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = 'The component (script name) passed as LogID to the Write-Log function')]
        [string]$LogId = $($MyInvocation.MyCommand).Name,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 0, HelpMessage = 'The folder containing the content to be packaged')]
        [string]$ContentFolder,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 1, HelpMessage = 'The folder to output the .intunewin file to')]
        [string]$OutputFolder,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 2, HelpMessage = 'The install command line used to calculate the setup file')]
        [string]$SetupFile,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 3, HelpMessage = 'Override intunewin filename. Default is the name calcualted from the install command line')]
        [string]$OverrideIntuneWin32FileName
    )
    process {
        Write-LogAndHost -Message "Function: New-IntuneWin was called" -LogId $LogId -ForegroundColor Cyan

        # Detect the installer technology. Order matters: scripts, then executables (interpreters are skipped), then MSI/MSP, then other scripts
        $techs = @(
            @{ Tech = '.ps1'; Description = 'PowerShell script' }
            @{ Tech = '.exe'; Description = 'Executable' }
            @{ Tech = '.msi'; Description = 'MSI' }
            @{ Tech = '.msp'; Description = 'MSP' }
            @{ Tech = '.vbs'; Description = 'VBScript' }
            @{ Tech = '.cmd'; Description = 'CMD script' }
            @{ Tech = '.bat'; Description = 'Batch script' }
            @{ Tech = '.js'; Description = 'JavaScript' }
        )

        $commandToUse = $null
        foreach ($entry in $techs) {
            try {
                $commandToUse = Get-InstallCommand -InstallTech $entry.Tech -SetupFile $SetupFile -LogId $LogId
                Write-LogAndHost -Message ("{0} detected" -f $entry.Description) -LogId $LogId -ForegroundColor Cyan
                break
            }
            catch {
                $commandToUse = $null
            }
        }

        if (-not $commandToUse) {
            $message = "No supported installer found in the install command '{0}'. Supported: .exe .msi .msp .ps1 .vbs .cmd .bat .js" -f $SetupFile
            Write-LogAndHost -Message $message -LogId $LogId -Severity 3
            throw $message
        }

        # Pre-flight checks
        # The session is usually on the ConfigMgr site drive (e.g. P01:), where a \\server\share path doesn't
        # resolve. Use the FileSystem provider explicitly for every content path check
        if (-not (Test-Path -LiteralPath "FileSystem::$ContentFolder")) {
            $message = "Content folder '{0}' was not found" -f $ContentFolder
            Write-LogAndHost -Message $message -LogId $LogId -Severity 3
            throw $message
        }
        if (-not (Test-Path -LiteralPath ("FileSystem::" + [System.IO.Path]::Combine($ContentFolder, $commandToUse)))) {
            $message = "Setup file '{0}' was not found in content folder '{1}'" -f $commandToUse, $ContentFolder
            Write-LogAndHost -Message $message -LogId $LogId -Severity 3
            throw $message
        }
        if (-not (Test-Path -LiteralPath $OutputFolder)) {
            New-Item -Path $OutputFolder -ItemType Directory -Force -ErrorAction Stop | Out-Null
        }

        $toolPath = Join-Path -Path "$workingFolder_Root\ContentPrepTool" -ChildPath 'IntuneWinAppUtil.exe'
        Write-LogAndHost -Message ("Building IntuneWinAppUtil.exe execution string: '{0}' -s '{1}' -c '{2}' -o '{3}'" -f $toolPath, $commandToUse, $ContentFolder, $OutputFolder) -LogId $LogId -ForegroundColor Cyan

        $arguments = @(
            '-s'
            "`"$commandToUse`""
            '-c'
            "`"$ContentFolder`""
            '-o'
            "`"$OutputFolder`""
            '-q'
        )

        # The tool's own output is written to a log next to the package instead of the console, where it buries the
        # migration tool's messages. It's shown only when the tool fails
        $toolLog = Join-Path -Path $OutputFolder -ChildPath 'IntuneWinAppUtil.log'
        $toolErrorLog = Join-Path -Path $OutputFolder -ChildPath 'IntuneWinAppUtil.error.log'

        $start = (Get-Date).AddSeconds(-2)
        try {
            $process = Start-Process -FilePath $toolPath -ArgumentList $arguments -WorkingDirectory $OutputFolder -Wait -PassThru -NoNewWindow `
                -RedirectStandardOutput $toolLog -RedirectStandardError $toolErrorLog -ErrorAction Stop
        }
        catch {
            Write-LogAndHost -Message ("An error was encountered when attempting to create a intunewin file at '{0}'. {1}" -f $OutputFolder, $_.Exception.Message) -LogId $LogId -Severity 3
            throw
        }
        Write-Log -Message ("IntuneWinAppUtil.exe output is in '{0}'" -f $toolLog) -LogId $LogId

        if ($process.ExitCode -ne 0) {
            $tail = @(foreach ($file in @($toolErrorLog, $toolLog)) {
                    if (Test-Path -LiteralPath $file) { Get-Content -LiteralPath $file -Tail 10 -ErrorAction SilentlyContinue }
                }) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
            $message = "IntuneWinAppUtil.exe failed with exit code {0} for setup file '{1}'. Last output: {2}" -f $process.ExitCode, $commandToUse, (($tail | ForEach-Object { $_.Trim() }) -join ' | ')
            Write-LogAndHost -Message $message -LogId $LogId -Severity 3
            throw $message
        }

        # The tool names the output after the setup file base name at the output root, so find the newest file created by this run
        $intuneWinFile = Get-ChildItem -LiteralPath $OutputFolder -Filter '*.intunewin' -File -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -ge $start } |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1

        if (-not $intuneWinFile) {
            $message = "The content prep tool ran successfully but no .intunewin file was found in '{0}'" -f $OutputFolder
            Write-LogAndHost -Message $message -LogId $LogId -Severity 3
            throw $message
        }

        $finalPath = $intuneWinFile.FullName
        Write-LogAndHost -Message ("Successfully created intunewin file '{0}'" -f $finalPath) -LogId $LogId -ForegroundColor Green

        # Override the intunewin filename if requested. We can't rename this during the creation of the file so let's rename it now
        if ($OverrideIntuneWin32FileName) {
            $newName = "$OverrideIntuneWin32FileName.intunewin"
            $targetPath = Join-Path -Path $OutputFolder -ChildPath $newName
            Write-LogAndHost -Message ("The 'OverrideIntuneWin32FileName' parameter was passed. Renaming intunewin file '{0}' to '{1}'" -f $intuneWinFile.Name, $newName) -LogId $LogId -ForegroundColor Cyan

            if ($targetPath -ne $finalPath) {
                try {
                    if (Test-Path -LiteralPath $targetPath) {
                        Write-LogAndHost -Message ("The file '{0}' already exists. Deleting the existing file before renaming" -f $targetPath) -LogId $LogId -Severity 2
                        Remove-Item -LiteralPath $targetPath -Force -ErrorAction Stop
                    }
                    Rename-Item -LiteralPath $finalPath -NewName $newName -ErrorAction Stop
                    $finalPath = $targetPath
                    Write-LogAndHost -Message ("Successfully renamed intunewin file '{0}' to '{1}'" -f $intuneWinFile.Name, $newName) -LogId $LogId -ForegroundColor Green
                }
                catch {
                    Write-LogAndHost -Message ("An error was encountered when attempting to rename intunewin file '{0}' to '{1}'. {2}" -f $intuneWinFile.Name, $newName, $_.Exception.Message) -LogId $LogId -Severity 3
                    throw
                }
            }
        }

        return $finalPath
    }
}
