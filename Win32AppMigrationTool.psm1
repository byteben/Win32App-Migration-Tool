<#
.Synopsis
Created on:   16/12/2023
Created by:   Ben Whitmore
Filename:     Win32AppMigrationTool.psm1

.Description
Win32App Packaging Tool Function Import
#>

$PublicFunctions = @( Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -Recurse -ErrorAction SilentlyContinue )
$PrivateFunctions = @( Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -Recurse -ErrorAction SilentlyContinue )

foreach ($GetFunction in @($PublicFunctions + $PrivateFunctions)) {
    try {
        . $GetFunction.FullName
    }
    catch {
        Write-Error -Message ("Failed to import function '{0}'" -f $GetFunction.FullName)
        throw
    }
}