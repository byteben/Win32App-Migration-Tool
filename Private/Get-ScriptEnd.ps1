<#
.Synopsis
Created on:   21/03/2021
Created by:   Ben Whitmore
Filename:     Get-ScriptEnd.ps1

.Description
Function to exit script
#>
Function Get-ScriptEnd {

    Set-Location $ScriptRoot
    Write-Host ''
    Write-Log -Message "## The Win32AppMigrationTool Script has Finished ##" -Log "Main.log" 
    Write-Host '## The Win32AppMigrationTool Script has Finished ##'
}