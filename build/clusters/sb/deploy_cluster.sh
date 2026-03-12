#!/bin/bash
#
ubuntu_ova_url="https://cloud-images.ubuntu.com/releases/noble/release/ubuntu-24.04-server-cloudimg-amd64.ova"
folder_app="backend"
/build/clusters/sb/download_file_from_url_to_location.sh "${ubuntu_ova_url}" "/root/$(basename ${ubuntu_ova_url})" "Ubuntu OVA"
export GOVC_USERNAME='administrator@vsphere.local'
export GOVC_PASSWORD='VMware1!'
export GOVC_DATACENTER='SiteB-Production'
export GOVC_DATASTORE='SB-Shared-02-Remote'
export GOVC_INSECURE=true
export GOVC_URL='sb-vcsa-01.vclass.local'
export GOVC_CLUSTER='SiteB-Compute-Cluster-01'
export GOVC_RESOURCE_POOL='SiteB-Compute-Cluster-01/Resources'
govc about
#
# destroy content library
#
govc library.rm cl-ubuntu
#
# destroy VMs
#
govc vm.destroy sb-server-01
govc vm.destroy sb-server-02
govc vm.destroy sb-server-03
#
# content library creation
#
govc library.create cl-ubuntu
govc library.import cl-ubuntu "/root/$(basename ${ubuntu_ova_url})"
#
# folder creation
#
list_folder=$(govc find -json . -type f)
echo "Creation of a folder for the Apps"
if $(echo ${list_folder} | jq -e '. | any(. == "./vm/'${folder_app}'")' >/dev/null ) ; then
  echo "WARNING: unable to create folder ${folder_app}: it already exists"
else
  govc folder.create /${GOVC_DATACENTER}/vm/${folder_app}
fi
#
# sb-server-01
#
sed -e "s#\${public_key}#$(cat /root/.ssh/id_rsa.pub)#" \
    -e "s@\${base64_userdata}@$(base64 /build/clusters/sb/userdata1.yaml -w 0)@" \
    -e "s/\${password}/VMware1!/" \
    -e "s@\${network_ref}@pg-SB-Web@" \
    -e "s/\${vm_name}/sb-server-01/" /build/clusters/sb/options-ubuntu.json.template | tee "/build/clusters/sb/options-ubuntu-01.json" > /dev/null 2>&1
#
govc library.deploy -options "/build/clusters/sb/options-ubuntu-01.json" -folder "${folder_app}" /cl-ubuntu/$(basename ${ubuntu_ova_url} .ova)
govc vm.change -vm "${folder_app}/sb-server-01" -c 2 -m 4096
govc vm.disk.change -vm "${folder_app}/sb-server-01" -size 15G
govc vm.power -on=true "${folder_app}/sb-server-01"
#
# sb-server-02
#
sed -e "s#\${public_key}#$(cat /root/.ssh/id_rsa.pub)#" \
    -e "s@\${base64_userdata}@$(base64 /build/clusters/sb/userdata2.yaml -w 0)@" \
    -e "s/\${password}/VMware1!/" \
    -e "s@\${network_ref}@pg-SB-Web@" \
    -e "s/\${vm_name}/sb-server-02/" /build/clusters/sb/options-ubuntu.json.template | tee "/build/clusters/sb/options-ubuntu-02.json" > /dev/null 2>&1
#
govc library.deploy -options "/build/clusters/sb/options-ubuntu-02.json" -folder "${folder_app}" /cl-ubuntu/$(basename ${ubuntu_ova_url} .ova)
govc vm.change -vm "${folder_app}/sb-server-02" -c 2 -m 4096
govc vm.disk.change -vm "${folder_app}/sb-server-02" -size 15G
govc vm.power -on=true "${folder_app}/sb-server-02"
#
# sb-server-03
#
sed -e "s#\${public_key}#$(cat /root/.ssh/id_rsa.pub)#" \
    -e "s@\${base64_userdata}@$(base64 /build/clusters/sb/userdata3.yaml -w 0)@" \
    -e "s/\${password}/VMware1!/" \
    -e "s@\${network_ref}@pg-SB-Web@" \
    -e "s/\${vm_name}/sb-server-03/" /build/clusters/sb/options-ubuntu.json.template | tee "/build/clusters/sb/options-ubuntu-03.json" > /dev/null 2>&1
#
govc library.deploy -options "/build/clusters/sb/options-ubuntu-03.json" -folder "${folder_app}" /cl-ubuntu/$(basename ${ubuntu_ova_url} .ova)
govc vm.change -vm "${folder_app}/sb-server-03" -c 2 -m 4096
govc vm.disk.change -vm "${folder_app}/sb-server-03" -size 15G
govc vm.power -on=true "${folder_app}/sb-server-03"
#
# checking K8s Node master node
#
ip_k8s_node="192.168.131.10"
retry=60 ; pause=10 ; attempt=1
while true ; do
  ssh -o StrictHostKeyChecking=no "ubuntu@${ip_k8s_node}" -q "exit" > /dev/null 2>&1
  if [[ $? -eq 0 ]]; then
    ssh -o StrictHostKeyChecking=no "ubuntu@${ip_k8s_node}" "test -f /tmp/cloudInitDone.log" 2>/dev/null
    if [[ $? -eq 0 ]]; then
      scp -o StrictHostKeyChecking=no "ubuntu@${ip_k8s_node}:/home/ubuntu/join-command" "/root/join-command"
      break
    fi
  fi
  ((attempt++))
  if [ $attempt -eq $retry ]; then
    echo "VM ${ip_k8s_node} is not reachable after $attempt attempt"
    break
  fi
  sleep $pause
done
#
# checking K8s Node worker node
#
ip_k8s_node="192.168.131.11"
retry=60 ; pause=10 ; attempt=1
while true ; do
  ssh -o StrictHostKeyChecking=no "ubuntu@${ip_k8s_node}" -q "exit" > /dev/null 2>&1
  if [[ $? -eq 0 ]]; then
    ssh -o StrictHostKeyChecking=no "ubuntu@${ip_k8s_node}" "test -f /tmp/cloudInitDone.log" 2>/dev/null
    if [[ $? -eq 0 ]]; then
      scp -o StrictHostKeyChecking=no "/root/join-command" "ubuntu@${ip_k8s_node}:/home/ubuntu/join-command"
      ssh -o StrictHostKeyChecking=no "ubuntu@${ip_k8s_node}" "sudo /bin/bash /home/ubuntu/join-command"
      break
    fi
  fi
  ((attempt++))
  if [ $attempt -eq $retry ]; then
    echo "VM ${ip_k8s_node} is not reachable after $attempt attempt"
    break
  fi
  sleep $pause
done
#
# checking K8s Node worker node
#
ip_k8s_node="192.168.131.12"
retry=60 ; pause=10 ; attempt=1
while true ; do
  ssh -o StrictHostKeyChecking=no "ubuntu@${ip_k8s_node}" -q "exit" > /dev/null 2>&1
  if [[ $? -eq 0 ]]; then
    ssh -o StrictHostKeyChecking=no "ubuntu@${ip_k8s_node}" "test -f /tmp/cloudInitDone.log" 2>/dev/null
    if [[ $? -eq 0 ]]; then
      scp -o StrictHostKeyChecking=no "/root/join-command" "ubuntu@${ip_k8s_node}:/home/ubuntu/join-command"
      ssh -o StrictHostKeyChecking=no "ubuntu@${ip_k8s_node}" "sudo /bin/bash /home/ubuntu/join-command"
      break
    fi
  fi
  ((attempt++))
  if [ $attempt -eq $retry ]; then
    echo "VM ${ip_k8s_node} is not reachable after $attempt attempt"
    break
  fi
  sleep $pause
done
#
# copying microservices folder and starting the services
#
ip_k8s_node="192.168.131.10"
scp -r /build/clusters/sb/microservices ubuntu@${ip_k8s_node}:/home/ubuntu
ssh -o StrictHostKeyChecking=no "ubuntu@${ip_k8s_node}" "kubectl apply -f microservices/avinetworks.yaml"
#
# transfer AKO Image
#
ip_k8s_node="192.168.131.10"
scp -r /build/bin/ako-2.1.3.tar.gz ubuntu@${ip_k8s_node}:/home/ubuntu/ako-2.1.3.tar.gz
ssh -o StrictHostKeyChecking=no "ubuntu@${ip_k8s_node}" "tar -zxvf ako-2.1.3.tar.gz"
ssh -o StrictHostKeyChecking=no "ubuntu@${ip_k8s_node}" "sudo docker load < ako/ako-2.1.3-docker.tar.gz"
ssh -o StrictHostKeyChecking=no "ubuntu@${ip_k8s_node}" "sudo docker load < ako/ako-2.1.3-gateway-api.tar.gz"
ssh -o StrictHostKeyChecking=no "ubuntu@${ip_k8s_node}" "sudo docker load < ako/ako-2.1.3-crd-operator.tar.gz"
ssh -o StrictHostKeyChecking=no "ubuntu@${ip_k8s_node}" "kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml"
ssh -o StrictHostKeyChecking=no "ubuntu@${ip_k8s_node}" "openssl req -newkey rsa:4096 -x509 -sha256 -days 3650 -nodes -out ssl.crt -keyout ssl.key -subj \"/C=US/ST=CA/L=Palo Alto/O=VMWARE/OU=IT/CN=ingress.sb.vclass.local\"; kubectl create secret tls cert01 --key=ssl.key --cert=ssl.crt"
#
ssh -o StrictHostKeyChecking=no "ubuntu@${ip_k8s_node}" "cd ako; tar -zxvf ako-2.1.3-crd-operator-helm.tgz"
ssh -o StrictHostKeyChecking=no "ubuntu@${ip_k8s_node}" "cd ako; tar -zxvf ako-2.1.3-helm.tgz"
ssh -o StrictHostKeyChecking=no "ubuntu@${ip_k8s_node}" "mv /home/ubuntu/ako/ako-helm/values.yaml /home/ubuntu/ako/ako-helm/values.yaml.old"
scp -o StrictHostKeyChecking=no /build/ako/sb/values.yaml ubuntu@${ip_k8s_node}:/home/ubuntu/ako/ako-helm
scp -o StrictHostKeyChecking=no -r /build/ako/sb/yaml ubuntu@${ip_k8s_node}:/home/ubuntu
#
ip_k8s_node="192.168.131.11"
scp -r /build/bin/ako-2.1.3.tar.gz ubuntu@${ip_k8s_node}:/home/ubuntu/ako-2.1.3.tar.gz
ssh -o StrictHostKeyChecking=no "ubuntu@${ip_k8s_node}" "tar -zxvf ako-2.1.3.tar.gz"
ip_k8s_node="192.168.131.12"
scp -r /build/bin/ako-2.1.3.tar.gz ubuntu@${ip_k8s_node}:/home/ubuntu/ako-2.1.3.tar.gz
ssh -o StrictHostKeyChecking=no "ubuntu@${ip_k8s_node}" "tar -zxvf ako-2.1.3.tar.gz"
#
# destroy content library
#
govc library.rm cl-ubuntu
