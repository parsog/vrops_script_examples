################################################
# Build vROPS API string & invoking REST API
################################################
$vROPsServer = "vrops.corp.local"
$vROpsUser = "admin"
$vROpsPassword = "VMware1!"

<#
# Adding certificate exception to prevent API errors
################################################
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
#>

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$BaseURL = "https://" + $vROPsServer + "/suite-api/api/"
$AuthURL = $BaseURL + "auth/token/acquire"
$Type = "application/json"
# Creating JSON for Auth Body
$AuthJSON =
"{
  ""username"": ""$vROpsUser"",
  ""authSource"": ""local"",
  ""password"": ""$vROpsPassword""
}"
# Authenticating with API
Try {
    $vROPSSessionResponse = Invoke-RestMethod -Method POST -Uri $AuthURL -Body $AuthJSON -ContentType $Type
}

Catch {
    $_.Exception.ToString()
    $error[0] | Format-List -Force
}

# Extract auth token from the response
$vROPSSessionHeader = @{"Authorization"="vRealizeOpsToken "+$vROPSSessionResponse.'auth-token'.token
"Accept"="application/json"}

# $authToken will be the session authorization token
$authToken = $vROPSSessionResponse.'auth-token'.token


###############################################
# Get Super Metric Definition Details
###############################################
$SuperMetricListURL = $BaseURL+"supermetrics/" + "?pageSize=5000"

Try {
    $superMetricJSON = Invoke-RestMethod -Method GET -Uri $SuperMetricListURL -Headers $vROPSSessionHeader -ContentType $Type
    $superMetricList = $superMetricJSON
}
Catch {
    $_.Exception.ToString()
    $error[0] | Format-List -Force
}


$smArrayMeasure = $superMetricList.superMetrics | measure
$smCount = $smArrayMeasure.Count
$latestModTime = 0

# Check all super metric definitions to find the last one modified - this is what will be validated
For($i=0; $i -lt $smCount; $i++){
    $modTime = $superMetricList.superMetrics.modificationTime[$i]
    If($modTime -gt $latestModTime){
        # This is the latest found so far
        $latestIndex = $i
        $latestModTime = $modTime
    }
}

# Check to see if there are any metric definitions that have been created since Aug 4th, 2019 (a date after the pod was checked in)
If($latestModTime -lt 1564956050000){
    # no new super metric definitions
    $definitionValidation = "fail - no recent super metric definitions"
    Write-Output $definitionValidation 
    exit 1
} else {
    # get values for latest definition
    $SuperMetric = $superMetricList.superMetrics[$latestIndex]
    $smId = $SuperMetric.id
    $smName = $SuperMetric.name
    $smDescription = $SuperMetric.description
    $smFormula = $SuperMetric.formula
    $smTime = $SuperMetric.modificationTime
}


# check the super metric name and description
If($smName -notmatch 'Cluster VM Avg CPU \(\%\)') {
    Write-Output "fail - incorrect name"
    exit 1
}
If($smDescription -notmatch "Average CPU usage of all virtual machines in the cluster") {
    Write-Output "fail - incorrect description"
    exit 1
}

# check to see if the super metric definition was property written
If($smFormula -match "(?<fncn>^\w+)\(.*=(?<adapterType>\w+),.*=(?<object>\w+),.*=(?<metric>.*),.*=(?<depth>\d+)") {
    If($matches['fncn'] -ne "avg") {
        Write-Output "fail - function is not avg"
        exit 1
    }
    If($matches['object'] -ne "VirtualMachine") {
        Write-Output "fail - object is not virtual machine"
        exit 1
    }
    If($matches['metric'] -ne "cpu|usage_average") {
        Write-Output "fail - incorrect metric"
        exit 1
    }
    If($matches['depth'] -lt 2) {
        Write-Output "fail - depth is not at least 2"
        exit 1
    }
} Else {
    # The metric definition did not match the correct format
    Write-Output "fail and exit. Metric definition is not formatted correctly"
    exit 1
}


###############################################
# Check If Super Metric Defined on Cluster-02 Object
###############################################
$epochTime = ([int](Get-Date (Get-Date).ToUniversalTime() -UFormat %s) - 65) * 1000  #Epoch time in ms 65 seconds ago (to make sure that there is at least one metric)


Write-Output "Pausing two minutes to give vROps time to do its thing"
Start-Sleep -Seconds 125  # It will take two collection/analytics cycles for a new metric to show up (up to 120 seconds in this pod)

$StatsURL = $BaseURL+"resources/43bed1de-d293-4358-a2e9-2b137eadf794/statkeys"  #query Cluster-02 for all exsiting metric keys

Try {
    $statsJSON = Invoke-RestMethod -Method GET -Uri $StatsURL -Headers $vROPSSessionHeader -ContentType $Type
    $stats=$statsJSON.'stat-key'
}
Catch {
    $_.Exception.ToString()
    $error[0] | Format-List -Force
}


# Final validation
If($stats.key -match $smId) {
    Write-Output "found it"
    Exit 0
} Else {
    Write-Output "the metric was not added to Cluster-02 within two minutes"
    Exit 1
}

