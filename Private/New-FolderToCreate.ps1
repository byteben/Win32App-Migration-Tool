<#
.Synopsis
Created on:   27/10/2023
Created by:   Ben Whitmore
Filename:     New-FolderToCreate.ps1

.Description
Function to create a folder

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
    
    Write-Log -Message 'Function: New-FolderToCreate was called'

    foreach ($folder in $FolderNames) {

        #Create Folders
        Write-Log -Message ("`$FolderToCreate = Join-Path -Path '{0}' -ChildPath '{1}'"-f $Root, $folder)
        $folderToCreate = Join-Path -Path $Root -ChildPath $folder
        
        If (!(Test-Path -Path $folderToCreate)) {
            Write-Host ("Creating Folder '{0}'..." -f $folderToCreate) -ForegroundColor Cyan
            try {
                New-Item -Path $folderToCreate -ItemType Directory -Force -ErrorAction Stop | Out-Null
                Write-Log -Message ("Folder '{0}' was created succesfully" -f $folderToCreate)
                Write-Host ("Folder '{0}' created succesfully" -f $folderToCreate) -ForegroundColor Green
            }
            catch {
                Write-Log -Message ("Couldn't create '{0}' folder" -f $folderToCreate) -Severity 3
                Write-Warning -Message ("Couldn't create '{0}' folder" -f $folderToCreate)
            }
        }
        else {
            Write-Log -Message ("Folder '{0}' already exists. Skipping folder creation" -f $folderToCreate) -Severity 2
            Write-Host ("Folder '{0}' already exists. Skipping folder creation" -f $folderToCreate) -ForegroundColor Yellow
        }
    }
} 