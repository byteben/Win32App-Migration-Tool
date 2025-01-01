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
        Write-Log -Message "Function: Connect-SiteServer was called" 
        Write-Log -Message "Import-Module `$ENV:SMS_ADMIN_UI_PATH\..\ConfigurationManager.psd1"
        Write-Host ("Importing Module: 'ConfigurationManager.psd1' and connecting to Provider '{0}'..." -f $ProviderMachineName) -ForegroundColor Cyan
    }
    
    process {
        $attempt = 0
        $maxAttempts = 3
        $siteCodeRetrieved = $false

        while (-not $siteCodeRetrieved -and $attempt -lt $maxAttempts) {
            if (-not $SiteCode) {
                try {
                    $siteCodeQuery = Get-CIMInstance -Namespace "root\SMS" -Class "SMS_ProviderLocation" -ComputerName $ProviderMachineName
                    $SiteCode = $siteCodeQuery.SiteCode
                    Write-Log -Message "Retrieved Site Code: $SiteCode"
                    Write-Host ("Retrieved Site Code: {0}" -f $SiteCode) -ForegroundColor Green
                    $siteCodeRetrieved = $true
                }
                catch {
                    Write-Log -Message "Failed to retrieve Site Code from provider machine: $($_.Exception.Message)" -Severity 3
                    Write-Host ("Failed to retrieve Site Code from provider machine: {0}" -f $_.Exception.Message) -ForegroundColor Red
                }
            }
            else {
                $siteCodeRetrieved = $true
            }

            if (-not $siteCodeRetrieved) {
                $SiteCode = Read-Host -Prompt "Please enter the Site Code (3 alphanumeric characters)"
                if ($SiteCode -match '^[a-zA-Z0-9]{3}$') {
                    $siteCodeRetrieved = $true
                }
                else {
                    Write-Log -Message "Invalid Site Code entered: $SiteCode" -Severity 3
                    Write-Host "Invalid Site Code entered. Please try again." -ForegroundColor Red
                }
            }

            $attempt++
        }

        if (-not $siteCodeRetrieved) {
            Write-Log -Message "Failed to retrieve or enter a valid Site Code after $maxAttempts attempts." -Severity 3
            Write-Host "Failed to retrieve or enter a valid Site Code after $maxAttempts attempts." -ForegroundColor Red
            throw "Failed to retrieve or enter a valid Site Code after $maxAttempts attempts."
        }

        # Import the ConfigurationManager.psd1 module 
        try {
            if (-not (Get-Module ConfigurationManager)) {
                Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" -Verbose:$false
            }
        }
        catch {
            Write-Log -Message "Failed to import ConfigurationManager module: $($_.Exception.Message)" -Severity 3
            Write-Host ("Failed to import ConfigurationManager module: {0}" -f $_.Exception.Message) -ForegroundColor Red
            throw
        }

        # Connect to the site
        try {
            Set-Location "$SiteCode`:"
            Write-Log -Message "Connected to site: $SiteCode"
            Write-Host ("Connected to site: {0}" -f $SiteCode) -ForegroundColor Green
        }
        catch {
            Write-Log -Message "Failed to connect to site: $($_.Exception.Message)" -Severity 3
            Write-Host ("Failed to connect to site: {0}" -f $_.Exception.Message) -ForegroundColor Red
            throw
        }
    }
}