Connect-VIServer vcsa-01a.corp.local -User administrator@corp.local -Password VMware1!

Start-Sleep -Seconds 5


# Check vCenter to see if a task is running to remove snapshots
$task = Get-Task
$taskCount = $task.Count
$taskDescription = $task.Description  # an array of the descriptions of all recent tasks in vCenter

$vms = Get-Cluster Cluster-02 | Get-VM
$snaps = $vms | Get-Snapshot
$snapCount = $snaps.count
$vmIds = $vms.Id   # array of all VM IDs in the cluster



If($taskCount -eq 1) {
    #single task - check to see if it is a snapshot deletions for a VM in Cluster-02
    $validation = "failed - the single recent task is not a snapshot deletion for a VM in Cluster-02"  # set the validation to failed in case it is not validated in the loop below
    $task.Description


    If($task.Description -like "Remove snapshot") {
        # there is a snapshot removal task but is it on one of the Cluster-02 VMs?
        If($vmIds -contains $task.ObjectId) {
            $validation = "success - the single recent task is a snapshot deletion on a VM in Cluster-02"
        }
    }
} ElseIf($taskCount -gt 1) {
    #multiple tasks - check to see if any of them are snapshot deletions for a VM in Cluster-02
    $validation = "failed - none of the recent tasks are snapshot deletions for a VM in Cluster-02"  # set the validation to failed in case it is not validated in the loop below
    For($i=0;$i -lt $taskCount; $i++) {
        If($task.Description[$i] -like "Remove snapshot") {
            # there is a snapshot removal task but is it on one of the Cluster-02 VMs?
            If($vmIds -contains $task.ObjectId[$i]) {
                $validation = "success - at least one of the recent tasks is a snapshot deletion on a VM in Cluster-02"
                break  # as soon as we get a match there is no need to continue checking
            }
        }
    }
} Else {
    #there are no recent tasks in vCenter
    #check to see if the snapshot deletion already completed
        If($snaps.Count -eq 0) {
            $validation = "success - all snapshots have been deleted"
        } Else {
            $validation = "failed - no recent tasks but snapshots still exist"
        }
}


Disconnect-VIServer vcsa-01a.corp.local -Confirm:$false

Write-Output $validation
If ($validation -Match "success") {
    exit 0
} Else {
    exit 1
}

