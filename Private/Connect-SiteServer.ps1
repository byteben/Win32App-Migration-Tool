<#
.Synopsis
Created on:   28/10/2023
Updated on:   16/11/2026
Created by:   Ben Whitmore
Filename:     Connect-SiteServer.ps1

.Description
Function to connect to a ConfigMgr site server. The caller's location is saved in
$global:Win32AppMigrationTool_OriginalLocation (if not already set) so Get-ScriptEnd can restore it.

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
        Write-LogAndHost -Message ("Importing Module: 'ConfigurationManager' and connecting to Provider '{0}'..." -f $ProviderMachineName) -LogId $LogId -ForegroundColor Cyan
    }
    
    process {
        $attempt = 0
        $maxAttempts = 3
        $siteCodeRetrieved = $false

        # Attempt to retrieve the Site Code from the provider machine
        while (-not $siteCodeRetrieved -and $attempt -lt $maxAttempts) {

            if (-not $SiteCode) {
                try {

                    # Get the Site Code from the provider machine. There can be several providers, take the first
                    $retrieved = Get-CimInstance -Namespace 'root\SMS' -ClassName 'SMS_ProviderLocation' -ComputerName $ProviderMachineName -ErrorAction Stop |
                        Select-Object -First 1 -ExpandProperty SiteCode

                    if ($retrieved) {
                        $SiteCode = $retrieved
                        Write-LogAndHost -Message ("Retrieved Site Code: {0}" -f $SiteCode) -LogId $LogId -ForegroundColor Green
                        $siteCodeRetrieved = $true
                    }
                    else {
                        Write-LogAndHost -Message ("No SMS_ProviderLocation instance was returned by '{0}'" -f $ProviderMachineName) -LogId $LogId -Severity 3
                    }
                }
                catch {
                    Write-LogAndHost -Message "Failed to retrieve Site Code from provider machine: $($_.Exception.Message)" -LogId $LogId -Severity 3
                }
            }
            else {
                $siteCodeRetrieved = $true
            }

            # If the Site Code was not retrieved, prompt the user to enter it
            if (-not $siteCodeRetrieved) {
                # Read into a separate variable: $SiteCode has [ValidatePattern], so assigning invalid input to it throws
                $enteredSiteCode = Read-Host -Prompt "Please enter the Site Code (3 alphanumeric characters)"

                if ($enteredSiteCode -match '^[a-zA-Z0-9]{3}$') {
                    $SiteCode = $enteredSiteCode
                    $siteCodeRetrieved = $true
                }
                else {
                    Write-LogAndHost -Message ("Invalid Site Code entered: {0}" -f $enteredSiteCode) -LogId $LogId -Severity 3
                }
            }

            $attempt++
        }

        # If the Site Code was not retrieved after the maximum attempts, throw an error
        if (-not $siteCodeRetrieved) {
            $message = "Failed to retrieve or enter a valid Site Code after {0} attempts" -f $maxAttempts
            Write-LogAndHost -Message $message -LogId $LogId -Severity 3
            throw $message
        }

        # Import the ConfigurationManager module
        try {
            if (-not (Get-Module ConfigurationManager)) {
                if ($env:SMS_ADMIN_UI_PATH) {
                    Import-Module "$($env:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" -Verbose:$false -ErrorAction Stop
                }
                else {
                    Import-Module ConfigurationManager -Verbose:$false -ErrorAction Stop
                }
            }
        }
        catch {
            $message = "Failed to import the ConfigurationManager module: $($_.Exception.Message)"
            Write-LogAndHost -Message $message -LogId $LogId -Severity 3
            throw $message
        }

        # Connect to the site
        try {

            # Save the caller's location so it can be restored by Get-ScriptEnd
            if (-not $global:Win32AppMigrationTool_OriginalLocation) {
                $global:Win32AppMigrationTool_OriginalLocation = (Get-Location).Path
            }

            # Create the site drive if it does not exist (first import of the module on this computer)
            if (-not (Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue)) {
                New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName -Scope Global | Out-Null
            }

            Set-Location -Path "$SiteCode`:" -ErrorAction Stop
            Write-LogAndHost -Message ("Connected to site: {0}" -f $SiteCode) -LogId $LogId -ForegroundColor Green
        }
        catch {
            $message = "Failed to connect to site '{0}': {1}" -f $SiteCode, $_.Exception.Message
            Write-LogAndHost -Message $message -LogId $LogId -Severity 3
            throw $message
        }
    }
}
