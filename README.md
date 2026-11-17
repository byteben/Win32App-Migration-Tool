
# Win32 App Migration Tool
![PowerShell Gallery](https://img.shields.io/powershellgallery/dt/Win32AppMigrationTool?color=green&label=PowerShell%20Gallery%20Downloads&logo=powershell)  
![License: Non-Commercial](https://img.shields.io/badge/License-Non--Commercial-purple.svg)  
![PowerShell](https://img.shields.io/badge/PowerShell-v7%2B-yellow?logo=powershell)  
![PowerShell](https://img.shields.io/badge/PowerShell-v5.1-blue?logo=powershell)  

![Tool Preview](https://raw.githubusercontent.com/byteben/byteben.com/main/repo-files/downloads-GitHub/MigTool3-AppSelection.jpg)  

---

## 📝 Synopsis

The **Win32AppMigrationTool** is designed to inventory **ConfigMgr Applications** and Deployment Types, build .intunewin files, and create win32 apps in the Intune.  

---

## 🔐 License

This tool is free for **personal, non-commercial use**, such as learning, research and testing in your own lab.

It is **not licensed for commercial or business use**. That includes using it to manage an organization's devices or environments, using it to deliver services to clients, and selling it or including it in a product or service.

You may modify the code for your own personal use, but you may not share or redistribute the original or modified versions.

Full terms are in the [License](License) file. Versions 2.0.20 to 3.0.03 were released under the GNU GPL and remain under those terms.

---

## ⚖️ Legal Disclaimer

This tool is provided as-is, without warranty of any kind. The author and any co-author(s) make no guarantees about its functionality, reliability, or suitability for any purpose.

**Use it at your own risk.** You are responsible for testing it in your own lab and checking its results before relying on them. The author and co-author(s) are not responsible for any damage, loss, or unintended effects resulting from its use.

---
  
## 👩‍💻 Development Status

  **STATUS: Preview**  
  The Win32App Migration Tool is in Preview.  
  
## 📋 Requirements  

- **Configuration Manager Console** The console must be installed on the machine you are running the Win32App Migration Tool from. The following path should resolve true: $ENV:SMS_ADMIN_UI_PATH
- **Local Administrator** The default Working folder is $ENV:SystemDrive\Win32AppMigrationTool. You will need permissions to create this directory on the System Drive  
- **Roles** Permission to run the Configuration Manager cmdlet **Get-CMApplication**  
- **Content Folder Permission** Read permissions to the content source for the Deployment Types that will be exported  
- **PowerShell 5.1 or 7** Both are supported. The ConfigurationManager module supports PowerShell 7 from ConfigMgr 2103
- **Internet Access** to download the Win32 Content Prep Tool
- **Microsoft.Graph.Authentication Module** Install-Module -Name Microsoft.Graph.Authentication (This is installed as part of the Win32AppMigrationTool Module if the -CreateApps parameter is passed)
- **Entra ID App Registration** For interactive sign-in, add two redirect URIs under **Authentication > Mobile and desktop applications**: **http://localhost** and **ms-appx-web://Microsoft.AAD.BrokerPlugin/<your client id>**. Recent versions of Microsoft.Graph.Authentication sign in through the Windows broker (WAM) and need the second one; without it the sign-in window can fail. `-UseDeviceAuthentication`, `-ClientSecret` and `-ClientCertificateThumbprint` don't use these redirect URIs
  
## 👏 Quick Start  
  
  **1. Install-Module Win32AppMigrationTool**  
  **2. New-Win32App** -ProviderMachineName "SCCM1.byteben.com" -AppName "Microsoft Edge Chromium *"  
  **3. Use Information from the CSVs to build a Win32 app in Intune**

  ```
  New-Win32App -ProviderMachineName <String> -AppName <String>
  ```

## 🔢 Order of Operations  

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
- Write a results file to %WorkingDirectory%\Details\MigrationResults_<timestamp>.csv with one row per deployment type (Success, Skipped or Failed, the stage reached, the Intune app Id and the reason)  

Each deployment type is processed on its own. If one fails, it's recorded in the results file and the tool moves on to the next one.

## 🔎 What is migrated

| ConfigMgr | Intune |
| --- | --- |
| Install / uninstall command | Install / uninstall command. If the deployment type has no uninstall command, `cmd.exe /c exit 1` is used and a warning is logged |
| Installation behavior (System, User, "Install for system if resource is device; otherwise user") | Install behavior system / user. The third option becomes system, with a warning |
| Maximum allowed run time | Maximum installation time |
| Program "Behavior" restart setting (Determine behavior based on return codes, No specific action, App may force a restart, Configuration Manager client will force a restart) | Device restart behavior (basedOnReturnCode, suppress, allow, force) |
| Return codes (Success, Failure, Soft reboot, Hard reboot, Fast retry) | Return codes (success, failed, softReboot, hardReboot, retry), added to the Intune defaults |
| Detection: Windows Installer product code (MSI deployment types) | Product code rule |
| Detection: PowerShell script | PowerShell script rule, keeping "Run script as 32-bit process" |
| Detection: file or folder exists; file version, size (whole MB), date modified, date created; folder dates | File system rule |
| Detection: registry value exists, or String / Integer / Version comparison; registry key exists | Registry rule |
| Detection: MSI product code exists or version comparison | Product code rule |

These detections can't be migrated as they are. The deployment type is marked **Skipped** in the results file, with the reason, so you can add the detection in Intune by hand:

- VBScript or JScript detection scripts (Intune runs PowerShell only)
- Rules joined with **Or** (Intune requires every rule to be true)
- Operators Intune doesn't have: Between, One of, None of, Begins with, Ends with, Contains and their negations
- File size comparisons that aren't a whole number of MB
  
### 1. Environment Setup  
  
 ![alt text](https://raw.githubusercontent.com/byteben/byteben.com/main/repo-files/downloads-GitHub/MigTool1-Env.jpg)  
  
### 2. Authentication  
  
 ![alt text](https://raw.githubusercontent.com/byteben/byteben.com/main/repo-files/downloads-GitHub/MigTool2-Authentication.jpg)
  
### 3. Application Selection  
  
 ![alt text](https://raw.githubusercontent.com/byteben/byteben.com/main/repo-files/downloads-GitHub/MigTool3-AppSelection.jpg)
  
### 4. Application Details Export  
  
 ![alt text](https://raw.githubusercontent.com/byteben/byteben.com/main/repo-files/downloads-GitHub/MigTool4-AppDetails.jpg)
  
### 5. Deployment Type Details Export  
  
 ![alt text](https://raw.githubusercontent.com/byteben/byteben.com/main/repo-files/downloads-GitHub/MigTool5-DeploymentTypeDetails.jpg)

### 6. Content Details Export  
  
 ![alt text](https://raw.githubusercontent.com/byteben/byteben.com/main/repo-files/downloads-GitHub/MigTool6-ContentDetails.jpg)
  
### 7. Content Download  
  
 ![alt text](https://raw.githubusercontent.com/byteben/byteben.com/main/repo-files/downloads-GitHub/MigTool7-ContentCopy.jpg)
  
### 8. CSV Export of Application Details  
  
 ![alt text](https://raw.githubusercontent.com/byteben/byteben.com/main/repo-files/downloads-GitHub/MigTool8-CSVExport.jpg)
  
### 9. Icon Export  
  
 ![alt text](https://raw.githubusercontent.com/byteben/byteben.com/main/repo-files/downloads-GitHub/MigTool9-IconExport.jpg)
  
### 10. Create an Intunewin  
  
 ![alt text](https://raw.githubusercontent.com/byteben/byteben.com/main/repo-files/downloads-GitHub/MigTool10-CreateIntunewinjpg.jpg)

### 11. Create Win32App JSON Body  
  
 ![alt text](https://raw.githubusercontent.com/byteben/byteben.com/main/repo-files/downloads-GitHub/MigTool11-CreateWin32AppJson.jpg)
  
### 12. Create the WIn32 app in Intune  
  
 ![alt text](https://raw.githubusercontent.com/byteben/byteben.com/main/repo-files/downloads-GitHub/MigTool12-CreateWin32App.jpg)
  
  
## ⚠️ Important Information

_**// Please use the tool with caution and test in your lab (dont be the person who tests in production). I accept no responsibility for loss or damage as a result of using these scripts //**_

## Troubleshooting  
  
**Main.log** in the **%WorkingFolder%\Logs** folder contains a detailed verbose output of the solution  
  
 ![alt text](https://raw.githubusercontent.com/byteben/byteben.com/main/repo-files/downloads-GitHub/Main-Log.jpg)

## ↘️ Parameters  

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

Pass an app name to search for matching applications in ConfigMgr. You can use * as a wildcard e.g. "Microsoft*" or "\*Reader". Out-GridView lets you select one of the matching applications. To process several, pass -NoOgv (every match is processed) or -AppId. Not required when -AppId is passed

```yaml
Type: String
Parameter Sets: (All)

Required: False
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

When passed, the Out-Gridview is suppressed and every application matching $AppName (after -ExcludeFilter and -ExcludePMPC) is processed

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

Pass $true to allow users to uninstall the app from the Company Portal when it has an Available assignment. Default $false

```yaml
Type: Boolean
Parameter Sets: (All)

Required: False
Position:
Default value:
Accept pipeline input: False
Accept wildcard characters: False
```

### -AppId

One or more ConfigMgr application CI_IDs to process. The search and Out-GridView are skipped, so the tool can run unattended. Use instead of, or as well as, -AppName

```yaml
Type: String[]
Parameter Sets: (All)

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -MaxAppSizeGB

The largest .intunewin, in GB (1,000,000,000 bytes), that will be uploaded. Intune limits Win32 apps to 30 GB per app, so a larger package is skipped before the Intune app is created, with the reason in the results file. With -PackageApps alone, an oversized package gets a warning. Only raise it if Microsoft has raised the limit for your tenant

```yaml
Type: Int32
Parameter Sets: (All)

Required: False
Position: Named
Default value: 30
Accept pipeline input: False
Accept wildcard characters: False
```

### -UploadTimeoutMinutes

How long to wait for Intune to process uploaded content before giving up. Raise it for very large packages

```yaml
Type: Int32
Parameter Sets: (All)

Required: False
Position: Named
Default value: 30
Accept pipeline input: False
Accept wildcard characters: False
```

### -KeepFailedApps

If the content upload or commit fails after the Win32 app was created, the half-created app is deleted from Intune. Pass this switch to keep it

```yaml
Type: SwitchParameter
Parameter Sets: (All)

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -NoPrompt

Don't ask whether to disconnect from Microsoft Graph at the end of the run

```yaml
Type: SwitchParameter
Parameter Sets: (All)

Required: False
Position: Named
Default value: False
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
