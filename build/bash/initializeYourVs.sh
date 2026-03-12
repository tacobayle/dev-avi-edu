#!/bin/bash
source /build/avi/avi_api.sh
#
# Removing vCenter content library
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
# removing vmware or blue or green username
#
users='["vmware", "blue", "green"]'
echo ${users} | jq -c -r .[] | while read user
do
  avi_api 2 1 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/user/?name=${user}"
  user_uuid=$(echo ${response_body} | jq -c -r '.results[0].uuid')
  if [[ ${user_uuid} != "null" ]]; then
    avi_api 2 2 "DELETE" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/user/${user_uuid}"
  fi
done
#
# removing eventually role "role-blue" or "role-green"
#
avi_api 2 1 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/role"
echo ${response_body} | jq -c -r .results[] | while read item
do
  if [[ $(echo ${item} | jq -c -r '.name') == "role-blue" || $(echo ${item} | jq -c -r '.name') == "role-green" ]]; then
    role_uuid=$(echo ${item} | jq -c -r '.uuid')
    avi_api 2 2 "DELETE" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/role/${role_uuid}"
  fi
done
#
# get tenants
#
avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/tenant?page_size=-1"
tenant_results=$(echo $response_body | jq -c -r '.results')
#
# get scheduler
#
avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/scheduler?page_size=-1"
echo ${response_body} | jq -c -r .results[] | while read item
do
  if [[ $(echo ${item} | jq -c -r '.name') == "Scheduler-ControlScript" ]]; then
    scheduler_uuid=$(echo ${item} | jq -c -r '.uuid')
    avi_api 2 2 "DELETE" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/scheduler/${scheduler_uuid}"
  fi
done
#
# update nsx cloud with state_based_dns_registration = false
#
avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/cloud"
echo ${response_body} | jq -c -r .results[] | while read item
do
  if [[ $(echo ${item} | jq -c -r '.vtype') == "CLOUD_NSXT" ]]; then
    nsx_cloud_uuid=$(echo ${item} | jq -c -r '.uuid')
    nsx_cloud_name=$(echo ${item} | jq -c -r '.name')
    nsx_cloud_url=$(echo ${item} | jq -c -r '.url')
    nsx_cloud_obj_name_prefix=$(echo ${item} | jq -c -r '.obj_name_prefix' | sed "s/-/_/g")
    if [[ $(echo ${item} | jq -c -r '.state_based_dns_registration') == "true" ]]; then
      json_data=$(echo ${item} | jq -c -r '. += {"state_based_dns_registration": false}')
      avi_api 2 2 "PUT" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "${json_data}" "${fqdn}" "api/cloud/${nsx_cloud_uuid}"
      sleep 5
      count=1
      response_body=""
      until [[ $(echo ${response_body} | jq -c -r '.results[0].status.se_image_state[0].state') == "IMG_GEN_COMPLETE" && $(echo ${response_body} | jq -c -r '.results[0].status.state') == "CLOUD_STATE_PLACEMENT_READY" ]]
      do
        avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/cloud-inventory/?name=${nsx_cloud_name}"
        sleep 10
        count=$((count+1))
          if [[ "${count}" -eq 30 ]]; then
            echo exit 1
          fi
      done
    fi
    #
    # if amount of VS is higher than 19 then delete the first VS which is not a child VS, identify the vip and remove all the other VSs that are using this vip, then delete the vip
    #
    avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "*" "${avi_version}" "" "${fqdn}" "api/virtualservice"
    if [[ $(echo ${response_body} | jq -c -r '.results | length') -gt 19 ]]; then
      while read vs
      do
        if [[ $(echo ${vs} | jq -c -r '.cloud_ref') == ${nsx_cloud_url} && $(echo ${vs} | jq -c -r '.type') != "VS_TYPE_VH_CHILD" ]]; then
          vs_uuid=$(echo ${vs} | jq -c -r '.uuid')
          item_tenant_uuid=$(echo ${vs} | jq -c -r '.tenant_ref' | grep / | cut -d/ -f6-)
          item_tenant_name=$(echo ${tenant_results} | jq -c -r --arg arg "${item_tenant_uuid}" '.[] | select( .uuid == $arg ) | .name')
          avi_api 2 2 "DELETE" "${avi_cookie_file}" "${csrftoken}" "${item_tenant_name}" "${avi_version}" "" "${fqdn}" "api/virtualservice/${vs_uuid}"
          vsvip_ref=$(echo ${vs} | jq -c -r '.vsvip_ref')
          vsvip_uuid=$(basename ${vsvip_ref})
          break
        fi
      done < <(echo "${response_body}" | jq -c -r .results[])
      #
      avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "*" "${avi_version}" "" "${fqdn}" "api/virtualservice"
      echo ${response_body} | jq -c -r .results[] | while read vs
      do
        if [[ $(echo ${vs} | jq -c -r '.cloud_ref') == ${nsx_cloud_url} && $(echo ${vs} | jq -c -r '.type') != "VS_TYPE_VH_CHILD" && $(echo ${vs} | jq -c -r '.vsvip_ref') == "${vsvip_ref}" ]]; then
          vs_uuid=$(echo ${vs} | jq -c -r '.uuid')
          item_tenant_uuid=$(echo ${vs} | jq -c -r '.tenant_ref' | grep / | cut -d/ -f6-)
          item_tenant_name=$(echo ${tenant_results} | jq -c -r --arg arg "${item_tenant_uuid}" '.[] | select( .uuid == $arg ) | .name')
          avi_api 2 2 "DELETE" "${avi_cookie_file}" "${csrftoken}" "${item_tenant_name}" "${avi_version}" "" "${fqdn}" "api/virtualservice/${vs_uuid}"
        fi
      done
      #
      avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "*" "${avi_version}" "" "${fqdn}" "api/vsvip"
      echo ${response_body} | jq -c -r .results[] | while read vsvip
      do
        if [[ $(echo ${vsvip} | jq -c -r '.cloud_ref') == ${nsx_cloud_url} && $(echo ${vsvip} | jq -c -r '.uuid') == "${vsvip_uuid}" ]]; then
          vsvip_uuid=$(echo ${vsvip} | jq -c -r '.uuid')
          item_tenant_uuid=$(echo ${vsvip} | jq -c -r '.tenant_ref' | grep / | cut -d/ -f6-)
          item_tenant_name=$(echo ${tenant_results} | jq -c -r --arg arg "${item_tenant_uuid}" '.[] | select( .uuid == $arg ) | .name')
          avi_api 2 2 "DELETE" "${avi_cookie_file}" "${csrftoken}" "${item_tenant_name}" "${avi_version}" "" "${fqdn}" "api/vsvip/${vsvip_uuid}"
          break
        fi
      done
    fi
    #
    # Creating a dummy vip
    #
    rm -f /tmp/dummy.log
    avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "*" "${avi_version}" "" "${fqdn}" "api/vsvip"
    echo ${response_body} | jq -c -r .results[] | while read vsvip
    do
      item_tenant_uuid=$(echo ${vsvip} | jq -c -r '.tenant_ref' | grep / | cut -d/ -f6-)
      item_tenant_name=$(echo ${tenant_results} | jq -c -r --arg arg "${item_tenant_uuid}" '.[] | select( .uuid == $arg ) | .name')
      if [[ $(echo ${vsvip} | jq -c -r '.cloud_ref') == ${nsx_cloud_url} && $(echo ${vsvip} | jq -c -r '.name') == "dummy-VsVip" && ${item_tenant_name} == "admin" ]]; then
        touch /tmp/dummy.log
      fi
    done
    if [ ! -f "/tmp/dummy.log" ]; then
      json_data='
      {
        "cloud_ref": "'${nsx_cloud_url}'",
        "dns_info": [
          {
            "algorithm": "DNS_RECORD_RESPONSE_CONSISTENT_HASH",
            "fqdn": "dummy.sa.vclass.local",
            "ttl": 30,
            "type": "DNS_RECORD_A"
          }
        ],
        "name": "dummy-VsVip",
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
    fi
    #
    # Creating a dummy vs
    #
    rm -f /tmp/dummy.log
    avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "*" "${avi_version}" "" "${fqdn}" "api/virtualservice"
    echo ${response_body} | jq -c -r .results[] | while read vs
    do
      item_tenant_uuid=$(echo ${vs} | jq -c -r '.tenant_ref' | grep / | cut -d/ -f6-)
      item_tenant_name=$(echo ${tenant_results} | jq -c -r --arg arg "${item_tenant_uuid}" '.[] | select( .uuid == $arg ) | .name')
      if [[ $(echo ${vs} | jq -c -r '.cloud_ref') == ${nsx_cloud_url} && $(echo ${vs} | jq -c -r '.name') == "dummy-vs" && ${item_tenant_name} == "admin" ]]; then
        touch /tmp/dummy.log
      fi
    done
    if [ ! -f "/tmp/dummy.log" ]; then
      json_data='
      {
        "cloud_ref": "'${nsx_cloud_url}'",
        "name": "dummy-vs",
        "vsvip_ref": "'${vsvip_url}'",
        "application_profile_ref": "/api/applicationprofile/?name=System-DNS",
        "network_profile_ref": "/api/networkprofile/?name=System-UDP-Per-Pkt",
        "services": [{"port": 53, "enable_ssl": false}]
      }'
      avi_api 2 2 "POST" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "${json_data}" "${fqdn}" "api/virtualservice"
      sleep 5
    fi
    #
    # identifying default SEG uuid
    #
    rm -f /tmp/default_seg_uuid
    avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "*" "${avi_version}" "" "${fqdn}" "api/serviceenginegroup"
    echo ${response_body} | jq -c -r .results[] | while read seg
    do
      serviceneginegroup_uuid=$(echo ${seg} | jq -c -r '.uuid')
      if [[ $(echo ${seg} | jq -c -r '.cloud_ref') == ${nsx_cloud_url} ]]; then
        item_tenant_uuid=$(echo ${seg} | jq -c -r '.tenant_ref' | grep / | cut -d/ -f6-)
        item_tenant_name=$(echo ${tenant_results} | jq -c -r --arg arg "${item_tenant_uuid}" '.[] | select( .uuid == $arg ) | .name')
	      if [[ $(echo ${seg} | jq -c -r '.name') == "Default-Group" && ${item_tenant_name} == "admin" ]]; then
          echo ${seg} | jq -c -r '.uuid' | tee /tmp/default_seg_uuid
	      fi
      fi
    done
    #
    # Removing all the VS of cloud NSX-T except the dummy vs
    #
    avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "*" "${avi_version}" "" "${fqdn}" "api/virtualservice"
    echo ${response_body} | jq -c -r .results[] | while read vs
    do
      if [[ $(echo ${vs} | jq -c -r '.cloud_ref') == ${nsx_cloud_url} && $(echo ${vs} | jq -c -r '.type') == "VS_TYPE_VH_CHILD" ]]; then
        vs_uuid=$(echo ${vs} | jq -c -r '.uuid')
        item_tenant_uuid=$(echo ${vs} | jq -c -r '.tenant_ref' | grep / | cut -d/ -f6-)
        item_tenant_name=$(echo ${tenant_results} | jq -c -r --arg arg "${item_tenant_uuid}" '.[] | select( .uuid == $arg ) | .name')
	      avi_api 2 2 "DELETE" "${avi_cookie_file}" "${csrftoken}" "${item_tenant_name}" "${avi_version}" "" "${fqdn}" "api/virtualservice/${vs_uuid}"
      fi
    done
    avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "*" "${avi_version}" "" "${fqdn}" "api/virtualservice"
    echo ${response_body} | jq -c -r .results[] | while read vs
    do
      if [[ $(echo ${vs} | jq -c -r '.cloud_ref') == ${nsx_cloud_url} && $(echo ${vs} | jq -c -r '.name') != "dummy-vs" ]]; then
        vs_uuid=$(echo ${vs} | jq -c -r '.uuid')
        item_tenant_uuid=$(echo ${vs} | jq -c -r '.tenant_ref' | grep / | cut -d/ -f6-)
        item_tenant_name=$(echo ${tenant_results} | jq -c -r --arg arg "${item_tenant_uuid}" '.[] | select( .uuid == $arg ) | .name')
	      avi_api 2 2 "DELETE" "${avi_cookie_file}" "${csrftoken}" "${item_tenant_name}" "${avi_version}" "" "${fqdn}" "api/virtualservice/${vs_uuid}"
      fi
    done
    #
    # Removing all the vsvip of cloud NSX-T except the dummy vs-vip
    #
    avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "*" "${avi_version}" "" "${fqdn}" "api/vsvip"
    echo ${response_body} | jq -c -r .results[] | while read vsvip
    do
      if [[ $(echo ${vsvip} | jq -c -r '.cloud_ref') == ${nsx_cloud_url} && $(echo ${vsvip} | jq -c -r '.name') != "dummy-VsVip" ]]; then
        vsvip_uuid=$(echo ${vsvip} | jq -c -r '.uuid')
        item_tenant_uuid=$(echo ${vsvip} | jq -c -r '.tenant_ref' | grep / | cut -d/ -f6-)
        item_tenant_name=$(echo ${tenant_results} | jq -c -r --arg arg "${item_tenant_uuid}" '.[] | select( .uuid == $arg ) | .name')
	      avi_api 2 2 "DELETE" "${avi_cookie_file}" "${csrftoken}" "${item_tenant_name}" "${avi_version}" "" "${fqdn}" "api/vsvip/${vsvip_uuid}"
      fi
    done
    #
    # Removing all the pool of cloud NSX-T
    #
    avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "*" "${avi_version}" "" "${fqdn}" "api/pool"
    echo ${response_body} | jq -c -r .results[] | while read pool
    do
      if [[ $(echo ${pool} | jq -c -r '.cloud_ref') == ${nsx_cloud_url} ]]; then
        pool_uuid=$(echo ${pool} | jq -c -r '.uuid')
        item_tenant_uuid=$(echo ${pool} | jq -c -r '.tenant_ref' | grep / | cut -d/ -f6-)
        item_tenant_name=$(echo ${tenant_results} | jq -c -r --arg arg "${item_tenant_uuid}" '.[] | select( .uuid == $arg ) | .name')
        avi_api 2 2 "DELETE" "${avi_cookie_file}" "${csrftoken}" "${item_tenant_name}" "${avi_version}" "" "${fqdn}" "api/pool/${pool_uuid}"
      fi
    done
    #
    # Remove various App profile
    #
    avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/applicationprofile"
    echo ${response_body} | jq -c -r .results[] | while read applicationprofile
    do
      if [[ $(echo ${applicationprofile} | jq -c -r '.name') == "Web-App-HTTP-custom" || $(echo ${applicationprofile} | jq -c -r '.name') == "webapp-application-profile" || $(echo ${applicationprofile} | jq -c -r '.name') == "my-application-profile-mtls" ]]; then
        applicationprofile_uuid=$(echo ${applicationprofile} | jq -c -r '.uuid')
        avi_api 2 2 "DELETE" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/applicationprofile/${applicationprofile_uuid}"
      fi
    done
    #
    # Removing http policy set to avoid name conflict
    #
    avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/httppolicyset"
    echo ${response_body} | jq -c -r .results[] | while read http_set
    do
      if [[ $(echo ${http_set} | jq -c -r '.name') == "webapp-policy" ]]; then
        http_set_uuid=$(echo ${http_set} | jq -c -r '.uuid')
        avi_api 2 2 "DELETE" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/httppolicyset/${http_set_uuid}"
      fi
    done
    #
    # Keeping only the service engine with the dummy VS
    #
    avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "*" "${avi_version}" "" "${fqdn}" "api/serviceengine-inventory/?cloud_ref.uuid=${nsx_cloud_uuid}"
    echo ${response_body} | jq -c -r .results[] | while read se
    do
      if [[ $(echo ${se} | jq -c -r '.config.virtualservice_refs | length') ==  0 ]]; then
        se_uuid=$(echo ${se} | jq -c -r '.config.uuid')
        item_tenant_uuid=$(echo ${se} | jq -c -r '.config.tenant_ref' | grep / | cut -d/ -f6-)
        item_tenant_name=$(echo ${tenant_results} | jq -c -r --arg arg "${item_tenant_uuid}" '.[] | select( .uuid == $arg ) | .name')
        avi_api 2 2 "DELETE" "${avi_cookie_file}" "${csrftoken}" "${item_tenant_name}" "${avi_version}" "" "${fqdn}" "api/serviceengine/${se_uuid}"
      fi
    done
    #
    # Remove network service
    #
    avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "*" "${avi_version}" "" "${fqdn}" "api/networkservice"
    echo ${response_body} | jq -c -r .results[] | while read netsvc
    do
      netsvc_uuid=$(echo ${netsvc} | jq -c -r '.uuid')
      item_tenant_uuid=$(echo ${netsvc} | jq -c -r '.tenant_ref' | grep / | cut -d/ -f6-)
      item_tenant_name=$(echo ${tenant_results} | jq -c -r --arg arg "${item_tenant_uuid}" '.[] | select( .uuid == $arg ) | .name')
      avi_api 2 2 "DELETE" "${avi_cookie_file}" "${csrftoken}" "${item_tenant_name}" "${avi_version}" "" "${fqdn}" "api/networkservice/${netsvc_uuid}"
    done
    #
    # Rollback to default SEG config (sizing and HA_MODE) and removed other SEGs
    #
    avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "*" "${avi_version}" "" "${fqdn}" "api/serviceenginegroup"
    echo ${response_body} | jq -c -r .results[] | while read seg
    do
      serviceneginegroup_uuid=$(echo ${seg} | jq -c -r '.uuid')
      item_tenant_uuid=$(echo ${seg} | jq -c -r '.tenant_ref' | grep / | cut -d/ -f6-)
      item_tenant_name=$(echo ${tenant_results} | jq -c -r --arg arg "${item_tenant_uuid}" '.[] | select( .uuid == $arg ) | .name')
      if [[ $(echo ${seg} | jq -c -r '.cloud_ref') == ${nsx_cloud_url} && $(echo ${seg} | jq -c -r '.name') == "Default-Group" && ${item_tenant_name} == "admin" ]]; then
        json_data=$(echo ${seg} | jq -c -r '.+={"cpu_reserve": false, "mem_reserve": false, "se_deprovision_delay": 120, "buffer_se": 0, "min_scaleout_per_vs": 2, "algo": "PLACEMENT_ALGO_PACKED", "ha_mode": "HA_MODE_SHARED_PAIR", "vcpus_per_se": 1, "memory_per_se": 2048, "disk_per_se": 15, "realtime_se_metrics": {"duration": 30, "enable": false}}')
	      avi_api 2 2 "PUT" "${avi_cookie_file}" "${csrftoken}" "${item_tenant_name}" "${avi_version}" "${json_data}" "${fqdn}" "api/serviceenginegroup/${serviceneginegroup_uuid}"
      fi
      if [[ $(echo ${seg} | jq -c -r '.cloud_ref') == ${nsx_cloud_url} && $(echo ${seg} | jq -c -r '.name') != "Default-Group" ]]; then
	      avi_api 2 2 "DELETE" "${avi_cookie_file}" "${csrftoken}" "${item_tenant_name}" "${avi_version}" "" "${fqdn}" "api/serviceenginegroup/${serviceneginegroup_uuid}"
      fi
    done
    #
    # Rollback to default network Mgmt pool
    #
    avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/network"
    echo ${response_body} | jq -c -r .results[] | while read network
    do
      if [[ $(echo ${network} | jq -c -r '.name') == "SA-Overlay-Mgmt" && $(echo ${network} | jq -c -r '.cloud_ref') == ${nsx_cloud_url} ]]; then
        network_uuid=$(echo ${network} | jq -c -r '.uuid')
        json_data=$(echo ${network} | jq -c -r '.')
        json_data=$(echo ${json_data} | jq -c -r '.configured_subnets[0].static_ip_ranges[0].range.end = {"addr": "21.0.0.120", "type": "V4"}')
        avi_api 2 2 "PUT" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "${json_data}" "${fqdn}" "api/network/${network_uuid}"
      fi
    done
    #
    # Recreating nsx-overlay-vs-vip
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
      "name": "nsx-overlay-vs-VsVip",
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
      "name": "nsx-overlay-vs-pool",
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
      "name": "nsx-overlay-vs",
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
    #
    # Removing the dummy vs
    #
    avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "*" "${avi_version}" "" "${fqdn}" "api/virtualservice"
    echo ${response_body} | jq -c -r .results[] | while read vs
    do
      if [[ $(echo ${vs} | jq -c -r '.cloud_ref') == ${nsx_cloud_url} && $(echo ${vs} | jq -c -r '.name') == "dummy-vs" ]]; then
        vs_uuid=$(echo ${vs} | jq -c -r '.uuid')
        item_tenant_uuid=$(echo ${vs} | jq -c -r '.tenant_ref' | grep / | cut -d/ -f6-)
        item_tenant_name=$(echo ${tenant_results} | jq -c -r --arg arg "${item_tenant_uuid}" '.[] | select( .uuid == $arg ) | .name')
	      avi_api 2 2 "DELETE" "${avi_cookie_file}" "${csrftoken}" "${item_tenant_name}" "${avi_version}" "" "${fqdn}" "api/virtualservice/${vs_uuid}"
      fi
    done
    #
    # Removing all the dummy vs-vip
    #
    avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "*" "${avi_version}" "" "${fqdn}" "api/vsvip"
    echo ${response_body} | jq -c -r .results[] | while read vsvip
    do
      if [[ $(echo ${vsvip} | jq -c -r '.cloud_ref') == ${nsx_cloud_url} && $(echo ${vsvip} | jq -c -r '.name') == "dummy-VsVip" ]]; then
        vsvip_uuid=$(echo ${vsvip} | jq -c -r '.uuid')
        item_tenant_uuid=$(echo ${vsvip} | jq -c -r '.tenant_ref' | grep / | cut -d/ -f6-)
        item_tenant_name=$(echo ${tenant_results} | jq -c -r --arg arg "${item_tenant_uuid}" '.[] | select( .uuid == $arg ) | .name')
	      avi_api 2 2 "DELETE" "${avi_cookie_file}" "${csrftoken}" "${item_tenant_name}" "${avi_version}" "" "${fqdn}" "api/vsvip/${vsvip_uuid}"
      fi
    done
  fi
done
#
# removing cert and key
#
sshpass -p "VMware1!" ssh -o StrictHostKeyChecking=no aviadmin@172.20.10.131 "rm -f /home/aviadmin/auth_app_cert.key"
sshpass -p "VMware1!" ssh -o StrictHostKeyChecking=no aviadmin@172.20.10.131 "rm -f /home/aviadmin/auth_app_cert.crt"
#
# removing certificate my-pki-profile
#
avi_api 2 1 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/pkiprofile"
echo ${response_body} | jq -c -r .results[] | while read item
do
  if [[ $(echo ${item} | jq -c -r '.name') == "my-pki-profile" ]]; then
    pki_uuid=$(echo ${item} | jq -c -r '.uuid')
    avi_api 2 2 "DELETE" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/pkiprofile/${pki_uuid}"
  fi
done
#
# removing certificate My-Root-CA
#
avi_api 2 1 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/sslkeyandcertificate"
echo ${response_body} | jq -c -r .results[] | while read item
do
  if [[ $(echo ${item} | jq -c -r '.name') == "My Root CA" ]]; then
    sslkeyandcertificate_uuid=$(echo ${item} | jq -c -r '.uuid')
    avi_api 2 2 "DELETE" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/sslkeyandcertificate/${sslkeyandcertificate_uuid}"
  fi
done
#
# removing control script
#
avi_api 2 1 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/alertscriptconfig/?name=force_disable_real_time_metrics"
cs_uuid=$(echo ${response_body} | jq -c -r .results[0].uuid)
if [[ ${cs_uuid} != "null" ]]; then
  avi_api 2 2 "DELETE" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/alertscriptconfig/${cs_uuid}"
fi
#
# removing hm
#
avi_api 2 1 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/healthmonitor/?name=my-custom-hm"
hm_uuid=$(echo ${response_body} | jq -c -r .results[0].uuid)
if [[ ${hm_uuid} != "null" ]]; then
  avi_api 2 2 "DELETE" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/healthmonitor/${hm_uuid}"
fi
#
# disable basic auth
#
avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/systemconfiguration"
json_data=$(echo ${response_body} | jq -c -r '.portal_configuration += {"allow_basic_authentication": false}')
avi_api 2 2 "PUT" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "${json_data}" "${fqdn}" "api/systemconfiguration"
#
# kill apache benchmark
#
sshpass -p "VMware1!" ssh -o StrictHostKeyChecking=no aviadmin@172.20.10.131 "kill $(ps -ef | grep -v ssh | grep -v grep | grep "ab -n" | awk '${print $2}')"