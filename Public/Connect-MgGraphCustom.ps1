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

.PARAMETER RequiredScopes
The scopes to request from the Microsoft Graph API. If not specified, the default value is used for .default

.PARAMETER UseDeviceAuthentication
This parameter will be used to determine if the device authentication flow should be used. If not specified, the default value is used for $false

.PARAMETER Interactive
This parameter will be used to determine if the interactive flow should be used. If not specified, the default value is used for $false

.EXAMPLE
Delegated Flow Example:
Connect-MgGraphCustom -TenantId 'contoso.onmicrosoft.com' -ClientId '00000000-0000-0000-0000-000000000000'

.EXAMPLE
Client Secret Flow Example:
Connect-MgGraphCustom -TenantId 'contoso.onmicrosoft.com' -ClientId '00000000-0000-0000-0000-000000000000' -ClientSecret 'clientsecret'

.EXAMPLE
Client Certificate Flow Example:
Connect-MgGraphCustom -TenantId 'contoso.onmicrosoft.com' -ClientId '00000000-0000-0000-0000-000000000000' -ClientCertificateThumbprint '00000000000000000000000000000000'

.EXAMPLE
Device Authentication Flow Example:
Connect-MgGraphCustom -TenantId 'contoso.onmicrosoft.com' -ClientId '00000000-0000-0000-0000-000000000000' -UseDeviceAuthentication
#>

function Connect-MgGraphCustom {
    [CmdletBinding(DefaultParameterSetName = 'Interactive')]
    param (
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 0, HelpMessage = 'The component (script name) passed as LogID to the "Write-Log" function')]
        [string]$LogId = $($MyInvocation.MyCommand).Name,

        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 1, HelpMessage = 'Module Name to connect to Graph. Default is Microsoft.Graph.Authentication')]
        [object]$ModuleNames = ('Microsoft.Graph.Authentication'),

        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 2, HelpMessage = 'If not specified, the default value NuGet is used for PackageProvider')]
        [string]$PackageProvider = 'NuGet',

        [Parameter(Mandatory = $true, ParameterSetName = 'ClientSecret', Position = 3, HelpMessage = 'Tenant Id or name to connect to')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ClientCertificateThumbprint', Position = 3, HelpMessage = 'Tenant Id or name to connect to')]
        [Parameter(Mandatory = $true, ParameterSetName = 'UseDeviceAuthentication', Position = 3, HelpMessage = 'Tenant Id or name to connect to')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Interactive', Position = 3, HelpMessage = 'Tenant Id or name to connect to')]
        [string]$TenantId,

        [Parameter(Mandatory = $true, ParameterSetName = 'ClientSecret', Position = 4, HelpMessage = 'Client Id (App Registration) to connect to')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ClientCertificateThumbprint', Position = 4, HelpMessage = 'Client Id (App Registration) to connect to')]
        [Parameter(Mandatory = $true, ParameterSetName = 'UseDeviceAuthentication', Position = 4, HelpMessage = 'Client Id (App Registration) to connect to')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Interactive', Position = 4, HelpMessage = 'Client Id (App Registration) to connect to')]
        [string]$ClientId,

        [Parameter(Mandatory = $true, ParameterSetName = 'ClientSecret', Position = 5, HelpMessage = 'Client secret for authentication')]
        [string]$ClientSecret,

        [Parameter(Mandatory = $true, ParameterSetName = 'ClientCertificateThumbprint', Position = 5, HelpMessage = 'Client certificate thumbprint for authentication')]
        [string]$ClientCertificateThumbprint,

        [Parameter(Mandatory = $true, ParameterSetName = 'UseDeviceAuthentication', Position = 5, HelpMessage = 'Use device authentication for Microsoft Graph API')]
        [switch]$UseDeviceAuthentication,

        [Parameter(Mandatory = $false, Position = 6, HelpMessage = 'The scopes required for Microsoft Graph API access. Default is DeviceManagementApps.ReadWrite.All')]
        [string[]]$RequiredScopes = ('DeviceManagementApps.ReadWrite.All'),

        [Parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 7, HelpMessage = 'Specifies the scope for installing the module. Default is CurrentUser')]
        [string]$ModuleScope = 'CurrentUser'
    )

    begin {

        Write-LogAndHost -Message 'Function: Connect-MgGraphCustom was called' -LogId $LogId -ForegroundColor Cyan
        Write-LogAndHost -Message "Resolved Parameter Set: $($PSCmdlet.ParameterSetName)" -LogId $LogId -ForegroundColor Cyan

        Initialize-Module -Modules $ModuleNames
    }

    process {

        # First check if we already have a valid connection with required scopes
        if (Test-MgConnection -RequiredScopes $RequiredScopes -TestScopes) {
            Write-LogAndHost -Message "Using existing Microsoft Graph connection" -LogId $LogId -ForegroundColor Green
            return
        }

        # If we don't have required scopes, set the default required scopes to create Win32 apps. This assumes the Connect-MgGraphCustom function is used outside of the New-Win32App function
        if (-not $RequiredScopes) {

            if (Test-Path variable:\global:scopes) {

                [string[]]$RequiredScopes = $global:scopes
                Write-LogAndHost -Message ("Required Scope defined already. Using existing required scopes: {0}" -f $RequiredScopes) -LogId $LogId -ForegroundColor Green
            }
            else {
                [string[]]$global:scopes = ('DeviceManagementApps.ReadWrite.All')
                [string[]]$RequiredScopes = $global:scopes
                Write-LogAndHost -Message ("Required Scope defined yet.Using default required scopes: {0}" -f $RequiredScopes) -LogId $LogId -ForegroundColor Green
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
                $secureClientSecret = ConvertTo-SecureString -String $ClientSecret -AsPlainText -Force
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
                $connectMgParams['Scopes'] = $RequiredScopes -join ' '
            }
            default {
                Write-LogAndHost -Message ("Unknown authentication method: {0}" -f $AuthenticationMethod) -LogId $LogId -Severity 3
                break
            }
        }

        # Convert the parameters to a string for logging
        $connectMgParamsString = 'Connect-MgGraph ' + ($connectMgParams.Keys | ForEach-Object { '-{0} {1}' -f $_, $connectMgParams.$_ }) -join ' '
        Write-LogAndHost -Message ("Connecting to Microsoft Graph with the following parameters: {0}" -f $connectMgParamsString) -LogId $LogId -ForegroundColor Cyan
            
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
                Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -Scopes $connectMgParams['Scopes'] -NoWelcome
            }
        }
        catch {
            Write-LogAndHost -Message ("Failed to connect to Microsoft Graph: {0}" -f $_.Exception.Message) -LogId $LogId -Severity 3
        }
         
        # Check if we have a valid connection with required scopes
        if (Test-MgConnection -LogId $LogId -RequiredScopes $RequiredScopes) {

            Write-LogAndHost -Message "Successfully connected to Microsoft Graph" -LogId $LogId -ForegroundColor Green
                
            # Get and display connection details
            $context = Get-MgContext
            if ($AuthenticationMethod -in @('ClientSecret', 'ClientCertificateThumbprint')) {
                Write-LogAndHost -Message ("Connected using Client Credential Flow with application: {0}" -f $context.AppName) -LogId $LogId -ForegroundColor Green
            }
            else {
                Write-LogAndHost -Message ("Connected using Delegated Flow as: {0}" -f $context.Account) -LogId $LogId -ForegroundColor Green
            }
            Write-LogAndHost -Message ("Scopes: {0}" -f ($context.Scopes -join ', ')) -LogId $LogId -ForegroundColor Green
        }
        else {
            Write-LogAndHost -Message "Failed to establish a valid connection with required scopes" -LogId $LogId -Severity 3
        }
    }
}