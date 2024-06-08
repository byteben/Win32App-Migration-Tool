<#
.Synopsis
Created on:   04/11/2023
Created by:   Ben Whitmore
Filename:     Get-ContentInfo.ps1

.Description
Function to get content from the content source folder for the deployment type and copy it to the content destination folder

.PARAMETER LogId
The component (script name) passed as LogID to the 'Write-Log' function. 
This parameter is built from the line number of the call from the function up the

.PARAMETER InstallContent
The content path for intent to install

.PARAMETER UninstallContent
The content path for intent to uninstall

.PARAMETER ApplicationId
The id of the application for the deployment type to get content for

.PARAMETER ApplicationName
The name of the application for the deployment type to get content for

.PARAMETER DeploymentTypeLogicalName
The logical name of the deployment type to get content for

.PARAMETER DeploymentTypeName
The name of the deployment type to get content for

.PARAMETER UninstallSetting
Is uninstall content same as install or different?

.PARAMETER InstallCommandLine
Command line used to install the deployment type
#>
function Get-ContentInfo {
    param (
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = "The component (script name) passed as LogID to the 'Write-Log' function")]
        [string]$LogId = $($MyInvocation.MyCommand).Name,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 0, HelpMessage = 'Content path for intent to install')]
        [string]$InstallContent,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 1, HelpMessage = 'Content path for intent to uninstall')]
        [string]$UninstallContent,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 2, HelpMessage = 'The id of the application for the deployment type to get content for')]
        [string]$ApplicationId,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 3, HelpMessage = 'The name of the application for the deployment type to get content for')]
        [string]$ApplicationName,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 4, HelpMessage = 'The logical name of the deployment type to get content for')]
        [string]$DeploymentTypeLogicalName,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 5, HelpMessage = 'The name of the deployment type to get content for')]
        [string]$DeploymentTypeName,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 6, HelpMessage = 'Is uninstall content same as install or different?')]
        [string]$UninstallSetting,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 7, HelpMessage = 'Command line used to install the deployment type')]
        [string]$InstallCommandLine
    )
    begin {

        # Characters that are not allowed in Windows folder names
        $invalidChars = '[<>:"/\\|\?\*]'
        
        # Sanitize the folder names
        $ApplicationNameSanitized = ($ApplicationName -replace $invalidChars, '_').TrimEnd('.', ' ')
        $DeploymentTypeNameSanitized = ($DeploymentTypeName -replace $invalidChars, '_').TrimEnd('.', ' ')

        # Content folder(s) to copy to
        $destinationInstallFolder = ("{0}\{1}" -f $ApplicationNameSanitized, $DeploymentTypeNameSanitized)
        $destinationUninstallFolder = ("{0}\{1}\Uninstall" -f $ApplicationNameSanitized, $DeploymentTypeNameSanitized)
        
        # Build final folder name strings
        $destinationInstallFolder = Join-Path -Path "$workingFolder_Root\Content" -ChildPath $destinationInstallFolder
        $destinationUninstallFolder = Join-Path -Path "$workingFolder_Root\Content" -ChildPath $destinationUninstallFolder
    }
    process {

        Write-Log -Message ("Getting content details for the application '{0}' and deployment type '{1}'" -f $applicationName, $DeploymentTypeName) -LogId $LogId
        Write-Host ("Getting content details for the application '{0}' and deployment type '{1}'" -f $applicationName, $DeploymentTypeName) -ForegroundColor Cyan

        # Create a new custom hashtable to store content details
        $contentObject = [PSCustomObject]@{}

        # Add content details to the PSCustomObject
        $contentObject | Add-Member NoteProperty -Name Application_Id -Value $ApplicationId
        $contentObject | Add-Member NoteProperty -Name Application_Name -Value $ApplicationName
        $contentObject | Add-Member NoteProperty -Name DeploymentType_LogicalName -Value $DeploymentTypeLogicalName
        $contentObject | Add-Member NoteProperty -Name DeploymentType_Name -Value $DeploymentTypeName
        $contentObject | Add-Member NoteProperty -Name Install_Source -Value $InstallContent
        $contentObject | Add-Member NoteProperty -Name Uninstall_Setting -Value $UninstallSetting
        $contentObject | Add-Member NoteProperty -Name Uninstall_Source -Value $UninstallContent
        $contentObject | Add-Member NoteProperty -Name Install_Destination -Value $destinationInstallFolder
        $contentObject | Add-Member NoteProperty -Name Uninstall_Destination -Value $destinationUninstallFolder
        $contentObject | Add-Member NoteProperty -Name Install_CommandLine -Value $InstallCommandLine
        $contentObject | Add-Member NoteProperty -Name Win32app_Destination -Value "$ApplicationNameSanitized\$DeploymentTypeNameSanitized"

        Write-Log -Message ("Application_Id = '{0}', Application_Name = '{1}', DeploymentType_LogicalName = '{2}', DeploymentType_Name = '{3}', Install_Source = '{4}', Uninstall_Setting = '{5}', Uninstall_Source = '{6}', Install_Destination = '{7}', Uninstall_Destination = '{8}', Win32app_Destinaton = '{9}'" -f `
                $ApplicationId, `
                $ApplicationName, `
                $DeploymentTypeLogicalName, `
                $DeploymentTypeName, `
                $InstallContent, `
                $UninstallSetting, `
                $UninstallContent, `
                $destinationInstallFolder, `
                $destinationUninstallFolder, `
                $Win32app_Destination) -LogId $LogId

        # Output the deployment type object
        Write-Host "`n$contentObject`n" -ForegroundColor Green

        return $contentObject
    }
}