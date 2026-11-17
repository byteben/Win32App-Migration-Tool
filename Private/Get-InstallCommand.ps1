<#
.Synopsis
Created on:   11/11/2023
Updated on:   16/11/2026
Created by:   Ben Whitmore
Filename:     Get-InstallCommand.ps1

.Description
Functions to find the setup file in an install command line for use with the content prep tool.
Split-CommandLine tokenises a command line respecting double and single quotes (quotes are removed from the tokens).
Get-InstallCommand picks the first token ending in the install technology extension (case-insensitive) that is not an
interpreter (powershell.exe, pwsh.exe, msiexec.exe, cmd.exe, cscript.exe, wscript.exe). It handles:
 - quoted and unquoted file names, including names with spaces
 - a leading '.\' or './' (removed)
 - sub-folders (returned relative to the content root with backslashes)
 - switch style prefixes such as '-File=x.ps1' or '/i:"x.msi"' (the prefix is removed)
 - absolute paths (drive letter or UNC), which are reduced to the file name with a warning

.PARAMETER LogId
The component (script name) passed as LogID to the 'Write-Log' function. 
This parameter is built from the line number of the call from the function up the pipeline

.PARAMETER InstallTech
The extension of the installer technology: .ps1, .exe, .msi, .msp, .vbs, .cmd, .bat or .js

.PARAMETER SetupFile
The full install command line

.PARAMETER CommandLine
Split-CommandLine: the command line to tokenise
#>
function Split-CommandLine {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [AllowEmptyString()]
        [string]$CommandLine
    )

    $tokens = New-Object System.Collections.Generic.List[string]
    $current = New-Object System.Text.StringBuilder
    $quote = $null
    $hasToken = $false

    foreach ($char in $CommandLine.ToCharArray()) {
        if ($null -ne $quote) {
            if ($char -eq $quote) { $quote = $null }
            else { [void]$current.Append($char) }
        }
        elseif ($char -eq '"' -or $char -eq "'") {
            $quote = $char
            $hasToken = $true
        }
        elseif ([char]::IsWhiteSpace($char)) {
            if ($hasToken -and $current.Length -gt 0) { $tokens.Add($current.ToString()) }
            [void]$current.Clear()
            $hasToken = $false
        }
        else {
            [void]$current.Append($char)
            $hasToken = $true
        }
    }
    if ($hasToken -and $current.Length -gt 0) { $tokens.Add($current.ToString()) }

    return , $tokens.ToArray()
}

function Get-InstallCommand {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = 'The component (script name) passed as LogID to the Write-Log function')]
        [string]$LogId = $($MyInvocation.MyCommand).Name,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 0, HelpMessage = 'The installer extension')]
        [ValidateSet('.ps1', '.exe', '.msi', '.msp', '.vbs', '.cmd', '.bat', '.js')]
        [string]$InstallTech,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 1, HelpMessage = 'The full install command line')]
        [string]$SetupFile
    )
    process {
        Write-LogAndHost -Message "Function: Get-InstallCommand was called" -LogId $LogId -ForegroundColor Cyan
        Write-LogAndHost -Message ("Extracting the SetupFile name for the Microsoft Win32 Content Prep Tool from the install command '{0}'" -f $SetupFile) -LogId $LogId -ForegroundColor Cyan

        $interpreters = @('powershell.exe', 'pwsh.exe', 'msiexec.exe', 'msiexec', 'cmd.exe', 'cscript.exe', 'wscript.exe')

        foreach ($token in (Split-CommandLine -CommandLine $SetupFile)) {
            $candidate = $token

            # Strip a switch style prefix such as -File=x.ps1 or /i:x.msi (not a drive letter, which has no leading switch character)
            if ($candidate -match '^[-/][A-Za-z][A-Za-z0-9]*[=:](?<rest>.+)$') {
                $candidate = $Matches['rest']
            }

            if (-not $candidate.EndsWith($InstallTech, [System.StringComparison]::OrdinalIgnoreCase)) { continue }

            $leaf = ($candidate -split '[\\/]')[-1].ToLowerInvariant()
            if ($interpreters -contains $leaf) { continue }

            if ($candidate -match '^[A-Za-z]:[\\/]' -or $candidate -match '^\\\\') {
                $result = ($candidate -split '[\\/]')[-1]
                Write-LogAndHost -Message ("The absolute path '{0}' was reduced to its file name '{1}'. The file must exist in the root of the content folder" -f $candidate, $result) -LogId $LogId -Severity 2
            }
            else {
                $result = $candidate -replace '/', '\'
                while ($result -match '^\.\\') { $result = $result.Substring(2) }
            }

            Write-LogAndHost -Message ("The setup file to pass to the Win32 Content Prep Tool is '{0}'" -f $result) -LogId $LogId -ForegroundColor Green
            return $result
        }

        throw ("Could not find a '{0}' file in the install command line '{1}'" -f $InstallTech, $SetupFile)
    }
}
