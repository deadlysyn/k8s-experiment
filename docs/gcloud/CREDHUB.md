# Generate self-signed key and cert

```
credhub generate --name /concourse/main/pks-cert \
  --type certificate \
  --common-name "${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME}" \
  --alternative-name "*.${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME}" \
  --alternative-name "*.pks.${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME}" \
  --self-sign
  ```

