<#
.Synopsis
Created on:   26/10/2023
Updated on:   17/02/2024
Created by:   Ben Whitmore
Filename:     Connect-SiteServer.ps1

.Description
Function to connect to a Site Server

.PARAMETER LogID
The component (script name) passed as LogID to the 'Write-Log' function. 
This parameter is built from the line number of the call from the function up the pipeline

.PARAMETER SiteCode
The Site Code of the Site Server to connect to
The Site Code must be only 3 alphanumeric characters

.PARAMETER ProviderMachineName
The Server name that has an SMS Provider site system role

.EXAMPLE
Connect-SiteServer -SiteCode "ABC" -ProviderMachineName "ABC-SMS01.contoso.local"
#>
function Connect-SiteServer {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = "The component (script name) passed as LogID to the 'Write-Log' function")]
        [string]$LogId = $($MyInvocation.MyCommand).Name,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 0, HelpMessage = 'The Site Code of the ConfigMgr Site')]
        [ValidatePattern('(?##The Site Code must be only 3 alphanumeric characters##)^[a-zA-Z0-9]{3}$')]
        [String]$SiteCode,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 1, HelpMessage = "Server name that has an SMS Provider site system role")]
        [String]$ProviderMachineName
    )

    begin {
        Write-Log -Message "Function: Connect-SiteServer was called" 
        Write-Log -Message "Import-Module `$ENV:SMS_ADMIN_UI_PATH\..\ConfigurationManager.psd1"
        Write-Host ("Importing Module: 'ConfigurationManager.psd1' and connecting to Provider '{0}'..." -f $ProviderMachineName) -ForegroundColor Cyan
    }
    
    process {

        # Import the ConfigurationManager.psd1 module 
        try {
            if (-not (Get-Module ConfigurationManager)) {
                Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" -Verbose:$false
            }
        }
        catch {
            Write-Log -Message "Warning: Could not import the ConfigurationManager.psd1 Module"
            Write-Warning "Warning: Could not import the 'ConfigurationManager.psd1' module"
            Write-Log -Message ("'{0}'" -f $_.Exception.Message) -LogId $LogId -Severity 3
            Get-ScriptEnd -LogId $LogId -ErrorMessage $_.Exception.Message
    }

        # Check the SMS Provider is valid
        if ( -not ( $ProviderMachineName -eq (Get-PSDrive -ErrorAction SilentlyContinue | Where-Object { $_.Provider -like "*CMSite*" }).Root ) ) {
            Write-Log -Message ("Could not connect to the Provider '{0}'" -f $ProviderMachineName) -Severity 3
            Write-Warning ("Could not connect to the Provider '{0}' `nDid you specify the correct Site System?" -f $ProviderMachineName)
            Write-Log -Message ("'{0}'" -f $_.Exception.Message) -LogId $LogId -Severity 3
            Get-ScriptEnd -LogId $LogId -ErrorMessage $_.Exception.Message
        }
        else {
            Write-Log -Message ("Connected to provider {0} at site '{1}'" -f $ProviderMachineName, $SiteCode )
            Write-Host ("Connected to provider '{0}'" -f $ProviderMachineName) -ForegroundColor Green
        }

        # Connect to the site drive if it is not already present
        try {
            if (!($SiteCode -eq ( Get-PSDrive -ErrorAction SilentlyContinue | Where-Object { $_.Provider -like "*CMSite*" }).Name) ) {
                Write-Log -Message ("No PSDrive found for '{0}' in PSProvider CMSite for Root '{1}'" -f $SiteCode, $ProviderMachineName) -LogId $LogId -Severity 3
                Write-Warning ("No PSDrive found for '{0}' in PSProvider CMSite for Root '{1}'. Did you specify the correct Site Code?" -f $SiteCode, $ProviderMachineName)
                Get-ScriptEnd -LogId $LogId -ErrorMessage $_.Exception.Message

            }
            else {
                Write-Log -Message ("Connected to PSDrive '{0}'" -f $SiteCode) -LogId $LogId
                Write-Host ("Connected to PSDrive '{0}'" -f $SiteCode) -ForegroundColor Green 
                Set-Location "$($SiteCode):\"
            }
        }
        catch {
            Write-Log -Message ("Warning: Could not connect to the specified provider '{0}' at site '{1}'" -f $ProviderMachineName, $SiteCode) -LogId $LogId -Severity 3
            Write-Warning ("Warning: Could not connect to the specified provider '{0}' at site '{1}'" -f $ProviderMachineName, $SiteCode)
            Get-ScriptEnd -ErrorMessage $_.Exception.Message -LogId $LogId 
        }
    }
}