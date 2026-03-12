#!/bin/bash
source /build/avi/avi_api.sh
#
# Creating API session
#
fqdn=sb-avicon-01.vclass.local
username='avi-edu'
password='VMware1!'
avi_version='31.1.2'
avi_cookie_file="/tmp/$(basename $0 | cut -d"." -f1)_${date_index}_cookie.txt"
curl_login=$(curl -s -k -X POST -H "Content-Type: application/json" \
                                -d "{\"username\": \"${username}\", \"password\": \"${password}\"}" \
                                -c ${avi_cookie_file} https://${fqdn}/login)
csrftoken=$(cat ${avi_cookie_file} | grep csrftoken | awk '{print $7}')
#
# get tenant
#
avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/tenant?page_size=-1"
tenant_results=$(echo $response_body | jq -c -r '.results')
#
# get virtualservice and disable all of them
#
avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "*" "${avi_version}" "" "${fqdn}" "api/virtualservice"
echo ${response_body} | jq -c -r .results[] | while read vs
do
  vs_uuid=$(echo ${vs} | jq -c -r '.uuid')
  json_data=$(echo $vs | jq -c -r '. += {"enabled": false}')
  item_tenant_uuid=$(echo ${vs} | jq -c -r '.tenant_ref' | grep / | cut -d/ -f6-)
  item_tenant_name=$(echo ${tenant_results} | jq -c -r --arg arg "${item_tenant_uuid}" '.[] | select( .uuid == $arg ) | .name')
  avi_api 2 2 "PUT" "${avi_cookie_file}" "${csrftoken}" "${item_tenant_name}" "${avi_version}" "${json_data}" "${fqdn}" "api/virtualservice/${vs_uuid}"
done
#
# Remove all the service engine
#
avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "*" "${avi_version}" "" "${fqdn}" "api/serviceengine-inventory"
echo ${response_body} | jq -c -r .results[] | while read se
do
  if [[ $(echo ${se} | jq -c -r '.config.virtualservice_refs | length') ==  0 ]]; then
    se_uuid=$(echo ${se} | jq -c -r '.config.uuid')
    item_tenant_uuid=$(echo ${se} | jq -c -r '.config.tenant_ref' | grep / | cut -d/ -f6-)
    item_tenant_name=$(echo ${tenant_results} | jq -c -r --arg arg "${item_tenant_uuid}" '.[] | select( .uuid == $arg ) | .name')
    avi_api 2 2 "DELETE" "${avi_cookie_file}" "${csrftoken}" "${item_tenant_name}" "${avi_version}" "" "${fqdn}" "api/serviceengine/${se_uuid}"
  fi
done
#
# Reboot clean
#
json_data='
{
  "mode": "REBOOT_CLEAN"
}'
avi_api 2 2 "POST" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "${json_data}" "${fqdn}" "api/cluster/reboot"