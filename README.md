

# Copy the terraform.tfvars.example and fill in values

This example assumes you have HCS and an Azure Web App already deployed. As a result, you will need some information about both of those environments that gets passed into Terraform.

```
cp terraform.tfvars.example terraform.tfvars
```

# Generate the HCS Client Config

```
az hcs get-config \
--resource-group hcs \
--name hcs
```

# Generate the HCS Bootstrap Token
```
az hcs create-token \
  --resource-group hcs \
  --name hcs
```

# Update the Client Config

The `az hcs get-config` command should have generated a `ca.pem` and `consul.json` file in your current directory. We are going to want to add a few configuration values to it including the GRPC port so that Envoy can communicate with Consul, enabled Consul Connect and set the data_dir to `/opt/consul`

```
...
    "ports": {
        "grpc": 8502
    },
    "connect": {
        "enabled": true
    },
    "data_dir": "/opt/consul"
}
```

In addition, we want to change the path to our ca file as it will be uploaded to `/etc/consul.d/ca.pem` by Terraform.

```
"ca_file": "/etc/consul.d/ca.pem",
```

Lastly, we need to include the bootstrap token that we generated earlier. 

```
...
    "tokens": {
        "agent": "1a67c087-6478-480d-9bb4-efef74c78729"
    }
...
```

# Test

SSH into the Terminating Gateway client and run the following curl command. Note that Consul doesn't currently pass through the Host header but this will be added, as a result we have to add the host header and set it to the hostname.

```
curl --header "Host: helloworld.azurewebsites.net" hello-world.service.dc1.consul
```