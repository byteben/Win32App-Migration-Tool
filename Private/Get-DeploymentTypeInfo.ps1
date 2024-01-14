<#
.Synopsis
Created on:   28/10/2023
Update on:    13/01/2024
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

        # Characters that are not allowed in Windows folder names
        $invalidChars = '[<>:"/\\|\?\*]'
        
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

                    # Sanitize the folder names
                    $applicationNameSanitized = ($xmlContent.AppMgmtDigest.Application.title.'#text' -replace $invalidChars, '_').TrimEnd('.', ' ')
                    $deploymentTypeNameSanitized = ($object.Title.InnerText -replace $invalidChars, '_').TrimEnd('.', ' ')

                    # Detection Methods child folder path
                    $detectionMethodsFolderPath = ("{0}\{1}" -f $applicationNameSanitized, $deploymentTypeNameSanitized)

                    # Build final folder name strings
                    $detectionMethodsFolder = Join-Path -Path "$workingFolder_Root\DetectionMethods" -ChildPath $detectionMethodsFolderPath

                    # Create the Detection Methods folder
                    New-FolderToCreate -Root "$workingFolder_Root\DetectionMethods" -FolderNames $detectionMethodsFolderPath

                    # Remove existing files from the Detection Methods folder to avoid ambiguity on import
                    $existingFiles = [System.IO.Directory]::GetFiles($detectionMethodsFolder)
                    
                    foreach ($file in $existingFiles) {
                        Write-Log -Message ("Removing existing file '{0}'" -f $file) -LogId $LogId
                        [System.IO.File]::Delete($file) 
                    }

                    # Create a new custom hashtable to store Deployment type details
                    $deploymentObject = [PSCustomObject]@{}

                    # Add deployment type details to the PSCustomObject
                    $deploymentObject | Add-Member NoteProperty -Name Application_Id -Value $ApplicationId
                    $deploymentObject | Add-Member NoteProperty -Name ApplicationName -Value $xmlContent.AppMgmtDigest.Application.title.'#text'
                    $deploymentObject | Add-Member NoteProperty -Name Application_LogicalName -Value $xmlContent.AppMgmtDigest.Application.LogicalName
                    $deploymentObject | Add-Member NoteProperty -Name LogicalName -Value $object.LogicalName
                    $deploymentObject | Add-Member NoteProperty -Name Name -Value $object.Title.InnerText
                    $deploymentObject | Add-Member NoteProperty -Name Technology -Value $object.Installer.Technology
                    $deploymentObject | Add-Member NoteProperty -Name ExecutionContext -Value $object.Installer.ExecutionContext
                    $deploymentObject | Add-Member NoteProperty -Name InstallContent -Value $installLocation.TrimEnd('\') 
                    $deploymentObject | Add-Member NoteProperty -Name InstallCommandLine -Value $object.Installer.CustomData.InstallCommandLine
                    $deploymentObject | Add-Member NoteProperty -Name UnInstallSetting -Value $object.Installer.CustomData.UnInstallSetting
                    $deploymentObject | Add-Member NoteProperty -Name UninstallContent -Value $uninstallLocation.TrimEnd('\') 
                    $deploymentObject | Add-Member NoteProperty -Name UninstallCommandLine -Value $object.Installer.CustomData.UninstallCommandLine
                    $deploymentObject | Add-Member NoteProperty -Name ExecuteTime -Value $object.Installer.CustomData.ExecuteTime
                    $deploymentObject | Add-Member NoteProperty -Name MaxExecuteTime -Value $object.Installer.CustomData.MaxExecuteTime
                    $deploymentObject | Add-Member NoteProperty -Name DetectionProvider -Value $object.Installer.DetectAction.Provider

                    # Switch on the detection method and save to file
                    Switch ($object.Installer.DetectAction.Provider) {

                        'Script' {
                            $detectionTypeScriptBody = $object.Installer.DetectAction.Args.Arg.Where({ $_.Name -eq 'ScriptBody' }).InnerText
                            $detectionTypeScriptRunAs32Bit = $object.Installer.DetectAction.Args.Arg.Where({ $_.Name -eq 'RunAs32Bit' }).InnerText
                            $detectionTypeExecutionContext = $object.Installer.DetectAction.Args.Arg.Where({ $_.Name -eq 'ExecutionContext' }).InnerText
                            $detectionTypeScriptType = $object.Installer.DetectAction.Args.Arg.Where({ $_.Name -eq 'ScriptType' }).InnerText
        
                            # ScriptType
                            # 0 = PowerShell
                            # 1 = VBScript
                            # 2 = JavaScript
        
                            Switch ($detectionTypeScriptType) {
                                '0' {
                                    $detectionTypeScriptFileExtension = '.ps1'
                                }
                                '1' {
                                    $detectionTypeScriptFileExtension = '.vbs'
                                }
                                '2' {
                                    $detectionTypeScriptFileExtension = '.js'
                                }
                            }
        
                            # Extract only the encoded base64 script from the script body
                            $pattern = '# ENCODEDSCRIPT # Begin Configuration Manager encoded script block #\s*(.*?)\s*# ENCODEDSCRIPT# End Configuration Manager encoded script block'
                            $match = [regex]::Match($detectionTypeScriptBody, $pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
        
                            if ($match.Success) {
                                $extractedContent = $match.Groups[1].Value

                                # Decode the Base64 string
                                $scriptContent = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($extractedContent))
                                 
                                # We need to trim the script to honor digital signatures
                                # Split the original string into lines
                                $lines = $scriptContent -split "`r`n"

                                # Remove the last line because the xml adds padding before the encoded string
                                $lines = $lines[0..($lines.Count - 2)]

                                # Join the lines back into a single string
                                $finalScriptContent = $lines -join "`r`n"
                                    
                                # Write the detection method to a file
                                $detectionMethodFile = Join-Path -Path $detectionMethodsFolder -ChildPath "DetectionScript$detectionTypeScriptFileExtension"
                                    
                                try {
                                    $finalScriptContent | Out-File -FilePath $detectionMethodFile -Force -Encoding UTF8
                                    Write-Log -Message ("Detection method script saved to file '{0}'" -f $detectionMethodFile) -LogId $LogId
                                    Write-Host ("Detection method script saved to file '{0}'" -f $detectionMethodFile) -ForegroundColor Green
                                }
                                catch {
                                    Write-Log -Message ("Could not write detection method to file '{0}'" -f $detectionMethodFile) -LogId $LogId -Severity 2
                                    Write-Host ("Could not write detection method to file '{0}'" -f $detectionMethodFile) -ForegroundColor Yellow
                                }
                            }
                            else {
                                Write-Log -Message ("Could not get ScriptBody encoded base64 value for deployment type '{0}'" -f $object.Title.InnerText) -LogId $LogId -Severity 2
                                Write-Host ("Could not get ScriptBody encoded base64 value for deployment type '{0}'" -f $object.Title.InnerText) -ForegroundColor Yellow
                            }
                        }
                        'Local' {
                            $detectionTypeExecutionContext = $object.Installer.DetectAction.Args.Arg.Where({ $_.Name -eq 'ExecutionContext' }).InnerText
                            $detectionTypeMethodBody = $object.Installer.DetectAction.Args.Arg.Where({ $_.Name -eq 'MethodBody' }).InnerText
        
                            # Write the detection method to file
                            $detectionMethodFile = Join-Path -Path $detectionMethodsFolder -ChildPath 'MethodBody.xml'

                            try {
                                $detectionTypeMethodBody | Out-File -FilePath $detectionMethodFile -Force -Encoding UTF8
                                Write-Log -Message ("Detection method XML saved to file '{0}'" -f $detectionMethodFile) -LogId $LogId
                                Write-Host ("Detection method XML saved to file '{0}'" -f $detectionMethodFile) -ForegroundColor Green
                            }
                            catch {
                                Write-Log -Message ("Could not write detection method to file '{0}'" -f $detectionMethodFile) -LogId $LogId -Severity 2
                                Write-Host ("Could not write detection method to file '{0}'" -f $detectionMethodFile) -ForegroundColor Yellow
                            }
                        }
                    }
                    
                    # Add detection method details to the PSCustomObject
                    $deploymentObject | Add-Member NoteProperty -Name DetectionTypeScriptRunAs32Bit -Value $detectionTypeScriptRunAs32Bit
                    $deploymentObject | Add-Member NoteProperty -Name DetectionTypeScriptType -Value $detectionTypeScriptType
                    $deploymentObject | Add-Member NoteProperty -Name DetectionTypeExecutionContext -Value $detectionTypeExecutionContext
                    $deploymentObject | Add-Member NoteProperty -Name DetectionMethodFile -Value $detectionMethodFile

                    Write-Log -Message ("Application_Id = '{0}', Application_Name = '{1}', Application_LogicalName = '{2}', LogicalName = '{3}', Name = '{4}', `
                    Technology = '{5}', ExecutionContext = '{6}', InstallContext = '{7}', InstallCommandLine = '{8}', UninstallSetting = '{9}', UninstallContent = '{10}', `
                    UninstallCommandLine = '{11}', ExecuteTime = '{12}', MaxExecuteTime = '{13}', DetectionProvider = '{14}', DetectionTypeScriptRunAs32Bit = '{15}', `
                    DetectionTypeScriptType = '{16}', DetectionTypeExecutionContext = '{17}', DetectionMethodFile = '{18}'" -f `
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
                            $object.Installer.CustomData.MaxExecuteTime, `
                            $object.Installer.DetectAction.Provider, `
                            $detectionTypeScriptRunAs32Bit, `
                            $detectionTypeScriptType, `
                            $detectionTypeExecutionContext, `
                            $detectionMethodFile) -LogId $LogId

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
            Get-ScriptEnd -LogId $LogId -ErrorMessage $_.Exception.Message
        }
    }
}