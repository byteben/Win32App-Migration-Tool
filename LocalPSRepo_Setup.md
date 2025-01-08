# Local PowerShell Repository Setup Guide

## Publishing Updates (Run Initially and After Changes)

```powershell
function Set-DevEnv {
$ModuleName = 'Win32AppMigrationTool'
$DevPath = '\\tsclient\C\GitHub\byteben\Win32App-Migration-Tool'
$LocalPath = 'C:\LocalModules\Win32AppMigrationTool'
Set-Location -Path $LocalPath
Write-Host -Object ("New-Item -Path {0} -ItemType Directory -Force" -f $LocalPath)
New-Item -Path $LocalPath -ItemType Directory -Force
Write-Host -Object ("Get-ChildItem -Path {0} | Copy-Item -Destination {0} -Recurse -Force" -f $DevPath, $LocalPath)
Get-ChildItem -Path $DevPath | Copy-Item -Destination $LocalPath -Recurse -Force
Write-Host -Object ("Import-Module {0} -Force" -f (Join-Path $LocalPath "$ModuleName.psd1"))
Import-Module (Join-Path -Path $LocalPath -ChildPath "$ModuleName.psd1") -Force
}
Set-DevEnv
```

## Troubleshooting

```powershell
Get-Module $ModuleName # Verify module is loaded with correct version
Get-Module $ModuleName -ListAvailable | Remove-Module -Force # Clear PowerShell module cache
```

## Cleanup (When Done Testing)

```powershell
Remove-Module $ModuleName -Force # Remove module from current session
