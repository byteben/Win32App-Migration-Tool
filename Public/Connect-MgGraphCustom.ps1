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
Module Name to use to connect to Graph. Default is Microsoft.Graph

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
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = 'The component (script name) passed as LogID to the "Write-Log" function')]
        [string]$LogId = $($MyInvocation.MyCommand).Name,
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = 'Module Name to connect to Graph')]
        [object]$ModuleName = ('Microsoft.Graph'),
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
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = 'The scopes to request from the Microsoft Graph API')]
        [object]$Scopes = @('https://graph.microsoft.com/.default'),
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = 'This parameter will be used to determine if the device authentication flow should be used')]
        [switch]$UseDeviceAuthentication = $false
    )

    begin {
        Write-Log -Message 'Function: Connect-MgGraphCustom was called' -LogId $LogId

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
        if (Test-MgConnection -LogId $LogId -RequiredScopes $Scopes) {
            Write-Log -Message "Using existing Microsoft Graph connection" -LogId $LogId
            Write-Host "Using existing Microsoft Graph connection" -ForegroundColor Green
            return
        }

        # If we don't have a valid connection, proceed with connection based on parameters
        try {
            $connectMgParams = @{
                TenantId = $TenantId
                ClientId = $ClientId
                Scopes   = $Scopes
            }

            if ($ClientSecret) {
                $secureSecret = ConvertTo-SecureString -String $ClientSecret -AsPlainText -Force
                $connectMgParams['ClientSecretCredential'] = $secureSecret
            }
            elseif ($ClientCertificateThumbprint) {
                $connectMgParams['CertificateThumbprint'] = $ClientCertificateThumbprint
            }
            elseif ($UseDeviceAuthentication) {
                $connectMgParams['UseDeviceCode'] = $true
            }

            Connect-MgGraph @connectMgParams
            
            if (Test-MgConnection -LogId $LogId -RequiredScopes $Scopes) {
                Write-Log -Message "Successfully connected to Microsoft Graph" -LogId $LogId
                Write-Host "Successfully connected to Microsoft Graph" -ForegroundColor Green
                
                # Get and display connection details
                $context = Get-MgContext
                Write-Log -Message ("Connected as: {0}" -f $context.Account) -LogId $LogId
                Write-Host ("Connected as: {0}" -f $context.Account) -ForegroundColor Green
                Write-Log -Message ("Scopes: {0}" -f ($context.Scopes -join ', ')) -LogId $LogId
                Write-Host ("Scopes: {0}" -f ($context.Scopes -join ', ')) -ForegroundColor Green
            }
            else {
                throw "Failed to establish a valid connection with required scopes"
            }
        }
        catch {
            Write-Log -Message "Failed to connect to Microsoft Graph: $($_.Exception.Message)" -LogId $LogId -Severity 3
            Write-Warning "Failed to connect to Microsoft Graph: $($_.Exception.Message)"
            throw
        }
    }

    end {
        Write-Log -Message "Function: Connect-MgGraphCustom finished" -LogId $LogId
    }
}