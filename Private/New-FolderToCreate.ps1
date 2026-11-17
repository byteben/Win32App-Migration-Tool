<#
.Synopsis
Created on:   27/10/2023
Updated on:   16/11/2026
Created by:   Ben Whitmore
Filename:     New-FolderToCreate.ps1

.Description
Function to create a folder

.PARAMETER LogId
The component (script name) passed as LogID to the 'Write-Log' function. 
This parameter is built from the line number of the call from the function up the pipeline

.PARAMETER Root
The root folder to create the folder(s) in

.PARAMETER Folders
The folder(s) to create
#>
function New-FolderToCreate {
    param(
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = 'The component (script name) passed as LogID to the Write-Log function')]
        [string]$LogId = $($MyInvocation.MyCommand).Name,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0, HelpMessage = 'The root folder to create the folder(s) in')]
        [String]$Root,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 1, HelpMessage = 'The folder(s) to create')]
        [String[]]$FolderNames
    )
    begin {
    
        Write-Host 'Function: New-FolderToCreate was called' -ForegroundColor Cyan
    }
    process {
        foreach ($folder in $FolderNames) {

            # Create Folders
            $folderToCreate = Join-Path -Path $Root -ChildPath $folder
        
            if (-not (Test-Path -Path $folderToCreate)) {
                Write-Host ("Creating Folder '{0}'..." -f $folderToCreate) -ForegroundColor Cyan

                try {

                    # Create the folder
                    New-Item -Path $folderToCreate -ItemType Directory -Force -ErrorAction Stop | Out-Null
                    Write-Host ("Folder '{0}' was created successfully" -f $folderToCreate) -ForegroundColor Green
                }
                catch {
                    Write-LogAndHost -Message ("Couldn't create '{0}' folder. {1}" -f $folderToCreate, $_.Exception.Message) -LogId $LogId -Severity 3
                    throw ("Couldn't create '{0}' folder. {1}" -f $folderToCreate, $_.Exception.Message)
                }
            }
            else {
                Write-Host ("Folder '{0}' already exists. Skipping folder creation" -f $folderToCreate) -ForegroundColor Yellow
            }
        }
    }
} 