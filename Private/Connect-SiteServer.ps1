<#
.Synopsis
Created on:   28/10/2023
Updated on:   01/01/2025
Created by:   Ben Whitmore
Filename:     Connect-SiteServer.ps1

.Description
Function to connect to a ConfigMgr site server

.PARAMETER LogId
The component (script name) passed as LogID to the 'Write-Log' function. 
This parameter is built from the line number of the call from the function up the

.PARAMETER SiteCode
The Site Code of the ConfigMgr Site. If not provided, the function will attempt to retrieve it from the provider machine

.PARAMETER ProviderMachineName
Server name that has an SMS Provider site system role
#>
function Connect-SiteServer {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = "The component (script name) passed as LogID to the 'Write-Log' function")]
        [string]$LogId = $($MyInvocation.MyCommand).Name,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 0, HelpMessage = 'The Site Code of the ConfigMgr Site')]
        [ValidatePattern('(?##The Site Code must be only 3 alphanumeric characters##)^[a-zA-Z0-9]{3}$')]
        [String]$SiteCode,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 1, HelpMessage = "Server name that has an SMS Provider site system role")]
        [String]$ProviderMachineName
    )

    begin {
        Write-LogAndHost -Message "Function: Connect-SiteServer was called" -LogId $LogId -ForegroundColor Cyan
        Write-LogAndHost ("Importing Module: 'ConfigurationManager.psd1' and connecting to Provider '{0}'..." -f $ProviderMachineName) -LogId $LogId -ForegroundColor Cyan
    }
    
    process {
        $attempt = 0
        $maxAttempts = 3
        $siteCodeRetrieved = $false

        # Attempt to retrieve the Site Code from the provider machine
        while (-not $siteCodeRetrieved -and $attempt -lt $maxAttempts) {

            if (-not $SiteCode) {
                try {

                    # Get the Site Code from the provider machine
                    $siteCodeQuery = Get-CIMInstance -Namespace "root\SMS" -Class "SMS_ProviderLocation" -ComputerName $ProviderMachineName
                    $SiteCode = $siteCodeQuery.SiteCode
                    Write-LogAndHost -Message ("Retrieved Site Code: {0}" -f $SiteCode) -LogId $LogId -ForegroundColor Green
                    $siteCodeRetrieved = $true
                }
                catch {
                    Write-LogAndHost -Message "Failed to retrieve Site Code from provider machine: $($_.Exception.Message)" -Severity 3
                }
            }
            else {
                $siteCodeRetrieved = $true
            }

            # If the Site Code was not retrieved, prompt the user to enter it
            if (-not $siteCodeRetrieved) {
                $SiteCode = Read-Host -Prompt "Please enter the Site Code (3 alphanumeric characters)"

                if ($SiteCode -match '^[a-zA-Z0-9]{3}$') {
                    $siteCodeRetrieved = $true
                }
                else {
                    Write-LogAndHost -Message ("Invalid Site Code entered: {0}" -f $SiteCode) -LogId $LogId -Severity 3
                }
            }

            $attempt++
        }

        # If the Site Code was not retrieved after the maximum attempts, throw an error
        if (-not $siteCodeRetrieved) {
            Write-LogAndHost -Message ("Failed to retrieve or enter a valid Site Code after {0} attempts." -f $maxAttempts) -LogId $LogId -Severity 3

            throw
        }

        # Import the ConfigurationManager.psd1 module 
        try {
            if (-not (Get-Module ConfigurationManager)) {
                Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" -Verbose:$false
            }
        }
        catch {
            Write-LogAndHost -Message "Failed to import ConfigurationManager module: $($_.Exception.Message)" -LogId $LogId -Severity 3

            throw
        }

        # Connect to the site
        try {
            Set-Location "$SiteCode`:"
            Write-LogAndHost ("Connected to site: {0}" -f $SiteCode) -LogId $LogId -ForegroundColor Green
        }
        catch {
            Write-LogAndHost -Message ("Failed to connect to site: {0}" -f $_.Exception.Message) -LogId $LogId -Severity 3
            
            throw
        }
    }
}