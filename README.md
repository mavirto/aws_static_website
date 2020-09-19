# aws_static_website
Web estática alojada en bucket S3 con protoclo HTTPS (CloudFront con certificado)

INFO: 		Despliegue de infraestructura para web estática en S3 utilizando procolo https (CloudFront con certificado)

Servicios: 	S3, CloudFront, ACM

Requiere: 	Ficheros index.html y error.html de la web, y disponer de un dominio registrado (hosted zone) en Route53

Nota: 		No está contemplado utilizar el prefijo "www." ya que eso requiere mayor complejidad en la configuración y despliegue de recursos. Eso ya para la versión 2

Nota: 		Hay que desplegar en la región us-east-1 de AWS, ya que solo se permite solicitar certificados para CloudFront en esa región

En estudio:	Crear un bucket para logs y configurar opciones del bucket de la web y la distribución de CloudFront para redirigir logs allí. Para la versión 2


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
