Ejemplo de Availability Zone
#Login
#SKU Stock-keeping unit En español algo como Codigo de articulo/ Numero de referencia

#Creamos resource group
az group create --name demo --location westus2

#Creamos Vnet y Subnet
az network vnet create -g demo -n demo-vnet \
    --address-prefix 192.168.0.0/16 \
    --subnet-name demo-subnet-iaas \
    --subnet-prefix 192.168.0.0/24

#Listar Sku disponible para la region
az vm list-skus --location westus2 --zone  --size Standard_D2 --output table

#Revisar lista de OS centos disponibles

az vm image list-skus --location westus2 --publisher OpenLogic --offer centos

#Creamos el Network Security Group
az network nsg create --resource-group demo --name demoNetworkSecurityGroup

#Creamos acceso al puerto 80
az network nsg rule create --resource-group demo --nsg-name demoNetworkSecurityGroup --name myNetworkSecurityGroupRule80-vmZone1-1 \
    --protocol tcp --direction inbound --source-address-prefix '*' --source-port-range '*'  \
    --destination-address-prefix '192.168.0.4' --destination-port-range 80 --access allow --priority 1002

az network nsg rule create --resource-group demo --nsg-name demoNetworkSecurityGroup --name myNetworkSecurityGroupRule80-vmZone1-2 \
    --protocol tcp --direction inbound --source-address-prefix '*' --source-port-range '*'  \
    --destination-address-prefix '192.168.0.5' --destination-port-range 80 --access allow --priority 1003

#Creando Ip publica para el load balancer
az network public-ip create --resource-group demo --name myPublicIPLoadBalancer --allocation-method Dynamic

#Creando load balancer
az network lb create --resource-group demo \
    --name loadBalancerWeb \
    --public-ip-address myPublicIPLoadBalancer \
    --frontend-ip-name webAccess \
    --backend-pool-name vmAccess

#Creamos un health Check Probe
az network lb probe create --resource-group demo \
    --lb-name loadBalancerWeb \
    --name loadBalancerWeb-probe80 \
    --protocol tcp \
    --port 80

#Creamos Reglas de balanceo
az network lb rule create \
    --resource-group demo \
    --lb-name loadBalancerWeb \
    --name loadBalancerWeb-balance80 \
    --protocol tcp \
    --frontend-port 80 \
    --backend-port 80 \
    --frontend-ip-name webAccess \
    --backend-pool-name vmAccess \
    --probe-name loadBalancerWeb-probe80


#Crear availability set
az vm availability-set create \
    --resource-group demo \
    --name AvailabilitySetZone1 \
    --platform-fault-domain-count 2 \
    --platform-update-domain-count 2

#Nic para las vms atachadas al load balancer

az network nic create \
        --resource-group demo \
        --name myNicvmZone1-1 \
        --vnet-name demo-vnet \
        --subnet demo-subnet-iaas \
        --network-security-group demoNetworkSecurityGroup \
        --lb-name loadBalancerWeb \
        --lb-address-pools vmAccess

az network nic create \
        --resource-group demo \
        --name myNicvmZone1-2 \
        --vnet-name demo-vnet \
        --subnet demo-subnet-iaas \
        --network-security-group demoNetworkSecurityGroup \
        --lb-name loadBalancerWeb \
        --lb-address-pools vmAccess

#Creamos cloud-init vm-1
cat <<EOF >> cloud-init.txt
#cloud-config
write_files:
  - owner: root
  - path: /etc/yum.repos.d/nginx.repo
    content: |
      [nginx]
      name=nginx repo
      baseurl=https://nginx.org/packages/mainline/centos/7/$basearch/
      gpgcheck=0
      enabled=1
package_upgrade: true
packages:
  - nginx
  - nmap-ncat
runcmd:
  - wget https://raw.githubusercontent.com/is-daimonos/demo-azure/master/nginx/vm1/index.html -O /usr/share/nginx/html/index.html
  - systemctl enable nginx
  - systemctl start nginx
EOF

#Maquinas en Availabilty Set
#Creando Maquina 1
az vm create --name vmZone1-1 \
    --resource-group demo \
    --admin-username everis \
    --location westus2 \
    --image "OpenLogic:CentOS:7-CI:latest" \
    --ssh-key-value /Users/everis/.ssh/id_rsa.pub \
    --size Standard_DS2_v2 \
    --availability-set AvailabilitySetZone1 \
    --custom-data cloud-init.txt \
    --nics myNicvmZone1-1

#Creamos cloud-init vm-2
cat <<EOF >> cloud-init.txt
#cloud-config
write_files:
  - owner: root
  - path: /etc/yum.repos.d/nginx.repo
    content: |
      [nginx]
      name=nginx repo
      baseurl=https://nginx.org/packages/mainline/centos/7/$basearch/
      gpgcheck=0
      enabled=1
package_upgrade: true
packages:
  - nginx
  - nmap-ncat
runcmd:
  - wget https://raw.githubusercontent.com/is-daimonos/demo-azure/master/nginx/vm2/index.html -O /usr/share/nginx/html/index.html
  - systemctl enable nginx
  - systemctl start nginx
EOF

#Creando Maquina 2
az vm create --name vmZone1-2 \
    --resource-group demo \
    --admin-username everis \
    --location westus2 \
    --image "OpenLogic:CentOS:7-CI:latest" \
    --ssh-key-value /Users/everis/.ssh/id_rsa.pub \
    --size Standard_DS2_v2 \
    --availability-set AvailabilitySetZone1 \
    --custom-data cloud-init.txt \
    --nics myNicvmZone1-2

#Flavor normal sin cloud init OpenLogic:CentOS:7.5:7.5.20180815

#Creamos regla de acceso a ssh

az network nsg rule create --resource-group demo --nsg-name demoNetworkSecurityGroup --name myNetworkSecurityGroupRuleSSH-vmZone1-1 \
  --protocol tcp --direction inbound --source-address-prefix '*' --source-port-range '*'  \
  --destination-address-prefix '192.168.0.4' --destination-port-range 22 --access allow --priority 1000

az network nsg rule create --resource-group demo --nsg-name demoNetworkSecurityGroup --name myNetworkSecurityGroupRuleSSH-vmZone1-2 \
  --protocol tcp --direction inbound --source-address-prefix '*' --source-port-range '*'  \
  --destination-address-prefix '192.168.0.5' --destination-port-range 22 --access allow --priority 1001

