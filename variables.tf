# VPC CIDR 
variable "aws_vpc" {
  default = "10.0.0.0/16"
}

#Public Subnet 1
variable "aws_pubsub01" {
  default = "10.0.1.0/24"
}

#Public Subnet 2
variable "aws_pubsub02" {
  default = "10.0.2.0/24"
}

#Private Subnet 1
variable "aws_prvsub01" {
  default = "10.0.3.0/24"
}

#Private Subnet 2
variable "aws_prvsub02" {
  default = "10.0.4.0/24"
}

#All IP CIDR
variable "all_ip" {
  default = "0.0.0.0/0"
}

# Key pair name
variable "pacpet1_key" {
  default = "pacpet1_prv"
}

# Path to public key pair
variable "pacpet1_keypub" {
  default = "pacpet1_pub_key"
}

variable "sonar_ami" {
  default = "ami-0fb391cce7a602d1f"
}

#route 53 variables
variable "domain_name" {
  default     = "barbarachiragia.com"
  description = "domain_name"
}


variable "record_name" {
  default     = "www"
  description = "sub domain name"
}
