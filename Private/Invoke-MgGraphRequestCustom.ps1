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

.PARAMETER OutputBody
If True, output body of the request to console and log

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
        [string]$Body,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, HelpMessage = 'If True, output body of the request to console and log. Useful for debugging')]
        [bool]$OutputBody = $false,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, HelpMessage = 'The content type for the PATCH or POST request')]
        [string]$ContentType = "application/json"
    )
    
    process {

        try {
            # Build the Uri
            $graphUri = "$($GraphUrl)/$($Endpoint)/$($Resource)"
            if ($Body -and $OutputBody) {
                Write-Log -Message ("Building Uri for Graph request. Method: '{0}', Uri: '{1}', Body: '{2}'" -f $Method, $GraphUri, $Body) -LogId $LogId
                Write-Host ("Building Uri for Graph request. Method: '{0}', Uri: '{1}', Body: '{2}'" -f $Method, $GraphUri, $Body) -ForegroundColor Cyan
            }
            else {
                Write-Log -Message ("Building Uri for Graph request. Method: '{0}', Uri: '{1}'" -f $Method, $GraphUri) -LogId $LogId
                Write-Host ("Building Uri for Graph request. Method: '{0}', Uri: '{1}'" -f $Method, $GraphUri) -ForegroundColor Cyan
            }
    
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
        }
    }
}