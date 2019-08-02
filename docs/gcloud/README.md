# Pre-reqs

You have a Google Cloud Platform account and access to https://console.cloud.google.com.

TODO: Link to docs on setting that up.

# Install gcloud SDK:

Lets you work with GCP from your local machine...

- https://cloud.google.com/sdk/install
  - https://cloud.google.com/sdk/docs/quickstart-macos
  - also: `brew cask install google-cloud-sdk`
- configure: `gcloud init` (answer questions)
- verify:
  - `gcloud config list`
  - `gcloud auth login`
- experiment:
  - go to console > compute engine and create a vm instance
  - `gcloud compute instances list`
  - `gcloud compute ssh $instanceName` _(**)_
  - `gcloud compute instances delete $instanceName --zone=$zoneName`

_(**)_ For `gcloud compute ssh` to work, you need to create instances on the default
VPC (which allows SSH by default), or add a firewall rule to your VPC allowing
the traffic. One way to do this without a blanket allow is via console >
VPC Network > $yourVPC > Firewall rules > Add firewall rule. Allow TCP/22, and
specify a target tag of "ssh-in" (or something you will remember). Then you can
simply apply this tag to compute instances to allow SSH access as needed
(`gcloud compute instances add-tags $instancename --tags ssh-in`).

# Create jumpbox

NOTE: Project and zone are coming from default config (`gcloud config list`).
Override with `--project` and `--zone` as needed.

```
gcloud services enable compute.googleapis.com

gcloud compute instances create "jbox-pks" \
  --image-project "ubuntu-os-cloud" \
  --image-family "ubuntu-1804-lts" \
  --boot-disk-size "200" \
  --machine-type=g1-small \
  --tags "jbox-pks"
```

## Authenticate jumpbox itself to GCP
```
glcoud compute ssh ubuntu@jbox-pks
gcloud auth login
```

## Enable services
```
gcloud services enable iam.googleapis.com --async
gcloud services enable cloudresourcemanager.googleapis.com --async
gcloud services enable dns.googleapis.com --async
gcloud services enable sqladmin.googleapis.com --async
gcloud services enable sourcerepo.googleapis.com --async
```

## Install tools
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

OM_VERSION=1.0.0
wget -O om https://github.com/pivotal-cf/om/releases/download/${OM_VERSION}/om-linux && \
  chmod +x om && \
  sudo mv om /usr/local/bin/

PN_VERSION=0.0.58
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

## Create service account
```
gcloud iam service-accounts create p-service --display-name "Pivotal Service Account"

gcloud projects add-iam-policy-binding $(gcloud config get-value core/project) \
  --member "serviceAccount:p-service@$(gcloud config get-value core/project).iam.gserviceaccount.com" \
  --role 'roles/owner'

gcloud iam service-accounts keys create 'gcp_credentials.json' \
  --iam-account "p-service@$(gcloud config get-value core/project).iam.gserviceaccount.com"
```

## Setup DNS
We'll need DNS names to make accessing things we deploy easier. This creates
an internal-only private domain just for use by k8s.

```
cat .env
  export PKS_DOMAIN_NAME=practice
  export PKS_SUBDOMAIN_NAME=k8s.test

gcloud dns managed-zones create practice --description="k8s/PKS practice domain" \
  --dns-name=practice.k8s.test. --visibility=private --networks $yourVPN
```

# Setup Concourse via Control Tower
```
source .env

GOOGLE_APPLICATION_CREDENTIALS=~/gcp_credentials.json \
  control-tower deploy \
    --region us-central1 \
    --iaas gcp \
    --workers 3 \
    ${PKS_SUBDOMAIN_NAME}

INFO=$(GOOGLE_APPLICATION_CREDENTIALS=~/gcp_credentials.json \
  control-tower info \
    --region us-central1 \
    --iaas gcp \
    --json \
    ${PKS_SUBDOMAIN_NAME}
)

echo "CC_ADMIN_PASSWD=$(echo ${INFO} | jq --raw-output .config.concourse_password)" >> ~/.env
echo "export CREDHUB_CA_CERT='$(echo ${INFO} | jq --raw-output .config.credhub_ca_cert)'" >> ~/.env
echo "export CREDHUB_CLIENT=credhub_admin" >> ~/.env
echo "export CREDHUB_SECRET=$(echo ${INFO} | jq --raw-output .config.credhub_admin_client_secret)" >> ~/.env
echo "export CREDHUB_SERVER=$(echo ${INFO} | jq --raw-output .config.credhub_url)" >> ~/.env

source ~/.env
```

# Download PKS and utils

On your jumpbox...

```
export PIVNET_TOKEN="$yourToken" # UAA token from network.pivotal.io
pivnet login --api-token=${PIVNET_TOKEN}

pivnet products # explore to find slugs and globs

PRODUCT_SLUG=pivotal-container-service
pivnet releases \
  --product-slug=${PRODUCT_SLUG}

RELEASE_VERSION=1.4.1
pivnet product-files \
  --product-slug=${PRODUCT_SLUG} \
  --release-version=${RELEASE_VERSION}

pivnet download-product-files \
  --product-slug=${PRODUCT_SLUG} \
  --release-version=${RELEASE_VERSION} \
  --glob='pks-linux-*'

pivnet download-product-files \
  --product-slug=${PRODUCT_SLUG} \
  --release-version=${RELEASE_VERSION} \
  --glob='kubectl-linux-*'

chmod +x pks-linux-*
chmod +x kubectl-linux-*
sudo mv pks-linux-* /usr/local/bin/pks
sudo mv kubectl-linux-* /usr/local/bin/kubectl
```

JSON output can be useful:

```
pivnet --format=json product-files \
  --product-slug=${PRODUCT_SLUG} \
  --release-version=${RELEASE_VERSION} \
  | jq '.[] | {name: .name, key: .aws_object_key}'
```
