<#
.Synopsis
Created on:   21/03/2021
Created by:   Ben Whitmore
Filename:     New-IntuneWin.ps1

.Description
Function to create a .intunewin file
#>

Function New-IntuneWin {
    Param (
        [String]$ContentFolder,
        [String]$OutputFolder,
        [String]$SetupFile
    )
    write-host $ContentFolder

    Write-Log -Message "Function: New-IntuneWin was called" -Log "Main.log" 

    #Search the Install Command line for other the installer type
    If ($SetupFile -match "powershell" -and $SetupFile -match "\.ps1") {
        Write-Log -Message "Powershell script detected" -Log "Main.log" 
        Write-Host "Powershell script detected" -ForegroundColor Yellow
        Write-Host ''
        $Right = ($SetupFile -split ".ps1")[0]
        $Right = ($Right -Split " ")[-1]
        $Filename = $Right.TrimStart("\", ".", "`"")
        $Command = $Filename + ".ps1"
        Write-Log -Message "Extracting the SetupFile Name for the Microsoft Win32 Content Prep Tool from the Install Command..." -Log "Main.log" 
        Write-Host "Extracting the SetupFile Name for the Microsoft Win32 Content Prep Tool from the Install Command..." -ForegroundColor Cyan
        Write-Log -Message "$($Command)" -Log "Main.log" 
        Write-Host $Command -ForegroundColor Green
    }
    elseif ($SetupFile -match "\.exe" -and $SetupFile -notmatch "msiexec" -and $SetupFile -notmatch "cscript" -and $SetupFile -notmatch "wscript") {
        $Installer = ".exe"
        Write-Log -Message "$($Installer) installer detected" -Log "Main.log" 
        Write-Host "$Installer installer detected"
        $Right = ($SetupFile -split "\.exe")[0]
        $Right = ($Right -Split " ")[-1]
        $FileName = $Right.TrimStart("\", ".", "`"")
        $Command = $Filename + $Installer
        $Command -replace '"', ''
        Write-Log -Message "Extracting the SetupFile Name for the Microsoft Win32 Content Prep Tool from the Install Command..." -Log "Main.log" 
        Write-Host "Extracting the SetupFile Name for the Microsoft Win32 Content Prep Tool from the Install Command..." -ForegroundColor Cyan
        Write-Log -Message "$($Command)" -Log "Main.log" 
        Write-Host $Command -ForegroundColor Green
    }
    elseif ($SetupFile -match "\.msi") {
        $Installer = ".msi"
        Write-Log -Message "$($Installer) installer detected" -Log "Main.log" 
        Write-Host "$Installer installer detected"
        $Right = ($SetupFile -split "\.msi")[0]
        $Right = ($Right -Split " ")[-1]
        $FileName = $Right.TrimStart("\", ".", "`"")
        $Command = $Filename + $Installer
        $Command -replace '"', ''
        Write-Log -Message "Extracting the SetupFile Name for the Microsoft Win32 Content Prep Tool from the Install Command..." -Log "Main.log" 
        Write-Host "Extracting the SetupFile Name for the Microsoft Win32 Content Prep Tool from the Install Command..." -ForegroundColor Cyan
        Write-Log -Message "$($Command)" -Log "Main.log" 
        Write-Host $Command -ForegroundColor Green
    }
    elseif ($SetupFile -match "\.vbs") {
        $Installer = ".vbs"
        Write-Log -Message "$($Installer) script detected" -Log "Main.log" 
        Write-Host "$Installer installer detected"
        $Right = ($SetupFile -split "\.vbs")[0]
        $Right = ($Right -Split " ")[-1]
        $FileName = $Right.TrimStart("\", ".", "`"")
        $Command = $Filename + $Installer
        $Command -replace '"', ''
        Write-Log -Message "Extracting the SetupFile Name for the Microsoft Win32 Content Prep Tool from the Install Command..." -Log "Main.log" 
        Write-Host "Extracting the SetupFile Name for the Microsoft Win32 Content Prep Tool from the Install Command..." -ForegroundColor Cyan
        Write-Log -Message "$($Command)" -Log "Main.log" 
        Write-Host $Command -ForegroundColor Green
    }
    elseif ($SetupFile -match "\.cmd") {
        $Installer = ".cmd"
        Write-Log -Message "$($Installer) installer detected" -Log "Main.log" 
        Write-Host "$Installer installer detected"
        $Right = ($SetupFile -split "\.cmd")[0]
        $Right = ($Right -Split " ")[-1]
        $FileName = $Right.TrimStart("\", ".", "`"")
        $Command = $Filename + $Installer
        $Command -replace '"', ''
        Write-Log -Message "Extracting the SetupFile Name for the Microsoft Win32 Content Prep Tool from the Install Command..." -Log "Main.log" 
        Write-Host "Extracting the SetupFile Name for the Microsoft Win32 Content Prep Tool from the Install Command..." -ForegroundColor Cyan
        Write-Log -Message "$($Command)" -Log "Main.log" 
        Write-Host $Command -ForegroundColor Green
    }
    elseif ($SetupFile -match "\.bat") {
        $Installer = ".bat"
        Write-Log -Message "$($Installer) installer detected" -Log "Main.log" 
        Write-Host "$Installer installer detected"
        $Right = ($SetupFile -split "\.bat")[0]
        $Right = ($Right -Split " ")[-1]
        $FileName = $Right.TrimStart("\", ".", "`"")
        $Command = $Filename + $Installer
        $Command -replace '"', ''
        Write-Log -Message "Extracting the SetupFile Name for the Microsoft Win32 Content Prep Tool from the Install Command..." -Log "Main.log" 
        Write-Host "Extracting the SetupFile Name for the Microsoft Win32 Content Prep Tool from the Install Command..." -ForegroundColor Cyan
        Write-Log -Message "$($Command)" -Log "Main.log" 
        Write-Host $Command -ForegroundColor Green
    }

    Write-Host ''

    Try {
        #Check IntuneWinAppUtil.exe
        Write-Log -Message "Re-checking presence of Win32 Content Prep Tool..." -Log "Main.log" 
        Write-Host "Re-checking presence of Win32 Content Prep Tool..." -ForegroundColor Cyan
        If (Test-Path (Join-Path -Path $WorkingFolder_ContentPrepTool -ChildPath "IntuneWinAppUtil.exe")) {
            Write-Log -Message "Information: IntuneWinAppUtil.exe already exists at ""$($WorkingFolder_ContentPrepTool)"". Skipping download" -Log "Main.log" 
            Write-Host "Information: IntuneWinAppUtil.exe already exists at ""$($WorkingFolder_ContentPrepTool)"". Skipping download" -ForegroundColor Magenta
        }
        else {
            Write-Log -Message "Downloading Win32 Content Prep Tool..." -Log "Main.log" 
            Write-Host "Downloading Win32 Content Prep Tool..." -ForegroundColor Cyan
            Write-Log -Message "Get-FileFromInternet -URI ""https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/raw/master/IntuneWinAppUtil.exe"" -Destination $($WorkingFolder_ContentPrepTool)" -Log "Main.log" 
            Get-FileFromInternet -URI "https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/raw/master/IntuneWinAppUtil.exe" -Destination $WorkingFolder_ContentPrepTool
        }
        Write-Host ''
        Write-Log -Message "Building IntuneWinAppUtil.exe execution string..." -Log "Main.log" 
        Write-Host "Building IntuneWinAppUtil.exe execution string..." -ForegroundColor Cyan
        Write-Log -Message """$($WorkingFolder_ContentPrepTool)\IntuneWinAppUtil.exe"" -s ""$($Command)"" -c ""$($ContentFolder)"" -o ""$($OutputFolder)""" -Log "Main.log" 
        Write-Host """$($WorkingFolder_ContentPrepTool)\IntuneWinAppUtil.exe"" -s ""$($Command)"" -c ""$($ContentFolder)"" -o ""$($OutputFolder)""" -ForegroundColor Green

        #Try running the content prep tool to build the intunewin
        Try {
            $Arguments = @(
                "-s"
                """$Command"""
                "-c"
                """$ContentFolder"""
                "-o"
                """$OutputFolder"""
                "-q"
            )
            Write-Log -Message "Start-Process -FilePath (Join-Path -Path $($WorkingFolder_ContentPrepTool) -ChildPath ""IntuneWinAppUtil.exe"") -ArgumentList $($Arguments) -Wait" -Log "Main.log" 
            Start-Process -FilePath (Join-Path -Path $WorkingFolder_ContentPrepTool -ChildPath "IntuneWinAppUtil.exe") -ArgumentList $Arguments -Wait 
            Write-Host ''
                 
            If (Test-Path (Join-Path -Path $OutputFolder -ChildPath "*.intunewin") ) {
                Write-Log -Message "Successfully created ""$($Filename).intunewin"" at ""$($OutputFolder)""" -Log "Main.log" 
                Write-Host "Successfully created ""$($Filename).intunewin"" at ""$($OutputFolder)""" -ForegroundColor Cyan
            }
            else {
                Write-Log -Message "Error: We couldn't verify that ""$($Filename).intunewin"" was created at ""$($OutputFolder)""" -Log "Main.log" 
                Write-Host "Error: We couldn't verify that ""$($Filename).intunewin"" was created at ""$($OutputFolder)""" -ForegroundColor Red
            }
        }
        Catch {
            Write-Log -Message "Error creating the .intunewin file" -Log "Main.log"
            Write-Host "Error creating the .intunewin file" -ForegroundColor Red
            Write-Log -Message "$($_)" -Log "Main.log"
            Write-Host $_ -ForegroundColor Red
        }
    }
    Catch {
        Write-Log -Message "The script encounted an error getting the Win32 Content Prep Tool" -Log "Main.log"
        Write-Host "The script encounted an error getting the Win32 Content Prep Tool" -ForegroundColor Red
    }
}