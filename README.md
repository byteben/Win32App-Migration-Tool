# Win32App Migration Tool
 
 ![alt text](https://byteben.com/bb/Downloads/GitHub/Win32AppMigrationTool_10.jpg)  
   
## Synopsis  
  
The Win32 App Migration Tool is designed to inventory ConfigMgr Applications and Deployment Types, build .intunewin files and create Win3Apps in The Intune Admin Center.  
Instead of manually checking Application and Deployment Type information and gathering content to build Win32apps, the Win32App Migration Tool is designed to do that for you. 
  
**Blog Post** https://msendpointmgr.com/2021/03/27/automatically-migrate-applications-from-configmgr-to-intune-with-the-win32app-migration-tool/
  
  ## Development Status
  **STATUS: BETA**  
  The Win32App Migration Tool is still in BETA. I would welcome feedback or suggestions for improvement. Reach out on Twitter to DM @byteben (DM's are open)  
  After the BETA has been tested succesfully, the next stage of the project will be to build the Win32Apps in Intune automatically.  
  
## Requirements  

- **Configuration Manager Console** The console must be installed on the machine you are running the Win32App Migration Tool from. The following path should resolve true: $ENV:SMS_ADMIN_UI_PATH 
- **Local Administrator** The default Working folder is $ENV:SystemDrive\Win32AppMigrationTool. You will need permissions to create this directory on the System Drive  
- **Roles** Permission to run the Configuration Manager cmdlet **Get-CMApplication**  
- **Content Folder Permission** Read permissions to the content source for the Deployment Types that will be exported  
- **PowerShell 5.1**  
- **Internet Access** to download the Win32 Content Prep Tool 
  
## Quick Start  
  
  **1. Install-Module Win32AppMigrationTool**  
  **2. New-Win32App**  -SiteCode "BB1" -ProviderMachineName "SCCM1.byteben.com" -AppName "Microsoft Edge Chromium *"  
  **3. Use Information from the CSVs to build a Win32App in Intune** 

  ```
  New-Win32App [-SiteCode] <String> [[-ProviderMachineName] <String>] [[-AppName] <String[]>]
  ```
    
The current release of the Win32 App Migration Tool will do the following:-  
  
- Download the Win32app Content Prep Tool to %WorkingDirectory%\ContentPrepTool
- Export .intunewin files to %WorkingDirectory%\Win32Apps\<Application GUID>\<Deployment Type GUID>  
- Export Application Details to %WorkingDirectory%\Details\Applications.csv  
- Export Deployment Type Details to %WorkingDirectory%\Details\DeploymentTypes.csv  
- Export Content Details to %WorkingDirectory%\Details\Content.csv (If -DownloadContent parameter passed)  
- Copy Select Deployment Type Content to %WorkingDirectory%\Content\<Deployment Type GUID>  
- Export Application icons(s) to %WorkingDirectory%\Icons  
- Log events to %WorkingDirectory%\Logs\Main.log  
  
## Important Information    
   
_**// Please use the tool with caution and test in your lab (dont be the guy or gal who tests in production). I accept no responsibility for loss or damage as a result of using these scripts //**_
   
## Troubleshooting  
  
Main.log in the %WorkingFolder%\Logs folder contains a detailed verbose output of the solution  
 
## Parameters  

### -SiteCode
The Site Code of the ConfigMgr Site. he Site Code must be only 3 alphanumeric characters

```yaml
Type: String
Parameter Sets: (All)

Required: True
Position: 0
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
Validate Pattern: ^[a-zA-Z0-9]{3}$')]
```

### -ProviderMachineName
Server name that has an SMS Provider site system role

```yaml
Type: String
Parameter Sets: (All)

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Parameter AppName
Pass an app name to search for matching applications in ConfigMgr. You can use * as a wildcard e.g. "Microsoft*" or "\*Reader"

```yaml
Type: String
Parameter Sets: (All)

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: True
```

### -Parameter WorkingFolder
The working folder for the Win32AppMigration Tool. Care should be given when specifying the working folder because downloaded content can increase the working folder size considerably

```yaml
Type: String
Parameter Sets: (All)

Required: False
Position: 3
Default value: C:\Win32AppMigrationTool
Accept pipeline input: False
Accept wildcard characters: False
```

### -Parameter ExcludeFilter
Pass this parameter to exclude specific apps from the results. Accepts wildcards e.g. "Microsoft*"'

```yaml
Type: String
Parameter Sets: (All)

Required: False
Position: 4
Default value:
Accept pipeline input: False
Accept wildcard characters: True
```

### -Parameter Win32ContentPrepToolUri
URI for Win32 Content Prep Tool

```yaml
Type: String
Parameter Sets: (All)

Required: False
Position: 5
Default value: https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/raw/master/IntuneWinAppUtil.exe
Accept pipeline input: False
Accept wildcard characters: False
```

### -Parameter OverrideIntuneWin32FileName
Override intunewin filename. Default is the name calcualted from the install command line

```yaml
Type: String
Parameter Sets: (All)

Required: False
Position: 6
Default value:
Accept pipeline input: False
Accept wildcard characters: False
```

### -Parameter DownloadContent
DownloadContent: When passed, the content for the deployment type is saved locally to the working folder "Content"

```yaml
Type: Switch
Parameter Sets: (All)

Required: False
Position:
Default value:
Accept pipeline input: False
Accept wildcard characters: False
```

### -Parameter ExportIcon
When passed, the Application icon is decoded from base64 and saved to the '$WorkingFolder\Icons' folder

```yaml
Type: Switch
Parameter Sets: (All)

Required: False
Position:
Default value:
Accept pipeline input: False
Accept wildcard characters: False
```

### -Parameter PackageApps
Pass this parameter to package selected apps in the .intunewin format

```yaml
Type: Switch
Parameter Sets: (All)

Required: False
Position:
Default value:
Accept pipeline input: False
Accept wildcard characters: False
```

### -Parameter CreateApps
Pass this parameter to create the Win32apps in Intune

```yaml
Type: Switch
Parameter Sets: (All)

Required: False
Position:
Default value:
Accept pipeline input: False
Accept wildcard characters: False
```

### -Parameter ResetLog
Pass this parameter to reset the log file

```yaml
Type: Switch
Parameter Sets: (All)

Required: False
Position:
Default value:
Accept pipeline input: False
Accept wildcard characters: False
```

### -Parameter ExcludePMP
Pass this parameter to exclude apps created by PMPC from the results. Filter is applied to Application "Comments". string can be modified in Get-AppList Function

```yaml
Type: Switch
Parameter Sets: (All)

Required: False
Position:
Default value:
Accept pipeline input: False
Accept wildcard characters: False
```

### -Parameter NoOgv
When passed, the Out-Gridview is suppressed and the value entered for $AppName will be searched using Get-CMApplication -Fast

```yaml
Type: Switch
Parameter Sets: (All)

Required: False
Position:
Default value:
Accept pipeline input: False
Accept wildcard characters: False
```

### -Parameter NoOgv
When passed, the Out-Gridview is suppressed and the value entered for $AppName will be searched using Get-CMApplication -Fast

```yaml
Type: Switch
Parameter Sets: (All)

Required: False
Position:
Default value:
Accept pipeline input: False
Accept wildcard characters: False
```
  
## Examples  
  
  ```
New-Win32App -SiteCode "BB1" -ProviderMachineName "SCCM1.byteben.com" -AppName "Microsoft Edge Chromium *"
  ```
  ``` 
New-Win32App -SiteCode "BB1" -ProviderMachineName "SCCM1.byteben.com" -AppName "Microsoft Edge Chromium *" -DownloadContent  
  ```
  ``` 
New-Win32App -SiteCode "BB1" -ProviderMachineName "SCCM1.byteben.com" -AppName "Microsoft Edge Chromium *" -ExportLogo  
  ```
  ``` 
New-Win32App -SiteCode "BB1" -ProviderMachineName "SCCM1.byteben.com" -AppName "Microsoft Edge Chromium *" -ExportLogo -PackageApps  
  ```
  ``` 
New-Win32App -SiteCode "BB1" -ProviderMachineName "SCCM1.byteben.com" -AppName "Microsoft Edge Chromium *" -ExportLogo -PackageApps -CreateApps  
  ```
  ``` 
New-Win32App -SiteCode "BB1" -ProviderMachineName "SCCM1.byteben.com" -AppName "Microsoft Edge Chromium *" -ExportLogo -PackageApps -CreateApps -ResetLog  
  ```
  ``` 
New-Win32App -SiteCode "BB1" -ProviderMachineName "SCCM1.byteben.com" -AppName "Microsoft Edge Chromium *" -ExportLogo -PackageApps -CreateApps -ResetLog -NoOGV  
  ```
  ``` 
New-Win32App -SiteCode "BB1" -ProviderMachineName "SCCM1.byteben.com" -AppName "Microsoft Edge Chromium *" -ExportLogo -PackageApps -CreateApps -ResetLog -ExcludePMPC
  ```
  ``` 
New-Win32App -SiteCode "BB1" -ProviderMachineName "SCCM1.byteben.com" -AppName "Microsoft Edge Chromium *" -ExportLogo -PackageApps -CreateApps -ResetLog -ExcludePMPC -ExcludeFilter "Microsoft*" 
  ``` 
  
## Version History  
  
**Version 2.0.17 - 12/11/2023 - BETA**  
  
✅ Faster code  
✅ Complete refactor of code  
✅ Better error handling  
✅ Improved file structure so its easier to find app content 
✅ Retain CSV data each run  
✅ Option to rename intunewin to a custom name  
✅ We now track uninstall content if its different from the install content  
✅ Compare files on copy to ensure we grab all the correct source content  
✅ Progress on file copy (useful for when dealing with larger files)  
✅ Reduce the number of times we call Get-CMApplication to speed run-time  
✅ Application, Deployment Type and Content details stored in different arrays. We call them multiple times and its quicker to split this out  
✅ Improved Logging - we now support log entry that is compatible with cmtrace  
✅ Single instance storage of icons  
✅ Win32ContentPrep tool is always re-downloaded at run-time if the packageapps parameter is passed  
✅ Added option to exclude specific apps using a filter  
  
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
  
**Version 1.03.21.04 - 21/03/2021 - BETA**  
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
