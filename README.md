# Win32App Migration Tool
 
 ![alt text](https://byteben.com/bb/Downloads/GitHub/Win32AppMigrationTool_0.jpg)  
  ![alt text](https://byteben.com/bb/Downloads/GitHub/Win32AppMigrationTool_6.jpg) 
   
## Synopsis  
  
The Win32 App Migration Tool is designed to inventory ConfigMgr Applications and Deployment Types, build .intunewin files and create Win3Apps in The MEM Admin Center.  
  
Instead of manually checking Application and Deployment Type information and gathering content to build Win32apps, the Win32App Migration Tool is designed to do that for you. Currently, the Application and Deployment Type information is gathered and a .Intunewin file is created. We are also exporting the logo for the selected Application(s).  
  
** The Win32App Migration Tool is still in BETA so I would welcome any feedback or suggestions for improvement. Reach out on Twitter to DM @byteben (DM's are open)**  
  
## Requirements  

- **Configuration Manager Console** The console must be installed on the machine you are running the Win32App Migration Tool from. The following path should resolve true: $ENV:SMS_ADMIN_UI_PATH 
- **Local Administrator** The default Working folder is $ENV:SystemDrive\Win32AppMigrationTool. You will need permissions to create this directory on the System Drive  
- **Role** The necessary permissions to run the Configuration Manager cmdlet **Get-CMApplication**  
- **Content Folder** Read permissions to the content source for the Deployment Types that will be exported  
  
## Getting Started  
  
  **1. Install-Module Win32AppMigrationTool**  
  **2. New-Win32App**  -SiteCode "BB1" -ProviderMachineName "SCCM1.byteben.com" -AppName "Microsoft Edge Chromium *"  
  **3. Use Information from the CSVs to build a Win32App in Intune**  
    
The current release of the Win32 App Migration Tool will do the following:-  
  
- Download the Win32app Content Prep Tool to %WorkingDirectory\ContentPrepTool
- Export .intunewin files to %WorkingDirectory\Win32Apps\<Application GUID>\<Deployment Type GUID>  
- Export Application Details to %WorkingDirectory\Details\Applications.csv  
- Export Deployment Type Details to %WorkingDirectory\Details\DeploymentTypes.csv  
- Export Content Details to %WorkingDirectory\Details\Content.csv
- Copy Select Deployment Type Content to %WorkingDirectory\Content\<Deployment Type GUID>
- Export Application Logo(s) to %WorkingDirectory\Logos
- Log events to %WorkingDirectory\Logs\Main.log
  
After the BETA has been tested succesfully, the next stage of the project will be to build the Win32Apps in Intune automatically.
   
## Supported Install Commands  
  
The Win32App Migration Tool will automatically detect the deployment technology based on the program install command for the Deployment Type. The following installers are supported:-  
  
- PowerShell Scripts  
- .EXE  
- .MSI  
- .CMD  
- .BAT  
- .VBS  
  
## Important Information    
   
_**// Please use the tool with caution and test in your lab (dont be the guy or gal who tests in production). I accept no responsibility for loss or damage as a result of using these scripts //**_
   
## Troubleshooting  
  
Main.log in the %WorkingFolder%\Logs folder contains a detailed verbose output of the solution  
Get-Help New-Win32App  
 
## Parameters  
  
**.Parameter AppName**
Pass a string to the toll to search for applications in ConfigMgr
  
**.Parameter SiteCode**
Specify the Sitecode you wish to connect to

**.Parameter ProviderMachineName**
Specify the Site Server to connect to

**.Parameter ExportLogo**
When passed, the Application logo is decoded from base64 and saved to the Logos folder

**.Parameter WorkingFolder**
This is the working folder for the Win32AppMigration Tool. Care should be given when specifying the working folder because downloaded content can increase the working folder size considerably. The Following folders are created in this directory:-
  
-Content  
-ContentPrepTool  
-Details  
-Logos  
-Logs  
-Win32Apps  

**.Parameter PackageApps**
Pass this parameter to package selected apps in the .intunewin format

**.Parameter CreateApps**
Pass this parameter to create the Win32apps in Intune

**.Parameter ResetLog**
Pass this parameter to reset the log file

## Examples  
  
**.Example**
New-Win32App -SiteCode "BB1" -ProviderMachineName "SCCM1.byteben.com" -AppName "Microsoft Edge Chromium *"

**.Example**
New-Win32App -SiteCode "BB1" -ProviderMachineName "SCCM1.byteben.com" -AppName "Microsoft Edge Chromium *" -ExportLogo

**.Example**
New-Win32App -SiteCode "BB1" -ProviderMachineName "SCCM1.byteben.com" -AppName "Microsoft Edge Chromium *" -ExportLogo -PackageApps

**.Example**
New-Win32App -SiteCode "BB1" -ProviderMachineName "SCCM1.byteben.com" -AppName "Microsoft Edge Chromium *" -ExportLogo -PackageApps -CreateApps

**.Example**
New-Win32App -SiteCode "BB1" -ProviderMachineName "SCCM1.byteben.com" -AppName "Microsoft Edge Chromium *" -ExportLogo -PackageApps -CreateApps -ResetLog  
  
## Version History  
  
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

## Bugs  
  
- Handle Script exit better when an invalid parameter is passed to New-Win32App  
- Remove SetupFile name from Write-Host after successful .intunewin creation  
  
## Planned Improvements  
  
- Option to build .Intunewin files without downloading the Deployment Type content locally
- Gather Requirements, Detection Rules and Supercedence for Applications and Deployment Types
- Create the Win32app in Intune 
- ConfigMgr Console Extension (Thanks @TheNotoriousDRR)  
- ~~Add to PSGallery~~  
- ~~Add support for .VBS~~   
- ~~Convert to a Module~~  
  
## Screenshots  
  
**Application Selection**   
https://byteben.com/bb/Downloads/GitHub/Win32AppMigrationTool_1.jpg  
![alt text](https://byteben.com/bb/Downloads/GitHub/Win32AppMigrationTool_0.jpg)  
  
**Create Application Folders**  
https://byteben.com/bb/Downloads/GitHub/Win32AppMigrationTool_2.jpg  
![alt text](https://byteben.com/bb/Downloads/GitHub/Win32AppMigrationTool_2.jpg)  
  
**Create Deployment Folders**  
https://byteben.com/bb/Downloads/GitHub/Win32AppMigrationTool_3.jpg  
![alt text](https://byteben.com/bb/Downloads/GitHub/Win32AppMigrationTool_3.jpg)  
  
**Create Content Folders**  
https://byteben.com/bb/Downloads/GitHub/Win32AppMigrationTool_4.jpg  
![alt text](https://byteben.com/bb/Downloads/GitHub/Win32AppMigrationTool_4.jpg)  

**Create .Intunewin Files**  
https://byteben.com/bb/Downloads/GitHub/Win32AppMigrationTool_5.jpg  
![alt text](https://byteben.com/bb/Downloads/GitHub/Win32AppMigrationTool_6.jpg) 
