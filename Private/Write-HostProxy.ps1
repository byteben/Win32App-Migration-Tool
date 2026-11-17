<#
.Synopsis
Created on:   17/11/2026
Created by:   Ben Whitmore
Filename:     Write-HostProxy.ps1

.Description
Module-private Write-Host and Write-Progress. Inside this module they replace the built-in cmdlets, so
New-Win32App -NoConsoleOutput can silence every console message and progress bar in one place. Without
-NoConsoleOutput they pass everything to the built-in cmdlets unchanged. The log file is written either way.
Outside the module, Write-Host and Write-Progress are not affected.

The idea and the switch come from pull request #40 by XxMrTyronexX.
#>
function Write-Host {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, Position = 0, ValueFromPipeline = $true, ValueFromRemainingArguments = $true)]
        [object]$Object,
        [Parameter(Mandatory = $false)]
        [switch]$NoNewline,
        [Parameter(Mandatory = $false)]
        [object]$Separator,
        [Parameter(Mandatory = $false)]
        [object]$ForegroundColor,
        [Parameter(Mandatory = $false)]
        [object]$BackgroundColor
    )
    process {
        if ($script:Win32AppMigrationTool_NoConsoleOutput) { return }

        # Drop empty colour values so the built-in cmdlet doesn't reject them
        $params = @{}
        foreach ($key in $PSBoundParameters.Keys) {
            if ($key -in @('ForegroundColor', 'BackgroundColor') -and [string]::IsNullOrWhiteSpace([string]$PSBoundParameters[$key])) { continue }
            $params[$key] = $PSBoundParameters[$key]
        }
        Microsoft.PowerShell.Utility\Write-Host @params
    }
}

function Write-Progress {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [string]$Activity,
        [Parameter(Mandatory = $false, Position = 1)]
        [string]$Status,
        [Parameter(Mandatory = $false, Position = 2)]
        [int]$Id,
        [Parameter(Mandatory = $false)]
        [int]$PercentComplete,
        [Parameter(Mandatory = $false)]
        [int]$SecondsRemaining,
        [Parameter(Mandatory = $false)]
        [string]$CurrentOperation,
        [Parameter(Mandatory = $false)]
        [int]$ParentId,
        [Parameter(Mandatory = $false)]
        [switch]$Completed,
        [Parameter(Mandatory = $false)]
        [int]$SourceId
    )
    if ($script:Win32AppMigrationTool_NoConsoleOutput) { return }
    Microsoft.PowerShell.Utility\Write-Progress @PSBoundParameters
}
