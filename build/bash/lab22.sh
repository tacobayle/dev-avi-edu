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
ssl_config='
{
  "openssl": {
    "directory": "/root",
    "ca": {
      "name": "My-Root-CA",
      "cn": "My Root CA",
      "c": "US",
      "st": "California",
      "l": "San Fransisco",
      "org": "Broadcom"
    },
    "app_certificate": {
      "name": "auth_app_cert",
      "cn": "My Auth App",
      "c": "US",
      "st": "California",
      "l": "San Fransisco",
      "org": "Broadcom",
      "days": 30
    }
  }
}'
directory=$(echo ${ssl_config} | jq -c -r '.openssl.directory')
ca_name=$(echo ${ssl_config} | jq -c -r '.openssl.ca.name')
CN=$(echo ${ssl_config} | jq -c -r '.openssl.ca.cn')
C=$(echo ${ssl_config} | jq -c -r '.openssl.ca.c')
ST=$(echo ${ssl_config} | jq -c -r '.openssl.ca.st')
L=$(echo ${ssl_config} | jq -c -r '.openssl.ca.l')
O=$(echo ${ssl_config} | jq -c -r '.openssl.ca.org')
key_size=4096
ca_cert_days=1826
ca_private_key_passphrase=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 12)
echo ${ca_private_key_passphrase} | tee ${directory}/ca_private_key_passphrase.txt
openssl genrsa -aes256 -passout pass:${ca_private_key_passphrase} -out ${directory}/${ca_name}.key ${key_size}
openssl pkcs8 -topk8 -inform PEM -outform PEM -nocrypt -passin pass:${ca_private_key_passphrase} -in ${directory}/${ca_name}.key -out ${directory}/${ca_name}.pkcs8.key
openssl req -x509 -new -nodes -passin pass:${ca_private_key_passphrase} -key ${directory}/${ca_name}.key -sha256 -days ${ca_cert_days} -out ${directory}/${ca_name}.crt -subj "/CN=${CN}/C=${C}/ST=${ST}/L=${L}/O=${O}" >/dev/null 2>&1
#
#
#
cert_name=$(echo ${ssl_config} | jq -c -r '.openssl.app_certificate.name')
cn=$(echo ${ssl_config} | jq -c -r '.openssl.app_certificate.cn')
c=$(echo ${ssl_config} | jq -c -r '.openssl.app_certificate.c')
st=$(echo ${ssl_config} | jq -c -r '.openssl.app_certificate.st')
l=$(echo ${ssl_config} | jq -c -r '.openssl.app_certificate.l')
org=$(echo ${ssl_config} | jq -c -r '.openssl.app_certificate.org')
cert_days=$(echo ${ssl_config} | jq -c -r '.openssl.app_certificate.days')
rm -f ${directory}/${cert_name}.csr ${directory}/${cert_name}.key ${directory}/${cert_name}.crt
openssl req -new -nodes -out ${directory}/${cert_name}.csr -newkey rsa:4096 -keyout ${directory}/${cert_name}.key -subj "/CN=${cn}/C=${c}/ST=${st}/L=${l}/O=${org}" >/dev/null 2>&1
openssl x509 -req -in ${directory}/${cert_name}.csr -CA ${directory}/${ca_name}.crt -passin pass:${ca_private_key_passphrase} -CAkey ${directory}/${ca_name}.key -CAcreateserial -out ${directory}/${cert_name}.crt -days ${cert_days} -sha256 >/dev/null 2>&1
sshpass -p "VMware1!" scp -o StrictHostKeyChecking=no ${directory}/${cert_name}.key aviadmin@172.20.10.131:/home/aviadmin/${cert_name}.key
sshpass -p "VMware1!" scp -o StrictHostKeyChecking=no ${directory}/${cert_name}.crt aviadmin@172.20.10.131:/home/aviadmin/${cert_name}.crt
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
    #
    #
    json_data='
    {
      "certificate": {
        "certificate": "'$(awk '{printf "%s\\n", $0}' ${directory}/${ca_name}.crt)'"
      },
      "import_key_to_hsm": false,
      "is_federated": false,
      "type": "SSL_CERTIFICATE_TYPE_CA",
      "name": "'${CN}'"
    }'
    avi_api 2 2 "POST" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "${json_data}" "${fqdn}" "api/sslkeyandcertificate"
    #
    #
    #
    json_data='
    {
      "ca_certs": [
        {
          "certificate": "'$(awk '{printf "%s\\n", $0}' ${directory}/${ca_name}.crt)'"
        }
      ],
      "crl_check": false,
      "ignore_peer_chain": false,
      "is_federated": false,
      "name": "my-pki-profile",
      "validate_only_leaf_crl": false
    }'
    avi_api 2 2 "POST" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "${json_data}" "${fqdn}" "api/pkiprofile"
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
        "max_header_count": 256,
        "max_keepalive_requests": 100,
        "max_response_headers_size": 48,
        "max_rps_cip": 0,
        "max_rps_cip_uri": 0,
        "max_rps_unknown_cip": 0,
        "max_rps_unknown_uri": 0,
        "max_rps_uri": 0,
        "pass_through_x_accel_headers": false,
        "pki_profile_ref": "api/pkiprofile/?name=my-pki-profile",
        "post_accept_timeout": 30000,
        "reset_conn_http_on_ssl_port": false,
        "respond_with_100_continue": true,
        "secure_cookie_enabled": false,
        "server_side_redirect_to_https": false,
        "ssl_client_certificate_mode": "SSL_CLIENT_CERTIFICATE_REQUIRE",
        "use_app_keepalive_timeout": false,
        "use_true_client_ip": false,
        "websockets_enabled": true,
        "x_forwarded_proto_enabled": false,
        "xff_alternate_name": "X-Forwarded-For",
        "xff_enabled": true,
        "xff_update": "REPLACE_XFF_HEADERS"
      },
      "name": "my-application-profile-mtls",
      "preserve_client_ip": false,
      "preserve_dest_ip_port": false,
      "type": "APPLICATION_PROFILE_TYPE_HTTP"
    }'
    avi_api 2 2 "POST" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "${json_data}" "${fqdn}" "api/applicationprofile"
    applicationprofile_url=$(echo ${response_body} | jq -c -r '.url')
    #
    #
    #
    json_data='
    {
      "cloud_ref": "https://sa-avicon-01.vclass.local/api/cloud/'${nsx_cloud_uuid}'",
      "dns_info": [
        {
          "algorithm": "DNS_RECORD_RESPONSE_CONSISTENT_HASH",
          "fqdn": "webapp-mtls.sa.vclass.local",
          "ttl": 30,
          "type": "DNS_RECORD_A"
        }
      ],
      "name": "webapp-mtls-VsVip",
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
      "name": "webapp-mtls-pool",
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
    json_data='
    {
      "cloud_ref": "https://sa-avicon-01.vclass.local/api/cloud/'${nsx_cloud_uuid}'",
      "name": "webapp-mtls",
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