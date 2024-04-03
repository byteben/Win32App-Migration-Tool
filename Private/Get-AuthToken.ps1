<#
.Synopsis
Created on:   22/01/2024
Updated on:   24/03/2024
Created by:   Ben Whitmore
Credit:       @NickolajA
Filename:     Get-AuthToken.ps1

.Description
Function to get an access token using MSAL.PS

.PARAMETER LogID
The component (script name) passed as LogID to the '#Write-Log' function. 
This parameter is built from the line number of the call from the function up the pipeline

.PARAMETER ModuleName
Module Name to use to get a token

.PARAMETER PackageProvider
Package Provider. If not specified, the default value NuGet is used

.PARAMETER ModuleScope
Module Scope. If not specified, the default value is used for CurrentUser

.PARAMETER TenantId
Tenant Id or name to connect to. This parameter is mandatory for obtaining a token

.PARAMETER ClientId
Client Id (App Registration) to connect to. This parameter is mandatory for obtaining a token

.PARAMETER ClientSecret
Client Secret for authentication

.PARAMETER ClientCertificateThumbrint
Client certificate thumbprint for authentication

.PARAMETER RedirectUri
RedirectUri to use for Client Id. If not specified, a default value is used based on the PowerShell version

.PARAMETER Scopes
The scopes to request from the Microsoft Graph API. If not specified, the default value is used for Application.ReadWrite.All

.PARAMETER RefreshToken
If specified, the token will be renewed

.PARAMETER UseDeviceAuthentication
This parameter will be used to determine if the device authentication flow should be used. If not specified, the default value is used for $false
#>
function Get-AuthToken {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = 'The component (script name) passed as LogID to the "#Write-Log" function')]
        [string]$LogId = $($MyInvocation.MyCommand).Name,
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = 'Module Name to connect to Graph')]
        [object]$ModuleName = ('MSAL.PS'),
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = 'If not specified, the default value NuGet is used for PackageProvider')]
        [string]$PackageProvider = 'NuGet',
        [Parameter(Mandatory = $true, ValuefromPipeline = $false, HelpMessage = 'Tenant Id or name to connect to')]
        [string]$TenantId,
        [Parameter(Mandatory = $true, ValuefromPipeline = $false, HelpMessage = 'Client Id (App Registration) to connect to')]
        [string]$ClientId,
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = 'Client secret for authentication')]
        [string]$ClientSecret,
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = 'Client certificate thumbprint for authentication')]
        [string]$ClientCertificateThumbprint,
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = 'If not specified, the default value is used for CurrentUser')]
        [string]$ModuleScope = 'CurrentUser',
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = 'RedirectUri to use for Client Id')]
        [string]$RedirectUri,
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = 'The scopes to request from the Microsoft Graph API')]
        [object]$Scopes = @('https://graph.microsoft.com/.default'),
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = 'Specify if the token should be renewed. If not specified, the default value is used for $false')]
        [Switch]$RefreshToken,
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = 'This parameter will be used to determine if the device authentication flow should be used. If not specified, the default value is used for $false')]
        [switch]$UseDeviceAuthentication = $false
    )

    begin {
        Write-Log -Message 'Function: Get-AuthToken was called' -LogId $LogId

        if (-not (Get-PackageProvider -ListAvailable -Name $PackageProvider)) {

            # Install the PackageProvider if it's not already installed
            Write-Log -Message ("PackageProvider not found. Will install PackageProvider '{0}'" -f $PackageProvider) -LogId $LogId
            Write-Host ("Installing PackageProvider '{0}'" -f $PackageProvider) -ForegroundColor Cyan
    
            try {
                Install-PackageProvider -Name $PackageProvider -ForceBootstrap -Confirm:$false -Verbose
            }
            catch {
                Write-Log -Message ("Warning: Could not install the PackageProvider '{0}'" -f $PackageProvider) -LogId $LogId -Severity 3
                Write-Warning ("Warning: Could not install the PackageProvider '{0}'" -f $PackageProvider)
                Write-Log -Message ("'{0}'" -f $_.Exception.Message) -LogId $LogId -Severity 3
                Get-ScriptEnd -ErrorMessage $_.Exception.Message -LogId $LogId 
            }
        }

        # Check if the module is installed
        foreach ($ModuleName in $ModuleName) {
            if (-not (Get-Module -ListAvailable -Name $ModuleName)) {

                # Install the module if it's not already installed
                Write-Log -Message ("Module not found. Will install module '{0}' in the scope of '{1}'" -f $ModuleName, $ModuleScope) -LogId $LogId
                Write-Host ("Installing module '{0}' in the scope of '{1}'" -f $ModuleName, $ModuleScope) -ForegroundColor Cyan
    
                try {
                    Install-Module -Name $ModuleName -Scope $ModuleScope -AllowClobber -Force -Confirm:$false
                }
                catch {
                    Write-Log -Message ("Warning: Could not install the module '{0}'" -f $ModuleName) -LogId $LogId -Severity 3
                    Write-Warning ("Warning: Could not install the module '{0}'" -f $ModuleName)
                    Write-Log -Message ("'{0}'" -f $_.Exception.Message) -LogId $LogId -Severity 3
                    Get-ScriptEnd -ErrorMessage $_.Exception.Message -LogId $LogId
                }
            }
            else {
                # Module is already installed, import it
                Write-Log -Message ("Module '{0}' is already installed" -f $ModuleName) -LogId $LogId
                Write-Host ("Module '{0}' is already installed" -f $ModuleName) -ForegroundColor Cyan

                if (-not (Get-Module -Name $ModuleName)) {

                    try {
                        Write-Log -Message ("Import-Module {0}" -f $ModuleName) -LogId $LogId
                        Write-Host ("Importing Module: '{0}'" -f $ModuleName) -ForegroundColor Cyan
                        Import-Module $ModuleName
                    }
                    catch {
                        Write-Log -Message ("Warning: Could not import the module '{0}'" -f $ModuleName) -LogId $LogId -Severity 3
                        Write-Warning ("Warning: Could not import the module '{0}'" -f $ModuleName)
                        Write-Log -Message ("'{0}'" -f $_.Exception.Message) -LogId $LogId -Severity 3
                        Get-ScriptEnd -ErrorMessage $_.Exception.Message -LogId $LogId 
                    }
                }
                else {
                    Write-Log -Message ("Module '{0}' is imported into PowerShell session" -f $ModuleName) -LogId $LogId
                    Write-Host ("Module '{0}' is imported into PowerShell session" -f $ModuleName) -ForegroundColor Cyan
                }
            }
        }
    }

    process {

        # Check if the redirect URI is specified, if not set it depending on the PowerShell version
        Write-Log -Message ("PowerShell version is '{0}'" -f $PSVersionTable.PSVersion) -LogId $LogId
        Write-Host ("PowerShell version is '{0}'" -f $PSVersionTable.PSVersion) -ForegroundColor Cyan

        if ($PSVersionTable.PSVersion.Major -lt 7) {
            $RedirectUri = 'https://login.microsoftonline.com/common/oauth2/nativeclient'
        }
        else {
            $RedirectUri = "http://localhost"
        }

        Write-Log -Message ("Setting redirect URI to '{0}'" -f $RedirectUri) -LogId $LogId

        # Build connection splat
        $tokenSplat = [ordered]@{
            'TenantId'    = $TenantId
            'ClientId'    = $ClientId
            'RedirectUri' = $RedirectUri
            'Scopes'      = $Scopes
        }

        # Add autnehntication method to the token splat
        if ($PSBoundParameters.ContainsKey('ClientSecret')) {
            $tokenSplat.Add("ClientSecret", $(ConvertTo-SecureString $ClientSecret -AsPlainText -Force))
        }
        elseif ($PSBoundParameters.ContainsKey('ClientCertificateThumbprint')) {

            # Get the client certificate from the certificate store
            $ClientCertificate = Get-ClientCertificate -Thumbprint $ClientCertificateThumbprint
            if (-not $ClientCertificate) {
                Get-ScriptEnd -ErrorMessage ("Failed to get a client certificate with thumbprint: {0}" -f $ClientCertificateThumbprint) -LogId $LogId
            }
            else {
                Write-Log -Message ("Successfully retrieved client certificate with thumbprint: {0}" -f $ClientCertificate.Thumbprint) -LogId $LogId
                Write-Host ("Successfully retrieved client certificate with thumbprint: {0}" -f $ClientCertificate.Thumbprint) -ForegroundColor Green
                $tokenSplat.Add("ClientCertificate", $ClientCertificate)
            }
        }
        else {
            $tokenSplat.Add('DeviceCode', $true)
        }

        # Check if we need to renew the token
        if ($PSBoundParameters["RefreshToken"]) {
            $tokenSplat.Add("ForceRefresh", $true)
        }

        # Attempt to obtain an access token
        try {
            Write-Log -Message ("Attempting to connect. Token Splat: '{0}'" -f $tokenSplat ) -LogId $LogId
            Write-Host "Attempting to connect..." -ForegroundColor Cyan
            foreach ($key in $tokenSplat.Keys) {
                if ($key -eq 'ClientCertificate') {
                    Write-Host ("{0}: {1}" -f $key, $tokenSplat[$key].Subject) -ForegroundColor Cyan
                }
                else {
                    Write-Host ("{0}: {1}" -f $key, $($tokenSplat[$key])) -ForegroundColor Cyan
                }
            }

            $Global:token = Get-MsalToken @tokenSplat -Verbose
        }
        catch {
            Write-Warning -Message ("'{0}'" -f $_.Exception.Message)
            Write-Log -Message ("'{0}'" -f $_.Exception.Message) -LogId $LogId -Severity 3
            Get-ScriptEnd -ErrorMessage 'Failed to get a token' -LogId $LogId
        }

        # Check if the connection is successful
        if ($token) {
            Write-Log -Message 'Successfully connected' -LogId $LogId
            Write-Log -Message ("Token expires on: {0}" -f $token.ExpiresOn.UtcDateTime) -LogId $LogId
            Write-Host 'Successfully connected' -ForegroundColor Green
            Write-Host ("Token expires on (UTC): {0}" -f $token.ExpiresOn.UtcDateTime) -ForegroundColor Green

            # Create the authentication header
            try {
                $Global:authHeader = @{
                    "Content-Type"  = "application/json"
                    "Authorization" = $token.CreateAuthorizationHeader()
                    "ExpiresOn"     = $token.ExpiresOn.UTCDateTime
                }
                Write-Log -Message 'Successfully created authentication header' -LogId $LogId
                Write-Host 'Successfully created authentication header' -ForegroundColor Green            
            }
            catch {
                Write-Warning -Message ("'{0}'" -f $_.Exception.Message)
                Get-ScriptEnd -ErrorMessage 'Failed to create authentication header' -LogId $LogId
            }
        }
        else {
            Get-ScriptEnd -ErrorMessage 'Failed to connect' -LogId $LogId 
        }
    }
}