#!/bin/bash
source /usr/local/bin/avi_api.sh
webhook_url='https://chat.googleapis.com/v1/spaces/AAQA4IHsZ3w/messages?key=AIzaSyDdI0hCZtE6vySjMm-WEfRq3CPzqKqqsHI&token=HxKJ-xNo0aRoy6mOIRrPZRizlqgNZz8nCgAFv_LixEA'
#
# google chat function
#
send_google_chat_message() {
  local url="$1"
  local message="$2"

  if [[ -z "$url" || -z "$message" ]]; then
    echo "Error: Webhook URL or message is missing."
    return 1
  fi

  local payload='{"text":"'$message'"}'

  curl -X POST -H "Content-Type: application/json; charset=UTF-8" -d "$payload" "$url"
}
#
# check Avi API
#
count=1
until [ "$(curl -k -s -o /dev/null -w "%{http_code}" "https://172.20.10.130/")" -eq 200 ]
do
  sleep 20
  count=$((count+1))
  if [[ "${count}" -eq 500 ]]; then
    message="Avi API check failed for 172.20.10.130 (siteA)"
    send_google_chat_message "$webhook_url" "$message"
  fi
  echo "site A Avi API is not good"
done
echo "site A Avi API is good"
count=1
until [ "$(curl -k -s -o /dev/null -w "%{http_code}" "https://172.20.110.130/")" -eq 200 ]
do
  sleep 20
  count=$((count+1))
  if [[ "${count}" -eq 500 ]]; then
    message="Avi API check failed for 172.20.10.130 (siteB)"
    send_google_chat_message "$webhook_url" "$message"
  fi
  echo "site B Avi API is not good"
done
echo "site B Avi API is good"
sleep 300
#
# Avi Enable VS
#
ips='["172.20.10.130", "172.20.110.130"]'
username=admin
password='VMware1!'
avi_version='31.1.1'
avi_cookie_file="/tmp/$(basename $0 | cut -d"." -f1)_cookie.txt"
rm -f ${avi_cookie_file}
echo $ips | jq -c -r .[] | while read ip
do
  curl_login=$(curl -s -k -X POST -H "Content-Type: application/json" \
                                  -d "{\"username\": \"${username}\", \"password\": \"${password}\"}" \
                                  -c ${avi_cookie_file} https://${ip}/login)
  csrftoken=$(cat ${avi_cookie_file} | grep csrftoken | awk '{print $7}')
  #
  # get tenant
  #
  avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${ip}" "api/tenant?page_size=-1"
  tenant_results=$(echo $response_body | jq -c -r '.results')
  #
  # get virtualservice
  #
  avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "*" "${avi_version}" "" "${ip}" "api/virtualservice"
  echo ${response_body} | jq -c -r .results[] | while read vs
  do
    vs_uuid=$(echo ${vs} | jq -c -r '.uuid')
    json_data=$(echo $vs | jq -c -r '. += {"enabled": true}')
    item_tenant_uuid=$(echo ${vs} | jq -c -r '.tenant_ref' | grep / | cut -d/ -f6-)
    item_tenant_name=$(echo ${tenant_results} | jq -c -r --arg arg "${item_tenant_uuid}" '.[] | select( .uuid == $arg ) | .name')
    avi_api 2 2 "PUT" "${avi_cookie_file}" "${csrftoken}" "${item_tenant_name}" "${avi_version}" "${json_data}" "${ip}" "api/virtualservice/${vs_uuid}"
  done
  #
  # checking licenses vailidity
  #
  avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${ip}" "api/licensing"
  echo ${response_body} | jq -c -r .licenses[] | while read item
  do
    if [[ $(echo ${item} | jq -c -r '.license_name') == "Trial" ]] ; then
      echo "ignore trial license"
    else
      date_valid_until=$(date -d $(echo ${item} | jq -c -r '.valid_until') +'%Y-%m-%d')
      today_date=$(date +'%Y-%m-%d')
      days_remaining=$((($(date -d "$date_valid_until" +%s) - $(date +%s)) / 86400))
      if [[ ${date_valid_until} < ${today_date} ]]; then
        message="${vApp_type}: ${ip}, cores $(echo ${item} | jq -c -r '.cores'), expired since ${date_valid_until}"
        send_google_chat_message "$webhook_url" "$message"
      else
        echo "${ip}, cores $(echo ${item} | jq -c -r '.cores') are valid until ${date_valid_until} - ($days_remaining days remaining)"
      fi
    fi
  done
done
echo "Avi script done"

