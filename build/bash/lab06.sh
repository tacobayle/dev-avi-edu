#!/bin/bash
ansible-playbook /build/ansible/sa/lab06.yaml
/bin/bash /build/bash/initializeYourVs.sh
source /build/avi/avi_api.sh
#
# Creating API session
#
fqdn=sa-avicon-01.vclass.local
username='avi-edu'
password='VMware1!'
avi_version='31.1.1'
avi_cookie_file="/tmp/$(basename $0 | cut -d"." -f1)_${date_index}_cookie.txt"
curl_login=$(curl -s -k -X POST -H "Content-Type: application/json" \
                                -d "{\"username\": \"${username}\", \"password\": \"${password}\"}" \
                                -c ${avi_cookie_file} https://${fqdn}/login)
csrftoken=$(cat ${avi_cookie_file} | grep csrftoken | awk '{print $7}')
avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/cloud"
echo ${response_body} | jq -c -r .results[] | while read item
do
  if [[ $(echo ${item} | jq -c -r '.vtype') == "CLOUD_NSXT" ]]; then
    nsx_cloud_uuid=$(echo ${item} | jq -c -r '.uuid')
    count=1
    response_body=""
    until [[ $(echo ${response_body} | jq -c -r '.results[0].runtime.oper_status.state') == "OPER_UP" ]]
    do
      avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/virtualservice-inventory/?cloud_uuid=${nsx_cloud_uuid}"
      sleep 10
      count=$((count+1))
        if [[ "${count}" -eq 60 ]]; then
          echo exit 1
        fi
    done
  fi
done