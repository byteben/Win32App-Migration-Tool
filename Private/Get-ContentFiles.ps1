<#
.Synopsis
Created on:   04/11/2023
Created by:   Ben Whitmore
Filename:     Get-ContentFiles.ps1

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
#>
function Get-ContentFiles {
    param (
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = "The component (script name) passed as LogID to the 'Write-Log' function")]
        [string]$LogId = $($MyInvocation.MyCommand).Name,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 0, HelpMessage = 'Content path for intent to install')]
        [string]$InstallContent,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 1, HelpMessage = 'Content path for intent to uninstall')]
        [string]$UninstallContent,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 2, HelpMessage = 'The id of the application for the deployment type to get content for')]
        [string]$ApplicationId,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 2, HelpMessage = 'The name of the application for the deployment type to get content for')]
        [string]$ApplicationName,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 3, HelpMessage = 'The logical name of the deployment type to get content for')]
        [string]$DeploymentTypeLogicalName,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 4, HelpMessage = 'The name of the deployment type to get content for')]
        [string]$DeploymentTypeName
    )

    begin {

        # Content folder(s) to copy to
        $destinationInstallFolder = ("{0}\{1}\Install" -f $ApplicationName, $DeploymentTypeName)
        $destinationUninstallFolder = ("{0}\{1}\Uninstall" -f $ApplicationName, $DeploymentTypeName)

        # Characters that are not allowed in Windows folder names
        $invalidChars = '[<>:"/\\|\?\*]'

        # Sanitize the folder names
        $destinationInstallFolder = $destinationInstallFolder -replace $invalidChars, '_'
        $destinationUninstallFolder = $destinationUninstallFolder -replace $invalidChars, '_'

        # Trim any trailing period or space
        $destinationInstallFolder = $destinationInstallFolder.TrimEnd('.', ' ')
        $destinationUninstallFolder = $destinationUninstallFolder.TrimEnd('.', ' ')

        # Build final folder name strings
        $destinationInstallFolder = Join-Path -Path $workingFolder_Root -ChildPath $destinationInstallFolder
        $destinationUninstallFolder = Join-Path -Path $workingFolder_Root -ChildPath $destinationUninstallFolder
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
        $contentObject | Add-Member NoteProperty -Name Uninstall_Source -Value $UninstallContent
        $contentObject | Add-Member NoteProperty -Name Install_Destination -Value $destinationInstallFolder
        $contentObject | Add-Member NoteProperty -Name Uninstall_Destination -Value $destinationUninstallFolder

        Write-Log -Message ("Application_Id = '{0}', Application_Name = '{1}', DeploymentType_LogicalName = '{2}', DeploymentType_Name = '{3}', Install_Source = '{4}', Uninstall_Source = '{5}', Install_Destination = '{6}', Uninstall_Destination = '{7}'" -f `
                $ApplicationId, `
                $ApplicationName, `
                $DeploymentTypeLogicalName, `
                $DeploymentTypeName, `
                $InstallContent, `
                $UninstallContent, `
                $destinationInstallFolder, `
                $destinationUninstallFolder) -LogId $LogId

        # Output the deployment type object
        Write-Host "`n$contentObject`n" -ForegroundColor Green

        Return $contentObject

        # Add padding to the source and destination paths
        Write-Log -Message ("Padding '{0}' in case content path has spaces. Note: Robocopy demands space at end of source string" -f $Source) -LogId $LogId
        $sourcePadded = "`"" + $Source + " `""

        Write-Log -Message ("Padding '{0}' in case content path has spaces. Note: Robocopy demands space at end of source string" -f $Destination) -LogId $LogId
        $DestinationPadded = "`"" + $Destination + " `""

        try {
            Write-Log -Message ("Invoking robocopy.exe '{0}' '{1}' /MIR /E /Z /R:5 /W:1 /NDL /NJH /NJS /NC /NS /NP /V /TEE  /UNILOG+:'{2}'" -f $sourcePadded, $destinationPadded, $uniLog)-LogId $LogId 
        
            $args = @(
                $SourcePadded
                $DestinationPadded
                /MIR
                /E
                /Z
                /R:5
                /W:1
                /NDL
                /NJH
                /NJS
                /NC
                /NS
                /NP
                /V
                /TEE
                /UNILOG+:$uniLog
            )

            # Invoke robocopy.exe
            Start-Process Robocopy.exe -ArgumentList $args -Wait -NoNewWindow -PassThru 

            if ((Get-ChildItem -Path $destination | Measure-Object).Count -eq 0 ) {

                Write-Log -Message ("Error: Could not transfer content from '{0}' to '{1}'" -f $source, $destination) -LogId $LogId
                Write-Warning -Message ("Error: Could not transfer content from '{0}' to '{1}'" -f $source, $destination)
            }
        }
        catch {
            Write-Log -Message ("Error: Could not transfer content from '{0}' to '{1}'" -f $source, $destination) -LogId $LogId
            Write-Warning -Message ("Error: Could not transfer content from '{0}' to '{1}'" -f $source, $destination)
        }
    }
}