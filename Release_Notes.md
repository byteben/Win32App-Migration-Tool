# Win32App Migration Tool - Release Notes

## 3.0.02 - General Availability - 03/01/2025  

✅ Fixed styling issue in New-FolderToCreate function  
✅ Added support for MSI detection methods  
✅ Fixed <https://github.com/byteben/Win32App-Migration-Tool/issues/23>

## 3.0.01 - General Availability - 01/01/2025

✅ New Branch for 3.0.01
✅ Removed dependency on MSAL.PS and replaced with Microsoft.Graph.Authentication  
✅ New Module Connect-MgGraphCustom to authenticate to the Microsoft Graph API  
✅ New Module Test-MgGraphConnection to test the connection to the Microsoft Graph API and required scopes  
✅ New Module Get-IntuneWinEncryptionDetails to get the encryption details of a .intunewin file  
✅ New-Module Get-IntuneWinInfo to get metadata of a .intunewin file to build the Win32 app JSON  
✅ New-Module Get-SasUri to generate a Sas Uri for uploading content to Azure Storage  
✅ New-Module Initialize-Module to handle module initialization like Microsoft.Graph.Authentication and Az.Storage  
✅ New-Module Invoke-IntuneContentCommit to commit content to Intune after uploading to Azure Storage  
✅ New-Module Invoke-MgGraphRequestCustom to make CRUD requests to the Microsoft Graph API  
✅ New-Module Invoke-StorageUpload to upload content to Azure Storage using the Az.Storage module  
✅ New-Module New-IntuneDetection to create detection method JSON for a Win32 app  
✅ New-Module New-IntuneFramework to create the body for requesting a Win32 app  
✅ New-Module New-IntuneWinContentRequest to create a content request blob for commital of a Win32 app content  
✅ New-Module Write-LogAndHost to write to both the log and console host thus removing duplication of the same Write-Log and Write-Host commands  
✅ Fixed an issue where we were not handling the difference indicators test correctly when comparing the source and destination folders  
✅ Improvement to when we download the Win32ContentPrepTool. We now only download if the packageapps parameter is passed and it has been more than 30 days since the last tool download  
✅ Improvement to Get-ScriptEnd. We now test if there is an active session with Get-MgContext and offer to disconnect or leave the session connected  
✅ Improvement in the Win32 app JSON creation. We now handle -AllowAvailableInstall ($true/$false)  
✅ Improvement in the Win32 app JSON creation. Return Codes are now added in the default, expected, order  

## 2.0.50 - BETA - 03/04/2024

✅ New Branch for 2.0.50  
✅ Fixed a regex bug in New-IntuneWin.ps1 where the name of the .intunewin was not passed correctly if it contained multiple periods  
✅ Renamed Connect-Graph module to Get-AuthToken. Using MSAL.PS so we can get the access token  
✅ New Module Get-ClientCertificate to get the x509 blob from either the CurrentUser or LocalMachine for authentication  
✅ New Module Invoke-GraphRequest to make Graph API requests  
✅ New Module New-FailedMigration to log failed migrations in a global array  
✅ New Module Get-FailedMigration to check for failed migration reasons  
✅ New Module New-Win32AppFramework to create the body for requesting a Win32App  
✅ New Module Get-NewIntuneWinContentRequest to create content for Win32app  
✅ New Module Get-IntuneWinInfo to read metadata from an .intunewin file  

## 2.0.20 - BETA - 23/03/2024

✅ Export Detection Method to file in the working folder 'DetectionMethods' folder  
✅ Export Detection Method supporting information to Details\DeploymentTypes.csv  
✅ Fix an incorrectly passed parameter for Get-ScriptEnd in Get-DeploymentTypeInfo.ps1  
✅ Fix a bug where base64 icon data causes cmtrace to not parse the log line correctly. We now omit icondata from being logged  
✅ Fix a bug where an incorrect parameter was passed when testing the SMS Provider connection  
✅ New module Connect-Graph (in development)  
✅ Fixed an issue outputting Detection Method Scripts to file. We now use the .NET method which is much more reliable than Out-File  
✅ Fixed a bug where return $applicationTypes was not outside the ForEach loop and only returned a single application even if multiple were selected  
✅ Fixed <https://github.com/byteben/Win32App-Migration-Tool/issues/17>  
✅ Fixed <https://github.com/byteben/Win32App-Migration-Tool/issues/18>  
✅ Updated Licence terms to GNU GENERAL PUBLIC LICENSE  
✅ New module Get-LocalDetectionMethods to extract local detection methods (file/reg/msi) when detection is not a script  
✅ New module New-IntuneDetectionMethod to create json for detection methods  
✅ Fixed an issue where icon export was attempted even if the icon was not present  

## 2.0.19 - BETA - 16/12/2023

✅ Fixed <https://github.com/byteben/Win32App-Migration-Tool/issues/11>  
✅ Fixed <https://github.com/byteben/Win32App-Migration-Tool/issues/12>  

## 2.0.18 - BETA - 25/11/2023
  
✅ Fixed <https://github.com/byteben/Win32App-Migration-Tool/issues/7>  
✅ Fixed <https://github.com/byteben/Win32App-Migration-Tool/issues/4>  
✅ Fixed <https://github.com/byteben/Win32App-Migration-Tool/issues/13>  

## 2.0.17 - BETA - 12/11/2023
  
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
  
## 1.103.12.01 - BETA - 12/03/2022
  
✅ Added UTF8 Encoding for CSV Exports <https://github.com/byteben/Win32App-Migration-Tool/issues/6>  
✅ Added option to exclude PMPC apps <https://github.com/byteben/Win32App-Migration-Tool/issues/5>  
✅ Added option to exclude specific apps using a filter  
  
## 1.08.29.02 - BETA - 29/08/2021

✅ Fixed an issue where logos were not being exported  
✅ Fixed an issue where the Localized Display Name was not outputed correctly  
  
## 1.08.29.01 - BETA - 29/08/2021
  
✅ Default to not copy content locally.  
✅ Use -DownloadContent switch to copy content to local working folder  
✅ Fixed an issue when the source content folder has a space in the path  
  
## 1.03.27.02 - BETA - 27/03/2021
  
✅ Fixed a grammar issue when creating the Working Folders  
  
## 1.03.25.01 - BETA - 25/03/2021

✅ Removed duplicate name in message for successful .intunewin creation  
✅ Added a new switch "-NoOGV" which will suppress the Out-Grid view. Thanks @philschwan  
✅ Fixed an issue where the -ResetLog parameter was not working  
  
## 1.03.23.01 - BETA - 23/03/2021
  
✅ Error handling improved when connecting to the Site Server and passing a Null app name  

## 1.03.22.01 - BETA - 22/03/2021
  
✅ Updates Manifest to only export New-Win32App Function  
  
## 1.03.21.04 - BETA - 21/03/2021
  
✅ Fixed RootModule issue in psm1  
  
## 1.03.21.03 - BETA - 21/03/2021
  
✅ Fixed Function error for New-Win32App  
  
## 1.03.21.01 - BETA - 21/03/2021
  
✅ Added to PSGallery and converted to Module

## 1.03.20.01 - BETA - 20/03/2021
  
✅ Added support for .vbs script installers  
✅ Fixed logic error for string matching  

## 1.03.19.01 - BETA - 19/03/2021
  
✅ Added Function Get-ScriptEnd  
  
## 1.03.18.03 - BETA - 18/03/2021
  
✅ Fixed an issue where Intunewin SetupFile was being detected as an .exe when msiexec was present in the install command  
  
## 1.03.18.02 - BETA - 18/03/2021
  
✅ Removed the character " from SetupFile command when an install command is wrapped in double quotes  
  
## 1.03.18.01 - BETA - 18/03/2021
  
✅ Robocopy for content now padding Source and Destination variables if content path has white space  
✅ Deployment Type Count was failing from the SDMPackageXML. Using the measure tool to check if Deployment Types exist for an Application  
✅ Removed " from SetupFile command if install commands are in double quotes  
  
## 1.03.18 - BETA - 18/03/2021
  
✅ Release for Testing  
✅ Logging Added  

## 1.0 - DEV - 14/03/2021
  
✅ DEV Release
