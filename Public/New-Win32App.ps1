<#
.Synopsis
Created on:   14/03/2021
Updated on:   16/11/2026
Created by:   Ben Whitmore
Filename:     New-Win32App.ps1

The Win32 App Migration Tool is designed to inventory ConfigMgr Applications and Deployment Types, build .intunewin files and create Win3 apps in The Intune admin center.
The script supports different authentication methods for connecting to the Microsoft Graph API. The preferred method is using a certificate, as this method is more secure. If you don't have a certificate, the Delegate and devicecode flow are also supported. Client Secret is an option too, but it is not recommended for production environments.
Documentation can be found at https://github.com/byteben/Win32App-Migration-Tool/blob/main/README.md

.Description
This script is designed to export the Application and Deployment Data from ConfigMgr to firstly create an .intunewin file and secondly publish the Win32 app to Intune
Change Control Log: https://github.com/byteben/Win32App-Migration-Tool/blob/main/Release_Notes.md

Each deployment type is processed on its own. A failure in one deployment type is recorded and the run
continues with the next one. A results CSV (Details\MigrationResults_<timestamp>.csv) lists every
deployment type with its status (Success, Skipped, Failed), the stage it reached, the Intune app Id and
the reason for any failure.

.NOTES
PowerShell 5.1 or later is required to run this script.
PowerShell 7 or later is recommended.

---------------------------------------------------------------------------------
LEGAL DISCLAIMER

This solution is distributed under the GNU GENERAL PUBLIC LICENSE

The PowerShell script provided is shared with the community as-is
The author and co-author(s) make no warranties or guarantees regarding its functionality, reliability, or suitability for any specific purpose
Please note that the script may need to be modified or adapted to fit your specific environment or requirements
It is recommended to thoroughly test the script in a non-production environment before using it in a live or critical system
The author and co-author(s) cannot be held responsible for any damages, losses, or adverse effects that may arise from the use of this script
You assume all risks and responsibilities associated with its usage
---------------------------------------------------------------------------------

.PARAMETER LogId
The component (script name) passed as LogID to the 'Write-Log' function.

.PARAMETER AppName
Pass a string to the tool to search for applications in ConfigMgr. Out-GridView lets you select one of the results; use -NoOgv or -AppId to process several

.PARAMETER AppId
One or more ConfigMgr application CI_IDs to process. Skips the search and Out-GridView, so it can be used unattended

.PARAMETER DownloadContent
When passed, the content for the deployment type is saved locally to the working folder "Content"

.PARAMETER SiteCode
Specify the Sitecode you wish to connect to. We try to get this automatically from the SMS_ProviderLocation WMI class if none is specified

.PARAMETER ProviderMachineName
Specify the SMS Provider you wish to connect to

.PARAMETER ExportIcon
When passed, the Application icon is decoded from base64 and saved to the Icons folder

.PARAMETER WorkingFolder
This is the working folder for the Win32AppMigration Tool.
Note: Care should be given when specifying the working folder because downloaded content can increase the working folder size considerably

.PARAMETER PackageApps
Pass this parameter to package selected apps in the .intunewin format

.PARAMETER CreateApps
Pass this parameter to create the Win32apps in Intune. Without -PackageApps, the newest .intunewin file already in the deployment type's Win32Apps folder is used

.PARAMETER ResetLog
Pass this parameter to reset the log file

.PARAMETER ExcludePMPC
Pass this parameter to exclude apps created by PMPC from the results. Filter is applied to the Application description

.PARAMETER ExcludeFilter
Pass this parameter to exclude specific apps from the results. string value that accepts wildcards e.g. "Microsoft*"

.PARAMETER NoOgv
When passed, the Out-Gridview is suppressed and every application matching AppName is processed

.PARAMETER Win32ContentPrepToolUri
URI for Win32 Content Prep Tool

.PARAMETER OverrideIntuneWin32FileName
Override intunewin filename. Default is the name calculated from the install command line. You only need to pass the file name, not the extension

.PARAMETER Win32AppNotes
Notes field value to add to the Win32App JSON body

.PARAMETER AllowAvailableUninstall
When creating the Win32App, allow the user to uninstall the app if it is available in the Company Portal. Default $false

.PARAMETER UploadTimeoutMinutes
How long to wait for Intune to process the uploaded content (commit). Large packages need longer. Default 30

.PARAMETER MaxAppSizeGB
The largest .intunewin, in GB (1,000,000,000 bytes), that will be uploaded. Intune limits Win32 apps to 30 GB per app, so a larger
package is skipped before an Intune app is created instead of failing partway through the upload. Default 30. Only raise it
if Microsoft has raised the limit for your tenant

.PARAMETER KeepFailedApps
By default, if the content upload or commit fails after the Win32 app was created in Intune, the half-created app is deleted. Pass this to keep it

.PARAMETER NoPrompt
Don't ask whether to disconnect from Microsoft Graph at the end of the run

.PARAMETER TenantId
Tenant Id or name to connect to. This parameter is mandatory for obtaining a token

.PARAMETER ClientId
Client Id (App Registration) to connect to. This parameter is mandatory for obtaining a token

.PARAMETER ClientSecret
Client Secret for the App Registration

.PARAMETER ClientCertificateThumbprint
Client certificate thumbprint for authentication

.PARAMETER UseDeviceAuthentication
Use device code authentication

.PARAMETER RequiredScopes
The scopes required for Microsoft Graph API access

.EXAMPLE
New-Win32App -ProviderMachineName "SCCM1.byteben.com" -AppName "Microsoft Edge Chromium *"

.EXAMPLE
New-Win32App -ProviderMachineName "SCCM1.byteben.com" -AppName "Microsoft Edge Chromium *" -DownloadContent -ExportIcon -PackageApps

.EXAMPLE
New-Win32App -ProviderMachineName "SCCM1.byteben.com" -AppName "7-Zip*" -PackageApps -CreateApps -TenantId "contoso.onmicrosoft.com" -ClientId "1234-1234-1234" -ClientCertificateThumbprint "ABCDEF0123456789ABCDEF0123456789ABCDEF01"

.EXAMPLE
New-Win32App -ProviderMachineName "SCCM1.byteben.com" -AppId 16777234,16777240 -PackageApps -CreateApps -NoPrompt -TenantId "contoso.onmicrosoft.com" -ClientId "1234-1234-1234" -ClientCertificateThumbprint "ABCDEF0123456789ABCDEF0123456789ABCDEF01"
#>
function New-Win32App {

    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param (
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 0, HelpMessage = 'The Site Code of the ConfigMgr Site')]
        [ValidatePattern('(?##The Site Code must be only 3 alphanumeric characters##)^[a-zA-Z0-9]{3}$')]
        [string]$SiteCode,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 1, HelpMessage = 'Server name that has an SMS Provider site system role')]
        [string]$ProviderMachineName,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 2, HelpMessage = 'The name of the application to search for. Accepts wildcards *')]
        [string]$AppName,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, HelpMessage = 'One or more ConfigMgr application CI_IDs to process')]
        [string[]]$AppId,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 3, HelpMessage = 'DownloadContent: When passed, the content for the deployment type is saved locally to the working folder "Content"')]
        [Switch]$DownloadContent,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 4, HelpMessage = 'ExportIcon: When passed, the Application icon is decoded from base64 and saved to the Icons folder')]
        [Switch]$ExportIcon,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 5, HelpMessage = 'The working folder for the Win32AppMigration Tool. Care should be given when specifying the working folder because downloaded content can increase the working folder size considerably')]
        [string]$workingFolder = "C:\Win32AppMigrationTool",
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 6, HelpMessage = 'PackageApps: Pass this parameter to package selected apps in the .intunewin format')]
        [Switch]$PackageApps,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 7, HelpMessage = 'ResetLog: Pass this parameter to reset the log file')]
        [Switch]$ResetLog,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 8, HelpMessage = 'ExcludePMPC: Pass this parameter to exclude apps created by PMPC from the results')]
        [Switch]$ExcludePMPC,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 9, HelpMessage = 'ExcludeFilter: Pass this parameter to exclude specific apps from the results. string value that accepts wildcards e.g. "Microsoft*"')]
        [string]$ExcludeFilter,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 10, HelpMessage = 'NoOGV: When passed, the Out-Gridview is suppressed')]
        [Switch]$NoOgv,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 11, HelpMessage = 'URI for Win32 Content Prep Tool')]
        [string]$Win32ContentPrepToolUri = 'https://raw.githubusercontent.com/microsoft/Microsoft-Win32-Content-Prep-Tool/refs/heads/master/IntuneWinAppUtil.exe',
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 12, HelpMessage = 'Override intunewin filename. Default is the name calculated from the install command line')]
        [string]$OverrideIntuneWin32FileName,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 13, HelpMessage = 'Notes field value to add to the Win32App JSON body')]
        [string]$Win32AppNotes = "Created by the Win32App Migration Tool",
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 14, HelpMessage = "When creating the Win32App, allow the user to uninstall the app if it is available in the Company Portal")]
        [bool]$AllowAvailableUninstall = $false,
        [Parameter(Mandatory = $false, Position = 15, HelpMessage = 'CreateApps: Pass this parameter to create the Win32apps in Intune')]
        [Switch]$CreateApps,
        [Parameter(Mandatory = $false, HelpMessage = 'Minutes to wait for Intune to process uploaded content')]
        [ValidateRange(1, 1440)]
        [int]$UploadTimeoutMinutes = 30,
        [Parameter(Mandatory = $false, HelpMessage = 'The largest .intunewin, in GB, to upload. Intune limits Win32 apps to 30 GB')]
        [ValidateRange(1, 1024)]
        [int]$MaxAppSizeGB = 30,
        [Parameter(Mandatory = $false, HelpMessage = 'Keep a half-created Intune app when its content upload fails')]
        [Switch]$KeepFailedApps,
        [Parameter(Mandatory = $false, HelpMessage = 'Do not prompt to disconnect from Microsoft Graph at the end')]
        [Switch]$NoPrompt,

        # Shared Parameters for Graph Authentication
        [Parameter(Mandatory = $true, ParameterSetName = 'ClientSecret', Position = 16, HelpMessage = 'Tenant Id or name to connect to')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ClientCertificateThumbprint', Position = 16, HelpMessage = 'Tenant Id or name to connect to')]
        [Parameter(Mandatory = $true, ParameterSetName = 'UseDeviceAuthentication', Position = 16, HelpMessage = 'Tenant Id or name to connect to')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Interactive', Position = 16, HelpMessage = 'Tenant Id or name to connect to')]
        [string]$TenantId,

        [Parameter(Mandatory = $true, ParameterSetName = 'ClientSecret', Position = 17, HelpMessage = 'Client Id (App Registration) to connect to')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ClientCertificateThumbprint', Position = 17, HelpMessage = 'Client Id (App Registration) to connect to')]
        [Parameter(Mandatory = $true, ParameterSetName = 'UseDeviceAuthentication', Position = 17, HelpMessage = 'Client Id (App Registration) to connect to')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Interactive', Position = 17, HelpMessage = 'Client Id (App Registration) to connect to')]
        [string]$ClientId,

        # AuthN and AuthZ Parameters
        [Parameter(Mandatory = $true, ParameterSetName = 'ClientSecret', Position = 18, HelpMessage = 'Client secret for authentication')]
        [string]$ClientSecret,
        [Parameter(Mandatory = $true, ParameterSetName = 'ClientCertificateThumbprint', Position = 18, HelpMessage = 'Client certificate thumbprint for authentication')]
        [string]$ClientCertificateThumbprint,
        [Parameter(Mandatory = $true, ParameterSetName = 'UseDeviceAuthentication', Position = 18, HelpMessage = 'Use device authentication for Microsoft Graph API')]
        [switch]$UseDeviceAuthentication,
        [Parameter(Mandatory = $false, Position = 19, HelpMessage = 'The scopes required for Microsoft Graph API access')]
        [string[]]$RequiredScopes = ('DeviceManagementApps.ReadWrite.All'),

        # Additional Parameters
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = "The component (script name) passed as LogID to the 'Write-Log' function")]
        [string]$LogId = $($MyInvocation.MyCommand).Name
    )

    process {

        # Resolve a relative working folder now. After Connect-SiteServer the location is the ConfigMgr
        # site drive, where a relative path would no longer point at the file system
        $workingFolder = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($workingFolder)

        # Create global variable(s) used by the private functions
        $global:workingFolder_Root = $workingFolder
        $global:scopes = $RequiredScopes

        # Characters that are not allowed in Windows folder names
        $invalidChars = '[<>:"/\\|\?\*]'

        #region Prepare_Workspace
        Write-Host "Initializing required folders..." -ForegroundColor Cyan

        foreach ($folder in $workingFolder_Root, "$workingFolder_Root\Logs") {
            if (-not (Test-Path -Path $folder)) {
                Write-Host ("Creating folder '{0}'" -f $folder) -ForegroundColor Cyan
                New-Item -Path $folder -ItemType Directory -Force -ErrorAction Stop | Out-Null
            }
        }

        if ($ResetLog -and (Test-Path -Path "$workingFolder_Root\Logs") ) {
            Write-Log -Message $null -ResetLogFile
        }
        #endregion

        New-VerboseRegion -Message 'Start Win32AppMigrationTool' -ForegroundColor 'Gray'
        Write-Log -Message ("Module root is '{0}'. PowerShell {1}" -f $PSScriptRoot, $PSVersionTable.PSVersion) -LogId $LogId

        if (-not $AppName -and -not $AppId) {
            Write-LogAndHost -Message "Specify -AppName or -AppId" -LogId $LogId -Severity 3
            return
        }

        # One result row per deployment type (or per application when it fails before its deployment types are known)
        $results = New-Object System.Collections.Generic.List[object]
        $pushedLocation = $false
        $runStamp = Get-Date -Format 'yyyyMMdd_HHmmss'

        function New-MigrationResult {
            param ([string]$ApplicationId, [string]$ApplicationName, [string]$DeploymentType)
            [pscustomobject][ordered]@{
                ApplicationId   = $ApplicationId
                ApplicationName = $ApplicationName
                DeploymentType  = $DeploymentType
                Status          = 'Started'
                Stage           = 'Start'
                IntuneAppId     = $null
                IntuneWinFile   = $null
                Message         = $null
                RequirementsNotMigrated = $null
                Warnings        = $null
            }
        }

        try {
            # Connect to Site Server
            if ($PSBoundParameters.ContainsKey('SiteCode')) {
                Connect-SiteServer -SiteCode $SiteCode -ProviderMachineName $ProviderMachineName
            }
            else {
                Connect-SiteServer -ProviderMachineName $ProviderMachineName
            }

            #region Create_Folders
            New-VerboseRegion -Message 'Checking Win32AppMigrationTool folder structure' -ForegroundColor 'Gray'
            New-FolderToCreate -Root $workingFolder_Root -FolderNames @('Icons', 'Content', 'ContentPrepTool', 'DetectionMethods', 'Details', 'Win32Apps')
            #endRegion

            #region Get_Content_Tool
            if ($PackageApps) {
                New-VerboseRegion -Message 'Checking the Win32 Content Prep Tool' -ForegroundColor 'Gray'
                $fileDestination = Join-Path -Path "$workingFolder_Root\ContentPrepTool" -ChildPath "IntuneWinAppUtil.exe"

                if (Test-Path $fileDestination) {
                    $fileAgeInDays = (New-TimeSpan -Start (Get-Item $fileDestination).LastWriteTime -End (Get-Date)).Days

                    if ($fileAgeInDays -gt 30) {
                        Write-LogAndHost -Message ("IntuneWinAppUtil.exe is {0} days old. Downloading the current version" -f $fileAgeInDays) -LogId $LogId -Severity 2
                        Get-FileFromInternet -Uri $Win32ContentPrepToolUri -Destination $fileDestination
                    }
                    else {
                        Write-LogAndHost -Message ("IntuneWinAppUtil.exe is {0} days old. Skipping download" -f $fileAgeInDays) -LogId $LogId -ForegroundColor Cyan
                    }
                }
                else {
                    Get-FileFromInternet -Uri $Win32ContentPrepToolUri -Destination $fileDestination
                }
            }
            #endRegion

            #region Connect_MgGraphCustom
            if ($CreateApps) {
                New-VerboseRegion -Message 'Connecting to the Microsoft Graph...' -ForegroundColor 'Gray'

                if (-not $PackageApps) {
                    Write-LogAndHost -Message "The 'CreateApps' parameter was passed without 'PackageApps'. The newest .intunewin file already in each deployment type's Win32Apps folder will be used" -LogId $LogId -Severity 2
                }

                if (-not ($PSBoundParameters.ContainsKey('TenantId') -and $PSBoundParameters.ContainsKey('ClientId'))) {
                    throw "TenantId and ClientId are required with -CreateApps to connect to Microsoft Graph"
                }

                Write-LogAndHost -Message ("TenantId '{0}', ClientId '{1}', parameter set '{2}', scopes '{3}'" -f $TenantId, $ClientId, $PSCmdlet.ParameterSetName, ($RequiredScopes -join ', ')) -LogId $LogId -ForegroundColor Cyan

                # Reuse a connection already in the session only if it has the scopes, is for this app registration and
                # actually works. Otherwise the SDK can ask for a sign-in on the first request, partway through the run
                $reuse = (Test-MgConnection -RequiredScopes $RequiredScopes -TestScopes) -and (Test-MgGraphAccess -LogId $LogId -ClientId $ClientId)
                if (-not $reuse) {
                    if (Get-MgContext -ErrorAction SilentlyContinue) {
                        Write-LogAndHost -Message 'Disconnecting the existing Microsoft Graph connection and signing in again' -LogId $LogId -Severity 2
                        Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
                    }
                    switch ($PSCmdlet.ParameterSetName) {
                        'ClientSecret' {
                            Connect-MgGraphCustom -TenantId $TenantId -ClientId $ClientId -ClientSecret $ClientSecret
                        }
                        'ClientCertificateThumbprint' {
                            Write-LogAndHost -Message ("Connecting with certificate thumbprint '{0}'" -f $ClientCertificateThumbprint) -LogId $LogId -ForegroundColor Cyan
                            Connect-MgGraphCustom -TenantId $TenantId -ClientId $ClientId -ClientCertificateThumbprint $ClientCertificateThumbprint
                        }
                        'UseDeviceAuthentication' {
                            Connect-MgGraphCustom -TenantId $TenantId -ClientId $ClientId -UseDeviceAuthentication -RequiredScopes $RequiredScopes
                        }
                        'Interactive' {
                            Connect-MgGraphCustom -TenantId $TenantId -ClientId $ClientId -RequiredScopes $RequiredScopes
                        }
                    }

                    if (-not (Test-MgConnection -LogId $LogId -RequiredScopes $RequiredScopes -TestScopes)) {
                        throw "Failed to connect to Microsoft Graph with the required scopes"
                    }
                    if (-not (Test-MgGraphAccess -LogId $LogId -ClientId $ClientId)) {
                        throw "Connected to Microsoft Graph, but a test request to Intune failed. Check the log for the reason"
                    }
                }
            }
            #endregion

            #region Select_Applications
            New-VerboseRegion -Message 'Selecting applications' -ForegroundColor 'Gray'

            $paramsToPassApp = @{ LogId = $LogId }
            if ($AppId) { $paramsToPassApp['AppId'] = $AppId }
            if ($AppName) { $paramsToPassApp['AppName'] = $AppName }
            if ($ExcludePMPC) { $paramsToPassApp['ExcludePMPC'] = $true }
            if ($ExcludeFilter) { $paramsToPassApp['ExcludeFilter'] = $ExcludeFilter }
            if ($NoOgv) { $paramsToPassApp['NoOgv'] = $true }

            $selectedApplications = @(Get-AppList @paramsToPassApp)

            if ($selectedApplications.Count -eq 0) {
                Write-LogAndHost -Message ("No applications were found or selected for '{0}{1}'. Nothing to do" -f $AppName, ($AppId -join ',')) -LogId $LogId -Severity 2
                return
            }

            Write-LogAndHost -Message ("Processing {0} application(s): {1}" -f $selectedApplications.Count, (($selectedApplications | ForEach-Object { "'{0}' ({1})" -f $_.LocalizedDisplayName, $_.Id }) -join ', ')) -LogId $LogId -ForegroundColor Cyan
            #endregion

            #region Get_App_And_DeploymentType_Details
            New-VerboseRegion -Message 'Getting application and deployment type details' -ForegroundColor 'Gray'

            $appArray = New-Object System.Collections.Generic.List[object]
            $deploymentTypeArray = New-Object System.Collections.Generic.List[object]

            foreach ($application in $selectedApplications) {
                $appResult = New-MigrationResult -ApplicationId $application.Id -ApplicationName $application.LocalizedDisplayName
                try {
                    $appResult.Stage = 'ApplicationDetails'
                    $appInfo = @(Get-AppInfo -ApplicationName @($application))[0]
                    if (-not $appInfo) { throw "Get-AppInfo returned nothing" }
                    $appArray.Add($appInfo)

                    $appResult.Stage = 'DeploymentTypeDetails'
                    $appDeploymentTypes = @(Get-DeploymentTypeInfo -ApplicationId $appInfo.Id | ForEach-Object { $_ })
                    if ($appDeploymentTypes.Count -eq 0) {
                        $appResult.Status = 'Skipped'
                        $appResult.Message = 'The application has no deployment types'
                        $results.Add($appResult)
                        continue
                    }
                    foreach ($deploymentType in $appDeploymentTypes) { $deploymentTypeArray.Add($deploymentType) }
                }
                catch {
                    $appResult.Status = 'Failed'
                    $appResult.Message = $_.Exception.Message
                    $results.Add($appResult)
                    Write-LogAndHost -Message ("Application '{0}' failed at {1}: {2}" -f $application.LocalizedDisplayName, $appResult.Stage, $_.Exception.Message) -LogId $LogId -Severity 3
                }
            }
            #endregion

            #region Content_Info
            $contentByDeploymentType = @{}
            foreach ($deploymentType in $deploymentTypeArray) {
                if (-not $deploymentType.InstallContent) { continue }
                try {
                    $contentByDeploymentType[$deploymentType.LogicalName] = Get-ContentInfo `
                        -InstallContent $deploymentType.InstallContent `
                        -UninstallContent ([string]$(if ($deploymentType.UninstallContent) { $deploymentType.UninstallContent } else { $deploymentType.InstallContent })) `
                        -UninstallSetting $(if ($deploymentType.UnInstallSetting) { [string]$deploymentType.UnInstallSetting } else { 'SameAsInstall' }) `
                        -ApplicationId $deploymentType.Application_Id `
                        -ApplicationName $deploymentType.ApplicationName `
                        -DeploymentTypeLogicalName $deploymentType.LogicalName `
                        -DeploymentTypeName $deploymentType.Name `
                        -InstallCommandLine ([string]$deploymentType.InstallCommandLine)
                }
                catch {
                    Write-LogAndHost -Message ("Could not get content details for '{0}': {1}" -f $deploymentType.Name, $_.Exception.Message) -LogId $LogId -Severity 2
                }
            }
            #endregion

            #region Exporting_Csv_data
            New-VerboseRegion -Message 'Exporting collected data to Csv' -ForegroundColor 'Gray'
            $detailsFolder = Join-Path -Path $workingFolder_Root -ChildPath 'Details'

            if ($appArray.Count -gt 0) {
                Export-CsvDetails -Name 'Applications' -Data ($appArray | Select-Object -Property * -ExcludeProperty IconData) -Path $detailsFolder
            }
            if ($deploymentTypeArray.Count -gt 0) {
                $deploymentTypeCsv = $deploymentTypeArray | Select-Object -Property * -ExcludeProperty DetectionRules, DetectionScriptContent, DetectionMethodBody, ReturnCodes
                Export-CsvDetails -Name 'DeploymentTypes' -Data $deploymentTypeCsv -Path $detailsFolder
            }
            if ($DownloadContent -and $contentByDeploymentType.Count -gt 0) {
                Export-CsvDetails -Name 'Content' -Data @($contentByDeploymentType.Values) -Path $detailsFolder
            }
            #endregion

            #region Exporting_Icons
            if ($ExportIcon) {
                New-VerboseRegion -Message 'Exporting icon(s)' -ForegroundColor 'Gray'
                foreach ($applicationIcon in $appArray) {
                    if ([string]::IsNullOrWhiteSpace($applicationIcon.IconData)) {
                        Write-LogAndHost -Message ("No icon data found for '{0}'. Skipping icon export" -f $applicationIcon.Name) -LogId $LogId -Severity 2
                        continue
                    }
                    try {
                        Export-Icon -AppName $applicationIcon.Name -IconPath $applicationIcon.IconPath -IconData $applicationIcon.IconData
                    }
                    catch {
                        Write-LogAndHost -Message ("Could not export the icon for '{0}': {1}" -f $applicationIcon.Name, $_.Exception.Message) -LogId $LogId -Severity 2
                    }
                }
            }
            #endregion

            #region Process_DeploymentTypes
            New-VerboseRegion -Message 'Processing deployment types' -ForegroundColor 'Gray'

            # ConfigMgr data has been read. Packaging and uploads work on files, so leave the site drive
            Push-Location -LiteralPath $workingFolder_Root
            $pushedLocation = $true

            foreach ($deploymentType in $deploymentTypeArray) {

                # Fresh state for every deployment type. Nothing carries over from the previous one
                $app = $appArray | Where-Object { $_.LogicalName -eq $deploymentType.Application_LogicalName } | Select-Object -First 1
                $result = New-MigrationResult -ApplicationId $deploymentType.Application_Id -ApplicationName $deploymentType.ApplicationName -DeploymentType $deploymentType.Name
                $result.Warnings = $deploymentType.Warnings
                $result.RequirementsNotMigrated = $deploymentType.Requirements
                $content = $null
                $intuneWinPath = $null
                $createdAppId = $null

                Write-LogAndHost -Message ("Working on '{0}' / '{1}'" -f $deploymentType.ApplicationName, $deploymentType.Name) -LogId $LogId -ForegroundColor Cyan -NewLine

                try {
                    if ($contentByDeploymentType.ContainsKey($deploymentType.LogicalName)) {
                        $content = $contentByDeploymentType[$deploymentType.LogicalName]
                    }

                    $win32AppFolderName = if ($content) { $content.Win32app_Destination } else {
                        "{0}\{1}" -f ([string]$deploymentType.ApplicationName -replace $invalidChars, '_').TrimEnd('.', ' '), ([string]$deploymentType.Name -replace $invalidChars, '_').TrimEnd('.', ' ')
                    }
                    $outputFolder = Join-Path -Path "$workingFolder_Root\Win32Apps" -ChildPath $win32AppFolderName

                    if (($DownloadContent -or $PackageApps) -and -not $content) {
                        throw "The deployment type has no content location, so it can't be downloaded or packaged"
                    }

                    if ($DownloadContent) {
                        $result.Stage = 'DownloadContent'
                        Get-ContentFiles -Source $content.Install_Source -Destination $content.Install_Destination -DeploymentTypeName $deploymentType.Name
                        if ($content.Uninstall_Setting -eq 'Different') {
                            Get-ContentFiles -Source $content.Uninstall_Source -Destination $content.Uninstall_Destination -Flags 'UninstallDifferent' -DeploymentTypeName $deploymentType.Name
                        }
                    }

                    if ($PackageApps) {
                        $result.Stage = 'Package'
                        $paramsToPassIntuneWin = @{
                            ContentFolder = if ($DownloadContent) { $content.Install_Destination } else { $content.Install_Source }
                            OutputFolder  = $outputFolder
                            SetupFile     = [string]$deploymentType.InstallCommandLine
                        }
                        if ($OverrideIntuneWin32FileName) { $paramsToPassIntuneWin['OverrideIntuneWin32FileName'] = $OverrideIntuneWin32FileName }
                        $intuneWinPath = New-IntuneWin @paramsToPassIntuneWin
                        $result.IntuneWinFile = $intuneWinPath
                        $tooLarge = Test-IntuneWinTooLarge -Path $intuneWinPath -MaxAppSizeGB $MaxAppSizeGB
                        if ($tooLarge -and -not $CreateApps) {
                            $result.Warnings = (@($result.Warnings, $tooLarge) | Where-Object { $_ }) -join ' | '
                            Write-LogAndHost -Message $tooLarge -LogId $LogId -Severity 2
                        }
                    }

                    if ($CreateApps) {

                        $result.Stage = 'Detection'
                        if (-not $deploymentType.DetectionSupported) {
                            $result.Status = 'Skipped'
                            $result.Message = "The detection method needs to be recreated manually: {0}" -f $deploymentType.DetectionIssues
                            Write-LogAndHost -Message $result.Message -LogId $LogId -Severity 2
                            continue
                        }

                        if (-not $intuneWinPath) {
                            $existing = Get-ChildItem -LiteralPath $outputFolder -Filter '*.intunewin' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                            if (-not $existing) { throw ("No .intunewin file found in '{0}'. Run with -PackageApps" -f $outputFolder) }
                            $intuneWinPath = $existing.FullName
                            $result.IntuneWinFile = $intuneWinPath
                        }

                        # Intune's size limit. Checked before the app is created so nothing is left half made in Intune
                        $tooLarge = Test-IntuneWinTooLarge -Path $intuneWinPath -MaxAppSizeGB $MaxAppSizeGB
                        if ($tooLarge) {
                            $result.Status = 'Skipped'
                            $result.Message = $tooLarge
                            Write-LogAndHost -Message $result.Message -LogId $LogId -Severity 2
                            continue
                        }

                        $result.Stage = 'CreateApp'
                        $intuneWinInfo = Get-IntuneWinInfo -SetupFile $intuneWinPath

                        $multipleDeploymentTypes = @($deploymentTypeArray | Where-Object { $_.Application_LogicalName -eq $deploymentType.Application_LogicalName }).Count -gt 1
                        $appDisplayName = if ($multipleDeploymentTypes) { "{0} - {1}" -f $app.Name, $deploymentType.Name } else { $app.Name }

                        $maxExecutionTime = 60
                        [void][int]::TryParse([string]$deploymentType.MaxExecuteTime, [ref]$maxExecutionTime)

                        $paramsToPassWin32App = @{
                            Name                    = $appDisplayName
                            Description             = $(if ($app.Description) { $app.Description } else { $app.Name })
                            Publisher               = $(if ([string]::IsNullOrWhiteSpace($app.Publisher)) { 'Not Specified' } else { $app.Publisher })
                            AppVersion              = [string]$app.Version
                            InformationURL          = [string]$app.InfoUrl
                            PrivacyURL              = [string]$app.PrivacyUrl
                            Notes                   = $Win32AppNotes
                            LargeIcon               = [string]$app.IconData
                            Path                    = $outputFolder
                            FileName                = [string]$intuneWinInfo.FileName
                            SetupFile               = [string]$intuneWinInfo.SetupFile
                            InstallCommandLine      = [string]$deploymentType.InstallCommandLine
                            UninstallCommandLine    = [string]$deploymentType.UninstallCommandLine
                            InstallExperience       = $deploymentType.InstallExperience
                            RestartBehavior         = $deploymentType.RestartBehavior
                            MaxExecutionTime        = $maxExecutionTime
                            AllowAvailableUninstall = $AllowAvailableUninstall
                            ReturnCodes             = @($deploymentType.ReturnCodes)
                            DetectionRules          = @($deploymentType.DetectionRules)
                        }

                        $win32AppJson = New-IntuneWinFramework @paramsToPassWin32App

                        $response = Invoke-MgGraphRequestCustom -Resource 'deviceAppManagement/mobileApps' -Method POST -Body $win32AppJson
                        if (-not $response.id) { throw "Graph did not return an Id for the new Win32 app" }
                        $createdAppId = $response.id
                        $result.IntuneAppId = $createdAppId
                        Write-LogAndHost -Message ("Created the Win32 app '{0}' with Id '{1}'" -f $appDisplayName, $createdAppId) -LogId $LogId -ForegroundColor Green

                        $result.Stage = 'UploadContent'
                        $encryptionInfo = Get-IntuneWinEncryptionInfo -FilePath $intuneWinPath
                        if (-not $encryptionInfo) { throw "Could not read the encryption details from '$intuneWinPath'" }
                        $sizeEncrypted = (Get-Item -LiteralPath $encryptionInfo.intuneWinPath).Length
                        $contentApplicationInfo = $encryptionInfo.contentApplicationInfo | ConvertFrom-Json

                        $contentRequest = New-IntuneWinContentRequest -Name $contentApplicationInfo.fileName -SizeUnencrypted $contentApplicationInfo.unencryptedContentSize -SizeEncrypted $sizeEncrypted -IsDependency $false
                        if (-not $contentRequest) { throw "Could not build the content request" }

                        $sasUri = Get-SasUri -Win32AppId $createdAppId -ContentRequest ($contentRequest | ConvertTo-Json -Depth 5 -Compress)

                        Invoke-StorageUpload -Win32AppId $createdAppId -ContentVersion $sasUri.contentVersion -ContentFileId $sasUri.contentRequestId -SasUri $sasUri.contentReady.azureStorageUri -FilePath $encryptionInfo.intuneWinPath | Out-Null

                        $result.Stage = 'CommitContent'
                        Invoke-IntuneContentCommit -Win32AppId $createdAppId -EncryptionInfo $encryptionInfo.encryptionDetails -ContentVersion $sasUri.contentVersion -ContentRequestId $sasUri.contentRequestId -TimeoutSeconds ($UploadTimeoutMinutes * 60) | Out-Null

                        Write-LogAndHost -Message ("Migration complete. '{0}' was migrated to Intune with App Id '{1}'" -f $appDisplayName, $createdAppId) -LogId $LogId -ForegroundColor Green
                    }

                    $result.Stage = 'Done'
                    $result.Status = 'Success'
                }
                catch {
                    $result.Status = 'Failed'
                    $result.Message = $_.Exception.Message
                    Write-LogAndHost -Message ("'{0}' / '{1}' failed at {2}: {3}" -f $deploymentType.ApplicationName, $deploymentType.Name, $result.Stage, $_.Exception.Message) -LogId $LogId -Severity 3

                    # Don't leave a Win32 app with no content behind, unless asked to
                    if ($createdAppId -and -not $KeepFailedApps) {
                        try {
                            Invoke-MgGraphRequestCustom -Resource ("deviceAppManagement/mobileApps/{0}" -f $createdAppId) -Method DELETE | Out-Null
                            $result.Message = "{0} The partially created Intune app '{1}' was deleted." -f $result.Message, $createdAppId
                            $result.IntuneAppId = $null
                            Write-LogAndHost -Message ("Deleted the partially created Intune app '{0}'" -f $createdAppId) -LogId $LogId -Severity 2
                        }
                        catch {
                            Write-LogAndHost -Message ("Could not delete the partially created Intune app '{0}': {1}" -f $createdAppId, $_.Exception.Message) -LogId $LogId -Severity 3
                        }
                    }
                }
                finally {
                    $results.Add($result)
                }
            }
            #endregion
        }
        catch {
            Write-LogAndHost -Message ("The run stopped: {0}" -f $_.Exception.Message) -LogId $LogId -Severity 3
            $fatal = New-MigrationResult -ApplicationName '(run)'
            $fatal.Status = 'Failed'
            $fatal.Message = $_.Exception.Message
            $results.Add($fatal)
        }
        finally {
            if ($pushedLocation) { Pop-Location }

            if ($results.Count -gt 0) {
                $resultsFile = Join-Path -Path (Join-Path -Path $workingFolder_Root -ChildPath 'Details') -ChildPath ("MigrationResults_{0}.csv" -f $runStamp)
                try {
                    if (-not (Test-Path -Path (Split-Path -Path $resultsFile -Parent))) {
                        New-Item -Path (Split-Path -Path $resultsFile -Parent) -ItemType Directory -Force | Out-Null
                    }
                    $results | Export-Csv -Path $resultsFile -NoTypeInformation -Encoding UTF8
                    Write-LogAndHost -Message ("Results written to '{0}'" -f $resultsFile) -LogId $LogId -ForegroundColor Cyan -NewLine
                }
                catch {
                    Write-LogAndHost -Message ("Could not write the results file: {0}" -f $_.Exception.Message) -LogId $LogId -Severity 3
                }

                $summary = $results | Group-Object -Property Status | ForEach-Object { "{0}: {1}" -f $_.Name, $_.Count }
                Write-LogAndHost -Message ("Summary - {0}" -f ($summary -join ', ')) -LogId $LogId -ForegroundColor Cyan
                $results | Format-Table -Property ApplicationName, DeploymentType, Status, Stage, IntuneAppId -AutoSize | Out-String | Write-Host
            }

            Get-ScriptEnd -LogId $LogId -NoPrompt:$NoPrompt
        }
    }
}
