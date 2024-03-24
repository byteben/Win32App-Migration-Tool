# Function to install the Microsoft Graph module and get a token
<#
.Synopsis
Created on:   22/01/2024
Updated on:   24/03/2024
Created by:   Ben Whitmore
Filename:     Connect-Graph.ps1

.Description
Function to connect to Microsoft Graph

.PARAMETER LogID
The component (script name) passed as LogID to the 'Write-Log' function. 
This parameter is built from the line number of the call from the function up the pipeline

.PARAMETER ModuleName
Module Name to connect to Graph. If not specified, the default value is used for Microsoft.Graph

.PARAMETER PackageProvider
Package Provider. If not specified, the default value NuGet is used

.PARAMETER ModuleScope
Module Scope. If not specified, the default value is used for CurrentUser

.PARAMETER Scopes
The scopes to request from the Microsoft Graph API. If not specified, the default value is used for Application.ReadWrite.All

.PARAMETER UseDeviceAuthentication
This parameter will be used to determine if the device authentication flow should be used. If not specified, the default value is used for $false

#>
function Invoke-GraphConnection {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = 'The component (script name) passed as LogID to the "Write-Log" function')]
        [string]$LogId = $($MyInvocation.MyCommand).Name,
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = 'Module Name to connect to Graph. If not specified, the default value is used for Microsoft.Graph')]
        [string]$ModuleName = 'Microsoft.Graph.Devices.CorporateManagement',
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = 'If not specified, the default value NuGet is used for PackageProvider')]
        [string]$PackageProvider = 'NuGet',
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = 'If not specified, the default value is used for CurrentUser')]
        [string]$ModuleScope = 'CurrentUser',
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = 'The scopes to request from the Microsoft Graph API. If not specified, the default value is used for Application.ReadWrite.All')]
        [string]$Scopes = 'DeviceManagementApps.ReadWrite.All',
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = 'This parameter will be used to determine if the device authentication flow should be used. If not specified, the default value is used for $false')]
        [switch]$UseDeviceAuthentication = $false
    )

    begin {
        Write-Log -Message 'Function: Connect-Graph was called' -LogId $LogId

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

    process {

        # Build connection splat
        $ConnectGraphSplat = @{
            Scopes    = $Scopes
            NoWelcome = $true
        }

        if ($PSBoundParameters["UseDeviceAuthentication"]) {
            $connectGraphSplat.Add('UseDeviceAuthentication', $true)
        }
        
        # Connect to Microsoft Graph
        try {
            Connect-MgGraph @ConnectGraphSplat -ErrorAction Stop
        }
        catch {
            Write-Warning -Message ("'{0}'" -f $_.Exception.Message)
            Write-Log -Message ("'{0}'" -f $_.Exception.Message) -LogId $LogId -Severity 3
            Get-ScriptEnd -ErrorMessage 'Failed to connect to Microsoft Graph' -LogId $LogId
        }

        # Check if the connection is successful
        $graphContext = Get-MgContext

        if ($graphContext) {

            #Log the connection details
            Write-Log -Message 'Connected to Microsoft Graph successfully' -LogId $LogId
            Write-Log -Message ("ClientId: '{0}',TenantId: '{1}',Scopes: '{2}',AuthType: '{3}',TokenCredentialType: '{4}',Account: '{5}',ContextScope: '{6}'," -f `
                    $graphContext.ClientId, `
                    $graphContext.TenantId, `
                ($graphContext.Scopes -join ", "), `
                    $graphContext.AuthType, `
                    $graphContext.TokenCredentialType, `
                    $graphContext.Account, `
                    $graphContext.ContextScope) -LogId $LogId

            # Write the connection details to the console
            Write-Host 'Connected to Microsoft Graph successfully' -ForegroundColor Cyan
            Write-Host ("ClientId: '{0}',TenantId: '{1}',Scopes: '{2}',AuthType: '{3}',TokenCredentialType: '{4}',Account: '{5}',ContextScope: '{6}'," -f `
                    $graphContext.ClientId, `
                    $graphContext.TenantId, `
                ($graphContext.Scopes -join ", "), `
                    $graphContext.AuthType, `
                    $graphContext.TokenCredentialType, `
                    $graphContext.Account, `
                    $graphContext.ContextScope) -ForegroundColor Green
        }
        else {
            Get-ScriptEnd -ErrorMessage 'Failed to connect to Microsoft Graph' -LogId $LogId 
        }
    }
}