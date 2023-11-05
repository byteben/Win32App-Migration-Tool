<#
.Synopsis
Created on:   14/03/2021
Updated on:   12/03/2022
Created by:   Ben Whitmore
Filename:     New-Win32App.ps1

The Win32 App Migration Tool is designed to inventory ConfigMgr Applications and Deployment Types, build .intunewin files and create Win3Apps in The MEM Admin Center.

Instead of manually checking Application and Deployment Type information and gathering content to build Win32apps, the Win32APp Migration Tool is designed to do that for you. To date, the Application and Deployment Type information is gathered and a .Intunewin file is created. We are also collecting the logo for the application.

The Win32App Migration Tool is still in BETA so I would welcome any feedback or suggestions for improvement. Reach out on Twitter to DM @byteben (DM's are open)

.Description
**Version 1.103.12.01 - 12/03/2022 - BETA**  
- Added UTF8 Encoding for CSV Exports https://github.com/byteben/Win32App-Migration-Tool/issues/6
- Added option to exclude PMPC apps https://github.com/byteben/Win32App-Migration-Tool/issues/5
- Added option to exclude specific apps using a filter

**Version 1.08.29.02 - 29/08/2021 - BETA**  
- Fixed an issue where logos were not being exported
- Fixed an issue where the Localized Display Name was not outputed correctly

**Version 1.08.29.01 - 29/08/2021 - BETA**  
- Default to not copy content locally.
- Use -DownloadContent switch to copy content to local working folder
- Fixed an issue when the source content folder has a space in the path

**Version 1.03.27.02 - 27/03/2021 - BETA**  
- Fixed a grammar issue when creating the Working Folders

**Version 1.03.25.01 - 25/03/2021 - BETA**  
- Removed duplicate name in message for successful .intunewin creation
- Added a new switch "-NoOGV" which will suppress the Out-Grid view. Thanks @philschwan
- Fixed an issue where the -ResetLog parameter was not working

**Version 1.03.23.01 - 23/03/2021 - BETA**  
- Error handling improved when connecting to the Site Server and passing a Null app name

**Version 1.03.22.01 - 22/03/2021 - BETA**  
- Updates Manifest to only export New-Win32App Function

**Version 1.03.21.03 - 21/03/2021 - BETA**  
- Fixed RootModule issue in psm1

**Version 1.03.21.03 - 21/03/2021 - BETA**  
- Fixed Function error for New-Win32App

**Version 1.03.21.01 - 21/03/2021 - BETA**  
- Added to PSGallery and converted to Module

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

.PARAMETER LogId
The component (script name) passed as LogID to the 'Write-Log' function.

.PARAMETER AppName
Pass a string to the toll to search for applications in ConfigMgr

.PARAMETER DownloadContent
When passed, the content for the deployment type is saved locally to the working folder "Content"

.PARAMETER SiteCode
Specify the Sitecode you wish to connect to

.PARAMETER ProviderMachineName
Specify the Site Server to connect to

.PARAMETER ExportLogo
When passed, the Application logo is decoded from base64 and saved to the Logos folder

.PARAMETER WorkingFolder
This is the working folder for the Win32AppMigration Tool. Care should be given when specifying the working folder because downloaded content can increase the working folder size considerably. The Following folders are created in this directory:-

-Content
-ContentPrepTool
-Details
-Logos
-Win32Apps

.PARAMETER PackageApps
Pass this parameter to package selected apps in the .intunewin format

.PARAMETER CreateApps
Pass this parameter to create the Win32apps in Intune

.PARAMETER ResetLog
Pass this parameter to reset the log file

.PARAMETER ExcludePMPC
Pass this parameter to exclude apps created by PMPC from the results. Filter is applied to Application "Comments". String can be modified in Get-AppList Function

.PARAMETER ExcludeFilter
Pass this parameter to exclude specific apps from the results. String value that accepts wildcards e.g. "Microsoft*"

.PARAMETER Win32ContentPrepToolUri
URI for Win32 Content Prep Tool

.EXAMPLE
New-Win32App -SiteCode "BB1" -ProviderMachineName "SCCM1.byteben.com" -AppName "Microsoft Edge Chromium *"

.EXAMPLE
New-Win32App -SiteCode "BB1" -ProviderMachineName "SCCM1.byteben.com" -AppName "Microsoft Edge Chromium *" -DownloadContent

.EXAMPLE
New-Win32App -SiteCode "BB1" -ProviderMachineName "SCCM1.byteben.com" -AppName "Microsoft Edge Chromium *" -ExportLogo

.EXAMPLE
New-Win32App -SiteCode "BB1" -ProviderMachineName "SCCM1.byteben.com" -AppName "Microsoft Edge Chromium *" -ExportLogo -PackageApps

.EXAMPLE
New-Win32App -SiteCode "BB1" -ProviderMachineName "SCCM1.byteben.com" -AppName "Microsoft Edge Chromium *" -ExportLogo -PackageApps -CreateApps

.EXAMPLE
New-Win32App -SiteCode "BB1" -ProviderMachineName "SCCM1.byteben.com" -AppName "Microsoft Edge Chromium *" -ExportLogo -PackageApps -CreateApps -ResetLog

.EXAMPLE
New-Win32App -SiteCode "BB1" -ProviderMachineName "SCCM1.byteben.com" -AppName "Microsoft Edge Chromium *" -ExportLogo -PackageApps -CreateApps -ResetLog -ExcludePMPC

.EXAMPLE
New-Win32App -SiteCode "BB1" -ProviderMachineName "SCCM1.byteben.com" -AppName "Microsoft Edge Chromium *" -ExportLogo -PackageApps -CreateApps -ResetLog -ExcludePMPC -ExcludeFilter "Microsoft*"
#>
function New-Win32App {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = "The component (script name) passed as LogID to the 'Write-Log' function")]
        [string]$LogId = $($MyInvocation.MyCommand).Name,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 0, HelpMessage = 'The Site Code of the ConfigMgr Site')]
        [ValidatePattern('(?##The Site Code must be only 3 alphanumeric characters##)^[a-zA-Z0-9]{3}$')]
        [String]$SiteCode,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 1, HelpMessage = 'Server name that has an SMS Provider site system role')]
        [String]$ProviderMachineName,  
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 2, HelpMessage = 'The name of the application to search for. Accepts wildcards *')]
        [String]$AppName,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, HelpMessage = 'DownloadContent: When passed, the content for the deployment type is saved locally to the working folder "Content"')]
        [Switch]$DownloadContent,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, HelpMessage = 'ExportLogo: When passed, the Application logo is decoded from base64 and saved to the Logos folder')]
        [Switch]$ExportLogo,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 3, HelpMessage = 'The working folder for the Win32AppMigration Tool. Care should be given when specifying the working folder because downloaded content can increase the working folder size considerably')]
        [String]$workingFolder = "C:\Win32AppMigrationTool",
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, HelpMessage = 'PackageApps: Pass this parameter to package selected apps in the .intunewin format')]
        [Switch]$PackageApps,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, HelpMessage = 'CreateApps: Pass this parameter to create the Win32apps in Intune')]
        [Switch]$CreateApps,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, HelpMessage = 'ResetLog: Pass this parameter to reset the log file')]
        [Switch]$ResetLog,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, HelpMessage = 'ExcludePMPC: Pass this parameter to exclude apps created by PMPC from the results. Filter is applied to Application "Comments". String can be modified in Get-AppList Function')]
        [Switch]$ExcludePMPC,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 4, HelpMessage = 'ExcludeFilter: Pass this parameter to exclude specific apps from the results. String value that accepts wildcards e.g. "Microsoft*"')]
        [String]$ExcludeFilter,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, HelpMessage = 'NoOGV: When passed, the Out-Gridview is suppressed')]
        [Switch]$NoOgv,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 5, HelpMessage = 'URI for Win32 Content Prep Tool')]
        [String]$Win32ContentPrepToolUri = 'https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/raw/master/IntuneWinAppUtil.exe'
    )

    # Create global variable(s) 
    $global:workingFolder_Root = $workingFolder

    #region Prepare_Workspace
    # Initialize folders to prepare workspace for logging
    Write-Host "Initializing required folders..." -ForegroundColor Cyan

    foreach ($folder in $workingFolder_Root, "$workingFolder_Root\Logs") {
        if (-not (Test-Path -Path $folder)) {
            Write-Log -Message ("Working folder root does not exist at '{0}'. Creating environemnt..." -f $folder) -LogId $LogId
            Write-Host ("Working folder root does not exist at '{0}'. Creating environemnt..." -f $folder) -ForegroundColor Cyan
            New-Item -Path $folder -ItemType Directory -Force -ErrorAction Stop | Out-Null
        }
        else {
            Write-Log -Message ("Folder '{0}' already exists. Skipping folder creation" -f $folder) -LogId $LogId -Severity 2
            Write-Host ("Folder '{0}' already exists. Skipping folder creation" -f $folder) -ForegroundColor Yellow
        }
    }

    # Rest the log file if the -ResetLog parameter is passed
    if ($ResetLog -and (Test-Path -Path "$workingFolder_Root\Logs") ) {
        Write-Log -Message $null -ResetLogFile
    }
    #endregion

    # Begin Script
    New-VerboseRegion -Message 'Start Win32AppMigrationTool' -ForegroundColor 'Gray'

    $ScriptRoot = $PSScriptRoot
    Write-Log -Message ("ScriptRoot is '{0}'" -f $ScriptRoot) -LogId $LogId

    # Connect to Site Server
    Connect-SiteServer -SiteCode  $SiteCode -ProviderMachineName $ProviderMachineName

    # Check the folder structure for the working directory and create if necessary
    New-VerboseRegion -Message 'Checking Win32AppMigrationTool folder structure' -ForegroundColor 'Gray'

    #region Create_Folders
    Write-Host "Creating additionl folders..." -ForegroundColor Cyan
    Write-Log -Message ("New-FolderToCreate -Root '{0}' -FolderNames @('Logos', 'Content', 'ContentPrepTool', 'Details', 'Win32Apps')" -f $workingFolder_Root) -LogId $LogId
    New-FolderToCreate -Root $workingFolder_Root -FolderNames @('Logos', 'Content', 'ContentPrepTool', 'Details', 'Win32Apps')
    #endRegion

    #region Get_Content_Tool
    New-VerboseRegion -Message 'Checking if the Win32contentpreptool is required' -ForegroundColor 'Gray'

    # Download the Win32 Content Prep Tool if the PackageApps parameter is passed
    if ($PackageApps) {
        Write-Host "Downloading the Win32contentpreptool..." -ForegroundColor Cyan
        if (Test-Path (Join-Path -Path "$workingFolder_Root\ContentPrepTool" -ChildPath "IntuneWinAppUtil.exe")) {
            Write-Log -Message ("Information: IntuneWinAppUtil.exe already exists at '{0}'. Skipping download" -f "$workingFolder_Root\ContentPrepTool") -LogId $LogId -Severity 2
            Write-Host ("Information: IntuneWinAppUtil.exe already exists at '{0}'. Skipping download" -f "$workingFolder_Root\ContentPrepTool") -ForegroundColor Yellow
        }
        else {
            Write-Log -Message ("Get-FileFromInternet -URI '{0} -Destination {1}" -f $Win32ContentPrepToolUri, "$workingFolder_Root\ContentPrepTool") -LogId $LogId
            Get-FileFromInternet -Uri $Win32ContentPrepToolUri -Destination "$workingFolder_Root\ContentPrepTool"
        }
    } 
    else {
        Write-Log -Message "The 'PackageApps' parameter was not passed. Skipping downloading of the Win32 Content Prep Tool" -LogId $LogId -Severity 2
        Write-Host "The 'PackageApps' parameter was not passed. Skipping downloading of the Win32 Content Prep Tool" -ForegroundColor Yellow
    }
    #endRegion


    #region Display_Application_Results
    New-VerboseRegion -Message 'Filtering application results' -ForegroundColor 'Gray'

    # Build a hash table of switch parameters to pass to the Get-AppList function
    $paramsToPassApp = @{}
    if ($ExcludePMPC) {
        $paramsToPassApp.Add('ExcludePMPC', $true) 
        Write-Log -Message "The ExcludePMPC parameter was passed. Ignoring all PMPC created applications" -LogId $LogId -Severity 2
        Write-Host "The ExcludePMPC parameter was passed. Ignoring all PMPC created applications" -ForegroundColor Cyan
    }
    if ($ExcludeFilter) {
        $paramsToPassApp.Add('ExcludeFilter', $ExcludeFilter) 
        Write-Log -Message ("The 'ExcludeFilter' parameter was passed. Ignoring applications that match '{0}'" -f $ExcludeFilter) -LogId $LogId -Severity 2
        Write-Host ("The 'ExcludeFilter' parameter was passed. Ignoring applications that match '{0}'" -f $ExcludeFilter) -ForegroundColor Cyan
    }
    if ($NoOGV) {
        $paramsToPassApp.Add('NoOGV', $true) 
        Write-Log -Message "The 'NoOgv' parameter was passed. Suppressing Out-GridView" -LogId $LogId -Severity 2   
        Write-Host "The 'NoOgv' parameter was passed. Suppressing Out-GridView" -ForegroundColor Cyan
    }

    Write-Log -Message ("Running function 'Get-AppList' -AppName '{0}'" -f $AppName) -LogId $LogId
    Write-Host ("Running function 'Get-AppList' -AppName '{0}'" -f $AppName) -ForegroundColor Cyan

    $applicationName = Get-AppList -AppName $AppName @paramsToPassApp
 
    # ApplicationName(s) returned from the Get-AppList function
    if ($applicationName) {
        Write-Log -Message "The Win32App Migration Tool will process the following applications:" -LogId $LogId
        Write-Host "The Win32App Migration Tool will process the following applications:" -ForegroundColor Cyan
        
        foreach ($application in $ApplicationName) {
            Write-Log -Message ("Id = '{0}', Name = '{1}'" -f $application.Id, $application.LocalizedDisplayName) -LogId $LogId
            Write-Host ("Id = '{0}', Name = '{1}'" -f $application.Id, $application.LocalizedDisplayName) -ForegroundColor Green
        }
    }
    else {
        if ($applicationName) { 
            Write-Log -Message ("AppName '{0}' could not be found or no selection was made." -f $AppName) -LogId $LogId -Severity 3
            Write-Warning -Message ("AppName '{0}' could not be found or no selection was made. Please re-run the tool and try again. The AppName parameter does accept wildcards i.e. *" -f $ApplicationName)
        }
        else {
            Write-Log -Message 'The Out-GrideView was closed. Cannot continue' -Log $LogId -Severity 3
            Write-Warning -Message 'The Out-GrideView was closed. Cannot continue. Please re-run the tool and try again. The AppName parameter does accept wildcards i.e. *'
        }
        Get-ScriptEnd
        break
    }
    #endRegion

    #region Get_App_Details
    New-VerboseRegion -Message 'Getting application details' -ForegroundColor 'Gray'

    # Calling function to grab application details
    Write-Log -Message "Calling 'Get-AppInfo' function to grab application details" -LogId $LogId
    Write-Host "Calling 'Get-AppInfo' function to grab application details" -ForegroundColor Cyan

    $app_Array = Get-AppInfo -ApplicationName $applicationName
    #endregion

    #region Get_DeploymentType_Details
    New-VerboseRegion -Message 'Getting deployment type details' -ForegroundColor 'Gray'

    # Calling function to grab deployment types details
    Write-Log -Message "Calling 'Get-DeploymentTypeInfo' function to grab deployment type details" -LogId $LogId
    Write-Host "Calling 'Get-DeploymentTypeInfo' function to grab deployment type details" -ForegroundColor Cyan
    
    $deploymentTypes_Array = foreach ($app in $app_Array) { Get-DeploymentTypeInfo -ApplicationId $app.Id }
    #endregion

    #region Get_DeploymentType_Content
    New-VerboseRegion -Message 'Getting deployment type content' -ForegroundColor 'Gray'

    if ($DownloadContent) {
        Write-Log -Message "The 'DownloadContent' parameter was passed. Will attempt to get content from content source" -LogId $LogId -Severity 2
        Write-Host "The 'DownloadContent' parameter was passed. Will attempt to get content from content source" -ForegroundColor Cyan
    
        # Calling function to grab deployment type content information
        Write-Log -Message "Calling 'Get-ContentFiles' function to grab deployment type content" -LogId $LogId
        Write-Host "Calling 'Get-ContentFiles' function to grab deployment type content" -ForegroundColor Cyan
            
        $content_Array = foreach ($deploymentType in $deploymentTypes_Array) { 
    
            # Build or reset a hash table of switch parameters to pass to the Get-ContentFiles function
            $paramsToPassContent = @{}
    
            if ($deploymentType.InstallContent) { $paramsToPassContent.Add('InstallContent', $deploymentType.InstallContent) }
            if ($deploymentType.UninstallContent) { $paramsToPassContent.Add('UninstallContent', $deploymentType.UninstallContent) }
            $paramsToPassContent.Add('ApplicationId', $deploymentType.Application_Id)
            $paramsToPassContent.Add('ApplicationName', $deploymentType.ApplicationName)
            $paramsToPassContent.Add('DeploymentTypeLogicalName', $deploymentType.LogicalName)
            $paramsToPassContent.Add('DeploymentTypeName', $deploymentType.Name)
    
            # If we have content, call the Get-ContentFiles function
            if ($deploymentType.InstallContent -or $deploymentType.UninstallContent) { Get-ContentFiles @paramsToPassContent }
        }
    } 
    else {
        Write-Log -Message "The 'DownloadContent' parameter was not passed. Will not attempt to get content from content source" -LogId $LogId -Severity 2
        Write-Host "The 'DownloadContent' parameter was not passed. Will not attempt to get content from content source" -ForegroundColor Cyan
    }
    #endregion
    
    #region Exporting_Csv data
    # Export $DeploymentTypes to CSV for reference
    New-VerboseRegion -Message 'Exporting collected data to Csv' -ForegroundColor 'Gray'
    $detailsFolder = (Join-Path -Path $workingFolder_Root -ChildPath 'Details')

    Write-Log -Message ("Destination folder will be '{0}\Details" -f $workingFolder_Root) -LogId $LogId -Severity 2
    Write-Host ("Destination folder will be '{0}\Details" -f $workingFolder_Root) -ForegroundColor Cyan

    # Export application information to CSV for reference
    Export-CsvDetails -Name 'Applications' -Data $app_Array -Path $detailsFolder

    # Export deployment type information to CSV for reference
    Export-CsvDetails -Name 'DeploymentTypes' -Data $deploymentTypes_Array -Path $detailsFolder

    # Export content information to CSV for reference
    Export-CsvDetails -Name 'Content' -Data $content_Array -Path $detailsFolder
    #endRegion

    break

    #Region Exporting_Logos
    If ($ExportLogo) {

        #Call function to export logo for application
        Write-Log -Message "--------------------------------------------" -Log "Main.log"
        Write-Log -Message "Exporting Logo(s)..." -Log "Main.log"
        Write-Log -Message "--------------------------------------------" -Log "Main.log"
        Write-Host ''
        Write-Host '--------------------------------------------' -ForegroundColor Gray
        Write-Host 'Exporting Logo(s)...' -ForegroundColor Gray
        Write-Host '--------------------------------------------' -ForegroundColor Gray
        Write-Host ''

        ForEach ($Application in $applications_Array) {
            Write-Log -Message "`$IconId = $($Application.Application_IconId)" -Log "Main.log"
            $IconId = $Application.Application_IconId
            Write-Log -Message "Export-Logo -IconId $($IconId) -AppName $($Application.Application_LogicalName)" -Log "Main.log"
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
        Write-Host '--------------------------------------------' -ForegroundColor Gray
        Write-Host 'Creating Application Folder(s)' -ForegroundColor Gray
        Write-Host '--------------------------------------------' -ForegroundColor Gray
        Write-Host ''

        ForEach ($Application in $applications_Array) {

            #Create Application Parent Folder(s)
            Write-Log -Message "Application: $($Application.Application_Name)" -Log "Main.log"
            Write-Host "Application: ""$($Application.Application_Name)"""
            Write-Log -Message "Creating Application Folder $($Application.Application_LogicalName) for Application $($Application.Application_Name)" -Log "Main.log"
            Write-Host "Creating Application Folder ""$($Application.Application_LogicalName)"" for Application ""$($Application.Application_Name)""" -ForegroundColor Cyan
            If (!(Test-Path -Path (Join-Path -Path $WorkingFolder_Win32Apps -ChildPath $Application.Application_LogicalName ))) {
                Write-Log -Message "New-FolderToCreate -Root $($WorkingFolder_Win32Apps) -FolderNames $($Application.Application_LogicalName)" -Log "Main.log"
                New-FolderToCreate -Root $WorkingFolder_Win32Apps -FolderNames $Application.Application_LogicalName
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
        Write-Host '--------------------------------------------' -ForegroundColor Gray
        Write-Host 'Creating DeploymentType Folder(s)' -ForegroundColor Gray
        Write-Host '--------------------------------------------' -ForegroundColor Gray
        Write-Host ''
        ForEach ($DeploymentType in $deploymentTypes_Array) {

            #Create DeploymentType Child Folder(s)
            Write-Log -Message "Creating DeploymentType Folder $($DeploymentType.DeploymentType_LogicalName) for DeploymentType $($DeploymentType.DeploymentType_Name)" -Log "Main.log"
            Write-Host "Creating DeploymentType Folder ""$($DeploymentType.DeploymentType_LogicalName)"" for DeploymentType ""$($DeploymentType.DeploymentType_Name)""" -ForegroundColor Cyan
            If (!(Test-Path -Path (Join-Path -Path (Join-Path -Path $WorkingFolder_Win32Apps -ChildPath $DeploymentType.Application_LogicalName ) -ChildPath $DeploymentType.DeploymentType_LogicalName))) {
                Write-Log -Message "New-FolderToCreate -Root $($WorkingFolder_Win32Apps) -FolderNames (Join-Path -Path $($DeploymentType.Application_LogicalName) -ChildPath $($DeploymentType.DeploymentType_LogicalName))" -Log "Main.log"
                New-FolderToCreate -Root $WorkingFolder_Win32Apps -FolderNames (Join-Path -Path $DeploymentType.Application_LogicalName -ChildPath $DeploymentType.DeploymentType_LogicalName)
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
        Write-Host '--------------------------------------------' -ForegroundColor Gray
        Write-Host 'Creating Content Folder(s)' -ForegroundColor Gray
        Write-Host '--------------------------------------------' -ForegroundColor Gray
        Write-Host ''
        ForEach ($DeploymentType in $deploymentTypes_Array) {

            #Create DeploymentType Content Folder(s)
            Write-Log -Message "Creating DeploymentType Content Folder for DeploymentType $($DeploymentType.DeploymentType_Name)" -Log "Main.log"
            Write-Host "Creating DeploymentType Content Folder for DeploymentType ""$($DeploymentType.DeploymentType_Name)""" -ForegroundColor Cyan
            If (!(Test-Path -Path (Join-Path -Path $WorkingFolder_Content -ChildPath $DeploymentType.Application_LogicalName))) {
                Write-Log -Message "New-FolderToCreate -Root $($WorkingFolder_Content) -FolderNames $($DeploymentType.DeploymentType_LogicalName)" -Log "Main.log"
                New-FolderToCreate -Root $WorkingFolder_Content -FolderNames $DeploymentType.DeploymentType_LogicalName
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
        Write-Log -Message "Content Evaluation" -Log "Main.log"
        Write-Log -Message "--------------------------------------------" -Log "Main.log"
        Write-Host '--------------------------------------------' -ForegroundColor Gray
        Write-Host 'Content Evaluation' -ForegroundColor Gray
        Write-Host '--------------------------------------------' -ForegroundColor Gray
        Write-Host ''

        If ($DownloadContent) {

            ForEach ($Content in $content_Array) {
                Write-Log -Message "Downloading Content for Deployment Type $($Content.Content_DeploymentType_LogicalName) from Content Source $($Content.Content_Location)..." -Log "Main.log"
                Write-Host "Downloading Content for Deployment Type ""$($Content.Content_DeploymentType_LogicalName)"" from Content Source ""$($Content.Content_Location)""..." -ForegroundColor Cyan
                Write-Log -Message "Get-ContentFiles -Source $($Content.Content_Location) -Destination (Join-Path -Path $($WorkingFolder_Content) -ChildPath $($Content.Content_DeploymentType_LogicalName))" -Log "Main.log" 
                Get-ContentFiles -Source $Content.Content_Location -Destination (Join-Path -Path $WorkingFolder_Content -ChildPath $Content.Content_DeploymentType_LogicalName)
            }
        }
        else {
            ForEach ($Content in $content_Array) {
                Write-Log -Message "DownloadContent switch not passed. Skipping Content download for Deployment Type $($Content.Content_DeploymentType_LogicalName) at Content Source $($Content.Content_Location)..." -Log "Main.log"
                Write-Host "DownloadContent switch not passed. Skipping Content download for Deployment Type ""$($Content.Content_DeploymentType_LogicalName)"" at Content Source ""$($Content.Content_Location)""..." -ForegroundColor Cyan
                $SkipFileName = "DownloadContent-Skipped.txt"
                New-Item -Path (Join-Path -Path $WorkingFolder_Content -ChildPath $Content.Content_DeploymentType_LogicalName) -Name $SkipFileName -Force | Out-Null
            }

        }
        #EndRegion Downloading_Content

        #Region Create_Intunewin_Files
        Write-Log -Message "--------------------------------------------" -Log "Main.log" 
        Write-Log -Message "Creating .IntuneWin File(s)" -Log "Main.log"
        Write-Log -Message "--------------------------------------------" -Log "Main.log"
        Write-Host ''
        Write-Host '--------------------------------------------' -ForegroundColor Gray
        Write-Host 'Creating .IntuneWin File(s)' -ForegroundColor Gray
        Write-Host '--------------------------------------------' -ForegroundColor Gray

        #Get Application and Deployment Type Details and Files
        ForEach ($Application in $applications_Array) {
            Write-Log -Message "--------------------------------------------" -Log "Main.log" 
            Write-Log -Message "$($Application.Application_Name)" -Log "Main.log"
            Write-Log -Message "There are a total of $($Application.Application_TotalDeploymentTypes) Deployment Types for this Application:" -Log "Main.log"
            Write-Log -Message "--------------------------------------------" -Log "Main.log"
            Write-Host ''
            Write-Host '--------------------------------------------' -ForegroundColor Gray
            Write-Host """$($Application.Application_Name)""" -ForegroundColor Green
            Write-Host "There are a total of $($Application.Application_TotalDeploymentTypes) Deployment Types for this Application:"
            Write-Host '--------------------------------------------' -ForegroundColor Gray
            Write-Host ''

            ForEach ($Deployment in $deploymentTypes_Array | Where-Object { $_.Application_LogicalName -eq $Application.Application_LogicalName }) {
            
                Write-Log -Message "--------------------------------------------" -Log "Main.log" 
                Write-Log -Message "$($Deployment.DeploymentType_Name)" -Log "Main.log"
                Write-Log -Message "--------------------------------------------" -Log "Main.log"
                Write-Host '--------------------------------------------' -ForegroundColor Gray
                Write-Host """$($Deployment.DeploymentType_Name)""" -ForegroundColor Green
                Write-Host '--------------------------------------------' -ForegroundColor Gray
                Write-Host ''

                #Grab install command executable or script
                $SetupFile = $Deployment.DeploymentType_InstallCommandLine
                Write-Log -Message "Install Command: ""$($SetupFile)""" -Log "Main.log"
                Write-Host "Install Command: ""$($SetupFile)"""

                ForEach ($Content in $content_Array | Where-Object { $_.Content_DeploymentType_LogicalName -eq $Deployment.DeploymentType_LogicalName }) {

                    #Create variables to pass to Function

                    If ($DownloadContent) {
                        Write-Log -Message "`$ContentFolder = Join-Path -Path $($WorkingFolder_Content) -ChildPath $($Deployment.DeploymentType_LogicalName)" -Log "Main.log"
                        $ContentFolder = Join-Path -Path $WorkingFolder_Content -ChildPath $Deployment.DeploymentType_LogicalName
                    }
                    else {
                        Write-Log -Message "`$ContentFolder = $($Content.Content_Location)" -Log "Main.log"
                        $ContentFolder = $Content.Content_Location  
                    }

                    #Trim ending backslash if it exists on folder path
                    If ($ContentFolder -match "\\$") {
                        $ContentFolder = $ContentFolder.TrimEnd('\')
                    }

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
                    New-IntuneWin -ContentFolder $ContentFolder -OutputFolder $OutputFolder -SetupFile $SetupFile
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
        Write-Host '--------------------------------------------' -ForegroundColor Gray
        Write-Host 'Creating Win32 Apps' -ForegroundColor Gray
        Write-Host '--------------------------------------------' -ForegroundColor Gray
        Write-Host ''
        #####----------------------IN DEVELOPMENT----------------------#####
    }
    #EndRegion Create_Apps
    Get-ScriptEnd
}