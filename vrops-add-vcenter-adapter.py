# addes a vCenter adapter and vCenter credentials to vROps

import json
import requests
import urllib3
urllib3.disable_warnings()
    

vrops_fqdn = "vr-operations.corp.local"
api_url_base = "https://" + vrops_fqdn + "/suite-api/api/"
headers = {'Content-Type': 'application/json', 'Accept': 'application/json'}


def get_token(user_name,pass_word):
    api_url = '{0}auth/token/acquire'.format(api_url_base)
    data =  {
              "username": user_name,
              "password": pass_word,
              "authSource": "local"
            }
    response = requests.post(api_url, headers=headers, data=json.dumps(data), verify=False)
    if response.status_code == 200:
        json_data = response.json()
        key = json_data['token']
        return key
    else:
        return('no token')


def add_vcenter_adapter():
    api_url = '{0}adapters'.format(api_url_base)
    data = {
        "name" : "VC Adapter Instance",
        "description" : "A vCenter Adapter Instance",
        "collectorId" : "1",
        "adapterKindKey" : "VMWARE",
        "resourceIdentifiers" : [ 
            {
            "name" : "AUTODISCOVERY",
            "value" : "true"
            }, {
            "name" : "PROCESSCHANGEEVENTS",
            "value" : "true"
            }, {
            "name" : "VCURL",
            "value" : "https://vcsa-01a.corp.local/sdk"
            } 
        ],
        "credential" : {
            "id" : "",
            "name" : "New Principal Credential",
            "adapterKindKey" : "VMWARE",
            "credentialKindKey" : "PRINCIPALCREDENTIAL",
            "fields" : [ 
                {
                "name" : "USER",
                "value" : "administrator@corp.local"
                }, {
                "name" : "PASSWORD",
                "value" : "VMware1!"
                } 
            ],
            "others" : [ ],
            "otherAttributes" : { }
        },
        "others" : [ ],
        "otherAttributes" : {
        }
    }
    response = requests.post(api_url, headers=headers1, data=json.dumps(data), verify=False)
    if response.status_code == 201:
        print('success')
    else:
        print('I failed')




##### MAIN #####

access_token = get_token("admin","VMware1!")
access_key = "vRealizeOpsToken " + access_token
headers1 = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Authorization': access_key
    }

add_vcenter_adapter()




