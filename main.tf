

####
# INFO: 	Despliegue de infraestructura para web estática en S3 utilizando procolo https (CloudFront con certificado)
# Servicios: 	S3, CloudFront, ACM
# Requiere: 	Ficheros index.html y error.html de la web, y disponer de un dominio registrado (hosted zone) en Route53
# Nota: 	No está contemplado utilizar el prefijo "www." ya que eso requiere mayor complejidad en la configuración y despliegue de recursos. Eso ya para la versión 2
# Nota: 	Hay que desplegar en la región us-east-1 de AWS, ya que solo se permite solicitar certificados para CloudFront en esa región
# En estudio:	Crear un bucket para logs y configurar opciones del bucket de la web y la distribución de CloudFront para redirigir logs allí. Para la versión 2
####



# Solo podemos generar certificado SSL para CloudFront en la región de Virginia (us-east-1)

#### Datasources

# Datasource Zona DNS

data "aws_route53_zone" "zona" {
  name         = var.webdomain
  private_zone = false
}


# Datasource que nos devuelve el ARN del certificado que solicitamos a AWS 

data "aws_acm_certificate" "info_certificado" {
  domain      = var.webdomain
  statuses    = ["ISSUED"]
  most_recent = true

  depends_on = [
    aws_acm_certificate.certificado,
    aws_route53_record.registro_certificado,
    aws_acm_certificate_validation.valida_certificado,
  ]
}


#### Certificado ACM

# Solicitamos certificado a AWS

resource "aws_acm_certificate" "certificado" {
  domain_name       = var.webdomain
  validation_method = "DNS"

  tags = {
    ManagedBy   = "terraform"
    Environment = "Static Website"
  }

  lifecycle {
    create_before_destroy = true
  }
}


# Registro para el certificado

resource "aws_route53_record" "registro_certificado" {
  for_each = {
    for dvo in aws_acm_certificate.certificado.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.zona.zone_id
}


# Validamos el certificado

resource "aws_acm_certificate_validation" "valida_certificado" {
  certificate_arn         = aws_acm_certificate.certificado.arn
  validation_record_fqdns = [for record in aws_route53_record.registro_certificado : record.fqdn]
}


#### Bucket S3

# Bucket S3 para alojar website

resource "aws_s3_bucket" "bucket" {
  bucket = var.webdomain
  acl    = "private"

  website {
    index_document = "index.html"
    error_document = "error.html"
  }

  tags = {
    ManagedBy   = "terraform"
    Environment = "Static Website"
  }
}


#### CloudFront

# CloudFront Origin Access Identity

resource "aws_cloudfront_origin_access_identity" "cfoai" {
  comment = "Cloudfront Origin Access Identity ${var.webdomain}"
}


# Creamos CloudFront Distribution (tarda en crearse unos 15 minutos. No asustarse cuando ejecutemos un terraform apply) 

resource "aws_cloudfront_distribution" "cf_distribution" {
  enabled     = true
  aliases     = [var.webdomain]

  # Ojo con el rollo este del Price_class; Solo permitimos los Edge Locations de USA y Europa/Israel. https://aws.amazon.com/cloudfront/pricing/
  price_class = "PriceClass_100"

  origin {
    origin_id   = "origin-${aws_s3_bucket.bucket.id}"
    domain_name = aws_s3_bucket.bucket.bucket_regional_domain_name

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.cfoai.cloudfront_access_identity_path
    }
  }

  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "origin-${aws_s3_bucket.bucket.id}"
    min_ttl                = "0"
    default_ttl            = "700"
    max_ttl                = "1400"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = data.aws_acm_certificate.info_certificado.arn
    ssl_support_method  = "sni-only"
  }

  custom_error_response {
    error_caching_min_ttl = 300
    error_code            = 404
    response_page_path    = "/error.html"
    response_code         = 404
  }

  tags = {
    ManagedBy  = "terraform"
    Environment = "Static Website"
  }

}


# Crea registro DNS apuntando a la distribución de CloudFront 

resource "aws_route53_record" "registro_website_cf" {
  name    = var.webdomain
  type    = "A"
  zone_id = data.aws_route53_zone.zona.zone_id

  alias {
    name                   = aws_cloudfront_distribution.cf_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.cf_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}




#### Bucket Policy y ficheros para la web

# Bucket Policy 

resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.bucket.id

  policy = <<POLICY
{
  "Version": "2008-10-17",
  "Id": "PolicyCF",
  "Statement": [
    {
      "Sid": "AllowCloudFrontOriginAccess",
      "Effect": "Allow",
      "Principal": {
        "AWS": "${aws_cloudfront_origin_access_identity.cfoai.iam_arn}"
      },
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "${aws_s3_bucket.bucket.arn}/*",
        "${aws_s3_bucket.bucket.arn}"
      ]
    }
  ]
}
POLICY
}

# Ficheros Bucket

resource "aws_s3_bucket_object" "ficheros_bucket" {
  for_each = var.ficheros_web

  bucket = aws_s3_bucket.bucket.id
  key    = each.key
  source = each.value
}

