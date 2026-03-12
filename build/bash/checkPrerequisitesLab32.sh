#!/bin/bash
source /build/avi/avi_api.sh
/bin/bash /build/bash/checkPrerequisitesLab06.sh
/bin/bash /build/bash/checkPrerequisitesLab09.sh
#!/bin/bash
source /build/avi/avi_api.sh
#
# Site A
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
avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/cloud"
while read item
do
  if [[ $(echo ${item} | jq -c -r '.vtype') == "CLOUD_NSXT" && $(echo ${item} | jq -c -r '.nsxt_configuration.data_network_config.tz_type') == "OVERLAY" ]]; then
    nsx_cloud_uuid=$(echo ${item} | jq -c -r '.uuid')
    nsx_cloud_url=$(echo ${item} | jq -c -r '.url')
    #
    avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "*" "${avi_version}" "" "${fqdn}" "api/virtualservice-inventory/?name=sa-global-dns-01"
    if [[ $(echo "${response_body}" | jq -c -r .results[0].runtime.oper_status.state) == "OPER_UP" && $(echo "${response_body}" | jq -c -r .results[0].config.cloud_ref) == "${nsx_cloud_url}" ]]; then
      checkVsSiteA=ok
    fi
    #
  fi
done< <(echo "${response_body}" | jq -c -r .results[])
#
# Site B
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
avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/cloud"
while read item
do
  if [[ $(echo ${item} | jq -c -r '.vtype') == "CLOUD_NSXT" && $(echo ${item} | jq -c -r '.nsxt_configuration.data_network_config.tz_type') == "VLAN" ]]; then
    nsx_cloud_uuid=$(echo ${item} | jq -c -r '.uuid')
    nsx_cloud_url=$(echo ${item} | jq -c -r '.url')
    #
    avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "*" "${avi_version}" "" "${fqdn}" "api/virtualservice-inventory/?name=sb-global-dns-01"
    if [[ $(echo "${response_body}" | jq -c -r .results[0].runtime.oper_status.state) == "OPER_UP" && $(echo "${response_body}" | jq -c -r .results[0].config.cloud_ref) == "${nsx_cloud_url}" ]]; then
      checkVsSiteB=ok
    fi
    #
  fi
done< <(echo "${response_body}" | jq -c -r .results[])
#
#
#
if [[ ${checkVsSiteA} == "ok" && ${checkVsSiteB} == "ok" ]]; then
  sleep 1
  exit 0
else
  exit 1
fi