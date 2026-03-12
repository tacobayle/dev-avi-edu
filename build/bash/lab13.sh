#!/bin/bash
source /build/avi/avi_api.sh
/bin/bash /build/bash/initializeYourVs.sh
#
# GOVC variables
#
export GOVC_USERNAME='administrator@vsphere.local'
export GOVC_PASSWORD='VMware1!'
export GOVC_DATACENTER='SiteA-Production'
export GOVC_INSECURE=true
export GOVC_URL='sa-vcsa-01.vclass.local'
export GOVC_CLUSTER='[SiteA-Edge-Cluster-01]'
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
    # Retrieving the mgmt IP of the remaining SE
    #
    avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "*" "${avi_version}" "" "${fqdn}" "api/serviceengine-inventory/?cloud_ref.uuid=${nsx_cloud_uuid}"
    while read se
    do
      if [[ $(echo ${se} | jq -c -r '.config.virtualservice_refs | length') !=  0 ]]; then
        se_ip_mgmt=$(echo ${se} | jq -c -r '.config.mgmt_ip_address.addr')
        break
      fi
    done< <(echo ${response_body} | jq -c -r .results[])
    #
    # Update the network with a single IP for the management
    #
    avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/network"
    echo ${response_body} | jq -c -r .results[] | while read network
    do
      if [[ $(echo ${network} | jq -c -r '.name') == "SA-Overlay-Mgmt" && $(echo ${network} | jq -c -r '.cloud_ref') == ${nsx_cloud_url} ]]; then
        network_uuid=$(echo ${network} | jq -c -r '.uuid')
        json_data=$(echo ${network} | jq -c -r '.')
        json_data=$(echo ${json_data} | jq -c -r '.configured_subnets[0].static_ip_ranges[0].range.begin = {"addr": "'${se_ip_mgmt}'", "type": "V4"}')
        json_data=$(echo ${json_data} | jq -c -r '.configured_subnets[0].static_ip_ranges[0].range.end = {"addr": "'${se_ip_mgmt}'", "type": "V4"}')
        avi_api 2 2 "PUT" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "${json_data}" "${fqdn}" "api/network/${network_uuid}"
      fi
    done
    #
    # Created a new VS to scale-out - vsvip
    #
    json_data='
    {
      "cloud_ref": "https://sa-avicon-01.vclass.local/api/cloud/'${nsx_cloud_uuid}'",
      "dns_info": [
        {
          "algorithm": "DNS_RECORD_RESPONSE_CONSISTENT_HASH",
          "fqdn": "nsx-overlay-vs.sa.vclass.local",
          "ttl": 30,
          "type": "DNS_RECORD_A"
        }
      ],
      "name": "nsx-overlay-scaleout-VsVip",
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
    # Created a new VS to scale-out - pool
    #
    json_data='
    {
      "cloud_ref": "https://sa-avicon-01.vclass.local/api/cloud/'${nsx_cloud_uuid}'",
      "default_server_port": 30001,
      "enabled": true,
      "name": "nsx-overlay-scaleout-pool",
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
    # Created a new VS to scale-out - vs
    #
    json_data='
    {
      "cloud_ref": "https://sa-avicon-01.vclass.local/api/cloud/'${nsx_cloud_uuid}'",
      "name": "nsx-overlay-scaleout",
      "vsvip_ref": "'${vsvip_url}'",
      "pool_ref": "'${pool_url}'",
      "services": [{"port": 80, "enable_ssl": false}, {"port": 443, "enable_ssl": true}]
    }'
    avi_api 2 2 "POST" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "${json_data}" "${fqdn}" "api/virtualservice"
    vs_uuid=$(echo ${response_body} | jq -c -r '.uuid')
    sleep 8
    avi_api 2 2 "POST" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" '{"to_new_se": true, "vip_id": 0}' "${fqdn}" "api/virtualservice/${vs_uuid}/scaleout"
  fi
done