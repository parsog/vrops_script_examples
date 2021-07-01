import urllib3
import requests
import json
urllib3.disable_warnings()

# put your values here
vrops_fqdn = "vrops80-weekly.cmbu.local"
api_url_base = "https://" + vrops_fqdn + "/suite-api"
vrops_user = "admin"
vrops_password = "VMware1!"
base_object_name = "wdcc01"

def get_token(user_name, pass_word):
    api_url = '{0}/api/auth/token/acquire'.format(api_url_base)
    data = {
        "username": user_name,
        "password": pass_word
    }
    response = requests.post(api_url, headers=token_header,
                             data=json.dumps(data), verify=False)
    if response.status_code == 200:
        json_data = response.json()
        key = json_data['token']
        return key
    else:
        return('Token failure')


def get_objectId(objName, objType):
    # gets the object ID for the base object
    api_url = '{0}/api/resources?name={1}&resourceKind={2}'.format(api_url_base, objName, objType)
    response = requests.get(api_url, headers=api_header, verify=False)
    if response.status_code == 200:
        json_data = response.json()
        resourceList = json_data['resourceList']
        count = len(resourceList)
        if count == 1:
            resource = resourceList[0]
            resourceId = resource['identifier']
            return(resourceId)
        else:
            return("multiple matches")
    else:
        return('API call failed')

def get_child_objects(objId, childType):
    # creates an email notification template
    api_url = '{0}/api/resources/{1}/relationships/children'.format(api_url_base, objId)
    response = requests.get(api_url, headers=api_header, verify=False)
    if response.status_code == 200:
        json_data = response.json()
        resourceList = json_data['resourceList']
        childIds = []
        for resource in resourceList:
            objectType = resource['resourceKey']['resourceKindKey']
            if objectType == childType:
                childId = resource['identifier']
                childIds.append(childId)
        return(childIds)
    else:
        return('API call failed')


##### MAIN #####

token_header = {'Content-Type': 'application/json', 'Accept': 'application/json'}
access_key = get_token(vrops_user, vrops_password)

api_header = {'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'vRealizeOpsToken {0}'.format(access_key)}

base_cluster_id = get_objectId(base_object_name, 'clustercomputeresource')
hosts = get_child_objects(base_cluster_id, 'HostSystem')
print(hosts)
