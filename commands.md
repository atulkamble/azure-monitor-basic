install terraform from https://developer.hashicorp.com/terraform/install#windows

powershell run as admin >> choco install terraform 

terraform --version 

az login 

git clone https://github.com/atulkamble/azure-monitor-basic.git
cd azure-monitor-basic

// update your subscription id to main.tf 

terraform init 
terraform plan 

az vm extension image list-versions \
  --location eastus \
  --name AzureMonitorLinuxAgent \
  --publisher Microsoft.Azure.Monitor

>> enter your email id 

example: cloudnautic@gmail.com

terraform apply 

terraform destroy 



ssh -i key.pem azureuser@52.224.50.50

sudo stress-ng --cpu 4 --timeout 5
sudo stress-ng --cpu 2 --timeout 2
sudo stress-ng --cpu 1 --timeout 3
sudo stress-ng --cpu 4 --timeout 10


sudo apt install stress -y 

create file script.sh 

touch script.sh
nano script.sh 

paste following content 

sudo stress --cpu 8 --timeout 20
sudo stress --cpu 4 --timeout 20
sudo stress --cpu 4 --timeout 10
sudo stress --cpu 8 --timeout 5
sudo stress --cpu 4 --timeout 5
sudo stress --cpu 2 --timeout 5
sudo stress-ng --cpu 4 --timeout 5
sudo stress-ng --cpu 2 --timeout 2
sudo stress-ng --cpu 1 --timeout 3
sudo stress-ng --cpu 4 --timeout 10
sudo stress --cpu 8 --timeout 20
sudo stress --cpu 4 --timeout 20
sudo stress --cpu 4 --timeout 10
sudo stress --cpu 8 --timeout 5
sudo stress --cpu 4 --timeout 5
sudo stress --cpu 2 --timeout 5
sudo stress-ng --cpu 4 --timeout 5
sudo stress-ng --cpu 2 --timeout 2
sudo stress-ng --cpu 1 --timeout 3
sudo stress-ng --cpu 4 --timeout 10

chmod +x script.sh 
./script.sh

















