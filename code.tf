provider “aws” {
region = “ap-south-1”
profile = "ankit"
}

/creating key pair
resource “tls_private_key” “tlspktask2” {
 
 algorithm = “RSA”
}
resource “aws_key_pair” “task2key” {
depends_on = [ tls_private_key.tlspktask2 ,]
key_name = “Terraform-test2”
public_key = tls_private_key.tlspktask2.public_key_openssh
 
}


//Creating S3 bucket
resource “aws_s3_bucket” “s3task2” {
  bucket = “task2-bucket”
  acl = “private”
}
//Downloading content from Github
resource “null_resource” “local-task2” {
   depends_on = [aws_s3_bucket.s3task2,]
   provisioner “local-exec” {
     command = “git clone https://github.com/001ankit-1/cloud_task_2.git"
}
}
// Uploading file to bucket
resource “aws_s3_bucket_object” “file_upload2” {
    depends_on = [aws_s3_bucket.s3task2 , null_resource.local-task2]
    bucket = aws_s3_bucket.s3task2.id
    key = “images.jpeg”
    source = “efss/image.png”
    acl = “public-read”
}
output “Image” {
    value = aws_s3_bucket_object.file_upload2
}

// Creating Cloudfront Distribution
resource “aws_cloudfront_distribution” “distribution” {
   depends_on = [aws_s3_bucket.s3task2 , null_resource.local-task2 ]
   origin {
     domain_name = aws_s3_bucket.s3task2.bucket_regional_domain_name
     origin_id = “S3-task2-bucket-id”
     custom_origin_config {
       http_port = 80
       https_port = 80
       origin_protocol_policy = “match-viewer”
       origin_ssl_protocols = [“TLSv1”, “TLSv1.1”, “TLSv1.2”]
     }
   }
   enabled = true
   default_cache_behavior {
      allowed_methods = [“DELETE”, “GET”, “HEAD”, “OPTIONS”, “PATCH”, “POST”, “PUT”]
      cached_methods = [“GET”, “HEAD”]
      target_origin_id = “S3-task2-bucket-id”
      forwarded_values {
        query_string = false
        cookies {
          forward = “none”
        }
      }
  viewer_protocol_policy = “allow-all”
  min_ttl = 0
  default_ttl = 3600
  max_ttl = 86400
  }
  restrictions {
     geo_restriction {
     restriction_type = “none”
   }
  }
  viewer_certificate {
  cloudfront_default_certificate = true
  }
 }
  output “domain-name” {
      value = aws_cloudfront_distribution.distribution.domain_name
 }



//SECURITY GROUP
resource “aws_security_group” “allowhttpnfs”{
ingress {
from_port = 80
to_port = 80
protocol = “tcp”
cidr_blocks = [ "0.0.0.0/0" ]
}
ingress {
from_port = 2049
to_port = 2049
protocol = “tcp”
cidr_blocks = [ "0.0.0.0/0" ]
}
ingress {
from_port = 22
to_port = 22
protocol = “tcp”
cidr_blocks = [ "0.0.0.0/0" ]
}
egress {
from_port = 80
to_port = 80
protocol = “tcp”
cidr_blocks = [ "0.0.0.0/0" ]
}
egress {
from_port = 2049
to_port = 2049
protocol = “tcp”
cidr_blocks = [ "0.0.0.0/0" ]
}
egress {
from_port = 22
to_port = 22
protocol = “tcp”
cidr_blocks = [ "0.0.0.0/0" ]
}
}


//EC2 with above Security Group
resource “aws_instance” “task2webap” {
     ami = “ami-01d025118d8e760db”
 
     instance_type = “t2.micro”
     key_name = aws_key_pair.task2key.key_name
     security_groups = [“${aws_security_group.allowhttpnfs.name}”]
    tags = {
 
         Name = “task2os”
   }
}


// Launching a EFS Storage
resource "aws_efs_file_system" "nfs" {
depends_on =  [ aws_security_group.allowhttpnfs , aws_instance.task2os ]
creation_token = "nfs"
tags = {
Name = "nfs"
}
}
// Mounting the EFS volume onto the VPC's Subnet


resource "aws_efs_mount_target" "targetnfs" {
depends_on =  [ aws_efs_file_system.nfs,]
file_system_id = aws_efs_file_system.nfs.id
subnet_id      = aws_instance.task2os.subnet_id
security_groups = ["${aws_security_group.allowhttpnfs.id}"]
}


//Connection to the instance of EC2
   connection {
     type = “ssh”
     user = “ec2-user”
     private_key = tls_private_key.tlspktask2.private_key_pem
     host = aws_instance.task2webap.public_ip
 
}
//Installing requirements
provisioner “remote-exec” {
   inline = [
      “sudo yum install httpd php git -y”,
      “sudo systemctl restart httpd”,
      “sudo systemctl enable httpd”,
      "sudo echo ${aws_efs_file_system.nfs.dns_name}:/var/www/html efs defaults,_netdev 0 0 >> sudo /etc/fstab",
        "sudo mount  ${aws_efs_file_system.nfs.dns_name}:/  /var/www/html",
      “sudo git clone "https://github.com/001ankit-1/cloud_task_2.git"  /var/www/html/”
]
}
}

output "task-instance-ip" {
value = aws_instance.task2os.public_ip
}
//Connect to the webserver to see the website
resource "null_resource" "webpage"  {

depends_on = [null_resource.remote-connect,]


provisioner "local-exec" {
   command = "start chrome ${aws_instance.task2webap.public_ip}"
  }
