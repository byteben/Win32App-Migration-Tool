<#
.Synopsis
Created on:   17/11/2026
Created by:   Ben Whitmore
Filename:     Test-IntuneWinTooLarge.ps1

.Description
Checks a .intunewin file against Intune's Win32 app size limit (30 GB per app). Returns a message when the file is
too large, or $null when it's within the limit or the file can't be found (later stages report a missing file).

.PARAMETER Path
The .intunewin file

.PARAMETER MaxAppSizeGB
The limit in GB (1,000,000,000 bytes). Default 30
#>
function Test-IntuneWinTooLarge {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$Path,
        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 1024)]
        [int]$MaxAppSizeGB = 30
    )

    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    $file = Get-Item -LiteralPath $Path -ErrorAction SilentlyContinue
    if (-not $file -or $file.PSIsContainer) { return $null }

    # Decimal GB, so the check is never more generous than Intune's limit
    $limitBytes = [int64]$MaxAppSizeGB * 1000000000
    if ($file.Length -le $limitBytes) { return $null }

    return ("'{0}' is {1:N2} GB, which is over Intune's limit of {2} GB per Win32 app. Reduce the content (for example, split it into separate apps) or use -MaxAppSizeGB if Microsoft has raised the limit for your tenant" -f $file.Name, ($file.Length / 1000000000), $MaxAppSizeGB)
}
