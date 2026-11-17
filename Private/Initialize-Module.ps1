<#
.Synopsis
Created on:   30/12/2024
Updated on:   16/11/2026
Created by:   Ben Whitmore
Filename:     Initialize-Module.ps1

.Description
Function to install and import required PowerShell modules

.PARAMETER Modules
Array of module names to install/import

.PARAMETER PackageProvider
Package provider required for module installation

.PARAMETER ModuleScope
Scope for module installation (CurrentUser/AllUsers)

.PARAMETER MinimumVersion
Optional hashtable of module name to minimum version string (for example @{ 'Az.Storage' = '5.0.0' }). Throws if the installed module is older. Nothing is installed to satisfy this check

.PARAMETER LogId
Component name for logging
#>
function Initialize-Module {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, HelpMessage = 'Array of module names to install')]
        [array]$Modules,

        [Parameter(Mandatory = $false, HelpMessage = 'Package provider required for module installation')]
        [string]$PackageProvider = "NuGet",

        [Parameter(Mandatory = $false, HelpMessage = 'Scope for module installation')]
        [ValidateSet('CurrentUser', 'AllUsers')]
        [string]$ModuleScope = "CurrentUser",

        [Parameter(Mandatory = $false, HelpMessage = 'Hashtable of module name to minimum version string')]
        [hashtable]$MinimumVersion,

        [Parameter(Mandatory = $false, HelpMessage = 'Component name for logging')]
        [string]$LogId = $($MyInvocation.MyCommand).Name
    )

    begin {
        Write-LogAndHost -Message ("Function: Initialize-Module was called for module(s): {0}" -f ($Modules -join ', ')) -LogId $LogId -ForegroundColor Cyan
    }

    process {

        try {

            # Check PackageProvider
            if (-not (Get-PackageProvider -ListAvailable -Name $PackageProvider)) {
                Write-LogAndHost -Message ("PackageProvider not found. Installing '{0}'" -f $PackageProvider) -LogId $LogId -ForegroundColor Cyan
                Install-PackageProvider -Name $PackageProvider -ForceBootstrap -Confirm:$false
            }

            # Process each module
            foreach ($Module in $Modules) {

                if (-not (Get-Module -ListAvailable -Name $Module)) {
                    Write-LogAndHost -Message ("Installing module '{0}' in scope '{1}'" -f $Module, $ModuleScope) -LogId $LogId -ForegroundColor Cyan
                    Install-Module -Name $Module -Scope $ModuleScope -AllowClobber -Force -Confirm:$false
                }

                if (-not (Get-Module -Name $Module)) {
                    Write-LogAndHost -Message ("Importing module '{0}'" -f $Module) -LogId $LogId -ForegroundColor Cyan
                    
                    try {

                        # Import the module
                        Import-Module $Module
                    }
                    catch {
                        Write-LogAndHost -Message ("Error importing module '{0}': {1}" -f $Module, $_.Exception.Message) -LogId $LogId -Severity 3

                        throw ("Failed to import module '{0}': {1}" -f $Module, $_.Exception.Message)
                    }
                }
                else {
                    Write-LogAndHost -Message ("Module '{0}' already imported" -f $Module) -LogId $LogId -ForegroundColor Green
                }

                # Check the minimum version if one was requested for this module
                if ($MinimumVersion -and $MinimumVersion.ContainsKey($Module)) {
                    $required = [version]([string]$MinimumVersion[$Module])
                    $installed = Get-Module -Name $Module -ListAvailable | Sort-Object -Property Version -Descending | Select-Object -First 1

                    if (-not $installed -or $installed.Version -lt $required) {
                        $installedText = 'not found'
                        if ($installed) { $installedText = [string]$installed.Version }
                        throw ("Module '{0}' version {1} or later is required. Installed version: {2}" -f $Module, $required, $installedText)
                    }
                }
            }
        }
        catch {
            Write-LogAndHost -Message ("Module installation failed: {0}" -f $_.Exception.Message) -LogId $LogId -Severity 3

            throw
        }
    }
}