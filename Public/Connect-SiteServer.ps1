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

    # Import the ConfigurationManager.psd1 module 
    Try {
        If ($Null -eq (Get-Module ConfigurationManager)) {
            Write-Log -Message "Import-Module $($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" -Log "Main.log"
            Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1"
        }
    }
    Catch {
        Write-Log -Message "Warning: Could not import the ConfigurationManager.psd1 Module" -Log "Main.log"
        Write-Host 'Warning: Could not import the ConfigurationManager.psd1 Module' -ForegroundColor Red
    }

    # Connect to the site's drive if it is not already present
    Try {
        if ($Null -eq (Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue)) {
            Write-Log -Message "New-PSDrive -Name $($SiteCode) -PSProvider CMSite -Root $($ProviderMachineName)" -Log "Main.log"
            New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName
        }
        #Set the current location to be the site code.
        Write-Log -Message "Set-Location $($SiteCode):\" -Log "Main.log"
        Set-Location "$($SiteCode):\"
        Write-Log -Message "Connected to provider $($ProviderMachineName) at site $($SiteCode)" -Log "Main.log" 
        Write-Host "Connected to provider ""$($ProviderMachineName)"" at site ""$($SiteCode)""" -ForegroundColor Green
    }
    Catch {
        Write-Log -Message "Warning: Could not connect to the specified provider $($ProviderMachineName) at site $($SiteCode)" -Log "Main.log"
        Write-Host "Warning: Could not connect to the specified provider ""$($ProviderMachineName)"" at site ""$($SiteCode)""" -ForegroundColor Red
    }
    
}