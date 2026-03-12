#!/bin/bash
#
webhook_url='https://chat.googleapis.com/v1/spaces/AAQA4IHsZ3w/messages?key=AIzaSyDdI0hCZtE6vySjMm-WEfRq3CPzqKqqsHI&token=HxKJ-xNo0aRoy6mOIRrPZRizlqgNZz8nCgAFv_LixEA'
vApp_type="ANS ICM EDU training"
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
# VRA restart
#
if $(curl --output /dev/null --silent --head -k https://sa-vra-01.vclass.local); then
  echo "https://sa-vra-01.vclass.local was reachable"
  exit
else
  echo "https://sa-vra-01.vclass.local was not reachable"
  sleep 1800
  sshpass -p "VMware1!" ssh -o StrictHostKeyChecking=no "root@sa-vra-01.vclass.local" -q "/opt/scripts/deploy.sh"
fi
sleep 300
if $(curl --output /dev/null --silent --head -k https://sa-vra-01.vclass.local); then
  echo "https://sa-vra-01.vclass.local was reachable"
  exit
else
  echo "https://sa-vra-01.vclass.local was not reachable"
  message="${vApp_type}: https://sa-vra-01.vclass.local was not reachable"
  send_google_chat_message "$webhook_url" "${message}"
fi

