<#
.Synopsis
Created on:   03/04/2024
Created by:   Ben Whitmore
Credit:       @NickolajA
Filename:     Invoke-GraphRequest.ps1

.Description
Function to invoke a request to the Microsoft Graph API

.PARAMETER LogId
The component (script name) passed as LogID to the 'Write-Log' function. 
This parameter is built from the line number of the call from the function up the

.PARAMETER GraphUrl
Graph Url to use

.PARAMETER Method
The HTTP method to use for the request

.PARAMETER Endpoint
The endpoint to use for the request

.PARAMETER Resource
The resource to use for the request

.PARAMETER Body
The body of the request

.PARAMETER ContentType
The content type for the PATCH or POST request
#>
function Invoke-MgGraphRequestCustom {
    param (
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = "The component (script name) passed as LogID to the 'Write-Log' function")]
        [string]$LogId = $($MyInvocation.MyCommand).Name,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, HelpMessage = 'Graph Url to use')]
        [string]$GraphUrl = 'https://graph.microsoft.com',
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, HelpMessage = 'The HTTP method to use for the request')]
        [ValidateSet("GET", "POST", "PATCH", "DELETE")]
        [string]$Method,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, HelpMessage = 'The endpoint to use for the request')]
        [string]$Endpoint = 'beta',
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, HelpMessage = 'The resource to use for the request')]
        [string]$Resource,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, HelpMessage = 'The body of the request')]
        [object]$Body,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, HelpMessage = 'The content type for the PATCH or POST request')]
        [string]$ContentType = "application/json; charset=utf-8"
    )
    
    process {

        try {
            # Build the Uri
            $graphUri = "$($GraphUrl)/$($Endpoint)/$($Resource)"
            Write-Log -Message ("Building Uri for Graph request. Method: '{0}', Uri: '{1}'" -f $Method, $GraphUri) -LogId $LogId
            Write-Host ("Building Uri for Graph request. Method: '{0}', Uri: '{1}'" -f $Method, $GraphUri) -ForegroundColor Cyan
    
            # Call Graph API and get JSON response
            switch ($Method) {
                "GET" {
                    $graphResult = Invoke-MgGraphRequest -Uri $GraphUri -Method $Method -ErrorAction Stop
                }
                "POST" {
                    $graphResult = Invoke-MgGraphRequest -Uri $GraphUri -Method $Method -Body $Body -ContentType $ContentType -ErrorAction Stop
                }
                "PATCH" {
                    $graphResult = Invoke-MgGraphRequest -Uri $GraphUri -Method $Method -Body $Body -ContentType $ContentType -ErrorAction Stop
                }
                "DELETE" {
                    $graphResult = Invoke-MgGraphRequest -Uri $GraphUri -Method $Method -ErrorAction Stop
                }
            }
            return $graphResult
        }
        catch {
            Write-Log -Message $_ -LogId $LogId -Severity 3
            Write-Error -Message $_

            $userInput = Read-Host -Prompt "An error was encountered with the Graph request. Do you want to continue (c) or quit (q)?"
            switch ($userInput.ToLower()) {
                "c" {
                    Write-Host "Continuing the script..." -ForegroundColor Green
                    break
                }
                "q" {
                    Write-Host "Ending the script..." -ForegroundColor Red
                    Get-ScriptEnd -LogId $LogId -ErrorMessage $_.Exception.Message
                }
                default {
                    Write-Host "Invalid input. Please type 'c' or 'q'." -ForegroundColor Yellow
                }
            }
        }
    }
}