<#
.Synopsis
Created on:   12/11/2023
Created by:   Ben Whitmore
Filename:     Win32AppMigrationTool.psm1

.Description
Win32App Packaging Tool Function Import
#>
[CmdletBinding()]
Param()
Process {
    $pub = Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath "Public") -Filter "*.ps1" -ErrorAction SilentlyContinue
    $priv = Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath "Private") -Filter "*.ps1" -ErrorAction SilentlyContinue

    foreach ($func in @($pub + $priv)) {
        try {
            . $func.FullName -ErrorAction Stop
        }
        catch [System.Exception] {
            Write-Error -Message "Failed to import the function '$($func.FullName)' with error: $($_.Exception.Message)"
        }
    }
}