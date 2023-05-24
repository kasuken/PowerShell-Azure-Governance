# Input bindings are passed in via param block.
param($Timer)

# Get the current universal time in the default string format
$currentUTCtime = (Get-Date).ToUniversalTime()

# The 'IsPastDue' porperty is 'true' when the current function invocation is later than scheduled.
if ($Timer.IsPastDue) {
    Write-Host "PowerShell timer is running late!"
}

$scope = "https://graph.microsoft.com/"

$tokenAuthUri = $env:IDENTITY_ENDPOINT + "?resource=$scope&api-version=2019-08-01"
$response = Invoke-RestMethod -Method Get -Headers @{"X-IDENTITY-HEADER"="$env:IDENTITY_HEADER"} -Uri $tokenAuthUri -UseBasicParsing
$accessToken = $response.access_token

#If access token is null, app is running in local environment
if ($null -eq $accessToken) {
    $tenantID = $env:TENANT_ID
    $appID = $env:APP_ID
    $client_secret = $env:CLIENT_SECRET

    $body = @{
        grant_type = "client_credentials"
        client_id = $appID
        client_secret = $client_secret
        scope = "https://graph.microsoft.com/.default"
    }
    
    $url = 'https://login.microsoftonline.com/' + $tenantId + '/oauth2/v2.0/token'

    try { 
        $tokenRequest = Invoke-WebRequest -Method Post -Uri $url -ContentType "application/x-www-form-urlencoded" -Body $body -UseBasicParsing -ErrorAction Stop 
    }
    catch { Write-Host "Unable to obtain access token, aborting..."; return }

    $accessToken = ($tokenRequest.Content | ConvertFrom-Json).access_token
}

#Invoke Graph API to get all groups
$authHeader = @{    
    'Content-Type'='application/json'
    'Authorization'='Bearer ' +  $accessToken
    'ConsistencyLevel'='eventual'
}
$uri = 'https://graph.microsoft.com/v1.0/groups'
$groups = (Invoke-RestMethod -Uri $uri -Headers $authHeader -Method GET).value

#Invoke Graph API to get members count for each group
foreach ($group in $groups) {
    $uri = 'https://graph.microsoft.com/v1.0/groups/' + $group.id + '/members/$count'
    $count = (Invoke-RestMethod -Uri $uri -Headers $authHeader -Method GET)

    #If group has no members, delete it
    if ($count -eq 0) {
        $uri = 'https://graph.microsoft.com/v1.0/groups/' + $group.id
        Invoke-RestMethod -Uri $uri -Headers $authHeader -Method Delete
    }
}
