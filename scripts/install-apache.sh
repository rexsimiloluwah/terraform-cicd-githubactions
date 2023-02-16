#!/bin/bash 
sudo apt update -y 
sudo apt install apache2 -y 
sudo systemctl start apache2 
sudo chmod -R 775 /var/www/html
echo "<h1>Hello World from Terraform</h1>" > /var/www/html/index.html