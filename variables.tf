variable "hcs_virtual_network_name" {
    type = string
}

variable "hcs_resource_group" {
    type = string
}

variable "hcs_bootstrap_token" {
    type = string
}

variable "gateway_resource_group_name" {
    type = string
    default = "gateway"
}

variable "consul_ca_path" {
    type = string
    default = "ca.pem"
}

variable "consul_config_path" {
    type = string
    default = "consul.json"
}

variable "web_app_domain" {
    type = string
}