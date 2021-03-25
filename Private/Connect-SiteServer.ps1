<#
.Synopsis
Created on:   21/03/2021
Created by:   Ben Whitmore
Filename:     Connect-SiteServer.ps1

.Description
Function to conect to a Site Server
#>
Function Connect-SiteServer {
    Param (
        [String]$SiteCode,
        [String]$ProviderMachineName
    )

    Write-Log -Message "Function: Connect-SiteServer was called" -Log "Main.log" 
    Write-Log -Message "Import-Module $($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" -Log "Main.log"
    Write-Host "Importing Module: ConfigurationManager.psd1 and connecting to Provider $($ProviderMachineName)..." -ForegroundColor Cyan
            
    # Import the ConfigurationManager.psd1 module 
    Try {
        If ($Null -eq (Get-Module ConfigurationManager)) {
            Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" -Verbose:$False
        }
    }
    Catch {
        Write-Log -Message "Warning: Could not import the ConfigurationManager.psd1 Module" -Log "Main.log"
        Write-Host 'Warning: Could not import the ConfigurationManager.psd1 Module' -ForegroundColor Red
        break
    }

    # Check Provider is valid
    if (!($ProviderMachineName -eq (Get-PSDrive -ErrorAction SilentlyContinue | Where-Object { $_.Provider -like "*CMSite*" }).Root)) {
        Write-Log -Message "Could not connect to the Provider $($ProviderMachineName). Did you specify the correct Site Server?" -Log "Main.log"
        Write-Host "Could not connect to the Provider $($ProviderMachineName). Did you specify the correct Site Server?" -ForegroundColor Red
        Get-ScriptEnd
        break
    }
    else {
        Write-Log -Message "Connected to provider $($ProviderMachineName) at site $($SiteCode)" -Log "Main.log" 
        Write-Host "Connected to provider ""$($ProviderMachineName)""" -ForegroundColor Green
    }

    # Connect to the site's drive if it is not already present
    Try {
        if (!($SiteCode -eq (Get-PSDrive -ErrorAction SilentlyContinue | Where-Object { $_.Provider -like "*CMSite*" }).Name)) {
            Write-Log -Message "No PSDrive found for $($SiteCode) in PSProvider CMSite for Root $($ProviderMachineName)" -Log "Main.log"
            Write-Host "No PSDrive found for $($SiteCode) in PSProvider CMSite for Root $($ProviderMachineName). Did you specify the correct Site Code?" -ForegroundColor Red
            Get-ScriptEnd
            break
        }
        else {
            Write-Log -Message "Connected to PSDrive $($SiteCode)" -Log "Main.log" 
            Write-Host "Connected to PSDrive $($SiteCode)" -ForegroundColor Green
            Set-Location "$($SiteCode):\"
        }
    }
    Catch {
        Write-Log -Message "Warning: Could not connect to the specified provider $($ProviderMachineName) at site $($SiteCode)" -Log "Main.log"
        Write-Host "Warning: Could not connect to the specified provider ""$($ProviderMachineName)"" at site ""$($SiteCode)""" -ForegroundColor Red
        break
    }
    
}