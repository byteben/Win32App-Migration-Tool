<#
.Synopsis
Created on:   28/10/2023
Created by:   Ben Whitmore
Filename:     Get-DeploymentTypeInfo.ps1

.Description
Function to get deployment type information from ConfigMgr

.PARAMETER LogId
The component (script name) passed as LogID to the 'Write-Log' function. 
This parameter is built from the line number of the call from the function up the

.PARAMETER ApplicationId
The CI_ID of the application to get deployment type information for
#>
function Get-DeploymentTypeInfo {
    param (
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = "The component (script name) passed as LogID to the 'Write-Log' function")]
        [string]$LogId = $($MyInvocation.MyCommand).Name,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 0, HelpMessage = 'The id of the application(s) to get information for')]
        [string]$ApplicationId
    )
    begin {

        # Create an empty array to store the deployment type information
        $deploymentTypes = @()
    }
    process {

        try {

            # Grab the SDMPackgeXML which contains the application and deployment type details
            Write-Log -Message ("Invoking Get-CMApplication where Id equals '{0}'" -f $ApplicationId) -LogId $LogId
            Write-Host ("Invoking Get-CMApplication where Id equals '{0}'" -f $ApplicationId) -ForegroundColor Cyan
            $xmlPackage = Get-CMApplication -Id $ApplicationId | Where-Object { $null -ne $_.SDMPackageXML } | Select-Object -ExpandProperty SDMPackageXML
        
            # Prepare xml from SDMPackageXML
            $xmlContent = [xml]($xmlPackage)

            # Get the total number of deployment types for the application
            $totalDeploymentTypes = ($xmlContent.AppMgmtDigest.Application.DeploymentTypes.DeploymentType | Measure-Object | Select-Object -ExpandProperty Count)
            Write-Log -Message ("The total number of deployment types for '{0}' is '{1}')" -f $xmlContent.AppMgmtDigest.Application.title.'#text', $totalDeploymentTypes) -LogId $LogId
            Write-Host ("The total number of deployment types for '{0}' is '{1}')" -f $xmlContent.AppMgmtDigest.Application.title.'#text', $totalDeploymentTypes) -ForegroundColor Cyan

            if ($totalDeploymentTypes -ge 0) {

                # If there are deployment types, iterate through each deployment type and collect the details
                foreach ($object in $xmlContent.AppMgmtDigest.DeploymentType) {

                    # Handle multiple objects if content is an array
                    if ($object.Installer.Contents.Content.Location.Count -gt 1) {
                        $installLocation = $object.Installer.Contents.Content.Location[0]
                        $uninstallLocation = $object.Installer.Contents.Content.Location[1]
                    }
                    else {
                        $installLocation = $object.Installer.Contents.Content.Location
                        $uninstallLocation = $object.Installer.Contents.Content.Location
                    }

                    # Create a new custom hashtable to store Deployment type details
                    $deploymentObject = [PSCustomObject]@{}

                    # Add deployment type details to the PSCustomObject
                    $deploymentObject | Add-Member NoteProperty -Name Application_Id -Value $ApplicationId
                    $deploymentObject | Add-Member NoteProperty -Name ApplicationName -Value $xmlContent.AppMgmtDigest.Application.title.'#text'
                    $deploymentObject | Add-Member NoteProperty -Name Application_LogicalName -Value $xmlContent.AppMgmtDigest.Application.LogicalName
                    $deploymentObject | Add-Member NoteProperty -Name LogicalName -Value $Object.LogicalName
                    $deploymentObject | Add-Member NoteProperty -Name Name -Value $Object.Title.InnerText
                    $deploymentObject | Add-Member NoteProperty -Name Technology -Value $Object.Installer.Technology
                    $deploymentObject | Add-Member NoteProperty -Name ExecutionContext -Value $Object.Installer.ExecutionContext
                    $deploymentObject | Add-Member NoteProperty -Name InstallContent -Value $installLocation.TrimEnd('\') 
                    $deploymentObject | Add-Member NoteProperty -Name InstallCommandLine -Value $Object.Installer.CustomData.InstallCommandLine
                    $deploymentObject | Add-Member NoteProperty -Name UnInstallSetting -Value $Object.Installer.CustomData.UnInstallSetting
                    $deploymentObject | Add-Member NoteProperty -Name UninstallContent -Value $uninstallLocation.TrimEnd('\') 
                    $deploymentObject | Add-Member NoteProperty -Name UninstallCommandLine -Value $Object.Installer.CustomData.UninstallCommandLine
                    $deploymentObject | Add-Member NoteProperty -Name ExecuteTime -Value $Object.Installer.CustomData.ExecuteTime
                    $deploymentObject | Add-Member NoteProperty -Name MaxExecuteTime -Value $Object.Installer.CustomData.MaxExecuteTime
                
                    Write-Log -Message ("Application_Id = '{0}', Application_Name = '{1}', Application_LogicalName = '{2}', LogicalName = '{3}', Name = '{4}', Technology = '{5}', ExecutionContext = '{6}', InstallContext = '{7}', `
                 InstallCommandLine = '{8}', UninstallSetting = '{9}', UninstallContent = '{10}', UninstallCommandLine = '{11}', ExecuteTime = '{12}', MaxExecuteTime = '{13}'" -f `
                            $ApplicationId, `
                            $xmlContent.AppMgmtDigest.Application.title.'#text', `
                            $xmlContent.AppMgmtDigest.Application.LogicalName, `
                            $object.LogicalName, `
                            $object.Title.InnerText, `
                            $object.Installer.Technology, `
                            $object.Installer.ExecutionContext, `
                            $installLocation, `
                            $object.Installer.CustomData.InstallCommandLine, `
                            $object.Installer.CustomData.UnInstallSetting, `
                            $uninstallLocation, `
                            $object.Installer.CustomData.UninstallCommandLine, `
                            $object.Installer.CustomData.ExecuteTime, `
                            $object.Installer.CustomData.MaxExecuteTime) -LogId $LogId

                    # Output the deployment type object
                    Write-Host "`n$deploymentObject`n" -ForegroundColor Green

                    # Add the deployment type object to the array
                    $deploymentTypes += $deploymentObject          
                }
            }
            else {
                Write-Log -Message ("Warning: No DeploymentTypes found for '{0}'" -f $xmlContent.AppMgmtDigest.Application.LogicalName) -LogId $LogId -Severity 2
                Write-Host ("Warning: No DeploymentTypes found for '{0}'" -f $xmlContent.AppMgmtDigest.Application.LogicalName) -ForegroundColor Yellow
            }
        
            return $deploymentTypes

        }
        catch {
            Write-Log -Message ("Could not get deployment type information for application Id '{0}'" -f $ApplicationId) -LogId $LogId -Severity 3
            Write-Warning -Message ("Could not get deployment type information for application id '{0}'" -f $ApplicationId)
            Get-ScriptEnd -LogId $LogId -Message $_.Exception.Message
        }
    }
}