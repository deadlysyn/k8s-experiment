# Login

```
ADMIN_PASSWORD=$(om credentials \
  -p pivotal-container-service \
  -c '.properties.uaa_admin_password' \
  -f secret)

pks login -a \
  https://api.pks.${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME} \
  --skip-ssl-validation \
  -u admin \
  -p ${ADMIN_PASSWORD}
```

another way...

```
CLUSTER_NAME=cluster-1

pks login \
  --api https://api.pks.${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME} \
  --username admin \
  --password $(om credentials \
      -p pivotal-container-service \
      -c '.properties.uaa_admin_password' \
      -f secret) \
  --skip-ssl-validation
```

# Create a cluster

```
pks clusters

pks plans

CLUSTER_NAME="cluster-1"

pks create-cluster ${CLUSTER_NAME} \
  --num-nodes 3 \
  --plan small \
  --external-hostname ${CLUSTER_NAME}.${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME}

watch pks cluster ${CLUSTER_NAME}
```

When `Last Action State` says "succeeded", your cluster will be ready for use. This can take 20 minutes or more.

# Configure DNS for master node (GCP)

```
K8S_MASTER_INTERNAL_IP=$( \
  pks cluster ${CLUSTER_NAME} --json |
    jq --raw-output '.kubernetes_master_ips[0]' \
)

K8S_MASTER_EXTERNAL_IP=$( \
  gcloud compute instances list --format json | \
    jq --raw-output --arg V "${K8S_MASTER_INTERNAL_IP}" \
    '.[] | select(.networkInterfaces[].networkIP | match ($V))
        | .networkInterfaces[].accessConfigs[].natIP' \
)

gcloud dns record-sets transaction start \
  --zone=${PKS_SUBDOMAIN_NAME}-zone

  gcloud dns record-sets transaction \
    add ${K8S_MASTER_EXTERNAL_IP} \
    --name=${CLUSTER_NAME}.${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME}. \
    --ttl=300 --type=A --zone=${PKS_SUBDOMAIN_NAME}-zone

gcloud dns record-sets transaction execute \
  --zone=${PKS_SUBDOMAIN_NAME}-zone
```

# Login to cluster

```
pks get-credentials "${CLUSTER_NAME}" # updates ~/.kube

kubectl cluster-info
```

# 

