# PKS on Azure

We want PKS, but we need a "control plane" (another network, with another opsman, to deploy concourse) so we can use Platform Automation to build the opsman + PKS bits we really want...  The idea is using terraform for initial IaaS paving, including laying down an initial opsman, then letting concourse do everything else.  We also want to follow a "supported" path.  If you already have a functional IaaS and concourse, you can skip the first few sections.

## Setup CLI

Install and configure azure-cli.

```
brew update;brew install azure-cli`

az cloud set --name AzureCloud
az login
az account set -s <subscription_id>
```

## Make a jumpbox

Optional, if you don't want to bootstrap from your laptop.

`public-ip-address` is the *name* of an IP address object to create or re-use, not the actual IP address!
Resource group, vnet and subnet should already exist.

```
az vm create -n jumpbox \
  -g sandbox \
  --image ubuntults \
  --vnet-name sandbox-virtual-network \
  --subnet sandbox-infrastructure-subnet \
  --public-ip-address JumpboxPublicIp \
  --public-ip-address-allocation static \
  --data-disk-sizes-gb 200 \
  --os-disk-size-gb 200 \
  --size Standard_DS2_v2 \
  --authentication-type ssh \
  --ssh-key-values ~/.ssh/id_rsa.pub
```

### Install dependencies

```
sudo apt update --yes && \
sudo apt install --yes unzip && \
sudo apt install --yes jq && \
sudo apt install --yes build-essential && \
sudo apt install --yes ruby-dev && \
sudo gem install --no-ri --no-rdoc cf-uaac

TF_VERSION=0.11.14
wget -O terraform.zip https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_amd64.zip && \
  unzip terraform.zip && \
  sudo mv terraform /usr/local/bin && \
  rm terraform.zip

OM_VERSION=3.0.0
wget -O om https://github.com/pivotal-cf/om/releases/download/${OM_VERSION}/om-linux-${OM_VERSION} && \
  chmod +x om && \
  sudo mv om /usr/local/bin/

PN_VERSION=0.0.60
wget -O pivnet https://github.com/pivotal-cf/pivnet-cli/releases/download/v${PN_VERSION}/pivnet-linux-amd64-${PN_VERSION} && \
  chmod +x pivnet && \
  sudo mv pivnet /usr/local/bin/

BOSH_VERSION=5.5.1
wget -O bosh https://s3.amazonaws.com/bosh-cli-artifacts/bosh-cli-${BOSH_VERSION}-linux-amd64 && \
  chmod +x bosh && \
  sudo mv bosh /usr/local/bin/

CHUB_VERSION=2.4.0
wget -O credhub.tgz https://github.com/cloudfoundry-incubator/credhub-cli/releases/download/${CHUB_VERSION}/credhub-linux-${CHUB_VERSION}.tgz && \
  tar -xvf credhub.tgz && \
  sudo mv credhub /usr/local/bin && \
  rm credhub.tgz

CT_VERSION=0.5.0
wget -O control-tower https://github.com/EngineerBetter/control-tower/releases/download/${CT_VERSION}/control-tower-linux-amd64 && \
  chmod +x control-tower && \
  sudo mv control-tower /usr/local/bin/

BBR_VERSION=1.5.1
wget -O /tmp/bbr.tar https://github.com/cloudfoundry-incubator/bosh-backup-and-restore/releases/download/v${BBR_VERSION}/bbr-${BBR_VERSION}.tar && \
  tar xvC /tmp/ -f /tmp/bbr.tar && \
  sudo mv /tmp/releases/bbr /usr/local/bin/

FLY_VERSION=5.2.0
wget -O fly.tgz https://github.com/concourse/concourse/releases/download/v${FLY_VERSION}/fly-${FLY_VERSION}-linux-amd64.tgz && \
  tar -xvf fly.tgz && \
  chmod +x fly && \
  sudo mv fly /usr/local/bin/ && \
  rm fly.tgz

wget -qO- https://get.docker.com/ | sh
sudo usermod -aG docker ubuntu
```

## Create initial opsmanager

### Prepare Azure

https://docs.pivotal.io/pcf/om/2-4/azure/prepare-azure-terraform.html

You need a service principle, `PASSWORD` will become your AZURE_CLIENT_SECRET.

```
az ad app create --display-name "Service Principal for BOSH" \
--password "PASSWORD" --homepage "http://BOSHAzureCPI" \
--identifier-uris "http://BOSHAzureCPI"
```

`identifier-uris` must be unique within the organization. You can just add some random characters. Keep `homepage` as-is.

`appId` in the json blob you get back is your `AZURE_APPLICATION_ID` (user, client -- wonderfully inconsistent descriptions in the docs).

Now you can finally create a service principle, and assign the `Contributor` role we require:

```
az ad sp create --id $AZURE_APPLICATION_ID

az role assignment create --assignee $AZURE_APPLICATION_ID \
--role "Contributor" --scope /subscriptions/$AZURE_SUBSCRIPTION
```

Verify:

```
az role assignment list --assignee $AZURE_APPLICATION_ID

az login --username $AZURE_APPLICATION_ID --password $AZURE_CLIENT_SECRET \
--service-principal --tenant $AZURE_TENANT_ID
```

Perform registrations:

```
az provider register --namespace Microsoft.Storage
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.Compute
```

### Prepare and run terraform

https://docs.pivotal.io/pcf/om/2-4/azure/prepare-env-terraform.html

Download latest terraform templates from Pivnet (under PAS). Use `terraforming-pks` to pave IaaS, but `ops_manager_image_uri=""` to skip creating Opertions Manager (done via Platform Automation).

Edit `terraform.tfvars`:

```
cd ~/workspace/pivotal-cf-terraforming-azure*/terraforming-pks

cat >terraform.tfvars <<EOF
subscription_id       = "$AZURE_SUBSCRIPTION_ID"
tenant_id             = "$AZURE_TENANT_ID"
client_id             = "$AZURE_APPLICATION_ID"
client_secret         = "$AZURE_CLIENT_SECRET"
location              = "centralus"
env_name              = "sandbox"
env_short_name        = "sbx"
location              = "Central US"
dns_suffix            = "sub.domain.tld"
# optional. if left blank, you get no opsman.
ops_manager_image_uri = "https://opsmanagereastus.blob.core.windows.net/images/ops-manager-2.6.5-build.173.vhd"
# optional. if left blank, will default to the pattern `env_name.dns_suffix`.
dns_subdomain         = ""
vm_admin_username     = "notadmin"
EOF

terraform init
terraform plan -out=plan
terraform apply plan
```

Now you can follow https://docs.pivotal.io/pcf/om/2-6/azure/config-terraform.html to get the director configured.
To do that, you'll need your azure subscription details from tfvars, and a few bits retrieved from tfstate:

```
terraform output pcf_resource_group_name
terraform output bosh_root_storage_account
terraform output bosh_deployed_vms_security_group_name
terraform output ops_manager_ssh_public_key
terraform output ops_manager_ssh_private_key
```

If you need NTP servers to use (pick your region):

```
0.north-america.pool.ntp.org,1.north-america.pool.ntp.org,2.north-america.pool.ntp.org,3.north-america.pool.ntp.org
```

**Make sure you enable post deploy scripts in Director Config (required by PKS).**

Apply changes, wait...

## Create managed identities

https://docs.pivotal.io/pks/1-4/azure-managed-identities.html

This part appears to be done by [terraform](https://github.com/pivotal-cf/terraforming-azure/blob/4b578c9c7f28d7ae894187c6f7d7ae277a4ac9a6/terraforming-pks/main.tf):

```
cat >pks_master_role.json <<EOF
{
  "Name": "PKS master",
  "IsCustom": true,
  "Description": "Permissions for PKS master",
  "Actions":  [
    "Microsoft.Network/*",
    "Microsoft.Compute/disks/*",
    "Microsoft.Compute/virtualMachines/write",
    "Microsoft.Compute/virtualMachines/read",
    "Microsoft.Storage/storageAccounts/*"
  ],
  "NotActions":  [

  ],
  "DataActions":  [

  ],
  "NotDataActions":  [

  ],
  "AssignableScopes":  [
    "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}"
  ]
}
EOF

cat >pks_worker_role.json <<EOF
{
  "Name":  "PKS worker",
  "IsCustom":  true,
  "Description":  "Permissions for PKS worker",
  "Actions":  [
    "Microsoft.Storage/storageAccounts/*"
  ],
  "NotActions":  [

  ],
  "DataActions":  [

  ],
  "NotDataActions":  [

  ],
  "AssignableScopes":  [
    "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}"
  ]
}
EOF

az role definition create --role-definition pks_master_role.json
az role definition create --role-definition pks_worker_role.json
```

If you get "already exists" messages, thank terraform and just do:

```
az identity create -g $AZURE_RESOURCE_GROUP -n pks-master
az identity create -g $AZURE_RESOURCE_GROUP -n pks-worker
```

If all else fails, go into console > resource group > iam and associate `Storage Account Contributor, Network Contributor, and Virtual Machine Contributor` with `pks-master` and `Storage Account Contributor` with `pks-worker`.

That was a lot of work for an opsman.  Now you can follow https://docs.pivotal.io/pks/1-4/installing-pks-azure.html
