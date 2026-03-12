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
# u
#
avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/cloud"
echo ${response_body} | jq -c -r .results[] | while read item
do
  if [[ $(echo ${item} | jq -c -r '.vtype') == "CLOUD_NSXT" ]]; then
    nsx_cloud_uuid=$(echo ${item} | jq -c -r '.uuid')
    nsx_cloud_url=$(echo ${item} | jq -c -r '.url')
    #
    #
    #
    json_data='
    {
      "cloud_ref": "https://sa-avicon-01.vclass.local/api/cloud/'${nsx_cloud_uuid}'",
      "dns_info": [
        {
          "algorithm": "DNS_RECORD_RESPONSE_CONSISTENT_HASH",
          "fqdn": "webapp.sa.vclass.local",
          "ttl": 30,
          "type": "DNS_RECORD_A"
        }
      ],
      "name": "webapp-VsVip",
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
      "name": "webapp-pool",
      "servers": [
        {
          "enabled": true,
          "hostname": "sa-server-01",
          "ratio": 1,
          "ip": {
            "addr": "192.168.130.10",
            "type": "V4"
          }
        },
        {
          "enabled": true,
          "hostname": "sa-server-02",
          "ratio": 1,
          "ip": {
            "addr": "192.168.130.11",
            "type": "V4"
          }
        },
        {
          "enabled": true,
          "hostname": "sa-server-03",
          "ratio": 1,
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
    json_data='
    {
      "http_profile": {
        "allow_dots_in_header_name": false,
        "client_body_timeout": 30000,
        "client_header_timeout": 10000,
        "client_max_body_size": 0,
        "client_max_header_size": 12,
        "client_max_request_size": 48,
        "close_server_side_connection_on_error": false,
        "collect_client_tls_fingerprint": false,
        "connection_multiplexing_enabled": true,
        "detect_ntlm_app": true,
        "disable_keepalive_posts_msie6": true,
        "disable_sni_hostname_check": false,
        "enable_chunk_merge": true,
        "enable_fire_and_forget": false,
        "enable_request_body_buffering": false,
        "enable_request_body_metrics": false,
        "fwd_close_hdr_for_bound_connections": true,
        "hsts_enabled": false,
        "hsts_max_age": 365,
        "hsts_subdomains_enabled": true,
        "http2_profile": {
          "enable_http2_server_push": false,
          "http2_initial_window_size": 64,
          "max_http2_concurrent_pushes_per_connection": 10,
          "max_http2_concurrent_streams_per_connection": 128,
          "max_http2_control_frames_per_connection": 1000,
          "max_http2_empty_data_frames_per_connection": 1000,
          "max_http2_header_field_size": 4096,
          "max_http2_queued_frames_to_client_per_connection": 1000,
          "max_http2_requests_per_connection": 1000
        },
        "http_to_https": false,
        "http_upstream_buffer_size": 0,
        "httponly_enabled": false,
        "keepalive_header": false,
        "keepalive_timeout": 30000,
        "max_bad_rps_cip": 0,
        "max_bad_rps_cip_uri": 0,
        "max_bad_rps_uri": 0,
        "max_header_count": 2,
        "max_keepalive_requests": 100,
        "max_response_headers_size": 48,
        "max_rps_cip": 0,
        "max_rps_cip_uri": 0,
        "max_rps_unknown_cip": 0,
        "max_rps_unknown_uri": 0,
        "max_rps_uri": 0,
        "pass_through_x_accel_headers": false,
        "post_accept_timeout": 30000,
        "reset_conn_http_on_ssl_port": false,
        "respond_with_100_continue": true,
        "secure_cookie_enabled": false,
        "server_side_redirect_to_https": false,
        "ssl_client_certificate_mode": "SSL_CLIENT_CERTIFICATE_NONE",
        "use_app_keepalive_timeout": false,
        "use_true_client_ip": false,
        "websockets_enabled": true,
        "x_forwarded_proto_enabled": false,
        "xff_alternate_name": "X-Forwarded-For",
        "xff_enabled": true,
        "xff_update": "REPLACE_XFF_HEADERS"
      },
      "name": "Web-App-HTTP-custom",
      "preserve_client_ip": false,
      "preserve_dest_ip_port": false,
      "type": "APPLICATION_PROFILE_TYPE_HTTP"
    }'
    avi_api 2 2 "POST" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "${json_data}" "${fqdn}" "api/applicationprofile"
    applicationprofile_url=$(echo ${response_body} | jq -c -r '.url')
    #
    # Recreating the VS
    #
    json_data='
    {
      "cloud_ref": "https://sa-avicon-01.vclass.local/api/cloud/'${nsx_cloud_uuid}'",
      "name": "webapp",
      "vsvip_ref": "'${vsvip_url}'",
      "pool_ref": "'${pool_url}'",
      "application_profile_ref": "'${applicationprofile_url}'",
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
  fi
done