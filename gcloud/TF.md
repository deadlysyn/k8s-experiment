# Download

In a web browser, navigate to https://github.com/pivotal-cf/terraforming-gcp/releases/latest and identify the latest release ID (e.g. 0.74.0).

```
TGCP_VERSION=0.74.0

wget -O ~/terraforming-gcp.tar.gz https://github.com/pivotal-cf/terraforming-gcp/releases/download/v${TGCP_VERSION}/terraforming-gcp-v${TGCP_VERSION}.tar.gz && \
  tar -zxvf ~/terraforming-gcp.tar.gz -C ~ && \
  rm ~/terraforming-gcp.tar.gz

cd ~/terraforming/terraforming-pks

cat > terraform.tfvars <<-EOF
dns_suffix          = "${PKS_DOMAIN_NAME}"
env_name            = "${PKS_SUBDOMAIN_NAME}"
region              = "us-central1"
zones               = ["us-central1-b", "us-central1-a", "us-central1-c"]
project             = "$(gcloud config get-value core/project)"
opsman_image_url    = ""
opsman_vm           = 0
create_gcs_buckets  = "false"
external_database   = 0
isolation_segment   = 0
service_account_key = <<SERVICE_ACCOUNT_KEY
$(cat ~/gcp_credentials.json)
SERVICE_ACCOUNT_KEY
EOF
```
