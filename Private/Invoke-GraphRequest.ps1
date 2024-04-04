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
            Write-Host ("Building Uri for Graph request. Method: '{0}', Uri: '{1}'" -f $Method, $GraphUri) -ForegroundColor Green
    
            # Call Graph API and get JSON response
            switch ($Method) {
                "GET" {
                    $graphResult = Invoke-RestMethod -Uri $GraphUri -Headers $Global:authHeader -Method $Method -ErrorAction Stop
                }
                "POST" {
                    $graphResult = Invoke-RestMethod -Uri $GraphUri -Headers $Global:authHeader -Method $Method -Body $Body -ContentType $ContentType -ErrorAction Stop
                }
                "PATCH" {
                    $graphResult = Invoke-RestMethod -Uri $GraphUri -Headers $Global:authHeader -Method $Method -Body $Body -ContentType $ContentType -ErrorAction Stop
                }
                "DELETE" {
                    $graphResult = Invoke-RestMethod -Uri $GraphUri -Headers $Global:authHeader -Method $Method -ErrorAction Stop
                }
            }
            return $graphResult
        }
        catch [System.Exception] {

            # Capture current error
            $ExceptionItem = $_
        
            # Construct response error custom object for cross platform support
            $ResponseBody = [PSCustomObject]@{
                "ErrorMessage" = [string]::Empty
                "ErrorCode"    = [string]::Empty
            }
        
            # Read response error details differently depending PSVersion
            if ($PSVersionTable.PSVersion.Major -eq 5) {
                
                # Read the response stream
                $StreamReader = New-Object -TypeName "System.IO.StreamReader" -ArgumentList @($ExceptionItem.Exception.Response.GetResponseStream())
                $StreamReader.BaseStream.Position = 0
                $StreamReader.DiscardBufferedData()
                $ResponseReader = ($StreamReader.ReadToEnd() | ConvertFrom-Json)
        
                # Set response error details
                $ResponseBody.ErrorMessage = $ResponseReader.error.message
                $ResponseBody.ErrorCode = $ResponseReader.error.code
            }
            else {
                $ErrorDetails = $ExceptionItem.ErrorDetails.Message | ConvertFrom-Json
        
                # Set response error details
                $ResponseBody.ErrorMessage = $ErrorDetails.error.message
                $ResponseBody.ErrorCode = $ErrorDetails.error.code
            }
        }
        
        # Convert status code to integer for output
        $HttpStatusCodeInteger = ([int][System.Net.HttpStatusCode]$ExceptionItem.Exception.Response.StatusCode)
        
        if ($Method -eq 'GET') {

            # Output warning message that the request failed with error message description from response stream
            Write-Log -Message ("Graph request failed with status code '{0}' '{1}'. Error details: '{2}' - '{3}'" -f $HttpStatusCodeInteger, $ExceptionItem.Exception.Response.StatusCode, $ResponseBody.ErrorCode, $ResponseBody.ErrorMessage) -LogId $LogId -Severity 3
            Write-Error -Message ("Graph request failed with status code '{0}' '{1}'. Error details: '{2}' - '{3}'" -f $HttpStatusCodeInteger, $ExceptionItem.Exception.Response.StatusCode, $ResponseBody.ErrorCode, $ResponseBody.ErrorMessage)
        }
        else {

            # Construct new custom error record
            $SystemException = New-Object -TypeName "System.Management.Automation.RuntimeException" -ArgumentList ("{0}: {1}" -f $ResponseBody.ErrorCode, $ResponseBody.ErrorMessage)
            $ErrorRecord = New-Object -TypeName "System.Management.Automation.ErrorRecord" -ArgumentList @($SystemException, $ErrorID, [System.Management.Automation.ErrorCategory]::NotImplemented, [string]::Empty)
        
            # Throw a terminating custom error record
            $PSCmdlet.ThrowTerminatingError($ErrorRecord)
        }
    }
}