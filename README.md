### Introduction
This is a template demonstrating a simple CI/CD pipeline using Terraform and GitHub Actions 

### Requirements/Uses 
- [Terraform](https://developer.hashicorp.com/terraform/docs)
- GitHub Actions 
- [AWS](https://aws.amazon.com)
- [Docker](https://www.docker.com)
- [AWS Elastic Container Registry](https://aws.amazon.com/ecr/)

### Commands (to run locally)
1. Clone the repository and navigate to the working directory
```bash
$cd terraform 
```

2. Create an S3 bucket for storing the Terraform state file. Modify the `bucket` name in the remote backend configuration of the terraform block in `main.tf` 

3. Initialize terraform
```bash
$terraform init
```

4. Generate the execution plan
```bash
$terraform plan \ 
    -var "public_key=$PUBLIC_KEY" \
    -var "private_key=$PRIVATE_KEY" \
    -out PLAN
```

5. Perform the execution plan to provision the resources 
```bash
$terraform apply PLAN 
```

6. View the output elastic IP of the deployed EC2 server 
```bash
$terraform output ec2_server_eip_public
```

7. To check if the web page is being served correctly by apache as defined in the User Data script, open `<server-ip>:80` in a web browser

8. Destroy provisioned resources/Clean-up
```bash
$terraform destroy
```

#### I hope this is helpful!