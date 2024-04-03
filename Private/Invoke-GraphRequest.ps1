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
function Invoke-GraphRequest {
    param (
        [Parameter(Mandatory = $false, ValuefromPipeline = $false, HelpMessage = "The component (script name) passed as LogID to the 'Write-Log' function")]
        [string]$LogId = $($MyInvocation.MyCommand).Name,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, HelpMessage = 'Graph Url to use')]
        [string]$GraphUrl = 'https://graph.microsoft.com',
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, HelpMessage = 'The HTTP method to use for the request')]
        [ValidateSet("GET", "POST", "PATCH", "DELETE")]
        [string]$Method,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, HelpMessage = 'The endpoint to use for the request')]
        [string]$Endpoint = 'Beta',
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
            Write-Host ("Building Uri for Graph request. Method: '{0}', Uri: '{1}'" -f $Method, $GraphUri) -ForegroundColor Green
    
            # Call Graph API and get JSON response
            switch ($Method) {
                "GET" {
                    $graphResult = Invoke-RestMethod -Uri $GraphURri-Headers $Global:AuthHeader -Method $Method -ErrorAction Stop -Verbose:$false
                }
                "POST" {
                    $graphResult = Invoke-RestMethod -Uri $GraphUri -Headers $Global:AuthHeader -Method $Method -Body $Body -ContentType $ContentType -ErrorAction Stop -Verbose:$false
                }
                "PATCH" {
                    $graphResult = Invoke-RestMethod -Uri $GraphUri -Headers $Global:AuthHeader -Method $Method -Body $Body -ContentType $ContentType -ErrorAction Stop -Verbose:$false
                }
                "DELETE" {
                    $graphResult = Invoke-RestMethod -Uri $GraphUri -Headers $Global:AuthHeader -Method $Method -ErrorAction Stop -Verbose:$false
                }
            }
            return $graphResult
        }
        catch [System.Exception] {
            Write-Log -Message ("Error invoking Graph request. Error: '{0}'" -f $_.Exception.Message) -LogId $LogId -Severity 3
            Write-Error -Message ("Error invoking Graph request. Error: '{0}'" -f $_.Exception.Message)
        }
    }
}