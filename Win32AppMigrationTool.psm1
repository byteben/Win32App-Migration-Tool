<#
.Synopsis
Created on:   27/10/2023
Created by:   Ben Whitmore
Filename:     Win32AppMigrationTool.psm1

.Description
Win32App Packaging Tool Function Import
#>



$publicFunctions = Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -Recurse -ErrorAction SilentlyContinue
$privateFunctions = Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -Recurse -ErrorAction SilentlyContinue


foreach ($function in @($publicFunctions + $privateFunctions)) {
    try {
        . $function.FullName
    }
    Catch {
        Write-Warning -Message ("Failed to import function '{0}'. {1}" -f $function.FullName, $_.Exception.Message)
    }
}