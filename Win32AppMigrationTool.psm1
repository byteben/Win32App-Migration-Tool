<#
.Synopsis
Created on:   21/03/2021
Created by:   Ben Whitmore
Filename:     Win32AppMigrationTool.psm1

.Description
Win32App Packaging Tool Function Import
#>

$PublicFunctions = @( Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -Recurse -ErrorAction SilentlyContinue )
$PrivateFunctions = @( Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -Recurse -ErrorAction SilentlyContinue )

foreach ($GetFunction in @($PublicFunctions + $PrivateFunctions)) {
    Try {
        . $GetFunction.FullName
    }
    Catch {
        Write-Host "Failed to import function $($GetFunction.FullName)" -ForegroundColor Red
        Write-Host "$_" -ForegroundColor Yellow
    }
}