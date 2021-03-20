<#
.Synopsis
Created on:   14/03/2021
Created by:   Ben Whitmore
Filename:     Win32AppMigrationTool.ps1

The Win32 App Migration Tool is designed to inventory ConfigMgr Applications and Deployment Types, build .intunewin files and create Win3Apps in The MEM Admin Center.

Instead of manually checking Application and Deployment Type information and gathering content to build Win32apps, the Win32APp Migration Tool is designed to do that for you. To date, the Application and Deployment Type information is gathered and a .Intunewin file is created. We are also collecting the logo for the application.

The Win32App Migration Tool is still in BETA so I would welcome any feedback or suggestions for improvement. Reach out on Twitter to DM @byteben (DM's are open)

.Description

**Version 1.03.20.01 - 20/03/2021 - BETA**  
- Added support for .vbs script installers  
- Fixed logic error for string matching  
    
**Version 1.03.19.01 - 19/03/2021 - BETA**    
- Added Function Get-ScriptEnd  
  
**Version 1.03.18.03 - 18/03/2021 - BETA**   
- Fixed an issue where Intunewin SetupFile was being detected as an .exe when msiexec was present in the install command  
  
**Version 1.03.18.02 - 18/03/2021 - BETA**   
- Removed the character " from SetupFile command when an install command is wrapped in double quotes  
  
**Version 1.03.18.01 - 18/03/2021  - BETA**  
- Robocopy for content now padding Source and Destination variables if content path has white space  
- Deployment Type Count was failing from the SDMPackageXML. Using the measure tool to check if Deployment Types exist for an Application  
- Removed " from SetupFile command if install commands are in double quotes  
  
**Version 1.03.18 - 18/03/2021  - BETA**
- Release for Testing  
- Logging Added  

**Version 1.0 - 14/03/2021 - DEV**  
- DEV Release  

.Parameter AppName
Pass a string to the toll to search for applications in ConfigMgr

.Parameter SiteCode
Specify the Sitecode you wish to connect to

.Parameter ProviderMachineName
Specify the Site Server to connect to

.Parameter ExportLogo
When passed, the Application logo is decoded from base64 and saved to the Logos folder

.Parameter WorkingFolder
This is the working folder for the Win32AppMigration Tool. Care should be given when specifying the working folder because downloaded content can increase the working folder size considerably. The Following folders are created in this directory:-

-Content
-ContentPrepTool
-Details
-Logos
-Logs
-Win32Apps

.Parameter PackageApps
Pass this parameter to package selected apps in the .intunewin format

.Parameter CreateApps
Pass this parameter to create the Win32apps in Intune

.Parameter ResetLog
Pass this parameter to reset the log file

.Example
.\Win32AppMigrationTool.ps1 -SiteCode "BB1" -ProviderMachineName "SCCM1.byteben.com" -AppName "Microsoft Edge Chromium *"

.Example
.\Win32AppMigrationTool.ps1 -SiteCode "BB1" -ProviderMachineName "SCCM1.byteben.com" -AppName "Microsoft Edge Chromium *" -ExportLogo

.Example
.\Win32AppMigrationTool.ps1 -SiteCode "BB1" -ProviderMachineName "SCCM1.byteben.com" -AppName "Microsoft Edge Chromium *" -ExportLogo -PackageApps

.Example
.\Win32AppMigrationTool.ps1 -SiteCode "BB1" -ProviderMachineName "SCCM1.byteben.com" -AppName "Microsoft Edge Chromium *" -ExportLogo -PackageApps -CreateApps

.Example
.\Win32AppMigrationTool.ps1 -SiteCode "BB1" -ProviderMachineName "SCCM1.byteben.com" -AppName "Microsoft Edge Chromium *" -ExportLogo -PackageApps -CreateApps -ResetLog
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $True)]
    [String]$AppName,
    [Parameter(Mandatory = $True)]
    [String]$ProviderMachineName,
    [Parameter(Mandatory = $True)]
    [ValidateLength(3, 3)]
    [String]$SiteCode,   
    [Parameter()]
    [Switch]$ExportLogo,
    [String]$WorkingFolder = "C:\Win32AppMigrationTool",
    [Switch]$PackageApps,
    [Switch]$CreateApps,
    [Switch]$ResetLog
)

#Create Global Variables
$Global:WorkingFolder_Root = $WorkingFolder
$Global:WorkingFolder_Logos = Join-Path -Path $WorkingFolder_Root -ChildPath "Logos"
$Global:WorkingFolder_Content = Join-Path -Path $WorkingFolder_Root -ChildPath "Content"
$Global:WorkingFolder_ContentPrepTool = Join-Path -Path $WorkingFolder_Root -ChildPath "ContentPrepTool"
$Global:WorkingFolder_Logs = Join-Path -Path $WorkingFolder_Root -ChildPath "Logs"
$Global:WorkingFolder_Detail = Join-Path -Path $WorkingFolder_Root -ChildPath "Details"
$Global:WorkingFolder_Win32Apps = Join-Path -Path $WorkingFolder_Root -ChildPath "Win32Apps"

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter()]
        [Switch]$TimeStamp,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String]$Message,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String]$Log
    )
    <#
    Function to write log information
    #>

    $Output = (Get-Date -f g) + ": " + $Message
    $Output | Out-File -Encoding Ascii -Append (Join-Path -Path $WorkingFolder_Logs -ChildPath $Log)

}

Function Get-ScriptEnd {
    <#
    Function to end the Win32 App Migration Tool
    #>

    Set-Location $ScriptRoot
    Write-Host ''
    Write-Log -Message "## The Win32AppMigrationTool Script has Finished ##" -Log "Main.log" 
    Write-Host '## The Win32AppMigrationTool Script has Finished ##'
}
Function New-IntuneWin {
    Param (
        [String]$ContentFolder,
        [String]$OutputFolder,
        [String]$SetupFile
    )
    <#
    Function to create new Intunewin
    #>
    Write-Log -Message "Function: New-IntuneWin was called" -Log "Main.log" 

    #Search the Install Command line for other the installer type
    If ($SetupFile -match "powershell" -and $SetupFile -match "\.ps1") {
        Write-Log -Message "Powershell script detected" -Log "Main.log" 
        Write-Host "Powershell script detected" -ForegroundColor Yellow
        Write-Host ''
        $Right = ($SetupFile -split ".ps1")[0]
        $Right = ($Right -Split " ")[-1]
        $Right = $Right.TrimStart("\", ".", "`"")
        $Command = $Right + ".ps1"
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
        $Right = $Right.TrimStart("\", ".", "`"")
        $Command = $Right + $Installer
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
        $Right = $Right.TrimStart("\", ".", "`"")
        $Command = $Right + $Installer
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
        $Right = $Right.TrimStart("\", ".", "`"")
        $Command = $Right + $Installer
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
        $Right = $Right.TrimStart("\", ".", "`"")
        $Command = $Right + $Installer
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
        $Right = $Right.TrimStart("\", ".", "`"")
        $Command = $Right + $Installer
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
                $Command
                "-c"
                $ContentFolder
                "-o"
                $OutputFolder
                "-q"
            )
            Write-Log -Message "Start-Process -FilePath (Join-Path -Path $($WorkingFolder_ContentPrepTool) -ChildPath ""IntuneWinAppUtil.exe"") -ArgumentList $($Arguments) -Wait" -Log "Main.log" 
            Start-Process -FilePath (Join-Path -Path $WorkingFolder_ContentPrepTool -ChildPath "IntuneWinAppUtil.exe") -ArgumentList $Arguments -Wait
            Write-Log -Message "Function Return: $($Right)" -Log "Main.log"
            Return $Right
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
Function Get-ContentFiles {
    Param (
        [String]$Source,
        [String]$Destination
    )
    <#
    Function to download Deployment Type Content from Content Source Folder
    #>
    Write-Log -Message "Function: Get-ContentFiles was called" -Log "Main.log" 
    Write-Log -Message "Padding $($Source) in case content path has spaces. Robocopy demand space at end of Source String" -Log "Main.log" 
    $SourcePadded = "`"" + $Source + " `""
    Write-Log -Message "Padding $($Destination) in case content path has spaces. Robocopy demand space at end of Destination String" -Log "Main.log" 
    $DestinationPadded = "`"" + $Destination + " `""

    Try {
        Write-Log -Message "`$Log = Join-Path -Path $($WorkingFolder_Logs) -ChildPath ""Main.Log""" -Log "Main.log" 
        $Log = Join-Path -Path $WorkingFolder_Logs -ChildPath "Main.Log"
        Write-Log -Message "Robocopy.exe $($SourcePadded) $($DestinationPadded) /MIR /E /Z /R:5 /W:1 /NDL /NJH /NJS /NC /NS /NP /V /TEE  /UNILOG+:$($Log)" -Log "Main.log" 
        $Robo = Robocopy.exe $SourcePadded $DestinationPadded /MIR /E /Z /R:5 /W:1 /NDL /NJH /NJS /NC /NS /NP /V /TEE /UNILOG+:$Log
        $Robo

        If ((Get-ChildItem -Path $Destination | Measure-Object).Count -eq 0 ) {
            Write-Log -Message "Error: Could not transfer content from ""$($Source)"" to ""$($Destination)""" -Log "Main.log" 
            Write-Host "Error: Could not transfer content from ""$($Source)"" to ""$($Destination)""" -ForegroundColor Red
        }
    }
    Catch {
        Write-Log -Message "Error: Could not transfer content from ""$($Source)"" to ""$($Destination)""" -Log "Main.log" 
        Write-Host "Error: Could not transfer content from ""$($Source)"" to ""$($Destination)""" -ForegroundColor Red
    }
}

Function Connect-SiteServer {
    Param (
        [String]$SiteCode,
        [String]$ProviderMachineName
    )
    <#
    Function to connect to ConfigMgr
    #>
    Write-Log -Message "Function: Connect-SiteServer was called" -Log "Main.log" 

    # Import the ConfigurationManager.psd1 module 
    Try {
        If ($Null -eq (Get-Module ConfigurationManager)) {
            Write-Log -Message "Import-Module $($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" -Log "Main.log"
            Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1"
        }
    }
    Catch {
        Write-Log -Message "Warning: Could not import the ConfigurationManager.psd1 Module" -Log "Main.log"
        Write-Host 'Warning: Could not import the ConfigurationManager.psd1 Module' -ForegroundColor Red
    }

    # Connect to the site's drive if it is not already present
    Try {
        if ($Null -eq (Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue)) {
            Write-Log -Message "New-PSDrive -Name $($SiteCode) -PSProvider CMSite -Root $($ProviderMachineName)" -Log "Main.log"
            New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName
        }
        #Set the current location to be the site code.
        Write-Log -Message "Set-Location $($SiteCode):\" -Log "Main.log"
        Set-Location "$($SiteCode):\"
        Write-Log -Message "Connected to provider $($ProviderMachineName) at site $($SiteCode)" -Log "Main.log" 
        Write-Host "Connected to provider ""$($ProviderMachineName)"" at site ""$($SiteCode)""" -ForegroundColor Green
    }
    Catch {
        Write-Log -Message "Warning: Could not connect to the specified provider $($ProviderMachineName) at site $($SiteCode)" -Log "Main.log"
        Write-Host "Warning: Could not connect to the specified provider ""$($ProviderMachineName)"" at site ""$($SiteCode)""" -ForegroundColor Red
    }
    
}

Function New-FolderToCreate {
    Param(
        [String]$Root,
        [String[]]$Folders
    )
    <#
    Function to create folder structure for Win32AppMigrationTool
    #>  

    Write-Log -Message "Function: New-FolderToCreate was called" -Log "Main.log" 
    
    If (!($Root)) {
        Write-Log -Message "Error: No Root Folder passed to Function" -Log "Main.log"
        Write-Host "Error: No Root Folder passed to Function" -ForegroundColor Red
    }
    If (!($Folders)) {
        Write-Log -Message "Error: No Folder(s) passed to Function" -Log "Main.log"
        Write-Host "Error: No Folder(s) passed to Function" -ForegroundColor Red
    }

    ForEach ($Folder in $Folders) {
        #Create Folders
        Write-Log -Message "`$FolderToCreate = Join-Path -Path $($Root) -ChildPath $($Folder)" -Log "Main.log"
        $FolderToCreate = Join-Path -Path $Root -ChildPath $Folder
        If (!(Test-Path $FolderToCreate)) {
            Write-Host "Creating Folder ""$($FolderToCreate)""..." -ForegroundColor Cyan
            Try {
                New-Item -Path $FolderToCreate -ItemType Directory -Force -ErrorAction Stop | Out-Null
                Write-Log -Message "Folder ""$($FolderToCreate)"" created succesfully" -Log "Main.log"
                Write-Host "Folder ""$($FolderToCreate)"" created succesfully"
            }
            Catch {
                Write-Log -Message "Warning: Couldn't create ""$($FolderToCreate)"" folder" -Log "Main.log"
                Write-Host "Warning: Couldn't create ""$($FolderToCreate)"" folder" -ForegroundColor Red
            }
        }
        else {
            Write-Log -Message "Information: Folder ""$($FolderToCreate)"" already exsts. Skipping folder creation" -Log "Main.log"
            Write-Host "Information: Folder ""$($FolderToCreate)"" already exsts. Skipping folder creation" -ForegroundColor Magenta
        }
    }
}  

Function Export-Logo {

    Param (
        [String]$IconId,
        [String]$AppName
    )
    <#
    Function to decode and export Base64 image for application logo to an output folder
    #>

    Write-Log -Message "Function: Export-Logo was called" -Log "Main.log" 
    Write-Host "Preparing to export Application Logo for ""$($AppName)"""
    If ($IconId) {

        #Check destination folder exists for logo
        If (!(Test-Path $WorkingFolder_Logos)) {
            Try {
                Write-Log -Message "New-Item -Path $($WorkingFolder_Logos) -ItemType Directory -Force -ErrorAction Stop | Out-Null" -Log "Main.log"
                New-Item -Path $WorkingFolder_Logos -ItemType Directory -Force -ErrorAction Stop | Out-Null
            }
            Catch {
                Write-Log -Message "Warning: Couldn't create ""$($WorkingFolder_Logos)"" folder for Application Logos" -Log "Main.log"
                Write-Host "Warning: Couldn't create ""$($WorkingFolder_Logos)"" folder for Application Logos" -ForegroundColor Red
            }
        }

        #Continue if Logofolder exists
        If (Test-Path $WorkingFolder_Logos) {
            Write-Log -Message "`$LogoFolder_Id = (Join-Path -Path $($WorkingFolder_Logos) -ChildPath $($IconId))" -Log "Main.log"
            $LogoFolder_Id = (Join-Path -Path $WorkingFolder_Logos -ChildPath $IconId)
            Write-Log -Message "`$Logo_File = (Join-Path -Path $($LogoFolder_Id) -ChildPath Logo.jpg)" -Log "Main.log"
            $Logo_File = (Join-Path -Path $LogoFolder_Id -ChildPath Logo.jpg)

            #Continue if logo does not already exist in destination folder
            If (!(Test-Path $Logo_File)) {

                If (!(Test-Path $LogoFolder_Id)) {
                    Try {
                        Write-Log -Message "New-Item -Path $($LogoFolder_Id) -ItemType Directory -Force -ErrorAction Stop | Out-Null" -Log "Main.log" 
                        New-Item -Path $LogoFolder_Id -ItemType Directory -Force -ErrorAction Stop | Out-Null
                    }
                    Catch {
                        Write-Log -Message "Warning: Couldn't create ""$($LogoFolder_Id)"" folder for Application Logo" -Log "Main.log" 
                        Write-Host "Warning: Couldn't create ""$($LogoFolder_Id)"" folder for Application Logo" -ForegroundColor Red
                    }
                }

                #Continue if Logofolder\<IconId> exists
                If (Test-Path $LogoFolder_Id) {
                    Try {
                        #Grab the SDMPackgeXML which contains the Application and Deployment Type details
                        Write-Log -Message "`$XMLPackage = Get-CMApplication -Name ""$($AppName)"" | Where-Object { `$Null -ne `$_.SDMPackageXML } | Select-Object -ExpandProperty SDMPackageXML" -Log "Main.log" 
                        $XMLPackage = Get-CMApplication -Name $AppName | Where-Object { $Null -ne $_.SDMPackageXML } | Select-Object -ExpandProperty SDMPackageXML

                        #Deserialize SDMPackageXML
                        $XMLContent = [xml]($XMLPackage)

                        $Raw = $XMLContent.AppMgmtDigest.Resources.icon.Data
                        $Logo = [Convert]::FromBase64String($Raw)
                        [System.IO.File]::WriteAllBytes($Logo_File, $Logo)
                        If (Test-Path $Logo_File) {
                            Write-Log -Message "Success: Application logo for ""$($AppName)"" exported successfully to ""$($Logo_File)""" -Log "Main.log" 
                            Write-Host "Success: Application logo for ""$($AppName)"" exported successfully to ""$($Logo_File)""" -ForegroundColor Green
                        }
                    }
                    Catch {
                        Write-Log -Message "Warning: Could not export Logo to folder ""$($LogoFolder_Id)""" -Log "Main.log" 
                        Write-Host "Warning: Could not export Logo to folder ""$($LogoFolder_Id)""" -ForegroundColor Red
                    }
                }
            }
            else {
                Write-Log -Message "Information: Did not export Logo for ""$($AppName)"" to ""$($Logo_File)"" because the file already exists" -Log "Main.log"
                Write-Host "Information: Did not export Logo for ""$($AppName)"" to ""$($Logo_File)"" because the file already exists" -ForegroundColor Magenta
            }
        }
    }
    else {
        Write-Log -Message "Warning: Null or invalid IconId passed to function. Could not export Logo" -Log "Main.log" 
        Write-Host "Warning: Null or invalid IconId passed to function. Could not export Logo" -ForegroundColor Red
    }
}

Function Get-FileFromInternet {
    Param (
        [String]$URI,
        [String]$Destination
    )
    <#
    Function to download and extract ContentPrep Tool
    #>

    Write-Log -Message "Function: Get-FileFromInternet was called" -Log "Main.log" 

    $File = $URI -replace '.*/'
    $FileDestination = Join-Path -Path $Destination -ChildPath $File
    Try {
        Invoke-WebRequest -UseBasicParsing -Uri $URI -OutFile $FileDestination -ErrorAction Stop
    }
    Catch {
        Write-Host "Warning: Error downloading the Win32 Content Prep Tool" -ForegroundColor Red
        $_
    }
}
Function Get-AppInfo {
    Param (
        [String[]]$ApplicationName
    )
 
    <#
    Function to get deployment type(s) for applcation(s) passed
    #>
    Write-Log -Message "Function: Get-AppInfo was called" -Log "Main.log" 

    #Create Array to display Application and Deployment Type Information
    $DeploymentTypes = @()
    $ApplicationTypes = @()
    $Content = @()

    #Iterate through each Application and get details
    ForEach ($Application in $ApplicationName) {

        #Grab the SDMPackgeXML which contains the Application and Deployment Type details
        Write-Log -Message "`$XMLPackage = Get-CMApplication -Name ""$($Application)"" | Where-Object { `$Null -ne `$_.SDMPackageXML } | Select-Object -ExpandProperty SDMPackageXML" -Log "Main.log" 
        $XMLPackage = Get-CMApplication -Name $Application | Where-Object { $Null -ne $_.SDMPackageXML } | Select-Object -ExpandProperty SDMPackageXML
        
        #Prepare XML from SDMPackageXML
        $XMLContent = [xml]($XMLPackage)

        #Get total number of Deployment Types for the Application
        Write-Log -Message "`$TotalDeploymentTypes = ($($XMLContent).AppMgmtDigest.Application.DeploymentTypes.DeploymentType | Measure-Object | Select-Object -ExpandProperty Count)" -Log "Main.log"
        $TotalDeploymentTypes = ($XMLContent.AppMgmtDigest.Application.DeploymentTypes.DeploymentType | Measure-Object | Select-Object -ExpandProperty Count)
        
        If (!($Null -eq $TotalDeploymentTypes) -or (!($TotalDeploymentTypes -eq 0))) {

            $ApplicationObject = New-Object PSCustomObject
            Write-Log -Message "ApplicationObject():" -Log "Main.log"
                
            #Application Details
            Write-Log -Message "Application_LogicalName -Value $XMLContent.AppMgmtDigest.Application.LogicalName" -Log "Main.log"
            $ApplicationObject | Add-Member NoteProperty -Name Application_LogicalName -Value $XMLContent.AppMgmtDigest.Application.LogicalName
            Write-Log -Message "Application_Name -Value $($XMLContent.AppMgmtDigest.Application.DisplayInfo.Info.Title)" -Log "Main.log"
            $ApplicationObject | Add-Member NoteProperty -Name Application_Name -Value $XMLContent.AppMgmtDigest.Application.DisplayInfo.Info.Title
            Write-Log -Message "Application_Description -Value $($XMLContent.AppMgmtDigest.Application.DisplayInfo.Info.Description)" -Log "Main.log"
            $ApplicationObject | Add-Member NoteProperty -Name Application_Description -Value $XMLContent.AppMgmtDigest.Application.DisplayInfo.Info.Description
            Write-Log -Message "Application_Publisher -Value $($XMLContent.AppMgmtDigest.Application.DisplayInfo.Info.Publisher)" -Log "Main.log"
            $ApplicationObject | Add-Member NoteProperty -Name Application_Publisher -Value $XMLContent.AppMgmtDigest.Application.DisplayInfo.Info.Publisher
            Write-Log -Message "Application_Version -Value $($XMLContent.AppMgmtDigest.Application.DisplayInfo.Info.Version)" -Log "Main.log"
            $ApplicationObject | Add-Member NoteProperty -Name Application_Version -Value $XMLContent.AppMgmtDigest.Application.DisplayInfo.Info.Version
            Write-Log -Message "Application_IconId -Value $($XMLContent.AppMgmtDigest.Application.DisplayInfo.Info.Icon.Id)" -Log "Main.log"
            $ApplicationObject | Add-Member NoteProperty -Name Application_IconId -Value $XMLContent.AppMgmtDigest.Application.DisplayInfo.Info.Icon.Id
            Write-Log -Message "Application_TotalDeploymentTypes -Value $($TotalDeploymentTypes)" -Log "Main.log"
            $ApplicationObject | Add-Member NoteProperty -Name Application_TotalDeploymentTypes -Value $TotalDeploymentTypes
                
            #If we have the logo, add the path
            If (!($Null -eq $XMLContent.AppMgmtDigest.Application.DisplayInfo.Info.Icon.Id)) {
                Try {
                    If (Test-Path -Path (Join-Path -Path $WorkingFolder_Logos -ChildPath (Join-Path -Path $XMLContent.AppMgmtDigest.Application.DisplayInfo.Info.Icon.Id -ChildPath "Logo.jpg"))) {
                        Write-Log -Message "Application_IconPath -Value (Join-Path -Path $($WorkingFolder_Logos) -ChildPath (Join-Path -Path $($XMLContent.AppMgmtDigest.Application.DisplayInfo.Info.Icon.Id) -ChildPath ""Logo.jpg""))" -Log "Main.log"
                        $ApplicationObject | Add-Member NoteProperty -Name Application_IconPath -Value (Join-Path -Path $WorkingFolder_Logos -ChildPath (Join-Path -Path $XMLContent.AppMgmtDigest.Application.DisplayInfo.Info.Icon.Id -ChildPath "Logo.jpg"))
                    }
                    else {
                        Write-Log -Message "Application_IconPath -Value `$Null" -Log "Main.log"
                        $ApplicationObject | Add-Member NoteProperty -Name Application_IconPath -Value $Null
                    }
                }
                Catch {
                    Write-Log -Message "Application_IconPath -Value `$Null" -Log "Main.log"
                    $ApplicationObject | Add-Member NoteProperty -Name Application_IconPath -Value $Null
                }
            }
            else {
                Write-Log -Message "Application_IconPath -Value `$Null" -Log "Main.log"
                $ApplicationObject | Add-Member NoteProperty -Name Application_IconPath -Value $Null  
            }
                
            $ApplicationTypes += $ApplicationObject
        
            #If Deployment Types exist, iterate through each DeploymentType and build deployment detail
            ForEach ($Object in $XMLContent.AppMgmtDigest.DeploymentType) {

                #Create new custom PSObjects to build line detail
                $DeploymentObject = New-Object -TypeName PSCustomObject
                $ContentObject = New-Object -TypeName PSCustomObject
                Write-Log -Message "DeploymentObject():" -Log "Main.log"

                #DeploymentType Details
                Write-Log -Message "Application_LogicalName -Value $($XMLContent.AppMgmtDigest.Application.LogicalName)" -Log "Main.log"
                $DeploymentObject | Add-Member NoteProperty -Name Application_LogicalName -Value $XMLContent.AppMgmtDigest.Application.LogicalName
                Write-Log -Message "DeploymentType_LogicalName -Value $($Object.LogicalName)" -Log "Main.log"
                $DeploymentObject | Add-Member NoteProperty -Name DeploymentType_LogicalName -Value $Object.LogicalName
                Write-Log -Message "DeploymentType_Name -Value $($Object.Title.InnerText)" -Log "Main.log"
                $DeploymentObject | Add-Member NoteProperty -Name DeploymentType_Name -Value $Object.Title.InnerText
                Write-Log -Message "DeploymentType_Technology -Value $($Object.Installer.Technology)" -Log "Main.log"
                $DeploymentObject | Add-Member NoteProperty -Name DeploymentType_Technology -Value $Object.Installer.Technology
                Write-Log -Message "DeploymentType_ExecutionContext -Value $($Object.Installer.ExecutionContext)" -Log "Main.log"
                $DeploymentObject | Add-Member NoteProperty -Name DeploymentType_ExecutionContext -Value $Object.Installer.ExecutionContext
                Write-Log -Message "DeploymentType_InstallContent -Value $($Object.Installer.CustomData.InstallContent.ContentId)" -Log "Main.log"
                $DeploymentObject | Add-Member NoteProperty -Name DeploymentType_InstallContent -Value $Object.Installer.CustomData.InstallContent.ContentId
                Write-Log -Message "DeploymentType_InstallCommandLine -Value $($Object.Installer.CustomData.InstallCommandLine)" -Log "Main.log"
                $DeploymentObject | Add-Member NoteProperty -Name DeploymentType_InstallCommandLine -Value $Object.Installer.CustomData.InstallCommandLine
                Write-Log -Message "DeploymentType_UnInstallSetting -Value $($Object.Installer.CustomData.UnInstallSetting)" -Log "Main.log"
                $DeploymentObject | Add-Member NoteProperty -Name DeploymentType_UnInstallSetting -Value $Object.Installer.CustomData.UnInstallSetting
                Write-Log -Message "DeploymentType_UninstallContent -Value $$($Object.Installer.CustomData.UninstallContent.ContentId)" -Log "Main.log"
                $DeploymentObject | Add-Member NoteProperty -Name DeploymentType_UninstallContent -Value $Object.Installer.CustomData.UninstallContent.ContentId
                Write-Log -Message "DeploymentType_UninstallCommandLine -Value $($Object.Installer.CustomData.UninstallCommandLine)" -Log "Main.log"
                $DeploymentObject | Add-Member NoteProperty -Name DeploymentType_UninstallCommandLine -Value $Object.Installer.CustomData.UninstallCommandLine
                Write-Log -Message "DeploymentType_ExecuteTime -Value $($Object.Installer.CustomData.ExecuteTime)" -Log "Main.log"
                $DeploymentObject | Add-Member NoteProperty -Name DeploymentType_ExecuteTime -Value $Object.Installer.CustomData.ExecuteTime
                Write-Log -Message "DeploymentType_MaxExecuteTime -Value $($Object.Installer.CustomData.MaxExecuteTime)" -Log "Main.log"
                $DeploymentObject | Add-Member NoteProperty -Name DeploymentType_MaxExecuteTime -Value $Object.Installer.CustomData.MaxExecuteTime

                $DeploymentTypes += $DeploymentObject

                #Content Details
                Write-Log -Message "ContentObject():" -Log "Main.log"
                Write-Log -Message "Content_DeploymentType_LogicalName -Value $($Object.LogicalName)" -Log "Main.log"
                $ContentObject | Add-Member NoteProperty -Name Content_DeploymentType_LogicalName -Value $Object.LogicalName
                Write-Log -Message "Content_Location -Value $($Object.Installer.Contents.Content.Location)" -Log "Main.log"
                $ContentObject | Add-Member NoteProperty -Name Content_Location -Value $Object.Installer.Contents.Content.Location

                $Content += $ContentObject                
            }
        }
        else {
            Write-Log -Message "Warning: No DeploymentTypes found for ""$($XMLContent.AppMgmtDigest.Application.LogicalName)""" -Log "Main.log"
            Write-Host "Warning: No DeploymentTypes found for ""$($XMLContent.AppMgmtDigest.Application.LogicalName)"" " -ForegroundColor Yellow
        }
    } 
    Return $DeploymentTypes, $ApplicationTypes, $Content
}

#Clear Logs if -ResetLog Parameter was passed
If ($ResetLog) {
    Write-Log -Message "The -ResetLog Parameter was passed to the script" -Log "Main.log"
    Try {
        Write-Log -Message "Get-ChildItem -Path $($WorkingFolder_Logs) | Remove-Item -Force" -Log "Main.log"
        Get-ChildItem -Path $WorkingFolder_Logs | Remove-Item -Force
    }
    Catch {
        Write-Log -Message "Error: Unable to delete log files at $($WorkingFolder_Logs). Do you have it open?" -Log "Main.log"
        Write-Host "Error: Unable to delete log files at $($WorkingFolder_Logs). Do you have it open?" -ForegroundColor Red
    }
}

Write-Log -Message "--------------------------------------------" -Log "Main.log"
Write-Log -Message "Script Start Win32AppMigrationTool" -Log "Main.log"
Write-Log -Message "--------------------------------------------" -Log "Main.log"
Write-Host '--------------------------------------------' -ForegroundColor DarkGray
Write-Host 'Script Start Win32AppMigrationTool' -ForegroundColor DarkGray
Write-Host '--------------------------------------------' -ForegroundColor DarkGray
Write-Host ''

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
Write-Log -Message "ScriptRoot = $($ScriptRoot)" -Log "Main.log" 

#Connect to Site Server
Write-Host 'Connecting to Site Server...' -ForegroundColor Cyan
Write-Log -Message "Connect-SiteServer -SiteCode $($SiteCode) -ProviderMachineName $($ProviderMachineName)" -Log "Main.log" 
Connect-SiteServer -SiteCode  $SiteCode -ProviderMachineName $ProviderMachineName

#Region Check_Folders
Write-Log -Message "--------------------------------------------" -Log "Main.log"
Write-Log -Message "Checking Win32AppMigrationTool Folder Structure..." -Log "Main.log"
Write-Log -Message "--------------------------------------------" -Log "Main.log"
Write-Host ''
Write-Host '--------------------------------------------' -ForegroundColor DarkGray
Write-Host 'Checking Win32AppMigrationTool Folder Structure...' -ForegroundColor DarkGray
Write-Host '--------------------------------------------' -ForegroundColor DarkGray
Write-Host ''

#Create Folders
Write-Host "Creating Folders..."-ForegroundColor Cyan
Write-Log -Message "New-FolderToCreate -Root ""$($WorkingFolder_Root)"" -Folders @("""", ""Logos"", ""Content"", ""ContentPrepTool"", ""Logs"", ""Details"", ""Win32Apps"")" -Log "Main.log" 
New-FolderToCreate -Root $WorkingFolder_Root -Folders @("", "Logos", "Content", "ContentPrepTool", "Logs", "Details", "Win32Apps")
#EndRegion Check_Folders

#Region Get_Content_Tool
Write-Log -Message "--------------------------------------------" -Log "Main.log"
Write-Log -Message "Checking Win32AppMigrationTool Content Tool..." -Log "Main.log"
Write-Log -Message "--------------------------------------------" -Log "Main.log"
Write-Host ''
Write-Host '--------------------------------------------' -ForegroundColor DarkGray
Write-Host 'Checking Win32AppMigrationTool Content Tool...' -ForegroundColor DarkGray
Write-Host '--------------------------------------------' -ForegroundColor DarkGray
Write-Host ''

#Download Win32 Content Prep Tool
If ($PackageApps) {
    Write-Host "Downloadling Win32 Content Prep Tool..." -ForegroundColor Cyan
    If (Test-Path (Join-Path -Path $WorkingFolder_ContentPrepTool -ChildPath "IntuneWinAppUtil.exe")) {
        Write-Log -Message "Information: IntuneWinAppUtil.exe already exists at ""$($WorkingFolder_ContentPrepTool)"". Skipping download" -Log "Main.log" 
        Write-Host "Information: IntuneWinAppUtil.exe already exists at ""$($WorkingFolder_ContentPrepTool)"". Skipping download" -ForegroundColor Magenta
    }
    else {
        Write-Log -Message "Get-FileFromInternet -URI ""https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/raw/master/IntuneWinAppUtil.exe"" -Destination $($WorkingFolder_ContentPrepTool)" -Log "Main.log" 
        Get-FileFromInternet -URI "https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/raw/master/IntuneWinAppUtil.exe" -Destination $WorkingFolder_ContentPrepTool
    }
} 
else {
    Write-Log -Message "The -PackageApps parameter was not passed. Skipping downloading of the Win32 Content Prep Tool." -Log "Main.log" 
    Write-Host "The -PackageApps parameter was not passed. Skipping downloading of the Win32 Content Prep Tool." -ForegroundColor Magenta
}
#EndRegion Get_Content_Tool


#Region Display_Application_Results
Write-Log -Message "--------------------------------------------" -Log "Main.log"
Write-Log -Message "Checking Applications..." -Log "Main.log"
Write-Log -Message "--------------------------------------------" -Log "Main.log"
Write-Host ''
Write-Host '--------------------------------------------' -ForegroundColor DarkGray
Write-Host 'Checking Applications...' -ForegroundColor DarkGray
Write-Host '--------------------------------------------' -ForegroundColor DarkGray
Write-Host ''

#Get list of Applications
Write-Log -Message "Get-CMApplication -Fast | Where-Object { $($_.LocalizedDisplayName) -like $($AppName) } | Select-Object -ExpandProperty LocalizedDisplayName | Sort-Object | Out-GridView -PassThru -OutVariable $($ApplicationName) -Title ""Select an Application(s) to process the associated Deployment Types""" -Log "Main.log" 
$ApplicationName = Get-CMApplication -Fast | Where-Object { $_.LocalizedDisplayName -like "$AppName" } | Select-Object -ExpandProperty LocalizedDisplayName | Sort-Object | Out-GridView -Passthru -Title "Select an Application(s) to process the associated Deployment Types"

If ($ApplicationName) {
    Write-Log -Message "The Win32App Migration Tool will process the following Applications:" -Log "Main.log"
    Write-Host "The Win32App Migration Tool will process the following Applications:"
    ForEach ($Application in $ApplicationName) {
        Write-Log -Message "$($Application)" -Log "Main.log"
        Write-Host """$($Application)""" -ForegroundColor Green
    }
}
else {
    Write-Log -Message "AppName ""$($AppName)"" could not be found." -Log "Main.log"
    Write-Host "AppName ""$($AppName)"" could not be found. Please re-run the tool and try again. The AppName parameter does accept wildcards i.e. *" -ForegroundColor Red
    Get-ScriptEnd
    Exit 1
}
#EndRegion Display_Application_Results

#Region Export_Details_CSV
Write-Log -Message "Calling function to grab deployment type detail for application(s)" -Log "Main.log" 
#Calling function to grab deployment type detail for application(s)
Write-Log -Message "`$App_Array = Get-AppInfo -ApplicationName ""$($ApplicationName)""" -Log "Main.log"
$App_Array = Get-AppInfo -ApplicationName $ApplicationName
$DeploymentTypes_Array = $App_Array[0]
$Applications_Array = $App_Array[1]
$Content_Array = $App_Array[2]

#Export $DeploymentTypes to CSV for reference
Try {
    $DeploymentTypes_Array | Export-Csv (Join-Path -Path $WorkingFolder_Detail -ChildPath "DeploymentTypes.csv") -NoTypeInformation -Force
    Write-Log -Message "`$DeploymentTypes_Array is located at $($WorkingFolder_Detail)\DeploymentTypes.csv" -Log "Main.log" 
}
Catch {
    Write-Host "Error: Could not Export DeploymentTypes.csv. Do you have it open?" -ForegroundColor Red
    Write-Log -Message "Error: Could not Export DeploymentTypes.csv. Do you have it open?" -Log "Main.log" 
}
Try {
    $Applications_Array | Export-Csv (Join-Path -Path $WorkingFolder_Detail -ChildPath "Applications.csv") -NoTypeInformation -Force
    Write-Log -Message "`$Applications_Array is located at $($WorkingFolder_Detail)\Applications.csv" -Log "Main.log" 
}
Catch {
    Write-Host "Error: Could not Export Applications.csv. Do you have it open?" -ForegroundColor Red
    Write-Log -Message "Error: Could not Export Applications.csv. Do you have it open?" -Log "Main.log" 
}
Try {
    $Content_Array | Export-Csv (Join-Path -Path $WorkingFolder_Detail -ChildPath "Content.csv") -NoTypeInformation -Force
    Write-Log -Message "`$Content_Array is located at $($WorkingFolder_Detail)\Content.csv" -Log "Main.log" 
}
Catch {
    Write-Host "Error: Could not Export Content.csv. Do you have it open?" -ForegroundColor Red
    Write-Log -Message "Error: Could not Export Content.csv. Do you have it open?" -Log "Main.log" 
}
Write-Host "Details of the selected Applications and Deployment Types can be found at ""$($WorkingFolder_Detail)"""
#EndRegion Export_Details_CSV

#Region Exporting_Logos
If ($ExportLogo) {

    #Call function to export logo for application
    Write-Log -Message "--------------------------------------------" -Log "Main.log"
    Write-Log -Message "Exporting Logo(s)..." -Log "Main.log"
    Write-Log -Message "--------------------------------------------" -Log "Main.log"
    Write-Host ''
    Write-Host '--------------------------------------------' -ForegroundColor DarkGray
    Write-Host 'Exporting Logo(s)...' -ForegroundColor DarkGray
    Write-Host '--------------------------------------------' -ForegroundColor DarkGray
    Write-Host ''

    ForEach ($Application in $Applications_Array) {
        Write-Log -Message "`$IconId = $($Application.Application_IconId)" -Log "Main.log"
        $IconId = $Application.Application_IconId
        Write-Log -Message "Export-Logo -IconId $($IconId) -AppName $($Application.Application_Name)" -Log "Main.log"
        Export-Logo -IconId $IconId -AppName $Application.Application_Name
    }
}
#EndRegion Exporting_Logos

#Region Package_Apps
#If the $PackageApps parameter was passed. Use the Win32Content Prep Tool to build Intune.win files
If ($PackageApps) {
    #Region Creating_Application_Folders
    Write-Log -Message "`$PackageApps Parameter passed" -Log "Main.log"
    Write-Log -Message "--------------------------------------------" -Log "Main.log"
    Write-Log -Message "Creating Application Folder(s)" -Log "Main.log"
    Write-Log -Message "--------------------------------------------" -Log "Main.log"
    Write-Host ''
    Write-Host '--------------------------------------------' -ForegroundColor DarkGray
    Write-Host 'Creating Application Folder(s)' -ForegroundColor DarkGray
    Write-Host '--------------------------------------------' -ForegroundColor DarkGray
    Write-Host ''

    ForEach ($Application in $Applications_Array) {

        #Create Application Parent Folder(s)
        Write-Log -Message "Application: $($Application.Application_Name)" -Log "Main.log"
        Write-Host "Application: ""$($Application.Application_Name)"""
        Write-Log -Message "Creating Application Folder $($Application.Application_LogicalName) for Application $($Application.Application_Name)" -Log "Main.log"
        Write-Host "Creating Application Folder ""$($Application.Application_LogicalName)"" for Application ""$($Application.Application_Name)""" -ForegroundColor Cyan
        If (!(Test-Path -Path (Join-Path -Path $WorkingFolder_Win32Apps -ChildPath $Application.Application_LogicalName ))) {
            Write-Log -Message "New-FolderToCreate -Root $($WorkingFolder_Win32Apps) -Folders $($Application.Application_LogicalName)" -Log "Main.log"
            New-FolderToCreate -Root $WorkingFolder_Win32Apps -Folders $Application.Application_LogicalName
        }
        else {
            Write-Log -Message "Information: Application Folder $($Application.Application_LogicalName) already exists" -Log "Main.log"
            Write-Host "Information: Application Folder ""$($Application.Application_LogicalName)"" already exists" -ForegroundColor Magenta
        }
        Write-Host ''
    }
    #EndRegion Creating_Application_Folders

    #Region Creating_DeploymentType_Folders
    Write-Log -Message "--------------------------------------------" -Log "Main.log"
    Write-Log -Message "Creating DeploymentType Folder(s)" -Log "Main.log"
    Write-Log -Message "--------------------------------------------" -Log "Main.log"
    Write-Host ''
    Write-Host '--------------------------------------------' -ForegroundColor DarkGray
    Write-Host 'Creating DeploymentType Folder(s)' -ForegroundColor DarkGray
    Write-Host '--------------------------------------------' -ForegroundColor DarkGray
    Write-Host ''
    ForEach ($DeploymentType in $DeploymentTypes_Array) {

        #Create DeploymentType Child Folder(s)
        Write-Log -Message "Creating DeploymentType Folder $($DeploymentType.DeploymentType_LogicalName) for DeploymentType $($DeploymentType.DeploymentType_Name)" -Log "Main.log"
        Write-Host "Creating DeploymentType Folder ""$($DeploymentType.DeploymentType_LogicalName)"" for DeploymentType ""$($DeploymentType.DeploymentType_Name)""" -ForegroundColor Cyan
        If (!(Test-Path -Path (Join-Path -Path (Join-Path -Path $WorkingFolder_Win32Apps -ChildPath $DeploymentType.Application_LogicalName ) -ChildPath $DeploymentType.DeploymentType_LogicalName))) {
            Write-Log -Message "New-FolderToCreate -Root $($WorkingFolder_Win32Apps) -Folders (Join-Path -Path $($DeploymentType.Application_LogicalName) -ChildPath $($DeploymentType.DeploymentType_LogicalName))" -Log "Main.log"
            New-FolderToCreate -Root $WorkingFolder_Win32Apps -Folders (Join-Path -Path $DeploymentType.Application_LogicalName -ChildPath $DeploymentType.DeploymentType_LogicalName)
        }
        else {
            Write-Log -Message "Information: Folder ""$($WorkingFolder_Win32Apps)\$($DeploymentType.DeploymentType_LogicalName)\$($DeploymentType.DeploymentType_LogicalName)"" already exists" -Log "Main.log"
            Write-Host "Information: Folder ""$($WorkingFolder_Win32Apps)\$($DeploymentType.DeploymentType_LogicalName)\$($DeploymentType.DeploymentType_LogicalName)"" already exists" -ForegroundColor Magenta
        }
        Write-Host ''
    }
    #EndRegion Creating_DeploymentType_Folders

    #Region Creating_Content_Folders
    Write-Log -Message "--------------------------------------------" -Log "Main.log"
    Write-Log -Message "Creating Content Folder(s)" -Log "Main.log"
    Write-Log -Message "--------------------------------------------" -Log "Main.log"
    Write-Host ''
    Write-Host '--------------------------------------------' -ForegroundColor DarkGray
    Write-Host 'Creating Content Folder(s)' -ForegroundColor DarkGray
    Write-Host '--------------------------------------------' -ForegroundColor DarkGray
    Write-Host ''
    ForEach ($DeploymentType in $DeploymentTypes_Array) {

        #Create DeploymentType Content Folder(s)
        Write-Log -Message "Creating DeploymentType Content Folder for DeploymentType $($DeploymentType.DeploymentType_Name)" -Log "Main.log"
        Write-Host "Creating DeploymentType Content Folder for DeploymentType ""$($DeploymentType.DeploymentType_Name)""" -ForegroundColor Cyan
        If (!(Test-Path -Path (Join-Path -Path $WorkingFolder_Content -ChildPath $DeploymentType.Application_LogicalName))) {
            Write-Log -Message "New-FolderToCreate -Root $($WorkingFolder_Content) -Folders $($DeploymentType.DeploymentType_LogicalName)" -Log "Main.log"
            New-FolderToCreate -Root $WorkingFolder_Content -Folders $DeploymentType.DeploymentType_LogicalName
        }
        else {
            Write-Log -Message "Information: Folder ""$($WorkingFolder_Content)\$($DeploymentType.DeploymentType_LogicalName)"" Content already exists" -Log "Main.log"
            Write-Host "Information: Folder ""$($WorkingFolder_Content)\$($DeploymentType.DeploymentType_LogicalName)"" Content already exists" -ForegroundColor Magenta
        }
        Write-Host ''
    }
    #EndRegion Creating_Content_Folders

    #Region Downloading_Content
    Write-Log -Message "--------------------------------------------" -Log "Main.log"
    Write-Log -Message "Downloading Content" -Log "Main.log"
    Write-Log -Message "--------------------------------------------" -Log "Main.log"
    Write-Host '--------------------------------------------' -ForegroundColor DarkGray
    Write-Host 'Downloading Content' -ForegroundColor DarkGray
    Write-Host '--------------------------------------------' -ForegroundColor DarkGray
    Write-Host ''

    ForEach ($Content in $Content_Array) {
        Write-Log -Message "Downloading Content for Deployment Type $($Content.Content_DeploymentType_LogicalName) from Content Source $($Content.Content_Location)..." -Log "Main.log"
        Write-Host "Downloading Content for Deployment Type ""$($Content.Content_DeploymentType_LogicalName)"" from Content Source ""$($Content.Content_Location)""..." -ForegroundColor Cyan
        Write-Log -Message "Get-ContentFiles -Source $($Content.Content_Location) -Destination (Join-Path -Path $($WorkingFolder_Content) -ChildPath $($Content.Content_DeploymentType_LogicalName))" -Log "Main.log" 
        Get-ContentFiles -Source $Content.Content_Location -Destination (Join-Path -Path $WorkingFolder_Content -ChildPath $Content.Content_DeploymentType_LogicalName)
    }
    #EndRegion Downloading_Content

    #Region Create_Intunewin_Files
    Write-Log -Message "--------------------------------------------" -Log "Main.log" 
    Write-Log -Message "Creating .IntuneWin File(s)" -Log "Main.log"
    Write-Log -Message "--------------------------------------------" -Log "Main.log"
    Write-Host ''
    Write-Host '--------------------------------------------' -ForegroundColor DarkGray
    Write-Host 'Creating .IntuneWin File(s)' -ForegroundColor DarkGray
    Write-Host '--------------------------------------------' -ForegroundColor DarkGray

    #Get Application and Deployment Type Details and Files
    ForEach ($Application in $Applications_Array) {
        Write-Log -Message "--------------------------------------------" -Log "Main.log" 
        Write-Log -Message "$($Application.Application_Name)" -Log "Main.log"
        Write-Log -Message "There are a total of $($Application.Application_TotalDeploymentTypes) Deployment Types for this Application:" -Log "Main.log"
        Write-Log -Message "--------------------------------------------" -Log "Main.log"
        Write-Host ''
        Write-Host '--------------------------------------------' -ForegroundColor DarkGray
        Write-Host """$($Application.Application_Name)""" -ForegroundColor Green
        Write-Host "There are a total of $($Application.Application_TotalDeploymentTypes) Deployment Types for this Application:"
        Write-Host '--------------------------------------------' -ForegroundColor DarkGray
        Write-Host ''

        ForEach ($Deployment in $DeploymentTypes_Array | Where-Object { $_.Application_LogicalName -eq $Application.Application_LogicalName }) {
            
            Write-Log -Message "--------------------------------------------" -Log "Main.log" 
            Write-Log -Message "$($Deployment.DeploymentType_Name)" -Log "Main.log"
            Write-Log -Message "--------------------------------------------" -Log "Main.log"
            Write-Host '--------------------------------------------' -ForegroundColor DarkGray
            Write-Host """$($Deployment.DeploymentType_Name)""" -ForegroundColor Green
            Write-Host '--------------------------------------------' -ForegroundColor DarkGray
            Write-Host ''

            #Grab install command executable or script
            $SetupFile = $Deployment.DeploymentType_InstallCommandLine
            Write-Log -Message "Install Command: ""$($SetupFile)""" -Log "Main.log"
            Write-Host "Install Command: ""$($SetupFile)"""

            ForEach ($Content in $Content_Array | Where-Object { $_.Content_DeploymentType_LogicalName -eq $Deployment.DeploymentType_LogicalName }) {

                #Create variables to pass to Function
                Write-Log -Message "`$ContentFolder = Join-Path -Path $($WorkingFolder_Content) -ChildPath $($Deployment.DeploymentType_LogicalName)" -Log "Main.log"
                $ContentFolder = Join-Path -Path $WorkingFolder_Content -ChildPath $Deployment.DeploymentType_LogicalName
                Write-Log -Message "`$OutputFolder = Join-Path -Path (Join-Path -Path $($WorkingFolder_Win32Apps) -ChildPath $($Application.Application_LogicalName)) -ChildPath $Deployment.DeploymentType_LogicalName" -Log "Main.log"
                $OutputFolder = Join-Path -Path (Join-Path -Path $WorkingFolder_Win32Apps -ChildPath $Application.Application_LogicalName) -ChildPath $Deployment.DeploymentType_LogicalName
                Write-Log -Message "Install Command: ""$($SetupFile)""" -Log "Main.log"
                $SetupFile = $Deployment.DeploymentType_InstallCommandLine

                Write-Log -Message "Content Folder: ""$($ContentFolder)""" -Log "Main.log"
                Write-Host "Content Folder: ""$($ContentFolder)"""
                Write-Log -Message "Intunewin Output Folder: ""$($OutputFolder)""" -Log "Main.log"
                Write-Host "Intunewin Output Folder: ""$($OutputFolder)"""
                Write-Host ''
                Write-Log -Message "Creating .Intunewin for ""$($Deployment.DeploymentType_Name)""..." -Log "Main.log" 
                Write-Host "Creating .Intunewin for ""$($Deployment.DeploymentType_Name)""..." -ForegroundColor Cyan
                Write-Log -Message "`$IntuneWinFileCommand = New-IntuneWin -ContentFolder $($ContentFolder) -OutputFolder $($OutputFolder) -SetupFile $($SetupFile)" -Log "Main.log"
                $IntuneWinFileCommand = New-IntuneWin -ContentFolder $ContentFolder -OutputFolder $OutputFolder -SetupFile $SetupFile
                $IntuneWinFile = $IntuneWinFileCommand
                Write-Host ''
                 
                If (Test-Path (Join-Path -Path $OutputFolder -ChildPath "*.intunewin") ) {
                    Write-Log -Message "Successfully created ""$($IntuneWinFile).intunewin"" at ""$($OutputFolder)""" -Log "Main.log" 
                    Write-Host "Successfully created ""$($IntuneWinFile).intunewin"" at ""$($OutputFolder)""" -ForegroundColor Cyan
                }
                else {
                    Write-Log -Message "Error: We couldn't verify that ""$($IntuneWinFile).intunewin"" was created at ""$($OutputFolder)""" -Log "Main.log" 
                    Write-Host "Error: We couldn't verify that ""$($IntuneWinFile).intunewin"" was created at ""$($OutputFolder)""" -ForegroundColor Red
                }
            }
        }
    }
    #EndRegion Create_Intunewin_Files
}
else {
    Write-Log -Message "The -PackageApps parameter was not passed. Application and Deployment Type information will be gathered only, content will not be downloaded" -Log "Main.log" 
    Write-Host "The -PackageApps parameter was not passed. Application and Deployment Type information will be gathered only, content will not be downloaded" -ForegroundColor Magenta
}
#EndRegion Package_Apps

#Region Create_Apps
#If the $CreateApps parameter was passed. Use the Win32Content Prep Tool to create Win32 Apps
If ($CreateApps) {
    Write-Log -Message "--------------------------------------------" -Log "Main.log" 
    Write-Log -Message "Creating Win32 Apps" -Log "Main.log"
    Write-Log -Message "--------------------------------------------" -Log "Main.log"
    Write-Host ''
    Write-Host '--------------------------------------------' -ForegroundColor DarkGray
    Write-Host 'Creating Win32 Apps' -ForegroundColor DarkGray
    Write-Host '--------------------------------------------' -ForegroundColor DarkGray
    Write-Host ''
    #####----------------------IN DEVELOPMENT----------------------#####
}
#EndRegion Create_Apps
Get-ScriptEnd