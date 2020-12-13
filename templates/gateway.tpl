#!/usr/bin/env bash

sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common \
    unzip

curl -sL 'https://getenvoy.io/gpg' | sudo apt-key add -

apt-key fingerprint 6FF974DB

sudo add-apt-repository \
    "deb [arch=amd64] https://dl.bintray.com/tetrate/getenvoy-deb \
    $(lsb_release -cs) \
    stable"

sudo apt-get update && sudo apt-get install -y getenvoy-envoy=1.14.4.p0.g923c411-1p67.g2aa564b


curl -s -o consul_${consul_version}_linux_amd64.zip "https://releases.hashicorp.com/consul/${consul_version}/consul_${consul_version}_linux_amd64.zip"

unzip consul_${consul_version}_linux_amd64.zip
sudo chown root:root consul
sudo mv consul /usr/local/bin/

sudo useradd --system --home /etc/consul.d --shell /bin/false consul

sudo mkdir --parents /opt/consul

sudo chown --recursive consul:consul /opt/consul

sudo touch /etc/systemd/system/consul.service

sudo tee -a /etc/systemd/system/consul.service > /dev/null <<EOT
[Unit]
Description="HashiCorp Consul - A service mesh solution"
Documentation=https://www.consul.io/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/consul.d/consul.json

[Service]
Type=exec
User=consul
Group=consul
ExecStart=/usr/local/bin/consul agent -config-dir=/etc/consul.d/
ExecReload=/usr/local/bin/consul reload
ExecStop=/usr/local/bin/consul leave
KillMode=process
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOT

sudo mkdir --parents /etc/consul.d
sudo touch /etc/consul.d/consul.hcl
sudo chown --recursive consul:consul /etc/consul.d
sudo chmod 640 /etc/consul.d/consul.hcl

sudo mkdir --parents /etc/consul.d/config

while [ ! -f /tmp/ca.pem ] ;
do
      sleep 5
      echo "Waiting for certificates..."
done

sudo mv /tmp/ca.pem /etc/consul.d/ca.pem

while [ ! -f /tmp/consul.json ] ;
do
      sleep 5
      echo "Waiting for config..."
done

sudo mv /tmp/consul.json /etc/consul.d/consul.json

# Setup config

sudo service consul enable
sudo service consul start

echo "Consul Started."

# Wait for Consul to Start
until $(curl --output /dev/null --silent --head --fail http://localhost:8500); do
    printf '.'
    sleep 5
done

export PRIVATE_IP=$(ifconfig | grep -A7 --no-group-separator '^eth' | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*')

echo -e "\nDNS=127.0.0.1\nDomains=~consul" | sudo tee -a /etc/systemd/resolved.conf

sudo service systemd-resolved restart

sudo iptables -t nat -A OUTPUT -d localhost -p udp -m udp --dport 53 -j REDIRECT --to-ports 8600
sudo iptables -t nat -A OUTPUT -d localhost -p tcp -m tcp --dport 53 -j REDIRECT --to-ports 8600

export CONSUL_HTTP_TOKEN=${hcs_bootstrap_token}

sudo tee -a /etc/consul.d/config/azure-web-app.json > /dev/null <<EOT
{
  "Node": "hello-world_node",
  "Address": "${azure_web_app_domain}",
  "NodeMeta": {
    "external-node": "true",
    "external-probe": "true"
  },
  "Service": {
    "ID": "hello-world-id",
    "Service": "hello-world",
    "Port": 443
  }, 
  "Checks": [
    {
      "Name": "http-check",
      "status": "passing",
      "Definition": {
        "http": "https://${azure_web_app_domain}",
        "interval": "30s"
      }
    }
  ]
}
EOT

sudo tee -a /etc/consul.d/config/azure-terminating-gateway.hcl > /dev/null <<EOT
Kind = "terminating-gateway"
Name = "azure-terminating-gateway"
Services = [
{
  Name = "hello-world"
}
]
EOT

sleep 10

curl --header "X-Consul-Token: $CONSUL_HTTP_TOKEN" --request PUT --data @/etc/consul.d/config/azure-web-app.json localhost:8500/v1/catalog/register
consul config write /etc/consul.d/config/azure-terminating-gateway.hcl

sudo nohup consul connect envoy -gateway=terminating -register -service azure-terminating-gateway -token "$CONSUL_HTTP_TOKEN" -admin-bind "127.0.0.1:19200" -address "$PRIVATE_IP:19201" &

# Update the Anonymous Token so that we can utilize DNS lookup for the hello-world service
consul acl policy create -name 'service-hello-world-read' -rules 'service "hello-world" { policy = "read" }'
consul acl token update -id 00000000-0000-0000-0000-000000000002 --merge-policies -description "Anonymous Token - Can List Nodes" -policy-name service-hello-world-read