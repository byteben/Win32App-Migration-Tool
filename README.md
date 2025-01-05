# Win32App Migration Tool

 ![alt text](https://byteben.com/bb/Downloads/GitHub/MigTool3-AppSelection.jpg)  

## Watch the tool in action  
  
[![Watch the video](https://byteben.com/bb/Downloads/GitHub/YouTube-MigTool.jpg)](https://www.youtube.com/watch?v=xpQO5naqsnA)  
https://www.youtube.com/watch?v=xpQO5naqsnA  
  
## Synopsis  
  
The Win32 App Migration Tool is designed to inventory ConfigMgr Applications and Deployment Types, build .intunewin files and create Win3Apps in The Intune Admin Center.  
Instead of manually checking Application and Deployment Type information and gathering content to build Win32apps, the Win32App Migration Tool is designed to do that for you.
  
**Blog Post** https://msendpointmgr.com/2021/03/27/automatically-migrate-applications-from-configmgr-to-intune-with-the-win32app-migration-tool/

---

**LEGAL DISCLAIMER**

This solution is distributed under the **GNU GENERAL PUBLIC LICENSE**.

The PowerShell script provided is shared with the community *as-is*. The author and co-author(s) make no warranties or guarantees regarding its functionality, reliability, or suitability for any specific purpose.  
Please note that the script may need to be modified or adapted to fit your specific environment or requirements. It is recommended to thoroughly test the script in a non-production environment before using it in a live or critical system.  
The author and co-author(s) cannot be held responsible for any damages, losses, or adverse effects that may arise from the use of this script.  
You assume all risks and responsibilities associated with its usage.

---
  
## Development Status

  **STATUS: Generally Available (Preview)**  
  The Win32App Migration Tool is now Generally Available (in Preview) as of January 2025. I would welcome feedback or suggestions for improvement. Reach out on Twitter to DM @byteben (DM's are open)  
  
## Requirements  

- **Configuration Manager Console** The console must be installed on the machine you are running the Win32App Migration Tool from. The following path should resolve true: $ENV:SMS_ADMIN_UI_PATH
- **Local Administrator** The default Working folder is $ENV:SystemDrive\Win32AppMigrationTool. You will need permissions to create this directory on the System Drive  
- **Roles** Permission to run the Configuration Manager cmdlet **Get-CMApplication**  
- **Content Folder Permission** Read permissions to the content source for the Deployment Types that will be exported  
- **PowerShell 5.1**  PowerShell 7 is recommended
- **Internet Access** to download the Win32 Content Prep Tool
- **Microsoft.Graph.Authentication Module** Install-Module -Name Microsoft.Graph.Authentication (This is installed as part of the Win32AppMigrationTool Module if the -CreateApps parameter is passed)
- **Az.Storage Module** Install-Module -Name Az.Storage (This is installed as part of the Win32AppMigrationTool Module if the -CreateApps parameter is passed)
  
## Quick Start  
  
  **1. Install-Module Win32AppMigrationTool**  
  **2. New-Win32App** -ProviderMachineName "SCCM1.byteben.com" -AppName "Microsoft Edge Chromium *"  
  **3. Use Information from the CSVs to build a Win32 app in Intune**

  ```
  New-Win32App -ProviderMachineName <String> -AppName <String>
  ```

## Order of Operations  

The current release of the Win32 App Migration Tool will do the following:-  
  
- Download the Win32 app Content Prep Tool to %WorkingDirectory%\ContentPrepTool
- Export .intunewin files to %WorkingDirectory%\Win32Apps\<Application GUID>\<Deployment Type GUID>  
- Export Application Details to %WorkingDirectory%\Details\Applications.csv  
- Export Deployment Type Details to %WorkingDirectory%\Details\DeploymentTypes.csv  
- Export Content Details to %WorkingDirectory%\Details\Content.csv (If -DownloadContent parameter passed)  
- Copy Select Deployment Type Content to %WorkingDirectory%\Content\<Deployment Type GUID>  
- Export Application icons(s) to %WorkingDirectory%\Icons  
- Build Win32 app JSON payload body for Intune
- Convert detection to JSON for Intune
- Extract the IntunePackage.intunewin for upload
- Get encryption information for Intunewin
- Request Content Upload Uri from Intune
- Upload file in chunks to Intune
- Commit file to Intune
- Log events to %WorkingDirectory%\Logs\Main.log  
  
### 1. Environment Setup  
  
 ![alt text](https://byteben.com/bb/Downloads/GitHub/MigTool1-Env.jpg)  
  
### 2. Authentication  
  
 ![alt text](https://byteben.com/bb/Downloads/GitHub/MigTool2-Authentication.jpg)
  
### 3. Application Selection  
  
 ![alt text](https://byteben.com/bb/Downloads/GitHub/MigTool3-AppSelection.jpg)
  
### 4. Application Details Export  
  
 ![alt text](https://byteben.com/bb/Downloads/GitHub/MigTool4-AppDetails.jpg)
  
### 5. Deployment Type Details Export  
  
 ![alt text](https://byteben.com/bb/Downloads/GitHub/MigTool5-DeploymentTypeDetails.jpg)

### 6. Content Details Export  
  
 ![alt text](https://byteben.com/bb/Downloads/GitHub/MigTool6-ContentDetails.jpg)
  
### 7. Content Download  
  
 ![alt text](https://byteben.com/bb/Downloads/GitHub/MigTool7-ContentCopy.jpg)
  
### 8. CSV Export of Application Details  
  
 ![alt text](https://byteben.com/bb/Downloads/GitHub/MigTool8-CSVExport.jpg)
  
### 9. Icon Export  
  
 ![alt text](https://byteben.com/bb/Downloads/GitHub/MigTool9-IconExport.jpg)
  
### 10. Create an Intunewin  
  
 ![alt text](https://byteben.com/bb/Downloads/GitHub/MigTool10-CreateIntunewinjpg.jpg)

### 11. Create Win32App JSON Body  
  
 ![alt text](https://byteben.com/bb/Downloads/GitHub/MigTool11-CreateWin32AppJson.jpg)
  
### 12. Create the WIn32 app in Intune  
  
 ![alt text](https://byteben.com/bb/Downloads/GitHub/MigTool12-CreateWin32App.jpg)
  
  
## Important Information

_**// Please use the tool with caution and test in your lab (dont be the person who tests in production). I accept no responsibility for loss or damage as a result of using these scripts //**_

## Troubleshooting  
  
**Main.log** in the **%WorkingFolder%\Logs** folder contains a detailed verbose output of the solution  
  
 ![alt text](https://byteben.com/bb/Downloads/GitHub/Main-Log.jpg)

## Parameters  

### -SiteCode

The Site Code of the ConfigMgr Site. The Site Code must be only 3 alphanumeric characters. This is an optional parameter. If not passed, the script will attempt to get the Site Code automatically from WMI. If the Site Code cannot be determined, the script will exit with an error message after 3 invalid attempts.

```yaml
Type: String
Parameter Sets: (All)

Required: False
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

### -Parameter AllowAvailableUninstall

When passed, the AvailableUninstall value will be set to True when creating the Win32App

```yaml
Type: Boolean
Parameter Sets: (All)

Required: False
Position:
Default value:
Accept pipeline input: False
Accept wildcard characters: False
```

### -TenantId

Tenant Id or name to connect to.

```yaml
Type: String
Parameter Sets: ClientSecret, ClientCertificateThumbprint, UseDeviceAuthentication, Interactive

Required: True
Position:
Default value:
Accept pipeline input: False
Accept wildcard characters: False
```

### -ClientId

Client Id or name to connect to. Please create an App Registration in EntraId and avoid using the Microsoft Graph Command Line Tools client app.
The client app must have the following API permission: DeviceManagementApps.ReadWrite.All.

```yaml
Type: String
Parameter Sets: ClientSecret, ClientCertificateThumbprint, UseDeviceAuthentication, Interactive

Required: True
Position:
Default value:
Accept pipeline input: False
Accept wildcard characters: False
```

### -ClientSecret

If using a Client Secret for authentication, pass the secret here.
Certificates are recommended for production environments.

```yaml
Type: String
Parameter Sets: ClientSecret

Required: True
Position:
Default value:
Accept pipeline input: False
Accept wildcard characters: False
```

### -ClientCertificateThumbprint

Certificates are recommended for production environments. Pass the thumbprint of the certificate to use for authentication to the client app.
You must have the private key and the public key must have been uploaded to the App Registration in Entra Id.

```yaml
Type: String
Parameter Sets: ClientCertificateThumbprint

Required: True
Position:
Default value:
Accept pipeline input: False
Accept wildcard characters: False
```

### -UseDeviceAuthentication

Generates a token using device authentication.

```yaml
Type: Switch
Parameter Sets: UseDeviceAuthentication

Required: True
Position:
Default value:
Accept pipeline input: False
Accept wildcard characters: False
```

## Examples  
  
The following examples will export information from ConfigMgr but not create the Win32Apps in Intune. 
  
  ```
New-Win32App -ProviderMachineName "SCCM1.byteben.com" -AppName "Microsoft Edge Chromium *"
  ```
  ```
New-Win32App -ProviderMachineName "SCCM1.byteben.com" -AppName "Microsoft Edge Chromium *" -DownloadContent  
  ```
  ```
New-Win32App -ProviderMachineName "SCCM1.byteben.com" -AppName "Microsoft Edge Chromium *" -ExportLogo  
  ```
  ```
New-Win32App -ProviderMachineName "SCCM1.byteben.com" -AppName "Microsoft Edge Chromium *" -ExportLogo -PackageApps  
  ```
  ```
New-Win32App -ProviderMachineName "SCCM1.byteben.com" -AppName "Microsoft Edge Chromium *" -ExportLogo -PackageApps -ResetLog  
  ```
  ```
New-Win32App -ProviderMachineName "SCCM1.byteben.com" -AppName "Microsoft Edge Chromium *" -ExportLogo -PackageApps -ResetLog -NoOGV  
  ```
  ```
New-Win32App -ProviderMachineName "SCCM1.byteben.com" -AppName "Microsoft Edge Chromium *" -ExportLogo -PackageApps -ResetLog -ExcludePMPC
  ```
  ```
New-Win32App -ProviderMachineName "SCCM1.byteben.com" -AppName "Microsoft Edge Chromium *" -ExportLogo -PackageApps -ResetLog -ExcludePMPC -ExcludeFilter "Microsoft*" 
  ```
  ```
New-Win32App -ProviderMachineName "SCCM1.byteben.com" -AppName "Microsoft Edge Chromium *" -ExportLogo -PackageApps -CreateApps -ResetLog -ExcludePMPC
  ```

## Examples 2 
  
The following examples will export information from ConfigMgr and will create the Win32Apps in Intune. 
  
  ```
New-Win32App -ProviderMachineName "SCCM1.byteben.com" -AppName "Microsoft Edge Chromium *" -CreateApps ExportLogo -PackageApps -ResetLog -TenantId "yourtenant.onmicrosoft.com" -ClientId "yourclientid" -ClientSecret "yourclientsecret"
  ```
  ```
New-Win32App -ProviderMachineName "SCCM1.byteben.com" -AppName "Microsoft Edge Chromium *" -CreateApps ExportLogo -PackageApps -ResetLog -TenantId "yourtenant.onmicrosoft.com" -ClientId "yourclientid" -ClientCertificateThumbprint "yourclientcertthumbprint"
  ```
  ```
