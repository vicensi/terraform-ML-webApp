# Projeto 7 - MLOps com IaC Para Automação do Deploy de Modelo de Machine Learning na Nuvem

# Define o provedor AWS e a região onde os recursos serão criados
provider "aws" {
  region = "us-east-2"
}

# Cria um bucket S3 para armazenar arquivos da aplicação Flask
resource "aws_s3_bucket" "dsa_bucket_flask" {
  bucket = "dsa-890582101704-bucket" # Nome único do bucket S3

  # Define tags para identificar o bucket
  tags = {
    Name        = "DSA Bucket"
    Environment = "Projeto7"
  }

  # Provisiona um script local para fazer upload de arquivos para o bucket após criação
  provisioner "local-exec" {
    command = "${path.module}/upload_to_s3.sh"
  }

  # Provisiona um script local para limpar o bucket S3 ao destruir o recurso
  provisioner "local-exec" {
    when    = destroy
    command = "aws s3 rm s3://dsa-890582101704-bucket --recursive"
  }
}

# Cria uma instância EC2 para hospedar a API de Machine Learning
resource "aws_instance" "dsa_ml_api" {

  ami = "ami-0a0d9cf81c479446a"  # ID da imagem de máquina (AMI) a ser usada
  instance_type = "t2.micro"     # Tipo da instância EC2

  # Associa o perfil IAM que concede acesso ao S3
  iam_instance_profile = aws_iam_instance_profile.ec2_s3_profile.name

  # Associa o Security Group criado à instância
  vpc_security_group_ids = [aws_security_group.dsa_ml_api_sg.id]

  # Script de inicialização que configura a instância para rodar a aplicação Flask
  user_data = <<-EOF
                #!/bin/bash
                sudo yum update -y
                sudo yum install -y python3 python3-pip awscli
                sudo pip3 install flask joblib scikit-learn numpy scipy gunicorn
                sudo mkdir /dsa_ml_app
                sudo aws s3 sync s3://dsa-890582101704-bucket /dsa_ml_app
                cd /dsa_ml_app
                nohup gunicorn -w 4 -b 0.0.0.0:5000 app:app &
              EOF

  # Define tags para identificar a instância
  tags = {
    Name = "DSAFlaskApp"
  }
}

# Cria um Security Group para permitir conexões seguras à instância
resource "aws_security_group" "dsa_ml_api_sg" {

  name        = "dsa_ml_api_sg"                        # Nome do Security Group
  description = "Security Group for Flask App in EC2"  # Descrição

  # Regras de entrada para permitir tráfego nas portas HTTP, Flask e SSH
  ingress {
    description = "Inbound Rule 1"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Permite tráfego de qualquer endereço IP
  }

  ingress {
    description = "Inbound Rule 2"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Inbound Rule 3"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Regra de saída para permitir tráfego de qualquer endereço
  egress {
    description = "Outbound Rule"
    from_port = 0
    to_port = 65535
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Cria um papel IAM para a instância EC2 acessar o S3
resource "aws_iam_role" "ec2_s3_access_role" {

  name = "ec2_s3_access_role"  # Nome do papel IAM

  # Define a política de confiança para permitir que o serviço EC2 assuma o papel
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

# Cria uma política de acesso ao S3 para o papel IAM
resource "aws_iam_role_policy" "s3_access_policy" {
  name = "s3_access_policy"  # Nome da política
  role = aws_iam_role.ec2_s3_access_role.id  # Associa ao papel IAM criado

  # Define as permissões de acesso ao bucket S3
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ],
        Effect = "Allow",
        Resource = [
          "${aws_s3_bucket.dsa_bucket_flask.arn}/*", # Permissões nos objetos do bucket
          "${aws_s3_bucket.dsa_bucket_flask.arn}"    # Permissões no bucket
        ]
      },
    ]
  })
}

# Cria um perfil de instância IAM para associar o papel à EC2
resource "aws_iam_instance_profile" "ec2_s3_profile" {
  name = "ec2_s3_profile"  # Nome do perfil de instância
  role = aws_iam_role.ec2_s3_access_role.name  # Papel associado ao perfil
}
