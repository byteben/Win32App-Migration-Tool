<#
.Synopsis
Created on:   03/04/2024
Updated on:   16/11/2026
Created by:   Ben Whitmore
Filename:     Invoke-MgGraphRequestCustom.ps1

.Description
Function to invoke a request to the Microsoft Graph API using the Microsoft.Graph.Authentication module from the Microsoft Graph SDK.
Transient failures (HTTP 429, 500, 502, 503, 504 and network errors) are retried, honouring the Retry-After header when present.
Throws if there is no valid Microsoft Graph connection.

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
If True, output body of the request to console and log. Bodies containing fileEncryptionInfo are never logged

.PARAMETER ContentType
The content type for the PATCH or POST request

.PARAMETER MaxRetries
The maximum number of retries for transient failures. Default is 5
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
        [string]$ContentType = "application/json",
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, HelpMessage = 'The maximum number of retries for transient failures')]
        [int]$MaxRetries = 5
    )

    try {

        # First check if we already have a valid connection with required scopes
        if (-not (Test-MgConnection)) {
            throw "No valid Microsoft Graph connection found. Please call Connect-MgGraphCustom first or pass at least the TenantId and ClientId parameters to New-Win32app"
        }

        # Build the Uri
        $graphUri = "$($GraphUrl)/$($Endpoint)/$($Resource)"
        if ($Body -and $OutputBody) {
            $bodyToLog = $Body
            if ($Body -match 'fileEncryptionInfo') {
                $bodyToLog = '<redacted: contains fileEncryptionInfo>'
            }
            Write-LogAndHost -Message ("Building Uri for Graph request. Method: '{0}', Uri: '{1}', Body: '{2}'" -f $Method, $graphUri, $bodyToLog) -LogId $LogId -ForegroundColor Cyan
        }
        else {
            Write-LogAndHost -Message ("Building Uri for Graph request. Method: '{0}', Uri: '{1}'" -f $Method, $graphUri) -LogId $LogId -ForegroundColor Cyan
        }

        $attempt = 0
        while ($true) {
            try {

                # Call Graph API and get JSON response
                switch ($Method) {
                    "GET" {
                        $graphResult = Invoke-MgGraphRequest -Uri $graphUri -Method $Method -ErrorAction Stop
                    }
                    "POST" {
                        $graphResult = Invoke-MgGraphRequest -Uri $graphUri -Method $Method -Body $Body -ContentType $ContentType -ErrorAction Stop
                    }
                    "PATCH" {
                        $graphResult = Invoke-MgGraphRequest -Uri $graphUri -Method $Method -Body $Body -ContentType $ContentType -ErrorAction Stop
                    }
                    "DELETE" {
                        $graphResult = Invoke-MgGraphRequest -Uri $graphUri -Method $Method -ErrorAction Stop
                    }
                }

                return $graphResult
            }
            catch {
                $statusCode = Get-GraphErrorStatusCode -ErrorRecord $_
                $retryable = $false
                if ($Method -in @('POST', 'PATCH')) {
                    # Not idempotent: a request that reached Graph but lost its response would run twice
                    # (for example two Win32 apps). Only throttled requests (429) are known not to have run
                    $retryable = ($statusCode -eq 429)
                }
                elseif ($null -ne $statusCode) {
                    $retryable = @(429, 500, 502, 503, 504) -contains $statusCode
                }
                else {
                    $retryable = Test-GraphTransientNetworkError -ErrorRecord $_
                }

                if (-not $retryable -or $attempt -ge $MaxRetries) {
                    throw
                }

                $attempt++
                $retryAfter = Get-GraphRetryAfterSeconds -ErrorRecord $_
                if ($null -ne $retryAfter -and $retryAfter -gt 0) {
                    $delay = [int][Math]::Ceiling($retryAfter)
                }
                else {
                    $delay = [int][Math]::Min(60, [Math]::Pow(2, $attempt))
                }

                Write-LogAndHost -Message ("Graph request '{0}' failed (status '{1}'): {2}. Retry {3}/{4} in {5} seconds" -f $Method, $statusCode, $_.Exception.Message, $attempt, $MaxRetries, $delay) -LogId $LogId -Severity 2
                Start-Sleep -Seconds $delay
            }
        }
    }
    catch {
        Write-LogAndHost -Message ([string]$_.Exception.Message) -LogId $LogId -Severity 3

        throw
    }
}

function Get-GraphErrorStatusCode {
    param($ErrorRecord)

    try {
        $response = $ErrorRecord.Exception.Response
        if ($null -ne $response -and $null -ne $response.StatusCode) {
            return [int]$response.StatusCode
        }
    }
    catch {
        Write-Verbose "Unable to read status code from error: $($_.Exception.Message)"
    }

    return $null
}

function Get-GraphRetryAfterSeconds {
    param($ErrorRecord)

    try {
        $response = $ErrorRecord.Exception.Response
        if ($null -eq $response -or $null -eq $response.Headers) {
            return $null
        }

        # System.Net.Http.HttpResponseMessage
        $retryAfter = $response.Headers.RetryAfter
        if ($null -ne $retryAfter) {
            if ($null -ne $retryAfter.Delta) {
                return [double]$retryAfter.Delta.TotalSeconds
            }
            if ($null -ne $retryAfter.Date) {
                $seconds = ($retryAfter.Date - [System.DateTimeOffset]::UtcNow).TotalSeconds
                if ($seconds -gt 0) { return [double]$seconds }
            }
        }
    }
    catch {
        Write-Verbose "Unable to read Retry-After from error: $($_.Exception.Message)"
    }

    return $null
}

function Test-GraphTransientNetworkError {
    param($ErrorRecord)

    $exception = $ErrorRecord.Exception
    while ($null -ne $exception) {
        $typeName = $exception.GetType().FullName
        if ($typeName -match 'HttpRequestException|WebException|SocketException|IOException|TaskCanceledException|TimeoutException') {
            return $true
        }
        $exception = $exception.InnerException
    }

    return $false
}
