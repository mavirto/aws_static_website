# aws_static_website
Web estática alojada en bucket S3 con protoclo HTTPS (CloudFront con certificado)


# main.tf
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

module "static_website" {
  source = "../aws_static_website"

  webdomain    = var.domain_name
  ficheros_web = var.ficheros
}


# variables.tf
variable aws_profile {
  type    = string
  default = "usuario_aws"
}
variable aws_region {
  type    = string
  default = "us-east-1"
}


variable domain_name {
  type    = string
  default = "mystaticwebsite.com"
}

variable "ficheros" {
  type = map(string)

  default = {
    "index.html"                 = "ficheros_website/index.html"
    "error.html"                 = "ficheros_website/error.html"
    "style.css"                  = "ficheros_website/style.css"
    "img/img1.png"      	 = "ficheros_website/img/img1.png"
    "img/img2.png"    		 = "ficheros_website/img/img2.png"
    "img/img3.png" 		 = "ficheros_website/img/img3.png"
    ...
  }
}
