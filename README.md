# Machine learning via web app 
MLOps com IaC Para Automação do Deploy de Modelo de Machine Learning na Nuvem


# Abra o terminal ou prompt de comando e navegue até a pasta onde você colocou os arquivos (não use espaço ou acento em nome de pasta)

# Execute o comando abaixo para criar a imagem Docker

docker build -t dsa-mlops-image:p7 .

# Execute o comando abaixo para criar o container Docker

docker run -dit --name dsa-mlops-p7 -v ./IaC:/iac dsa-mlops-image:p7 /bin/bash

NOTA: No Windows você deve substituir ./IaC pelo caminho completo da pasta, por exemplo: C:\DSA\Cap15\IaC


