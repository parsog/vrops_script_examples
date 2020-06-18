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
# Get "HOL" Alert Definition
###############################################
$AlertsURL = $BaseURL+"alertdefinitions?pageSize=5000"
Try {
    $AlertDefinitionJSON = Invoke-RestMethod -Method GET -Uri $AlertsURL -Headers $vROPSSessionHeader -ContentType $Type
    $alertDef = $AlertDefinitionJSON.alertDefinitions
}
Catch {
    $_.Exception.ToString()
    $error[0] | Format-List -Force
}

$validation = 'fail - no alert with "odyssey" in the name'
ForEach($definition in $alertDef) {
    
    If($definition.name -match "odyssey") {
        $validation = 'success - found an alert with "HOL" in the name'
        $alertName = $definition.name
        $holAlertDefinition = $definition.id
        If($definition.description -notmatch "testing") {
            Write-Output "fail - bad description"
            Exit 1
        }
        If($definition.resourceKindKey -notmatch "virtualmachine") {
            Write-Output "fail - alert not defined on virtual machine"
            Exit 1
        }
        If($definition.waitCycles -ne 1) {
            Write-Output "fail - Alert wait cycles not equal 1"
            Exit 1
        }
        If($definition.type -ne 16) {
            Write-Output "fail - Alert not Virtualization-Hypervisor type"
            Exit 1
        }
        If($definition.subType -ne 19) {
            Write-Output "fail - Alert sub-type not Performance"
            Exit 1
        }

        ###############################################
        # Build list of states
        ###############################################

        ForEach($state in $definition.states) {
            If($state.severity -notmatch "AUTO") {
                $state.severity
                Write-Output "fail - alert definition has a severity set - should be symptom-based"
                Exit 1
            }
            $SymptomSet = $state.'base-symptom-set'
            ForEach($set in $SymptomSet) {
                $SymptomDefinitionId = $set.symptomDefinitionIds
            }
            $AlertImpact = $state.impact
            ForEach($aImpact in $AlertImpact) {
                If($aImpact.detail -notmatch "health") {
                    Write-Output "fail - impact is not health"
                    Exit 1
                }
            }


            $RecommendationId = $state.recommendationPriorityMap  -split([Environment]::NewLine) | Select -First 1

            Try {
            $RecommendationId = $RecommendationId.Substring(2, $RecommendationId.Length-5)
            }
            Catch {
                Write-Output "fail - there is no recommendation for the alert"
                Exit 1
            }
        }

    }
}


If($validation -match "fail") {
    Write-Output $validation
    Exit 1
}




###############################################
# Get Symptom Definition
###############################################
$SymptomDefinitionURL = $BaseURL+"symptomdefinitions/" + $SymptomDefinitionId + "?pageSize=5000"

Try {
    $SymptomDefinitionJSON = Invoke-RestMethod -Method GET -Uri $SymptomDefinitionURL -Headers $vROPSSessionHeader -ContentType $Type
    $SymptomDefinition = $SymptomDefinitionJSON
    $SymptomDefinitionState = $SymptomDefinitionJSON.state
}
Catch {
    $_.Exception.ToString()
    $error[0] | Format-List -Force
}

If($SymptomDefinition.name -notmatch "odyssey") {
    Write-Output "fail - bad symptom name"
    Exit 1
}
If($SymptomDefinition.waitCycles -ne 1) {
    Write-Output "fail - symptom wait cycles not equal 1"
    Exit 1
}
If($SymptomDefinition.resourceKindKey -notmatch "virtualmachine") {
    Write-Output "fail - symptom resource kind not virtual macine"
    Exit 1
}

ForEach($SymptomDefinitionState in $SymptomDefinitionState) {
    # Setting values
    $SymptomSeverity = $SymptomDefinitionState.severity

    $SymptomCondition = $SymptomDefinitionState.condition
    ForEach($SymptomCondition in $SymptomCondition) {
        If($SymptomCondition.type -notmatch "CONDITION_HT") {
            Write-Output "fail - symptom condition not hard threshold type"
            Exit 1
        }
        If($SymptomCondition.key -notmatch "guestfilesystem|percentage_total") {
            Write-Output "fail - symptom metric is incorrect"
            Exit 1
        }
        If($SymptomCondition.operator -ne "GT") {
            Write-Output "fail - symptom operator is not greater than"
            Exit 1
        }
        If($SymptomCondition.value -notmatch 25) {
            Write-Output "fail - symptom value is not 25"
            Exit 1
        }
    }
}


###############################################
# Get Recommendation
###############################################
$RecommendationURL = $BaseURL+"recommendations/" + $RecommendationId + "?pageSize=5000"

Try {
    $RecommendationJSON = Invoke-RestMethod -Method GET -Uri $RecommendationURL -Headers $vROPSSessionHeader -ContentType $Type
    $RecommendationObject = $RecommendationJSON
}
Catch {#
    $_.Exception.ToString()
    $error[0] | Format-List -Force
}

If($RecommendationObject.description -notmatch "odyssey challenge") {
    Write-Output "fail - recommendation is wrong"
    Exit 1
}
If($RecommendationObject.action.targetMethod -notmatch "delete unused snapshots for vm express") {
    Write-Output "fail - recommendation action is wrong"
    Exit 1
}

Write-Output "Looks good"
Exit 0


<# Original plan was to check for triggered alerts but don't want to wait for validation
###############################################
# Getting Current Alerts
###############################################
$AlertsURL = $BaseURL+"alerts?pageSize=5000"

Try {
    $AlertsJSON = Invoke-RestMethod -Method GET -Uri $AlertsURL -Headers $vROPSSessionHeader -ContentType $Type
    $Alerts = $AlertsJSON.alerts
}
Catch {
    $_.Exception.ToString()
    $error[0] | Format-List -Force
}

###############################################
# Get all active alerts
###############################################
$ActiveAlerts = $Alerts | Where-Object {$_.status -eq "Active"}
$ActiveAlertsCount = $ActiveAlerts.count

###############################################
# Get an active alert with "HOL" in the alert name ($testAlertId)
###############################################
$HOLalert = $ActiveAlerts | Where-Object {$_.alertDefinitionName -like "HOL"}
$testAlertId = $HOLalert.AlertId -split([Environment]::NewLine) | Select -First 1
$testAlertDefinition = $HOLalert.alertDefinitionId -split([Environment]::NewLine) | Select -First 1
"Test alert: $HOLalert.alertDefinitionName"
"Test Alert ID: $testAlertId"
"Test Alert Definition ID: $testAlertDefinition"


<#  This block was used for testing to get all open alerts
# Output of result
"ActiveAlerts:$ActiveAlertsCount"

###############################################
# Building list of alerts
###############################################
$AlertList = @()
ForEach($ActiveAlert in $ActiveAlerts) {
    # Setting values
    $AlertDefinitionId = $ActiveAlert.alertDefinitionId
    $AlertDefinition = $ActiveAlert.alertDefinitionName
    $AlertId = $ActiveAlert.alertId
    $AlertLevel = $ActiveAlert.alertLevel
    $AlertImpact = $ActiveAlert.alertImpact

    # Converting date times from Epoch to readable format
    $AlertStartTimeUTC = $ActiveAlert.startTimeUTC
    $AlertUpdateTimeUTC = $ActiveAlert.updateTimeUTC
    $AlertStartTime = [TimeZone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddMilliSeconds($AlertStartTimeUTC))
    $AlertUpdateTime = [TimeZone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddMilliSeconds($AlertStartTimeUTC))

    # Adding to table
    $AlertListRow = new-object PSObject
    $AlertListRow | Add-Member -MemberType NoteProperty -Name "Alert ID" -Value "$AlertId"
    $AlertListRow | Add-Member -MemberType NoteProperty -Name "Level" -Value "$AlertLevel"
    $AlertListRow | Add-Member -MemberType NoteProperty -Name "Impact" -Value "$AlertImpact"
    $AlertListRow | Add-Member -MemberType NoteProperty -Name "Alert Name" -Value "$AlertDefinition"
    $AlertListRow | Add-Member -MemberType NoteProperty -Name "Alert Definition ID" -Value "$AlertDefinitionId"
    $AlertListRow | Add-Member -MemberType NoteProperty -Name "Start" -Value "$AlertStartTime"
    $AlertListRow | Add-Member -MemberType NoteProperty -Name "Update" -Value "$AlertUpdateTime"
    $AlertList += $AlertListRow
    }
# Output of the list
$AlertList | Sort-Object Alert | Format-Table
#>
