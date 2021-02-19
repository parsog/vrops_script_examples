import urllib3
import requests
import json
urllib3.disable_warnings()


vrops_fqdn = "vrops80-weekly.cmbu.local"
api_url_base = "https://" + vrops_fqdn + "/suite-api"


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


def get_notification_templates():
    # 
    api_url = '{0}/api/notifications/email/templates'.format(api_url_base)
    response = requests.get(api_url, headers=api_header, verify=False)
    if response.status_code == 200:
        json_data = response.json()
        template_list = json_data["emailTemplateList"]
        count = len(template_list)
        for template in template_list:
            templateId = template['id']
            print(templateId)
        return(template_list)
    else:
        print('Could not get templates')

def create_notification_template(data):
    # creates an email notification template
    api_url = '{0}/api/notifications/email/templates'.format(api_url_base)
    response = requests.post(api_url, headers=api_header,
                            data=json.dumps(data), verify=False)
    if response.status_code == 201:
        json_data = response.json()
        return(json_data)
    else:
        print('Failed to create the template')


##### MAIN #####

token_header = {'Content-Type': 'application/json', 'Accept': 'application/json'}
access_key = get_token("admin", "VMware1!")

api_header = {'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'vRealizeOpsToken {0}'.format(access_key)}

# email notification template data
template_data = {
    "id" : None,
    "name" : "Email Template 1",
    "html" : True,
    "template" : "$$Subject=[Email Template 1 Subject] State:{{AlertCriticality}}, Name:{{AffectedResourceName}} \n\n New alert was generated at: {{AlertGenerateTime}} Info: {{AffectedResourceName}} {{AffectedResourceKind}} Alert Definition Name: {{AlertDefinitionName}} Alert Definition Description: {{AlertDefinitionDesc}} Object Name : {{AffectedResourceName}} Object Type : {{AffectedResourceKind}} Alert Impact: {{AlertImpact}} Alert State : {{AlertCriticality}} Alert Type : {{AlertType}} Alert Sub-Type : {{AlertSubType}} Object Health State: {{ResourceHealthState}} Object Risk State: {{ResourceRiskState}} Object Efficiency State: {{ResourceEfficiencyState}} Symptoms: {{Anomalies}} Recommendations: {{AlertRecommendation}} vROps Server - {{vcopsServerName}} Alert detail",
    "others" : [ ],
    "otherAttributes" : {}
}

#create_notification_template(template_data)
templates = get_notification_templates()

print(templates)
