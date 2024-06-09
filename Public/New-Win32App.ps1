<#
.Synopsis
Created on:   14/03/2021
Updated on:   23/03/2024
Created by:   Ben Whitmore
Filename:     New-Win32App.ps1

The Win32 App Migration Tool is designed to inventory ConfigMgr Applications and Deployment Types, build .intunewin files and create Win3Apps in The Intune Admin Center.

.Description
**Version 2.0.12 BETA**  

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

.PARAMETER ExportIcon
When passed, the Application icon is decoded from base64 and saved to the Logos folder

.PARAMETER WorkingFolder
This is the working folder for the Win32AppMigration Tool. 
Note: Care should be given when specifying the working folder because downloaded content can increase the working folder size considerably

.PARAMETER PackageApps
Pass this parameter to package selected apps in the .intunewin format

.PARAMETER CreateApps
Pass this parameter to create the Win32apps in Intune

.PARAMETER ResetLog
Pass this parameter to reset the log file

.PARAMETER ExcludePMPC
Pass this parameter to exclude apps created by PMPC from the results. Filter is applied to Application "Comments". string can be modified in Get-AppList Function

.PARAMETER ExcludeFilter
Pass this parameter to exclude specific apps from the results. string value that accepts wildcards e.g. "Microsoft*"

.PARAMETER Win32ContentPrepToolUri
URI for Win32 Content Prep Tool

.PARAMETER OverrideIntuneWin32FileName
Override intunewin filename. Default is the name calcualted from the install command line. You only need to pass the file name, not the extension

.PARAMETER Win32AppNotes
Notes field value to add to the Win32App JSON body

.PARAMETER AllowAvailableUninstall
When creating the Win32App, allow the user to uninstall the app if it is available in the Company Portal

.PARAMETER TenantId
Tenant Id or name to connect to. This parameter is mandatory for obtaining a token

.PARAMETER ClientId
Client Id (App Registration) to connect to. This parameter is mandatory for obtaining a token

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

.EXAMPLE
New-Win32App -SiteCode "BB1" -ProviderMachineName "SCCM1.byteben.com" -AppName "Microsoft Edge Chromium *" -ExportLogo -PackageApps -CreateApps -ResetLog -ExcludePMPC -ExcludeFilter "Microsoft*" -OverrideIntuneWin32FileName "application"

.EXAMPLE
New-Win32App -SiteCode "BB1" -ProviderMachineName "SCCM1.byteben.com" -AppName "Microsoft Edge Chromium *" -ExportLogo -PackageApps -CreateApps -ResetLog -ExcludePMPC -ExcludeFilter "Microsoft*" -OverrideIntuneWin32FileName "application" -Win32AppNotes "Created by the Win32App Migration Tool"

#>
function New-Win32App {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 0, HelpMessage = 'The Site Code of the ConfigMgr Site')]
        [ValidatePattern('(?##The Site Code must be only 3 alphanumeric characters##)^[a-zA-Z0-9]{3}$')]
        [string]$SiteCode,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 1, HelpMessage = 'Server name that has an SMS Provider site system role')]
        [string]$ProviderMachineName,  
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 2, HelpMessage = 'The name of the application to search for. Accepts wildcards *')]
        [string]$AppName,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, HelpMessage = 'DownloadContent: When passed, the content for the deployment type is saved locally to the working folder "Content"')]
        [Switch]$DownloadContent,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, HelpMessage = 'ExportLogo: When passed, the Application icon is decoded from base64 and saved to the Logos folder')]
        [Switch]$ExportIcon,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 3, HelpMessage = 'The working folder for the Win32AppMigration Tool. Care should be given when specifying the working folder because downloaded content can increase the working folder size considerably')]
        [string]$workingFolder = "C:\Win32AppMigrationTool",
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, HelpMessage = 'PackageApps: Pass this parameter to package selected apps in the .intunewin format')]
        [Switch]$PackageApps,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, HelpMessage = 'ResetLog: Pass this parameter to reset the log file')]
        [Switch]$ResetLog,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, HelpMessage = 'ExcludePMPC: Pass this parameter to exclude apps created by PMPC from the results. Filter is applied to Application "Comments". string can be modified in Get-AppList Function')]
        [Switch]$ExcludePMPC,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 4, HelpMessage = 'ExcludeFilter: Pass this parameter to exclude specific apps from the results. string value that accepts wildcards e.g. "Microsoft*"')]
        [string]$ExcludeFilter,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, HelpMessage = 'NoOGV: When passed, the Out-Gridview is suppressed')]
        [Switch]$NoOgv,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 5, HelpMessage = 'URI for Win32 Content Prep Tool')]
        [string]$Win32ContentPrepToolUri = 'https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/raw/master/IntuneWinAppUtil.exe',
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 6, HelpMessage = 'Override intunewin filename. Default is the name calcualted from the install command line')]
        [string]$OverrideIntuneWin32FileName,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 7, HelpMessage = 'Notes field value to add to the Win32App JSON body')]
        [string]$Win32AppNotes = "Created by the Win32App Migration Tool",
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, Position = 8, HelpMessage = "When creating the Win32App, allow the user to uninstall the app if it is available in the Company Portal")]
        [bool]$AllowAvailableUninstall = $true,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, ParameterSetName = 'CreateAppsSet', HelpMessage = 'CreateApps: Pass this parameter to create the Win32apps in Intune')]
        [Switch]$CreateApps,
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, ParameterSetName = 'CreateAppsSet', Position = 9, HelpMessage = 'Tenant Id or name to connect to')]
        [string]$TenantId,
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, ParameterSetName = 'CreateAppsSet', Position = 10, HelpMessage = 'Client Id (App Registration) to connect to')]
        [string]$ClientId,
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = "The component (script name) passed as LogID to the 'Write-Log' function")]
        [string]$LogId = $($MyInvocation.MyCommand).Name
        
    )
    begin {

        # Add logic to check for CreateApps parameter and validate TenantId and ClientId
        if ($PSCmdlet.ParameterSetName -eq 'CreateAppsSet') {
            if (-not $TenantId) {
                throw "TenantId is required when CreateApps is specified."
            }
            if (-not $ClientId) {
                throw "ClientId is required when CreateApps is specified."
            }
        }
    }

    process {

        # Create global variable(s) 
        $global:workingFolder_Root = $workingFolder

        #region Prepare_Workspace
        # Initialize folders to prepare workspace for logging
        Write-Host "Initializing required folders..." -ForegroundColor Cyan

        foreach ($folder in $workingFolder_Root, "$workingFolder_Root\Logs") {
            if (-not (Test-Path -Path $folder)) {
                Write-Host ("Working folder root does not exist at '{0}'. Creating environemnt..." -f $folder) -ForegroundColor Cyan
                New-Item -Path $folder -ItemType Directory -Force -ErrorAction Stop | Out-Null
            }
            else {
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
        Write-Log -Message ("New-FolderToCreate -Root '{0}' -FolderNames @('Icons', 'Content', 'ContentPrepTool', 'DetectionMethods','Details', 'Win32Apps')" -f $workingFolder_Root) -LogId $LogId
        New-FolderToCreate -Root $workingFolder_Root -FolderNames @('Icons', 'Content', 'ContentPrepTool', 'DetectionMethods', 'Details', 'Win32Apps')
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

        #region Get_Auth_Token
        # Get a token if the CreateApps parameter is passed
        if ($PSBoundParameters.ContainsKey('CreateApps')) {

            if (-not $global:authToken -and (-not $PSBoundParameters.ContainsKey('TenantId') -or -not $PSBoundParameters.ContainsKey('ClientId'))) {
                Write-Log -Message "The 'CreateApps' parameter was passed. Please run Get-AuthToken to obtain an authentication token" -LogId $LogId
                Write-Host "The 'CreateApps' parameter was passed. Please run Get-AuthToken to obtain an authentication token" -ForegroundColor Cyan
                break
            }

            if ($PSBoundParameters.ContainsKey('TenantId') -and $PSBoundParameters.ContainsKey('ClientId')) {
                Write-Log -Message "The 'CreateApps' parameter was passed. Testing to see if we have a valid authentication token" -LogId $LogId
                Write-Host "The 'CreateApps' parameter was passed. Testing to see if we have a valid authentication token" -ForegroundColor Cyan

                Get-AuthToken -TenantId $TenantId -ClientId $ClientId
            }
        }
        #endregion

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
            Write-Log -Message ("There were no applications found that match the crieria '{0}' or the Out-GrideView was closed with no selection made. Cannot continue" -f $AppName) -LogId $LogId -Severity 3
            Write-Warning -Message ("There were no applications found that match the crieria '{0}' or the Out-GrideView was closed with no selection made. Cannot continue" -f $AppName)
            Get-ScriptEnd
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
        New-VerboseRegion -Message 'Getting deployment type content information' -ForegroundColor 'Gray'
  
        # Calling function to grab deployment type content information
        Write-Log -Message "Calling 'Get-ContentFiles' function to grab deployment type content" -LogId $LogId
        Write-Host "Calling 'Get-ContentFiles' function to grab deployment type content" -ForegroundColor Cyan
            
        $content_Array = foreach ($deploymentType in $deploymentTypes_Array) { 
    
            # Build or reset a hash table of switch parameters to pass to the Get-ContentFiles function
            $paramsToPassContent = @{}
    
            if ($deploymentType.InstallContent) { $paramsToPassContent.Add('InstallContent', $deploymentType.InstallContent) }
            $paramsToPassContent.Add('UninstallSetting', $deploymentType.UninstallSetting)
            if ($deploymentType.UninstallContent) { $paramsToPassContent.Add('UninstallContent', $deploymentType.UninstallContent) }
            $paramsToPassContent.Add('ApplicationId', $deploymentType.Application_Id)
            $paramsToPassContent.Add('ApplicationName', $deploymentType.ApplicationName)
            $paramsToPassContent.Add('DeploymentTypeLogicalName', $deploymentType.LogicalName)
            $paramsToPassContent.Add('DeploymentTypeName', $deploymentType.Name)
            $paramsToPassContent.Add('InstallCommandLine', $deploymentType.InstallCommandLine)

            # If we have content, call the Get-ContentInfo function
            if ($deploymentType.InstallContent -or $deploymentType.UninstallContent) { Get-ContentInfo @paramsToPassContent }
        }

        # If $DownloadContent was passed, download content to the working folder
        New-VerboseRegion -Message 'Copying content files' -ForegroundColor 'Gray'

        if ($DownloadContent) {
            Write-Log -Message "The 'DownloadContent' parameter passed" -LogId $LogId

            foreach ($content in $content_Array) {
                Get-ContentFiles -Source $content.Install_Source -Destination $content.Install_Destination

                # If the uninstall content is different to the install content, copy that too
                if ($content.Uninstall_Setting -eq 'Different') {
                    Get-ContentFiles -Source $content.Uninstall_Source -Destination $content.Uninstall_Destination -Flags 'UninstallDifferent'
                }
            }  
        }
        else {
            Write-Log -Message "The 'DownloadContent' parameter was not passed. Skipping content download" -LogId $LogId -Severity 2
            Write-Host "The 'DownloadContent' parameter was not passed. Skipping content download" -ForegroundColor Yellow
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
        if ($DownloadContent) {
            Export-CsvDetails -Name 'Content' -Data $content_Array -Path $detailsFolder
        }
        #endregion

        #region Exporting_Logos
        # Export icon(s) for the applications
        New-VerboseRegion -Message 'Exporting icon(s)' -ForegroundColor 'Gray'

        if ($ExportIcon) {
            Write-Log -Message "The 'ExportIcon' parameter passed" -LogId $LogId

            foreach ($applicationIcon in $app_Array) {

                if ([string]::IsNullOrWhiteSpace($applicationIcon.IconData)) {
                    Write-Log -Message ("No icon data found for '{0}'. Skipping icon export" -f $applicationIcon.Name) -LogId $LogId -Severity 2
                    Write-Host ("No icon data found for '{0}'. Skipping icon export" -f $applicationIcon.Name) -ForegroundColor Yellow
                }
                else {
                    Write-Log -Message ("Exporting icon for '{0}' to '{1}'" -f $applicationIcon.Name, $applicationIcon.IconPath) -Logid $LogId
                    Write-Host ("Exporting icon for '{0}' to '{1}'" -f $applicationIcon.Name, $applicationIcon.IconPath) -ForegroundColor Cyan
                
                    # Export the icon to disk
                    Export-Icon -AppName $applicationIcon.Name -IconPath $applicationIcon.IconPath -IconData $applicationIcon.IconData
                }
            }
        }
        else {
            Write-Log -Message "The 'ExportIcon' parameter was not passed. Skipping icon export" -LogId $LogId -Severity 2
            Write-Host "The 'ExportIcon' parameter was not passed. Skipping icon export" -ForegroundColor Yellow
        }
        #endregion

        #region Package_Apps
        if ($PackageApps) {

            # If the $PackageApps parameter was passed. Use the Win32Content Prep Tool to build Intune.win files
            Write-Log -Message "The 'PackageApps' Parameter passed" -LogId $LogId
            New-VerboseRegion -Message 'Creating intunewin file(s)' -ForegroundColor 'Gray'

            foreach ($content in $content_Array) {

                Write-Log -Message ("Working on application '{0}'..." -f $content.Application_Name) -LogId $LogId
                Write-Host ("`nWorking on application '{0}'..." -f $content.Application_Name) -ForegroundColor Cyan

                # Create the Win32app folder for the .intunewin files
                New-FolderToCreate -Root "$workingFolder_Root\Win32Apps" -FolderNames $content.Win32app_Destination
        
                # Create intunewin files
                Write-Log -Message ("Creating intunewin file for the deployment type '{0}' for app '{1}'" -f $content.DeploymentType_Name, $content.Application_Name) -LogId $LogId
                Write-Host ("Creating intunewin file for the deployment type '{0}' for app '{1}'" -f $content.DeploymentType_Name, $content.Application_Name)  -ForegroundColor Cyan
            
                # Build parameters to splat at the New-IntuneWin function
                $paramsToPassIntuneWin = @{}

                # If DownloadContent switch is not passed we will use content from the Configmgr source folder
                if ($DownloadContent) {
                    $paramsToPassIntuneWin.Add('ContentFolder', $content.Install_Destination)
                }
                else {
                    $paramsToPassIntuneWin.Add('ContentFolder', $content.Install_Source)
                }

                $paramsToPassIntuneWin.Add('OutputFolder', (Join-Path -Path "$workingFolder_Root\Win32Apps" -ChildPath $content.Win32app_Destination))
                $paramsToPassIntuneWin.Add('SetupFile', $content.Install_CommandLine)

                if ($OverrideIntuneWin32FileName) { 
                    $paramsToPassIntuneWin.Add('OverrideIntuneWin32FileName', $OverrideIntuneWin32FileName) 
                }

                # Create the .intunewin file
                New-IntuneWin @paramsToPassIntuneWin
            }
        }
        else {
            Write-Log -Message "The 'PackageApps' parameter was not passed. Intunewin files will not be created" -LogId $LogId -Severity 2
            Write-Host "The 'PackageApps' parameter was not passed. Intunewin files will not be created" -ForegroundColor Yellow
        }
        #endRegion

        #region Create Intune Win32 app JSON body
        if ($CreateApps -and $PackageApps) {

            # If the $CreateApps parameter was passed. Start creating the Win32 apps in Intune
            Write-Log -Message "The 'CreateApps' Parameter passed" -LogId $LogId
            New-VerboseRegion -Message 'Creating Win32 app JSON body' -ForegroundColor 'Gray'

            foreach ($app in $app_array) {
        
                foreach ($deploymentType in $deploymentTypes_Array | Where-Object { $_.Application_Logicalname -eq $app.LogicalName }) {

                    foreach ($content in $content_Array | Where-Object { $_.DeploymentType_LogicalName -eq $deploymentType.LogicalName }) {

                        Write-Log -Message ("Working on application '{0}'..." -f $app.Name) -LogId $LogId
                        Write-Host ("`nWorking on application '{0}'..." -f $app.name) -ForegroundColor Cyan

                        # Create the Win32app folder for the JSON files if it doesn't exist
                        if (-not (Test-Path -Path "$workingFolder_Root\Win32Apps") ) {
                            New-FolderToCreate -Root "$workingFolder_Root\Win32Apps" -FolderNames $content.Win32app_Destination
                        }

                        $PathforWin32AppBodyJSON = Join-Path -Path "$workingFolder_Root\Win32Apps" -ChildPath $content.Win32app_Destination

                        # Get the intunewin meta data
                        try {
                            $setupFilePath = Get-ChildItem -Path $PathforWin32AppBodyJSON -Filter "*.intunewin" -Recurse | Select-Object -First 1 -ExpandProperty FullName
                            
                            if ($setupFilePath) {
                                Write-Log -Message ("Found the .intunewin file at '{0}'" -f $setupFilePath) -LogId $LogId
                                Write-Host ("Found the .intunewin file at '{0}'" -f $setupFilePath) -ForegroundColor Cyan

                                # Get the intunewin file information
                                $intuneWinInfo = Get-IntuneWinInfo -SetupFile $setupFilePath
                            }
                            else {
                                Write-Log -Message ("Failed to get the .intunewin file from '{0}'" -f $PathforWin32AppBodyJSON) -LogId $LogId -Severity 3
                                throw ("Failed to get the .intunewin file from '{0}'" -f $PathforWin32AppBodyJSON)
                                break
                            }
                        }
                        catch {
                            Write-Log -Message ("Failed to get the .intunewin file from '{0}'" -f $PathforWin32AppBodyJSON) -LogId $LogId -Severity 3
                            throw ("Failed to get the .intunewin file from '{0}'" -f $PathforWin32AppBodyJSON)
                            break
                        }

                        # Create Win32 app body
                        Write-Log -Message ("Creating Win32 app body for the deployment type '{0}' for app '{1}'" -f $deploymentType.Name, $deploymentType.ApplicationName) -LogId $LogId
                        Write-Host ("Creating Win32 app body for the deployment type '{0}' for app '{1}'" -f $deploymentType.Name, $deploymentType.ApplicationName)  -ForegroundColor Cyan

                        # Build parameters to splat at the New-IntuneWinFramework function

                        # Body for the Win32 app
                        $paramsToPassWin32App = @{}
                        $paramsToPassWin32App.Add('Name', $app.Name)
                        $paramsToPassWin32App.Add('Description', $app.Description)
                        $paramsToPassWin32App.Add('Publisher', $app.Publisher)
                        $paramsToPassWin32App.Add('InformationURL', $app.InfoURL)
                        $paramsToPassWin32App.Add('PrivacyURL', $app.PrivacyURL)
                        $paramsToPassWin32App.Add('Notes', $Win32AppNotes)
                        $paramsToPassWin32App.Add('LargeIcon', $app.IconData)
                        $paramsToPassWin32App.Add('Path', $PathforWin32AppBodyJSON)
                        $paramsToPassWin32App.Add('FileName', $intuneWinInfo.FileName)
                        $paramsToPassWin32App.Add('SetupFile', $intuneWinInfo.SetupFile)
                        $paramsToPassWin32App.Add('InstallCommandLine', $deploymentType.InstallCommandLine)
                        $paramsToPassWin32App.Add('UninstallCommandLine', $deploymentType.UninstallCommandLine)
                        $paramsToPassWin32App.Add('InstallExperience', $deploymentType.ExecutionContext)

                        if ($PSBoundParameters.ContainsKey('AllowAvailableUninstall')) {
                            $paramsToPassWin32App.Add('AllowAvailableUninstall', $AllowAvailableUninstall)
                        }
                        else {
                            $paramsToPassWin32App.Add('AllowAvailableUninstall', $false)
                        }

                        # Detection method (rules) for the Win32 app
                        if (Test-Path -Path $deploymentType.DetectionMethodJsonFile) {
                            try {
                                $jsonBlob = Get-Content -Path $deploymentType.DetectionMethodJsonFile -Raw
                                $paramsToPassWin32App.Add('DetectionMethodJson', ($jsonBlob))
                            }
                            catch {
                                Write-Log -Message ("Failed to read the JSON file '{0}'" -f $deploymentType.DetectionMethodJsonFile) -LogId $LogId -Severity 3
                                Write-Warning -Message ("Failed to read the JSON file '{0}'" -f $deploymentType.DetectionMethodJsonFile)
                            }
                        }
                        elseif (Test-Path -path $deploymentType.DetectionTypeScriptType) {
                            $scriptBlob = Get-Content -Path $deploymentType.DetectionTypeScriptType -Raw
                            $bytes = [System.Text.Encoding]::UTF8.GetBytes($scriptBlob)
                            $base64EncodedScript = [Convert]::ToBase64String($bytes)
                            $paramsToPassWin32App.Add('DetectionScript', $base64EncodedScript)
                        }
                        else {
                            Write-Log -Message ("No detection method found for '{0}'" -f $app.Name) -LogId $LogId -Severity 3
                            Write-Warning -Message ("No detection method found for '{0}'" -f $app.Name)
                        }
                    }

                    # Create the JSON body file
                    New-IntuneWinFramework @paramsToPassWin32App
            
                }          
            }
        }
        
        #endregion
        Get-ScriptEnd
    }
}