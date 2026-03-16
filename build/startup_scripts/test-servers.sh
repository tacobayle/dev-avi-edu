#!/bin/bash
#
sleep 1800
ips='["192.168.130.10","192.168.130.11","192.168.130.12","192.168.131.10","192.168.131.11","192.168.131.12"]'
ports='["30001"]'
webhook_url='https://chat.googleapis.com/v1/spaces/AAQA4IHsZ3w/messages?key=AIzaSyDdI0hCZtE6vySjMm-WEfRq3CPzqKqqsHI&token=HxKJ-xNo0aRoy6mOIRrPZRizlqgNZz8nCgAFv_LixEA'
vApp_type="ANS PCT EDU training"
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
# Servers HTTP check
#
echo $ips | jq -c -r .[] | while read ip
do
  echo $ports | jq -c -r .[] | while read port
  do
    if $(curl --output /dev/null --silent --head http://${ip}:${port}); then
      echo "http://${ip}:${port} was reachable"
    else
      echo "http://${ip}:${port} was NOT reachable"
      message="${vApp_type}: http://${ip}:${port} was NOT reachable"
      send_google_chat_message "$webhook_url" "${message}"
    fi
  done
  sleep 1
done