import urllib3
import requests
import json
urllib3.disable_warnings()

local_creds = False

debug = True


vrops_fqdn = "vrops80-weekly.cmbu.local"
api_url_base = "https://" + vrops_fqdn + "/suite-api"


def log(msg):
    if debug:
        sys.stdout.write(msg + '\n')
    file = open("C:\\hol\\vraConfig.log", "a")
    file.write(msg + '\n')
    file.close()


def send_slack_notification(payload):
    slack_url = 'https://hooks.slack.com/services/'
    post_url = slack_url + slack_api_key
    requests.post(url=post_url, proxies=proxies, json=payload)
    return()


def extract_values(obj, key):
    """Pull all values of specified key from nested JSON."""
    arr = []

    def extract(obj, arr, key):
        """Recursively search for values of key in JSON tree."""
        if isinstance(obj, dict):
            for k, v in obj.items():
                if isinstance(v, (dict, list)):
                    extract(v, arr, key)
                elif k == key:
                    arr.append(v)
        elif isinstance(obj, list):
            for item in obj:
                extract(item, arr, key)
        return arr
    results = extract(obj, arr, key)
    return results


def get_token(user_name, pass_word):
    api_url = '{0}/api/auth/token/acquire'.format(api_url_base)
    data = {
        "username": user_name,
        "password": pass_word
    }
    response = requests.post(api_url, headers=headers,
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
    response = requests.get(api_url, headers=headers1, verify=False)
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
    # 
    api_url = '{0}/api/notifications/email/templates'.format(api_url_base)
    response = requests.post(api_url, headers=headers1,
                            data=json.dumps(data), verify=False)
    if response.status_code == 201:
        json_data = response.json()
        template_list = extract_values(json_data, 'emailTemplateList')
        for x in template_list:
            print(x)
        return(template_list)
    else:
        print('FAIL')


##### MAIN #####

headers = {'Content-Type': 'application/json', 'Accept': 'application/json'}

access_key = get_token("admin", "VMware1!")

headers1 = {'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'vRealizeOpsToken {0}'.format(access_key)}
headers2 = {'Content-Type': 'application/x-yaml',
            'Authorization': 'Bearer {0}'.format(access_key)}


# template data
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

