<#
.SYNOPSIS
Created on:   30/12/2024
Created by:   Ben Whitmore
Filename:     Initialize-Module.ps1

.DESCRIPTION
Function to install and import required PowerShell modules

.PARAMETER Modules
Array of module names to install/import

.PARAMETER PackageProvider
Package provider required for module installation

.PARAMETER ModuleScope
Scope for module installation (CurrentUser/AllUsers)

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

        [Parameter(Mandatory = $false, HelpMessage = 'Component name for logging')]
        [string]$LogId = $($MyInvocation.MyCommand).Name
    )

    begin {
        Write-Log -Message ("Function: Initialize-Module was called for module(s): {0}" -f ($Modules -join ', ')) -LogId $LogId
        Write-Host ("Function: Initialize-Module was called for module(s): {0}" -f ($Modules -join ', ')) -ForegroundColor Cyan
    }

    process {
        try {

            # Check PackageProvider
            if (-not (Get-PackageProvider -ListAvailable -Name $PackageProvider)) {
                Write-Log -Message ("PackageProvider not found. Installing '{0}'" -f $PackageProvider) -LogId $LogId
                Write-Host ("Installing PackageProvider '{0}'" -f $PackageProvider) -ForegroundColor Cyan
                
                Install-PackageProvider -Name $PackageProvider -ForceBootstrap -Confirm:$false
            }

            # Process each module
            foreach ($Module in $Modules) {
                if (-not (Get-Module -ListAvailable -Name $Module)) {
                    Write-Log -Message ("Installing module '{0}' in scope '{1}'" -f $Module, $ModuleScope) -LogId $LogId
                    Write-Host ("Installing module '{0}' in scope '{1}'" -f $Module, $ModuleScope) -ForegroundColor Cyan
                    
                    Install-Module -Name $Module -Scope $ModuleScope -AllowClobber -Force -Confirm:$false
                }

                if (-not (Get-Module -Name $Module)) {
                    Write-Log -Message ("Importing module '{0}'" -f $Module) -LogId $LogId
                    Write-Host ("Importing module '{0}'" -f $Module) -ForegroundColor Cyan
                    
                    try {
                        Import-Module $Module
                    }
                    catch {
                        Write-Log -Message ("Error importing module '{0}': {1}" -f $Module, $_.Exception.Message) -LogId $LogId -Severity 3
                        Write-Error ("Error importing module '{0}': {1}" -f $Module, $_.Exception.Message)
                        break
                    }
                }
                else {
                    Write-Log -Message ("Module '{0}' already imported" -f $Module) -LogId $LogId
                    Write-Host ("Module '{0}' already imported" -f $Module) -ForegroundColor Green
                }
            }
        }
        catch {
            Write-Log -Message ("Module installation failed: {0}" -f $_.Exception.Message) -LogId $LogId -Severity 3
            Write-Error $_
            break
        }
    }
}