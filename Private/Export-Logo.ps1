<#
.Synopsis
Created on:   21/03/2021
Created by:   Ben Whitmore
Filename:     Export-Logo.ps1

.Description
Function to export logo from selected ConfigMgr Application
#>
Function Export-Logo {

    Param (
        [String]$IconId,
        [String]$AppName
    )

    Write-Log -Message "Function: Export-Logo was called" -Log "Main.log" 
    Write-Host "Preparing to export Application Logo for ""$($AppName)"""
    If ($IconId) {

        #Check destination folder exists for logo
        If (!(Test-Path $WorkingFolder_Logos)) {
            Try {
                Write-Log -Message "New-Item -Path $($WorkingFolder_Logos) -ItemType Directory -Force -ErrorAction Stop | Out-Null" -Log "Main.log"
                New-Item -Path $WorkingFolder_Logos -ItemType Directory -Force -ErrorAction Stop | Out-Null
            }
            Catch {
                Write-Log -Message "Warning: Couldn't create ""$($WorkingFolder_Logos)"" folder for Application Logos" -Log "Main.log"
                Write-Host "Warning: Couldn't create ""$($WorkingFolder_Logos)"" folder for Application Logos" -ForegroundColor Red
            }
        }

        #Continue if Logofolder exists
        If (Test-Path $WorkingFolder_Logos) {
            Write-Log -Message "`$LogoFolder_Id = (Join-Path -Path $($WorkingFolder_Logos) -ChildPath $($IconId))" -Log "Main.log"
            $LogoFolder_Id = (Join-Path -Path $WorkingFolder_Logos -ChildPath $IconId)
            Write-Log -Message "`$Logo_File = (Join-Path -Path $($LogoFolder_Id) -ChildPath Logo.jpg)" -Log "Main.log"
            $Logo_File = (Join-Path -Path $LogoFolder_Id -ChildPath Logo.jpg)

            #Continue if logo does not already exist in destination folder
            If (!(Test-Path $Logo_File)) {

                If (!(Test-Path $LogoFolder_Id)) {
                    Try {
                        Write-Log -Message "New-Item -Path $($LogoFolder_Id) -ItemType Directory -Force -ErrorAction Stop | Out-Null" -Log "Main.log" 
                        New-Item -Path $LogoFolder_Id -ItemType Directory -Force -ErrorAction Stop | Out-Null
                    }
                    Catch {
                        Write-Log -Message "Warning: Couldn't create ""$($LogoFolder_Id)"" folder for Application Logo" -Log "Main.log" 
                        Write-Host "Warning: Couldn't create ""$($LogoFolder_Id)"" folder for Application Logo" -ForegroundColor Red
                    }
                }

                #Continue if Logofolder\<IconId> exists
                If (Test-Path $LogoFolder_Id) {
                    Try {
                        #Grab the SDMPackgeXML which contains the Application and Deployment Type details
                        Write-Log -Message "`$XMLPackage = Get-CMApplication -Name ""$($AppName)"" | Where-Object { `$Null -ne `$_.SDMPackageXML } | Select-Object -ExpandProperty SDMPackageXML" -Log "Main.log" 
                        $XMLPackage = Get-CMApplication -Name $AppName | Where-Object { $Null -ne $_.SDMPackageXML } | Select-Object -ExpandProperty SDMPackageXML

                        #Deserialize SDMPackageXML
                        $XMLContent = [xml]($XMLPackage)

                        $Raw = $XMLContent.AppMgmtDigest.Resources.icon.Data
                        $Logo = [Convert]::FromBase64String($Raw)
                        [System.IO.File]::WriteAllBytes($Logo_File, $Logo)
                        If (Test-Path $Logo_File) {
                            Write-Log -Message "Success: Application logo for ""$($AppName)"" exported successfully to ""$($Logo_File)""" -Log "Main.log" 
                            Write-Host "Success: Application logo for ""$($AppName)"" exported successfully to ""$($Logo_File)""" -ForegroundColor Green
                        }
                    }
                    Catch {
                        Write-Log -Message "Warning: Could not export Logo to folder ""$($LogoFolder_Id)""" -Log "Main.log" 
                        Write-Host "Warning: Could not export Logo to folder ""$($LogoFolder_Id)""" -ForegroundColor Red
                    }
                }
            }
            else {
                Write-Log -Message "Information: Did not export Logo for ""$($AppName)"" to ""$($Logo_File)"" because the file already exists" -Log "Main.log"
                Write-Host "Information: Did not export Logo for ""$($AppName)"" to ""$($Logo_File)"" because the file already exists" -ForegroundColor Magenta
            }
        }
    }
    else {
        Write-Log -Message "Warning: Null or invalid IconId passed to function. Could not export Logo" -Log "Main.log" 
        Write-Host "Warning: Null or invalid IconId passed to function. Could not export Logo" -ForegroundColor Red
    }
}