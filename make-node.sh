#!/bin/bash
set -euo pipefail

if [ $# -ne 2 ]; then
    echo "Usage: make-node.sh <node name> <hostname>"
    echo ""
    echo "For example:"
    echo "  make-node.sh myvps myvps.myprovider.example"
    exit 1
fi

echo "Creating node nodes/$1"
mkdir nodes/$1
cat <<EOF > nodes/$1/docker-compose.yaml
services:
  node-exporter:
    image: prom/node-exporter:latest
    container_name: monitoring-node-exporter
    restart: unless-stopped
    ports:
      - 9100:9100
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
      - ./node-exporter.web.yml:/etc/prometheus/web.yml
      - ./certs/:/certs
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.ignored-mount-points="^/(sys|proc|dev|host|etc)($$|/)"'
      - '--web.config.file=/etc/prometheus/web.yml'
EOF

echo "Generating password"
password=$(python3 -c "from random import choices; import string; print(''.join(choices(string.ascii_letters + string.digits, k=32)))")
hashed=$(htpasswd -n -b -B node-exporter $password | cut -d: -f2)

echo "Creating node-exporter.web.yml config"
cat <<EOF > nodes/$1/node-exporter.web.yml
basic_auth_users:
    node-exporter: $hashed
tls_server_config:
  cert_file: /certs/$1.pem
  key_file: /certs/$1-key.pem
EOF

echo "Creating $1 certs"
mkdir nodes/$1/certs
pwd=$(pwd)
cd pki
./gen-cert.sh $1 $2
cd $pwd
cp pki/certs/$1/$1-ca.pem nodes/$1/certs/
cp pki/certs/$1/$1.pem nodes/$1/certs/
cp pki/certs/$1/$1-key.pem nodes/$1/certs/
cp pki/certs/$1/$1-ca.pem monitoring/certs/
chmod 644 nodes/$1/certs/*


echo -e "Add the following to your prometheus.yml scrape_configs in your monitoring container:\n"
cat <<EOF
  - job_name: '$1'
    scheme: https
    tls_config:
      ca_file: /certs/$1-ca.pem
    basic_auth:
      username: node-exporter
      password: $password
    static_configs:
      - targets: ['$2:9100']
EOF
echo -e "\nCopy nodes/$1 to your server and run 'docker compose up -d' to start the node exporter container"