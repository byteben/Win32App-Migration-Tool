<#
.Synopsis
Created on:   27/10/2023
Created by:   Ben Whitmore
Filename:     Win32AppMigrationTool.psm1

.Description
Win32App Packaging Tool Function Import
#>


$functionsToImport = $[PSCustomObject]@ {
    PublicFunctions = @(Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -Recurse -ErrorAction SilentlyContinue)
    PrivateFunctions = @(Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -Recurse -ErrorAction SilentlyContinue)
}

foreach ($function in @($functionsToImport.PublicFunctions + $functionsToImport.PrivateFunctions)) {
    try {
        . $GetFunction.FullName
    }
    Catch {
        Write-Warning -Message ("Failed to import function '{0}'. {1}" -f $GetFunction.FullName, $_.Exception.Message)
    }
}