#!/bin/bash
source /build/avi/avi_api.sh
/bin/bash /build/bash/initializeYourVs.sh
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
# retrieve nsx cloud url and cloud uuid
#
avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/cloud"
echo ${response_body} | jq -c -r .results[] | while read item
do
  echo $(echo ${item} | jq -c -r '.vtype')
  if [[ $(echo ${item} | jq -c -r '.vtype') == "CLOUD_NSXT" ]]; then
    nsx_cloud_url=$(echo ${item} | jq -c -r '.url')
    nsx_cloud_uuid=$(echo ${item} | jq -c -r '.uuid')
    #
    # update seg to 20 vs
    #
    avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/serviceenginegroup"
    echo ${response_body} | jq -c -r .results[] | while read seg
    do
      serviceneginegroup_uuid=$(echo ${seg} | jq -c -r '.uuid')
      if [[ $(echo ${seg} | jq -c -r '.cloud_ref') == ${nsx_cloud_url} && $(echo ${seg} | jq -c -r '.name') == "Default-Group" ]]; then
        json_data=$(echo ${seg} | jq -c -r '.+={"max_vs_per_se": 20}')
	      avi_api 2 2 "PUT" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "${json_data}" "${fqdn}" "api/serviceenginegroup/${serviceneginegroup_uuid}"
      fi
    done
    for i in {1..20}; do
      #
      # Recreating nsx-overlay-vs-vip
      #
      json_data='
      {
        "cloud_ref": "https://sa-avicon-01.vclass.local/api/cloud/'${nsx_cloud_uuid}'",
        "dns_info": [
          {
            "algorithm": "DNS_RECORD_RESPONSE_CONSISTENT_HASH",
            "fqdn": "nsx-overlay-vs-'${i}'.sa.vclass.local",
            "ttl": 30,
            "type": "DNS_RECORD_A"
          }
        ],
        "name": "nsx-overlay-vs-VsVip-'${i}'",
        "vip": [
          {
            "auto_allocate_ip": true,
            "ipam_network_subnet": {
              "network_ref": "/api/network/?name=SA-Overlay-VIP",
              "subnet": {
                "ip_addr": {
                  "addr": "22.0.0.0",
                  "type": "V4"
                },
                "mask": 24
              }
            }
          }
        ],
        "vrf_context_ref": "/api/vrfcontext/?name=SA-T1"
      }'
      avi_api 2 2 "POST" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "${json_data}" "${fqdn}" "api/vsvip"
      vsvip_url=$(echo ${response_body} | jq -c -r '.url')
      #
      # Recreating pool for nsx-overlay-vs
      #
      json_data='
      {
        "cloud_ref": "https://sa-avicon-01.vclass.local/api/cloud/'${nsx_cloud_uuid}'",
        "default_server_port": 30001,
        "enabled": true,
        "name": "nsx-overlay-vs-pool-'${i}'",
        "health_monitor_refs": ["/api/healthmonitor?name=System-HTTP"],
        "servers": [
          {
            "enabled": true,
            "hostname": "sa-server-01",
            "ip": {
              "addr": "192.168.130.10",
              "type": "V4"
            }
          },
          {
            "enabled": true,
            "hostname": "sa-server-02",
            "ip": {
              "addr": "192.168.130.11",
              "type": "V4"
            }
          },
          {
            "enabled": true,
            "hostname": "sa-server-03",
            "ip": {
              "addr": "192.168.130.12",
              "type": "V4"
            }
          }
        ],
        "vrf_ref": "/api/vrfcontext/?name=SA-T1"
      }'
      avi_api 2 2 "POST" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "${json_data}" "${fqdn}" "api/pool"
      pool_url=$(echo ${response_body} | jq -c -r '.url')
      #
      # Recreating the VS
      #
      json_data='
      {
        "cloud_ref": "https://sa-avicon-01.vclass.local/api/cloud/'${nsx_cloud_uuid}'",
        "name": "nsx-overlay-vs-'${i}'",
        "vsvip_ref": "'${vsvip_url}'",
        "pool_ref": "'${pool_url}'",
        "analytics_policy": {
          "udf_log_throttle": 10,
          "full_client_logs": {
            "duration": 0,
            "throttle": 10,
            "enabled": true
          },
          "metrics_realtime_update": {
            "duration": 0,
            "enabled": true
          },
          "significant_log_throttle": 10,
          "client_insights": "NO_INSIGHTS",
          "all_headers": true
        },
        "services": [{"port": 80, "enable_ssl": false}, {"port": 443, "enable_ssl": true}]
      }'
      avi_api 2 2 "POST" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "${json_data}" "${fqdn}" "api/virtualservice"
    done
  fi
done