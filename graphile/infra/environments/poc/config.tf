terraform {
    required_version = "1.0.1"

    required_providers {
        digitalocean = {
            source = "digitalocean/digitalocean"
            version = "~> 2.0"
        }
    }
}

provider "digitalocean" {}

module "do_infra" {
    source = "../../modules/do_infra"

    region = "sfo2"
}
