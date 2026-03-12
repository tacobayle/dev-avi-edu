#!/bin/bash
source /build/avi/avi_api.sh
#
# Creating API session
#
fqdn=sb-avicon-01.vclass.local
username='avi-edu'
password='VMware1!'
avi_version='31.1.1'
avi_cookie_file="/tmp/$(basename $0 | cut -d"." -f1)_${date_index}_cookie.txt"
curl_login=$(curl -s -k -X POST -H "Content-Type: application/json" \
                                -d "{\"username\": \"${username}\", \"password\": \"${password}\"}" \
                                -c ${avi_cookie_file} https://${fqdn}/login)
csrftoken=$(cat ${avi_cookie_file} | grep csrftoken | awk '{print $7}')
#
# checking if there is a CLOUD_NSXT type of cloud and VLAN use case
#
avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/cloud"
while read item
do
  if [[ $(echo ${item} | jq -c -r '.vtype') == "CLOUD_VCENTER" ]]; then
    vcenter_cloud_uuid=$(echo ${item} | jq -c -r '.uuid')
    #
    #  checking if there is a virtual service called nsx-vlan-vs
    #
    avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/virtualservice"
    while read vs
    do
      if [[ $(echo ${vs} | jq -c -r '.name') == "SB-DNS-01" && $(basename $(echo ${vs} | jq -c -r '.cloud_ref')) == ${vcenter_cloud_uuid} ]]; then
        checkDnsVs=ok
      fi
    done< <(echo "${response_body}" | jq -c -r .results[])
  fi
  if [[ $(echo ${item} | jq -c -r '.vtype') == "CLOUD_NSXT" && $(echo ${item} | jq -c -r '.nsxt_configuration.data_network_config.tz_type') == "VLAN" ]]; then
    nsx_cloud_uuid=$(echo ${item} | jq -c -r '.uuid')
    nsx_cloud_url=$(echo ${item} | jq -c -r '.url')
    avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "*" "${avi_version}" "" "${fqdn}" "api/cloud-inventory/?uuid=${nsx_cloud_uuid}"
    if [[ $(echo ${response_body} | jq -c -r '.results[0].status.state') != "CLOUD_STATE_PLACEMENT_READY" || $(echo ${response_body} | jq -c -r '.results[0].status.se_image_state[0].state') != "IMG_GEN_COMPLETE" ]]; then
      exit 1
    fi
    avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "*" "${avi_version}" "" "${fqdn}" "api/serviceengine-inventory/?cloud_ref.uuid=${nsx_cloud_uuid}"
    #
    #  checking if there is at least one SE with proper operational status
    #
    avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "*" "${avi_version}" "" "${fqdn}" "api/serviceengine-inventory/?cloud_ref.uuid=${nsx_cloud_uuid}"
    if [[ $(echo ${response_body} | jq -c -r '[.results[] | select(.runtime.oper_status.state == "OPER_UP").config.name] | length') -gt 0 ]]; then
      checkSe=ok
    fi
    #
    #  checking if there is a virtual service called nsx-vlan-vs
    #
    avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/virtualservice"
    while read vs
    do
      if [[ $(echo ${vs} | jq -c -r '.name') == "nsx-vlan-vs" && $(basename $(echo ${vs} | jq -c -r '.cloud_ref')) == ${nsx_cloud_uuid} ]]; then
        checkVs=ok
      fi
    done< <(echo "${response_body}" | jq -c -r .results[])
  fi
done< <(echo "${response_body}" | jq -c -r .results[])
#
#
#
if [[ ${checkSe} == "ok" && ${checkVs} == "ok" && ${checkDnsVs} == "ok" ]]; then
  sleep 3
  exit 0
else
  exit 1
fi