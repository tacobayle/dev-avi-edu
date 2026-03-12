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
# get tenants
#
avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/tenant?page_size=-1"
tenant_results=$(echo $response_body | jq -c -r '.results')
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
    for i in {1..4}; do
      #
      #
      #
      json_data='
      {
        "cloud_ref": "https://sa-avicon-01.vclass.local/api/cloud/'${nsx_cloud_uuid}'",
        "dns_info": [
          {
            "algorithm": "DNS_RECORD_RESPONSE_CONSISTENT_HASH",
            "fqdn": "webapp-'${i}'.sa.vclass.local",
            "ttl": 30,
            "type": "DNS_RECORD_A"
          }
        ],
        "name": "webapp-VsVip-'${i}'",
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
      #
      #
      json_data='
      {
        "cloud_ref": "https://sa-avicon-01.vclass.local/api/cloud/'${nsx_cloud_uuid}'",
        "default_server_port": 30001,
        "enabled": true,
        "name": "webapp-pool-'${i}'",
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
      #
      #
      if (( i % 2 == 0 )); then
        json_data='
        {
          "cloud_ref": "https://sa-avicon-01.vclass.local/api/cloud/'${nsx_cloud_uuid}'",
          "name": "webapp-'${i}'",
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
              "duration": 30,
              "enabled": false
            },
            "significant_log_throttle": 10,
            "client_insights": "NO_INSIGHTS",
            "all_headers": true
          },
          "services": [{"port": 80, "enable_ssl": false}, {"port": 443, "enable_ssl": true}]
        }'
      else
        json_data='
        {
          "cloud_ref": "https://sa-avicon-01.vclass.local/api/cloud/'${nsx_cloud_uuid}'",
          "name": "webapp-'${i}'",
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
      fi
      avi_api 2 2 "POST" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "${json_data}" "${fqdn}" "api/virtualservice"
    done
    #
    # removing nsx-overlay-vs
    #
    avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "*" "${avi_version}" "" "${fqdn}" "api/virtualservice"
    while read vs
    do
      if [[ $(echo ${vs} | jq -c -r '.cloud_ref') == ${nsx_cloud_url} && $(echo ${vs} | jq -c -r '.name') == "nsx-overlay-vs" && $(echo ${vs} | jq -c -r '.type') != "VS_TYPE_VH_CHILD" ]]; then
        vs_uuid=$(echo ${vs} | jq -c -r '.uuid')
        item_tenant_uuid=$(echo ${vs} | jq -c -r '.tenant_ref' | grep / | cut -d/ -f6-)
        item_tenant_name=$(echo ${tenant_results} | jq -c -r --arg arg "${item_tenant_uuid}" '.[] | select( .uuid == $arg ) | .name')
        avi_api 2 2 "DELETE" "${avi_cookie_file}" "${csrftoken}" "${item_tenant_name}" "${avi_version}" "" "${fqdn}" "api/virtualservice/${vs_uuid}"
        vsvip_ref=$(echo ${vs} | jq -c -r '.vsvip_ref')
        vsvip_uuid=$(basename ${vsvip_ref})
        pool_ref=$(echo ${vs} | jq -c -r '.pool_ref')
        pool_uuid=$(basename ${pool_ref})
        avi_api 2 2 "DELETE" "${avi_cookie_file}" "${csrftoken}" "${item_tenant_name}" "${avi_version}" "" "${fqdn}" "api/vsvip/${vsvip_uuid}"
        avi_api 2 2 "DELETE" "${avi_cookie_file}" "${csrftoken}" "${item_tenant_name}" "${avi_version}" "" "${fqdn}" "api/pool/${pool_uuid}"
        break
      fi
    done < <(echo "${response_body}" | jq -c -r .results[])
  fi
done
sleep 10
sshpass -p "VMware1!" ssh -o StrictHostKeyChecking=no aviadmin@172.20.10.131 "ab -n 800000 -c 1000 https://webapp-2.sa.vclass.local:443/"