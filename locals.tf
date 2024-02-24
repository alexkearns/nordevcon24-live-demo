locals {
  availability_zones = {
    "eu-west-2a" = "euw2a"
    "eu-west-2b" = "euw2b"
#    "eu-west-2c" = "euw2c"
  }

  subnets = {
    "public-euw2a" = { tier = "public", az = "eu-west-2a", cidr_block = "10.0.0.0/19" }
    "app-euw2a"    = { tier = "app", az = "eu-west-2a", cidr_block = "10.0.32.0/19" }
    "public-euw2b" = { tier = "public", az = "eu-west-2b", cidr_block = "10.0.64.0/19" }
    "app-euw2b"  = { tier = "app", az = "eu-west-2b", cidr_block = "10.0.96.0/19" }
#    "public-euw2c" = { tier = "public", az = "eu-west-2c", cidr_block = "10.0.128.0/19" }
#    "app-euw2c" = { tier = "app", az = "eu-west-2c", cidr_block = "10.0.160.0/19" }
#    "spare"  = { tier = "spare", az = "eu-west-2a", cidr_block = "10.0.192.0/19" }
#    "spare"  = { tier = "spare", az = "eu-west-2b", cidr_block = "10.0.224.0/19" }
  }
}