#!/bin/bash
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
#
# checking if there is a CLOUD_NSXT type of cloud and NSX OVERLAY use case
#
avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/cloud"
while read item
do
  if [[ $(echo ${item} | jq -c -r '.vtype') == "CLOUD_NSXT" && $(echo ${item} | jq -c -r '.nsxt_configuration.data_network_config.tz_type') == "OVERLAY" ]]; then
    nsx_cloud_uuid=$(echo ${item} | jq -c -r '.uuid')
    nsx_cloud_url=$(echo ${item} | jq -c -r '.url')
    avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "*" "${avi_version}" "" "${fqdn}" "api/cloud-inventory/?uuid=${nsx_cloud_uuid}"
    if [[ $(echo ${response_body} | jq -c -r '.results[0].status.state') != "CLOUD_STATE_PLACEMENT_READY" || $(echo ${response_body} | jq -c -r '.results[0].status.se_image_state[0].state') != "IMG_GEN_COMPLETE" ]]; then
      exit 1
    fi
    #
    #  checking if there is at least one SE with proper operational status
    #
    avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "*" "${avi_version}" "" "${fqdn}" "api/serviceengine-inventory/?cloud_ref.uuid=${nsx_cloud_uuid}"
    if [[ $(echo ${response_body} | jq -c -r '[.results[] | select(.runtime.oper_status.state == "OPER_UP").config.name] | length') -gt 0 ]]; then
      checkSe=ok
    fi
    #
    # checking the proper ip route for data network - SA-T1
    #
    avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/vrfcontext"
    while read vrf
    do
      if [[ $(echo ${vrf} | jq -c -r '.cloud_ref') == ${nsx_cloud_url} && $(echo ${vrf} | jq -c -r '.name') == "SA-T1" && $(echo ${vrf} | jq -c -r '.static_routes') != "null" ]]; then
        while read route
        do
          if [[ $(echo ${route} | jq -c -r '.prefix.ip_addr.addr') == "0.0.0.0" && $(echo ${route} | jq -c -r '.prefix.mask') == "0" && $(echo ${route} | jq -c -r '.next_hop.addr') == "22.0.0.1" ]]; then
            checkRoute=ok
          fi
        done< <(echo "${vrf}" | jq -c -r .static_routes[])
        #
        #
        #
      fi
    done< <(echo "${response_body}" | jq -c -r .results[])
    #
    #
    #
  fi
done< <(echo "${response_body}" | jq -c -r .results[])
#
#
#
if [[ ${checkSe} == "ok" && ${checkRoute} == "ok" ]]; then
  sleep 3
  exit 0
else
  exit 1
fi





