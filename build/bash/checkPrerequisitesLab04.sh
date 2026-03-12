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
#
#
avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/scheduler"
while read item
do
  if [[ $(echo ${item} | jq -c -r '.name') == "Default-Scheduler" && $(echo ${item} | jq -c -r '.scheduler_action') == "SCHEDULER_ACTION_BACKUP" ]]; then
    checkScheduler=ok
  fi
done< <(echo "${response_body}" | jq -c -r .results[])
#
#
#
avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/backupconfiguration"
if [[ $(echo "${response_body}" | jq -c -r '.results[0].remote_directory') == "/home/avi-backup" && $(echo "${response_body}" | jq -c -r '.results[0].remote_file_transfer_protocol') == "SCP" && $(echo "${response_body}" | jq -c -r '.results[0].remote_hostname') == "sa-server-01" && $(echo "${response_body}" | jq -c -r '.results[0].upload_to_remote_host') == "true" ]]; then
  checkBackup=ok
fi
#
#
#
if [[ ${checkScheduler} == "ok" && ${checkBackup} == "ok" ]]; then
  sleep 1
  exit 0
else
  exit 1
fi