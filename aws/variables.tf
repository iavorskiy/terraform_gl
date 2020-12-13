variable "region" {
  description = "The region where resources will be created"
  default     = "us-west-2"
}

variable "application_port" {
  description = "The port that you want to expose to the external load balancer"
  default     = 80
}



variable "public_key" {
  description = "Pablic key for instance"
  default     = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDCLSW49Yc9Ao4kuXR5Q29tNeslnGdm0iYiH2Rkm4B/7N2a55tDEneudDPV+7REP/kC4lYiAdY+DWE+Yign30q3nayckamefSSLETleXwwiozDM1TTrMbi4sDgGlCm0JcZBXAM1xW6HGPPyvyWWoQcl9kIVXaCNx0GpAiQ2CbPlFqrUBlMzk6pp3wzU6cSXHMFOv7ZjDFW0Doinxk900gy9/H3ERdBloOStfc52nvvqVDlN8f3vA3WFHrg5520oD6eCGeRD1wlgNLudHHeq48HYDc+AKQX/Yw8kuJWYd5gHu+QrC0648EY1D+ctBirszggAwYA1H5JTREI9y8Wfes7b alex@localhost.localdomain"

}


variable "az_a" {
  description = "Availability zone"
  default     = "us-west-2a"
}

variable "az_b" {
  description = "Availability zone"
  default     = "us-west-2b"
}

variable "ssh_port" {
  description = "The ssh conect port"
  default     = 22
}
