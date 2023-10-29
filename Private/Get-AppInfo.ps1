<#
.Synopsis
Created on:   28/10/2023
Created by:   Ben Whitmore
Filename:     Get-AppInfo.ps1

.Description
Function to get application and deployment type information from ConfigMgr

.PARAMETER LogID
The component (script name) passed as LogID to the 'Write-Log' function. 
This parameter is built from the line number of the call from the function up the

.PARAMETER ApplicationName
The name of the application to get information for
#>
function Get-AppInfo {
    param (
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = "The component (script name) passed as LogID to the 'Write-Log' function")]
        [string]$LogId = $($MyInvocation.MyCommand).Name,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 0, HelpMessage = 'The name of the application to get information for')]
        [String[]]$ApplicationName
    )
    begin {
        Write-Log -Message "Function: Get-AppInfo was called" -LogId $LogId

        # Create Array to display application and deployment type information
        $deploymentTypes = @()
        $applicationTypes = @()
        $content = @()
    }
    process {

        # Iterate through each application and get the details
        ForEach ($application in $ApplicationName) {

            # Grab the SDMPackgeXML which contains the application and deployment type details
            Write-Log -Message ("Invoking Get-CMApplication where CI_ID equals {0}' ('{1}') expanding the property SDMPackageXML" -f $application.CI__ID, $application.LocalizedDisplayName) -LogId $LogId
            $xmlPackage = Get-CMApplication $application.CI__ID | Where-Object { $Null -ne $_.SDMPackageXML } | Select-Object -ExpandProperty SDMPackageXML
        
            # Prepare xml from SDMPackageXML
            Write-Log -Message "Preparing XML from SDMPackageXML" -LogId $LogId
            $xmlContent = [xml]($xmlPackage)

            # Get the total number of deployment types for the application
            $totalDeploymentTypes = ($xmlContent.AppMgmtDigest.Application.DeploymentTypes.DeploymentType | Measure-Object | Select-Object -ExpandProperty Count)
            Write-Log -Message ("The total number of deployment types for '{0}' with CI_ID '{1}' is '{2}')" -f $application.LocalizedDisplayName, $application.CI__ID, $totalDeploymentTypes) -LogId $LogId

        
            If (!($Null -eq $TotalDeploymentTypes) -or (!($TotalDeploymentTypes -eq 0))) {

                $ApplicationObject = New-Object PSCustomObject
                Write-Log -Message "ApplicationObject():" -Log "Main.log"
                
                #Application Details
                Write-Log -Message "Application_LogicalName -Value $XMLContent.AppMgmtDigest.Application.LogicalName" -Log "Main.log"
                $ApplicationObject | Add-Member NoteProperty -Name Application_LogicalName -Value $XMLContent.AppMgmtDigest.Application.LogicalName
                Write-Log -Message "Application_Name -Value $($XMLContent.AppMgmtDigest.Application.title.'#text')" -Log "Main.log"
                $ApplicationObject | Add-Member NoteProperty -Name Application_Name -Value $XMLContent.AppMgmtDigest.Application.title.'#text'
                Write-Log -Message "Application_Description -Value $($XMLContent.AppMgmtDigest.Application.DisplayInfo.Info.Description)" -Log "Main.log"
                $ApplicationObject | Add-Member NoteProperty -Name Application_Description -Value $XMLContent.AppMgmtDigest.Application.DisplayInfo.Info.Description
                Write-Log -Message "Application_Publisher -Value $($XMLContent.AppMgmtDigest.Application.DisplayInfo.Info.Publisher)" -Log "Main.log"
                $ApplicationObject | Add-Member NoteProperty -Name Application_Publisher -Value $XMLContent.AppMgmtDigest.Application.DisplayInfo.Info.Publisher
                Write-Log -Message "Application_Version -Value $($XMLContent.AppMgmtDigest.Application.DisplayInfo.Info.Version)" -Log "Main.log"
                $ApplicationObject | Add-Member NoteProperty -Name Application_Version -Value $XMLContent.AppMgmtDigest.Application.DisplayInfo.Info.Version
                Write-Log -Message "Application_IconId -Value $($XMLContent.AppMgmtDigest.Application.DisplayInfo.Info.Icon.Id)" -Log "Main.log"
                $ApplicationObject | Add-Member NoteProperty -Name Application_IconId -Value $XMLContent.AppMgmtDigest.Application.DisplayInfo.Info.Icon.Id
                Write-Log -Message "Application_TotalDeploymentTypes -Value $($TotalDeploymentTypes)" -Log "Main.log"
                $ApplicationObject | Add-Member NoteProperty -Name Application_TotalDeploymentTypes -Value $TotalDeploymentTypes
                
                #If we have the logo, add the path
                If (!($Null -eq $XMLContent.AppMgmtDigest.Application.DisplayInfo.Info.Icon.Id)) {
                    Try {
                        If (Test-Path -Path (Join-Path -Path $WorkingFolder_Logos -ChildPath (Join-Path -Path $XMLContent.AppMgmtDigest.Application.DisplayInfo.Info.Icon.Id -ChildPath "Logo.jpg"))) {
                            Write-Log -Message "Application_IconPath -Value (Join-Path -Path $($WorkingFolder_Logos) -ChildPath (Join-Path -Path $($XMLContent.AppMgmtDigest.Application.DisplayInfo.Info.Icon.Id) -ChildPath ""Logo.jpg""))" -Log "Main.log"
                            $ApplicationObject | Add-Member NoteProperty -Name Application_IconPath -Value (Join-Path -Path $WorkingFolder_Logos -ChildPath (Join-Path -Path $XMLContent.AppMgmtDigest.Application.DisplayInfo.Info.Icon.Id -ChildPath "Logo.jpg"))
                        }
                        else {
                            Write-Log -Message "Application_IconPath -Value `$Null" -Log "Main.log"
                            $ApplicationObject | Add-Member NoteProperty -Name Application_IconPath -Value $Null
                        }
                    }
                    Catch {
                        Write-Log -Message "Application_IconPath -Value `$Null" -Log "Main.log"
                        $ApplicationObject | Add-Member NoteProperty -Name Application_IconPath -Value $Null
                    }
                }
                else {
                    Write-Log -Message "Application_IconPath -Value `$Null" -Log "Main.log"
                    $ApplicationObject | Add-Member NoteProperty -Name Application_IconPath -Value $Null  
                }
                
                $ApplicationTypes += $ApplicationObject
        
                #If Deployment Types exist, iterate through each DeploymentType and build deployment detail
                ForEach ($Object in $XMLContent.AppMgmtDigest.DeploymentType) {

                    #Create new custom PSObjects to build line detail
                    $DeploymentObject = New-Object -TypeName PSCustomObject
                    $ContentObject = New-Object -TypeName PSCustomObject
                    Write-Log -Message "DeploymentObject():" -Log "Main.log"

                    #DeploymentType Details
                    Write-Log -Message "Application_LogicalName -Value $($XMLContent.AppMgmtDigest.Application.LogicalName)" -Log "Main.log"
                    $DeploymentObject | Add-Member NoteProperty -Name Application_LogicalName -Value $XMLContent.AppMgmtDigest.Application.LogicalName
                    Write-Log -Message "DeploymentType_LogicalName -Value $($Object.LogicalName)" -Log "Main.log"
                    $DeploymentObject | Add-Member NoteProperty -Name DeploymentType_LogicalName -Value $Object.LogicalName
                    Write-Log -Message "DeploymentType_Name -Value $($Object.Title.InnerText)" -Log "Main.log"
                    $DeploymentObject | Add-Member NoteProperty -Name DeploymentType_Name -Value $Object.Title.InnerText
                    Write-Log -Message "DeploymentType_Technology -Value $($Object.Installer.Technology)" -Log "Main.log"
                    $DeploymentObject | Add-Member NoteProperty -Name DeploymentType_Technology -Value $Object.Installer.Technology
                    Write-Log -Message "DeploymentType_ExecutionContext -Value $($Object.Installer.ExecutionContext)" -Log "Main.log"
                    $DeploymentObject | Add-Member NoteProperty -Name DeploymentType_ExecutionContext -Value $Object.Installer.ExecutionContext
                    Write-Log -Message "DeploymentType_InstallContent -Value $($Object.Installer.CustomData.InstallContent.ContentId)" -Log "Main.log"
                    $DeploymentObject | Add-Member NoteProperty -Name DeploymentType_InstallContent -Value $Object.Installer.CustomData.InstallContent.ContentId
                    Write-Log -Message "DeploymentType_InstallCommandLine -Value $($Object.Installer.CustomData.InstallCommandLine)" -Log "Main.log"
                    $DeploymentObject | Add-Member NoteProperty -Name DeploymentType_InstallCommandLine -Value $Object.Installer.CustomData.InstallCommandLine
                    Write-Log -Message "DeploymentType_UnInstallSetting -Value $($Object.Installer.CustomData.UnInstallSetting)" -Log "Main.log"
                    $DeploymentObject | Add-Member NoteProperty -Name DeploymentType_UnInstallSetting -Value $Object.Installer.CustomData.UnInstallSetting
                    Write-Log -Message "DeploymentType_UninstallContent -Value $$($Object.Installer.CustomData.UninstallContent.ContentId)" -Log "Main.log"
                    $DeploymentObject | Add-Member NoteProperty -Name DeploymentType_UninstallContent -Value $Object.Installer.CustomData.UninstallContent.ContentId
                    Write-Log -Message "DeploymentType_UninstallCommandLine -Value $($Object.Installer.CustomData.UninstallCommandLine)" -Log "Main.log"
                    $DeploymentObject | Add-Member NoteProperty -Name DeploymentType_UninstallCommandLine -Value $Object.Installer.CustomData.UninstallCommandLine
                    Write-Log -Message "DeploymentType_ExecuteTime -Value $($Object.Installer.CustomData.ExecuteTime)" -Log "Main.log"
                    $DeploymentObject | Add-Member NoteProperty -Name DeploymentType_ExecuteTime -Value $Object.Installer.CustomData.ExecuteTime
                    Write-Log -Message "DeploymentType_MaxExecuteTime -Value $($Object.Installer.CustomData.MaxExecuteTime)" -Log "Main.log"
                    $DeploymentObject | Add-Member NoteProperty -Name DeploymentType_MaxExecuteTime -Value $Object.Installer.CustomData.MaxExecuteTime

                    $DeploymentTypes += $DeploymentObject

                    #Content Details
                    Write-Log -Message "ContentObject():" -Log "Main.log"
                    Write-Log -Message "Content_DeploymentType_LogicalName -Value $($Object.LogicalName)" -Log "Main.log"
                    $ContentObject | Add-Member NoteProperty -Name Content_DeploymentType_LogicalName -Value $Object.LogicalName
                    Write-Log -Message "Content_Location -Value $($Object.Installer.Contents.Content.Location)" -Log "Main.log"
                    $ContentObject | Add-Member NoteProperty -Name Content_Location -Value $Object.Installer.Contents.Content.Location

                    $Content += $ContentObject                
                }
            }
            else {
                Write-Log -Message "Warning: No DeploymentTypes found for ""$($XMLContent.AppMgmtDigest.Application.LogicalName)""" -Log "Main.log"
                Write-Host "Warning: No DeploymentTypes found for ""$($XMLContent.AppMgmtDigest.Application.LogicalName)"" " -ForegroundColor Yellow
            }
        } 
        Return $DeploymentTypes, $ApplicationTypes, $Content
    }
}