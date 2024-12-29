<#
.Synopsis
Created on:   28/12/2024
Created by:   Ben Whitmore
Filename:     Connect-MgGraphCustom.ps1

.Description
Function to connect to Microsoft Graph using various authentication methods

.PARAMETER LogID
The component (script name) passed as LogID to the 'Write-Log' function

.PARAMETER ModuleName
Module Name to use to connect to Graph. Default is Microsoft.Graph.Authentication

.PARAMETER PackageProvider
Package Provider. If not specified, the default value NuGet is used

.PARAMETER ModuleScope
Module Scope. If not specified, the default value is used for CurrentUser

.PARAMETER TenantId
Tenant Id or name to connect to. This parameter is mandatory for obtaining a connection

.PARAMETER ClientId
Client Id (App Registration) to connect to. This parameter is mandatory for obtaining a connection

.PARAMETER ClientSecret
Client Secret for authentication

.PARAMETER ClientCertificateThumbprint
Client certificate thumbprint for authentication

.PARAMETER Scopes
The scopes to request from the Microsoft Graph API. If not specified, the default value is used for .default

.PARAMETER UseDeviceAuthentication
This parameter will be used to determine if the device authentication flow should be used. If not specified, the default value is used for $false
#>
function Connect-MgGraphCustom {
    [CmdletBinding(DefaultParameterSetName = 'Interactive')]
    param (
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, HelpMessage = 'The component (script name) passed as LogID to the "Write-Log" function')]
        [string]$LogId = $($MyInvocation.MyCommand).Name,

        [Parameter(Mandatory = $false, ValueFromPipeline = $false, HelpMessage = 'Module Name to connect to Graph. Default is Microsoft.Graph.Authentication')]
        [object]$ModuleName = ('Microsoft.Graph.Authentication'),

        [Parameter(Mandatory = $false, ValueFromPipeline = $false, HelpMessage = 'If not specified, the default value NuGet is used for PackageProvider')]
        [string]$PackageProvider = 'NuGet',

        [Parameter(Mandatory = $true, ParameterSetName = 'ClientSecret', HelpMessage = 'Tenant Id or name to connect to')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ClientCertificateThumbprint', HelpMessage = 'Tenant Id or name to connect to')]
        [Parameter(Mandatory = $true, ParameterSetName = 'UseDeviceAuthentication', HelpMessage = 'Tenant Id or name to connect to')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Interactive', HelpMessage = 'Tenant Id or name to connect to')]
        [string]$TenantId,

        [Parameter(Mandatory = $true, ParameterSetName = 'ClientSecret', HelpMessage = 'Client Id (App Registration) to connect to')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ClientCertificateThumbprint', HelpMessage = 'Client Id (App Registration) to connect to')]
        [Parameter(Mandatory = $true, ParameterSetName = 'UseDeviceAuthentication', HelpMessage = 'Client Id (App Registration) to connect to')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Interactive', HelpMessage = 'Client Id (App Registration) to connect to')]
        [string]$ClientId,

        [Parameter(Mandatory = $true, ParameterSetName = 'ClientSecret', HelpMessage = 'Client secret for authentication')]
        [string]$ClientSecret,

        [Parameter(Mandatory = $true, ParameterSetName = 'ClientCertificateThumbprint', HelpMessage = 'Client certificate thumbprint for authentication')]
        [string]$ClientCertificateThumbprint,

        [Parameter(Mandatory = $true, ParameterSetName = 'UseDeviceAuthentication', HelpMessage = 'Use device authentication for Microsoft Graph API')]
        [switch]$UseDeviceAuthentication,

        [Parameter(Mandatory = $false, HelpMessage = 'The scopes required for Microsoft Graph API access. Default is DeviceManagementApps.ReadWrite.All')]
        [string[]]$RequiredScopes = ('DeviceManagementApps.ReadWrite.All'),

        [Parameter(Mandatory = $false, ValueFromPipeline = $false, HelpMessage = 'Specifies the scope for installing the module. Default is CurrentUser')]
        [string]$ModuleScope = 'CurrentUser'
    )

    begin {

        Write-Log -Message 'Function: Connect-MgGraphCustom was called' -LogId $LogId
        Write-Log -Message "Resolved Parameter Set: $($PSCmdlet.ParameterSetName)" -LogId $LogId
        Write-Host "Resolved Parameter Set: $($PSCmdlet.ParameterSetName)" -ForegroundColor Cyan

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
        foreach ($Module in $ModuleName) {
            if (-not (Get-Module -ListAvailable -Name $Module)) {
                # Install the module if it's not already installed
                Write-Log -Message ("Module not found. Will install module '{0}' in the scope of '{1}'" -f $Module, $ModuleScope) -LogId $LogId
                Write-Host ("Installing module '{0}' in the scope of '{1}'" -f $Module, $ModuleScope) -ForegroundColor Cyan
    
                try {
                    Install-Module -Name $Module -Scope $ModuleScope -AllowClobber -Force -Confirm:$false
                }
                catch {
                    Write-Log -Message ("Warning: Could not install the module '{0}'" -f $Module) -LogId $LogId -Severity 3
                    Write-Warning ("Warning: Could not install the module '{0}'" -f $Module)
                    Write-Log -Message ("'{0}'" -f $_.Exception.Message) -LogId $LogId -Severity 3
                    Get-ScriptEnd -ErrorMessage $_.Exception.Message -LogId $LogId
                }
            }
            else {
                # Module is already installed, import it
                Write-Log -Message ("Module '{0}' is already installed" -f $Module) -LogId $LogId
                Write-Host ("Module '{0}' is already installed" -f $Module) -ForegroundColor Cyan

                if (-not (Get-Module -Name $Module)) {
                    try {
                        Write-Log -Message ("Import-Module {0}" -f $Module) -LogId $LogId
                        Write-Host ("Importing Module: '{0}'" -f $Module) -ForegroundColor Cyan
                        Import-Module $Module
                    }
                    catch {
                        Write-Log -Message ("Warning: Could not import the module '{0}'" -f $Module) -LogId $LogId -Severity 3
                        Write-Warning ("Warning: Could not import the module '{0}'" -f $Module)
                        Write-Log -Message ("'{0}'" -f $_.Exception.Message) -LogId $LogId -Severity 3
                        Get-ScriptEnd -ErrorMessage $_.Exception.Message -LogId $LogId 
                    }
                }
                else {
                    Write-Log -Message ("Module '{0}' is imported into PowerShell session" -f $Module) -LogId $LogId
                    Write-Host ("Module '{0}' is imported into PowerShell session" -f $Module) -ForegroundColor Cyan
                }
            }
        }
    }

    process {

        # First check if we already have a valid connection with required scopes
        if (Test-MgConnection -LogId $LogId -RequiredScopes $RequiredScopes -TestScopes) {
            Write-Log -Message "Using existing Microsoft Graph connection" -LogId $LogId
            Write-Host "Using existing Microsoft Graph connection" -ForegroundColor Green
            return
        }

        # If we don't have required scopes, set the default required scopes to create Win32 apps. This assumes the Connect-MgGraphCustom function is used outside of the New-Win32App function
        if (-not $RequiredScopes) {
            if (Test-Path variable:\global:scopes) {
                [string[]]$RequiredScopes = $global:scopes
                Write-Log -Message ("Required Scope defined already. Using existing required scopes: {0}" -f $RequiredScopes) -LogId $LogId
                Write-Host ("Required Scope defined already. Using existing required scopes: {0}" -f $RequiredScopes) -ForegroundColor Green
            }
            else {
                [string[]]$global:scopes = ('DeviceManagementApps.ReadWrite.All')
                [string[]]$RequiredScopes = $global:scopes
                Write-Log -Message ("Required Scope defined yet.Using default required scopes: {0}" -f $RequiredScopes) -LogId $LogId
                Write-Host ("Required Scope defined yet. Using default required scopes: {0}" -f $RequiredScopes) -ForegroundColor Green
            }
        }

        # Determine the authentication method based on provided parameters
        if ($PSCmdlet.ParameterSetName -eq 'ClientSecret') {
            $AuthenticationMethod = 'ClientSecret'
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'ClientCertificateThumbprint') {
            $AuthenticationMethod = 'ClientCertificateThumbprint'
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'UseDeviceAuthentication') {
            $AuthenticationMethod = 'UseDeviceAuthentication'
        }
        else {
            $AuthenticationMethod = 'Interactive'
        }

        # If we don't have a valid connection, proceed with connection based on parameters
        $connectMgParams = [ordered]@{
            TenantId = $TenantId
        }

        switch ($AuthenticationMethod) {
            'ClientSecret' {
                $secureClientSecret =  ConvertTo-SecureString -String $ClientSecret -AsPlainText -Force
                $credential = New-Object System.Management.Automation.PSCredential -ArgumentList $ClientId, $secureClientSecret
                $connectMgParams['ClientSecretCredential'] = $credential
            }
            'ClientCertificateThumbprint' {
                $connectMgParams['ClientId'] = $ClientId
                $connectMgParams['CertificateThumbprint'] = $ClientCertificateThumbprint
            }
            'UseDeviceAuthentication' {
                $connectMgParams['ClientId'] = $ClientId
                $connectMgParams['UseDeviceCode'] = $true
                $connectMgParams['Scopes'] = $RequiredScopes
            }
            'Interactive' {
                $connectMgParams['ClientId'] = $ClientId
                $connectMgParams['Scopes'] = $RequiredScopes
            }
            default {
                Write-Log -Message ("Unknown authentication method: {0}" -f $AuthenticationMethod) -LogId $LogId -Severity 3
                Write-Warning ("Unknown authentication method: {0}" -f $AuthenticationMethod)
                break
            }
        }

        # Convert the parameters to a string for logging
        $connectMgParamsString = 'Connect-MgGraph ' + ($connectMgParams.Keys | ForEach-Object { '-{0} {1}' -f $_, $connectMgParams.$_ }) -join ' '
        Write-Host "Connecting to Microsoft Graph with the following parameters: $connectMgParamsString" -ForegroundColor Cyan
        Write-Log -Message "Connecting to Microsoft Graph with the following parameters: $connectMgParamsString" -LogId $LogId
            
        try {
            # Explicitly pass the parameters to Connect-MgGraph
            if ($AuthenticationMethod -eq 'ClientSecret') {
                Connect-MgGraph -TenantId $TenantId -ClientSecretCredential $connectMgParams['ClientSecretCredential'] -NoWelcome
            }
            elseif ($AuthenticationMethod -eq 'ClientCertificateThumbprint') {
                Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -CertificateThumbprint $ClientCertificateThumbprint -NoWelcome
            }
            elseif ($AuthenticationMethod -eq 'UseDeviceAuthentication') {
                Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -UseDeviceCode -Scopes $connectMgParams['Scopes'] -NoWelcome
            }
            else {
                Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -Interactive -Scopes $connectMgParams['Scopes'] -NoWelcome
            }
        }
        catch {
            Write-Log -Message ("Failed to connect to Microsoft Graph: {0}" -f $_.Exception.Message) -LogId $LogId -Severity 3
            Write-Warning ("Failed to connect to Microsoft Graph: {0}" -f $_.Exception.Message)
        }
            
        if (Test-MgConnection -LogId $LogId -RequiredScopes $RequiredScopes) {
            Write-Log -Message "Successfully connected to Microsoft Graph" -LogId $LogId
            Write-Host "Successfully connected to Microsoft Graph" -ForegroundColor Green
                
            # Get and display connection details
            $context = Get-MgContext
            if ($AuthenticationMethod -in @('ClientSecret', 'ClientCertificateThumbprint')) {
                Write-Log -Message ("Connected using Client Credential Flow with application: {0}" -f $context.AppName) -LogId $LogId
                Write-Host ("Connected using Client Credential Flow with application: {0}" -f $context.AppName) -ForegroundColor Green
            }
            else {
                Write-Log -Message ("Connected using Delegated Flow as: {0}" -f $context.Account) -LogId $LogId
                Write-Host ("Connected using Delegated Flow as: {0}" -f $context.Account) -ForegroundColor Green
            }
            Write-Log -Message ("Scopes: {0}" -f ($context.Scopes -join ', ')) -LogId $LogId
            Write-Host ("Scopes: {0}" -f ($context.Scopes -join ', ')) -ForegroundColor Green
        }
        else {
            Write-Log -Message "Failed to establish a valid connection with required scopes" -LogId $LogId -Severity 3
            Write-Warning "Failed to establish a valid connection with required scopes"
        }
    }
}