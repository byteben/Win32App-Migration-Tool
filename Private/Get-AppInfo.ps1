<#
.Synopsis
Created on:   28/10/2023
Created by:   Ben Whitmore
Filename:     Get-AppInfo.ps1

.Description
Function to get application and deployment type information from ConfigMgr

.PARAMETER LogId
The component (script name) passed as LogID to the 'Write-Log' function. 
This parameter is built from the line number of the call from the function up the

.PARAMETER ApplicationName
The name of the application to get information for
#>
function Get-AppInfo {
    param (
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = "The component (script name) passed as LogID to the 'Write-Log' function")]
        [string]$LogId = $($MyInvocation.MyCommand).Name,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 0, HelpMessage = 'The name of the application(s) to get information for')]
        [object[]]$ApplicationName
    )
    begin {
        Write-Log -Message "Function: Get-AppInfo was called" -LogId $LogId
    }
    process {

        # Create Array to display application and deployment type information
        $deploymentTypes = @()
        $applicationTypes = @()
        $content = @()

        # Iterate through each application and get the details
        Write-Log -Message ( "Iterating through '{0}' appllication{1}" -f ( ($ApplicationName | Measure-Object).Count ), $(if ( ($ApplicationName | Measure-Object).Count -ne 1) { 's' } ) ) -LogId $LogId
        Write-Host ( "Iterating through '{0}' application{1}" -f ( ($ApplicationName | Measure-Object).Count ), $(if ( ($ApplicationName | Measure-Object).Count -ne 1) { 's' } ) ) -ForegroundColor Cyan
        Write-Log -Message "Function: Get-AppInfo was called" -LogId $LogId

        foreach ($application in $applicationName) {

            # Grab the SDMPackgeXML which contains the application and deployment type details
            Write-Log -Message ("Invoking Get-CMApplication where Id equals '{0}' for appliction '{1}' and expanding the property SDMPackageXML" -f $application.Id, $application.LocalizedDisplayName) -LogId $LogId
            $xmlPackage = Get-CMApplication -Id $application.Id | Where-Object { $null -ne $_.SDMPackageXML } | Select-Object -ExpandProperty SDMPackageXML
        
            # Prepare xml from SDMPackageXML
            Write-Log -Message "Preparing XML from SDMPackageXML" -LogId $LogId
            $xmlContent = [xml]($xmlPackage)

            # Get the total number of deployment types for the application
            $totalDeploymentTypes = ($xmlContent.AppMgmtDigest.Application.DeploymentTypes.DeploymentType | Measure-Object | Select-Object -ExpandProperty Count)
            Write-Log -Message ("The total number of deployment types for '{0}' with CI_ID '{1}' is '{2}')" -f $application.LocalizedDisplayName, $application.Id, $totalDeploymentTypes) -LogId $LogId

            if ($totalDeploymentTypes -ge 0) {

                $applicationObject = New-Object PSCustomObject
                
                # Add pplication details to PSCustomObject
                Write-Log -Message "Application_LogicalName -Value $xmlContent.AppMgmtDigest.Application.LogicalName" -LogId $LogId
                $applicationObject | Add-Member NoteProperty -Name LogicalName -Value $xmlContent.AppMgmtDigest.Application.LogicalName
                Write-Log -Message "Application_Name -Value $($xmlContent.AppMgmtDigest.Application.title.'#text')" -LogId $LogId
                $applicationObject | Add-Member NoteProperty -Name Name -Value $xmlContent.AppMgmtDigest.Application.title.'#text'
                Write-Log -Message "Application_Description -Value $($xmlContent.AppMgmtDigest.Application.DisplayInfo.Info.Description)" -LogId $LogId
                $applicationObject | Add-Member NoteProperty -Name Description -Value $xmlContent.AppMgmtDigest.Application.DisplayInfo.Info.Description
                Write-Log -Message "Application_Publisher -Value $($xmlContent.AppMgmtDigest.Application.DisplayInfo.Info.Publisher)" -LogId $LogId
                $applicationObject | Add-Member NoteProperty -Name Publisher -Value $xmlContent.AppMgmtDigest.Application.DisplayInfo.Info.Publisher
                Write-Log -Message "Application_Version -Value $($xmlContent.AppMgmtDigest.Application.DisplayInfo.Info.Version)" -LogId $LogId
                $applicationObject | Add-Member NoteProperty -Name Version -Value $xmlContent.AppMgmtDigest.Application.DisplayInfo.Info.Version
                Write-Log -Message "Application_IconId -Value $($xmlContent.AppMgmtDigest.Application.DisplayInfo.Info.Icon.Id)" -LogId $LogId
                $applicationObject | Add-Member NoteProperty -Name IconId -Value $xmlContent.AppMgmtDigest.Application.DisplayInfo.Info.Icon.Id
                Write-Log -Message "Application_TotalDeploymentTypes -Value $($TotalDeploymentTypes)" -LogId $LogId
                $applicationObject | Add-Member NoteProperty -Name TotalDeploymentTypes -Value $totalDeploymentTypes
                
                # If we have the logo, add the path
                if (-not ($null -eq $xmlContent.AppMgmtDigest.Application.DisplayInfo.Info.Icon.Id) ) {
                    try {
                        logoPath = (Join-Path -Path $xmlContent.AppMgmtDigest.Application.DisplayInfo.Info.Icon.Id -ChildPath "Logo.jpg")

                        if (Test-Path -Path $logoPath) {
                            Write-Log -Message ("Application_IconPath is '{0}'" -f ("$WorkingFolder\Logos\$logoPath")) -LogId $LogId
                            $applicationObject | Add-Member NoteProperty -Name Application_IconPath -Value "$WorkingFolder\Logos\$logoPath"
                        }
                        else {
                            Write-Log -Message "Application_IconPath -Value `$null" -LogId $LogId
                            $applicationObject | Add-Member NoteProperty -Name Application_IconPath -Value $null
                        }
                    }
                    catch {
                        Write-Log -Message "Application_IconPath -Value `$null" -LogId $LogId
                        $applicationObject | Add-Member NoteProperty -Name Application_IconPath -Value $null
                    }
                }
                else {
                    Write-Log -Message "Application_IconPath -Value `$null" -LogId $LogId
                    $applicationObject | Add-Member NoteProperty -Name Application_IconPath -Value $null  
                }
                
                $applicationTypes += $applicationObject
        
                # If Dthere are deployment types, iterate through each deployment type and collect the details
                foreach ($Object in $xmlContent.AppMgmtDigest.DeploymentType) {

                    #Create new custom PSObjects to build line detail
                    $DeploymentObject = New-Object -TypeName PSCustomObject
                    $ContentObject = New-Object -TypeName PSCustomObject
                    Write-Log -Message "DeploymentObject():" -LogId $LogId

                    #DeploymentType Details
                    Write-Log -Message "Application_LogicalName -Value $($xmlContent.AppMgmtDigest.Application.LogicalName)" -LogId $LogId
                    $DeploymentObject | Add-Member NoteProperty -Name Application_LogicalName -Value $xmlContent.AppMgmtDigest.Application.LogicalName
                    Write-Log -Message "DeploymentType_LogicalName -Value $($Object.LogicalName)" -LogId $LogId
                    $DeploymentObject | Add-Member NoteProperty -Name DeploymentType_LogicalName -Value $Object.LogicalName
                    Write-Log -Message "DeploymentType_Name -Value $($Object.Title.InnerText)" -LogId $LogId
                    $DeploymentObject | Add-Member NoteProperty -Name DeploymentType_Name -Value $Object.Title.InnerText
                    Write-Log -Message "DeploymentType_Technology -Value $($Object.Installer.Technology)" -LogId $LogId
                    $DeploymentObject | Add-Member NoteProperty -Name DeploymentType_Technology -Value $Object.Installer.Technology
                    Write-Log -Message "DeploymentType_ExecutionContext -Value $($Object.Installer.ExecutionContext)" -LogId $LogId
                    $DeploymentObject | Add-Member NoteProperty -Name DeploymentType_ExecutionContext -Value $Object.Installer.ExecutionContext
                    Write-Log -Message "DeploymentType_InstallContent -Value $($Object.Installer.CustomData.InstallContent.ContentId)" -LogId $LogId
                    $DeploymentObject | Add-Member NoteProperty -Name DeploymentType_InstallContent -Value $Object.Installer.CustomData.InstallContent.ContentId
                    Write-Log -Message "DeploymentType_InstallCommandLine -Value $($Object.Installer.CustomData.InstallCommandLine)" -LogId $LogId
                    $DeploymentObject | Add-Member NoteProperty -Name DeploymentType_InstallCommandLine -Value $Object.Installer.CustomData.InstallCommandLine
                    Write-Log -Message "DeploymentType_UnInstallSetting -Value $($Object.Installer.CustomData.UnInstallSetting)" -LogId $LogId
                    $DeploymentObject | Add-Member NoteProperty -Name DeploymentType_UnInstallSetting -Value $Object.Installer.CustomData.UnInstallSetting
                    Write-Log -Message "DeploymentType_UninstallContent -Value $$($Object.Installer.CustomData.UninstallContent.ContentId)" -LogId $LogId
                    $DeploymentObject | Add-Member NoteProperty -Name DeploymentType_UninstallContent -Value $Object.Installer.CustomData.UninstallContent.ContentId
                    Write-Log -Message "DeploymentType_UninstallCommandLine -Value $($Object.Installer.CustomData.UninstallCommandLine)" -LogId $LogId
                    $DeploymentObject | Add-Member NoteProperty -Name DeploymentType_UninstallCommandLine -Value $Object.Installer.CustomData.UninstallCommandLine
                    Write-Log -Message "DeploymentType_ExecuteTime -Value $($Object.Installer.CustomData.ExecuteTime)" -LogId $LogId
                    $DeploymentObject | Add-Member NoteProperty -Name DeploymentType_ExecuteTime -Value $Object.Installer.CustomData.ExecuteTime
                    Write-Log -Message "DeploymentType_MaxExecuteTime -Value $($Object.Installer.CustomData.MaxExecuteTime)" -LogId $LogId
                    $DeploymentObject | Add-Member NoteProperty -Name DeploymentType_MaxExecuteTime -Value $Object.Installer.CustomData.MaxExecuteTime

                    $DeploymentTypes += $DeploymentObject

                    #Content Details
                    Write-Log -Message "ContentObject():" -LogId $LogId
                    Write-Log -Message "Content_DeploymentType_LogicalName -Value $($Object.LogicalName)" -LogId $LogId
                    $ContentObject | Add-Member NoteProperty -Name Content_DeploymentType_LogicalName -Value $Object.LogicalName
                    Write-Log -Message "Content_Location -Value $($Object.Installer.Contents.Content.Location)" -LogId $LogId
                    $ContentObject | Add-Member NoteProperty -Name Content_Location -Value $Object.Installer.Contents.Content.Location

                    $Content += $ContentObject                
                }
            }
            else {
                Write-Log -Message "Warning: No DeploymentTypes found for ""$($xmlContent.AppMgmtDigest.Application.LogicalName)""" -LogId $LogId
                Write-Host "Warning: No DeploymentTypes found for ""$($xmlContent.AppMgmtDigest.Application.LogicalName)"" " -ForegroundColor Yellow
            }
        } 
        Return $DeploymentTypes, $applicationTypes, $Content
    }
}