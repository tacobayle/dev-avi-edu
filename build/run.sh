#!/bin/bash
echo "172.20.10.94 sa-vcsa-01.vclass.local" | tee -a /etc/hosts
echo "172.20.110.95 sb-vcsa-01.vclass.local" | tee -a /etc/hosts
echo "172.20.10.130 sa-avicon-01.vclass.local" | tee -a /etc/hosts
echo "172.20.10.131 sa-avitools-01.vclass.local" | tee -a /etc/hosts
echo "172.20.110.130 sb-avicon-01.vclass.local" | tee -a /etc/hosts
ssh-keygen -t rsa -N "" -f /root/.ssh/id_rsa
service nginx start
cd /build/api
gunicorn --workers 3 --bind 127.0.0.1:5000 -m 007 wsgi:app
while true ; do sleep 3600 ; done